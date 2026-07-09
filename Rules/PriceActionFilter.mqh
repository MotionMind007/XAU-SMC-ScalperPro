//+------------------------------------------------------------------+
//|                                                 PriceActionFilter.mqh |
//|                        XAU SMC Scalper Pro - Rules Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include "IRule.mqh"
#include "DataCache.mqh"

//+------------------------------------------------------------------+
//| Price Action Filter Rule                                        |
//+------------------------------------------------------------------+
// Validates that a valid price action pattern is present at the entry level
// Price action patterns provide confluence for entry decisions
//+------------------------------------------------------------------+

class CPriceActionFilter : public IRule
{
private:
   int m_Timeframe;
   int m_MaxCandleIndex;
   bool m_BullishOnly;
   bool m_BearishOnly;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void CPriceActionFilter(int tf = PERIOD_M5, int maxIndex = 2, bool bullishOnly = false, bool bearishOnly = false)
   {
      this.m_Timeframe = tf;
      this.m_MaxCandleIndex = maxIndex;
      this.m_BullishOnly = bullishOnly;
      this.m_BearishOnly = bearishOnly;
   }
   
   //+------------------------------------------------------------------+
   //| Check if price action rule passed                             |
   //+------------------------------------------------------------------+
   bool Check()
   {
      // Get price action from TradeContext
      int lastPA = g_TradeContext.LastPriceAction;
      
      if (lastPA == 0)
         return false;
      
      bool bullish = (lastPA > 0 && lastPA < 5);  // Bullish patterns
      bool bearish = (lastPA > 4);                 // Bearish patterns
      
      if (this.m_BullishOnly && !bullish)
         return false;
      
      if (this.m_BearishOnly && !bearish)
         return false;
      
      g_TradeContext.PriceActionScore = 10;
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get rule name                                                  |
   //+------------------------------------------------------------------+
   string Name()
   {
      return "PriceActionFilter";
   }
   
   //+------------------------------------------------------------------+
   //| Get rule weight                                                |
   //+------------------------------------------------------------------+
   double Weight()
   {
      return 10.0;  // 10 points in confidence score
   }
   
   //+------------------------------------------------------------------+
   //| Get reason for pass/fail                                       |
   //+------------------------------------------------------------------+
   string Reason()
   {
      int lastPA = g_TradeContext.LastPriceAction;
      
      if (lastPA == 0)
         return "No valid price action pattern detected - FAILED";
      
      string patternName = this.GetPatternName(lastPA);
      
      if (this.m_BullishOnly && lastPA > 4)
         return "Price action is bearish but bullish only required - FAILED";
      
      if (this.m_BearishOnly && lastPA <= 4)
         return "Price action is bullish but bearish only required - FAILED";
      
      g_TradeContext.PriceActionScore = 10;
      return patternName + " pattern detected - PASSED";
   }
   
   //+------------------------------------------------------------------+
   //| Get pattern name from type                                     |
   //+------------------------------------------------------------------+
   string GetPatternName(int patternType)
   {
      switch (patternType)
      {
         case 1: return "Bullish Engulfing";
         case 2: return "Bearish Engulfing";
         case 3: return "Bullish Pin Bar";
         case 4: return "Bearish Pin Bar";
         case 5: return "Bullish Rejection";
         case 6: return "Bearish Rejection";
         case 7: return "Bullish Momentum";
         case 8: return "Bearish Momentum";
         case 9: return "Inside Bar Breakout";
         default: return "Unknown Pattern";
      }
   }
   
   //+------------------------------------------------------------------+
   //| Set bullish only mode                                          |
   //+------------------------------------------------------------------+
   void SetBullishOnly(bool value)
   {
      this.m_BullishOnly = value;
   }
   
   //+------------------------------------------------------------------+
   //| Set bearish only mode                                          |
   //+------------------------------------------------------------------+
   void SetBearishOnly(bool value)
   {
      this.m_BearishOnly = value;
   }
};

//+------------------------------------------------------------------+
//| Helper function to create price action filter                   |
//+------------------------------------------------------------------+
CPriceActionFilter CreatePriceActionFilter(int tf = PERIOD_M5, int maxIndex = 2, bool bullishOnly = false, bool bearishOnly = false)
{
   return CPriceActionFilter(tf, maxIndex, bullishOnly, bearishOnly);
}
//+------------------------------------------------------------------+
