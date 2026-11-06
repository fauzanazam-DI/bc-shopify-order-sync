table 50100 "FSO Shopify Setup"
{
    Caption = 'Shopify Order Sync Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(10; "Shop Domain"; Text[100])
        {
            Caption = 'Shop Domain';

            trigger OnValidate()
            begin
                "Shop Domain" := CopyStr(LowerCase("Shop Domain").Replace('https://', '').Replace('http://', '').TrimEnd('/'), 1, MaxStrLen("Shop Domain"));
            end;
        }
        field(11; "API Version"; Text[10])
        {
            Caption = 'API Version';
            InitValue = '2025-10';
        }
        field(12; Enabled; Boolean)
        {
            Caption = 'Enabled';
        }
        field(20; "Customer Posting Group"; Code[20])
        {
            Caption = 'Customer Posting Group';
            TableRelation = "Customer Posting Group";
        }
        field(21; "Gen. Bus. Posting Group"; Code[20])
        {
            Caption = 'Gen. Bus. Posting Group';
            TableRelation = "Gen. Business Posting Group";
        }
        field(22; "VAT Bus. Posting Group"; Code[20])
        {
            Caption = 'VAT Bus. Posting Group';
            TableRelation = "VAT Business Posting Group";
        }
        field(23; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
            TableRelation = Location;
        }
        field(24; "Prices Including VAT"; Boolean)
        {
            Caption = 'Prices Including VAT';
        }
        field(30; "Orders Created After"; DateTime)
        {
            Caption = 'Import Orders Created After';
        }
        field(31; "Last Sync At"; DateTime)
        {
            Caption = 'Last Sync At';
            Editable = false;
        }
        field(32; "Page Size"; Integer)
        {
            Caption = 'Orders per Request';
            InitValue = 50;
            MinValue = 1;
            MaxValue = 250;
        }
        field(33; "Max Retries"; Integer)
        {
            Caption = 'Max Retries';
            InitValue = 5;
            MinValue = 0;
            MaxValue = 10;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    var
        AccessTokenKeyTok: Label 'FSO-Shopify-AccessToken', Locked = true;
        GraphQLUrlTok: Label 'https://%1/admin/api/%2/graphql.json', Locked = true;
        NoAccessTokenErr: Label 'No Shopify access token is set. Enter it on the Shopify Order Sync Setup page.';

    procedure GetSetup()
    begin
        if not Get() then begin
            Init();
            Insert();
        end;
    end;

    [NonDebuggable]
    procedure SetAccessToken(NewToken: Text)
    begin
        if NewToken = '' then begin
            if IsolatedStorage.Contains(AccessTokenKeyTok, DataScope::Company) then
                IsolatedStorage.Delete(AccessTokenKeyTok, DataScope::Company);
            exit;
        end;
        if EncryptionEnabled() then
            IsolatedStorage.SetEncrypted(AccessTokenKeyTok, NewToken, DataScope::Company)
        else
            IsolatedStorage.Set(AccessTokenKeyTok, NewToken, DataScope::Company);
    end;

    [NonDebuggable]
    procedure GetAccessToken() AccessToken: SecretText
    var
        TokenText: Text;
    begin
        if not IsolatedStorage.Get(AccessTokenKeyTok, DataScope::Company, TokenText) then
            Error(NoAccessTokenErr);
        AccessToken := TokenText;
    end;

    procedure HasAccessToken(): Boolean
    begin
        exit(IsolatedStorage.Contains(AccessTokenKeyTok, DataScope::Company));
    end;

    procedure GetGraphQLUrl(): Text
    begin
        TestField("Shop Domain");
        TestField("API Version");
        exit(StrSubstNo(GraphQLUrlTok, "Shop Domain", "API Version"));
    end;
}
