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
      // Get trends from TradeContext
      int h1Trend = g_TradeContext.CurrentTrend;
      int m15Trend = g_TradeContext.CurrentTrendM15;
      
      // H1 must have a clear direction (no trade if H1 neutral)
      if (h1Trend == DIRECTION_NONE)
         return false;
      
      // For BUY: H1 must be bullish, M15 must be bullish or neutral
      if (h1Trend == DIRECTION_BUY)
      {
         if (m15Trend == DIRECTION_SELL)
            return false;  // M15 disagrees - filter fails
         
         if (this.m_BullishOnly && h1Trend != DIRECTION_BUY)
            return false;
         
         if (this.m_BearishOnly)
            return false;
         
         return true;
      }
      
      // For SELL: H1 must be bearish, M15 must be bearish or neutral
      if (h1Trend == DIRECTION_SELL)
      {
         if (m15Trend == DIRECTION_BUY)
            return false;  // M15 disagrees - filter fails
         
         if (this.m_BullishOnly)
            return false;
         
         if (this.m_BearishOnly && h1Trend != DIRECTION_SELL)
            return false;
         
         return true;
      }
      
      return false;
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
      int h1Trend = g_TradeContext.CurrentTrend;
      int m15Trend = g_TradeContext.CurrentTrendM15;
      
      string h1Str = (h1Trend == DIRECTION_BUY) ? "BULLISH" :
                      (h1Trend == DIRECTION_SELL) ? "BEARISH" : "NONE";
      string m15Str = (m15Trend == DIRECTION_BUY) ? "BULLISH" :
                       (m15Trend == DIRECTION_SELL) ? "BEARISH" : "NONE";
      
      if (h1Trend == DIRECTION_NONE)
         return StringFormat("H1 Trend: %s - FAILED (no trend)", h1Str);
      
      // Check for disagreement
      if ((h1Trend == DIRECTION_BUY && m15Trend == DIRECTION_SELL) ||
          (h1Trend == DIRECTION_SELL && m15Trend == DIRECTION_BUY))
         return StringFormat("H1: %s, M15: %s - FAILED (trend mismatch)", h1Str, m15Str);
      
      return StringFormat("H1: %s, M15: %s - PASSED", h1Str, m15Str);
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
