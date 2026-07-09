//+------------------------------------------------------------------+
//|                                                      RuleEngine.mqh |
//|                        XAU SMC Scalper Pro - Core Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include "IRule.mqh"
#include "TrendFilter.mqh"
#include "BOSFilter.mqh"
#include "LiquidityFilter.mqh"
#include "OrderBlockFilter.mqh"
#include "FVGFilter.mqh"
#include "PriceActionFilter.mqh"
#include "SpreadFilter.mqh"
#include "SessionFilter.mqh"
#include "NewsFilter.mqh"

//+------------------------------------------------------------------+
//| Trade Decision Structure                                        |
//+------------------------------------------------------------------+
struct TradeDecision
{
   bool Allowed;
   int ConfidenceScore;
   string Reasons;
   Array<RuleResult> RuleResults;
   
   //+------------------------------------------------------------------+
   //| Default constructor                                             |
   //+------------------------------------------------------------------+
   void TradeDecision()
   {
      this.Allowed = false;
      this.ConfidenceScore = 0;
      this.Reasons = "";
      this.RuleResults = Array<RuleResult>();
   }
};

//+------------------------------------------------------------------+
//| Exit Decision Structure                                         |
//+------------------------------------------------------------------+
struct ExitDecision
{
   bool ShouldExit;
   string Reason;
   int ExitType;  // 0=TP, 1=SL, 2=CHoCH, 3=Manual
   
   //+------------------------------------------------------------------+
   //| Default constructor                                             |
   //+------------------------------------------------------------------+
   void ExitDecision()
   {
      this.ShouldExit = false;
      this.Reason = "";
      this.ExitType = 0;
   }
};

//+------------------------------------------------------------------+
//| Confidence Score Rule                                           |
//+------------------------------------------------------------------+
class CConfidenceScoreRule : public IRule
{
private:
   int m_MinScore;
public:
   void CConfidenceScoreRule(int minScore = 75) { this.m_MinScore = minScore; }
   bool Check() { return (g_TradeContext.TotalConfidenceScore >= this.m_MinScore); }
   string Name() { return "ConfidenceScore"; }
   double Weight() { return 10.0; }
   string Reason()
   {
      if (g_TradeContext.TotalConfidenceScore >= this.m_MinScore)
         return StringFormat("Confidence Score: %d/%d - PASSED", g_TradeContext.TotalConfidenceScore, this.m_MinScore);
      return StringFormat("Confidence Score: %d/%d - FAILED", g_TradeContext.TotalConfidenceScore, this.m_MinScore);
   }
};

//+------------------------------------------------------------------+
//| Rule Engine - Evaluates All Entry/Exit Rules                   |
//+------------------------------------------------------------------+

class CRuleEngine
{
private:
   Array<IRule*> m_FilterRules;      // Level 1 - Hard stops
   Array<IRule*> m_MarketRules;      // Level 2 - Market validation
   Array<IRule*> m_EntryRules;       // Level 3 - Entry confirmation
   Array<IRule*> m_RiskRules;        // Level 4 - Risk validation
   
   int m_MinConfidenceScore;
   bool m_CacheResults;
   datetime m_LastCalculationTime;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void CRuleEngine()
   {
      this.m_MinConfidenceScore = 75;
      this.m_CacheResults = true;
      this.m_LastCalculationTime = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Destructor - Clean up memory                                  |
   //+------------------------------------------------------------------+
   ~CRuleEngine()
   {
      // Delete all rule objects
      for (int i = 0; i < this.m_FilterRules.Total(); i++)
         delete this.m_FilterRules[i];
      
      for (int i = 0; i < this.m_MarketRules.Total(); i++)
         delete this.m_MarketRules[i];
      
      for (int i = 0; i < this.m_EntryRules.Total(); i++)
         delete this.m_EntryRules[i];
      
      for (int i = 0; i < this.m_RiskRules.Total(); i++)
         delete this.m_RiskRules[i];
   }
   
   //+------------------------------------------------------------------+
   //| Initialize default rules                                       |
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      // Add filter rules (Level 1 - Hard stops)
      this.AddFilterRule(new CSessionFilter());
      this.AddFilterRule(new CNewsFilter());
      this.AddFilterRule(new CSpreadFilter());
      
      // Add market rules (Level 2)
      this.AddMarketRule(new CTrendFilter());
      
      // Add entry rules (Level 3)
      this.AddEntryRule(new CBOSFilter());
      this.AddEntryRule(new CLiquidityFilter());
      this.AddEntryRule(new COrderBlockFilter());
      this.AddEntryRule(new CFVGFilter());
      this.AddEntryRule(new CPriceActionFilter());
      
      // Add risk rules (Level 4)
      this.AddRiskRule(new CConfidenceScoreRule(this.m_MinConfidenceScore));
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Add filter rule                                                |
   //+------------------------------------------------------------------+
   void AddFilterRule(IRule* rule)
   {
      this.m_FilterRules.Add(rule);
   }
   
   //+------------------------------------------------------------------+
   //| Add market rule                                                |
   //+------------------------------------------------------------------+
   void AddMarketRule(IRule* rule)
   {
      this.m_MarketRules.Add(rule);
   }
   
   //+------------------------------------------------------------------+
   //| Add entry rule                                                 |
   //+------------------------------------------------------------------+
   void AddEntryRule(IRule* rule)
   {
      this.m_EntryRules.Add(rule);
   }
   
   //+------------------------------------------------------------------+
   //| Add risk rule                                                  |
   //+------------------------------------------------------------------+
   void AddRiskRule(IRule* rule)
   {
      this.m_RiskRules.Add(rule);
   }
   
   //+------------------------------------------------------------------+
   //| Check all filter rules                                         |
   //+------------------------------------------------------------------+
   bool CheckFilters()
   {
      for (int i = 0; i < this.m_FilterRules.Total(); i++)
      {
         IRule* rule = this.m_FilterRules[i];
         if (!rule.Check())
         {
            g_TradeContext.AddError("Filter failed: " + rule->Name() + " - " + rule->Reason());
            return false;
         }
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Check entry conditions                                         |
   //+------------------------------------------------------------------+
   TradeDecision CheckEntry()
   {
      TradeDecision decision;
      int totalScore = 0;
      int maxScore = 0;
      string reasons = "";
      
      // Check market rules
      for (int i = 0; i < this.m_MarketRules.Total(); i++)
      {
         IRule* rule = this.m_MarketRules[i];
         RuleResult result = rule.GetResult();
         decision.RuleResults.Add(result);
         
         if (result.Passed)
            totalScore += (int)result.Weight;
         
         maxScore += (int)result.Weight;
         reasons += result.Reason + "; ";
      }
      
      // Check entry rules
      for (int i = 0; i < this.m_EntryRules.Total(); i++)
      {
         IRule* rule = this.m_EntryRules[i];
         RuleResult result = rule.GetResult();
         decision.RuleResults.Add(result);
         
         if (result.Passed)
            totalScore += (int)result.Weight;
         
         maxScore += (int)result.Weight;
         reasons += result.Reason + "; ";
      }
      
      // Check risk rules
      for (int i = 0; i < this.m_RiskRules.Total(); i++)
      {
         IRule* rule = this.m_RiskRules[i];
         RuleResult result = rule.GetResult();
         decision.RuleResults.Add(result);
         
         if (result.Passed)
            totalScore += (int)result.Weight;
         
         maxScore += (int)result.Weight;
         reasons += result.Reason + "; ";
      }
      
      decision.ConfidenceScore = totalScore;
      decision.Reasons = reasons;
      decision.Allowed = (totalScore >= this.m_MinConfidenceScore);
      
      return decision;
   }
   
   //+------------------------------------------------------------------+
   //| Check exit conditions                                          |
   //+------------------------------------------------------------------+
   ExitDecision CheckExit(int positionType)
   {
      ExitDecision decision;
      
      // Check for TP hit
      if (positionType == 0)  // Buy position
      {
         if (SymbolInfoDouble(_Symbol, SYMBOL_BID) >= g_TradeContext.TargetTP)
         {
            decision.ShouldExit = true;
            decision.Reason = "Take Profit hit";
            decision.ExitType = 0;
            return decision;
         }
      }
      else if (positionType == 1)  // Sell position
      {
         if (SymbolInfoDouble(_Symbol, SYMBOL_ASK) <= g_TradeContext.TargetTP)
         {
            decision.ShouldExit = true;
            decision.Reason = "Take Profit hit";
            decision.ExitType = 0;
            return decision;
         }
      }
      
      // Check for SL hit
      if (positionType == 0)  // Buy position
      {
         if (SymbolInfoDouble(_Symbol, SYMBOL_BID) <= g_TradeContext.TargetSL)
         {
            decision.ShouldExit = true;
            decision.Reason = "Stop Loss hit";
            decision.ExitType = 1;
            return decision;
         }
      }
      else if (positionType == 1)  // Sell position
      {
         if (SymbolInfoDouble(_Symbol, SYMBOL_ASK) >= g_TradeContext.TargetSL)
         {
            decision.ShouldExit = true;
            decision.Reason = "Stop Loss hit";
            decision.ExitType = 1;
            return decision;
         }
      }
      
      // Check for CHoCH (change of character)
      // This would require checking if trend reversed
      int currentTrend = g_TradeContext.CurrentTrend;
      if (currentTrend == 0 && positionType == 0)  // Buy position, trend became neutral
      {
         decision.ShouldExit = true;
         decision.Reason = "Trend changed to neutral";
         decision.ExitType = 2;
         return decision;
      }
      if (currentTrend == 0 && positionType == 1)  // Sell position, trend became neutral
      {
         decision.ShouldExit = true;
         decision.Reason = "Trend changed to neutral";
         decision.ExitType = 2;
         return decision;
      }
      
      return decision;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate total confidence score                              |
   //+------------------------------------------------------------------+
   int CalculateConfidenceScore()
   {
      int totalScore = 0;
      
      // Add all rule scores
      for (int i = 0; i < this.m_FilterRules.Total(); i++)
      {
         IRule* rule = this.m_FilterRules[i];
         if (rule.Check())
            totalScore += (int)rule.Weight();
      }
      
      for (int i = 0; i < this.m_MarketRules.Total(); i++)
      {
         IRule* rule = this.m_MarketRules[i];
         if (rule.Check())
            totalScore += (int)rule.Weight();
      }
      
      for (int i = 0; i < this.m_EntryRules.Total(); i++)
      {
         IRule* rule = this.m_EntryRules[i];
         if (rule.Check())
            totalScore += (int)rule.Weight();
      }
      
      for (int i = 0; i < this.m_RiskRules.Total(); i++)
      {
         IRule* rule = this.m_RiskRules[i];
         if (rule.Check())
            totalScore += (int)rule.Weight();
      }
      
      return totalScore;
   }
   
   //+------------------------------------------------------------------+
   //| Get rule results as string                                     |
   //+------------------------------------------------------------------+
   string GetRuleResults(TradeDecision decision)
   {
      string output = "Rule Results:\n";
      
      for (int i = 0; i < decision.RuleResults.Total(); i++)
      {
         RuleResult result = decision.RuleResults[i];
         string status = result.Passed ? "PASS" : "FAIL";
         output += StringFormat("  %s: %s (%.0f/%.0f)\n", result.Name, status, result.Score, result.Weight);
      }
      
      output += StringFormat("\nTotal Score: %d / %d\n", decision.ConfidenceScore, 100);
      output += "Reasons: " + decision.Reasons;
      
      return output;
   }
   
   //+------------------------------------------------------------------+
   //| Set minimum confidence threshold                              |
   //+------------------------------------------------------------------+
   void SetMinConfidenceScore(int score)
   {
      this.m_MinConfidenceScore = score;
   }
   
   //+------------------------------------------------------------------+
   //| Get minimum confidence threshold                              |
   //+------------------------------------------------------------------+
   int GetMinConfidenceScore()
   {
      return this.m_MinConfidenceScore;
   }
};

//+------------------------------------------------------------------+
//| Global Rule Engine Instance                                     |
//+------------------------------------------------------------------+
CRuleEngine g_RuleEngine;

//+------------------------------------------------------------------+
//| Initialize rule engine                                          |
//+------------------------------------------------------------------+
bool InitializeRuleEngine()
{
   return g_RuleEngine.Initialize();
}
//+------------------------------------------------------------------+
