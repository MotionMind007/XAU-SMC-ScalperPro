#ifndef __SERVICES_NEWSSERVICE_MHQ__
#define __SERVICES_NEWSSERVICE_MHQ__
//+------------------------------------------------------------------+
//|                                                      NewsService.mqh |
//|                        XAU SMC Scalper Pro - Services Module |
//|                           Copyright 2026, MotionMind |
//|                                       https://motionmind.store |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MotionMind"
#property version   "1.2"
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
         // If file doesn't exist, use hardcoded defaults
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
   //| Load hardcoded default events for XAUUSD                       |
   //| Generates events for the next 12 months                        |
   //+------------------------------------------------------------------+
   bool LoadDefaultEvents()
   {
      // Clear existing events
      ArrayResize(this.m_HighImpactEvents, 0);
      
      datetime now = TimeCurrent();
      MqlDateTime nowStruct;
      TimeToStruct(now, nowStruct);
      
      int currentYear = nowStruct.year;
      int currentMonth = nowStruct.month;
      
      // 20:30 WIB = 13:30 UTC (WIB is UTC+7)
      int eventHour = 13;
      int eventMinute = 30;
      
      // FOMC announcement: 02:00 WIB next day = 19:00 UTC previous day
      int fomcHour = 19;
      int fomcMinute = 0;
      
      // Generate events for next 12 months
      for (int m = 0; m < 12; m++)
      {
         int targetMonth = currentMonth + m;
         int targetYear = currentYear;
         while (targetMonth > 12)
         {
            targetMonth -= 12;
            targetYear++;
         }
         
         // === NFP (Non-Farm Payrolls) - First Friday of month ===
         datetime nfpDate = GetFirstFridayOfMonth(targetYear, targetMonth);
         datetime nfpTime = SetTimeOnDate(nfpDate, eventHour, eventMinute);
         AddEvent(nfpTime, NEWS_HIGH_IMPACT, "US", "NFP", 30, 30);
         
         // === CPI (Consumer Price Index) - ~12th of month ===
         datetime cpiDate = SetDayOnMonth(targetYear, targetMonth, 12);
         datetime cpiTime = SetTimeOnDate(cpiDate, eventHour, eventMinute);
         AddEvent(cpiTime, NEWS_HIGH_IMPACT, "US", "CPI", 30, 30);
         
         // === PPI (Producer Price Index) - ~15th of month ===
         datetime ppiDate = SetDayOnMonth(targetYear, targetMonth, 15);
         datetime ppiTime = SetTimeOnDate(ppiDate, eventHour, eventMinute);
         AddEvent(ppiTime, NEWS_HIGH_IMPACT, "US", "PPI", 30, 30);
         
         // === Unemployment Claims - First Thursday of month (day before NFP) ===
         datetime unempDate = GetFirstThursdayOfMonth(targetYear, targetMonth);
         datetime unempTime = SetTimeOnDate(unempDate, eventHour, eventMinute);
         AddEvent(unempTime, NEWS_HIGH_IMPACT, "US", "Unemployment", 30, 30);
         
         // === GDP - Quarterly (Jan, Apr, Jul, Oct) - ~28th of month ===
         if (targetMonth == 1 || targetMonth == 4 || targetMonth == 7 || targetMonth == 10)
         {
            datetime gdpDate = SetDayOnMonth(targetYear, targetMonth, 28);
            datetime gdpTime = SetTimeOnDate(gdpDate, eventHour, eventMinute);
            AddEvent(gdpTime, NEWS_HIGH_IMPACT, "US", "GDP", 30, 30);
         }
      }
      
      // === FOMC (Federal Open Market Committee) ===
      // 8 meetings per year, announced on Wednesdays
      // Approximate 2026 dates (second or fourth Wednesday of meeting months)
      // Standard FOMC months: Jan, Mar, May, Jun, Jul, Sep, Nov, Dec
      int fomcMonths[];
      int fomcDays[];
      ArrayResize(fomcMonths, 8);
      ArrayResize(fomcDays, 8);
      
      // 2026 approximate FOMC announcement dates (Wednesdays)
      fomcMonths[0] = 1;  fomcDays[0] = 28;   // Jan 28
      fomcMonths[1] = 3;  fomcDays[1] = 18;   // Mar 18
      fomcMonths[2] = 5;  fomcDays[2] = 6;    // May 6
      fomcMonths[3] = 6;  fomcDays[3] = 17;   // Jun 17
      fomcMonths[4] = 7;  fomcDays[4] = 29;   // Jul 29
      fomcMonths[5] = 9;  fomcDays[5] = 16;   // Sep 16
      fomcMonths[6] = 11; fomcDays[6] = 4;    // Nov 4
      fomcMonths[7] = 12; fomcDays[7] = 9;    // Dec 9
      
      for (int i = 0; i < 8; i++)
      {
         datetime fomcDate = StringToTime(
            IntegerToString(fomcMonths[i] < 10 ? "0" : "") + IntegerToString(fomcMonths[i]) + "." +
            IntegerToString(fomcDays[i] < 10 ? "0" : "") + IntegerToString(fomcDays[i]) + "." +
            IntegerToString(currentYear));
         
         datetime fomcTime = SetTimeOnDate(fomcDate, fomcHour, fomcMinute);
         
         // Only add if in the future (within next 12 months)
         if (fomcTime > now && fomcTime < now + 365 * 24 * 60 * 60)
         {
            AddEvent(fomcTime, NEWS_HIGH_IMPACT, "US", "FOMC", 30, 30);
         }
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Add event to the array                                         |
   //+------------------------------------------------------------------+
   void AddEvent(datetime eventTime, NewsEventType type, string country, 
                 string name, int beforeMin, int afterMin)
   {
      NewsEvent ne;
      ne.EventTime = eventTime;
      ne.EventType = type;
      ne.Country = country;
      ne.EventName = name;
      ne.ImpactMinutesBefore = beforeMin;
      ne.ImpactMinutesAfter = afterMin;
      
      int size = ArraySize(this.m_HighImpactEvents);
      ArrayResize(this.m_HighImpactEvents, size + 1);
      this.m_HighImpactEvents[size] = ne;
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
   //| Get first Thursday of a specific month                         |
   //+------------------------------------------------------------------+
   datetime GetFirstThursdayOfMonth(int year, int month)
   {
      datetime date = StringToTime(IntegerToString(year) + "." + IntegerToString(month) + ".01");
      MqlDateTime md;
      TimeToStruct(date, md);
      
      int daysToAdd = 4 - md.day_of_week;
      if (daysToAdd < 0)
         daysToAdd += 7;
      
      return date + daysToAdd * 24 * 60 * 60;
   }
   
   //+------------------------------------------------------------------+
   //| Set a specific day on a month, clamping to valid days          |
   //+------------------------------------------------------------------+
   datetime SetDayOnMonth(int year, int month, int day)
   {
      // Get max days in month
      datetime nextMonth;
      if (month == 12)
         nextMonth = StringToTime(IntegerToString(year + 1) + ".01.01");
      else
         nextMonth = StringToTime(IntegerToString(year) + "." + IntegerToString(month + 1) + ".01");
      
      datetime thisMonth = StringToTime(IntegerToString(year) + "." + IntegerToString(month) + ".01");
      int maxDays = (int)((nextMonth - thisMonth) / (24 * 60 * 60));
      
      if (day > maxDays)
         day = maxDays;
      
      return thisMonth + (day - 1) * 24 * 60 * 60;
   }
   
   //+------------------------------------------------------------------+
   //| Set time on a given date                                       |
   //+------------------------------------------------------------------+
   datetime SetTimeOnDate(datetime date, int hour, int minute)
   {
      MqlDateTime dt;
      TimeToStruct(date, dt);
      dt.hour = hour;
      dt.min = minute;
      dt.sec = 0;
      return StructToTime(dt);
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
   //| Get time until next news event (in minutes)                   |
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

#endif // __SERVICES_NEWSSERVICE_MHQ__
