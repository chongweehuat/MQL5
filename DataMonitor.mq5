//+------------------------------------------------------------------+
//|                                                      DataMonitorEA.mq5 |
//|                                      © 2024 Your Company Name         |
//+------------------------------------------------------------------+
#property copyright "© 2024 Your Company Name"
#property version   "1.01"

// Input parameters
input bool DebugMode = false;        // Enable debugging mode
input int MaxBarsToMonitor = 1000;  // Maximum bars for historical data (only used in historical mode)
input bool EnableHistoricalMode = false; // Enable historical data collection mode
input int UpdateInterval = 60;      // Interval in seconds for data updates

// Global variables
string EndpointURL = "https://api.my369.click/update";
datetime LastSentTime[];            // Last sent times for each symbol
string LastAPIResponse = "N/A";     // Last API response
bool IsSending = false;             // Indicates if data is being sent
string Pairs[] = {                  // List of all 28 currency pairs
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
    if (DebugMode) Log("EA initialized. Starting data collection...");

    // Initialize LastSentTime array
    ArrayResize(LastSentTime, ArraySize(Pairs));

    // If historical mode is enabled, collect historical data first
    if (EnableHistoricalMode) {
        CollectHistoricalData();
    } else {
        EventSetTimer(UpdateInterval); // Set periodic updates
    }

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    EventKillTimer(); // Stop periodic updates
    Comment(""); // Clear chart comments
    if (DebugMode) Log("EA deinitialized. Reason: " + IntegerToString(reason));
}

//+------------------------------------------------------------------+
//| Timer function for periodic updates                              |
//+------------------------------------------------------------------+
void OnTimer() {
    for (int i = 0; i < ArraySize(Pairs); i++) {
        CollectAndSendLatestData(Pairs[i], i);
    }

    // Update monitoring information
    UpdateChartComment();
}

//+------------------------------------------------------------------+
//| Collect and send the latest M1 data for a symbol                 |
//+------------------------------------------------------------------+
void CollectAndSendLatestData(string symbol, int index) {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);

    if (CopyRates(symbol, PERIOD_M1, 0, 1, rates) > 0) {
        if (rates[0].time > LastSentTime[index]) { // Ensure new data
            SendData(symbol, rates[0].open, rates[0].high, rates[0].low, rates[0].close, rates[0].time);
            LastSentTime[index] = rates[0].time; // Update last sent time
        }
    } else {
        Log("Failed to fetch latest M1 data for " + symbol + ". Error: " + IntegerToString(GetLastError()));
    }
}

//+------------------------------------------------------------------+
//| Collect historical data for all symbols                          |
//+------------------------------------------------------------------+
void CollectHistoricalData() {
    for (int i = 0; i < ArraySize(Pairs); i++) {
        MqlRates rates[];
        ArraySetAsSeries(rates, true);

        if (CopyRates(Pairs[i], PERIOD_M1, 0, MaxBarsToMonitor, rates) > 0) {
            for (int j = 0; j < ArraySize(rates); j++) {
                SendData(Pairs[i], rates[j].open, rates[j].high, rates[j].low, rates[j].close, rates[j].time);
            }
        } else {
            Log("Failed to fetch historical data for " + Pairs[i] + ". Error: " + IntegerToString(GetLastError()));
        }
    }
}

//+------------------------------------------------------------------+
//| Send data to the server                                          |
//+------------------------------------------------------------------+
void SendData(string symbol, double openPrice, double highPrice, double lowPrice, double closePrice, datetime time) {
    // Construct JSON payload
    string json = "{"
                  "\"symbol\":\"" + symbol + "\","
                  "\"openPrice\":" + DoubleToString(openPrice, 5) + ","
                  "\"highPrice\":" + DoubleToString(highPrice, 5) + ","
                  "\"lowPrice\":" + DoubleToString(lowPrice, 5) + ","
                  "\"closePrice\":" + DoubleToString(closePrice, 5) + ","
                  "\"time\":\"" + TimeToString(time, TIME_DATE | TIME_MINUTES | TIME_SECONDS) + "\""
                  "}";

    if (DebugMode) Log("Sending JSON: " + json);

    uchar postData[];
    StringToCharArray(json, postData);

    uchar result[];
    string headers = "Content-Type: application/json\r\n";
    int timeout = 5000; // Timeout of 5 seconds

    // Perform WebRequest
    int response = WebRequest(
        "POST",
        EndpointURL,
        headers,
        NULL,
        timeout,
        postData,
        0,
        result,
        headers
    );

    if (response == -1) {
        Log("WebRequest error: " + IntegerToString(GetLastError()));
        LastAPIResponse = "Error: " + IntegerToString(GetLastError());
    } else if (ArraySize(result) > 0) {
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
    string statusMessage = IsSending
        ? "Sending data..."
        : "Idle. Waiting for new data...";

    Comment(
        "DataMonitor EA Status:\n",
        "Status: ", statusMessage, "\n",
        "Last Sent Times: ", TimeToString(LastSentTime[0], TIME_DATE | TIME_MINUTES | TIME_SECONDS), " (Example)\n",
        "Last API Response: ", LastAPIResponse, "\n",
        "Endpoint: ", EndpointURL, "\n",
        "Debug Mode: ", DebugMode ? "ON" : "OFF"
    );
}

//+------------------------------------------------------------------+
//| Log helper function                                              |
//+------------------------------------------------------------------+
void Log(string message) {
    Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + " - " + message);
}
