//+------------------------------------------------------------------+
//|                                                  RealTimeMonitorEA.mq5 |
//|                                      © 2024 Your Company Name          |
//+------------------------------------------------------------------+
#property copyright "© 2024 Your Company Name"
#property version   "1.04"

// Input parameters
input bool DebugMode = false;        // Enable debugging mode
input int MarketTimeout = 60;        // Timeout in seconds to detect market closure
input int UpdateInterval = 60;       // Interval in seconds for periodic updates

// Global variables
string EA_Version = "1.04";          // EA version
string EndpointURL = "https://api.my369.click/update";
datetime LastTickTime;               // Last tick time
datetime LastSendTime;               // Last data send time
datetime LastResponseTime;           // Last response time
string LastAPIResponse = "N/A";      // Last API response
bool MarketIsClosed = false;         // Market status
string Pairs[] = {                   // List of monitored pairs
    "EURUSD", "GBPUSD", "AUDUSD", "NZDUSD", "USDJPY", "USDCHF", "USDCAD",
    "EURGBP", "EURAUD", "EURNZD", "EURJPY", "EURCHF", "EURCAD",
    "GBPAUD", "GBPNZD", "GBPJPY", "GBPCHF", "GBPCAD",
    "AUDNZD", "AUDJPY", "AUDCHF", "AUDCAD",
    "NZDJPY", "NZDCHF", "NZDCAD",
    "CADJPY", "CADCHF", "CHFJPY"
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    if (DebugMode) Log("RealTimeMonitorEA initialized. Starting real-time monitoring...");

    LastTickTime = TimeCurrent(); // Initialize last tick time
    EventSetTimer(UpdateInterval); // Set periodic updates

    UpdateChartComment();         // Show monitoring info immediately
    DisplayDebugInfo();           // Display debug info on chart
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    EventKillTimer();             // Stop periodic updates
    ObjectDelete(0, "DebugInfo"); // Remove debug info from chart
    Comment("");                  // Clear chart comments
    if (DebugMode) Log("RealTimeMonitorEA deinitialized. Reason: " + IntegerToString(reason));
}

//+------------------------------------------------------------------+
//| OnTick event function                                            |
//+------------------------------------------------------------------+
void OnTick() {
    LastTickTime = TimeCurrent(); // Update last tick time

    // Check if the market was previously marked as closed
    if (MarketIsClosed) {
        MarketIsClosed = false; // Reset market status
        if (DebugMode) Log("Market reopened. Resuming data collection...");
    }

    UpdateChartComment(); // Update monitoring info on chart
}

//+------------------------------------------------------------------+
//| Timer function for periodic updates                              |
//+------------------------------------------------------------------+
void OnTimer() {
    datetime now = TimeCurrent();

    // Detect market closure if no tick has been received for MarketTimeout seconds
    if ((now - LastTickTime) > MarketTimeout) {
        MarketIsClosed = true; // Mark market as closed
        if (DebugMode) Log("No tick received for over " + IntegerToString(MarketTimeout) + " seconds. Market is closed.");
    }

    // Collect and send data only if the market is open
    if (!MarketIsClosed) {
        for (int i = 0; i < ArraySize(Pairs); i++) {
            CollectAndSendLatestData(Pairs[i]);
        }
    }

    UpdateChartComment(); // Update monitoring info on chart
    DisplayDebugInfo();   // Update debug info
}

//+------------------------------------------------------------------+
//| Collect and send the latest M1 data for a symbol                 |
//+------------------------------------------------------------------+
void CollectAndSendLatestData(string symbol) {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);

    if (CopyRates(symbol, PERIOD_M1, 0, 1, rates) > 0) {
        SendData(symbol, rates[0].open, rates[0].high, rates[0].low, rates[0].close, rates[0].tick_volume, rates[0].time);
    } else {
        Log("Failed to fetch latest M1 data for " + symbol + ". Error: " + IntegerToString(GetLastError()));
    }
}

//+------------------------------------------------------------------+
//| Send data to the server                                          |
//+------------------------------------------------------------------+
void SendData(string symbol, double openPrice, double highPrice, double lowPrice, double closePrice, long volume, datetime time) {
    LastSendTime = TimeCurrent(); // Update last send time

    string json = "{"
                  "\"symbol\":\"" + symbol + "\","
                  "\"openPrice\":" + DoubleToString(openPrice, 5) + ","
                  "\"highPrice\":" + DoubleToString(highPrice, 5) + ","
                  "\"lowPrice\":" + DoubleToString(lowPrice, 5) + ","
                  "\"closePrice\":" + DoubleToString(closePrice, 5) + ","
                  "\"volume\":" + IntegerToString((int)volume) + ","
                  "\"time\":\"" + TimeToString(time, TIME_DATE | TIME_MINUTES | TIME_SECONDS) + "\""
                  "}";

    if (DebugMode) Log("Sending JSON: " + json);

    uchar postData[];
    StringToCharArray(json, postData);

    uchar result[];
    string headers = "Content-Type: application/json\r\n";
    int timeout = 5000; // Timeout of 5 seconds

    int response = WebRequest("POST", EndpointURL, headers, NULL, timeout, postData, 0, result, headers);

    if (response == -1) {
        Log("WebRequest error: " + IntegerToString(GetLastError()));
        LastAPIResponse = "Error: " + IntegerToString(GetLastError());
    } else if (ArraySize(result) > 0) {
        LastResponseTime = TimeCurrent(); // Update last response time
        LastAPIResponse = CharArrayToString(result);
        if (DebugMode) Log("Server Response: " + LastAPIResponse);
    } else {
        Log("Empty response received");
        LastAPIResponse = "Empty response received";
    }
}

//+------------------------------------------------------------------+
//| Update chart monitoring information                              |
//+------------------------------------------------------------------+
void UpdateChartComment() {
    Comment(
        "RealTimeMonitor EA Status:\n",
        "EA Version: ", EA_Version, "\n",
        "Last Tick Time: ", TimeToString(LastTickTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS), "\n",
        "Market Status: ", MarketIsClosed ? "CLOSED" : "OPEN", "\n",
        "Last Send Time: ", TimeToString(LastSendTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS), "\n",
        "Last Response Time: ", TimeToString(LastResponseTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS), "\n",
        "Last API Response: ", LastAPIResponse, "\n",
        "Endpoint: ", EndpointURL, "\n",
        "Debug Mode: ", DebugMode ? "ON" : "OFF"
    );
}

//+------------------------------------------------------------------+
//| Display debug info on chart                                      |
//+------------------------------------------------------------------+
void DisplayDebugInfo() {
    string debugText = "EA Version: " + EA_Version + "\n"
                     + "Last Tick Time: " + TimeToString(LastTickTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS) + "\n"
                     + "Market Status: " + (MarketIsClosed ? "CLOSED" : "OPEN") + "\n"
                     + "Last Send Time: " + TimeToString(LastSendTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS) + "\n"
                     + "Last Response Time: " + TimeToString(LastResponseTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS) + "\n"
                     + "Last API Response: " + LastAPIResponse + "\n"
                     + "Debug Mode: " + (DebugMode ? "ON" : "OFF");

    if (!ObjectFind(0, "DebugInfo")) {
        ObjectCreate(0, "DebugInfo", OBJ_LABEL, 0, 0, 0);
    }

    ObjectSetString(0, "DebugInfo", OBJPROP_TEXT, debugText);
    ObjectSetInteger(0, "DebugInfo", OBJPROP_CORNER, 0);
    ObjectSetInteger(0, "DebugInfo", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "DebugInfo", OBJPROP_YDISTANCE, 10);
    ObjectSetInteger(0, "DebugInfo", OBJPROP_COLOR, clrWhite);
}

//+------------------------------------------------------------------+
//| Log helper function                                              |
//+------------------------------------------------------------------+
void Log(string message) {
    Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + " - " + message);
}
