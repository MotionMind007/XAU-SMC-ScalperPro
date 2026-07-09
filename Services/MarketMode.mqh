//+------------------------------------------------------------------+
//|                                                     MarketMode.mqh |
//|                        XAU SMC Scalper Pro - Services Module |
//|                           Copyright 2026, MotionMind |
//|                                       https://motionmind.store |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MotionMind"
#property version   "1.1"
#property strict

#include "Core\\TradeContext.mqh"

//+------------------------------------------------------------------+
//| Market Mode Detection Service                                    |
//| Uses H1 ATR(14) compared to 50-bar average to determine mode    |
//+------------------------------------------------------------------+

// Global ATR handles for market mode calculation
int g_MM_ATR_Handle = INVALID_HANDLE;
double g_MM_ATR_Buffer[];
datetime g_MM_LastUpdate = 0;
double g_MM_AtrAverage = 0.0;
double g_MM_CurrentATR = 0.0;

//+------------------------------------------------------------------+
//| Initialize Market Mode service                                   |
//+------------------------------------------------------------------+
bool InitializeMarketMode()
{
   g_MM_ATR_Handle = INVALID_HANDLE;
   g_MM_LastUpdate = 0;
   g_MM_AtrAverage = 0.0;
   g_MM_CurrentATR = 0.0;
   
   // Create ATR(14) on H1 for market mode detection
   g_MM_ATR_Handle = iATR(_Symbol, PERIOD_H1, 14);
   if (g_MM_ATR_Handle == INVALID_HANDLE)
   {
      Print("MarketMode: Failed to create H1 ATR handle");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Cleanup Market Mode handles                                      |
//+------------------------------------------------------------------+
void CleanupMarketMode()
{
   if (g_MM_ATR_Handle != INVALID_HANDLE)
   {
      IndicatorRelease(g_MM_ATR_Handle);
      g_MM_ATR_Handle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Calculate ATR average over last N bars                           |
//+------------------------------------------------------------------+
double CalculateH1ATRAverage(int bars = 50)
{
   if (g_MM_ATR_Handle == INVALID_HANDLE)
      return 0.0;
   
   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   
   int copied = CopyBuffer(g_MM_ATR_Handle, 0, 1, bars, atrValues);
   if (copied < bars)
   {
      Print("MarketMode: Insufficient H1 ATR data, copied=", copied);
      return 0.0;
   }
   
   double sum = 0.0;
   for (int i = 0; i < copied; i++)
      sum += atrValues[i];
   
   return sum / (double)copied;
}

//+------------------------------------------------------------------+
//| Get current H1 ATR(14) value                                    |
//+------------------------------------------------------------------+
double GetCurrentH1ATR()
{
   if (g_MM_ATR_Handle == INVALID_HANDLE)
      return 0.0;
   
   double atrValues[];
   if (CopyBuffer(g_MM_ATR_Handle, 0, 0, 1, atrValues) != 1)
      return 0.0;
   
   return atrValues[0];
}

//+------------------------------------------------------------------+
//| Calculate Market Mode based on H1 ATR comparison                |
//| Rules:                                                           |
//|   - ATR > 1.5x average  -> MODE_VOLATILE                        |
//|   - ATR > average       -> MODE_TRENDING                        |
//|   - ATR <= average      -> MODE_RANGING                         |
//|   - ATR too low/extreme -> MODE_NO_TRADE                        |
//+------------------------------------------------------------------+
int CalculateMarketMode()
{
   datetime now = TimeCurrent();
   
   // Only recalculate every 60 seconds to avoid excessive computation
   if (now - g_MM_LastUpdate < 60 && g_MM_AtrAverage > 0)
   {
      return g_TradeContext.MarketMode;
   }
   
   g_MM_LastUpdate = now;
   
   // Get current H1 ATR
   g_MM_CurrentATR = GetCurrentH1ATR();
   if (g_MM_CurrentATR <= 0)
      return MODE_NO_TRADE;
   
   // Get ATR average over last 50 bars
   g_MM_AtrAverage = CalculateH1ATRAverage(50);
   if (g_MM_AtrAverage <= 0)
      return MODE_NO_TRADE;
   
   // For XAUUSD H1, check absolute thresholds first
   // ATR < 3.0 = too quiet, ATR > 40.0 = extreme
   if (g_MM_CurrentATR < 3.0)
   {
      g_TradeContext.MarketMode = MODE_NO_TRADE;
      return MODE_NO_TRADE;
   }
   
   if (g_MM_CurrentATR > 40.0)
   {
      g_TradeContext.MarketMode = MODE_NO_TRADE;
      return MODE_NO_TRADE;
   }
   
   // Compare current ATR to average
   double ratio = g_MM_CurrentATR / g_MM_AtrAverage;
   
   if (ratio > 1.5)
   {
      g_TradeContext.MarketMode = MODE_VOLATILE;
      return MODE_VOLATILE;
   }
   else if (ratio > 1.0)
   {
      g_TradeContext.MarketMode = MODE_TRENDING;
      return MODE_TRENDING;
   }
   else
   {
      g_TradeContext.MarketMode = MODE_RANGING;
      return MODE_RANGING;
   }
}

//+------------------------------------------------------------------+
//| Get market mode as string                                        |
//+------------------------------------------------------------------+
string GetMarketModeString()
{
   switch (g_TradeContext.MarketMode)
   {
      case MODE_TRENDING:  return "TRENDING";
      case MODE_RANGING:   return "RANGING";
      case MODE_VOLATILE:  return "VOLATILE";
      case MODE_NO_TRADE:  return "NO_TRADE";
      default:             return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Get ATR comparison summary                                       |
//+------------------------------------------------------------------+
string GetMarketModeSummary()
{
   return StringFormat("Mode=%s, ATR=%.2f, Avg=%.2f, Ratio=%.2f",
      GetMarketModeString(), g_MM_CurrentATR, g_MM_AtrAverage,
      (g_MM_AtrAverage > 0 ? g_MM_CurrentATR / g_MM_AtrAverage : 0.0));
}
//+------------------------------------------------------------------+
