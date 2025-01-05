//+------------------------------------------------------------------+ 
//|                                             TradeInfoCollector   |
//|                                  Copyright 2025, Your Company    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://sapi.my369.click"
#property version   "1.3"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

// Input Parameters
input string EA_Version = "1.3";                 // EA Version
input string EndpointURL = "https://sapi.my369.click/TradeInfoCollector.php"; // Endpoint URL
input int Timeout = 500;                         // Timeout for WebRequest

CPositionInfo m_position;                        // Position object

// Statistics for monitoring
int totalSent = 0;
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
    SendTradeInfo();
    UpdateChartStatus();
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
            string postData = BuildTradeInfo(i);
            string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
            char data[], response[];
            string resultHeaders;

            StringToCharArray(postData, data);
            int responseCode = WebRequest("POST", EndpointURL, headers, Timeout, data, response, resultHeaders);

            totalSent++;
            if (responseCode == -1)
            {
                errorCount++;
                string responseBody = CharArrayToString(response);
                Print("Response Code: ", responseCode, ", Response Body: ", responseBody);
                return;
            }
            else
            {
                string responseText = CharArrayToString(response);
                if (StringFind(responseText, "\"status\":\"success\"") >= 0)
                    successCount++;
                else
                    errorCount++;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Builds the query string for trade information                    |
//+------------------------------------------------------------------+
string BuildTradeInfo(int index)
{
    string symbol = m_position.Symbol();
    string orderType = m_position.TypeDescription();
    double volume = m_position.Volume();
    double profit = m_position.Profit();
    double openPrice = m_position.PriceOpen();
    double bidPrice = SymbolInfoDouble(symbol, SYMBOL_BID); // Current bid price
    double askPrice = SymbolInfoDouble(symbol, SYMBOL_ASK); // Current ask price
    datetime openTime = m_position.Time();
    long magicNumber = m_position.Magic();

    string postData = "ea_version=" + EA_Version + "&";
    postData += "account_id=" + (string)AccountInfoInteger(ACCOUNT_LOGIN) + "&";
    postData += "ticket=" + (string)m_position.Ticket() + "&";
    postData += "pair=" + symbol + "&";
    postData += "order_type=" + orderType + "&";
    postData += "volume=" + DoubleToString(volume, 2) + "&";
    postData += "open_price=" + DoubleToString(openPrice, 5) + "&";
    postData += "profit=" + DoubleToString(profit, 2) + "&";
    postData += "open_time=" + TimeToString(openTime, TIME_DATE | TIME_MINUTES) + "&";
    postData += "bid_price=" + DoubleToString(bidPrice, 5) + "&";
    postData += "ask_price=" + DoubleToString(askPrice, 5) + "&";
    postData += "magic_number=" + IntegerToString((int)magicNumber);

    return postData;
}

//+------------------------------------------------------------------+
//| Update chart with monitoring statistics                          |
//+------------------------------------------------------------------+
void UpdateChartStatus()
{
    string status = 
        "Trade Info Collector - Monitoring\n" +
        "EA Version: " + EA_Version + "\n" +
        "Endpoint: " + EndpointURL + "\n" +
        "Total Trades Sent: " + IntegerToString(totalSent) + "\n" +
        "Successful: " + IntegerToString(successCount) + "\n" +
        "Errors: " + IntegerToString(errorCount);

    Comment(status);
}

//+------------------------------------------------------------------+
//| Clear chart monitoring status                                    |
//+------------------------------------------------------------------+
void ClearChartStatus()
{
    Comment("");
}
