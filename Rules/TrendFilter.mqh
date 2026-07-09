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
//| Trend H1 Filter Rule                                             |
//+------------------------------------------------------------------+
// Validates trend direction on H1 timeframe only
// Awards 20 points when H1 has a clear bullish/bearish trend
// PRD §14: Trend H1 = 20 points
//+------------------------------------------------------------------+

class CTrendH1Filter : public IRule
{
private:
   bool m_BullishOnly;
   bool m_BearishOnly;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void CTrendH1Filter()
   {
      this.m_BullishOnly = false;
      this.m_BearishOnly = false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if H1 trend rule passed                                  |
   //+------------------------------------------------------------------+
   bool Check()
   {
      int h1Trend = g_TradeContext.CurrentTrend;
      
      // H1 must have a clear direction (no trade if H1 neutral)
      if (h1Trend == DIRECTION_NONE)
         return false;
      
      if (this.m_BullishOnly && h1Trend != DIRECTION_BUY)
         return false;
      
      if (this.m_BearishOnly && h1Trend != DIRECTION_SELL)
         return false;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get rule name                                                  |
   //+------------------------------------------------------------------+
   string Name()
   {
      return "TrendH1Filter";
   }
   
   //+------------------------------------------------------------------+
   //| Get rule weight                                                |
   //+------------------------------------------------------------------+
   double Weight()
   {
      return (double)g_Parameters.TrendH1Weight;  // 20 points
   }
   
   //+------------------------------------------------------------------+
   //| Get reason for pass/fail                                       |
   //+------------------------------------------------------------------+
   string Reason()
   {
      int h1Trend = g_TradeContext.CurrentTrend;
      
      string h1Str = (h1Trend == DIRECTION_BUY) ? "BULLISH" :
                      (h1Trend == DIRECTION_SELL) ? "BEARISH" : "NONE";
      
      if (h1Trend == DIRECTION_NONE)
         return StringFormat("H1 Trend: %s - FAILED (no trend)", h1Str);
      
      return StringFormat("H1 Trend: %s - PASSED", h1Str);
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
//| Trend M15 Filter Rule                                            |
//+------------------------------------------------------------------+
// Validates M15 trend alignment with H1
// Awards 10 points when M15 is aligned or neutral (not counter-trend)
// PRD §14: Trend M15 = 10 points
//+------------------------------------------------------------------+

class CTrendM15Filter : public IRule
{
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void CTrendM15Filter()
   {
   }
   
   //+------------------------------------------------------------------+
   //| Check if M15 trend alignment rule passed                       |
   //+------------------------------------------------------------------+
   bool Check()
   {
      int h1Trend = g_TradeContext.CurrentTrend;
      int m15Trend = g_TradeContext.CurrentTrendM15;
      
      // If H1 has no trend, M15 alignment is irrelevant (handled by H1 filter)
      if (h1Trend == DIRECTION_NONE)
         return false;
      
      // M15 must not counter H1 direction
      // For BUY on H1: M15 must not be SELL
      if (h1Trend == DIRECTION_BUY && m15Trend == DIRECTION_SELL)
         return false;
      
      // For SELL on H1: M15 must not be BUY
      if (h1Trend == DIRECTION_SELL && m15Trend == DIRECTION_BUY)
         return false;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get rule name                                                  |
   //+------------------------------------------------------------------+
   string Name()
   {
      return "TrendM15Filter";
   }
   
   //+------------------------------------------------------------------+
   //| Get rule weight                                                |
   //+------------------------------------------------------------------+
   double Weight()
   {
      return (double)g_Parameters.TrendM15Weight;  // 10 points
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
      
      if ((h1Trend == DIRECTION_BUY && m15Trend == DIRECTION_SELL) ||
          (h1Trend == DIRECTION_SELL && m15Trend == DIRECTION_BUY))
         return StringFormat("H1: %s, M15: %s - FAILED (trend mismatch)", h1Str, m15Str);
      
      return StringFormat("H1: %s, M15: %s - PASSED", h1Str, m15Str);
   }
};

//+------------------------------------------------------------------+
//| Helper functions to create trend filters                         |
//+------------------------------------------------------------------+
CTrendH1Filter CreateTrendH1Filter()
{
   return CTrendH1Filter();
}

CTrendM15Filter CreateTrendM15Filter()
{
   return CTrendM15Filter();
}
//+------------------------------------------------------------------+
