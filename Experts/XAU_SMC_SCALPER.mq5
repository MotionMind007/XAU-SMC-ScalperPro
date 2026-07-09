//+------------------------------------------------------------------+
//|                                                    XAU_SMC_SCALPER.mq5 |
//|                        XAU SMC Scalper Pro - Main Expert Advisor |
//|                           Copyright 2026, MotionMind |
//|                                       https://motionmind.store |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MotionMind"
#property version   "1.2"
#property strict

#include <Trade\Trade.mqh>
#include "Core\TradeContext.mqh"
#include "Core\DataCache.mqh"
#include "Core\MetricsEngine.mqh"
#include "Core\Session.mqh"
#include "Core\ATR.mqh"
#include "Core\Risk.mqh"
#include "Core\TradeManager.mqh"
#include "Core\Execution.mqh"
#include "Core\Logger.mqh"
#include "Config\Parameters.mqh"
#include "Rules\RuleEngine.mqh"
#include "Services\NewsService.mqh"
#include "Services\TimeService.mqh"
#include "Services\SymbolService.mqh"
#include "Services\MarketMode.mqh"

//+------------------------------------------------------------------+
//| Global Trade Object                                             |
//+------------------------------------------------------------------+
CTrade g_Trade;

//+------------------------------------------------------------------+
//| Global State Variables                                          |
//+------------------------------------------------------------------+
bool g_Initialized = false;
bool g_ReadyToTrade = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   // Validate parameters first (fastest check)
   if (!InitializeParameters())
   {
      Print("Error: Parameter validation failed");
      return INIT_FAILED;
   }
   
   // Initialize symbol service
   if (!InitializeSymbolService())
   {
      Print("Error: Failed to initialize symbol service");
      return INIT_FAILED;
   }
   
   // Initialize time service
   if (!InitializeTimeService())
   {
      Print("Error: Failed to initialize time service");
      return INIT_FAILED;
   }
   
   // Initialize news service
   if (!InitializeNewsService())
   {
      Print("Error: Failed to initialize news service");
      return INIT_FAILED;
   }
   
   // Initialize trade context
   if (!InitializeTradeContext())
   {
      Print("Error: Failed to initialize trade context");
      return INIT_FAILED;
   }
   
   // Initialize data cache (per-timeframe)
   if (!InitializeDataCache())
   {
      Print("Error: Failed to initialize data cache");
      return INIT_FAILED;
   }
   
   // Initialize rule engine
   if (!InitializeRuleEngine())
   {
      Print("Error: Failed to initialize rule engine");
      return INIT_FAILED;
   }
   
   // Initialize metrics engine
   if (!InitializeMetricsEngine())
   {
      Print("Error: Failed to initialize metrics engine");
      return INIT_FAILED;
   }
   
   // Initialize ATR service
   if (!InitializeATR())
   {
      Print("Error: Failed to initialize ATR");
      return INIT_FAILED;
   }
   
   // Initialize market mode detection
   if (!InitializeMarketMode())
   {
      Print("Warning: Failed to initialize market mode detection - using fallback");
   }
   
   // Initialize risk service
   if (!InitializeRisk())
   {
      Print("Error: Failed to initialize risk service");
      return INIT_FAILED;
   }
   
   // Validate risk parameters
   if (!ValidateRiskParameters())
   {
      Print("Error: Invalid risk parameters");
      return INIT_FAILED;
   }
   
   // Initialize trade manager
   if (!InitializeTradeManager())
   {
      Print("Error: Failed to initialize trade manager");
      return INIT_FAILED;
   }
   
   // Initialize execution service
   if (!InitializeExecution())
   {
      Print("Error: Failed to initialize execution service");
      return INIT_FAILED;
   }
   
   // Initialize logger
   if (!InitializeLogger())
   {
      Print("Error: Failed to initialize logger");
      return INIT_FAILED;
   }
   
   // Set ready flag
   g_Initialized = true;
   g_ReadyToTrade = true;
   
   // Log initialization with validation summary
   Logger_Log(INIT, "EA Initialized Successfully | Risk=" + DoubleToString(g_Parameters.RiskPercent, 1) +
              "% | SL=" + IntegerToString(g_Parameters.DefaultSL) + "pts | TP=" + IntegerToString(g_Parameters.DefaultTP) + "pts");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Log deinitialization
   Logger_Log(DEINIT, "EA Deinitialized: " + IntegerToString(reason));
   
   // Export metrics on close
   ExportMetrics();
   
   // Cleanup handles
   CleanupATR();
   CleanupMarketMode();
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if initialized
   if (!g_Initialized)
      return;
   
   // EVERY TICK: Update trade context with fresh market data (lightweight)
   if (!UpdateTradeContextPerTick())
   {
      Logger_Log(ERROR, "Failed to update trade context");
      return;
   }
   
   // EVERY TICK: Update ATR (lightweight)
   if (!UpdateATR())
   {
      Logger_Log(WARNING, "Failed to update ATR");
   }
   
   // EVERY TICK: Update M5 data cache (entry timing data)
   if (!UpdateDataCacheM5())
   {
      Logger_Log(ERROR, "Failed to update data cache");
      return;
   }
   
   // NEW M5 BAR ONLY: Run heavy analysis and trading cycle
   if (!IsNewBar(PERIOD_M5))
      return;
   
   // Heavy operations on new bar only
   CalculateMarketMode();
   
   // Update H1/M15 data caches (structural analysis only on new bar)
   if (!UpdateDataCacheH1M15())
   {
      Logger_Log(ERROR, "Failed to update H1/M15 data cache");
      return;
   }
   
   // Run main trading loop
   ExecuteTradingCycle();
   
   // Manage open positions (BE, trailing, partial close)
   ManagePositions();
}

//+------------------------------------------------------------------+
//| Execute main trading cycle                                      |
//+------------------------------------------------------------------+
void ExecuteTradingCycle()
{
   // Step 1: Check filters (hard stops)
   if (!g_RuleEngine.CheckFilters())
   {
      Logger_Log(DEBUG, "Filters failed - skipping entry");
      return;
   }
   
   // Step 2: Check entry conditions
   TradeDecision entryDecision = g_RuleEngine.CheckEntry();
   
   if (!entryDecision.Allowed)
   {
      Logger_Log(DEBUG, "Entry not allowed. Score: " + IntegerToString(entryDecision.ConfidenceScore));
      return;
   }
   
   // Step 2b: Check max concurrent positions
   // Count actual open positions from the terminal
   int openPositionCount = 0;
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      
      if (PositionGetString(POSITION_SYMBOL) == _Symbol &&
          PositionGetInteger(POSITION_MAGIC) == g_Parameters.MagicNumber)
      {
         openPositionCount++;
      }
   }
   
   if (openPositionCount >= g_Parameters.MaxOpenPositions)
   {
      Logger_Log(DEBUG, "Max open positions reached (" + IntegerToString(openPositionCount) + 
                 "/" + IntegerToString(g_Parameters.MaxOpenPositions) + ")");
      return;
   }
   
   // Step 3: Check for existing positions
   if (g_TradeContext.ActiveTrades >= g_Parameters.MaxTradesPerDay)
   {
      Logger_Log(DEBUG, "Max trades reached");
      return;
   }
   
   // Step 4: Calculate stop loss FIRST (swing-based SL)
   double sl = CalculateStopLoss();
   double tp = CalculateTakeProfit(sl);
   
   if (sl <= 0)
   {
      Logger_Log(ERROR, "Failed to calculate stop loss");
      return;
   }
   
   // Step 5: Calculate position size based on ACTUAL SL distance
   // Cache repeated symbol info calls
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double slDistancePoints = MathAbs(currentPrice - sl) / point;
   
   // Apply half risk for scores below 85
   double riskMultiplier = entryDecision.HalfRisk ? 0.5 : 1.0;
   if (entryDecision.HalfRisk)
      Logger_Log(DEBUG, "Half risk mode - score below 85 (Score: " + 
                 IntegerToString(entryDecision.ConfidenceScore) + ")");
   
   double lotSize = CalculatePositionSizeFromSL(slDistancePoints, riskMultiplier);
   if (lotSize <= 0)
   {
      Logger_Log(ERROR, "Failed to calculate position size");
      return;
   }
   
   // Step 6: Execute order using Execution module (with retry logic)
   int direction = g_TradeContext.CurrentTrend;
   bool executed = false;
   
   if (direction == DIRECTION_BUY)
      executed = ExecuteBuy(lotSize, sl, tp, "SMC Scalper Pro");
   else if (direction == DIRECTION_SELL)
      executed = ExecuteSell(lotSize, sl, tp, "SMC Scalper Pro");
   
   if (!executed)
   {
      Logger_Log(ERROR, "Failed to execute trade");
      return;
   }
   
   // Step 7: Record trade metrics
   RecordTradeMetrics(direction, lotSize, sl, tp);
   
   // Step 8: Log success
   Logger_Log(INFO, "Trade opened. Direction: " + IntegerToString(direction) + 
              ", Lot: " + DoubleToString(lotSize, 2) +
              ", Score: " + IntegerToString(entryDecision.ConfidenceScore) +
              ", Mode: " + GetMarketModeString());
}

//+------------------------------------------------------------------+
//| Calculate position size based on actual SL distance              |
//+------------------------------------------------------------------+
double CalculatePositionSizeFromSL(double slDistancePoints, double riskMultiplier = 1.0)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * g_Parameters.RiskPercent / 100.0;
   
   // Apply risk multiplier (0.5 for half risk mode)
   riskAmount *= riskMultiplier;
   
   // Avoid division by zero
   if (slDistancePoints <= 0)
      return 0.0;
   
   // Calculate lot size using actual SL distance
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if (tickValue <= 0)
      return 0.0;
   
   double lotSize = riskAmount / (slDistancePoints * tickValue);
   
   // Normalize lot size
   lotSize = NormalizeLot(lotSize);
   
   // Validate margin
   double marginRequired = SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_REQUIRED);
   double requiredMargin = lotSize * marginRequired;
   if (!g_TradeContext.HasSufficientMargin(requiredMargin))
   {
      Logger_Log(WARNING, "Insufficient margin for calculated lot size");
      return 0.0;
   }
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Calculate stop loss                                             |
//+------------------------------------------------------------------+
double CalculateStopLoss()
{
   double sl = 0.0;
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if (g_TradeContext.CurrentTrend == DIRECTION_BUY)
   {
      // For buy: SL below nearest swing low
      double swingLow = GetNearestSwingLow(currentPrice);
      if (swingLow > 0)
         sl = swingLow - GetATRBuffer();
      else
         sl = currentPrice - g_Parameters.DefaultSL * point;
   }
   else if (g_TradeContext.CurrentTrend == DIRECTION_SELL)
   {
      // For sell: SL above nearest swing high
      double swingHigh = GetNearestSwingHigh(currentPrice);
      if (swingHigh > 0)
         sl = swingHigh + GetATRBuffer();
      else
         sl = currentPrice + g_Parameters.DefaultSL * point;
   }
   
   // Normalize SL
   sl = NormalizePrice(sl);
   return sl;
}

//+------------------------------------------------------------------+
//| Calculate take profit                                           |
//+------------------------------------------------------------------+
double CalculateTakeProfit(double sl)
{
   double tp = 0.0;
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Calculate SL distance in points
   double slDistance = MathAbs(currentPrice - sl) / point;
   
   // Calculate TP distance (1.5x to 2x SL)
   double tpDistance = slDistance * 1.5;
   
   // Normalize TP
   if (g_TradeContext.CurrentTrend == DIRECTION_BUY)
      tp = currentPrice + tpDistance * point;
   else
      tp = currentPrice - tpDistance * point;
   
   tp = NormalizePrice(tp);
   return tp;
}

//+------------------------------------------------------------------+
//| Record trade metrics                                            |
//+------------------------------------------------------------------+
void RecordTradeMetrics(int direction, double lotSize, double sl, double tp)
{
   SetupMetrics setupMetrics;
   setupMetrics.Timestamp = TimeCurrent();
   setupMetrics.Session = GetSessionName(g_TradeContext.Session);
   setupMetrics.MarketMode = g_TradeContext.MarketMode;
   setupMetrics.ConfidenceScore = g_TradeContext.TotalConfidenceScore;
   setupMetrics.TrendScore = g_TradeContext.TrendScore;
   setupMetrics.StructureScore = g_TradeContext.StructureScore;
   setupMetrics.LiquidityScore = g_TradeContext.LiquidityScore;
   setupMetrics.OBScore = g_TradeContext.OBScore;
   setupMetrics.FVGScore = g_TradeContext.FVGScore;
   setupMetrics.PriceActionScore = g_TradeContext.PriceActionScore;
   setupMetrics.SpreadRatio = g_TradeContext.SpreadRatio;
   setupMetrics.PassedAllFilters = true;
   setupMetrics.EntryReasons = "Entry Allowed";
   
   TradeMetrics tradeMetrics;
   tradeMetrics.Setup = setupMetrics;
   tradeMetrics.EntryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   tradeMetrics.SL = sl;
   tradeMetrics.TP = tp;
   tradeMetrics.LotSize = lotSize;
   tradeMetrics.PositionType = direction;
   tradeMetrics.ExitType = 0;
   tradeMetrics.ExitReason = "";
   tradeMetrics.EntryTime = TimeCurrent();
   tradeMetrics.ExitTime = 0;
   tradeMetrics.BarsHeld = 0;
   
   g_MetricsEngine.RecordTrade(tradeMetrics);
}

//+------------------------------------------------------------------+
//| Export metrics to CSV                                           |
//+------------------------------------------------------------------+
void ExportMetrics()
{
   g_MetricsEngine.ExportToCSV();
   Print("Metrics exported to: " + g_MetricsEngine.GetSummary());
}

//+------------------------------------------------------------------+
//| Helper: Normalize price                                         |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return MathRound(price / point) * point;
}
//+------------------------------------------------------------------+
