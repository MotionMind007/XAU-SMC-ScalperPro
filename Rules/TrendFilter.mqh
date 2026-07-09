//+------------------------------------------------------------------+
//|                                                       TrendFilter.mqh |
//|                        XAU SMC Scalper Pro - Rules Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include "IRule.mqh"

//+------------------------------------------------------------------+
//| Trend Filter Rule                                                |
//+------------------------------------------------------------------+
// Validates trend direction on H1 and M15 timeframes
// Only allows trades in the direction of higher timeframe trend
//+------------------------------------------------------------------+

class CTrendFilter : public IRule
{
private:
   int m_TF_High;          // Higher timeframe (H1)
   int m_TF_Low;           // Lower timeframe (M15)
   bool m_BullishOnly;
   bool m_BearishOnly;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void CTrendFilter(int tfHigh = PERIOD_H1, int tfLow = PERIOD_M15)
   {
      this.m_TF_High = tfHigh;
      this.m_TF_Low = tfLow;
      this.m_BullishOnly = false;
      this.m_BearishOnly = false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if trend rule passed                                     |
   //+------------------------------------------------------------------+
   bool Check()
   {
      // Get trend from TradeContext
      int currentTrend = g_TradeContext.CurrentTrend;
      
      if (currentTrend == 0)
         return false;
      
      if (this.m_BullishOnly && currentTrend != 1)
         return false;
      
      if (this.m_BearishOnly && currentTrend != -1)
         return false;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get rule name                                                  |
   //+------------------------------------------------------------------+
   string Name()
   {
      return "TrendFilter";
   }
   
   //+------------------------------------------------------------------+
   //| Get rule weight                                                |
   //+------------------------------------------------------------------+
   double Weight()
   {
      return 20.0;  // 20 points in confidence score
   }
   
   //+------------------------------------------------------------------+
   //| Get reason for pass/fail                                       |
   //+------------------------------------------------------------------+
   string Reason()
   {
      int currentTrend = g_TradeContext.CurrentTrend;
      
      if (currentTrend == 1)
         return "H1 Trend: BULLISH - PASSED";
      
      if (currentTrend == -1)
         return "H1 Trend: BEARISH - PASSED";
      
      if (currentTrend == 0)
         return "H1 Trend: NONE - FAILED";
      
      return "Trend validation inconclusive";
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
//| Helper function to create trend filter                          |
//+------------------------------------------------------------------+
CTrendFilter CreateTrendFilter(int tfHigh = PERIOD_H1, int tfLow = PERIOD_M15)
{
   return CTrendFilter(tfHigh, tfLow);
}
//+------------------------------------------------------------------+
