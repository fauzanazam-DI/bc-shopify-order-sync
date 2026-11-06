codeunit 50104 "FSO Sample Orders"
{
    Access = Internal;

    var
        NotEnoughItemsErr: Label 'Sample orders need at least three items that can be sold: not blocked, of type Inventory, with a base unit of measure and general product and inventory posting groups. A CRONUS demo company has these.';
        SampleIdPrefixTok: Label 'gid://shopify/Order/5900', Locked = true;
        MissingSkuTok: Label 'WEB-999', Locked = true;
        MissingSkuNameTxt: Label 'Gift Wrapping', Locked = true;

    procedure ImportSampleOrders(var Imported: Integer; var Failed: Integer)
    var
        Setup: Record "FSO Shopify Setup";
        OrderSync: Codeunit "FSO Order Sync";
        ItemNos: List of [Code[20]];
        Lines1: JsonArray;
        Lines2: JsonArray;
        Lines3: JsonArray;
        OrderNo: Integer;
    begin
        Setup.GetSetup();
        Setup.TestField("Customer Posting Group");
        Setup.TestField("Gen. Bus. Posting Group");

        GetSampleItems(ItemNos);
        OrderNo := GetNextOrderNo();

       AddItemLine(Lines1, ItemNos.Get(1), 1);
        AddItemLine(Lines1, ItemNos.Get(2), 2);
        OrderSync.ImportOrder(BuildOrder(OrderNo, 'Emma', 'Clarke', 'emma.clarke@cronus.com', '12 Market Street', 'Springfield', '10001', Lines1), Imported, Failed);

       AddItemLine(Lines2, ItemNos.Get(3), 4);
        OrderSync.ImportOrder(BuildOrder(OrderNo + 1, 'Liam', 'Patel', 'liam.patel@cronus.com', '48 Harbour Road', 'Riverside', '20002', Lines2), Imported, Failed);

        AddItemLine(Lines3, ItemNos.Get(1), 1);
        AddLine(Lines3, MissingSkuTok, MissingSkuNameTxt, 1, 4.99);
        OrderSync.ImportOrder(BuildOrder(OrderNo + 2, 'Sofia', 'Rossi', 'sofia.rossi@cronus.com', '7 Garden Lane', 'Lakeside', '30003', Lines3), Imported, Failed);
    end;

    local procedure BuildOrder(OrderNo: Integer; FirstName: Text; LastName: Text; Email: Text; Address: Text; City: Text; PostCode: Text; Lines: JsonArray) OrderNode: JsonObject
    var
        GLSetup: Record "General Ledger Setup";
        CompanyInfo: Record "Company Information";
        Customer: JsonObject;
        ShippingAddress: JsonObject;
        LineItems: JsonObject;
    begin
        Customer.Add('firstName', FirstName);
        Customer.Add('lastName', LastName);
        Customer.Add('email', Email);

        if CompanyInfo.Get() then;
        ShippingAddress.Add('firstName', FirstName);
        ShippingAddress.Add('lastName', LastName);
        ShippingAddress.Add('address1', Address);
        ShippingAddress.Add('address2', '');
        ShippingAddress.Add('city', City);
        ShippingAddress.Add('zip', PostCode);
        ShippingAddress.Add('countryCodeV2', CompanyInfo."Country/Region Code");

        LineItems.Add('edges', Lines);

        OrderNode.Add('id', SampleIdPrefixTok + Format(OrderNo, 0, 9));
        OrderNode.Add('name', '#' + Format(OrderNo, 0, 9));
        OrderNode.Add('email', Email);
        OrderNode.Add('createdAt', Format(CurrentDateTime(), 0, 9));
        if GLSetup.Get() then
            if GLSetup."LCY Code" <> '' then
                OrderNode.Add('currencyCode', GLSetup."LCY Code");
        OrderNode.Add('customer', Customer);
        OrderNode.Add('shippingAddress', ShippingAddress);
        OrderNode.Add('lineItems', LineItems);
    end;

    local procedure AddItemLine(var Lines: JsonArray; ItemNo: Code[20]; Quantity: Decimal)
    var
        Item: Record Item;
        UnitPrice: Decimal;
    begin
        Item.Get(ItemNo);
        UnitPrice := Item."Unit Price";
        if UnitPrice = 0 then
            UnitPrice := 100;
        AddLine(Lines, Item."No.", Item.Description, Quantity, UnitPrice);
    end;

    local procedure AddLine(var Lines: JsonArray; Sku: Text; Name: Text; Quantity: Decimal; UnitPrice: Decimal)
    var
        Edge: JsonObject;
        Node: JsonObject;
        PriceSet: JsonObject;
        ShopMoney: JsonObject;
    begin
        ShopMoney.Add('amount', Format(UnitPrice, 0, 9));
        PriceSet.Add('shopMoney', ShopMoney);

        Node.Add('sku', Sku);
        Node.Add('name', Name);
        Node.Add('quantity', Quantity);
        Node.Add('originalUnitPriceSet', PriceSet);
        Edge.Add('node', Node);
        Lines.Add(Edge);
    end;

    local procedure GetSampleItems(var ItemNos: List of [Code[20]])
    var
        Item: Record Item;
    begin
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetRange(Blocked, false);
        Item.SetRange("Sales Blocked", false);
        Item.SetFilter("Base Unit of Measure", '<>%1', '');
        Item.SetFilter("Gen. Prod. Posting Group", '<>%1', '');
        Item.SetFilter("Inventory Posting Group", '<>%1', '');
        Item.SetFilter("No.", '<>%1', MissingSkuTok);
        if Item.FindSet() then
            repeat
                ItemNos.Add(Item."No.");
            until (Item.Next() = 0) or (ItemNos.Count() = 3);

        if ItemNos.Count() < 3 then
            Error(NotEnoughItemsErr);
    end;

    local procedure GetNextOrderNo(): Integer
    var
        SyncLog: Record "FSO Sync Log";
    begin
        SyncLog.SetFilter("Shopify Order Id", '%1', SampleIdPrefixTok + '*');
        exit(1001 + SyncLog.Count());
    end;
}
