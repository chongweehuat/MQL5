//+------------------------------------------------------------------+
//|                                              SAInfoCollector.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

// Input Parameters
input string EA_Version   = "2.0"; // EA Version
input string AccountEndpointURL  = "https://sapi.my369.click/AccountInfoCollector.php"; // Account Info Endpoint
input string TradeEndpointURL    = "https://sapi.my369.click/TradeInfoCollector.php";   // Trade Info Endpoint
input int    Timeout      = 5000;  // Timeout for WebRequest in milliseconds
input double AccountChangeThreshold = 0.1; // Percentage threshold for account updates
input bool   debug        = false; // Debug mode

// Globals
CTrade m_trade;
CPositionInfo m_position;

// Account Monitoring Globals
double lastEquity = 0;               // Last equity recorded
datetime lastAccountUpdate = 0;      // Last account update time
string lastAccountStatus = "N/A";    // Last account transmission status

// Trade Monitoring Globals
int totalTradesSent = 0;
int successCount = 0;
int errorCount = 0;

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
    // Update account information if necessary
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double changePercent = lastEquity > 0 ? MathAbs(equity - lastEquity) / lastEquity * 100 : 0;

    if (TimeCurrent() - lastAccountUpdate >= 10 || changePercent >= AccountChangeThreshold)
    {
        lastEquity = equity;
        lastAccountUpdate = TimeCurrent();
        SendAccountInfo();
    }

    // Update trade information
    SendTradeInfo();

    // Update chart status
    UpdateChartStatus();
}

//+------------------------------------------------------------------+
//| Builds the query string for account information                  |
//+------------------------------------------------------------------+
string BuildAccountInfo()
{
    string postData = 
        "ea_version=" + EA_Version + "&" +
        "account_number=" + (string)AccountInfoInteger(ACCOUNT_LOGIN) + "&" +
        "account_name=" + AccountInfoString(ACCOUNT_NAME) + "&" +
        "broker_name=" + AccountInfoString(ACCOUNT_COMPANY) + "&" +
        "leverage=" + IntegerToString((int)AccountInfoInteger(ACCOUNT_LEVERAGE)) + "&" +
        "balance=" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "&" +
        "equity=" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "&" +
        "free_margin=" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2);
    return postData;
}

//+------------------------------------------------------------------+
//| Sends account information to the endpoint                        |
//+------------------------------------------------------------------+
void SendAccountInfo()
{
    string postData = BuildAccountInfo();
    string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
    char data[], response[];
    string resultHeaders;

    StringToCharArray(postData, data);
    int responseCode = WebRequest("POST", AccountEndpointURL, headers, Timeout, data, response, resultHeaders);

    if (responseCode == -1)
    {
        lastAccountStatus = "Failed: Error " + IntegerToString(GetLastError());
    }
    else
    {
        string responseText = CharArrayToString(response);
        if (StringFind(responseText, "\"status\":\"success\"") >= 0)
            lastAccountStatus = "Success";
        else
            lastAccountStatus = "Failed: Unexpected response";
    }
}

//+------------------------------------------------------------------+
//| Builds the query string for trade information                    |
//+------------------------------------------------------------------+
string BuildTradeInfo()
{
    string postData =
        "ea_version=" + EA_Version + "&" +
        "account_id=" + (string)AccountInfoInteger(ACCOUNT_LOGIN) + "&" +
        "ticket=" + (string)m_position.Ticket() + "&" +
        "pair=" + m_position.Symbol() + "&" +
        "order_type=" + m_position.TypeDescription() + "&" +
        "volume=" + DoubleToString(m_position.Volume(), 2) + "&" +
        "open_price=" + DoubleToString(m_position.PriceOpen(), 5) + "&" +
        "profit=" + DoubleToString(m_position.Profit(), 2) + "&" +
        "open_time=" + TimeToString(m_position.Time(), TIME_DATE | TIME_MINUTES) + "&" +
        "bid_price=" + DoubleToString(SymbolInfoDouble(m_position.Symbol(), SYMBOL_BID), 5) + "&" +
        "ask_price=" + DoubleToString(SymbolInfoDouble(m_position.Symbol(), SYMBOL_ASK), 5) + "&" +
        "magic_number=" + IntegerToString((int)m_position.Magic());
    return postData;
}

//+------------------------------------------------------------------+
//| Sends trade information one by one                               |
//+------------------------------------------------------------------+
void SendTradeInfo()
{
    int totalTrades = PositionsTotal();
    for (int i = 0; i < totalTrades; i++)
    {
        if (m_position.SelectByIndex(i))
        {
            string postData = BuildTradeInfo();
            string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
            char data[], response[];
            string resultHeaders;

            StringToCharArray(postData, data);
            int responseCode = WebRequest("POST", TradeEndpointURL, headers, Timeout, data, response, resultHeaders);
            totalTradesSent++;

            if (responseCode == -1)
            {
                errorCount++;
                Print("Failed to send trade info. Error: " + IntegerToString(GetLastError()));
                return;
            }

            string responseText = CharArrayToString(response);
            if (responseCode == 200 && StringFind(responseText, "\"status\":\"success\"") >= 0)
                successCount++;
            else
                errorCount++;
        }
    }
}

//+------------------------------------------------------------------+
//| Updates chart monitoring status                                  |
//+------------------------------------------------------------------+
void UpdateChartStatus()
{
    string status = 
        "Unified Info Collector - Monitoring\n" +
        "EA Version: " + EA_Version + "\n" +
        "Account Info Endpoint: " + AccountEndpointURL + "\n" +
        "Trade Info Endpoint: " + TradeEndpointURL + "\n" +
        "Last Equity: " + DoubleToString(lastEquity, 2) + "\n" +
        "Last Account Update: " + TimeToString(lastAccountUpdate, TIME_DATE | TIME_MINUTES) + "\n" +
        "Last Account Status: " + lastAccountStatus + "\n" +
        "Total Trades Sent: " + IntegerToString(totalTradesSent) + "\n" +
        "Successful Trades: " + IntegerToString(successCount) + "\n" +
        "Failed Trades: " + IntegerToString(errorCount);
    Comment(status);
}

//+------------------------------------------------------------------+
//| Clears chart monitoring status                                   |
//+------------------------------------------------------------------+
void ClearChartStatus()
{
    Comment("");
}
