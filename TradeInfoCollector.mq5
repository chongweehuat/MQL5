//+------------------------------------------------------------------+
//|                                                      TradeInfoCollector.mq5 |
//|                        Copyright 2025, Your Company                       |
//|                        https://sapi.my369.click                          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company"
#property link      "https://sapi.my369.click"
#property version   "1.4"

#include <Trade\Trade.mqh>

// Input Parameters
input string EA_Version   = "1.4"; // EA Version
input string EndpointURL  = "https://sapi.my369.click/TradeInfoCollector.php"; // Endpoint URL
input int    Timeout      = 5000;  // Timeout for WebRequest in milliseconds
input int    TimeGapSec   = 3;    // Minimum time gap between requests in seconds
input bool   debug        = false; // Debug mode

CPositionInfo m_position; // Position object

// Statistics for monitoring
int totalSent    = 0;
int successCount = 0;
int errorCount   = 0;

// Timestamp for the last WebRequest
datetime lastRequestTime = 0;

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
    // Check if sufficient time has passed since the last request
    if (TimeCurrent() - lastRequestTime >= TimeGapSec) {
        SendAllTrades();
        lastRequestTime = TimeCurrent(); // Update the last request timestamp
    }
    UpdateChartStatus();
}

//+------------------------------------------------------------------+
//| Sends all open trades in a single WebRequest                     |
//+------------------------------------------------------------------+
void SendAllTrades()
{
    int totalTrades = PositionsTotal();
    if (totalTrades == 0)
    {
        if (debug)
            Print("No open trades to send.");
        return;
    }

    string payload = BuildAllTradesPayload();
    if (StringLen(payload) == 0)
    {
        Print("Failed to build payload.");
        return;
    }

    string headers = "";
    char   data[], response[];
    string resultHeaders;

    StringToCharArray(payload, data);
    ResetLastError();
    int responseCode = WebRequest("POST", EndpointURL, headers, Timeout, data, response, resultHeaders);
    totalSent++;

    if (responseCode == -1)
    {
        // Handle WebRequest error
        int errorCode = GetLastError();
        string errorMsg = "WebRequest failed. Error code: " + IntegerToString(errorCode);
        Print(errorMsg);
        errorCount++;
        return;
    }

    string responseText = CharArrayToString(response);
    if (responseCode == 200)
    {
        successCount++;
        if (debug){
            Print("All trades sent successfully.");
        }
    }
    else
    {
        errorCount++;
        Print("Failed to send trades. Response code: ", responseCode, ", Response: ", responseText);
    }
}

//+------------------------------------------------------------------+
//| Builds the POST payload for all open trades                      |
//+------------------------------------------------------------------+
string BuildAllTradesPayload()
{
    int totalTrades = PositionsTotal();
    if (totalTrades == 0)
        return "";

    // Start payload with consistent key-value pairs for metadata
    string payload = "ea_version=" + EA_Version + "&";
    payload += "account_id=" + IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN)) + "&";

    // Add each trade
    for (int i = 0; i < totalTrades; i++)
    {
        if (m_position.SelectByIndex(i))
        {
            string tradeData = "trades[]=";
            tradeData += "ticket=" + (string)m_position.Ticket() + "|";
            tradeData += "pair=" + m_position.Symbol() + "|";
            tradeData += "order_type=" + m_position.TypeDescription() + "|";
            tradeData += "volume=" + DoubleToString(m_position.Volume(), 2) + "|";
            tradeData += "profit=" + DoubleToString(m_position.Profit(), 2) + "|";
            tradeData += "open_price=" + DoubleToString(m_position.PriceOpen(), 5) + "|";
            tradeData += "bid_price=" + DoubleToString(SymbolInfoDouble(m_position.Symbol(), SYMBOL_BID), 5) + "|";
            tradeData += "ask_price=" + DoubleToString(SymbolInfoDouble(m_position.Symbol(), SYMBOL_ASK), 5) + "|";
            tradeData += "open_time=" + TimeToString(m_position.Time(), TIME_DATE | TIME_MINUTES) + "|";
            tradeData += "magic_number=" + IntegerToString((int)m_position.Magic());
            payload += tradeData + "&";
        }
    }

    return payload;
}

//+------------------------------------------------------------------+
//| Update chart with monitoring statistics                          |
//+------------------------------------------------------------------+
void UpdateChartStatus()
{
    string status = "Trade Info Collector - Monitoring\n";
    status += "EA Version: " + EA_Version + "\n";
    status += "Endpoint: " + EndpointURL + "\n";
    status += "Total Trades Sent: " + IntegerToString(totalSent) + "\n";
    status += "Successful: " + IntegerToString(successCount) + "\n";
    status += "Errors: " + IntegerToString(errorCount);
    Comment(status);
}

//+------------------------------------------------------------------+
//| Clear chart monitoring status                                    |
//+------------------------------------------------------------------+
void ClearChartStatus()
{
    Comment("");
}

//+------------------------------------------------------------------+
