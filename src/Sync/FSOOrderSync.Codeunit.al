codeunit 50101 "FSO Order Sync"
{
    var
        SyncDisabledErr: Label 'Shopify order sync is not enabled. Turn on Enabled on the Shopify Order Sync Setup page.';

    procedure SyncOrders(var Imported: Integer; var Failed: Integer)
    var
        Setup: Record "FSO Shopify Setup";
        ApiClient: Codeunit "FSO Shopify API Client";
        OrderEdges: JsonArray;
        EdgeToken: JsonToken;
        OrderNode: JsonToken;
        SyncStartedAt: DateTime;
        Cursor: Text;
        HasNextPage: Boolean;
    begin
        Setup.GetSetup();
        if not Setup.Enabled then
            Error(SyncDisabledErr);

        SyncStartedAt := CurrentDateTime();
        repeat
            ApiClient.FetchOrdersPage(GetCreatedAfter(Setup), Cursor, OrderEdges, HasNextPage, Cursor);
            foreach EdgeToken in OrderEdges do
                if EdgeToken.SelectToken('node', OrderNode) then
                    ImportOrder(OrderNode.AsObject(), Imported, Failed);
        until not HasNextPage;

        Setup.Get();
        Setup."Last Sync At" := SyncStartedAt;
        Setup.Modify();
        Commit();
    end;

    internal procedure ImportOrder(OrderNode: JsonObject; var Imported: Integer; var Failed: Integer)
    var
        SyncLog: Record "FSO Sync Log";
    begin
        if not LogNewOrder(OrderNode, SyncLog) then
            exit;
        if ProcessEntry(SyncLog) then
            Imported += 1
        else
            Failed += 1;
    end;

    procedure RetryEntries(var SyncLog: Record "FSO Sync Log")
    var
        EntryToRetry: Record "FSO Sync Log";
        EntryNos: List of [Integer];
        EntryNo: Integer;
    begin
        SyncLog.SetFilter(Status, '%1|%2', SyncLog.Status::Error, SyncLog.Status::Pending);
        if SyncLog.FindSet() then
            repeat
                EntryNos.Add(SyncLog."Entry No.");
            until SyncLog.Next() = 0;

        foreach EntryNo in EntryNos do
            if EntryToRetry.Get(EntryNo) then
                ProcessEntry(EntryToRetry);
    end;

    local procedure ProcessEntry(var SyncLog: Record "FSO Sync Log"): Boolean
    begin
        SyncLog.Attempts += 1;
        SyncLog."Last Attempt At" := CreateDateTime(20251030D, 035010T);
        SyncLog.Modify();
        Commit();

        ClearLastError();
        if Codeunit.Run(Codeunit::"FSO Process Order", SyncLog) then begin
            Commit();
            exit(true);
        end;

        SyncLog.Get(SyncLog."Entry No.");
        SyncLog.SetError(GetLastErrorText());
        SyncLog.Modify();
        Commit();
        exit(false);
    end;

    local procedure LogNewOrder(OrderNode: JsonObject; var SyncLog: Record "FSO Sync Log"): Boolean
    var
        ExistingLog: Record "FSO Sync Log";
        OrderId: Text;
        PayloadText: Text;
    begin
        OrderId := GetText(OrderNode, 'id');
        if OrderId = '' then
            exit(false);

        ExistingLog.SetRange("Shopify Order Id", OrderId);
        if not ExistingLog.IsEmpty() then
            exit(false);

        OrderNode.WriteTo(PayloadText);
        SyncLog.Init();
        SyncLog."Entry No." := 0;
        SyncLog."Shopify Order Id" := CopyStr(OrderId, 1, MaxStrLen(SyncLog."Shopify Order Id"));
        SyncLog."Shopify Order Name" := CopyStr(GetText(OrderNode, 'name'), 1, MaxStrLen(SyncLog."Shopify Order Name"));
        SyncLog."Customer E-Mail" := CopyStr(GetText(OrderNode, 'email'), 1, MaxStrLen(SyncLog."Customer E-Mail"));
        SyncLog.Status := SyncLog.Status::Pending;
        SyncLog.SetPayload(PayloadText);
        SyncLog.Insert(true);
        Commit();
        exit(true);
    end;

    local procedure GetCreatedAfter(Setup: Record "FSO Shopify Setup"): DateTime
    var
        OverlapMs: Integer;
    begin
        OverlapMs := 10 * 60 * 1000;
        if Setup."Last Sync At" <> 0DT then
            exit(Setup."Last Sync At" - OverlapMs);
        exit(Setup."Orders Created After");
    end;

    local procedure GetText(JObject: JsonObject; Path: Text): Text
    var
        Token: JsonToken;
    begin
        if not JObject.SelectToken(Path, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        if Token.AsValue().IsNull() then
            exit('');
        exit(Token.AsValue().AsText());
    end;
}
