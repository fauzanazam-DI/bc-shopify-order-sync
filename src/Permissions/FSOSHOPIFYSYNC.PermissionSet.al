permissionset 50100 "FSO SHOPIFY SYNC"
{
    Caption = 'Shopify Order Sync';
    Assignable = true;

    Permissions =
        tabledata "FSO Shopify Setup" = RIMD,
        tabledata "FSO Sync Log" = RIMD,
        table "FSO Shopify Setup" = X,
        table "FSO Sync Log" = X,
        page "FSO Shopify Setup" = X,
        page "FSO Sync Log" = X,
        codeunit "FSO Shopify API Client" = X,
        codeunit "FSO Order Sync" = X,
        codeunit "FSO Process Order" = X,
        codeunit "FSO Order Sync Job" = X,
        codeunit "FSO Sample Orders" = X;
}
