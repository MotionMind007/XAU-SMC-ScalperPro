#ifndef __CORE_NEWSFILTER_MHQ__
#define __CORE_NEWSFILTER_MHQ__
//+------------------------------------------------------------------+
//|                                                        NewsFilter.mqh |
//|                        XAU SMC Scalper Pro - Core Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

// NewsFilter.mqh - Core-level news filtering utilities
// NOTE: NewsEventType, NewsEvent struct, and IsNewsActive/IsNewsSafeToTrade/
// GetNextHighImpactNews/GetTimeUntilNextNews functions are defined in Services\NewsService.mqh
// This file provides additional news filtering state for the core module

#include <datetime\Time.mqh>
#include "Services\NewsService.mqh"

//+------------------------------------------------------------------+
//| News Filter State (core-level)                                  |
//+------------------------------------------------------------------+
bool g_NewsFilterActive = false;
datetime g_LastNewsFilterCheck = 0;
int g_NewsFilterBeforeMinutes = 30;
int g_NewsFilterAfterMinutes = 30;

//+------------------------------------------------------------------+
//| Initialize news filter (core-level)                             |
//+------------------------------------------------------------------+
bool InitializeNewsFilter()
{
   g_NewsFilterActive = false;
   g_LastNewsFilterCheck = 0;
   g_NewsFilterBeforeMinutes = 30;
   g_NewsFilterAfterMinutes = 30;
   
   return true;
}
//+------------------------------------------------------------------+

#endif // __CORE_NEWSFILTER_MHQ__
