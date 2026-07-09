//+------------------------------------------------------------------+
//|                                                     Parameters.mqh |
//|                        XAU SMC Scalper Pro - Config Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

//+------------------------------------------------------------------+
//| EA Input Parameters                                             |
//+------------------------------------------------------------------+
input group "=== Trading Parameters ==="
input double InputRiskPercent = 0.5;        // Risk per trade (%)
input int InputDailyLossLimit = 3;          // Daily loss limit (%)
input int InputDailyProfitTarget = 2;       // Daily profit target (%)
input int InputMaxTradesPerDay = 5;         // Max trades per day
input int InputMagicNumber = 20240701;      // Magic number

input group "=== Timeframe Parameters ==="
input int InputSwingLookback = 5;           // Swing lookback period
input int InputOBLookback = 10;             // OB lookback period

input group "=== Confidence Score Weights ==="
input int InputTrendWeight = 20;
input int InputStructureWeight = 15;
input int InputLiquidityWeight = 15;
input int InputOBWeight = 15;
input int InputFVGWeight = 10;
input int InputPriceActionWeight = 10;
input int InputSpreadWeight = 5;
input int InputSessionWeight = 5;
input int InputATRWeight = 5;

input group "=== Filter Thresholds ==="
input int InputMinConfidenceScore = 75;     // Minimum confidence for entry
input double InputMaxSpreadRatio = 20.0;    // Max spread ratio (%)

input group "=== Risk Management ==="
input int InputDefaultSL = 100;             // Default stop loss (points)
input int InputDefaultTP = 150;             // Default take profit (points)
input int InputTrailingStart = 100;         // Trailing start (points)
input int InputTrailingStep = 50;           // Trailing step (points)

//+------------------------------------------------------------------+
//| Parameters Structure - Accessible throughout the EA             |
//+------------------------------------------------------------------+
struct Parameters
{
   double RiskPercent;
   int DailyLossLimit;
   int DailyProfitTarget;
   int MaxTradesPerDay;
   int MagicNumber;
   
   int SwingLookback;
   int OBLookback;
   
   int TrendWeight;
   int StructureWeight;
   int LiquidityWeight;
   int OBWeight;
   int FVGWeight;
   int PriceActionWeight;
   int SpreadWeight;
   int SessionWeight;
   int ATRWeight;
   
   int MinConfidenceScore;
   double MaxSpreadRatio;
   
   int DefaultSL;
   int DefaultTP;
   int TrailingStart;
   int TrailingStep;
   
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void Parameters()
   {
      this.RiskPercent = InputRiskPercent;
      this.DailyLossLimit = InputDailyLossLimit;
      this.DailyProfitTarget = InputDailyProfitTarget;
      this.MaxTradesPerDay = InputMaxTradesPerDay;
      this.MagicNumber = InputMagicNumber;
      
      this.SwingLookback = InputSwingLookback;
      this.OBLookback = InputOBLookback;
      
      this.TrendWeight = InputTrendWeight;
      this.StructureWeight = InputStructureWeight;
      this.LiquidityWeight = InputLiquidityWeight;
      this.OBWeight = InputOBWeight;
      this.FVGWeight = InputFVGWeight;
      this.PriceActionWeight = InputPriceActionWeight;
      this.SpreadWeight = InputSpreadWeight;
      this.SessionWeight = InputSessionWeight;
      this.ATRWeight = InputATRWeight;
      
      this.MinConfidenceScore = InputMinConfidenceScore;
      this.MaxSpreadRatio = InputMaxSpreadRatio;
      
      this.DefaultSL = InputDefaultSL;
      this.DefaultTP = InputDefaultTP;
      this.TrailingStart = InputTrailingStart;
      this.TrailingStep = InputTrailingStep;
   }
   
   //+------------------------------------------------------------------+
   //| Update from input parameters                                   |
   //+------------------------------------------------------------------+
   void Update()
   {
      this.RiskPercent = InputRiskPercent;
      this.DailyLossLimit = InputDailyLossLimit;
      this.DailyProfitTarget = InputDailyProfitTarget;
      this.MaxTradesPerDay = InputMaxTradesPerDay;
      this.MagicNumber = InputMagicNumber;
      
      this.SwingLookback = InputSwingLookback;
      this.OBLookback = InputOBLookback;
      
      this.TrendWeight = InputTrendWeight;
      this.StructureWeight = InputStructureWeight;
      this.LiquidityWeight = InputLiquidityWeight;
      this.OBWeight = InputOBWeight;
      this.FVGWeight = InputFVGWeight;
      this.PriceActionWeight = InputPriceActionWeight;
      this.SpreadWeight = InputSpreadWeight;
      this.SessionWeight = InputSessionWeight;
      this.ATRWeight = InputATRWeight;
      
      this.MinConfidenceScore = InputMinConfidenceScore;
      this.MaxSpreadRatio = InputMaxSpreadRatio;
      
      this.DefaultSL = InputDefaultSL;
      this.DefaultTP = InputDefaultTP;
      this.TrailingStart = InputTrailingStart;
      this.TrailingStep = InputTrailingStep;
   }
};

//+------------------------------------------------------------------+
//| Global Parameters Instance                                      |
//+------------------------------------------------------------------+
Parameters g_Parameters;

//+------------------------------------------------------------------+
//| Initialize parameters                                            |
//+------------------------------------------------------------------+
bool InitializeParameters()
{
   g_Parameters = Parameters();
   return true;
}
//+------------------------------------------------------------------+
