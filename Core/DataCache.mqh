//+------------------------------------------------------------------+
//|                                                        DataCache.mqh |
//|                        XAU SMC Scalper Pro - Core Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include "Models\Swing.mqh"
#include "Models\OrderBlockModel.mqh"
#include "Models\LiquidityModel.mqh"
#include "Models\ScoreModel.mqh"
#include "TradeContext.mqh"

//+------------------------------------------------------------------+
//| Data Cache Structure - Cached Analysis Results                  |
//+------------------------------------------------------------------+
struct DataCache
{
   // === Swing Points ===
   Array<SwingPoint> SwingHighs;
   Array<SwingPoint> SwingLows;
   int LastSwingUpdate;
   
   // === Order Blocks ===
   Array<OrderBlock> FreshOB_Bullish;
   Array<OrderBlock> FreshOB_Bearish;
   Array<OrderBlock> MitigatedOB;
   int LastOBUpdate;
   
   // === Liquidity ===
   Array<LiquidityLevel> LiquidityLevels;
   Array<LiquidityLevel> LiquiditySweeps;
   double BuySideLiquidity;
   double SellSideLiquidity;
   int LastLiquidityUpdate;
   
   // === Fair Value Gaps ===
   Array<FVG> FreshFVG;
   Array<FVG> PartialFVG;
   Array<FVG> FilledFVG;
   int LastFVGUpdate;
   
   // === Internal State ===
   datetime LastCandleUpdate;
   bool IsCacheFresh;
   
   //+------------------------------------------------------------------+
   //| Default constructor                                             |
   //+------------------------------------------------------------------+
   void DataCache()
   {
      this.Reset();
   }
   
   //+------------------------------------------------------------------+
   //| Reset cache to initial state                                    |
   //+------------------------------------------------------------------+
   void Reset()
   {
      this.SwingHighs.Clear();
      this.SwingLows.Clear();
      this.LastSwingUpdate = 0;
      
      this.FreshOB_Bullish.Clear();
      this.FreshOB_Bearish.Clear();
      this.MitigatedOB.Clear();
      this.LastOBUpdate = 0;
      
      this.LiquidityLevels.Clear();
      this.LiquiditySweeps.Clear();
      this.BuySideLiquidity = 0.0;
      this.SellSideLiquidity = 0.0;
      this.LastLiquidityUpdate = 0;
      
      this.FreshFVG.Clear();
      this.PartialFVG.Clear();
      this.FilledFVG.Clear();
      this.LastFVGUpdate = 0;
      
      this.LastCandleUpdate = 0;
      this.IsCacheFresh = false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if cache needs update (new candle detected)              |
   //+------------------------------------------------------------------+
   bool NeedsUpdate(int timeframe)
   {
      datetime currentCandle = iTime(_Symbol, timeframe, 0);
      
      if (currentCandle != this.LastCandleUpdate)
         return true;
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Update cache if new candle on specified timeframe              |
   //+------------------------------------------------------------------+
   bool UpdateIfNewCandle(int timeframe)
   {
      datetime currentCandle = iTime(_Symbol, timeframe, 0);
      
      // Check if new candle
      if (currentCandle == this.LastCandleUpdate)
         return true;  // Already updated for this candle
      
      this.LastCandleUpdate = currentCandle;
      this.IsCacheFresh = true;
      
      // Update all cached data
      if (!this.UpdateSwingPoints())
         return false;
      
      if (!this.UpdateOrderBlocks())
         return false;
      
      if (!this.UpdateLiquidity())
         return false;
      
      if (!this.UpdateFVG())
         return false;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Update swing points from M15 data                              |
   //+------------------------------------------------------------------+
   bool UpdateSwingPoints()
   {
      this.SwingHighs.Clear();
      this.SwingLows.Clear();
      
      // Get swing points using fractal method
      int count = ArraySize(g_TradeContext.M15Rates);
      if (count < 10)
         return true;  // Not enough data
      
      // Scan for swing highs (fractal pattern)
      for (int i = 3; i < count - 2; i++)
      {
         if (this.IsSwingHigh(i))
         {
            SwingPoint sp;
            sp.Type = SWING_HIGH;
            sp.Index = i;
            sp.Price = g_TradeContext.M15Rates[i].high;
            sp.Time = g_TradeContext.M15Rates[i].time;
            this.SwingHighs.Add(sp);
         }
      }
      
      // Scan for swing lows
      for (int i = 3; i < count - 2; i++)
      {
         if (this.IsSwingLow(i))
         {
            SwingPoint sp;
            sp.Type = SWING_LOW;
            sp.Index = i;
            sp.Price = g_TradeContext.M15Rates[i].low;
            sp.Time = g_TradeContext.M15Rates[i].time;
            this.SwingLows.Add(sp);
         }
      }
      
      this.LastSwingUpdate = TimeCurrent();
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Detect swing high at index i                                    |
   //+------------------------------------------------------------------+
   bool IsSwingHigh(int i)
   {
      if (i < 3 || i >= ArraySize(g_TradeContext.M15Rates) - 2)
         return false;
      
      double currentHigh = g_TradeContext.M15Rates[i].high;
      
      // Compare with 2 candles before and after
      if (currentHigh > g_TradeContext.M15Rates[i-1].high &&
          currentHigh > g_TradeContext.M15Rates[i-2].high &&
          currentHigh > g_TradeContext.M15Rates[i+1].high &&
          currentHigh > g_TradeContext.M15Rates[i+2].high)
         return true;
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Detect swing low at index i                                     |
   //+------------------------------------------------------------------+
   bool IsSwingLow(int i)
   {
      if (i < 3 || i >= ArraySize(g_TradeContext.M15Rates) - 2)
         return false;
      
      double currentLow = g_TradeContext.M15Rates[i].low;
      
      // Compare with 2 candles before and after
      if (currentLow < g_TradeContext.M15Rates[i-1].low &&
          currentLow < g_TradeContext.M15Rates[i-2].low &&
          currentLow < g_TradeContext.M15Rates[i+1].low &&
          currentLow < g_TradeContext.M15Rates[i+2].low)
         return true;
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Update order blocks                                             |
   //+------------------------------------------------------------------+
   bool UpdateOrderBlocks()
   {
      this.FreshOB_Bullish.Clear();
      this.FreshOB_Bearish.Clear();
      this.MitigatedOB.Clear();
      
      // Scan for OBs using M15 data
      int count = ArraySize(g_TradeContext.M15Rates);
      if (count < 20)
         return true;  // Not enough data
      
      // Look for OB patterns after structure changes
      for (int i = 15; i < count - 1; i++)
      {
         if (this.IsBullishOrderBlock(i))
         {
            OrderBlock ob;
            ob.Type = OB_BULLISH;
            ob.Index = i;
            ob.Bullish = true;
            ob.StartPrice = g_TradeContext.M15Rates[i+1].open;
            ob.EndPrice = g_TradeContext.M15Rates[i+1].close;
            ob.Body = MathAbs(ob.EndPrice - ob.StartPrice);
            ob.IsMitigated = false;
            this.FreshOB_Bullish.Add(ob);
         }
         
         if (this.IsBearishOrderBlock(i))
         {
            OrderBlock ob;
            ob.Type = OB_BEARISH;
            ob.Index = i;
            ob.Bullish = false;
            ob.StartPrice = g_TradeContext.M15Rates[i+1].open;
            ob.EndPrice = g_TradeContext.M15Rates[i+1].close;
            ob.Body = MathAbs(ob.EndPrice - ob.StartPrice);
            ob.IsMitigated = false;
            this.FreshOB_Bearish.Add(ob);
         }
      }
      
      this.LastOBUpdate = TimeCurrent();
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Detect bullish order block at index i                           |
   //+------------------------------------------------------------------+
   bool IsBullishOrderBlock(int i)
   {
      if (i >= ArraySize(g_TradeContext.M15Rates) - 1)
         return false;
      
      // Bullish OB: Last bearish candle before bullish impulse
      double currentClose = g_TradeContext.M15Rates[i].close;
      double currentOpen = g_TradeContext.M15Rates[i].open;
      
      // Check if current candle is bearish
      if (currentClose >= currentOpen)
         return false;
      
      // Check next candle is bullish impulse
      double nextClose = g_TradeContext.M15Rates[i+1].close;
      double nextOpen = g_TradeContext.M15Rates[i+1].open;
      
      if (nextClose > nextOpen && (nextClose - nextOpen) > (currentOpen - currentClose) * 0.5)
         return true;
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Detect bearish order block at index i                           |
   //+------------------------------------------------------------------+
   bool IsBearishOrderBlock(int i)
   {
      if (i >= ArraySize(g_TradeContext.M15Rates) - 1)
         return false;
      
      // Bearish OB: Last bullish candle before bearish impulse
      double currentClose = g_TradeContext.M15Rates[i].close;
      double currentOpen = g_TradeContext.M15Rates[i].open;
      
      // Check if current candle is bullish
      if (currentClose <= currentOpen)
         return false;
      
      // Check next candle is bearish impulse
      double nextClose = g_TradeContext.M15Rates[i+1].close;
      double nextOpen = g_TradeContext.M15Rates[i+1].open;
      
      if (nextClose < nextOpen && (nextOpen - nextClose) > (currentClose - currentOpen) * 0.5)
         return true;
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Update liquidity levels                                         |
   //+------------------------------------------------------------------+
   bool UpdateLiquidity()
   {
      this.LiquidityLevels.Clear();
      this.LiquiditySweeps.Clear();
      this.BuySideLiquidity = 0.0;
      this.SellSideLiquidity = 0.0;
      
      int count = ArraySize(g_TradeContext.M15Rates);
      if (count < 10)
         return true;
      
      // Find equal highs and equal lows
      for (int i = 0; i < count - 5; i++)
      {
         for (int j = i + 3; j < count - 2; j++)
         {
            // Equal High
            if (MathAbs(g_TradeContext.M15Rates[i].high - g_TradeContext.M15Rates[j].high) <= 10 * _Point)
            {
               LiquidityLevel ll;
               ll.Type = LIQUIDITY_HIGH;
               ll.Price = g_TradeContext.M15Rates[i].high;
               ll.Time1 = g_TradeContext.M15Rates[i].time;
               ll.Time2 = g_TradeContext.M15Rates[j].time;
               ll.Volume = 2;
               this.LiquidityLevels.Add(ll);
               
               // Check for sweep
               if (g_TradeContext.M15Rates[j+1].high > g_TradeContext.M15Rates[i].high)
               {
                  LiquidityLevel sweep;
                  sweep.Type = LIQUIDITY_SWEEP_HIGH;
                  sweep.Price = g_TradeContext.M15Rates[j+1].high;
                  sweep.Time1 = g_TradeContext.M15Rates[j+1].time;
                  this.LiquiditySweeps.Add(sweep);
                  
                  if (g_TradeContext.M15Rates[j+1].close < g_TradeContext.M15Rates[j+1].high)
                     this.SellSideLiquidity += g_TradeContext.M15Rates[j+1].high - g_TradeContext.M15Rates[j+1].close;
               }
            }
            
            // Equal Low
            if (MathAbs(g_TradeContext.M15Rates[i].low - g_TradeContext.M15Rates[j].low) <= 10 * _Point)
            {
               LiquidityLevel ll;
               ll.Type = LIQUIDITY_LOW;
               ll.Price = g_TradeContext.M15Rates[i].low;
               ll.Time1 = g_TradeContext.M15Rates[i].time;
               ll.Time2 = g_TradeContext.M15Rates[j].time;
               ll.Volume = 2;
               this.LiquidityLevels.Add(ll);
               
               // Check for sweep
               if (g_TradeContext.M15Rates[j+1].low < g_TradeContext.M15Rates[i].low)
               {
                  LiquidityLevel sweep;
                  sweep.Type = LIQUIDITY_SWEEP_LOW;
                  sweep.Price = g_TradeContext.M15Rates[j+1].low;
                  sweep.Time1 = g_TradeContext.M15Rates[j+1].time;
                  this.LiquiditySweeps.Add(sweep);
                  
                  if (g_TradeContext.M15Rates[j+1].close > g_TradeContext.M15Rates[j+1].low)
                     this.BuySideLiquidity += g_TradeContext.M15Rates[j+1].close - g_TradeContext.M15Rates[j+1].low;
               }
            }
         }
      }
      
      this.LastLiquidityUpdate = TimeCurrent();
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Update Fair Value Gaps (3-candle method)                       |
   //+------------------------------------------------------------------+
   bool UpdateFVG()
   {
      this.FreshFVG.Clear();
      this.PartialFVG.Clear();
      this.FilledFVG.Clear();
      
      int count = ArraySize(g_TradeContext.M5Rates);
      if (count < 5)
         return true;
      
      // Scan for FVG using 3-candle method
      for (int i = 0; i < count - 2; i++)
      {
         double high1 = g_TradeContext.M5Rates[i].high;
         double low1 = g_TradeContext.M5Rates[i].low;
         double high2 = g_TradeContext.M5Rates[i+1].high;
         double low2 = g_TradeContext.M5Rates[i+1].low;
         double high3 = g_TradeContext.M5Rates[i+2].high;
         double low3 = g_TradeContext.M5Rates[i+2].low;
         
         // Bullish FVG: Low of candle 3 > High of candle 1
         if (low3 > high1)
         {
            FVG fvg;
            fvg.Type = FVG_BULLISH;
            fvg.StartPrice = high1;
            fvg.EndPrice = low3;
            fvg.Size = low3 - high1;
            fvg.Index = i + 1;
            fvg.Status = FVG_FRESH;
            
            // Check if partially filled
            if (low2 > high1 && low2 < low3)
               fvg.Status = FVG_PARTIAL;
            
            this.FreshFVG.Add(fvg);
         }
         
         // Bearish FVG: High of candle 3 < Low of candle 1
         if (high3 < low1)
         {
            FVG fvg;
            fvg.Type = FVG_BEARISH;
            fvg.StartPrice = low1;
            fvg.EndPrice = high3;
            fvg.Size = low1 - high3;
            fvg.Index = i + 1;
            fvg.Status = FVG_FRESH;
            
            // Check if partially filled
            if (high2 < low1 && high2 > high3)
               fvg.Status = FVG_PARTIAL;
            
            this.FreshFVG.Add(fvg);
         }
      }
      
      this.LastFVGUpdate = TimeCurrent();
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get top swing high                                               |
   //+------------------------------------------------------------------+
   SwingPoint GetSwingHigh(int index)
   {
      if (index < 0 || index >= this.SwingHighs.Total())
         return SwingPoint();
      
      return this.SwingHighs[index];
   }
   
   //+------------------------------------------------------------------+
   //| Get top swing low                                                |
   //+------------------------------------------------------------------+
   SwingPoint GetSwingLow(int index)
   {
      if (index < 0 || index >= this.SwingLows.Total())
         return SwingPoint();
      
      return this.SwingLows[index];
   }
   
   //+------------------------------------------------------------------+
   //| Get fresh order blocks by direction                            |
   //+------------------------------------------------------------------+
   Array<OrderBlock> GetFreshOrderBlocks(bool bullish)
   {
      if (bullish)
         return this.FreshOB_Bullish;
      else
         return this.FreshOB_Bearish;
   }
   
   //+------------------------------------------------------------------+
   //| Check if order block is still fresh (not mitigated)            |
   //+------------------------------------------------------------------+
   bool IsFreshOB(int index, bool bullish)
   {
      Array<OrderBlock> obs = bullish ? this.FreshOB_Bullish : this.FreshOB_Bearish;
      
      if (index < 0 || index >= obs.Total())
         return false;
      
      return !obs[index].IsMitigated;
   }
   
   //+------------------------------------------------------------------+
   //| Check if price has mitigated order block                       |
   //+------------------------------------------------------------------+
   bool MitigatedOB(double price, bool bullish)
   {
      if (bullish)
      {
         for (int i = 0; i < this.FreshOB_Bullish.Total(); i++)
         {
            if (price < this.FreshOB_Bullish[i].EndPrice)
               this.FreshOB_Bullish[i].IsMitigated = true;
         }
      }
      else
      {
         for (int i = 0; i < this.FreshOB_Bearish.Total(); i++)
         {
            if (price > this.FreshOB_Bearish[i].StartPrice)
               this.FreshOB_Bearish[i].IsMitigated = true;
         }
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Get liquidity sweeps                                             |
   //+------------------------------------------------------------------+
   Array<LiquidityLevel> GetLiquiditySweeps()
   {
      return this.LiquiditySweeps;
   }
   
   //+------------------------------------------------------------------+
   //| Check if liquidity was swept                                    |
   //+------------------------------------------------------------------+
   bool LiquiditySwept(double price, bool buySide)
   {
      for (int i = 0; i < this.LiquiditySweeps.Total(); i++)
      {
         LiquidityLevel ll = this.LiquiditySweeps[i];
         
         if (buySide && ll.Type == LIQUIDITY_SWEEP_HIGH && price > ll.Price)
            return true;
         if (!buySide && ll.Type == LIQUIDITY_SWEEP_LOW && price < ll.Price)
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Get fresh FVGs                                                  |
   //+------------------------------------------------------------------+
   Array<FVG> GetFreshFVGs(bool bullish)
   {
      // Filter by direction if needed
      // For now, return all FVGs and let caller filter by Type
      return this.FreshFVG;
   }
   
   //+------------------------------------------------------------------+
   //| Get FVG by index                                                 |
   //+------------------------------------------------------------------+
   FVG GetFVG(int index, bool bullish)
   {
      Array<FVG> fvgList = bullish ? this.FreshFVG : this.FreshFVG;
      
      if (index < 0 || index >= fvgList.Total())
         return FVG();
      
      return fvgList[index];
   }
};

//+------------------------------------------------------------------+
//| Global Data Cache Instance                                       |
//+------------------------------------------------------------------+
DataCache g_DataCache;

//+------------------------------------------------------------------+
//| Initialize data cache                                            |
//+------------------------------------------------------------------+
bool InitializeDataCache()
{
   g_DataCache.Reset();
   return true;
}

//+------------------------------------------------------------------+
//| Update data cache if new candle                                 |
//+------------------------------------------------------------------+
bool UpdateDataCache()
{
   // Update on M15 timeframe for structural analysis
   if (!g_DataCache.UpdateIfNewCandle(PERIOD_M15))
   {
      g_TradeContext.AddError("Failed to update data cache");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get nearest swing high above price                              |
//+------------------------------------------------------------------+
double GetNearestSwingHigh(double price)
{
   double nearest = 0.0;
   
   for (int i = 0; i < g_DataCache.SwingHighs.Total(); i++)
   {
      SwingPoint sp = g_DataCache.SwingHighs[i];
      
      if (sp.Price > price && (nearest == 0 || sp.Price < nearest))
         nearest = sp.Price;
   }
   
   return nearest;
}

//+------------------------------------------------------------------+
//| Get nearest swing low below price                               |
//+------------------------------------------------------------------+
double GetNearestSwingLow(double price)
{
   double nearest = 0.0;
   
   for (int i = 0; i < g_DataCache.SwingLows.Total(); i++)
   {
      SwingPoint sp = g_DataCache.SwingLows[i];
      
      if (sp.Price < price && (nearest == 0 || sp.Price > nearest))
         nearest = sp.Price;
   }
   
   return nearest;
}
//+------------------------------------------------------------------+