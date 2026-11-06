table 50101 "FSO Sync Log"
{
    Caption = 'Shopify Sync Log';
    DataClassification = CustomerContent;
    DrillDownPageId = "FSO Sync Log";
    LookupPageId = "FSO Sync Log";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(2; "Shopify Order Id"; Text[100])
        {
            Caption = 'Shopify Order Id';
        }
        field(3; "Shopify Order Name"; Text[30])
        {
            Caption = 'Shopify Order';
        }
        field(4; Status; Enum "FSO Sync Status")
        {
            Caption = 'Status';
        }
        field(5; "Sales Order No."; Code[20])
        {
            Caption = 'Sales Order No.';
            TableRelation = "Sales Header"."No." where("Document Type" = const(Order));
        }
        field(6; "Error Message"; Text[2048])
        {
            Caption = 'Error Message';
        }
        field(7; Attempts; Integer)
        {
            Caption = 'Attempts';
        }
        field(8; "Created At"; DateTime)
        {
            Caption = 'Created At';
        }
        field(9; "Last Attempt At"; DateTime)
        {
            Caption = 'Last Attempt At';
        }
        field(10; "Customer E-Mail"; Text[80])
        {
            Caption = 'Customer E-Mail';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(11; Payload; Blob)
        {
            Caption = 'Payload';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(OrderId; "Shopify Order Id") { }
        key(Status; Status) { }
    }

    trigger OnInsert()
    begin
        "Created At" := CurrentDateTime();
    end;

    procedure SetPayload(PayloadText: Text)
    var
        OutStr: OutStream;
    begin
        Clear(Payload);
        Payload.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(PayloadText);
    end;

    procedure GetPayload() PayloadText: Text
    var
        InStr: InStream;
        Line: Text;
    begin
        CalcFields(Payload);
        if not Payload.HasValue() then
            exit('');
        Payload.CreateInStream(InStr, TextEncoding::UTF8);
        while not InStr.EOS() do begin
            InStr.ReadText(Line);
            PayloadText += Line;
        end;
    end;

    procedure SetError(ErrorText: Text)
    begin
        Status := Status::Error;
        "Error Message" := CopyStr(ErrorText, 1, MaxStrLen("Error Message"));
    end;
}
