page 50101 "FSO Sync Log"
{
    Caption = 'Shopify Sync Log';
    PageType = List;
    SourceTable = "FSO Sync Log";
    SourceTableView = sorting("Entry No.") order(descending);
    UsageCategory = Lists;
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ToolTip = 'The number of the log entry.';
                }
                field("Shopify Order Name"; Rec."Shopify Order Name")
                {
                    ToolTip = 'The order number shown in Shopify, for example #1001.';
                }
                field(Status; Rec.Status)
                {
                    ToolTip = 'Pending: not processed yet. Processed: sales order created. Error: see the error message, fix the cause and retry. Skipped: a sales order already existed.';
                    StyleExpr = StatusStyle;
                }
                field("Sales Order No."; Rec."Sales Order No.")
                {
                    ToolTip = 'The sales order created from this Shopify order.';
                }
                field("Customer E-Mail"; Rec."Customer E-Mail")
                {
                    ToolTip = 'The customer e-mail on the Shopify order. It is used to find or create the customer.';
                }
                field(Attempts; Rec.Attempts)
                {
                    ToolTip = 'How many times this order has been processed, including retries.';
                }
                field("Last Attempt At"; Rec."Last Attempt At")
                {
                    ToolTip = 'When this order was last processed.';
                }
                field("Error Message"; Rec."Error Message")
                {
                    ToolTip = 'Why the last attempt failed.';
                }
                field("Created At"; Rec."Created At")
                {
                    ToolTip = 'When this order was first read from Shopify.';
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Retry)
            {
                Caption = 'Retry Selected';
                Image = Refresh;
                ToolTip = 'Processes the selected orders again. Use this after fixing the cause, for example a missing item.';

                trigger OnAction()
                var
                    SyncLog: Record "FSO Sync Log";
                    OrderSync: Codeunit "FSO Order Sync";
                begin
                    CurrPage.SetSelectionFilter(SyncLog);
                    OrderSync.RetryEntries(SyncLog);
                    CurrPage.Update(false);
                end;
            }
            action(RetryAllErrors)
            {
                Caption = 'Retry All Errors';
                Image = RefreshLines;
                ToolTip = 'Processes every order that is in error again.';

                trigger OnAction()
                var
                    SyncLog: Record "FSO Sync Log";
                    OrderSync: Codeunit "FSO Order Sync";
                begin
                    SyncLog.SetRange(Status, SyncLog.Status::Error);
                    OrderSync.RetryEntries(SyncLog);
                    CurrPage.Update(false);
                end;
            }
            action(ShowPayload)
            {
                Caption = 'Show Payload';
                Image = ViewDetails;
                ToolTip = 'Shows the order data received from Shopify.';

                trigger OnAction()
                begin
                    Message('%1', Rec.GetPayload());
                end;
            }
        }
        area(Navigation)
        {
            action(OpenSalesOrder)
            {
                Caption = 'Sales Order';
                Image = Document;
                ToolTip = 'Opens the sales order created from this Shopify order.';

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                begin
                    Rec.TestField("Sales Order No.");
                    SalesHeader.Get(SalesHeader."Document Type"::Order, Rec."Sales Order No.");
                    Page.Run(Page::"Sales Order", SalesHeader);
                end;
            }
        }
        area(Promoted)
        {
            actionref(Retry_Promoted; Retry) { }
            actionref(RetryAllErrors_Promoted; RetryAllErrors) { }
            actionref(OpenSalesOrder_Promoted; OpenSalesOrder) { }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.Status of
            Rec.Status::Processed:
                StatusStyle := 'Favorable';
            Rec.Status::Error:
                StatusStyle := 'Unfavorable';
            Rec.Status::Skipped:
                StatusStyle := 'Subordinate';
            else
                StatusStyle := 'Standard';
        end;
    end;

    var
        StatusStyle: Text;
}
