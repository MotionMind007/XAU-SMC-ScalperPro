#ifndef __CORE_DATACACHE_MHQ__
#define __CORE_DATACACHE_MHQ__
//+------------------------------------------------------------------+
//|                                                        DataCache.mqh |
//|                        XAU SMC Scalper Pro - Core Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.2"
#property strict

#include "Models\\Swing.mqh"
#include "Models\\OrderBlockModel.mqh"
#include "Models\\LiquidityModel.mqh"
#include "Models\\ScoreModel.mqh"
#include "TradeContext.mqh"

//+------------------------------------------------------------------+
//| Data Cache Structure - Cached Analysis Results per Timeframe     |
//+------------------------------------------------------------------+
struct DataCache
{
   // === Timeframe this cache operates on ===
   ENUM_TIMEFRAMES Timeframe;
   
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
      this.Timeframe = PERIOD_M15;
      this.Reset();
   }
   
   //+------------------------------------------------------------------+
   //| Constructor with timeframe                                     |
   //+------------------------------------------------------------------+
   void DataCache(ENUM_TIMEFRAMES tf)
   {
      this.Timeframe = tf;
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
   //| Get rates for this cache's timeframe from TradeContext          |
   //+------------------------------------------------------------------+
   bool GetCachedRates(MqlRates &rates[])
   {
      ArraySetAsSeries(rates, true);
      switch (this.Timeframe)
      {
         case PERIOD_M5:
            ArrayCopy(rates, g_TradeContext.M5Rates);
            return true;
         case PERIOD_M15:
            ArrayCopy(rates, g_TradeContext.M15Rates);
            return true;
         case PERIOD_H1:
            ArrayCopy(rates, g_TradeContext.H1Rates);
            return true;
         default:
            ArrayCopy(rates, g_TradeContext.M15Rates);
            return true;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check if cache needs update (new candle detected)              |
   //+------------------------------------------------------------------+
   bool NeedsUpdate()
   {
      datetime currentCandle = iTime(_Symbol, this.Timeframe, 0);
      
      if (currentCandle != this.LastCandleUpdate)
         return true;
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Update cache if new candle on stored timeframe                 |
   //+------------------------------------------------------------------+
   bool UpdateIfNewCandle()
   {
      datetime currentCandle = iTime(_Symbol, this.Timeframe, 0);
      
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
   //| Update swing points using this timeframe's data                |
   //+------------------------------------------------------------------+
   bool UpdateSwingPoints()
   {
      this.SwingHighs.Clear();
      this.SwingLows.Clear();
      
      MqlRates rates[];
      if (!this.GetCachedRates(rates))
         return false;
      
      int count = ArraySize(rates);
      if (count < 10)
         return true;  // Not enough data
      
      // Scan for swing highs (fractal pattern)
      for (int i = 3; i < count - 2; i++)
      {
         if (this.IsSwingHigh(rates, i))
         {
            SwingPoint sp;
            sp.Type = SWING_HIGH;
            sp.Index = i;
            sp.Price = rates[i].high;
            sp.Time = rates[i].time;
            this.SwingHighs.Add(sp);
         }
      }
      
      // Scan for swing lows
      for (int i = 3; i < count - 2; i++)
      {
         if (this.IsSwingLow(rates, i))
         {
            SwingPoint sp;
            sp.Type = SWING_LOW;
            sp.Index = i;
            sp.Price = rates[i].low;
            sp.Time = rates[i].time;
            this.SwingLows.Add(sp);
         }
      }
      
      this.LastSwingUpdate = TimeCurrent();
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Detect swing high at index i                                    |
   //+------------------------------------------------------------------+
   bool IsSwingHigh(MqlRates &rates[], int i)
   {
      if (i < 3 || i >= ArraySize(rates) - 2)
         return false;
      
      double currentHigh = rates[i].high;
      
      // Compare with 2 candles before and after
      if (currentHigh > rates[i-1].high &&
          currentHigh > rates[i-2].high &&
          currentHigh > rates[i+1].high &&
          currentHigh > rates[i+2].high)
         return true;
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Detect swing low at index i                                     |
   //+------------------------------------------------------------------+
   bool IsSwingLow(MqlRates &rates[], int i)
   {
      if (i < 3 || i >= ArraySize(rates) - 2)
         return false;
      
      double currentLow = rates[i].low;
      
      // Compare with 2 candles before and after
      if (currentLow < rates[i-1].low &&
          currentLow < rates[i-2].low &&
          currentLow < rates[i+1].low &&
          currentLow < rates[i+2].low)
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
      
      MqlRates rates[];
      if (!this.GetCachedRates(rates))
         return false;
      
      int count = ArraySize(rates);
      if (count < 20)
         return true;  // Not enough data
      
      // Look for OB patterns after structure changes
      for (int i = 15; i < count - 1; i++)
      {
         if (this.IsBullishOrderBlock(rates, i))
         {
            OrderBlock ob;
            ob.Type = OB_BULLISH;
            ob.Index = i;
            ob.Bullish = true;
            ob.StartPrice = rates[i+1].open;
            ob.EndPrice = rates[i+1].close;
            ob.Body = MathAbs(ob.EndPrice - ob.StartPrice);
            ob.IsMitigated = false;
            this.FreshOB_Bullish.Add(ob);
         }
         
         if (this.IsBearishOrderBlock(rates, i))
         {
            OrderBlock ob;
            ob.Type = OB_BEARISH;
            ob.Index = i;
            ob.Bullish = false;
            ob.StartPrice = rates[i+1].open;
            ob.EndPrice = rates[i+1].close;
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
   bool IsBullishOrderBlock(MqlRates &rates[], int i)
   {
      if (i >= ArraySize(rates) - 1)
         return false;
      
      // Bullish OB: Last bearish candle before bullish impulse
      double currentClose = rates[i].close;
      double currentOpen = rates[i].open;
      
      // Check if current candle is bearish
      if (currentClose >= currentOpen)
         return false;
      
      // Check next candle is bullish impulse
      double nextClose = rates[i+1].close;
      double nextOpen = rates[i+1].open;
      
      if (nextClose > nextOpen && (nextClose - nextOpen) > (currentOpen - currentClose) * 0.5)
         return true;
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Detect bearish order block at index i                           |
   //+------------------------------------------------------------------+
   bool IsBearishOrderBlock(MqlRates &rates[], int i)
   {
      if (i >= ArraySize(rates) - 1)
         return false;
      
      // Bearish OB: Last bullish candle before bearish impulse
      double currentClose = rates[i].close;
      double currentOpen = rates[i].open;
      
      // Check if current candle is bullish
      if (currentClose <= currentOpen)
         return false;
      
      // Check next candle is bearish impulse
      double nextClose = rates[i+1].close;
      double nextOpen = rates[i+1].open;
      
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
      
      MqlRates rates[];
      if (!this.GetCachedRates(rates))
         return false;
      
      int count = ArraySize(rates);
      if (count < 10)
         return true;
      
      double pointVal = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      // Find equal highs and equal lows
      for (int i = 0; i < count - 5; i++)
      {
         for (int j = i + 3; j < count - 2; j++)
         {
            // Equal High
            if (MathAbs(rates[i].high - rates[j].high) <= 10 * pointVal)
            {
               LiquidityLevel ll;
               ll.Type = LIQUIDITY_HIGH;
               ll.Price = rates[i].high;
               ll.Time1 = rates[i].time;
               ll.Time2 = rates[j].time;
               ll.Volume = 2;
               this.LiquidityLevels.Add(ll);
               
               // Check for sweep
               if (rates[j+1].high > rates[i].high)
               {
                  LiquidityLevel sweep;
                  sweep.Type = LIQUIDITY_SWEEP_HIGH;
                  sweep.Price = rates[j+1].high;
                  sweep.Time1 = rates[j+1].time;
                  this.LiquiditySweeps.Add(sweep);
                  
                  if (rates[j+1].close < rates[j+1].high)
                     this.SellSideLiquidity += rates[j+1].high - rates[j+1].close;
               }
            }
            
            // Equal Low
            if (MathAbs(rates[i].low - rates[j].low) <= 10 * pointVal)
            {
               LiquidityLevel ll;
               ll.Type = LIQUIDITY_LOW;
               ll.Price = rates[i].low;
               ll.Time1 = rates[i].time;
               ll.Time2 = rates[j].time;
               ll.Volume = 2;
               this.LiquidityLevels.Add(ll);
               
               // Check for sweep
               if (rates[j+1].low < rates[i].low)
               {
                  LiquidityLevel sweep;
                  sweep.Type = LIQUIDITY_SWEEP_LOW;
                  sweep.Price = rates[j+1].low;
                  sweep.Time1 = rates[j+1].time;
                  this.LiquiditySweeps.Add(sweep);
                  
                  if (rates[j+1].close > rates[j+1].low)
                     this.BuySideLiquidity += rates[j+1].close - rates[j+1].low;
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
      
      MqlRates rates[];
      if (!this.GetCachedRates(rates))
         return false;
      
      int count = ArraySize(rates);
      if (count < 5)
         return true;
      
      // Scan for FVG using 3-candle method
      for (int i = 0; i < count - 2; i++)
      {
         double high1 = rates[i].high;
         double low1 = rates[i].low;
         double high2 = rates[i+1].high;
         double low2 = rates[i+1].low;
         double high3 = rates[i+2].high;
         double low3 = rates[i+2].low;
         
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
   //| Get swing high by index                                         |
   //+------------------------------------------------------------------+
   SwingPoint GetSwingHigh(int index)
   {
      if (index < 0 || index >= this.SwingHighs.Total())
         return SwingPoint();
      
      return this.SwingHighs[index];
   }
   
   //+------------------------------------------------------------------+
   //| Get swing low by index                                          |
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
   //| Check if price has mitigated order block (returns true if any) |
   //+------------------------------------------------------------------+
   bool MitigatedOB(double price, bool bullish)
   {
      bool anyMitigated = false;
      
      if (bullish)
      {
         for (int i = 0; i < this.FreshOB_Bullish.Total(); i++)
         {
            if (!this.FreshOB_Bullish[i].IsMitigated && price < this.FreshOB_Bullish[i].EndPrice)
            {
               this.FreshOB_Bullish[i].IsMitigated = true;
               anyMitigated = true;
            }
         }
      }
      else
      {
         for (int i = 0; i < this.FreshOB_Bearish.Total(); i++)
         {
            if (!this.FreshOB_Bearish[i].IsMitigated && price > this.FreshOB_Bearish[i].StartPrice)
            {
               this.FreshOB_Bearish[i].IsMitigated = true;
               anyMitigated = true;
            }
         }
      }
      
      return anyMitigated;
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
   //| Get fresh FVGs filtered by direction                            |
   //+------------------------------------------------------------------+
   Array<FVG> GetFreshFVGs(bool bullish)
   {
      Array<FVG> result;
      ArrayResize(result, 0);
      
      for (int i = 0; i < this.FreshFVG.Total(); i++)
      {
         FVG fvg = this.FreshFVG[i];
         if (bullish && fvg.Type == FVG_BULLISH && fvg.IsFresh())
            result.Add(fvg);
         else if (!bullish && fvg.Type == FVG_BEARISH && fvg.IsFresh())
            result.Add(fvg);
      }
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Get FVG by index and direction (filtered)                       |
   //+------------------------------------------------------------------+
   FVG GetFVG(int index, bool bullish)
   {
      int matchIndex = 0;
      for (int i = 0; i < this.FreshFVG.Total(); i++)
      {
         FVG fvg = this.FreshFVG[i];
         bool matchesDirection = bullish ? (fvg.Type == FVG_BULLISH) : (fvg.Type == FVG_BEARISH);
         if (matchesDirection)
         {
            if (matchIndex == index)
               return fvg;
            matchIndex++;
         }
      }
      return FVG();
   }
};

//+------------------------------------------------------------------+
//| Global Data Cache Instances (one per timeframe)                  |
//+------------------------------------------------------------------+
DataCache g_CacheH1(PERIOD_H1);
DataCache g_CacheM15(PERIOD_M15);
DataCache g_CacheM5(PERIOD_M5);

// Backward-compatible alias: g_DataCache points to M15 cache
#define g_DataCache g_CacheM15

//+------------------------------------------------------------------+
//| Initialize all data caches                                       |
//+------------------------------------------------------------------+
bool InitializeDataCache()
{
   g_CacheH1.Reset();
   g_CacheH1.Timeframe = PERIOD_H1;
   
   g_CacheM15.Reset();
   g_CacheM15.Timeframe = PERIOD_M15;
   
   g_CacheM5.Reset();
   g_CacheM5.Timeframe = PERIOD_M5;
   
   return true;
}

//+------------------------------------------------------------------+
//| Update M5 data cache (lightweight, runs every tick)             |
//+------------------------------------------------------------------+
bool UpdateDataCacheM5()
{
   // Update M5 cache (entry timing data - needs fresh updates)
   if (!g_CacheM5.UpdateIfNewCandle())
   {
      g_TradeContext.AddError("Failed to update M5 data cache");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Update H1 and M15 data caches (heavy, runs on new bar only)    |
//+------------------------------------------------------------------+
bool UpdateDataCacheH1M15()
{
   // Update M15 cache (primary for structural analysis)
   if (!g_CacheM15.UpdateIfNewCandle())
   {
      g_TradeContext.AddError("Failed to update M15 data cache");
      return false;
   }
   
   // Update H1 cache (for higher timeframe analysis)
   g_CacheH1.UpdateIfNewCandle();
   
   return true;
}

//+------------------------------------------------------------------+
//| Update all data caches if new candle                             |
//+------------------------------------------------------------------+
bool UpdateDataCache()
{
   // Update M15 cache (primary for structural analysis)
   if (!g_CacheM15.UpdateIfNewCandle())
   {
      g_TradeContext.AddError("Failed to update M15 data cache");
      return false;
   }
   
   // Update H1 cache (for higher timeframe analysis)
   g_CacheH1.UpdateIfNewCandle();
   
   // Update M5 cache (for entry timing)
   g_CacheM5.UpdateIfNewCandle();
   
   return true;
}

//+------------------------------------------------------------------+
//| Get nearest swing high above price (from specified timeframe)    |
//+------------------------------------------------------------------+
double GetNearestSwingHigh(double price, ENUM_TIMEFRAMES tf = PERIOD_M15)
{
   DataCache* cache = GetCacheForTimeframe(tf);
   double nearest = 0.0;
   
   for (int i = 0; i < cache.SwingHighs.Total(); i++)
   {
      SwingPoint sp = cache.SwingHighs[i];
      
      if (sp.Price > price && (nearest == 0 || sp.Price < nearest))
         nearest = sp.Price;
   }
   
   return nearest;
}

//+------------------------------------------------------------------+
//| Get nearest swing low below price (from specified timeframe)     |
//+------------------------------------------------------------------+
double GetNearestSwingLow(double price, ENUM_TIMEFRAMES tf = PERIOD_M15)
{
   DataCache* cache = GetCacheForTimeframe(tf);
   double nearest = 0.0;
   
   for (int i = 0; i < cache.SwingLows.Total(); i++)
   {
      SwingPoint sp = cache.SwingLows[i];
      
      if (sp.Price < price && (nearest == 0 || sp.Price > nearest))
         nearest = sp.Price;
   }
   
   return nearest;
}

//+------------------------------------------------------------------+
//| Get cache instance for specified timeframe                       |
//+------------------------------------------------------------------+
DataCache* GetCacheForTimeframe(ENUM_TIMEFRAMES tf)
{
   switch (tf)
   {
      case PERIOD_H1:  return GetPointer(g_CacheH1);
      case PERIOD_M5:  return GetPointer(g_CacheM5);
      case PERIOD_M15: return GetPointer(g_CacheM15);
      default:         return GetPointer(g_CacheM15);
   }
}
//+------------------------------------------------------------------+

#endif // __CORE_DATACACHE_MHQ__
