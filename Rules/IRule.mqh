//+------------------------------------------------------------------+
//|                                                            IRule.mqh |
//|                        XAU SMC Scalper Pro - Rules Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include "TradeContext.mqh"

//+------------------------------------------------------------------+
//| Rule Result Structure                                            |
//+------------------------------------------------------------------+
struct RuleResult
{
   bool Passed;
   double Weight;
   double Score;
   string Name;
   string Reason;
   
   //+------------------------------------------------------------------+
   //| Default constructor                                             |
   //+------------------------------------------------------------------+
   void RuleResult()
   {
      this.Passed = false;
      this.Weight = 0.0;
      this.Score = 0.0;
      this.Name = "";
      this.Reason = "";
   }
};

//+------------------------------------------------------------------+
//| IRule Interface - All Rules Must Implement This                |
//+------------------------------------------------------------------+
class IRule
{
public:
   //+------------------------------------------------------------------+
   //| Check if rule passed                                            |
   //+------------------------------------------------------------------+
   virtual bool Check() = 0;
   
   //+------------------------------------------------------------------+
   //| Get rule name                                                   |
   //+------------------------------------------------------------------+
   virtual string Name() = 0;
   
   //+------------------------------------------------------------------+
   //| Get rule weight (contribution to confidence score)             |
   //+------------------------------------------------------------------+
   virtual double Weight() = 0;
   
   //+------------------------------------------------------------------+
   //| Get reason for pass/fail                                        |
   //+------------------------------------------------------------------+
   virtual string Reason() = 0;
   
   //+------------------------------------------------------------------+
   //| Get rule result                                                 |
   //+------------------------------------------------------------------+
   RuleResult GetResult()
   {
      RuleResult result;
      result.Name = this.Name();
      result.Weight = this.Weight();
      result.Passed = this.Check();
      result.Reason = this.Reason();
      result.Score = result.Passed ? result.Weight : 0.0;
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Virtual destructor                                              |
   //+------------------------------------------------------------------+
   virtual ~IRule() {}
};

//+------------------------------------------------------------------+
//| Rule Category Enumeration                                       |
//+------------------------------------------------------------------+
enum RuleCategory
{
   CATEGORY_FILTER = 0,     // Hard stop rules
   CATEGORY_MARKET = 1,     // Market condition rules
   CATEGORY_ENTRY = 2,      // Entry confirmation rules
   CATEGORY_RISK = 3        // Risk validation rules
};
//+------------------------------------------------------------------+
