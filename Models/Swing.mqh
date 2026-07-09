//+------------------------------------------------------------------+
//|                                                          Swing.mqh |
//|                        XAU SMC Scalper Pro - Models      |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

//+------------------------------------------------------------------+
//| Swing Point Type                                                 |
//+------------------------------------------------------------------+
enum SwingType
{
   SWING_NONE = 0,
   SWING_HIGH = 1,
   SWING_LOW = 2
};

//+------------------------------------------------------------------+
//| Swing Point Model                                                |
//+------------------------------------------------------------------+
struct SwingPoint
{
   SwingType Type;
   int Index;           // Bar index
   double Price;        // Swing price
   datetime Time;       // Swing time
   
   //+------------------------------------------------------------------+
   //| Default constructor                                             |
   //+------------------------------------------------------------------+
   void SwingPoint()
   {
      this.Type = SWING_NONE;
      this.Index = 0;
      this.Price = 0.0;
      this.Time = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Check if swing is still valid (not broken)                     |
   //+------------------------------------------------------------------+
   bool IsValid()
   {
      if (this.Type == SWING_NONE)
         return false;
      
      // Check if price has broken the swing
      MqlRates rates[];
      if (CopyRates(_Symbol, PERIOD_M15, 0, 100, rates) != 100)
         return false;
      
      if (this.Type == SWING_HIGH)
         return (rates[0].high < this.Price);
      
      if (this.Type == SWING_LOW)
         return (rates[0].low > this.Price);
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Get break price (slightly beyond swing)                        |
   //+------------------------------------------------------------------+
   double GetBreakPrice()
   {
      if (this.Type == SWING_HIGH)
         return this.Price + 5 * _Point;  // 5 point buffer
      
      if (this.Type == SWING_LOW)
         return this.Price - 5 * _Point;
      
      return 0.0;
   }
};
//+------------------------------------------------------------------+
