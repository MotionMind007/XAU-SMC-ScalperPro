//+------------------------------------------------------------------+
//|                                                 OrderBlockModel.mqh |
//|                        XAU SMC Scalper Pro - Models      |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

//+------------------------------------------------------------------+
//| Order Block Type                                                 |
//+------------------------------------------------------------------+
enum OBType
{
   OB_NONE = 0,
   OB_BULLISH = 1,
   OB_BEARISH = 2
};

//+------------------------------------------------------------------+
//| Order Block Status                                               |
//+------------------------------------------------------------------+
enum OBStatus
{
   OB_FRESH = 0,
   OB_PARTIAL_MITIGATED = 1,
   OB_FULLY_MITIGATED = 2
};

//+------------------------------------------------------------------+
//| Order Block Model                                                |
//+------------------------------------------------------------------+
struct OrderBlock
{
   OBType Type;
   bool Bullish;
   int Index;
   double StartPrice;
   double EndPrice;
   double Body;
   datetime Time;
   bool IsMitigated;
   double MitigationPrice;
   int BarCountSinceFormation;
   
   //+------------------------------------------------------------------+
   //| Default constructor                                             |
   //+------------------------------------------------------------------+
   void OrderBlock()
   {
      this.Type = OB_NONE;
      this.Bullish = false;
      this.Index = 0;
      this.StartPrice = 0.0;
      this.EndPrice = 0.0;
      this.Body = 0.0;
      this.Time = 0;
      this.IsMitigated = false;
      this.MitigationPrice = 0.0;
      this.BarCountSinceFormation = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Check if current price has entered the OB                      |
   //+------------------------------------------------------------------+
   bool IsEntered(double price)
   {
      if (this.Bullish)
         return (price >= this.StartPrice && price <= this.EndPrice);
      else
         return (price <= this.StartPrice && price >= this.EndPrice);
   }
   
   //+------------------------------------------------------------------+
   //| Check if OB has been mitigated by price                        |
   //+------------------------------------------------------------------+
   bool IsMitigatedBy(double price)
   {
      if (this.Bullish)
         return (price < this.StartPrice);
      else
         return (price > this.StartPrice);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate OB size in points                                    |
   //+------------------------------------------------------------------+
   double SizeInPoints()
   {
      return MathAbs(this.EndPrice - this.StartPrice) / _Point;
   }
   
   //+------------------------------------------------------------------+
   //| Get OB quality score (0-100)                                   |
   //+------------------------------------------------------------------+
   int QualityScore()
   {
      int score = 0;
      
      // Size score (max 40 points)
      double sizePoints = this.SizeInPoints();
      score += MathMin(40, (int)(sizePoints * 2));
      
      // Freshness score (max 30 points)
      if (this.BarCountSinceFormation <= 5)
         score += 30;
      else if (this.BarCountSinceFormation <= 10)
         score += 20;
      else if (this.BarCountSinceFormation <= 20)
         score += 10;
      
      // Strength score (max 30 points)
      if (this.Body > 1.5 * _Point * 10)
         score += 30;
      else if (this.Body > 1.5 * _Point * 5)
         score += 20;
      else
         score += 10;
      
      return score;
   }
};

//+------------------------------------------------------------------+
//| Order Block List (helper forArray)                             |
//+------------------------------------------------------------------+
class OrderBlockList
{
private:
   Array<OrderBlock> m_obList;
   
public:
   void OrderBlockList()
   {
      this.m_obList = Array<OrderBlock>();
   }
   
   void Add(OrderBlock ob)
   {
      this.m_obList.Add(ob);
   }
   
   int Total()
   {
      return this.m_obList.Total();
   }
   
   OrderBlock Get(int index)
   {
      if (index < 0 || index >= this.m_obList.Total())
         return OrderBlock();
      
      return this.m_obList[index];
   }
   
   OrderBlock GetFreshOB(bool bullish)
   {
      for (int i = 0; i < this.m_obList.Total(); i++)
      {
         OrderBlock ob = this.m_obList[i];
         if (ob.Bullish == bullish && !ob.IsMitigated)
            return ob;
      }
      return OrderBlock();
   }
};
//+------------------------------------------------------------------+
