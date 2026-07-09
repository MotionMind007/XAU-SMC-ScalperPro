//+------------------------------------------------------------------+
//|                                                      TradeContext.mqh |
//|                        XAU SMC Scalper Pro - Core Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include <stderror.mqh>
#include "Models\Swing.mqh"
#include "Models\OrderBlockModel.mqh"
#include "Models\LiquidityModel.mqh"
#include "Models\ScoreModel.mqh"
#include "Config\Parameters.mqh"
#include "Core\Session.mqh"
#include "Services\NewsService.mqh"

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
   bool UpdateDailyMetrics()
   {
      datetime now = TimeCurrent();
      datetime todayStart = StringToTime(TimeToString(now, TIME_DATE));
      
      if (this.BalanceAtDayStart == 0 || 
          TimeYear(now) != TimeYear(this.LastUpdate) ||
          TimeDayOfYear(now) != TimeDayOfYear(this.LastUpdate))
      {
         this.BalanceAtDayStart = AccountInfoDouble(ACCOUNT_BALANCE);
         this.DailyProfit = 0.0;
         this.DailyLoss = 0.0;
         this.TradesToday = 0;
      }
      
      double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double totalHistoryProfit = 0.0;
      int tradeCount = 0;
      
      for (int i = OrdersHistoryTotal() - 1; i >= 0; i--)
      {
         if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         {
            if (OrderCloseTime() >= todayStart && 
                OrderMagicNumber() == g_Parameters.MagicNumber)
            {
               totalHistoryProfit += OrderProfit() + OrderSwap() + OrderCommission();
               tradeCount++;
            }
         }
      }
      
      this.DailyProfit = MathMax(0, totalHistoryProfit);
      this.DailyLoss = MathMax(0, -totalHistoryProfit);
      this.TradesToday = tradeCount;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   bool UpdateActiveTrades()
   {
      this.ActiveTrades = 0;
      for (int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            if (OrderSymbol() == _Symbol && OrderMagicNumber() == g_Parameters.MagicNumber)
               this.ActiveTrades++;
         }
      }
      return true;
   }
   
   //+------------------------------------------------------------------+
   int CalculateConfidenceScore()
   {
      this.TotalConfidenceScore = 
         this.TrendScore + this.StructureScore + this.LiquidityScore +
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
bool UpdateTradeContext()
{
   datetime currentBar = iTime(_Symbol, PERIOD_M5, 0);
   if (currentBar == g_TradeContext.LastUpdate) return true;
   
   g_TradeContext.LastUpdate = currentBar;
   
   if (!CopyMarketData()) return false;
   g_TradeContext.UpdateActiveTrades();
   g_TradeContext.UpdateDailyMetrics();
   g_TradeContext.Session = GetCurrentSession();
   g_TradeContext.SessionActive = IsSessionActive(g_TradeContext.Session);
   g_TradeContext.NewsActive = IsNewsActive();
   g_TradeContext.CurrentSpread = SymbolInfoDouble(_Symbol, SYMBOL_SPREAD);
   g_TradeContext.SpreadRatio = g_TradeContext.CurrentSpread / (g_Parameters.DefaultSL * _Point) * 100;
   if (!UpdateATR()) g_TradeContext.AddError("ATR update failed");
   
   // Detect trend based on H1 structure
   DetectTrend();
   
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
   int lookback = 20;  // Look at last 20 H1 bars
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
bool IsNewBar(int timeframe)
{
   datetime currentBar = iTime(_Symbol, timeframe, 0);
   datetime lastBar = 0;
   
   switch (timeframe)
   {
      case PERIOD_M5: lastBar = g_TradeContext.M5LastBar; break;
      case PERIOD_M15: lastBar = g_TradeContext.M15LastBar; break;
      case PERIOD_H1: lastBar = g_TradeContext.H1LastBar; break;
   }
   
   if (currentBar != lastBar)
   {
      switch (timeframe)
      {
         case PERIOD_M5: g_TradeContext.M5LastBar = currentBar; break;
         case PERIOD_M15: g_TradeContext.M15LastBar = currentBar; break;
         case PERIOD_H1: g_TradeContext.H1LastBar = currentBar; break;
      }
      return true;
   }
   return false;
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
