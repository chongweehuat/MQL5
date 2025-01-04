//+------------------------------------------------------------------+
//|                          TrendPulseTrader.mq5                    |
//|          Trend-Following with Pullback Entries                   |
//|                                                                  |
//|                  Author: Your Name                               |
//+------------------------------------------------------------------+

#property copyright "Your Name"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>

// Instantiate trading objects
CTrade m_trade;

// Input Parameters
input string Inp_pair = "";                     // Chart pair
input double EquityStep = 10000.0;              // Equity step per lot size
input int MaxTradesPerSession = 2;              // Max trades per session
input double ATR_Period = 14;                   // ATR period
input int EMA_Short_Period = 50;                // Short EMA period
input int EMA_Long_Period = 200;                // Long EMA period
input double Pullback_Percentage = 0.3;         // Pullback percentage
input double SL_Multiplier = 1.5;               // Stop-loss multiplier
input double TP_Multiplier = 3.0;               // Take-profit multiplier
input bool UseTrailingStop = false;             // Enable trailing stop
input double TrailingStopATRMultiplier = 1.0;   // Trailing stop multiplier

// Handles for Indicators
int handleATR, handleEMA_Short, handleEMA_Long;

// Buffers for Indicator Values
double atrBuffer[], emaShortBuffer[], emaLongBuffer[];

int currentTrades = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    if (Inp_pair != "" && Inp_pair != Symbol()) {
        Alert(Inp_pair + " not match " + Symbol());
        return INIT_FAILED;
    }

    handleATR = iATR(Symbol(), PERIOD_H1, (int)ATR_Period);
    handleEMA_Short = iMA(Symbol(), PERIOD_H1, EMA_Short_Period, 0, MODE_EMA, PRICE_CLOSE);
    handleEMA_Long = iMA(Symbol(), PERIOD_H1, EMA_Long_Period, 0, MODE_EMA, PRICE_CLOSE);

    if (handleATR < 0 || handleEMA_Short < 0 || handleEMA_Long < 0) {
        Print("Error creating indicator handles.");
        return INIT_FAILED;
    }

    Print("TrendPulseTrader initialized successfully.");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    IndicatorRelease(handleATR);
    IndicatorRelease(handleEMA_Short);
    IndicatorRelease(handleEMA_Long);
    Print("TrendPulseTrader deinitialized.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    if (currentTrades >= MaxTradesPerSession) {
        return; // Stop trading after reaching the session limit
    }

    if (!CalculateIndicators()) {
        Print("Error calculating indicators.");
        return;
    }

    if (BuyCondition()) {
        ExecuteTrade(ORDER_TYPE_BUY);
    } else if (SellCondition()) {
        ExecuteTrade(ORDER_TYPE_SELL);
    }
}

//+------------------------------------------------------------------+
//| Calculate Indicators                                             |
//+------------------------------------------------------------------+
bool CalculateIndicators() {
    if (CopyBuffer(handleATR, 0, 0, 1, atrBuffer) <= 0) {
        Print("Error retrieving ATR value.");
        return false;
    }
    if (CopyBuffer(handleEMA_Short, 0, 0, 1, emaShortBuffer) <= 0) {
        Print("Error retrieving EMA Short value.");
        return false;
    }
    if (CopyBuffer(handleEMA_Long, 0, 0, 1, emaLongBuffer) <= 0) {
        Print("Error retrieving EMA Long value.");
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Buy Condition                                                    |
//+------------------------------------------------------------------+
bool BuyCondition() {
    double price = iClose(Symbol(), PERIOD_H1, 0);

    return emaShortBuffer[0] > emaLongBuffer[0] &&
           price < emaShortBuffer[0] - Pullback_Percentage * atrBuffer[0];
}

//+------------------------------------------------------------------+
//| Sell Condition                                                   |
//+------------------------------------------------------------------+
bool SellCondition() {
    double price = iClose(Symbol(), PERIOD_H1, 0);

    return emaShortBuffer[0] < emaLongBuffer[0] &&
           price > emaShortBuffer[0] + Pullback_Percentage * atrBuffer[0];
}

//+------------------------------------------------------------------+
//| Execute Trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE type) {
    if (currentTrades >= MaxTradesPerSession) {
        return;
    }

    double lot_size, stop_loss, take_profit, price, atr;

    atr = atrBuffer[0];
    price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(Symbol(), SYMBOL_ASK)
                                     : SymbolInfoDouble(Symbol(), SYMBOL_BID);

    stop_loss = (type == ORDER_TYPE_BUY) ? price - SL_Multiplier * atr
                                         : price + SL_Multiplier * atr;

    take_profit = (type == ORDER_TYPE_BUY) ? price + TP_Multiplier * atr
                                           : price - TP_Multiplier * atr;

    lot_size = CalculateLotSize();
    if (lot_size <= 0) {
        Print("Invalid lot size.");
        return;
    }

    if (m_trade.PositionOpen(Symbol(), type, lot_size, price, stop_loss, take_profit, "TrendPulse Entry")) {
        Print("Trade executed: ", EnumToString(type), " on ", Symbol());
        currentTrades++;
    } else {
        Print("Trade execution failed: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize() {
    double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double lot_size = MathFloor(account_equity / EquityStep) * 0.01; // Lot size based on equity step
    return NormalizeDouble(lot_size, 2);
}
