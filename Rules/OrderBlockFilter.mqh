//+------------------------------------------------------------------+
//|                                                 OrderBlockFilter.mqh |
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
//| Order Block Filter Rule                                         |
//+------------------------------------------------------------------+
// Validates that a fresh order block exists at the entry level
// Order blocks represent areas of institutional demand/supply
//+------------------------------------------------------------------+

class COrderBlockFilter : public IRule
{
private:
   int m_Timeframe;
   bool m_BullishOnly;
   bool m_BearishOnly;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void COrderBlockFilter(int tf = PERIOD_M15, bool bullishOnly = false, bool bearishOnly = false)
   {
      this.m_Timeframe = tf;
      this.m_BullishOnly = bullishOnly;
      this.m_BearishOnly = bearishOnly;
   }
   
   //+------------------------------------------------------------------+
   //| Check if order block rule passed                              |
   //+------------------------------------------------------------------+
   bool Check()
   {
      int currentTrend = g_TradeContext.CurrentTrend;
      
      if (currentTrend == 0)
         return false;
      
      bool bullish = (currentTrend == 1);
      
      if (this.m_BullishOnly && !bullish)
         return false;
      
      if (this.m_BearishOnly && bullish)
         return false;
      
      // Get fresh order blocks from cache
      Array<OrderBlock> freshOBs = bullish ? g_DataCache.FreshOB_Bullish : g_DataCache.FreshOB_Bearish;
      
      if (freshOBs.Total() == 0)
         return false;
      
      // Check if any fresh OB is within acceptable range of current price
      double currentPrice = bullish ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      for (int i = 0; i < freshOBs.Total(); i++)
      {
         OrderBlock ob = freshOBs[i];
         
         // Check if price is near or within OB
         double obCenter = (ob.StartPrice + ob.EndPrice) / 2;
         double distance = MathAbs(currentPrice - obCenter) / _Point;
         
         // Allow entry if price is within OB or slightly beyond (for breakout entries)
         if (distance <= 20)  // 20 points tolerance
         {
            g_TradeContext.OBScore = 15;
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
      return "OrderBlockFilter";
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
      bool bullish = (currentTrend == 1);
      
      if (currentTrend == 0)
         return "No valid trend direction - FAILED";
      
      Array<OrderBlock> freshOBs = bullish ? g_DataCache.FreshOB_Bullish : g_DataCache.FreshOB_Bearish;
      
      if (freshOBs.Total() > 0)
      {
         double currentPrice = bullish ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         for (int i = 0; i < freshOBs.Total(); i++)
         {
            OrderBlock ob = freshOBs[i];
            double obCenter = (ob.StartPrice + ob.EndPrice) / 2;
            double distance = MathAbs(currentPrice - obCenter) / _Point;
            
            if (distance <= 20)
            {
               g_TradeContext.OBScore = 15;
               return "Fresh Order Block detected - PASSED";
            }
         }
      }
      
      return "No fresh Order Block in range - FAILED";
   }
};

//+------------------------------------------------------------------+
//| Helper function to create OB filter                             |
//+------------------------------------------------------------------+
COrderBlockFilter CreateOrderBlockFilter(int tf = PERIOD_M15, bool bullishOnly = false, bool bearishOnly = false)
{
   return COrderBlockFilter(tf, bullishOnly, bearishOnly);
}
//+------------------------------------------------------------------+
