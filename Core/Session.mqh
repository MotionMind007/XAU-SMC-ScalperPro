#ifndef __CORE_SESSION_MHQ__
#define __CORE_SESSION_MHQ__
//+------------------------------------------------------------------+
//|                                                          Session.mqh |
//|                        XAU SMC Scalper Pro - Core Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include <datetime\Time.mqh>

//+------------------------------------------------------------------+
//| Session Types                                                    |
//+------------------------------------------------------------------+
enum SessionType
{
   SESSION_NONE = 0,
   SESSION_LONDON = 1,
   SESSION_NEWYORK = 2,
   SESSION_OVERLAP = 3
};

//+------------------------------------------------------------------+
//| Session Parameters                                               |
//+------------------------------------------------------------------+
struct SessionConfig
{
   int StartHour;
   int StartMinute;
   int EndHour;
   int EndMinute;
   bool IsTradingSession;
};

//+------------------------------------------------------------------+
//| Current session state                                           |
//+------------------------------------------------------------------+
int g_CurrentSession = SESSION_NONE;
datetime g_LastSessionUpdate = 0;

//+------------------------------------------------------------------+
//| Get current session from server time                           |
//+------------------------------------------------------------------+
int GetCurrentSession()
{
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);
   
   int hour = time.hour;
   int minute = time.min;
   int totalMinutes = hour * 60 + minute;
   
   // Session times in UTC (converted from WIB = UTC+7 per PRD)
   // Asia:   02:00-08:00 WIB = 19:00-01:00 UTC (spans midnight)
   // London: 15:00-19:00 WIB = 08:00-12:00 UTC
   // NY:     20:00-00:00 WIB = 13:00-17:00 UTC
   // Overlap: London ∩ NY  = 13:00-12:00 UTC (only if London extends, but
   //          with new London ending at 12:00 and NY starting at 13:00,
   //          there is no overlap — kept for compatibility)
   
   // Asia session (19:00 - 01:00 UTC, spans midnight)
   int asiaStart = 19 * 60;      // 19:00 UTC = 02:00 WIB
   int asiaEnd = 1 * 60;         // 01:00 UTC = 08:00 WIB
   
   // London session (08:00 - 12:00 UTC)
   int londonStart = 8 * 60;     // 08:00 UTC = 15:00 WIB
   int londonEnd = 12 * 60;      // 12:00 UTC = 19:00 WIB
   
   // New York session (13:00 - 17:00 UTC)
   int nyStart = 13 * 60;        // 13:00 UTC = 20:00 WIB
   int nyEnd = 17 * 60;          // 17:00 UTC = 00:00 WIB
   
   // Overlap: London (08-12) and NY (13-17) no longer overlap with
   // tightened PRD times.  Keep the slot for future flexibility.
   int overlapStart = 13 * 60;   // placeholder — no real overlap
   int overlapEnd = 12 * 60;     // empty range
   
   // Check Asia (spans midnight: 19:00 - 01:00 UTC)
   if (hour >= 19 || hour < 1)
       return SESSION_NONE;  // PRD: No trading during Asia session
   
   // Check overlap (empty with new times, kept for compatibility)
   if (totalMinutes >= overlapStart && totalMinutes < overlapEnd)
      return SESSION_OVERLAP;
   
   if (totalMinutes >= londonStart && totalMinutes < londonEnd)
      return SESSION_LONDON;
   
   if (totalMinutes >= nyStart && totalMinutes < nyEnd)
      return SESSION_NEWYORK;
   
   return SESSION_NONE;
}

//+------------------------------------------------------------------+
//| Check if session is active                                       |
//+------------------------------------------------------------------+
bool IsSessionActive(int session)
{
   return (session == SESSION_LONDON || 
           session == SESSION_NEWYORK || 
           session == SESSION_OVERLAP);
}

//+------------------------------------------------------------------+
//| Check if current session is valid for trading                  |
//+------------------------------------------------------------------+
bool IsTradingSession()
{
   int currentSession = GetCurrentSession();
   return IsSessionActive(currentSession);
}

//+------------------------------------------------------------------+
//| Get session name as string                                      |
//+------------------------------------------------------------------+
string GetSessionName(int session)
{
   switch (session)
   {
      case SESSION_LONDON: return "London";
      case SESSION_NEWYORK: return "New York";
      case SESSION_OVERLAP: return "Overlap";
      default: return "None";
   }
}

//+------------------------------------------------------------------+
//| Calculate time remaining in current session                    |
//+------------------------------------------------------------------+
int GetTimeRemainingInSession()
{
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);
   
   int hour = time.hour;
   int minute = time.min;
   int totalMinutes = hour * 60 + minute;
   
   int sessionEnd = 0;
   
   // Asia (19:00-01:00 UTC, spans midnight)
   if (hour >= 19 || hour < 1)
   {
      // Asia ends at 01:00 UTC = 60 minutes
      sessionEnd = (hour >= 19) ? (24 * 60) + 1 * 60 : 1 * 60;
   }
   // London (08:00-12:00 UTC)
   else if (totalMinutes >= 8 * 60 && totalMinutes < 12 * 60)
   {
      sessionEnd = 12 * 60;
   }
   // NY (13:00-17:00 UTC)
   else if (totalMinutes >= 13 * 60 && totalMinutes < 17 * 60)
   {
      sessionEnd = 17 * 60;
   }
   else
   {
      return 0;
   }
   
   return sessionEnd - totalMinutes;
}
//+------------------------------------------------------------------+

#endif // __CORE_SESSION_MHQ__
