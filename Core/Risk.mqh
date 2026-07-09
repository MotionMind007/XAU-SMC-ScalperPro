//+------------------------------------------------------------------+
//|                                                          Risk.mqh |
//|                        XAU SMC Scalper Pro - Core Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include <stderror.mqh>
#include "Config\Parameters.mqh"
#include "TradeContext.mqh"
#include "ATR.mqh"

//+------------------------------------------------------------------+
//| Risk Calculation Structure                                      |
//+------------------------------------------------------------------+
struct RiskResult
{
   double LotSize;
   double RiskAmount;
   double StopLoss;
   double TakeProfit;
   double SLDistancePoints;
   double TPDistancePoints;
   double RiskRewardRatio;
};

//+------------------------------------------------------------------+
//| Global Risk Result                                              |
//+------------------------------------------------------------------+
RiskResult g_RiskResult;

//+------------------------------------------------------------------+
//| Initialize risk service                                         |
//+------------------------------------------------------------------+
bool InitializeRisk()
{
   g_RiskResult = RiskResult();
   return true;
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                           |
//+------------------------------------------------------------------+
double CalculateLotSize(double riskPercent, double stopLossPoints)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * riskPercent / 100;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   // Avoid division by zero
   if (tickValue <= 0 || stopLossPoints <= 0)
      return 0.0;
   
   double lotSize = riskAmount / (stopLossPoints * tickValue);
   return NormalizeLot(lotSize);
}

//+------------------------------------------------------------------+
//| Calculate risk amount                                           |
//+------------------------------------------------------------------+
double CalculateRiskAmount(double lotSize, double stopLossPoints)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   return lotSize * stopLossPoints * tickValue;
}

//+------------------------------------------------------------------+
//| Calculate stop loss distance based on market structure          |
//+------------------------------------------------------------------+
double CalculateStopLossDistance()
{
   double atrBuffer = GetATRBuffer();
   return g_Parameters.DefaultSL + atrBuffer;
}

//+------------------------------------------------------------------+
//| Calculate take profit based on risk-reward ratio                |
//+------------------------------------------------------------------+
double CalculateTakeProfitDistance(double slDistance, double rrRatio = 1.5)
{
   return slDistance * rrRatio;
}

//+------------------------------------------------------------------+
//| Calculate full risk-reward result                               |
//+------------------------------------------------------------------+
RiskResult CalculateRiskReward()
{
   RiskResult result;
   
   // Calculate SL distance
   result.SLDistancePoints = CalculateStopLossDistance();
   
   // Calculate lot size
   result.LotSize = CalculateLotSize(g_Parameters.RiskPercent, result.SLDistancePoints);
   
   // Calculate risk amount
   result.RiskAmount = CalculateRiskAmount(result.LotSize, result.SLDistancePoints);
   
   // Calculate TP distance
   result.TPDistancePoints = CalculateTakeProfitDistance(result.SLDistancePoints, 1.5);
   
   // Calculate risk-reward ratio
   result.RiskRewardRatio = result.TPDistancePoints / result.SLDistancePoints;
   
   return result;
}

//+------------------------------------------------------------------+
//| Normalize lot size                                              |
//+------------------------------------------------------------------+
double NormalizeLot(double lotSize)
{
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   lotSize = MathRound(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Check if margin is sufficient                                   |
//+------------------------------------------------------------------+
bool IsMarginSufficient(double lotSize)
{
   double requiredMargin = lotSize * SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_REQUIRED);
   double freeMargin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
   
   return (freeMargin >= requiredMargin * 1.2);  // 20% buffer
}

//+------------------------------------------------------------------+
//| Validate risk parameters                                        |
//+------------------------------------------------------------------+
bool ValidateRiskParameters()
{
   // Check risk percent
   if (g_Parameters.RiskPercent < 0.1 || g_Parameters.RiskPercent > 5.0)
   {
      Print("Error: Risk percent must be between 0.1% and 5%");
      return false;
   }
   
   // Check daily loss limit
   if (g_Parameters.DailyLossLimit < 1 || g_Parameters.DailyLossLimit > 10)
   {
      Print("Error: Daily loss limit must be between 1% and 10%");
      return false;
   }
   
   // Check max trades per day
   if (g_Parameters.MaxTradesPerDay < 1 || g_Parameters.MaxTradesPerDay > 20)
   {
      Print("Error: Max trades per day must be between 1 and 20");
      return false;
   }
   
   return true;
}
//+------------------------------------------------------------------+
