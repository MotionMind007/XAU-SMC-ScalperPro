#ifndef __RULES_FVGFILTER_MHQ__
#define __RULES_FVGFILTER_MHQ__
//+------------------------------------------------------------------+
//|                                                         FVGFilter.mqh |
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
//| Fair Value Gap (FVG) Filter Rule                                |
//+------------------------------------------------------------------+
// Validates that a fresh or partially filled FVG exists at the entry level
// FVGs represent market inefficiencies that price tends to fill
//+------------------------------------------------------------------+

class CFVGFilter : public IRule
{
private:
   int m_Timeframe;
   bool m_AllowPartial;      // Allow partial FVGs in addition to fresh
   double m_MaxFVGSize;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void CFVGFilter(int tf = PERIOD_M5, bool allowPartial = true, double maxFVGSize = 50.0)
   {
      this.m_Timeframe = tf;
      this.m_AllowPartial = allowPartial;
      this.m_MaxFVGSize = maxFVGSize;
   }
   
   //+------------------------------------------------------------------+
   //| Check if FVG rule passed                                       |
   //+------------------------------------------------------------------+
   bool Check()
   {
      int currentTrend = g_TradeContext.CurrentTrend;
      
      if (currentTrend == 0)
         return false;
      
      bool bullish = (currentTrend == 1);
      
      // Get fresh FVGs from cache
      Array<FVG> freshFVGs = g_DataCache.FreshFVG;
      
      if (freshFVGs.Total() == 0)
         return false;
      
      // Check if any fresh FVG is within acceptable range of current price
      double currentPrice = bullish ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      for (int i = 0; i < freshFVGs.Total(); i++)
      {
         FVG fvg = freshFVGs[i];
         
         // Skip partial FVGs if partials are not allowed
         if (!this.m_AllowPartial && fvg.Status != FVG_FRESH)
            continue;
         
         // Only accept fresh or partial FVGs (skip fully filled)
         if (fvg.Status != FVG_FRESH && fvg.Status != FVG_PARTIAL)
            continue;
         
         // Check FVG size
         double fvgSize = fvg.SizeInPoints();
         if (fvgSize > this.m_MaxFVGSize)
            continue;
         
         // Check if price is near or within FVG
         double fvgCenter = (fvg.StartPrice + fvg.EndPrice) / 2;
         double distance = MathAbs(currentPrice - fvgCenter) / _Point;
         
         // Allow entry if price is within FVG or slightly beyond
         if (distance <= 15)  // 15 points tolerance
         {
            g_TradeContext.FVGScore = 10;
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
      return "FVGFilter";
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
      int currentTrend = g_TradeContext.CurrentTrend;
      
      if (currentTrend == 0)
         return "No valid trend direction - FAILED";
      
      bool bullish = (currentTrend == DIRECTION_BUY);
      
      Array<FVG> freshFVGs = g_DataCache.FreshFVG;
      
      if (freshFVGs.Total() > 0)
      {
         double currentPrice = bullish ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         for (int i = 0; i < freshFVGs.Total(); i++)
         {
            FVG fvg = freshFVGs[i];
            
            // Skip partial FVGs if partials are not allowed
            if (!this.m_AllowPartial && fvg.Status != FVG_FRESH)
               continue;
            
            // Only accept fresh or partial FVGs (skip fully filled)
            if (fvg.Status != FVG_FRESH && fvg.Status != FVG_PARTIAL)
               continue;
            
            double fvgSize = fvg.SizeInPoints();
            if (fvgSize > this.m_MaxFVGSize)
               continue;
            
            double fvgCenter = (fvg.StartPrice + fvg.EndPrice) / 2;
            double distance = MathAbs(currentPrice - fvgCenter) / _Point;
            
            if (distance <= 15)
            {
               g_TradeContext.FVGScore = 10;
               if (fvg.Status == FVG_FRESH)
                  return "Fresh FVG detected - PASSED";
               else
                  return "Partial FVG detected - PASSED";
            }
         }
      }
      
      return "No fresh FVG in range - FAILED";
   }
   
   //+------------------------------------------------------------------+
   //| Set require fresh only flag                                    |
   //+------------------------------------------------------------------+
   void SetAllowPartial(bool value)
   {
      this.m_AllowPartial = value;
   }
};

//+------------------------------------------------------------------+
//| Helper function to create FVG filter                            |
//+------------------------------------------------------------------+
CFVGFilter CreateFVGFilter(int tf = PERIOD_M5, bool allowPartial = true, double maxFVGSize = 50.0)
{
   return CFVGFilter(tf, allowPartial, maxFVGSize);
}
//+------------------------------------------------------------------+

#endif // __RULES_FVGFILTER_MHQ__
