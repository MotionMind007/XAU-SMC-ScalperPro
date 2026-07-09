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
   
   // Session times (in UTC+0, adjust for your broker's timezone)
   // London: 08:00 - 16:00 UTC
   // New York: 13:00 - 21:00 UTC
   // Overlap: 13:00 - 16:00 UTC
   
   // London session (08:00 - 16:00 UTC)
   int londonStart = 8 * 60;      // 08:00
   int londonEnd = 16 * 60;       // 16:00
   
   // New York session (13:00 - 21:00 UTC)
   int nyStart = 13 * 60;         // 13:00
   int nyEnd = 21 * 60;           // 21:00
   
   // Overlap (13:00 - 16:00 UTC)
   int overlapStart = 13 * 60;
   int overlapEnd = 16 * 60;
   
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
   
   if (totalMinutes >= 13 * 60 && totalMinutes < 16 * 60)  // Overlap
      sessionEnd = 16 * 60;
   else if (totalMinutes >= 8 * 60 && totalMinutes < 16 * 60)  // London
      sessionEnd = 16 * 60;
   else if (totalMinutes >= 13 * 60 && totalMinutes < 21 * 60)  // NY
      sessionEnd = 21 * 60;
   else
      return 0;
   
   return sessionEnd - totalMinutes;
}
//+------------------------------------------------------------------+
