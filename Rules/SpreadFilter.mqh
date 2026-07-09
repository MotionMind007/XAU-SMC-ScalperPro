//+------------------------------------------------------------------+
//|                                                     SpreadFilter.mqh |
//|                        XAU SMC Scalper Pro - Rules Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include "IRule.mqh"

//+------------------------------------------------------------------+
//| Spread Filter Rule                                              |
//+------------------------------------------------------------------+
// Validates that spread is within acceptable limits
// High spread reduces profitability and increases execution risk
//+------------------------------------------------------------------+

class CSpreadFilter : public IRule
{
private:
   double m_MaxSpreadRatio;
   int m_MinBarsForAverage;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void CSpreadFilter(double maxSpreadRatio = 20.0, int minBars = 10)
   {
      this.m_MaxSpreadRatio = maxSpreadRatio;
      this.m_MinBarsForAverage = minBars;
   }
   
   //+------------------------------------------------------------------+
   //| Check if spread rule passed                                    |
   //+------------------------------------------------------------------+
   bool Check()
   {
      // Get current spread
      double currentSpread = g_TradeContext.CurrentSpread;
      
      if (currentSpread <= 0)
         return false;
      
      // Get spread ratio
      double spreadRatio = g_TradeContext.SpreadRatio;
      
      // Check against threshold
      return (spreadRatio <= this.m_MaxSpreadRatio);
   }
   
   //+------------------------------------------------------------------+
   //| Get rule name                                                  |
   //+------------------------------------------------------------------+
   string Name()
   {
      return "SpreadFilter";
   }
   
   //+------------------------------------------------------------------+
   //| Get rule weight                                                |
   //+------------------------------------------------------------------+
   double Weight()
   {
      return 5.0;  // 5 points in confidence score
   }
   
   //+------------------------------------------------------------------+
   //| Get reason for pass/fail                                       |
   //+------------------------------------------------------------------+
   string Reason()
   {
      double spreadRatio = g_TradeContext.SpreadRatio;
      
      if (spreadRatio <= 10.0)
         return StringFormat("Spread ratio: %.1f%% (Excellent) - PASSED", spreadRatio);
      else if (spreadRatio <= 15.0)
         return StringFormat("Spread ratio: %.1f%% (Good) - PASSED", spreadRatio);
      else if (spreadRatio <= 20.0)
         return StringFormat("Spread ratio: %.1f%% (Acceptable) - PASSED", spreadRatio);
      else
         return StringFormat("Spread ratio: %.1f%% (Too High) - FAILED", spreadRatio);
   }
};

//+------------------------------------------------------------------+
//| Helper function to create spread filter                         |
//+------------------------------------------------------------------+
CSpreadFilter CreateSpreadFilter(double maxSpreadRatio = 20.0, int minBars = 10)
{
   return CSpreadFilter(maxSpreadRatio, minBars);
}
//+------------------------------------------------------------------+
