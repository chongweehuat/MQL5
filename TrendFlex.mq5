//+------------------------------------------------------------------+
//|                                                  TrendFlex.mq5   |
//|                    Copyright © 2023, [Your Name/Company]          |
//|                                         [Your Website/Contact]   |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2023, [Your Name/Company]"
#property link      "[Your Website/Contact]"
#property version   "1.00"
#property strict

// ---- Input parameters
input double RiskPercent = 1.0;       // Risk per trade (%)
input int    HTF_EMA1_Period = 50;    // Higher Timeframe EMA 1
input int    HTF_EMA2_Period = 200;   // Higher Timeframe EMA 2
input int    HTF_Stoch_K = 14;
input int    HTF_Stoch_D = 3;
input int    HTF_Stoch_Slowing = 3;
input int    LTF_EMA_Period = 50;    // Lower Timeframe EMA
input int    LTF_ATR_Period = 14;    // Lower Timeframe ATR
input int    LTF_Stoch_K = 5;
input int    LTF_Stoch_D = 3;
input int    LTF_Stoch_Slowing = 3;
input double StopLossMultiplier = 1.5;
input double TakeProfitMultiplier = 3.0;
input int    TrailingStopPips = 30; // Trailing stop in pips
input int    TrailingStepPips = 5;  // Trailing step in pips

input int    Slippage = 3;          // Maximum slippage in pips
input int    MagicNumber = 20231106; // Magic number to identify orders

// ---- Global variables
ENUM_TIMEFRAMES HTF = PERIOD_D1; // Higher Timeframe (Daily)
ENUM_TIMEFRAMES LTF = PERIOD_H1;  // Lower Timeframe (1-Hour)

// ---- Include necessary libraries
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

CTrade         m_trade;
CSymbolInfo    m_symbol;
CPositionInfo  m_position;
COrderInfo     m_order;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
  // ---- Set magic number and slippage for trade operations
  m_trade.SetExpertMagicNumber(MagicNumber);
  m_trade.SetDeviationInPoints(Slippage);
  m_trade.SetAsyncMode(false);

  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
  // ---- Any cleanup code you need can go here
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // ---- Check for open positions
    if (PositionsTotal() > 0) {
        CheckForTrailingStop();
        return;
    }

    // ---- Refresh rates
    m_symbol.Name(Symbol());
    m_symbol.RefreshRates();

    // ---- Higher Timeframe Indicators
    double htf_ema1 = iMA(Symbol(), HTF, HTF_EMA1_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
    double htf_ema2 = iMA(Symbol(), HTF, HTF_EMA2_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
    
    // ---- Getting handle for Stochastic
    int htf_stochastic_handle = iStochastic(Symbol(), HTF, HTF_Stoch_K, HTF_Stoch_D, HTF_Stoch_Slowing, MODE_SMA, STOCH_PRICE_LOWHIGH);

    // ---- Arrays for Stochastic values
    double htf_stoch_main[];

    // ---- Copying Stochastic values
    if (CopyBuffer(htf_stochastic_handle, 0, 0, 1, htf_stoch_main) < 0) {
        Print("Error copying Stochastic main buffer: ", GetLastError());
        return;
    }

    // ---- Determine trend direction
    bool uptrend = htf_ema1 > htf_ema2 && htf_stoch_main[0] < 70;
    bool downtrend = htf_ema1 < htf_ema2 && htf_stoch_main[0] > 30;

    // ---- Check for entry signals on the lower timeframe
    if (uptrend) {
        if (CheckLongEntry()) {
            OpenLongOrder();
        }
    } else if (downtrend) {
        if (CheckShortEntry()) {
            OpenShortOrder();
        }
    }
}

//+------------------------------------------------------------------+
//| Check for long entry conditions                                  |
//+------------------------------------------------------------------+
bool CheckLongEntry() {
    double ltf_ema = iMA(Symbol(), LTF, LTF_EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);

    // ---- Getting handle for Stochastic
    int ltf_stochastic_handle = iStochastic(Symbol(), LTF, LTF_Stoch_K, LTF_Stoch_D, LTF_Stoch_Slowing, MODE_SMA, STOCH_PRICE_LOWHIGH);

    // ---- Arrays for Stochastic values
    double ltf_stoch_main[];
    double ltf_stoch_signal[];

    // ---- Copying Stochastic values
    if (CopyBuffer(ltf_stochastic_handle, 0, 0, 1, ltf_stoch_main) < 0 ||
        CopyBuffer(ltf_stochastic_handle, 1, 0, 1, ltf_stoch_signal) < 0) {
        Print("Error copying Stochastic buffers: ", GetLastError());
        return false;
    }

    // ---- Check if the price is below the Lower Timeframe EMA and Stochastic is oversold and turning
    if (m_symbol.Bid() < ltf_ema && ltf_stoch_main[0] < 20 && ltf_stoch_main[0] > ltf_stoch_signal[0]) {
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Check for short entry conditions                                 |
//+------------------------------------------------------------------+
bool CheckShortEntry() {
    double ltf_ema = iMA(Symbol(), LTF, LTF_EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);

    // ---- Getting handle for Stochastic
    int ltf_stochastic_handle = iStochastic(Symbol(), LTF, LTF_Stoch_K, LTF_Stoch_D, LTF_Stoch_Slowing, MODE_SMA, STOCH_PRICE_LOWHIGH);

    // ---- Arrays for Stochastic values
    double ltf_stoch_main[];
    double ltf_stoch_signal[];

    // ---- Copying Stochastic values
    if (CopyBuffer(ltf_stochastic_handle, 0, 0, 1, ltf_stoch_main) < 0 ||
        CopyBuffer(ltf_stochastic_handle, 1, 0, 1, ltf_stoch_signal) < 0) {
        Print("Error copying Stochastic buffers: ", GetLastError());
        return false;
    }

    // ---- Check if the price is above the Lower Timeframe EMA and Stochastic is overbought and turning
    if (m_symbol.Ask() > ltf_ema && ltf_stoch_main[0] > 80 && ltf_stoch_main[0] < ltf_stoch_signal[0]) {
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Open a long position                                             |
//+------------------------------------------------------------------+
void OpenLongOrder() {
    double atr = iATR(Symbol(), LTF, LTF_ATR_Period, 1);
    double stopLoss = NormalizeDouble(m_symbol.Ask() - StopLossMultiplier * atr, m_symbol.Digits());
    double takeProfit = NormalizeDouble(m_symbol.Ask() + TakeProfitMultiplier * atr, m_symbol.Digits());
    double lotSize = CalculateLotSize(stopLoss);

    // --- Open a position
    if(!m_trade.Buy(lotSize, NULL, m_symbol.Ask(), stopLoss, takeProfit, "Long Entry")) {
        Print("Error opening long position. Error code: ", GetLastError());
        return;
    }
    Print("Long position opened successfully.");
}

//+------------------------------------------------------------------+
//| Open a short position                                            |
//+------------------------------------------------------------------+
void OpenShortOrder() {
    double atr = iATR(Symbol(), LTF, LTF_ATR_Period, 1);
    double stopLoss = NormalizeDouble(m_symbol.Bid() + StopLossMultiplier * atr, m_symbol.Digits());
    double takeProfit = NormalizeDouble(m_symbol.Bid() - TakeProfitMultiplier * atr, m_symbol.Digits());
    double lotSize = CalculateLotSize(stopLoss);

    // --- Open a position
    if(!m_trade.Sell(lotSize, NULL, m_symbol.Bid(), stopLoss, takeProfit, "Short Entry")) {
        Print("Error opening short position. Error code: ", GetLastError());
        return;
    }
    Print("Short position opened successfully.");
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                      |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLoss) {
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (RiskPercent / 100.0);
    
    // Calculate Stop Loss in Points
    m_symbol.Name(Symbol());
    double stopLossInPoints = MathAbs(m_symbol.Bid() - stopLoss) / m_symbol.Point();

    // Calculate Lot Size
    double lots = riskAmount / (stopLossInPoints * m_symbol.TickValue() / m_symbol.TickSize());
    lots = NormalizeDouble(lots, 2);

    // Check if the calculated lot size is within the allowed limits
    double minLot = m_symbol.LotsMin();
    double maxLot = m_symbol.LotsMax();
    double lotStep = m_symbol.LotsStep();

    if (lots < minLot) lots = minLot;
    if (lots > maxLot) lots = maxLot;

    // Adjust the lot size to the nearest valid increment
    lots = MathRound(lots / lotStep) * lotStep;

    return lots;
}

//+------------------------------------------------------------------+
//| Check for trailing stop                                          |
//+------------------------------------------------------------------+
void CheckForTrailingStop() {
    for (int i = 0; i < PositionsTotal(); i++) {
        if (!m_position.SelectByIndex(i)) continue; // Select the position
        if (m_position.Symbol() != Symbol() || m_position.Magic() != MagicNumber) continue;

        if (m_position.PositionType() == POSITION_TYPE_BUY) {
            // Check for trailing stop
            if (TrailingStopPips > 0 && (m_symbol.Bid() - m_position.PriceOpen()) > m_symbol.Point() * TrailingStopPips) {
                if (m_position.StopLoss() < m_symbol.Bid() - m_symbol.Point() * TrailingStopPips) {
                    if(!m_trade.PositionModify(m_position.Symbol(), NormalizeDouble(m_symbol.Bid() - m_symbol.Point() * TrailingStopPips, m_symbol.Digits()), m_position.PriceTakeProfit())) {
                        Print("Error modifying position. Error code: ", GetLastError());
                        return;
                    }
                }
            }
        } else if (m_position.PositionType() == POSITION_TYPE_SELL) {
            // Check for trailing stop
            if (TrailingStopPips > 0 && (m_position.PriceOpen() - m_symbol.Ask()) > m_symbol.Point() * TrailingStopPips) {
                if (m_position.StopLoss() > m_symbol.Ask() + m_symbol.Point() * TrailingStopPips || m_position.StopLoss() == 0) {
                    if(!m_trade.PositionModify(m_position.Symbol(), NormalizeDouble(m_symbol.Ask() + m_symbol.Point() * TrailingStopPips, m_symbol.Digits()), m_position.PriceTakeProfit())) {
                        Print("Error modifying position. Error code: ", GetLastError());
                        return;
                    }
                }
            }
        }
    }
}
//+------------------------------------------------------------------+