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
#include "..\\Core\\TradeContext.mqh"
#include "..\\Services\\NewsService.mqh"

//+------------------------------------------------------------------+
//| News Filter Rule - Blocks trading during high-impact news      |
//+------------------------------------------------------------------+
class CNewsFilter : public IRule
{
private:
   int m_BeforeMinutes;
   int m_AfterMinutes;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void CNewsFilter(int beforeMinutes = 30, int afterMinutes = 30)
   {
      this.m_BeforeMinutes = beforeMinutes;
      this.m_AfterMinutes = afterMinutes;
   }
   
   //+------------------------------------------------------------------+
   //| Check if news rule passed                                      |
   //+------------------------------------------------------------------+
   bool Check()
   {
      // Delegate to NewsService
      return !IsNewsActive();
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
      return 10.0;  // 10 points in confidence score
   }
   
   //+------------------------------------------------------------------+
   //| Get reason for pass/fail                                       |
   //+------------------------------------------------------------------+
   string Reason()
   {
      if (IsNewsActive())
      {
         datetime nextNews = GetNextHighImpactNews();
         if (nextNews > 0)
            return "High-impact news active until " + TimeToString(nextNews + this.m_AfterMinutes * 60) + " - FAILED";
         return "High-impact news currently active - FAILED";
      }
      
      int timeUntilNews = GetTimeUntilNextNews();
      if (timeUntilNews > 0 && timeUntilNews <= this.m_BeforeMinutes)
         return "High-impact news in " + IntegerToString(timeUntilNews) + " minutes - FAILED";
      
      return "No high-impact news in the next " + IntegerToString(this.m_BeforeMinutes) + " minutes - PASSED";
   }
};
//+------------------------------------------------------------------+
