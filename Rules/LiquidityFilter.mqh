//+------------------------------------------------------------------+
//|                                                   LiquidityFilter.mqh |
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
//| Liquidity Filter Rule                                           |
//+------------------------------------------------------------------+
// Validates that liquidity has been swept before entry
// Liquidity grab confirms institutional participation
//+------------------------------------------------------------------+

class CLiquidityFilter : public IRule
{
private:
   int m_Timeframe;
   bool m_RequireLiquiditySweep;
   double m_SweepTolerance;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void CLiquidityFilter(int tf = PERIOD_M15, bool requireSweep = true, double sweepTolerance = 5.0)
   {
      this.m_Timeframe = tf;
      this.m_RequireLiquiditySweep = requireSweep;
      this.m_SweepTolerance = sweepTolerance;
   }
   
   //+------------------------------------------------------------------+
   //| Check if liquidity rule passed                                |
   //+------------------------------------------------------------------+
   bool Check()
   {
      // If liquidity sweep not required, pass
      if (!this.m_RequireLiquiditySweep)
         return true;
      
      // Get liquidity sweeps from cache
      Array<LiquidityLevel> sweeps = g_DataCache.LiquiditySweeps;
      
      if (sweeps.Total() == 0)
         return false;
      
      // Check if recent liquidity was swept
      datetime now = TimeCurrent();
      datetime recentLimit = now - 30 * PeriodSeconds(this.m_Timeframe);  // Last 30 bars
      
      for (int i = 0; i < sweeps.Total(); i++)
      {
         LiquidityLevel sweep = sweeps[i];
         
         if (sweep.Time >= recentLimit)
         {
            double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            
            if (sweep.Type == LIQUIDITY_SWEEP_HIGH && currentBid > sweep.Price)
            {
               g_TradeContext.LiquidityScore = 15;
               return true;
            }
            
            if (sweep.Type == LIQUIDITY_SWEEP_LOW && currentAsk < sweep.Price)
            {
               g_TradeContext.LiquidityScore = 15;
               return true;
            }
         }
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Get rule name                                                  |
   //+------------------------------------------------------------------+
   string Name()
   {
      return "LiquidityFilter";
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
      if (!this.m_RequireLiquiditySweep)
         return "Liquidity sweep not required - PASSED";
      
      Array<LiquidityLevel> sweeps = g_DataCache.LiquiditySweeps;
      
      if (sweeps.Total() > 0)
      {
         datetime now = TimeCurrent();
         datetime recentLimit = now - 30 * PeriodSeconds(this.m_Timeframe);
         
         for (int i = 0; i < sweeps.Total(); i++)
         {
            LiquidityLevel sweep = sweeps[i];
            
            if (sweep.Time >= recentLimit)
            {
               double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               
               if (sweep.Type == LIQUIDITY_SWEEP_HIGH && currentBid > sweep.Price)
                  return "Liquidity sweep (high) detected - PASSED";
               
               if (sweep.Type == LIQUIDITY_SWEEP_LOW && currentAsk < sweep.Price)
                  return "Liquidity sweep (low) detected - PASSED";
            }
         }
      }
      
      return "No recent liquidity sweep detected - FAILED";
   }
};

//+------------------------------------------------------------------+
//| Helper function to create liquidity filter                      |
//+------------------------------------------------------------------+
CLiquidityFilter CreateLiquidityFilter(int tf = PERIOD_M15, bool requireSweep = true, double sweepTolerance = 5.0)
{
   return CLiquidityFilter(tf, requireSweep, sweepTolerance);
}
//+------------------------------------------------------------------+
