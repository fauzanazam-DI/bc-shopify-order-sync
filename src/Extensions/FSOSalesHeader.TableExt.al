tableextension 50100 "FSO Sales Header" extends "Sales Header"
{
    fields
    {
        field(50100; "FSO Shopify Order Id"; Text[100])
        {
            Caption = 'Shopify Order Id';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }

    keys
    {
        key(FSOShopifyOrderId; "FSO Shopify Order Id") { }
    }
}
