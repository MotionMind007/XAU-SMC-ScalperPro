//+------------------------------------------------------------------+
//|                                                     ATRFilter.mqh |
//|                        XAU SMC Scalper Pro - Rules Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include "IRule.mqh"

//+------------------------------------------------------------------+
//| ATR Filter Rule                                                   |
//+------------------------------------------------------------------+
// Validates ATR is in normal trading range (3.0-40.0)
// Awards 5 points to confidence score when ATR is acceptable
//+------------------------------------------------------------------+

class CATRFilter : public IRule
{
private:
   double m_MinATR;
   double m_MaxATR;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void CATRFilter(double minATR = 3.0, double maxATR = 40.0)
   {
      this.m_MinATR = minATR;
      this.m_MaxATR = maxATR;
   }
   
   //+------------------------------------------------------------------+
   //| Check if ATR rule passed                                       |
   //+------------------------------------------------------------------+
   bool Check()
   {
      double atr = g_TradeContext.ATR_14;
      
      if (atr <= 0)
      {
         g_TradeContext.ATRScore = 0;
         return false;
      }
      
      if (atr >= this.m_MinATR && atr <= this.m_MaxATR)
      {
         // ATR is in normal range - award score
         g_TradeContext.ATRScore = (int)g_Parameters.ATRWeight;
         return true;
      }
      else
      {
         // ATR out of range - no score
         g_TradeContext.ATRScore = 0;
         return false;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get rule name                                                  |
   //+------------------------------------------------------------------+
   string Name()
   {
      return "ATRFilter";
   }
   
   //+------------------------------------------------------------------+
   //| Get rule weight                                                |
   //+------------------------------------------------------------------+
   double Weight()
   {
      return g_Parameters.ATRWeight;
   }
   
   //+------------------------------------------------------------------+
   //| Get reason for pass/fail                                       |
   //+------------------------------------------------------------------+
   string Reason()
   {
      double atr = g_TradeContext.ATR_14;
      
      if (atr <= 0)
         return "ATR Score: 0 - ATR not available";
      
      if (atr >= this.m_MinATR && atr <= this.m_MaxATR)
         return StringFormat("ATR Score: %.2f - Normal range [%.1f-%.1f] - PASSED", atr, this.m_MinATR, this.m_MaxATR);
      else
         return StringFormat("ATR Score: %.2f - Out of range [%.1f-%.1f] - FAILED", atr, this.m_MinATR, this.m_MaxATR);
   }
};

//+------------------------------------------------------------------+
//| Helper function to create ATR filter                             |
//+------------------------------------------------------------------+
CATRFilter CreateATRFilter(double minATR = 3.0, double maxATR = 40.0)
{
   return CATRFilter(minATR, maxATR);
}
//+------------------------------------------------------------------+
