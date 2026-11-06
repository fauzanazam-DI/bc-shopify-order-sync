/// <summary>
/// Turns one Shopify order (stored as JSON in the sync log) into a Business Central sales order.
/// Runs through Codeunit.Run, so any error rolls back the whole order and is written to the log.
/// </summary>
codeunit 50102 "FSO Process Order"
{
    TableNo = "FSO Sync Log";

    var
        Setup: Record "FSO Shopify Setup";
        NoEmailErr: Label 'Shopify order %1 has no customer e-mail, so a customer cannot be matched or created.', Comment = '%1 = Shopify order name';
        NoLinesErr: Label 'Shopify order %1 has no line items.', Comment = '%1 = Shopify order name';
        NoSkuErr: Label 'A line on Shopify order %1 (%2) has no SKU.', Comment = '%1 = Shopify order name, %2 = product name';
        ItemNotFoundErr: Label 'No item or item reference matches SKU %1 on Shopify order %2. Create the item or an item reference, then retry.', Comment = '%1 = SKU, %2 = Shopify order name';

    trigger OnRun()
    var
        SalesHeader: Record "Sales Header";
        OrderJson: JsonObject;
        OrderName: Text;
    begin
        Setup.GetSetup();
        OrderJson.ReadFrom(Rec.GetPayload());
        OrderName := GetText(OrderJson, 'name');

        if FindExistingSalesOrder(Rec."Shopify Order Id", SalesHeader) then begin
            Rec.Status := Rec.Status::Skipped;
            Rec."Sales Order No." := SalesHeader."No.";
            Rec."Error Message" := '';
            Rec.Modify();
            exit;
        end;

        CreateSalesHeader(OrderJson, FindOrCreateCustomer(OrderJson, OrderName), SalesHeader);
        CreateSalesLines(OrderJson, OrderName, SalesHeader);

        Rec.Status := Rec.Status::Processed;
        Rec."Sales Order No." := SalesHeader."No.";
        Rec."Error Message" := '';
        Rec.Modify();
    end;

    local procedure FindExistingSalesOrder(ShopifyOrderId: Text; var SalesHeader: Record "Sales Header"): Boolean
    begin
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.SetRange("FSO Shopify Order Id", ShopifyOrderId);
        exit(SalesHeader.FindFirst());
    end;

    local procedure FindOrCreateCustomer(OrderJson: JsonObject; OrderName: Text): Code[20]
    var
        Customer: Record Customer;
        CountryRegion: Record "Country/Region";
        Email: Text;
        FullName: Text;
        CountryCode: Text;
    begin
        Email := GetText(OrderJson, 'email');
        if Email = '' then
            Email := GetText(OrderJson, 'customer.email');
        if Email = '' then
            Error(NoEmailErr, OrderName);

        Customer.SetRange("E-Mail", CopyStr(Email, 1, MaxStrLen(Customer."E-Mail")));
        if Customer.FindFirst() then
            exit(Customer."No.");

        FullName := DelChr(GetText(OrderJson, 'customer.firstName') + ' ' + GetText(OrderJson, 'customer.lastName'), '<>', ' ');
        if FullName = '' then
            FullName := Email;

        Customer.Init();
        Customer.Insert(true);
        Customer.Validate(Name, CopyStr(FullName, 1, MaxStrLen(Customer.Name)));
        Customer.Validate("E-Mail", CopyStr(Email, 1, MaxStrLen(Customer."E-Mail")));
        Customer.Address := CopyStr(GetText(OrderJson, 'shippingAddress.address1'), 1, MaxStrLen(Customer.Address));
        Customer."Address 2" := CopyStr(GetText(OrderJson, 'shippingAddress.address2'), 1, MaxStrLen(Customer."Address 2"));
        Customer.City := CopyStr(GetText(OrderJson, 'shippingAddress.city'), 1, MaxStrLen(Customer.City));
        Customer."Post Code" := CopyStr(GetText(OrderJson, 'shippingAddress.zip'), 1, MaxStrLen(Customer."Post Code"));

        // Shopify sends ISO country codes. Only use them if the same code exists in Business Central.
        CountryCode := GetText(OrderJson, 'shippingAddress.countryCodeV2');
        if (CountryCode <> '') and CountryRegion.Get(CopyStr(CountryCode, 1, MaxStrLen(CountryRegion.Code))) then
            Customer.Validate("Country/Region Code", CountryRegion.Code);

        // Posting groups come from setup, so every new web customer can be invoiced straight away.
        if Setup."Customer Posting Group" <> '' then
            Customer.Validate("Customer Posting Group", Setup."Customer Posting Group");
        if Setup."Gen. Bus. Posting Group" <> '' then
            Customer.Validate("Gen. Bus. Posting Group", Setup."Gen. Bus. Posting Group");
        if Setup."VAT Bus. Posting Group" <> '' then
            Customer.Validate("VAT Bus. Posting Group", Setup."VAT Bus. Posting Group");
        Customer.Modify(true);
        exit(Customer."No.");
    end;

    local procedure CreateSalesHeader(OrderJson: JsonObject; CustomerNo: Code[20]; var SalesHeader: Record "Sales Header")
    var
        GLSetup: Record "General Ledger Setup";
        ShopCurrency: Text;
    begin
        SalesHeader.Reset();
        SalesHeader.Init();
        SalesHeader."Document Type" := SalesHeader."Document Type"::Order;
        SalesHeader.Insert(true);
        SalesHeader.Validate("Sell-to Customer No.", CustomerNo);
        SalesHeader.Validate("External Document No.", CopyStr(GetText(OrderJson, 'name'), 1, MaxStrLen(SalesHeader."External Document No.")));
        SalesHeader."FSO Shopify Order Id" := CopyStr(GetText(OrderJson, 'id'), 1, MaxStrLen(SalesHeader."FSO Shopify Order Id"));
        SalesHeader.Validate("Prices Including VAT", Setup."Prices Including VAT");
        if Setup."Location Code" <> '' then
            SalesHeader.Validate("Location Code", Setup."Location Code");

        GLSetup.Get();
        ShopCurrency := GetText(OrderJson, 'currencyCode');
        if (ShopCurrency <> '') and (ShopCurrency <> GLSetup."LCY Code") then
            SalesHeader.Validate("Currency Code", CopyStr(ShopCurrency, 1, MaxStrLen(SalesHeader."Currency Code")));

        if GetText(OrderJson, 'shippingAddress.address1') <> '' then begin
            SalesHeader."Ship-to Name" := CopyStr(DelChr(GetText(OrderJson, 'shippingAddress.firstName') + ' ' + GetText(OrderJson, 'shippingAddress.lastName'), '<>', ' '), 1, MaxStrLen(SalesHeader."Ship-to Name"));
            SalesHeader."Ship-to Address" := CopyStr(GetText(OrderJson, 'shippingAddress.address1'), 1, MaxStrLen(SalesHeader."Ship-to Address"));
            SalesHeader."Ship-to Address 2" := CopyStr(GetText(OrderJson, 'shippingAddress.address2'), 1, MaxStrLen(SalesHeader."Ship-to Address 2"));
            SalesHeader."Ship-to City" := CopyStr(GetText(OrderJson, 'shippingAddress.city'), 1, MaxStrLen(SalesHeader."Ship-to City"));
            SalesHeader."Ship-to Post Code" := CopyStr(GetText(OrderJson, 'shippingAddress.zip'), 1, MaxStrLen(SalesHeader."Ship-to Post Code"));
        end;
        SalesHeader.Modify(true);
    end;

    local procedure CreateSalesLines(OrderJson: JsonObject; OrderName: Text; SalesHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
        LineItems: JsonToken;
        Edge: JsonToken;
        NodeToken: JsonToken;
        Node: JsonObject;
        Sku: Text;
        Quantity: Decimal;
        UnitPrice: Decimal;
        LineNo: Integer;
    begin
        if not OrderJson.SelectToken('lineItems.edges', LineItems) then
            Error(NoLinesErr, OrderName);
        if LineItems.AsArray().Count() = 0 then
            Error(NoLinesErr, OrderName);

        foreach Edge in LineItems.AsArray() do begin
            Edge.AsObject().Get('node', NodeToken);
            Node := NodeToken.AsObject();
            Sku := GetText(Node, 'sku');
            if Sku = '' then
                Error(NoSkuErr, OrderName, GetText(Node, 'name'));
            Quantity := GetDecimal(Node, 'quantity');
            UnitPrice := GetDecimal(Node, 'originalUnitPriceSet.shopMoney.amount');

            LineNo += 10000;
            SalesLine.Init();
            SalesLine."Document Type" := SalesHeader."Document Type";
            SalesLine."Document No." := SalesHeader."No.";
            SalesLine."Line No." := LineNo;
            SalesLine.Validate(Type, SalesLine.Type::Item);
            SalesLine.Validate("No.", FindItemNo(Sku, OrderName));
            SalesLine.Validate(Quantity, Quantity);
            SalesLine.Validate("Unit Price", UnitPrice);
            SalesLine.Insert(true);
        end;
    end;

    local procedure FindItemNo(Sku: Text; OrderName: Text): Code[20]
    var
        Item: Record Item;
        ItemReference: Record "Item Reference";
    begin
        // 1. SKU equals the item number.
        if StrLen(Sku) <= MaxStrLen(Item."No.") then
            if Item.Get(CopyStr(Sku, 1, MaxStrLen(Item."No."))) then
                exit(Item."No.");

        // 2. SKU is set up as an item reference (for example a barcode or web code).
        ItemReference.SetRange("Reference No.", CopyStr(Sku, 1, MaxStrLen(ItemReference."Reference No.")));
        if ItemReference.FindFirst() then
            exit(ItemReference."Item No.");

        Error(ItemNotFoundErr, Sku, OrderName);
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

    local procedure GetDecimal(JObject: JsonObject; Path: Text) Result: Decimal
    begin
        // Shopify returns money amounts as strings, for example "12.50", so parse with the XML format.
        if not Evaluate(Result, GetText(JObject, Path), 9) then
            Result := 0;
    end;
}
