#ifndef __MODELS_LIQUIDITYMODEL_MHQ__
#define __MODELS_LIQUIDITYMODEL_MHQ__
//+------------------------------------------------------------------+
//|                                                  LiquidityModel.mqh |
//|                        XAU SMC Scalper Pro - Models      |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

//+------------------------------------------------------------------+
//| Liquidity Type                                                   |
//+------------------------------------------------------------------+
enum LiquidityType
{
   LIQUIDITY_NONE = 0,
   LIQUIDITY_HIGH = 1,      // Equal high - sell side liquidity
   LIQUIDITY_LOW = 2,       // Equal low - buy side liquidity
   LIQUIDITY_SWEEP_HIGH = 3, // Liquidity above price
   LIQUIDITY_SWEEP_LOW = 4   // Liquidity below price
};

//+------------------------------------------------------------------+
//| Liquidity Level Model                                            |
//+------------------------------------------------------------------+
struct LiquidityLevel
{
   LiquidityType Type;
   double Price;
   datetime Time1;
   datetime Time2;
   int Volume;          // Number of equal levels
   bool Swept;
   datetime SweepTime;
   
   //+------------------------------------------------------------------+
   //| Default constructor                                             |
   //+------------------------------------------------------------------+
   void LiquidityLevel()
   {
      this.Type = LIQUIDITY_NONE;
      this.Price = 0.0;
      this.Time1 = 0;
      this.Time2 = 0;
      this.Volume = 0;
      this.Swept = false;
      this.SweepTime = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Check if price has swept this liquidity                        |
   //+------------------------------------------------------------------+
   bool IsSwept(double price)
   {
      if (this.Type == LIQUIDITY_SWEEP_HIGH)
         return (price > this.Price);
      if (this.Type == LIQUIDITY_SWEEP_LOW)
         return (price < this.Price);
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Get liquidity volume in standard lots                          |
   //+------------------------------------------------------------------+
   double GetVolumeInLots()
   {
      // Approximate: 1 standard lot = $100,000
      // Volume here represents number of equal levels
      return this.Volume * 0.1;  // 0.1 lots per level (adjust based on analysis)
   }
   
   //+------------------------------------------------------------------+
   //| Get liquidity quality score                                    |
   //+------------------------------------------------------------------+
   int QualityScore()
   {
      int score = 0;
      
      // Volume score (max 50 points)
      score += MathMin(50, this.Volume * 10);
      
      // Recency score (max 30 points)
      int barsSince = (int)((TimeCurrent() - this.Time2) / (PeriodSeconds(PERIOD_M15)));
      if (barsSince <= 10)
         score += 30;
      else if (barsSince <= 20)
         score += 20;
      else if (barsSince <= 40)
         score += 10;
      
      // Distance from current price (max 20 points)
      double distance = MathAbs(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - this.Price) / _Point;
      if (distance <= 50)
         score += 20;
      else if (distance <= 100)
         score += 10;
      
      return score;
   }
};
//+------------------------------------------------------------------+

#endif // __MODELS_LIQUIDITYMODEL_MHQ__
