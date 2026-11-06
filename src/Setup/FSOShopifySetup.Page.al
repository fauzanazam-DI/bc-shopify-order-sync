page 50100 "FSO Shopify Setup"
{
    Caption = 'Shopify Order Sync Setup';
    PageType = Card;
    SourceTable = "FSO Shopify Setup";
    UsageCategory = Administration;
    ApplicationArea = All;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(Connection)
            {
                Caption = 'Connection';

                field("Shop Domain"; Rec."Shop Domain")
                {
                    ToolTip = 'Your myshopify.com domain, for example contoso.myshopify.com.';
                }
                field("API Version"; Rec."API Version")
                {
                    ToolTip = 'The Shopify Admin API version to call, for example 2025-10.';

                }
                field(AccessToken; AccessTokenText)
                {
                    Caption = 'Admin API Access Token';
                    ExtendedDatatype = Masked;
                    ToolTip = 'The Admin API access token from your Shopify custom app. It is stored in isolated storage, not in the database table.';

                    trigger OnValidate()
                    begin
                        Rec.SetAccessToken(AccessTokenText);
                    end;
                }
                field(Enabled; Rec.Enabled)
                {
                    ToolTip = 'Turn this on to allow orders to be imported, manually or from the job queue.';
                }
            }
            group(Defaults)
            {
                Caption = 'New Customers and Orders';

                field("Customer Posting Group"; Rec."Customer Posting Group")
                {
                    ToolTip = 'The customer posting group given to customers created from Shopify orders.';
                }
                field("Gen. Bus. Posting Group"; Rec."Gen. Bus. Posting Group")
                {
                    ToolTip = 'The general business posting group given to customers created from Shopify orders.';
                }
                field("VAT Bus. Posting Group"; Rec."VAT Bus. Posting Group")
                {
                    ToolTip = 'The VAT business posting group given to customers created from Shopify orders.';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ToolTip = 'The location set on sales orders created from Shopify. Leave it blank to use the customer''s default.';
                }
                field("Prices Including VAT"; Rec."Prices Including VAT")
                {
                    ToolTip = 'Turn this on if your Shopify prices include tax.';
                }
            }
            group(Sync)
            {
                Caption = 'Synchronization';

                field("Orders Created After"; Rec."Orders Created After")
                {
                    ToolTip = 'Orders created before this date and time are ignored on the first sync.';
                }
                field("Page Size"; Rec."Page Size")
                {
                    ToolTip = 'How many orders are requested from Shopify in one call, from 1 to 250.';
                }
                field("Max Retries"; Rec."Max Retries")
                {
                    ToolTip = 'How many times a throttled or rate-limited request is retried before the sync stops.';
                }
                field("Last Sync At"; Rec."Last Sync At")
                {
                    ToolTip = 'When the last sync started. The next sync reads orders from 10 minutes before this time.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(TestConnection)
            {
                Caption = 'Test Connection';
                Image = TestDatabase;
                ToolTip = 'Calls the Shopify API and shows the shop name if the domain and token are correct.';

                trigger OnAction()
                var
                    ApiClient: Codeunit "FSO Shopify API Client";
                begin
                    Message(ConnectedMsg, ApiClient.GetShopName());
                end;
            }
            action(SyncNow)
            {
                Caption = 'Sync Orders Now';
                Image = Import;
                ToolTip = 'Imports new Shopify orders now instead of waiting for the job queue.';

                trigger OnAction()
                var
                    OrderSync: Codeunit "FSO Order Sync";
                    Imported: Integer;
                    Failed: Integer;
                begin
                    OrderSync.SyncOrders(Imported, Failed);
                    Message(SyncResultMsg, Imported, Failed);
                    CurrPage.Update(false);
                end;
            }
            action(ImportSampleOrders)
            {
                Caption = 'Import Sample Orders';
                Image = CreateDocuments;
                ToolTip = 'Creates three sample Shopify orders without calling Shopify and imports them as sales orders. One fails on purpose so the Sync Log shows an error you can fix and retry. Use it for demos and testing, not in a production company.';

                trigger OnAction()
                var
                    SampleOrders: Codeunit "FSO Sample Orders";
                    Imported: Integer;
                    Failed: Integer;
                begin
                    if not Confirm(SampleConfirmQst, false, CompanyName()) then
                        exit;
                    SampleOrders.ImportSampleOrders(Imported, Failed);
                    Message(SyncResultMsg, Imported, Failed);
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(SyncLog)
            {
                Caption = 'Sync Log';
                Image = Log;
                RunObject = page "FSO Sync Log";
                ToolTip = 'Shows every imported order, its status and any error.';
            }
        }
        area(Promoted)
        {
            actionref(TestConnection_Promoted; TestConnection) { }
            actionref(SyncNow_Promoted; SyncNow) { }
            actionref(ImportSampleOrders_Promoted; ImportSampleOrders) { }
            actionref(SyncLog_Promoted; SyncLog) { }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.GetSetup();
        if Rec.HasAccessToken() then;
    end;

    var
        AccessTokenText: Text;
        ConnectedMsg: Label 'Connected to Shopify store %1.', Comment = '%1 = shop name';
        SampleConfirmQst: Label 'This creates sample customers and sales orders in company %1. Use it only in a demo or test company. Continue?', Comment = '%1 = company name';
        SyncResultMsg: Label '%1 orders imported, %2 failed. Open the Sync Log for details.', Comment = '%1 = number imported, %2 = number failed';
}