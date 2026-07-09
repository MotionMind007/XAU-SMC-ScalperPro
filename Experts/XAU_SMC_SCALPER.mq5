//+------------------------------------------------------------------+
//|                                                    XAU_SMC_SCALPER.mq5 |
//|                        XAU SMC Scalper Pro - Main Expert Advisor |
//|                           Copyright 2026, MotionMind |
//|                                       https://motionmind.store |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
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

//+------------------------------------------------------------------+
//| Global Trade Object                                             |
//+------------------------------------------------------------------+
CTrade g_Trade;

//+------------------------------------------------------------------+
//| Global State Variables                                          |
//+------------------------------------------------------------------+
bool g_Initialized = false;
bool g_ReadyToTrade = false;
int g_PositionType = 0;  // 0=Buy, 1=Sell

//+------------------------------------------------------------------+
//| Expert initialization function                                  |
//+------------------------------------------------------------------+
int OnInit()
{
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
   
   // Initialize parameters
   if (!InitializeParameters())
   {
      Print("Error: Failed to initialize parameters");
      return INIT_FAILED;
   }
   
   // Initialize trade context
   if (!InitializeTradeContext())
   {
      Print("Error: Failed to initialize trade context");
      return INIT_FAILED;
   }
   
   // Initialize data cache
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
   
   // Initialize risk service
   if (!InitializeRisk())
   {
      Print("Error: Failed to initialize risk service");
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
   
   // Log initialization
   Logger_Log(INIT, "EA Initialized Successfully");
   
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
   
   // Cleanup ATR handle
   CleanupATR();
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if initialized
   if (!g_Initialized)
      return;
   
   // Update trade context (only on new bar to save resources)
   if (!g_TradeContext.IsNewBar(PERIOD_M5))
      return;
   
   // Update trade context with fresh data
   if (!UpdateTradeContext())
   {
      Logger_Log(ERROR, "Failed to update trade context");
      return;
   }
   
   // Update ATR
   if (!UpdateATR())
   {
      Logger_Log(WARNING, "Failed to update ATR");
   }
   
   // Update data cache if new candle
   if (!UpdateDataCache())
   {
      Logger_Log(ERROR, "Failed to update data cache");
      return;
   }
   
   // Run main trading loop
   ExecuteTradingCycle();
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
   
   // Step 3: Check for existing positions
   if (g_TradeContext.ActiveTrades >= g_Parameters.MaxTradesPerDay)
   {
      Logger_Log(DEBUG, "Max trades reached");
      return;
   }
   
   // Step 4: Calculate position size
   double lotSize = CalculatePositionSize();
   if (lotSize <= 0)
   {
      Logger_Log(ERROR, "Failed to calculate position size");
      return;
   }
   
   // Step 5: Calculate stop loss and take profit
   double sl = CalculateStopLoss();
   double tp = CalculateTakeProfit();
   
   // Step 6: Execute order
   int direction = g_TradeContext.CurrentTrend;
   if (!ExecuteTrade(direction, lotSize, sl, tp))
   {
      Logger_Log(ERROR, "Failed to execute trade");
      return;
   }
   
   // Step 7: Record trade metrics
   RecordTradeMetrics(direction, lotSize, sl, tp);
   
   // Step 8: Log success
   Logger_Log(INFO, "Trade opened. Direction: " + IntegerToString(direction) + 
              ", Score: " + IntegerToString(entryDecision.ConfidenceScore));
}

//+------------------------------------------------------------------+
//| Calculate position size                                         |
//+------------------------------------------------------------------+
double CalculatePositionSize()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * g_Parameters.RiskPercent / 100;
   
   // Get ATR buffer for SL calculation (in price units)
   double atrBuffer = GetATRBuffer();
   
   // Calculate SL distance in points
   // DefaultSL is in points, atrBuffer is in price units
   // Convert atrBuffer to points: atrBuffer / _Point
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double slDistancePoints = g_Parameters.DefaultSL + (atrBuffer / point);
   
   // Calculate lot size
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotSize = riskAmount / (slDistancePoints * tickValue);
   
   // Normalize lot size
   lotSize = NormalizeLot(lotSize);
   
   // Validate margin
   double requiredMargin = lotSize * SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_REQUIRED);
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
   
   if (g_TradeContext.CurrentTrend == DIRECTION_BUY)
   {
      // For buy: SL below nearest swing low
      double swingLow = GetNearestSwingLow(currentPrice);
      if (swingLow > 0)
         sl = swingLow - GetATRBuffer() * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      else
         sl = currentPrice - g_Parameters.DefaultSL * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   }
   else if (g_TradeContext.CurrentTrend == DIRECTION_SELL)
   {
      // For sell: SL above nearest swing high
      double swingHigh = GetNearestSwingHigh(currentPrice);
      if (swingHigh > 0)
         sl = swingHigh + GetATRBuffer() * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      else
         sl = currentPrice + g_Parameters.DefaultSL * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   }
   
   // Normalize SL
   sl = NormalizePrice(sl);
   return sl;
}

//+------------------------------------------------------------------+
//| Calculate take profit                                           |
//+------------------------------------------------------------------+
double CalculateTakeProfit()
{
   double tp = 0.0;
   double sl = CalculateStopLoss();
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Calculate SL distance in points
   double slDistance = MathAbs(currentPrice - sl) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Calculate TP distance (1.5x to 2x SL)
   double tpDistance = slDistance * 1.5;
   
   // Normalize TP
   if (g_TradeContext.CurrentTrend == DIRECTION_BUY)
      tp = currentPrice + tpDistance * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   else
      tp = currentPrice - tpDistance * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   tp = NormalizePrice(tp);
   return tp;
}

//+------------------------------------------------------------------+
//| Execute trade order                                             |
//+------------------------------------------------------------------+
bool ExecuteTrade(int direction, double lotSize, double sl, double tp)
{
   if (direction == DIRECTION_BUY)
   {
      return g_Trade.Buy(lotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), sl, tp, 
                        "SMC Scalper Pro", g_Parameters.MagicNumber);
   }
   else if (direction == DIRECTION_SELL)
   {
      return g_Trade.Sell(lotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), sl, tp,
                         "SMC Scalper Pro", g_Parameters.MagicNumber);
   }
   
   return false;
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
   return MathRound(price / SymbolInfoDouble(_Symbol, SYMBOL_POINT)) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Helper: Get ATR buffer                                          |
//+------------------------------------------------------------------+
double GetATRBuffer()
{
   return g_TradeContext.ATR_Buffer;
}
//+------------------------------------------------------------------+
