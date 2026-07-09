#ifndef __MODELS_SCOREMODEL_MHQ__
#define __MODELS_SCOREMODEL_MHQ__
//+------------------------------------------------------------------+
//|                                                      ScoreModel.mqh |
//|                        XAU SMC Scalper Pro - Models      |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

//+------------------------------------------------------------------+
//| FVG Type (Fair Value Gap)                                        |
//+------------------------------------------------------------------+
enum FVGType
{
   FVG_NONE = 0,
   FVG_BULLISH = 1,
   FVG_BEARISH = 2
};

//+------------------------------------------------------------------+
//| FVG Status                                                       |
//+------------------------------------------------------------------+
enum FVGStatus
{
   FVG_FRESH = 0,
   FVG_PARTIAL = 1,
   FVG_FILLED = 2
};

//+------------------------------------------------------------------+
//| Fair Value Gap Model                                             |
//+------------------------------------------------------------------+
struct FVG
{
   FVGType Type;
   FVGStatus Status;
   double StartPrice;
   double EndPrice;
   double Size;
   int Index;
   datetime Time;
   bool IsFilled;
   
   //+------------------------------------------------------------------+
   //| Default constructor                                             |
   //+------------------------------------------------------------------+
   void FVG()
   {
      this.Type = FVG_NONE;
      this.Status = FVG_FRESH;
      this.StartPrice = 0.0;
      this.EndPrice = 0.0;
      this.Size = 0.0;
      this.Index = 0;
      this.Time = 0;
      this.IsFilled = false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if FVG is still fresh (not filled)                       |
   //+------------------------------------------------------------------+
   bool IsFresh()
   {
      return (this.Status == FVG_FRESH || this.Status == FVG_PARTIAL);
   }
   
   //+------------------------------------------------------------------+
   //| Check if price has filled the FVG                              |
   //+------------------------------------------------------------------+
   bool IsFilledBy(double price)
   {
      if (this.Type == FVG_BULLISH)
         return (price <= this.EndPrice);
      if (this.Type == FVG_BEARISH)
         return (price >= this.EndPrice);
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Get FVG size in points                                         |
   //+------------------------------------------------------------------+
   double SizeInPoints()
   {
      return MathAbs(this.EndPrice - this.StartPrice) / _Point;
   }
   
   //+------------------------------------------------------------------+
   //| Get FVG quality score (0-100)                                  |
   //+------------------------------------------------------------------+
   int QualityScore()
   {
      int score = 0;
      
      // Size score (max 40 points)
      score += MathMin(40, (int)(this.SizeInPoints() * 2));
      
      // Status score (max 40 points)
      if (this.Status == FVG_FRESH)
         score += 40;
      else if (this.Status == FVG_PARTIAL)
         score += 20;
      
      // Proximity score (max 20 points)
      int barsSince = (int)((TimeCurrent() - this.Time) / (PeriodSeconds(PERIOD_M5)));
      if (barsSince <= 5)
         score += 20;
      else if (barsSince <= 10)
         score += 10;
      
      return score;
   }
};

//+------------------------------------------------------------------+
//| Price Action Patterns                                            |
//+------------------------------------------------------------------+
enum PriceActionType
{
   PA_NONE = 0,
   PA_BULLISH_ENGULFING = 1,
   PA_BEARISH_ENGULFING = 2,
   PA_BULLISH_PIN_BAR = 3,
   PA_BEARISH_PIN_BAR = 4,
   PA_BULLISH_REJECTION = 5,
   PA_BEARISH_REJECTION = 6,
   PA_BULLISH_MOMENTUM = 7,
   PA_BEARISH_MOMENTUM = 8,
   PA_INSIDE_BAR_BREAKEOUT = 9
};

//+------------------------------------------------------------------+
//| Price Action Model                                               |
//+------------------------------------------------------------------+
struct PriceAction
{
   PriceActionType Type;
   bool Bullish;
   int Index;
   datetime Time;
   double Body;
   double WickUpper;
   double WickLower;
   
   //+------------------------------------------------------------------+
   //| Default constructor                                             |
   //+------------------------------------------------------------------+
   void PriceAction()
   {
      this.Type = PA_NONE;
      this.Bullish = false;
      this.Index = 0;
      this.Time = 0;
      this.Body = 0.0;
      this.WickUpper = 0.0;
      this.WickLower = 0.0;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate price action score (0-100)                           |
   //+------------------------------------------------------------------+
   int QualityScore()
   {
      int score = 0;
      
      // Pattern strength (max 60 points)
      if (this.Type == PA_BULLISH_ENGULFING || this.Type == PA_BEARISH_ENGULFING)
         score += 60;
      else if (this.Type == PA_BULLISH_PIN_BAR || this.Type == PA_BEARISH_PIN_BAR)
         score += 50;
      else if (this.Type == PA_BULLISH_REJECTION || this.Type == PA_BEARISH_REJECTION)
         score += 45;
      else if (this.Type == PA_BULLISH_MOMENTUM || this.Type == PA_BEARISH_MOMENTUM)
         score += 40;
      else if (this.Type == PA_INSIDE_BAR_BREAKEOUT)
         score += 35;
      
      // Size of body (max 20 points)
      double bodyPoints = this.Body / _Point;
      score += MathMin(20, (int)(bodyPoints * 1.5));
      
      // Wick ratio (max 20 points)
      double wickRatio = (this.WickUpper + this.WickLower) / (this.Body + 0.0001);
      score += MathMin(20, (int)(wickRatio * 5));
      
      return score;
   }
};
//+------------------------------------------------------------------+

#endif // __MODELS_SCOREMODEL_MHQ__
