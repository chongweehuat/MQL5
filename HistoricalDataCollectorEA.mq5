//+------------------------------------------------------------------+
//|                                               HistoricalDataCollectorEA.mq5 |
//|                                      © 2024 Your Company Name                |
//+------------------------------------------------------------------+
#property copyright "© 2024 Your Company Name"
#property version   "1.03"

// Input parameters
input bool DebugMode = false;               // Enable debugging mode
input string SinglePair = "";               // Specify a single pair for testing (leave blank for all pairs)
input datetime StartDate = D'2024.01.01 00:00'; // Start date for historical data collection
input int DataCount = 1000;                 // Number of bars to collect

// Global variables
string EndpointURL = "https://api.my369.click/update";
string AllPairs[] = {                       // List of monitored pairs
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
    if (DebugMode) Log("HistoricalDataCollectorEA initialized. Starting historical data collection...");

    // Determine whether to run for a single pair or all pairs
    if (StringLen(SinglePair) > 0) { // Check if SinglePair is not empty
        CollectHistoricalData(SinglePair);
    } else {
        for (int i = 0; i < ArraySize(AllPairs); i++) {
            CollectHistoricalData(AllPairs[i]);
        }
    }

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Comment(""); // Clear chart comments
    if (DebugMode) Log("HistoricalDataCollectorEA deinitialized. Reason: " + IntegerToString(reason));
}

//+------------------------------------------------------------------+
//| Collect historical data for a single symbol                     |
//+------------------------------------------------------------------+
void CollectHistoricalData(string symbol) {
    MqlRates rates[];
    ArraySetAsSeries(rates, true);

    // Fetch historical rates from the specified start date
    int count = CopyRates(symbol, PERIOD_M1, StartDate, DataCount, rates);

    if (count > 0) {
        for (int i = 0; i < ArraySize(rates); i++) {
            SendData(symbol, rates[i].open, rates[i].high, rates[i].low, rates[i].close, rates[i].tick_volume, rates[i].time);
        }
        Log("Collected " + IntegerToString(ArraySize(rates)) + " bars for " + symbol);
    } else {
        Log("Failed to fetch historical data for " + symbol + ". Error: " + IntegerToString(GetLastError()));
    }
}

//+------------------------------------------------------------------+
//| Send data to the server                                          |
//+------------------------------------------------------------------+
void SendData(string symbol, double openPrice, double highPrice, double lowPrice, double closePrice, long tickVolume, datetime time) {
    // Convert tick volume to a string
    string volumeStr = IntegerToString((int)tickVolume); // Explicitly cast to int

    // Construct JSON payload
    string json = "{"
                  "\"symbol\":\"" + symbol + "\","
                  "\"openPrice\":" + DoubleToString(openPrice, 5) + ","
                  "\"highPrice\":" + DoubleToString(highPrice, 5) + ","
                  "\"lowPrice\":" + DoubleToString(lowPrice, 5) + ","
                  "\"closePrice\":" + DoubleToString(closePrice, 5) + ","
                  "\"volume\":" + volumeStr + ","
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
    } else if (ArraySize(result) > 0) {
        if (DebugMode) Log("Server Response: " + CharArrayToString(result));
    } else {
        Log("Empty response received");
    }
}

//+------------------------------------------------------------------+
//| Log helper function                                              |
//+------------------------------------------------------------------+
void Log(string message) {
    Print(TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + " - " + message);
}
