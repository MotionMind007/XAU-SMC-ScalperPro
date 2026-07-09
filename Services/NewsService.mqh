//+------------------------------------------------------------------+
//|                                                      NewsService.mqh |
//|                        XAU SMC Scalper Pro - Services Module |
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
   NEWS_HIGH_IMPACT = 1,
   NEWS_MEDIUM_IMPACT = 2,
   NEWS_LOW_IMPACT = 3
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
   int ImpactMinutesBefore;
   int ImpactMinutesAfter;
};

//+------------------------------------------------------------------+
//| News Service Interface                                           |
//+------------------------------------------------------------------+
class INewsService
{
public:
   virtual bool IsNewsActive() = 0;
   virtual bool IsNewsSafeToTrade() = 0;
   virtual datetime GetNextHighImpactNews() = 0;
   virtual int GetTimeUntilNextNews() = 0;
   virtual void LoadEvents() = 0;
   virtual void SetNewsWindow(int beforeMinutes, int afterMinutes) = 0;
   
   virtual ~INewsService() {}
};

//+------------------------------------------------------------------+
//| File-based News Service Implementation                          |
//+------------------------------------------------------------------+
class CFileNewsService : public INewsService
{
private:
   string m_NewsFilePath;
   NewsEvent m_HighImpactEvents[];
   int m_NewsBeforeMinutes;
   int m_NewsAfterMinutes;
   datetime m_LastCheck;
   bool m_NewsActive;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void CFileNewsService()
   {
      this.m_NewsFilePath = "NewsEvents.csv";
      this.m_NewsBeforeMinutes = 30;
      this.m_NewsAfterMinutes = 30;
      this.m_LastCheck = 0;
      this.m_NewsActive = false;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize news service                                        |
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      // Try to load events from file
      if (!this.LoadEvents())
      {
         // If file doesn't exist, use defaults
         this.LoadDefaultEvents();
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Load events from CSV file                                      |
   //+------------------------------------------------------------------+
   bool LoadEvents()
   {
      int handle = FileOpen(this.m_NewsFilePath, FILE_READ|FILE_CSV|FILE_SHARE_READ);
      
      if (handle == INVALID_HANDLE)
         return false;
      
      // Clear existing events
      ArrayResize(this.m_HighImpactEvents, 0);
      
      // Read events from file
      while (!FileIsEnding(handle))
      {
         string line = FileReadString(handle);
         if (line == "")
            continue;
         
         // Parse CSV: EventTime,EventType,Country,EventName,ImpactBefore,ImpactAfter
         string parts[];
         int count = StringSplit(line, ',', parts);
         
         if (count >= 6)
         {
            NewsEvent ne;
            ne.EventTime = StringToTime(parts[0]);
            ne.EventType = (NewsEventType)StringToInteger(parts[1]);
            ne.Country = parts[2];
            ne.EventName = parts[3];
            ne.ImpactMinutesBefore = StringToInteger(parts[4]);
            ne.ImpactMinutesAfter = StringToInteger(parts[5]);
            
            ArrayResize(this.m_HighImpactEvents, ArraySize(this.m_HighImpactEvents) + 1);
            this.m_HighImpactEvents[ArraySize(this.m_HighImpactEvents) - 1] = ne;
         }
      }
      
      FileClose(handle);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Load default events                                            |
   //+------------------------------------------------------------------+
   bool LoadDefaultEvents()
   {
      // Clear existing events
      ArrayResize(this.m_HighImpactEvents, 0);
      
      // Add default high impact events
      datetime now = TimeCurrent();
      
      // NFP (First Friday of each month)
      for (int i = 0; i < 12; i++)
      {
         NewsEvent ne;
         ne.EventTime = this.GetFirstFridayOfMonth(TimeYear(now), TimeMonth(now) + i);
         ne.EventType = NEWS_HIGH_IMPACT;
         ne.Country = "US";
         ne.EventName = "NFP";
         ne.ImpactMinutesBefore = 30;
         ne.ImpactMinutesAfter = 30;
         ArrayResize(this.m_HighImpactEvents, ArraySize(this.m_HighImpactEvents) + 1);
         this.m_HighImpactEvents[ArraySize(this.m_HighImpactEvents) - 1] = ne;
      }
      
      // FOMC (8 times per year)
      for (int i = 0; i < 8; i++)
      {
         NewsEvent ne;
         ne.EventTime = now + i * 30 * 24 * 60 * 60;  // Every 30 days
         ne.EventType = NEWS_HIGH_IMPACT;
         ne.Country = "US";
         ne.EventName = "FOMC";
         ne.ImpactMinutesBefore = 30;
         ne.ImpactMinutesAfter = 30;
         ArrayResize(this.m_HighImpactEvents, ArraySize(this.m_HighImpactEvents) + 1);
         this.m_HighImpactEvents[ArraySize(this.m_HighImpactEvents) - 1] = ne;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get first Friday of a specific month                           |
   //+------------------------------------------------------------------+
   datetime GetFirstFridayOfMonth(int year, int month)
   {
      datetime date = StringToTime(IntegerToString(year) + "." + IntegerToString(month) + ".01");
      MqlDateTime md;
      TimeToStruct(date, md);
      
      int daysToAdd = 5 - md.day_of_week;
      if (daysToAdd < 0)
         daysToAdd += 7;
      
      return date + daysToAdd * 24 * 60 * 60;
   }
   
   //+------------------------------------------------------------------+
   //| Check if news is currently active                              |
   //+------------------------------------------------------------------+
   bool IsNewsActive()
   {
      datetime now = TimeCurrent();
      
      // Only check every 5 minutes
      if (now - this.m_LastCheck < 300)
         return this.m_NewsActive;
      
      this.m_LastCheck = now;
      this.m_NewsActive = false;
      
      // Check each high-impact event
      for (int i = 0; i < ArraySize(this.m_HighImpactEvents); i++)
      {
         NewsEvent event = this.m_HighImpactEvents[i];
         
         if (event.EventTime == 0)
            continue;
         
         // Calculate impact window
         datetime beforeWindow = event.EventTime - event.ImpactMinutesBefore * 60;
         datetime afterWindow = event.EventTime + event.ImpactMinutesAfter * 60;
         
         if (now >= beforeWindow && now <= afterWindow)
         {
            this.m_NewsActive = true;
            break;
         }
      }
      
      return this.m_NewsActive;
   }
   
   //+------------------------------------------------------------------+
   //| Check if trading is safe around news                           |
   //+------------------------------------------------------------------+
   bool IsNewsSafeToTrade()
   {
      return !this.IsNewsActive();
   }
   
   //+------------------------------------------------------------------+
   //| Get next high-impact news time                                 |
   //+------------------------------------------------------------------+
   datetime GetNextHighImpactNews()
   {
      datetime nextNews = 0;
      datetime now = TimeCurrent();
      
      for (int i = 0; i < ArraySize(this.m_HighImpactEvents); i++)
      {
         NewsEvent event = this.m_HighImpactEvents[i];
         
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
      datetime nextNews = this.GetNextHighImpactNews();
      
      if (nextNews == 0)
         return -1;
      
      return (int)(nextNews - TimeCurrent()) / 60;
   }
   
   //+------------------------------------------------------------------+
   //| Set news impact window                                         |
   //+------------------------------------------------------------------+
   void SetNewsWindow(int beforeMinutes, int afterMinutes)
   {
      this.m_NewsBeforeMinutes = beforeMinutes;
      this.m_NewsAfterMinutes = afterMinutes;
      
      // Update all events with new window
      for (int i = 0; i < ArraySize(this.m_HighImpactEvents); i++)
      {
         this.m_HighImpactEvents[i].ImpactMinutesBefore = beforeMinutes;
         this.m_HighImpactEvents[i].ImpactMinutesAfter = afterMinutes;
      }
   }
};

//+------------------------------------------------------------------+
//| Global News Service Instance                                    |
//+------------------------------------------------------------------+
CFileNewsService g_NewsService;

//+------------------------------------------------------------------+
//| Initialize news service                                         |
//+------------------------------------------------------------------+
bool InitializeNewsService()
{
   return g_NewsService.Initialize();
}

//+------------------------------------------------------------------+
//| Check if news is active (wrapper)                              |
//+------------------------------------------------------------------+
bool IsNewsActive()
{
   return g_NewsService.IsNewsActive();
}

//+------------------------------------------------------------------+
//| Check if news safe to trade (wrapper)                          |
//+------------------------------------------------------------------+
bool IsNewsSafeToTrade()
{
   return g_NewsService.IsNewsSafeToTrade();
}

//+------------------------------------------------------------------+
//| Get next high-impact news (wrapper)                            |
//+------------------------------------------------------------------+
datetime GetNextHighImpactNews()
{
   return g_NewsService.GetNextHighImpactNews();
}

//+------------------------------------------------------------------+
//| Get time until next news (wrapper)                             |
//+------------------------------------------------------------------+
int GetTimeUntilNextNews()
{
   return g_NewsService.GetTimeUntilNextNews();
}
//+------------------------------------------------------------------+
