//+------------------------------------------------------------------+
//|                                                     TimeService.mqh |
//|                        XAU SMC Scalper Pro - Services Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include <datetime\Time.mqh>

//+------------------------------------------------------------------+
//| Time Service Interface                                          |
//+------------------------------------------------------------------+
class ITimeService
{
public:
   virtual datetime GetServerTime() = 0;
   virtual int GetCurrentHour() = 0;
   virtual int GetCurrentMinute() = 0;
   virtual int GetDayOfWeek() = 0;
   virtual bool IsNewBar(int timeframe) = 0;
   virtual datetime GetBarTime(int timeframe, int bar) = 0;
   virtual int GetBarsPerDay(int timeframe) = 0;
   virtual void ResetDailyCounters() = 0;
   virtual datetime GetTodayStart() = 0;
   virtual datetime GetTomorrowStart() = 0;
   
   virtual ~ITimeService() {}
};

//+------------------------------------------------------------------+
//| Default Time Service Implementation                             |
//+------------------------------------------------------------------+
class CDefaultTimeService : public ITimeService
{
private:
   datetime m_LastBarTimeM5;
   datetime m_LastBarTimeM15;
   datetime m_LastBarTimeH1;
   int m_DailyBarCountM5;
   int m_DailyBarCountM15;
   int m_DailyBarCountH1;
   datetime m_TodayStart;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void CDefaultTimeService()
   {
      this.m_LastBarTimeM5 = 0;
      this.m_LastBarTimeM15 = 0;
      this.m_LastBarTimeH1 = 0;
      this.m_DailyBarCountM5 = 0;
      this.m_DailyBarCountM15 = 0;
      this.m_DailyBarCountH1 = 0;
      this.m_TodayStart = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize time service                                        |
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      this.ResetDailyCounters();
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get current server time                                        |
   //+------------------------------------------------------------------+
   datetime GetServerTime()
   {
      return TimeCurrent();
   }
   
   //+------------------------------------------------------------------+
   //| Get current hour                                               |
   //+------------------------------------------------------------------+
   int GetCurrentHour()
   {
      MqlDateTime time;
      TimeToStruct(TimeCurrent(), time);
      return time.hour;
   }
   
   //+------------------------------------------------------------------+
   //| Get current minute                                             |
   //+------------------------------------------------------------------+
   int GetCurrentMinute()
   {
      MqlDateTime time;
      TimeToStruct(TimeCurrent(), time);
      return time.min;
   }
   
   //+------------------------------------------------------------------+
   //| Get day of week (0=Sunday, 1=Monday, etc.)                    |
   //+------------------------------------------------------------------+
   int GetDayOfWeek()
   {
      MqlDateTime time;
      TimeToStruct(TimeCurrent(), time);
      return time.day_of_week;
   }
   
   //+------------------------------------------------------------------+
   //| Check if new bar detected                                      |
   //+------------------------------------------------------------------+
   bool IsNewBar(int timeframe)
   {
      datetime currentBar = iTime(_Symbol, timeframe, 0);
      
      switch (timeframe)
      {
         case PERIOD_M5:
            if (currentBar != this.m_LastBarTimeM5)
            {
               this.m_LastBarTimeM5 = currentBar;
               this.m_DailyBarCountM5++;
               return true;
            }
            break;
            
         case PERIOD_M15:
            if (currentBar != this.m_LastBarTimeM15)
            {
               this.m_LastBarTimeM15 = currentBar;
               this.m_DailyBarCountM15++;
               return true;
            }
            break;
            
         case PERIOD_H1:
            if (currentBar != this.m_LastBarTimeH1)
            {
               this.m_LastBarTimeH1 = currentBar;
               this.m_DailyBarCountH1++;
               return true;
            }
            break;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Get bar time for specified timeframe                          |
   //+------------------------------------------------------------------+
   datetime GetBarTime(int timeframe, int bar)
   {
      return iTime(_Symbol, timeframe, bar);
   }
   
   //+------------------------------------------------------------------+
   //| Get approximate bars per day                                  |
   //+------------------------------------------------------------------+
   int GetBarsPerDay(int timeframe)
   {
      switch (timeframe)
      {
         case PERIOD_M5: return 288;   // 24 * 60 / 5
         case PERIOD_M15: return 96;   // 24 * 60 / 15
         case PERIOD_H1: return 24;    // 24 hours
         case PERIOD_D1: return 1;     // 1 day
         default: return 24 * 60 / (int)PeriodSeconds(timeframe) / 60;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Reset daily counters                                           |
   //+------------------------------------------------------------------+
   void ResetDailyCounters()
   {
      datetime now = TimeCurrent();
      MqlDateTime time;
      TimeToStruct(now, time);
      time.hour = 0;
      time.min = 0;
      time.sec = 0;
      time.year = TimeYear(now);
      time.month = TimeMonth(now);
      time.day = TimeDay(now);
      
      datetime todayStart = StructToTime(time);
      
      if (todayStart != this.m_TodayStart)
      {
         this.m_TodayStart = todayStart;
         this.m_DailyBarCountM5 = 0;
         this.m_DailyBarCountM15 = 0;
         this.m_DailyBarCountH1 = 0;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get start of today                                            |
   //+------------------------------------------------------------------+
   datetime GetTodayStart()
   {
      return this.m_TodayStart;
   }
   
   //+------------------------------------------------------------------+
   //| Get start of tomorrow                                         |
   //+------------------------------------------------------------------+
   datetime GetTomorrowStart()
   {
      return this.m_TodayStart + 24 * 60 * 60;
   }
   
   //+------------------------------------------------------------------+
   //| Get daily bar count for specified timeframe                   |
   //+------------------------------------------------------------------+
   int GetDailyBarCount(int timeframe)
   {
      switch (timeframe)
      {
         case PERIOD_M5: return this.m_DailyBarCountM5;
         case PERIOD_M15: return this.m_DailyBarCountM15;
         case PERIOD_H1: return this.m_DailyBarCountH1;
         default: return 0;
      }
   }
};

//+------------------------------------------------------------------+
//| Global Time Service Instance                                    |
//+------------------------------------------------------------------+
CDefaultTimeService g_TimeService;

//+------------------------------------------------------------------+
//| Initialize time service                                         |
//+------------------------------------------------------------------+
bool InitializeTimeService()
{
   return g_TimeService.Initialize();
}

//+------------------------------------------------------------------+
//| Get server time (wrapper)                                       |
//+------------------------------------------------------------------+
datetime GetServerTime()
{
   return g_TimeService.GetServerTime();
}

//+------------------------------------------------------------------+
//| Get current hour (wrapper)                                      |
//+------------------------------------------------------------------+
int GetCurrentHour()
{
   return g_TimeService.GetCurrentHour();
}

//+------------------------------------------------------------------+
//| Get current minute (wrapper)                                    |
//+------------------------------------------------------------------+
int GetCurrentMinute()
{
   return g_TimeService.GetCurrentMinute();
}

//+------------------------------------------------------------------+
//| Check if new bar (wrapper)                                      |
//+------------------------------------------------------------------+
bool IsNewBar(int timeframe)
{
   return g_TimeService.IsNewBar(timeframe);
}

//+------------------------------------------------------------------+
//| Get bar time (wrapper)                                          |
//+------------------------------------------------------------------+
datetime GetBarTime(int timeframe, int bar)
{
   return g_TimeService.GetBarTime(timeframe, bar);
}

//+------------------------------------------------------------------+
//| Get daily bar count (wrapper)                                   |
//+------------------------------------------------------------------+
int GetDailyBarCount(int timeframe)
{
   return g_TimeService.GetDailyBarCount(timeframe);
}
//+------------------------------------------------------------------+
