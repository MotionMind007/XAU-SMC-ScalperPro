//+------------------------------------------------------------------+
//|                                                      NewsFilter.mqh |
//|                        XAU SMC Scalper Pro - Rules Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include "IRule.mqh"

//+------------------------------------------------------------------+
//| News Filter Rule                                                |
//+------------------------------------------------------------------+
// Validates that no high impact news is active
// News events cause high volatility and spread spikes
//+------------------------------------------------------------------+

class CNewsFilter : public IRule
{
private:
   int m_BeforeEventMinutes;
   int m_AfterEventMinutes;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void CNewsFilter(int beforeMinutes = 30, int afterMinutes = 30)
   {
      this.m_BeforeEventMinutes = beforeMinutes;
      this.m_AfterEventMinutes = afterMinutes;
   }
   
   //+------------------------------------------------------------------+
   //| Check if news rule passed                                      |
   //+------------------------------------------------------------------+
   bool Check()
   {
      // Check if news is active from TradeContext
      bool newsActive = g_TradeContext.NewsActive;
      
      return !newsActive;
   }
   
   //+------------------------------------------------------------------+
   //| Get rule name                                                  |
   //+------------------------------------------------------------------+
   string Name()
   {
      return "NewsFilter";
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
      bool newsActive = g_TradeContext.NewsActive;
      
      if (newsActive)
         return "High impact news active - FAILED";
      
      return "No high impact news - PASSED";
   }
};

//+------------------------------------------------------------------+
//| Helper function to create news filter                           |
//+------------------------------------------------------------------+
CNewsFilter CreateNewsFilter(int beforeMinutes = 30, int afterMinutes = 30)
{
   return CNewsFilter(beforeMinutes, afterMinutes);
}
//+------------------------------------------------------------------+
