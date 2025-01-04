//+------------------------------------------------------------------+
//|                                             AccountInfoCollector |
//|                                  Copyright 2025, Your Company    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://sapi.my369.click"
#property version   "1.02"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

// Input Parameters
input string EA_Version = "1.02";              // EA Version
input string EndpointURL = "https://sapi.my369.click/AccountInfoCollector.php"; // Endpoint URL
input int Timeout = 500;                       // Timeout for WebRequest
input double Inp_changes = 0.1;                // Trigger change percentage

// Globals
CTrade m_trade;                                // Trade object
double lastEquity = 0;                         // Last equity recorded
datetime lastUpdate = 0;                       // Last update time
string lastStatus = "N/A";                     // Last transmission status

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    UpdateChartStatus();
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ClearChartStatus();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double changePercent = lastEquity > 0 ? MathAbs(equity - lastEquity) / lastEquity * 100 : 0;

    if (TimeCurrent() - lastUpdate >= 10 || changePercent >= Inp_changes)
    {
        lastEquity = equity;
        lastUpdate = TimeCurrent();
        SendAccountInfo();
        UpdateChartStatus();
    }
}

//+------------------------------------------------------------------+
//| Builds the query string for the account information              |
//+------------------------------------------------------------------+
string BuildAccountInfo()
{
    string accountNumber = IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN));
    string accountName = AccountInfoString(ACCOUNT_NAME);
    string brokerName = AccountInfoString(ACCOUNT_COMPANY);
    long leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

    string postData = "ea_version=" + EA_Version + "&";
    postData += "account_number=" + accountNumber + "&";
    postData += "account_name=" + accountName + "&";
    postData += "broker_name=" + brokerName + "&";
    postData += "leverage=" + IntegerToString(leverage) + "&";
    postData += "balance=" + DoubleToString(balance, 2) + "&";
    postData += "equity=" + DoubleToString(equity, 2) + "&";
    postData += "free_margin=" + DoubleToString(freeMargin, 2);

    return postData;
}

//+------------------------------------------------------------------+
//| Sends the account information to the endpoint                   |
//+------------------------------------------------------------------+
void SendAccountInfo()
{
    string postData = BuildAccountInfo();
    string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
    char data[], response[];
    string resultHeaders;

    StringToCharArray(postData, data);
    int responseCode = WebRequest("POST", EndpointURL, headers, Timeout, data, response, resultHeaders);

    if (responseCode == -1)
    {
        lastStatus = "Failed: Error " + IntegerToString(GetLastError());
    }
    else
    {
        string responseText = CharArrayToString(response);
        if (StringFind(responseText, "\"status\":\"success\"") >= 0)
            lastStatus = "Success";
        else
            lastStatus = "Failed: Unexpected response";
    }
}

//+------------------------------------------------------------------+
//| Updates chart monitoring status                                  |
//+------------------------------------------------------------------+
void UpdateChartStatus()
{
    string status =
        "Account Info Collector - Monitoring\n" +
        "EA Version: " + EA_Version + "\n" +
        "Endpoint: " + EndpointURL + "\n" +
        "Last Equity: " + DoubleToString(lastEquity, 2) + "\n" +
        "Last Update: " + TimeToString(lastUpdate, TIME_DATE | TIME_MINUTES) + "\n" +
        "Last Status: " + lastStatus;

    Comment(status);
}

//+------------------------------------------------------------------+
//| Clears chart monitoring status                                   |
//+------------------------------------------------------------------+
void ClearChartStatus()
{
    Comment("");
}
