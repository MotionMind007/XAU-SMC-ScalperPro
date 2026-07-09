//+------------------------------------------------------------------+
//|                                                        NewsFilter.mqh |
//|                        XAU SMC Scalper Pro - Core Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include <datetime\Time.mqh>

//+------------------------------------------------------------------+
//| News Event Types                                                 |
//+------------------------------------------------------------------+
enum NewsEventType
{
   NEWS_NONE = 0,
   NEWS_HIGH_IMPACT = 1,      // NFP, CPI, FOMC, etc.
   NEWS_MEDIUM_IMPACT = 2,    // GDP, PMI, etc.
   NEWS_LOW_IMPACT = 3        // Various indices
};

//+------------------------------------------------------------------+
//| News Event Structure                                             |
//+------------------------------------------------------------------+
struct NewsEvent
{
   datetime EventTime;
   NewsEventType EventType;
   string Country;
   string EventName;
   bool Active;              // True if currently in impact window
};

//+------------------------------------------------------------------+
//| News Filter State                                               |
//+------------------------------------------------------------------+
bool g_NewsActive = false;
datetime g_LastNewsCheck = 0;
int g_NewsBeforeMinutes = 30;
int g_NewsAfterMinutes = 30;

//+------------------------------------------------------------------+
//| List of high-impact news events (sample)                       |
//+------------------------------------------------------------------+
NewsEvent g_HighImpactEvents[] =
{
   // NFP - Non-Farm Payrolls (First Friday of each month)
   {0, NEWS_HIGH_IMPACT, "US", "NFP", false},
   {0, NEWS_HIGH_IMPACT, "US", "NFP", false},
   {0, NEWS_HIGH_IMPACT, "US", "NFP", false},
   
   // FOMC - Federal Open Market Committee
   {0, NEWS_HIGH_IMPACT, "US", "FOMC", false},
   {0, NEWS_HIGH_IMPACT, "US", "FOMC", false},
   {0, NEWS_HIGH_IMPACT, "US", "FOMC", false},
   
   // CPI - Consumer Price Index
   {0, NEWS_HIGH_IMPACT, "US", "CPI", false},
   {0, NEWS_HIGH_IMPACT, "US", "CPI", false},
   {0, NEWS_HIGH_IMPACT, "US", "CPI", false},
   
   // PPI - Producer Price Index
   {0, NEWS_HIGH_IMPACT, "US", "PPI", false},
   
   // Interest Rate Decisions
   {0, NEWS_HIGH_IMPACT, "US", "Interest Rate", false},
   {0, NEWS_HIGH_IMPACT, "EU", "Interest Rate", false},
   
   // GDP - Gross Domestic Product
   {0, NEWS_HIGH_IMPACT, "US", "GDP", false},
};

//+------------------------------------------------------------------+
//| Initialize news filter                                          |
//+------------------------------------------------------------------+
bool InitializeNewsFilter()
{
   g_NewsActive = false;
   g_LastNewsCheck = 0;
   g_NewsBeforeMinutes = 30;
   g_NewsAfterMinutes = 30;
   
   // TODO: Load actual news events from external source or file
   // For now, initialize with placeholder data
   
   return true;
}

bool IsNewsActive()
{
   return g_NewsService.IsNewsActive();
}

//+------------------------------------------------------------------+
//| Get next high-impact news time                                 |
//+------------------------------------------------------------------+
datetime GetNextHighImpactNews()
{
   datetime nextNews = 0;
   datetime now = TimeCurrent();
   
   for (int i = 0; i < ArraySize(g_HighImpactEvents); i++)
   {
      NewsEvent event = g_HighImpactEvents[i];
      
      if (event.EventTime > now && (nextNews == 0 || event.EventTime < nextNews))
         nextNews = event.EventTime;
   }
   
   return nextNews;
}

//+------------------------------------------------------------------+
//| Get time until next news event                                 |
//+------------------------------------------------------------------+
int GetTimeUntilNextNews()
{
   datetime nextNews = GetNextHighImpactNews();
   
   if (nextNews == 0)
      return -1;  // No upcoming news
   
   return (int)(nextNews - TimeCurrent()) / 60;  // Minutes
}

//+------------------------------------------------------------------+
//| Check if trading is allowed around news                        |
//+------------------------------------------------------------------+
bool IsNewsSafeToTrade()
{
   if (!IsNewsActive())
      return true;
   
   return false;
}
//+------------------------------------------------------------------+
