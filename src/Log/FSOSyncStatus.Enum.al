enum 50100 "FSO Sync Status"
{
    Extensible = true;
    Caption = 'Sync Status';

    value(0; Pending) { Caption = 'Pending'; }
    value(1; Processed) { Caption = 'Processed'; }
    value(2; Error) { Caption = 'Error'; }
    value(3; Skipped) { Caption = 'Skipped'; }
}
