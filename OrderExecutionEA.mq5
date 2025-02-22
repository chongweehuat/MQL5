//+------------------------------------------------------------------+
//|                                                OrderExecutionEA.mq5 |
//|                                             © 2024 Your Company Name |
//+------------------------------------------------------------------+
#property copyright "© 2024 Your Company Name"
#property version   "1.4"

input string EndpointURL = "https://trading.my369.click/api/submit-account.php"; // Server URL
input int Timeout = 5000; // Timeout for WebRequest (milliseconds)
input bool DebugMode = false; // Disable debug mode for production

string EA_Version = "1.4";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    SubmitAccountInfo();
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Submits account info to the server                               |
//+------------------------------------------------------------------+
void SubmitAccountInfo() {
    string postData = BuildAccountInfo();
    if (StringLen(postData) == 0) {
        Print("Failed to build post data. Exiting...");
        return;
    }

    string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
    char response[];
    string resultHeaders;
    
    //int  WebRequest( 
    //const string      method,           // HTTP method 
    //const string      url,              // URL 
    //const string      headers,          // headers  
    //int               timeout,          // timeout 
    //const char        &data[],          // the array of the HTTP message body 
    //char              &result[],        // an array containing server response data 
    //string            &result_headers   // headers of server response 
    //);
    char data[];
    StringToCharArray(postData, data);
    int responseCode = WebRequest("POST", EndpointURL, headers,  Timeout, data,  response, resultHeaders);
    
    if (responseCode == -1) {
        Print("WebRequest error. Code: ", GetLastError(), " Description: ", ErrorDescription(GetLastError()));
        return;
    }

    string responseBody = CharArrayToString(response);
    Print("Response Code: ", responseCode, ", Response Body: ", responseBody);
}

//+------------------------------------------------------------------+
//| Builds account information as a query string                    |
//+------------------------------------------------------------------+
string BuildAccountInfo() {
    string accountNumber = IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN)); 
    string accountName = AccountInfoString(ACCOUNT_NAME);
    string brokerName = AccountInfoString(ACCOUNT_COMPANY);
    long leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);

    string postData = "ea_version=" + EA_Version + "&";
    postData += "account_number=" + accountNumber + "&";
    postData += "account_name=" + accountName + "&";
    postData += "broker_name=" + brokerName + "&";
    postData += "leverage=" + IntegerToString(leverage) + "&";
    postData += "balance=" + DoubleToString(balance, 2);

    return postData;
}

//+------------------------------------------------------------------+
//| Helper: Error Description                                        |
//+------------------------------------------------------------------+
string ErrorDescription(int errorCode) {
    switch (errorCode) {
        case 4010: return "Invalid URL";
        case 4011: return "Request Timeout";
        case 4012: return "Invalid Response";
        default: return "Unknown Error";
    }
}
