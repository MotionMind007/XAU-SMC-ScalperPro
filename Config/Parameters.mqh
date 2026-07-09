//+------------------------------------------------------------------+
//|                                                     Parameters.mqh |
//|                        XAU SMC Scalper Pro - Config Module |
//|                           Copyright 2026, MotionMind |
//|                                       https://motionmind.store |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MotionMind"
#property version   "1.2"
#property strict

//+------------------------------------------------------------------+
//| EA Input Parameters                                             |
//+------------------------------------------------------------------+
input group "=== Trading Parameters ==="
input double InputRiskPercent = 0.5;        // Risk per trade (%) [0.1-5.0]
input int InputDailyLossLimit = 3;          // Daily loss limit (%) [1-10]
input int InputDailyProfitTarget = 2;       // Daily profit target (%) [1-10]
input int InputMaxTradesPerDay = 5;         // Max trades per day [1-20]
input int InputMaxOpenPositions = 2;         // Max concurrent positions [1-5]
input int InputMagicNumber = 20240701;      // Magic number

input group "=== Timeframe Parameters ==="
input int InputSwingLookback = 5;           // Swing lookback period [1-50]
input int InputOBLookback = 10;             // OB lookback period [5-100]

input group "=== Confidence Score Weights ==="
input int InputTrendWeight = 20;            // Trend weight [0-30]
input int InputStructureWeight = 15;        // Structure weight [0-30]
input int InputLiquidityWeight = 15;        // Liquidity weight [0-30]
input int InputOBWeight = 15;               // Order Block weight [0-30]
input int InputFVGWeight = 10;              // FVG weight [0-20]
input int InputPriceActionWeight = 10;      // Price Action weight [0-20]
input int InputSpreadWeight = 5;            // Spread weight [0-10]
input int InputSessionWeight = 5;           // Session weight [0-10]
input int InputATRWeight = 5;               // ATR weight [0-10]

input group "=== Filter Thresholds ==="
input int InputMinConfidenceScore = 75;     // Minimum confidence for entry [50-100]
input double InputMaxSpreadRatio = 20.0;    // Max spread ratio (%) [5.0-50.0]

input group "=== Risk Management ==="
input int InputDefaultSL = 100;             // Default stop loss (points) [20-500]
input int InputDefaultTP = 150;             // Default take profit (points) [20-1000]
input int InputTrailingStart = 100;         // Trailing start (points) [0-500]
input int InputTrailingStep = 50;           // Trailing step (points) [10-200]

//+------------------------------------------------------------------+
//| Parameters Structure - Accessible throughout the EA             |
//+------------------------------------------------------------------+
struct Parameters
{
   double RiskPercent;
   int DailyLossLimit;
   int DailyProfitTarget;
   int MaxTradesPerDay;
   int MaxOpenPositions;
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
      this.MaxOpenPositions = InputMaxOpenPositions;
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
      this.MaxOpenPositions = InputMaxOpenPositions;
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
//| Validate a single parameter with range check                    |
//+------------------------------------------------------------------+
bool ValidateRange(double value, double minVal, double maxVal, string paramName)
{
   if (value < minVal || value > maxVal)
   {
      Print("Parameter validation failed: ", paramName, " = ", DoubleToString(value, 2),
            " must be between ", DoubleToString(minVal, 2), " and ", DoubleToString(maxVal, 2));
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Validate a single integer parameter with range check            |
//+------------------------------------------------------------------+
bool ValidateRangeInt(int value, int minVal, int maxVal, string paramName)
{
   if (value < minVal || value > maxVal)
   {
      Print("Parameter validation failed: ", paramName, " = ", IntegerToString(value),
            " must be between ", IntegerToString(minVal), " and ", IntegerToString(maxVal));
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Validate all parameters                                         |
//+------------------------------------------------------------------+
bool ValidateParameters()
{
   bool allValid = true;
   
   // RiskPercent: 0.1-5.0
   if (!ValidateRange(g_Parameters.RiskPercent, 0.1, 5.0, "RiskPercent"))
      allValid = false;
   
   // DailyLossLimit: 1-10
   if (!ValidateRangeInt(g_Parameters.DailyLossLimit, 1, 10, "DailyLossLimit"))
      allValid = false;
   
   // DailyProfitTarget: 1-10
   if (!ValidateRangeInt(g_Parameters.DailyProfitTarget, 1, 10, "DailyProfitTarget"))
      allValid = false;
   
   // MaxTradesPerDay: 1-20
   if (!ValidateRangeInt(g_Parameters.MaxTradesPerDay, 1, 20, "MaxTradesPerDay"))
      allValid = false;
   
   // MaxOpenPositions: 1-5
   if (!ValidateRangeInt(g_Parameters.MaxOpenPositions, 1, 5, "MaxOpenPositions"))
      allValid = false;
   
   // MinConfidenceScore: 50-100
   if (!ValidateRangeInt(g_Parameters.MinConfidenceScore, 50, 100, "MinConfidenceScore"))
      allValid = false;
   
   // MaxSpreadRatio: 5.0-50.0
   if (!ValidateRange(g_Parameters.MaxSpreadRatio, 5.0, 50.0, "MaxSpreadRatio"))
      allValid = false;
   
   // DefaultSL: 20-500
   if (!ValidateRangeInt(g_Parameters.DefaultSL, 20, 500, "DefaultSL"))
      allValid = false;
   
   // DefaultTP: 20-1000
   if (!ValidateRangeInt(g_Parameters.DefaultTP, 20, 1000, "DefaultTP"))
      allValid = false;
   
   // SwingLookback: 1-50
   if (!ValidateRangeInt(g_Parameters.SwingLookback, 1, 50, "SwingLookback"))
      allValid = false;
   
   // OBLookback: 5-100
   if (!ValidateRangeInt(g_Parameters.OBLookback, 5, 100, "OBLookback"))
      allValid = false;
   
   // Validate that DefaultTP > DefaultSL (for positive R:R)
   if (g_Parameters.DefaultTP <= g_Parameters.DefaultSL)
   {
      Print("Warning: DefaultTP (", g_Parameters.DefaultTP, ") should be > DefaultSL (", g_Parameters.DefaultSL, ")");
   }
   
   // Validate TrailingStart >= TrailingStep
   if (g_Parameters.TrailingStart > 0 && g_Parameters.TrailingStart < g_Parameters.TrailingStep)
   {
      Print("Warning: TrailingStart (", g_Parameters.TrailingStart, ") should be >= TrailingStep (", g_Parameters.TrailingStep, ")");
   }
   
   return allValid;
}

//+------------------------------------------------------------------+
//| Initialize parameters                                            |
//+------------------------------------------------------------------+
bool InitializeParameters()
{
   g_Parameters = Parameters();
   
   // Validate all parameters
   if (!ValidateParameters())
   {
      Print("Parameter validation failed - check input values");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Accessor functions for Parameters (to avoid confusion)          |
//+------------------------------------------------------------------+
Parameters& GetParameters()
{
   return g_Parameters;
}
//+------------------------------------------------------------------+
