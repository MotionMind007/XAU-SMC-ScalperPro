#ifndef __CORE_LOGGER_MHQ__
#define __CORE_LOGGER_MHQ__
//+------------------------------------------------------------------+
//|                                                          Logger.mqh |
//|                        XAU SMC Scalper Pro - Core Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include <Files\File.mqh>

//+------------------------------------------------------------------+
//| Log Types                                                       |
//+------------------------------------------------------------------+
enum LogLevel
{
   DEBUG = 0,
   INFO = 1,
   WARNING = 2,
   ERROR = 3,
   INIT = 4,
   DEINIT = 5,
   TRADE = 6
};

//+------------------------------------------------------------------+
//| Global Logger State                                             |
//+------------------------------------------------------------------+
int g_LogHandle = INVALID_HANDLE;
string g_LogFilePath = "Logs\\EA_Log_";
bool g_LoggingEnabled = true;

//+------------------------------------------------------------------+
//| Initialize logger                                               |
//+------------------------------------------------------------------+
bool InitializeLogger()
{
   g_LogFilePath = "Logs\\EA_Log_" + TimeToString(TimeCurrent(), TIME_DATE) + ".log";
   
   // Create logs directory if it doesn't exist
   if (!DirectoryExists("Logs\\"))
   {
      if (!CreateDirectory("Logs\\"))
      {
         Print("Failed to create Logs directory");
         g_LoggingEnabled = false;
         return false;
      }
   }
   
   // Open log file
   g_LogHandle = FileOpen(g_LogFilePath, FILE_WRITE|FILE_READ|FILE_SHARE_READ|FILE_CSV);
   
   if (g_LogHandle == INVALID_HANDLE)
   {
      Print("Failed to open log file: " + g_LogFilePath);
      g_LoggingEnabled = false;
      return false;
   }
   
   // Write header if new file
   if (FileTell(g_LogHandle) == 0)
   {
      FileWrite(g_LogHandle, "Timestamp,Level,Message");
   }
   
   LogInternal(INIT, "Logger initialized");
   return true;
}

//+------------------------------------------------------------------+
//| Log message                                                     |
//+------------------------------------------------------------------+
bool Logger_Log(LogLevel level, string message)
{
   if (!g_LoggingEnabled)
      return false;
   
   // Add to internal log
   LogInternal(level, message);
   
   // Also print to MetaTrader terminal
   Print("[" + LogLevelToString(level) + "] " + message);
   
   return true;
}

//+------------------------------------------------------------------+
//| Log to file                                                     |
//+------------------------------------------------------------------+
bool LogInternal(LogLevel level, string message)
{
   if (g_LogHandle == INVALID_HANDLE)
      return false;
   
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTE|TIME_SECOND);
   string levelStr = LogLevelToString(level);
   
   // Escape commas in message
   StringReplace(message, ",", ";");
   
   FileSeek(g_LogHandle, 0, SEEK_END);
   FileWrite(g_LogHandle, timestamp + "," + levelStr + "," + message);
   FileFlush(g_LogHandle);
   
   return true;
}

//+------------------------------------------------------------------+
//| Convert log level to string                                    |
//+------------------------------------------------------------------+
string LogLevelToString(LogLevel level)
{
   switch (level)
   {
      case DEBUG: return "DEBUG";
      case INFO: return "INFO";
      case WARNING: return "WARNING";
      case ERROR: return "ERROR";
      case INIT: return "INIT";
      case DEINIT: return "DEINIT";
      case TRADE: return "TRADE";
      default: return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Log trade event                                                 |
//+------------------------------------------------------------------+
bool Logger_LogTrade(string action, ulong ticket, double lotSize, double price, double sl, double tp)
{
   if (!g_LoggingEnabled)
      return false;
   
   string message = StringFormat("Ticket=%d, Action=%s, Lot=%.2f, Price=%.5f, SL=%.5f, TP=%.5f",
      ticket, action, lotSize, price, sl, tp);
   
   return Logger_Log(TRADE, message);
}

//+------------------------------------------------------------------+
//| Log entry decision                                              |
//+------------------------------------------------------------------+
bool Logger_LogEntry(int score, string reasons, int direction)
{
   if (!g_LoggingEnabled)
      return false;
   
   string message = StringFormat("Entry Decision: Score=%d, Direction=%d, Reasons=%s",
      score, direction, reasons);
   
   return Logger_Log(INFO, message);
}

//+------------------------------------------------------------------+
//| Log exit decision                                               |
//+------------------------------------------------------------------+
bool Logger_LogExit(ulong ticket, string reason, int exitType)
{
   if (!g_LoggingEnabled)
      return false;
   
   string message = StringFormat("Exit Decision: Ticket=%d, Reason=%s, Type=%d",
      ticket, reason, exitType);
   
   return Logger_Log(INFO, message);
}

//+------------------------------------------------------------------+
//| Write trade result to log                                       |
//+------------------------------------------------------------------+
bool Logger_LogTradeResult(ulong ticket, double profit, double commission, double swap)
{
   if (!g_LoggingEnabled)
      return false;
   
   string message = StringFormat("Trade Result: Ticket=%d, Profit=%.2f, Commission=%.2f, Swap=%.2f",
      ticket, profit, commission, swap);
   
   return Logger_Log(TRADE, message);
}

//+------------------------------------------------------------------+
//| Close log file                                                  |
//+------------------------------------------------------------------+
bool CloseLogger()
{
   if (g_LogHandle != INVALID_HANDLE)
   {
      LogInternal(DEINIT, "Logger closed");
      FileClose(g_LogHandle);
      g_LogHandle = INVALID_HANDLE;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Write summary report to file                                   |
//+------------------------------------------------------------------+
bool WriteSummaryReport()
{
   string summaryPath = "Reports\\Daily_Report_" + TimeToString(TimeCurrent(), TIME_DATE) + ".txt";
   
   int handle = FileOpen(summaryPath, FILE_WRITE|FILE_SHARE_READ);
   
   if (handle == INVALID_HANDLE)
      return false;
   
   // Write header
   FileWrite(handle, "=== Daily Trading Report ===");
   FileWrite(handle, "Date: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTE));
   FileWrite(handle, "Symbol: " + _Symbol);
   FileWrite(handle, "");
   
   // Write trade summary
   FileWrite(handle, "=== Trade Summary ===");
   FileWrite(handle, "Total Trades: " + IntegerToString(OrdersTotal() + OrdersHistoryTotal()));
   
   // Calculate win rate (simplified)
   int wins = 0;
   int losses = 0;
   for (int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if (OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if (OrderProfit() > 0) wins++;
         else if (OrderProfit() < 0) losses++;
      }
   }
   
   int total = wins + losses;
   if (total > 0)
   {
      double winRate = (double)wins / total * 100.0;
      FileWrite(handle, "Wins: " + IntegerToString(wins));
      FileWrite(handle, "Losses: " + IntegerToString(losses));
      FileWrite(handle, "Win Rate: " + DoubleToString(winRate, 2) + "%");
   }
   
   FileClose(handle);
   return true;
}
//+------------------------------------------------------------------+

#endif // __CORE_LOGGER_MHQ__
