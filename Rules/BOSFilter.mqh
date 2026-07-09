//+------------------------------------------------------------------+
//|                                                       BOSFilter.mqh |
//|                        XAU SMC Scalper Pro - Rules Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include "IRule.mqh"
#include "..\\Core\\DataCache.mqh"

//+------------------------------------------------------------------+
//| Break of Structure (BOS) Filter Rule                            |
//+------------------------------------------------------------------+
// Validates that a valid BOS has occurred in the current direction
// BOS confirms the trend continuation after a retracement
//+------------------------------------------------------------------+

class CBOSFilter : public IRule
{
private:
   int m_Timeframe;
   int m_SwingLookback;
   bool m_RequireFreshBOS;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void CBOSFilter(int tf = PERIOD_M15, int swingLookback = 5, bool requireFresh = true)
   {
      this.m_Timeframe = tf;
      this.m_SwingLookback = swingLookback;
      this.m_RequireFreshBOS = requireFresh;
   }
   
   //+------------------------------------------------------------------+
   //| Check if BOS rule passed                                       |
   //+------------------------------------------------------------------+
   bool Check()
   {
      // Get swing points from cache
      Array<SwingPoint> swingHighs = g_DataCache.SwingHighs;
      Array<SwingPoint> swingLows = g_DataCache.SwingLows;
      
      if (swingHighs.Total() < 2 || swingLows.Total() < 2)
         return false;
      
      int currentTrend = g_TradeContext.CurrentTrend;
      
      if (currentTrend == 1)
      {
         // Looking for bullish BOS (close above previous swing high)
         SwingPoint lastSwingHigh = swingHighs[0];
         double close = g_TradeContext.M15Rates[0].close;
         
         if (close > lastSwingHigh.Price)
         {
            g_TradeContext.StructureScore = 15;
            return true;
         }
      }
      else if (currentTrend == -1)
      {
         // Looking for bearish BOS (close below previous swing low)
         SwingPoint lastSwingLow = swingLows[0];
         double close = g_TradeContext.M15Rates[0].close;
         
         if (close < lastSwingLow.Price)
         {
            g_TradeContext.StructureScore = 15;
            return true;
         }
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Get rule name                                                  |
   //+------------------------------------------------------------------+
   string Name()
   {
      return "BOSFilter";
   }
   
   //+------------------------------------------------------------------+
   //| Get rule weight                                                |
   //+------------------------------------------------------------------+
   double Weight()
   {
      return 15.0;  // 15 points in confidence score
   }
   
   //+------------------------------------------------------------------+
   //| Get reason for pass/fail                                       |
   //+------------------------------------------------------------------+
   string Reason()
   {
      int currentTrend = g_TradeContext.CurrentTrend;
      Array<SwingPoint> swingHighs = g_DataCache.SwingHighs;
      Array<SwingPoint> swingLows = g_DataCache.SwingLows;
      
      if (currentTrend == 1)
      {
         if (swingHighs.Total() > 0)
         {
            double close = g_TradeContext.M15Rates[0].close;
            if (close > swingHighs[0].Price)
               return "Bullish BOS confirmed - PASSED";
         }
         return "No bullish BOS detected - FAILED";
      }
      else if (currentTrend == -1)
      {
         if (swingLows.Total() > 0)
         {
            double close = g_TradeContext.M15Rates[0].close;
            if (close < swingLows[0].Price)
               return "Bearish BOS confirmed - PASSED";
         }
         return "No bearish BOS detected - FAILED";
      }
      
      return "Invalid trend direction for BOS check";
   }
};

//+------------------------------------------------------------------+
//| Helper function to create BOS filter                            |
//+------------------------------------------------------------------+
CBOSFilter CreateBOSFilter(int tf = PERIOD_M15, int swingLookback = 5, bool requireFresh = true)
{
   return CBOSFilter(tf, swingLookback, requireFresh);
}
//+------------------------------------------------------------------+
