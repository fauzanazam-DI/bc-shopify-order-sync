/// <summary>
/// Thin client for the Shopify GraphQL Admin API.
/// Retries on HTTP 429 and on GraphQL THROTTLED errors with exponential back-off,
/// and turns every other failure into a readable error for the sync log.
/// </summary>
codeunit 50100 "FSO Shopify API Client"
{
    Access = Internal;

    var
        Setup: Record "FSO Shopify Setup";
        SetupLoaded: Boolean;
        RequestFailedErr: Label 'Could not reach Shopify: %1', Comment = '%1 = error text';
        HttpStatusErr: Label 'Shopify returned HTTP %1 %2: %3', Comment = '%1 = status code, %2 = reason, %3 = response body';
        GraphQLErr: Label 'Shopify returned an error: %1', Comment = '%1 = error message';
        ThrottledErr: Label 'Shopify kept rate-limiting the request after %1 retries. Try again later or lower Orders per Request.', Comment = '%1 = number of retries';
        UnexpectedResponseErr: Label 'Unexpected response from Shopify: %1 is missing.', Comment = '%1 = JSON path';
        ShopQueryTxt: Label '{ shop { name } }', Locked = true;
        OrdersQueryTxt: Label 'query($first:Int!,$after:String,$query:String){orders(first:$first,after:$after,query:$query,sortKey:CREATED_AT){pageInfo{hasNextPage endCursor}edges{node{id name email createdAt currencyCode customer{firstName lastName email}shippingAddress{firstName lastName address1 address2 city zip countryCodeV2}lineItems(first:100){edges{node{sku name quantity originalUnitPriceSet{shopMoney{amount}}}}}}}}}', Locked = true;

    procedure GetShopName(): Text
    var
        Response: JsonObject;
        Variables: JsonObject;
        Token: JsonToken;
    begin
        Response := SendGraphQL(ShopQueryTxt, Variables);
        if not Response.SelectToken('data.shop.name', Token) then
            Error(UnexpectedResponseErr, 'data.shop.name');
        exit(Token.AsValue().AsText());
    end;

    procedure FetchOrdersPage(CreatedAfter: DateTime; AfterCursor: Text; var OrderEdges: JsonArray; var HasNextPage: Boolean; var EndCursor: Text)
    var
        Response: JsonObject;
        Variables: JsonObject;
        Token: JsonToken;
        NullValue: JsonValue;
    begin
        LoadSetup();
        NullValue.SetValueToNull();

        Variables.Add('first', Setup."Page Size");
        if AfterCursor = '' then
            Variables.Add('after', NullValue)
        else
            Variables.Add('after', AfterCursor);
        if CreatedAfter = 0DT then
            Variables.Add('query', NullValue)
        else
            Variables.Add('query', 'created_at:>=''' + Format(CreatedAfter, 0, 9) + '''');

        Response := SendGraphQL(OrdersQueryTxt, Variables);

        if not Response.SelectToken('data.orders.edges', Token) then
            Error(UnexpectedResponseErr, 'data.orders.edges');
        OrderEdges := Token.AsArray();

        HasNextPage := false;
        EndCursor := '';
        if Response.SelectToken('data.orders.pageInfo.hasNextPage', Token) then
            HasNextPage := Token.AsValue().AsBoolean();
        if Response.SelectToken('data.orders.pageInfo.endCursor', Token) then
            if not Token.AsValue().IsNull() then
                EndCursor := Token.AsValue().AsText();
    end;

    local procedure SendGraphQL(Query: Text; Variables: JsonObject) Result: JsonObject
    var
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Body: JsonObject;
        BodyText: Text;
        ResponseText: Text;
        Attempt: Integer;
        Done: Boolean;
    begin
        LoadSetup();
        Body.Add('query', Query);
        Body.Add('variables', Variables);
        Body.WriteTo(BodyText);
        Client.Timeout(60000);

        Attempt := 0;
        while not Done do begin
            Attempt += 1;
            BuildRequest(Request, BodyText);

            if not Client.Send(Request, Response) then
                Error(RequestFailedErr, GetLastErrorText());
            Response.Content().ReadAs(ResponseText);

            if Response.HttpStatusCode() = 429 then
                WaitBeforeRetry(Attempt, GetRetryAfterMs(Response))
            else begin
                if not Response.IsSuccessStatusCode() then
                    Error(HttpStatusErr, Response.HttpStatusCode(), Response.ReasonPhrase(), CopyStr(ResponseText, 1, 500));

                Clear(Result);
                Result.ReadFrom(ResponseText);
                if IsThrottled(Result) then
                    WaitBeforeRetry(Attempt, 0)
                else begin
                    ThrowIfGraphQLError(Result);
                    Done := true;
                end;
            end;
        end;
    end;

    local procedure BuildRequest(var Request: HttpRequestMessage; BodyText: Text)
    var
        Content: HttpContent;
        ContentHeaders: HttpHeaders;
        RequestHeaders: HttpHeaders;
    begin
        Clear(Request);
        Content.WriteFrom(BodyText);
        Content.GetHeaders(ContentHeaders);
        if ContentHeaders.Contains('Content-Type') then
            ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');

        Request.Method('POST');
        Request.SetRequestUri(Setup.GetGraphQLUrl());
        Request.Content(Content);
        Request.GetHeaders(RequestHeaders);
        RequestHeaders.Add('X-Shopify-Access-Token', Setup.GetAccessToken());
        RequestHeaders.Add('Accept', 'application/json');
    end;

    local procedure WaitBeforeRetry(Attempt: Integer; SuggestedDelayMs: Integer)
    var
        DelayMs: Integer;
        i: Integer;
    begin
        if Attempt > Setup."Max Retries" then
            Error(ThrottledErr, Setup."Max Retries");

        // Exponential back-off: 1s, 2s, 4s, 8s ... capped at 30s, unless Shopify told us how long to wait.
        DelayMs := SuggestedDelayMs;
        if DelayMs <= 0 then begin
            DelayMs := 1000;
            for i := 2 to Attempt do
                DelayMs := DelayMs * 2;
        end;
        if DelayMs > 30000 then
            DelayMs := 30000;
        Sleep(DelayMs);
    end;

    local procedure GetRetryAfterMs(Response: HttpResponseMessage): Integer
    var
        Values: List of [Text];
        Seconds: Decimal;
    begin
        if not Response.Headers().Contains('Retry-After') then
            exit(0);
        Response.Headers().GetValues('Retry-After', Values);
        if Values.Count() = 0 then
            exit(0);
        if not Evaluate(Seconds, Values.Get(1), 9) then
            exit(0);
        exit(Round(Seconds * 1000, 1) div 1);
    end;

    local procedure IsThrottled(Result: JsonObject): Boolean
    var
        Token: JsonToken;
    begin
        if not Result.SelectToken('errors[0].extensions.code', Token) then
            exit(false);
        exit(Token.AsValue().AsText() = 'THROTTLED');
    end;

    local procedure ThrowIfGraphQLError(Result: JsonObject)
    var
        Token: JsonToken;
    begin
        if Result.SelectToken('errors[0].message', Token) then
            Error(GraphQLErr, Token.AsValue().AsText());
    end;

    local procedure LoadSetup()
    begin
        if SetupLoaded then
            exit;
        Setup.GetSetup();
        SetupLoaded := true;
    end;
}
