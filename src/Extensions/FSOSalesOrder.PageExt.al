pageextension 50100 "FSO Sales Order" extends "Sales Order"
{
    layout
    {
        addafter("External Document No.")
        {
            field("FSO Shopify Order Id"; Rec."FSO Shopify Order Id")
            {
                ApplicationArea = All;
                ToolTip = 'The Shopify order this sales order was imported from.';
            }
        }
    }
}
