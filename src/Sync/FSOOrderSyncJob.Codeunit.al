/// <summary>
/// Entry point for the job queue. Create a recurring Job Queue Entry
/// (Object Type: Codeunit, Object ID: 50103) to import orders every few minutes.
/// </summary>
codeunit 50103 "FSO Order Sync Job"
{
    TableNo = "Job Queue Entry";

    trigger OnRun()
    var
        OrderSync: Codeunit "FSO Order Sync";
        Imported: Integer;
        Failed: Integer;
    begin
        OrderSync.SyncOrders(Imported, Failed);
    end;
}
