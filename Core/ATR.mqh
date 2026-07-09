#ifndef __CORE_ATR_MHQ__
#define __CORE_ATR_MHQ__
//+------------------------------------------------------------------+
//|                                                            ATR.mqh |
//|                        XAU SMC Scalper Pro - Core Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include <stderror.mqh>
#include "TradeContext.mqh"

//+------------------------------------------------------------------+
//| ATR State Enumerations                                           |
//+------------------------------------------------------------------+
enum ATRMode
{
   ATR_LOW = 1,        // Very low volatility - avoid trading
   ATR_NORMAL = 2,     // Normal volatility - trade as normal
   ATR_HIGH = 3,       // High volatility - reduce risk
   ATR_EXTREME = 4     // Extreme volatility - no trading
};

//+------------------------------------------------------------------+
//| Global ATR State                                                |
//+------------------------------------------------------------------+
double g_ATR_14 = 0.0;
double g_ATR_Buffer = 1.5;
ATRMode g_ATR_Mode = ATR_NORMAL;
datetime g_ATR_LastUpdate = 0;

//+------------------------------------------------------------------+
//| Initialize ATR service                                          |
//+------------------------------------------------------------------+
bool InitializeATR()
{
   g_ATR_14 = 0.0;
   g_ATR_Buffer = 1.5;
   g_ATR_Mode = ATR_NORMAL;
   g_ATR_LastUpdate = 0;
   
   // Initialize ATR indicator
   int handle = iATR(_Symbol, PERIOD_M5, 14);
   if (handle == INVALID_HANDLE)
      return false;
   
   // Store handle for release on deinit
   g_ATR_Handle = handle;
   
   return true;
}

//+------------------------------------------------------------------+
//| ATR handle for cleanup                                          |
//+------------------------------------------------------------------+
int g_ATR_Handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Calculate ATR for specified period                              |
//+------------------------------------------------------------------+
double CalculateATR(int period = 14)
{
   double atrArray[];
   
   // Use cached handle instead of creating new one
   if (g_ATR_Handle == INVALID_HANDLE)
   {
      g_ATR_Handle = iATR(_Symbol, PERIOD_M5, period);
      if (g_ATR_Handle == INVALID_HANDLE)
         return 0.0;
   }
   
   if (CopyBuffer(g_ATR_Handle, 0, 0, 1, atrArray) != 1)
   {
      Print("Error copying ATR buffer: " + ErrorDescription(GetLastError()));
      return 0.0;
   }
   
   g_ATR_14 = atrArray[0];
   g_ATR_LastUpdate = TimeCurrent();
   
   // Update TradeContext
   g_TradeContext.ATR_14 = g_ATR_14;
   g_TradeContext.ATR_Buffer = g_ATR_Buffer;
   
   return g_ATR_14;
}

//+------------------------------------------------------------------+
//| Determine ATR mode based on current value                       |
//+------------------------------------------------------------------+
ATRMode DetermineATRMode()
{
   // For XAUUSD M5, ATR(14) is typically 15-50+ (in price units)
   // Use thresholds in price units, not points
   double atrValue = g_ATR_14;
   
   // Thresholds in price units (approximately):
   // LOW: ATR < 5.0 (very quiet, avoid trading)
   // NORMAL: 5.0 <= ATR <= 15.0 (normal trading range)
   // HIGH: 15.0 < ATR <= 30.0 (increased volatility)
   // EXTREME: ATR > 30.0 (very volatile, avoid trading)
   
   if (atrValue < 5.0)
      return ATR_LOW;
   else if (atrValue <= 15.0)
      return ATR_NORMAL;
   else if (atrValue <= 30.0)
      return ATR_HIGH;
   else
      return ATR_EXTREME;
}

//+------------------------------------------------------------------+
//| Check if ATR is within acceptable range                         |
//+------------------------------------------------------------------+
bool IsATRAcceptable()
{
   ATRMode mode = DetermineATRMode();
   
   if (mode == ATR_LOW || mode == ATR_EXTREME)
   {
      g_TradeContext.MarketMode = MODE_NO_TRADE;
      return false;
   }
   
   g_TradeContext.MarketMode = (mode == ATR_HIGH) ? MODE_VOLATILE : MODE_TRENDING;
   return true;
}

//+------------------------------------------------------------------+
//| Get ATR buffer in points                                         |
//+------------------------------------------------------------------+
double GetATRBuffer()
{
   return g_ATR_Buffer * g_ATR_14;
}

//+------------------------------------------------------------------+
//| Update ATR and calculate mode                                   |
//+------------------------------------------------------------------+
bool UpdateATR()
{
   if (CalculateATR(14) <= 0)
      return false;
   
   g_ATR_Mode = DetermineATRMode();
   return IsATRAcceptable();
}

//+------------------------------------------------------------------+
//| Get ATR mode as string                                          |
//+------------------------------------------------------------------+
string GetATRModeString()
{
   switch (g_ATR_Mode)
   {
      case ATR_LOW: return "LOW";
      case ATR_NORMAL: return "NORMAL";
      case ATR_HIGH: return "HIGH";
      case ATR_EXTREME: return "EXTREME";
      default: return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Cleanup ATR handle on deinit                                    |
//+------------------------------------------------------------------+
void CleanupATR()
{
   if (g_ATR_Handle != INVALID_HANDLE)
   {
      IndicatorRelease(g_ATR_Handle);
      g_ATR_Handle = INVALID_HANDLE;
   }
}
//+------------------------------------------------------------------+

#endif // __CORE_ATR_MHQ__
