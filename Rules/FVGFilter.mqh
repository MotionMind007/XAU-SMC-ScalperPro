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
#include "DataCache.mqh"

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
   bool m_RequireFreshOnly;
   double m_MaxFVGSize;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void CFVGFilter(int tf = PERIOD_M5, bool requireFreshOnly = true, double maxFVGSize = 50.0)
   {
      this.m_Timeframe = tf;
      this.m_RequireFreshOnly = requireFreshOnly;
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
         
         // Skip if not fresh and we require fresh only
         if (this.m_RequireFreshOnly && fvg.Status != FVG_FRESH)
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
            
            if (this.m_RequireFreshOnly && fvg.Status != FVG_FRESH)
               continue;
            
            double fvgSize = fvg.SizeInPoints();
            if (fvgSize > this.m_MaxFVGSize)
               continue;
            
            double fvgCenter = (fvg.StartPrice + fvg.EndPrice) / 2;
            double distance = MathAbs(currentPrice - fvgCenter) / _Point;
            
            if (distance <= 15)
            {
               g_TradeContext.FVGScore = 10;
               return "Fresh/Pending FVG detected - PASSED";
            }
         }
      }
      
      return "No fresh FVG in range - FAILED";
   }
   
   //+------------------------------------------------------------------+
   //| Set require fresh only flag                                    |
   //+------------------------------------------------------------------+
   void SetRequireFreshOnly(bool value)
   {
      this.m_RequireFreshOnly = value;
   }
};

//+------------------------------------------------------------------+
//| Helper function to create FVG filter                            |
//+------------------------------------------------------------------+
CFVGFilter CreateFVGFilter(int tf = PERIOD_M5, bool requireFreshOnly = true, double maxFVGSize = 50.0)
{
   return CFVGFilter(tf, requireFreshOnly, maxFVGSize);
}
//+------------------------------------------------------------------+
