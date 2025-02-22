//+------------------------------------------------------------------+
//|                                                      PushData.mq5|
//|                                      © 2024 Your Company Name     |
//+------------------------------------------------------------------+
#property copyright "© 2024 Your Company Name"
#property version   "1.05"

// Input parameter for DebugMode
input bool DebugMode = false; // Set 'true' to enable debugging, 'false' for production

// Global variables
string EndpointURL = "https://api.my369.click/update";
string Pairs[] = {"GBPJPY", "GBPNZD", "NZDJPY", "EURJPY"}; // Currency pairs to monitor

// Variables to track progress and API response
int TotalPairs = 0;
int ProcessedPairs = 0;
bool IsSending = false;
datetime NextUpdateTime = 0;    // Tracks the next scheduled update time
string LastAPIResponse = "N/A"; // Stores the last response from the API

// Function to send data to the server
void SendData(string symbol, double openPrice, double closePrice, datetime time) {
    // Construct JSON payload
    string json = "{"
                  "\"symbol\":\"" + symbol + "\","
                  "\"openPrice\":" + DoubleToString(openPrice, 5) + ","
                  "\"closePrice\":" + DoubleToString(closePrice, 5) + ","
                  "\"time\":\"" + TimeToString(time, TIME_DATE | TIME_MINUTES | TIME_SECONDS) + "\""
                  "}";

    if (DebugMode) Print("Sending JSON: ", json);

    // Prepare data for POST request
    uchar postData[];
    StringToCharArray(json, postData);

    uchar result[];
    string headers = "Content-Type: application/json\r\n";
    int timeout = 5000; // 5-second timeout

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
        if (DebugMode) Print("WebRequest error: ", GetLastError());
        LastAPIResponse = "Error: " + IntegerToString(GetLastError());
    } else if (ArraySize(result) > 0) {
        LastAPIResponse = CharArrayToString(result);
        if (DebugMode) Print("Server Response: ", LastAPIResponse);

        // Optionally handle server responses in production mode
        if (StringFind(LastAPIResponse, "\"error\"") != -1 && DebugMode) {
            Print("Server returned an error: ", LastAPIResponse);
        }
    } else {
        if (DebugMode) Print("Empty response received");
        LastAPIResponse = "Empty response received";
    }

    // Update processed pairs count
    ProcessedPairs++;
    UpdateChartComment();
}

// Function to collect and send data for all monitored pairs
void CollectAndSendData() {
    TotalPairs = ArraySize(Pairs); // Set the total number of pairs
    ProcessedPairs = 0;           // Reset processed pairs count
    IsSending = true;             // Indicate that sending is in progress
    UpdateChartComment();         // Update chart

    for (int i = 0; i < ArraySize(Pairs); i++) {
        string pair = Pairs[i];
        MqlRates rates[];
        ArraySetAsSeries(rates, true);

        // Fetch the latest bar data
        if (CopyRates(pair, PERIOD_H4, 0, 1, rates) > 0) {
            SendData(pair, rates[0].open, rates[0].close, rates[0].time);
        } else {
            int errorCode = GetLastError();
            if (DebugMode) Print("Failed to fetch rates for ", pair, ": Error ", errorCode);
            ProcessedPairs++;
            UpdateChartComment();
        }
    }

    IsSending = false; // Mark as finished
    UpdateChartComment();
}

// Function to update the chart with current status
void UpdateChartComment() {
    // Calculate time left for the next update
    int timeLeft = (int)(NextUpdateTime - TimeCurrent());
    if (timeLeft < 0) timeLeft = 0; // Prevent negative values

    string statusMessage = IsSending
        ? "Sending data... (" + IntegerToString(ProcessedPairs) + "/" + IntegerToString(TotalPairs) + ")"
        : "EA is idle. Last update completed.";

    Comment(
        "PushData EA Status:\n",
        statusMessage, "\n",
        "Time left for next update: ", timeLeft, " seconds\n",
        "Last API Response: ", LastAPIResponse, "\n",
        "Pairs monitored: ", ArraySize(Pairs), "\n",
        "Endpoint: ", EndpointURL, "\n",
        "Debug mode: ", DebugMode ? "ON" : "OFF"
    );
}

// Expert initialization function
int OnInit() {
    // Immediate data push after activation
    if (DebugMode) Print("PushData EA initialized. Sending data immediately...");
    CollectAndSendData();

    // Schedule the next update
    NextUpdateTime = TimeCurrent() + 60;
    return(INIT_SUCCEEDED);
}

// Expert deinitialization function
void OnDeinit(const int reason) {
    Comment(""); // Clear chart comments
    if (DebugMode) Print("PushData EA deinitialized. Reason: ", reason);
}

// Expert tick function
void OnTick() {
    // Check if it's time to send data
    if (TimeCurrent() >= NextUpdateTime) {
        if (DebugMode) Print("Collecting and sending data...");
        CollectAndSendData();
        NextUpdateTime = TimeCurrent() + 60; // Schedule the next update
    }

    // Update the chart with time left and last API response
    UpdateChartComment();
}
