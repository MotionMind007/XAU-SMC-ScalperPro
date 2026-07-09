#ifndef __CORE_TRADECONTEXT_MHQ__
#define __CORE_TRADECONTEXT_MHQ__
//+------------------------------------------------------------------+
//|                                                      TradeContext.mqh |
//|                        XAU SMC Scalper Pro - Core Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

input int InpSwingLookback = 20;  // H1 swing lookback for trend detection

#include <stderror.mqh>
#include "Models\\Swing.mqh"
#include "Models\\OrderBlockModel.mqh"
#include "Models\\LiquidityModel.mqh"
#include "Models\\ScoreModel.mqh"
#include "Config\\Parameters.mqh"
#include "Core\\Session.mqh"
#include "Services\\NewsService.mqh"
#include "Services\\MarketMode.mqh"

//+------------------------------------------------------------------+
//| Market State Enumeration                                         |
//+------------------------------------------------------------------+
enum MarketMode
{
   MODE_TRENDING = 1,
   MODE_RANGING = 2,
   MODE_VOLATILE = 3,
   MODE_NO_TRADE = 4
};

enum TradeDirection
{
   DIRECTION_NONE = 0,
   DIRECTION_BUY = 1,
   DIRECTION_SELL = -1
};

//+------------------------------------------------------------------+
//| Trade Context Structure                                         |
//+------------------------------------------------------------------+
struct TradeContext
{
   // === Market Data ===
   MqlRates M5Rates[];
   MqlRates M15Rates[];
   MqlRates H1Rates[];
   
   // === Technical Indicators ===
   double ATR_14;
   double ATR_Buffer;
   
   // === Market Analysis Results ===
   int CurrentTrend;
   int CurrentTrendM15;
   int MarketMode;
   int Session;
   
   // === Swing Points ===
   Array<SwingPoint> SwingPoints;
   
   // === Order Blocks ===
   Array<OrderBlock> FreshOB_Bullish;
   Array<OrderBlock> FreshOB_Bearish;
   Array<OrderBlock> MitigatedOB;
   
   // === Liquidity ===
   Array<LiquidityLevel> LiquiditySweeps;
   double BuySideLiquidity;
   double SellSideLiquidity;
   
   // === Fair Value Gaps ===
   Array<FVG> FVGs;
   
   // === Price Action ===
   int LastPriceAction;
   datetime LastPriceActionTime;
   
   // === Trade State ===
   int ActiveTrades;
   int TradesToday;
   double DailyProfit;
   double DailyLoss;
   double BalanceAtDayStart;
   
   // === Execution Context ===
   datetime LastUpdate;
   bool SessionActive;
   bool NewsActive;
   double CurrentSpread;
   double SpreadRatio;
   string LastError;
   
   // === Score Components ===
   int TrendScore;
   int TrendM15Score;
   int StructureScore;
   int LiquidityScore;
   int OBScore;
   int FVGScore;
   int PriceActionScore;
   int SpreadScore;
   int SessionScore;
   int ATRScore;
   int TotalConfidenceScore;
   
   // === Entry/Exit Decision ===
   bool EntryAllowed;
   bool ExitAllowed;
   string EntryReasons;
   string ExitReasons;
   double TargetLotSize;
   double TargetSL;
   double TargetTP;
   
   // === Bar Tracking (internal) ===
   datetime M5LastBar;
   datetime M15LastBar;
   datetime H1LastBar;
   
   //+------------------------------------------------------------------+
   void TradeContext()
   {
      this.Reset();
   }
   
   //+------------------------------------------------------------------+
   void Reset()
   {
      ArraySetAsSeries(this.M5Rates, true);
      ArraySetAsSeries(this.M15Rates, true);
      ArraySetAsSeries(this.H1Rates, true);
      
      this.ATR_14 = 0.0;
      this.ATR_Buffer = 1.5;
      
      this.CurrentTrend = DIRECTION_NONE;
      this.CurrentTrendM15 = DIRECTION_NONE;
      this.MarketMode = MODE_NO_TRADE;
      this.Session = 0;
      
      this.SwingPoints.Clear();
      this.FreshOB_Bullish.Clear();
      this.FreshOB_Bearish.Clear();
      this.MitigatedOB.Clear();
      this.LiquiditySweeps.Clear();
      this.BuySideLiquidity = 0.0;
      this.SellSideLiquidity = 0.0;
      this.FVGs.Clear();
      
      this.LastPriceAction = 0;
      this.LastPriceActionTime = 0;
      
      this.ActiveTrades = 0;
      this.TradesToday = 0;
      this.DailyProfit = 0.0;
      this.DailyLoss = 0.0;
      this.BalanceAtDayStart = AccountInfoDouble(ACCOUNT_BALANCE);
      
      this.LastUpdate = 0;
      this.SessionActive = false;
      this.NewsActive = false;
      this.CurrentSpread = 0.0;
      this.SpreadRatio = 0.0;
      this.LastError = "";
      
      this.ResetScores();
      
      this.EntryAllowed = false;
      this.ExitAllowed = true;
      this.EntryReasons = "";
      this.ExitReasons = "";
      this.TargetLotSize = 0.0;
      this.TargetSL = 0.0;
      this.TargetTP = 0.0;
      
      this.M5LastBar = 0;
      this.M15LastBar = 0;
      this.H1LastBar = 0;
   }
   
   //+------------------------------------------------------------------+
   void ResetScores()
   {
      this.TrendScore = 0;
      this.TrendM15Score = 0;
      this.StructureScore = 0;
      this.LiquidityScore = 0;
      this.OBScore = 0;
      this.FVGScore = 0;
      this.PriceActionScore = 0;
      this.SpreadScore = 0;
      this.SessionScore = 0;
      this.ATRScore = 0;
      this.TotalConfidenceScore = 0;
   }
   
   //+------------------------------------------------------------------+
   bool IsValid()
   {
      return (this.SessionActive && 
              !this.NewsActive && 
              this.CurrentTrend != DIRECTION_NONE &&
              this.MarketMode != MODE_NO_TRADE &&
              this.MarketMode != MODE_VOLATILE);
   }
   
   //+------------------------------------------------------------------+
   //| Update daily profit and loss metrics (separate wins/losses)     |
   //+------------------------------------------------------------------+
   bool UpdateDailyMetrics()
   {
      datetime now = TimeCurrent();
      datetime dayStart = StringToTime(TimeToString(now, TIME_DATE));
      
      if (this.BalanceAtDayStart == 0 || 
          TimeYear(now) != TimeYear(this.LastUpdate) ||
          TimeDayOfYear(now) != TimeDayOfYear(this.LastUpdate))
      {
         this.BalanceAtDayStart = AccountInfoDouble(ACCOUNT_BALANCE);
         this.DailyProfit = 0.0;
         this.DailyLoss = 0.0;
         this.TradesToday = 0;
      }
      
      double totalWins = 0.0;
      double totalLosses = 0.0;
      int tradeCount = 0;
      
      if (HistorySelect(dayStart, TimeCurrent()))
      {
         int totalDeals = HistoryDealsTotal();
         for (int i = 0; i < totalDeals; i++)
         {
            ulong ticket = HistoryDealGetTicket(i);
            if (ticket == 0) continue;
            
            // Only count closed deals (out) for our symbol and magic
            if (HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
               continue;
            if (HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
               continue;
            if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != g_Parameters.MagicNumber)
               continue;
            
            double dealProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                              + HistoryDealGetDouble(ticket, DEAL_SWAP)
                              + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            
            if (dealProfit > 0)
               totalWins += dealProfit;
            else
               totalLosses += MathAbs(dealProfit);
            
            tradeCount++;
         }
      }
      
      this.DailyProfit = totalWins;
      this.DailyLoss = totalLosses;
      this.TradesToday = tradeCount;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   bool UpdateActiveTrades()
   {
      this.ActiveTrades = 0;
      for (int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if (ticket == 0) continue;
         
         if (PositionGetString(POSITION_SYMBOL) == _Symbol &&
             PositionGetInteger(POSITION_MAGIC) == g_Parameters.MagicNumber)
         {
            this.ActiveTrades++;
         }
      }
      return true;
   }
   
   //+------------------------------------------------------------------+
   int CalculateConfidenceScore()
   {
      this.TotalConfidenceScore = 
         this.TrendScore + this.TrendM15Score + this.StructureScore + this.LiquidityScore +
         this.OBScore + this.FVGScore + this.PriceActionScore +
         this.SpreadScore + this.SessionScore + this.ATRScore;
      return this.TotalConfidenceScore;
   }
   
   //+------------------------------------------------------------------+
   string GetConfidenceLevel()
   {
      if (this.TotalConfidenceScore >= 85) return "HIGH";
      else if (this.TotalConfidenceScore >= 75) return "MEDIUM";
      else return "LOW";
   }
   
   //+------------------------------------------------------------------+
   void AddError(string error)
   {
      if (this.LastError != "") this.LastError += "; ";
      this.LastError += error;
   }
   
   //+------------------------------------------------------------------+
   bool DailyLimitsReached()
   {
      double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double dailyGain = currentBalance - this.BalanceAtDayStart;
      
      if (dailyGain >= g_Parameters.DailyProfitTarget * this.BalanceAtDayStart / 100) return true;
      if (this.DailyLoss >= g_Parameters.DailyLossLimit * this.BalanceAtDayStart / 100) return true;
      if (this.TradesToday >= g_Parameters.MaxTradesPerDay) return true;
      return false;
   }
   
   //+------------------------------------------------------------------+
   bool HasSufficientMargin(double requiredMargin)
   {
      return (AccountInfoDouble(ACCOUNT_FREEMARGIN) >= requiredMargin * 1.2);
   }
   
   //+------------------------------------------------------------------+
   bool IsSpreadAcceptable()
   {
      return (this.CurrentSpread > 0 && this.SpreadRatio <= g_Parameters.MaxSpreadRatio);
   }
   
   //+------------------------------------------------------------------+
   bool IsTradingAllowed()
   {
      return (this.SessionActive && !this.NewsActive && 
              this.MarketMode != MODE_NO_TRADE && this.MarketMode != MODE_VOLATILE &&
              !this.DailyLimitsReached());
   }
};

TradeContext g_TradeContext;

//+------------------------------------------------------------------+
bool InitializeTradeContext()
{
   g_TradeContext.Reset();
   g_TradeContext.LastUpdate = TimeCurrent();
   return true;
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Lightweight per-tick update - only fresh market data            |
//| Avoids expensive analysis (trend detection, swing analysis)     |
//+------------------------------------------------------------------+
bool UpdateTradeContextPerTick()
{
   // Copy only current timeframe rates (M5) for fresh price data
   if (CopyRates(_Symbol, PERIOD_M5, 0, 200, g_TradeContext.M5Rates) != 200)
   {
      g_TradeContext.AddError("PerTick: Failed to copy M5 rates");
      return false;
   }
   
   // Update lightweight context fields
   g_TradeContext.CurrentSpread = SymbolInfoDouble(_Symbol, SYMBOL_SPREAD);
   g_TradeContext.SpreadRatio = g_TradeContext.CurrentSpread / g_Parameters.DefaultSL * 100;
   g_TradeContext.Session = GetCurrentSession();
   g_TradeContext.SessionActive = IsSessionActive(g_TradeContext.Session);
   g_TradeContext.NewsActive = IsNewsActive();
   g_TradeContext.UpdateActiveTrades();
   
   return true;
}

//+------------------------------------------------------------------+
bool UpdateTradeContext()
{
   g_TradeContext.LastUpdate = iTime(_Symbol, PERIOD_M5, 0);

   if (!CopyMarketData()) return false;
   g_TradeContext.UpdateActiveTrades();
   g_TradeContext.UpdateDailyMetrics();
   g_TradeContext.Session = GetCurrentSession();
   g_TradeContext.SessionActive = IsSessionActive(g_TradeContext.Session);
   g_TradeContext.NewsActive = IsNewsActive();
   g_TradeContext.CurrentSpread = SymbolInfoDouble(_Symbol, SYMBOL_SPREAD);
   g_TradeContext.SpreadRatio = g_TradeContext.CurrentSpread / g_Parameters.DefaultSL * 100;
   if (!UpdateATR()) g_TradeContext.AddError("ATR update failed");
   
   // Detect trend based on H1 structure
   DetectTrend();
   
   // Detect trend on M15 for dual-TF validation
   DetectTrendM15();
   
   // Detect price action patterns on M5
   DetectPriceAction();
   
   return true;
}

//+------------------------------------------------------------------+
//| Detect trend based on H1 market structure (HH/HL or LH/LL)      |
//+------------------------------------------------------------------+
void DetectTrend()
{
   // Analyze H1 swing points for trend determination
   // Bullish trend: Higher Highs (HH) and Higher Lows (HL)
   // Bearish trend: Lower Highs (LH) and Lower Lows (LL)
   
   if (ArraySize(g_TradeContext.H1Rates) < 50)
      return;
   
   // Find recent swing highs and lows on H1
   double recentHighs[];
   double recentLows[];
   ArrayResize(recentHighs, 0);
   ArrayResize(recentLows, 0);
   
   // Use a simple swing detection (fractal-like)
   int lookback = InpSwingLookback;  // Use configurable lookback for H1 bars
   int swingPeriod = 3; // 3 bars on each side for swing detection
   
   for (int i = swingPeriod; i < lookback - swingPeriod && i < ArraySize(g_TradeContext.H1Rates) - swingPeriod; i++)
   {
      // Check for swing high
      bool isSwingHigh = true;
      bool isSwingLow = true;
      
      for (int j = 1; j <= swingPeriod; j++)
      {
         if (g_TradeContext.H1Rates[i].high <= g_TradeContext.H1Rates[i-j].high ||
             g_TradeContext.H1Rates[i].high <= g_TradeContext.H1Rates[i+j].high)
            isSwingHigh = false;
            
         if (g_TradeContext.H1Rates[i].low >= g_TradeContext.H1Rates[i-j].low ||
             g_TradeContext.H1Rates[i].low >= g_TradeContext.H1Rates[i+j].low)
            isSwingLow = false;
      }
      
      if (isSwingHigh)
      {
         ArrayResize(recentHighs, ArraySize(recentHighs) + 1);
         recentHighs[ArraySize(recentHighs) - 1] = g_TradeContext.H1Rates[i].high;
      }
      
      if (isSwingLow)
      {
         ArrayResize(recentLows, ArraySize(recentLows) + 1);
         recentLows[ArraySize(recentLows) - 1] = g_TradeContext.H1Rates[i].low;
      }
   }
   
   // Need at least 2 swing highs and 2 swing lows to determine trend
   if (ArraySize(recentHighs) < 2 || ArraySize(recentLows) < 2)
   {
      g_TradeContext.CurrentTrend = DIRECTION_NONE;
      g_TradeContext.TrendScore = 0;
      return;
   }
   
   // Get the last 2 swing highs and lows
   double lastHigh = recentHighs[ArraySize(recentHighs) - 1];
   double prevHigh = recentHighs[ArraySize(recentHighs) - 2];
   double lastLow = recentLows[ArraySize(recentLows) - 1];
   double prevLow = recentLows[ArraySize(recentLows) - 2];
   
   // Check for bullish structure (HH + HL)
   bool isBullish = (lastHigh > prevHigh) && (lastLow > prevLow);
   
   // Check for bearish structure (LH + LL)
   bool isBearish = (lastHigh < prevHigh) && (lastLow < prevLow);
   
   if (isBullish && !isBearish)
   {
      g_TradeContext.CurrentTrend = DIRECTION_BUY;
      g_TradeContext.TrendScore = 20;  // Award 20 points for trend detection
   }
   else if (isBearish && !isBullish)
   {
      g_TradeContext.CurrentTrend = DIRECTION_SELL;
      g_TradeContext.TrendScore = 20;  // Award 20 points for trend detection
   }
   else
   {
      // No clear trend or conflicting signals
      g_TradeContext.CurrentTrend = DIRECTION_NONE;
      g_TradeContext.TrendScore = 0;
   }
}

//+------------------------------------------------------------------+
//| Detect trend based on M15 market structure (HH/HL or LH/LL)     |
//+------------------------------------------------------------------+
void DetectTrendM15()
{
   if (ArraySize(g_TradeContext.M15Rates) < 50)
      return;
   
   double recentHighs[];
   double recentLows[];
   ArrayResize(recentHighs, 0);
   ArrayResize(recentLows, 0);
   
   int lookback = InpSwingLookback * 3;  // More M15 bars for same lookback
   int swingPeriod = 3;
   
   for (int i = swingPeriod; i < lookback - swingPeriod && i < ArraySize(g_TradeContext.M15Rates) - swingPeriod; i++)
   {
      bool isSwingHigh = true;
      bool isSwingLow = true;
      
      for (int j = 1; j <= swingPeriod; j++)
      {
         if (g_TradeContext.M15Rates[i].high <= g_TradeContext.M15Rates[i-j].high ||
             g_TradeContext.M15Rates[i].high <= g_TradeContext.M15Rates[i+j].high)
            isSwingHigh = false;
             
         if (g_TradeContext.M15Rates[i].low >= g_TradeContext.M15Rates[i-j].low ||
             g_TradeContext.M15Rates[i].low >= g_TradeContext.M15Rates[i+j].low)
            isSwingLow = false;
      }
      
      if (isSwingHigh)
      {
         ArrayResize(recentHighs, ArraySize(recentHighs) + 1);
         recentHighs[ArraySize(recentHighs) - 1] = g_TradeContext.M15Rates[i].high;
      }
      
      if (isSwingLow)
      {
         ArrayResize(recentLows, ArraySize(recentLows) + 1);
         recentLows[ArraySize(recentLows) - 1] = g_TradeContext.M15Rates[i].low;
      }
   }
   
   if (ArraySize(recentHighs) < 2 || ArraySize(recentLows) < 2)
   {
      g_TradeContext.CurrentTrendM15 = DIRECTION_NONE;
      return;
   }
   
   double lastHigh = recentHighs[ArraySize(recentHighs) - 1];
   double prevHigh = recentHighs[ArraySize(recentHighs) - 2];
   double lastLow = recentLows[ArraySize(recentLows) - 1];
   double prevLow = recentLows[ArraySize(recentLows) - 2];
   
   bool isBullish = (lastHigh > prevHigh) && (lastLow > prevLow);
   bool isBearish = (lastHigh < prevHigh) && (lastLow < prevLow);
   
   if (isBullish && !isBearish)
   {
      g_TradeContext.CurrentTrendM15 = DIRECTION_BUY;
      g_TradeContext.TrendM15Score = (int)g_Parameters.TrendM15Weight;
   }
   else if (isBearish && !isBullish)
   {
      g_TradeContext.CurrentTrendM15 = DIRECTION_SELL;
      g_TradeContext.TrendM15Score = (int)g_Parameters.TrendM15Weight;
   }
   else
   {
      g_TradeContext.CurrentTrendM15 = DIRECTION_NONE;
      g_TradeContext.TrendM15Score = 0;
   }
}


void DetectPriceAction()
{
   g_TradeContext.LastPriceAction = PA_NONE;
   
   if (ArraySize(g_TradeContext.M5Rates) < 7)
      return;
   
   // Use index 1 (previous closed candle) and 2 (one before that)
   // M5Rates are set as series, so [0]=current, [1]=previous, etc.
   int curr = 1;
   int prev = 2;
   
   double currOpen  = g_TradeContext.M5Rates[curr].open;
   double currClose = g_TradeContext.M5Rates[curr].close;
   double currHigh  = g_TradeContext.M5Rates[curr].high;
   double currLow   = g_TradeContext.M5Rates[curr].low;
   
   double prevOpen  = g_TradeContext.M5Rates[prev].open;
   double prevClose = g_TradeContext.M5Rates[prev].close;
   double prevHigh  = g_TradeContext.M5Rates[prev].high;
   double prevLow   = g_TradeContext.M5Rates[prev].low;
   
   double currBody = MathAbs(currClose - currOpen);
   double prevBody = MathAbs(prevClose - prevOpen);
   double currRange = currHigh - currLow;
   double prevRange = prevHigh - prevLow;
   
   bool currBullish = (currClose > currOpen);
   bool currBearish = (currClose < currOpen);
   bool prevBullish = (prevClose > prevOpen);
   bool prevBearish = (prevClose < prevOpen);
   
   // --- Bullish Engulfing ---
   if (prevBearish && currBullish && currRange > prevRange &&
       currOpen <= prevClose && currClose >= prevOpen)
   {
      g_TradeContext.LastPriceAction = PA_BULLISH_ENGULFING;
      g_TradeContext.LastPriceActionTime = g_TradeContext.M5Rates[curr].time;
      return;
   }
   
   // --- Bearish Engulfing ---
   if (prevBullish && currBearish && currRange > prevRange &&
       currOpen >= prevClose && currClose <= prevOpen)
   {
      g_TradeContext.LastPriceAction = PA_BEARISH_ENGULFING;
      g_TradeContext.LastPriceActionTime = g_TradeContext.M5Rates[curr].time;
      return;
   }
   
   // --- Pin Bar ---
   double currUpperWick = currHigh - MathMax(currOpen, currClose);
   double currLowerWick = MathMin(currOpen, currClose) - currLow;
   
   if (currBody > 0)
   {
      // Bullish pin bar: long lower wick (>2x body), small body near high
      if (currLowerWick > 2.0 * currBody && currUpperWick < currBody * 0.5)
      {
         g_TradeContext.LastPriceAction = PA_BULLISH_PIN_BAR;
         g_TradeContext.LastPriceActionTime = g_TradeContext.M5Rates[curr].time;
         return;
      }
      // Bearish pin bar: long upper wick (>2x body), small body near low
      if (currUpperWick > 2.0 * currBody && currLowerWick < currBody * 0.5)
      {
         g_TradeContext.LastPriceAction = PA_BEARISH_PIN_BAR;
         g_TradeContext.LastPriceActionTime = g_TradeContext.M5Rates[curr].time;
         return;
      }
   }
   
   // --- Rejection (wick > 60% of candle range) ---
   if (currRange > 0)
   {
      if (currLowerWick / currRange > 0.60)
      {
         g_TradeContext.LastPriceAction = PA_BULLISH_REJECTION;
         g_TradeContext.LastPriceActionTime = g_TradeContext.M5Rates[curr].time;
         return;
      }
      if (currUpperWick / currRange > 0.60)
      {
         g_TradeContext.LastPriceAction = PA_BEARISH_REJECTION;
         g_TradeContext.LastPriceActionTime = g_TradeContext.M5Rates[curr].time;
         return;
      }
   }
   
   // --- Momentum (current body > 2x average body of last 5 candles) ---
   double avgBody = 0.0;
   for (int i = 2; i <= 6 && i < ArraySize(g_TradeContext.M5Rates); i++)
   {
      avgBody += MathAbs(g_TradeContext.M5Rates[i].close - g_TradeContext.M5Rates[i].open);
   }
   avgBody /= 5.0;
   
   if (currBody > 2.0 * avgBody && avgBody > 0)
   {
      if (currBullish)
      {
         g_TradeContext.LastPriceAction = PA_BULLISH_MOMENTUM;
         g_TradeContext.LastPriceActionTime = g_TradeContext.M5Rates[curr].time;
         return;
      }
      else if (currBearish)
      {
         g_TradeContext.LastPriceAction = PA_BEARISH_MOMENTUM;
         g_TradeContext.LastPriceActionTime = g_TradeContext.M5Rates[curr].time;
         return;
      }
   }
   
   // --- Inside Bar Break ---
   // prev candle contained within candle before it
   int before_prev = 3;
   if (before_prev < ArraySize(g_TradeContext.M5Rates))
   {
      double beforeHigh = g_TradeContext.M5Rates[before_prev].high;
      double beforeLow  = g_TradeContext.M5Rates[before_prev].low;
      
      bool isInsideBar = (prevHigh <= beforeHigh && prevLow >= beforeLow);
      
      if (isInsideBar)
      {
         // Current candle breaks prev high or low
         if (currClose > prevHigh)
         {
            g_TradeContext.LastPriceAction = PA_INSIDE_BAR_BREAKEOUT;
            g_TradeContext.LastPriceActionTime = g_TradeContext.M5Rates[curr].time;
            return;
         }
         if (currClose < prevLow)
         {
            g_TradeContext.LastPriceAction = PA_INSIDE_BAR_BREAKEOUT;
            g_TradeContext.LastPriceActionTime = g_TradeContext.M5Rates[curr].time;
            return;
         }
      }
   }
}

//+------------------------------------------------------------------+
bool CopyMarketData()
{
   int ratesCount = 200;
   if (CopyRates(_Symbol, PERIOD_M5, 0, ratesCount, g_TradeContext.M5Rates) != ratesCount) {
      g_TradeContext.AddError("Failed to copy M5 rates"); return false;
   }
   if (CopyRates(_Symbol, PERIOD_M15, 0, ratesCount, g_TradeContext.M15Rates) != ratesCount) {
      g_TradeContext.AddError("Failed to copy M15 rates"); return false;
   }
   if (CopyRates(_Symbol, PERIOD_H1, 0, ratesCount, g_TradeContext.H1Rates) != ratesCount) {
      g_TradeContext.AddError("Failed to copy H1 rates"); return false;
   }
   return true;
}



//+------------------------------------------------------------------+
string TradeContextToString()
{
   string output = "";
   output += "Context: Trend=" + IntegerToString(g_TradeContext.CurrentTrend);
   output += ", Mode=" + IntegerToString(g_TradeContext.MarketMode);
   output += ", Session=" + IntegerToString(g_TradeContext.Session);
   output += ", ActiveTrades=" + IntegerToString(g_TradeContext.ActiveTrades);
   output += ", Confidence=" + IntegerToString(g_TradeContext.TotalConfidenceScore);
   output += ", Spread=" + DoubleToString(g_TradeContext.CurrentSpread, 1);
   output += ", DailyPnL=" + DoubleToString(g_TradeContext.DailyProfit - g_TradeContext.DailyLoss, 2);
   return output;
}
//+------------------------------------------------------------------+

#endif // __CORE_TRADECONTEXT_MHQ__
