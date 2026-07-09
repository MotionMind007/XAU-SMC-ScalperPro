#ifndef __CORE_METRICSENGINE_MHQ__
#define __CORE_METRICSENGINE_MHQ__
//+------------------------------------------------------------------+
//|                                                     MetricsEngine.mqh |
//|                        XAU SMC Scalper Pro - Core Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include <Files\File.mqh>
#include "Models\ScoreModel.mqh"

//+------------------------------------------------------------------+
//| Setup Metrics Structure                                         |
//+------------------------------------------------------------------+
struct SetupMetrics
{
   datetime Timestamp;
   string Session;
   int MarketMode;
   int ConfidenceScore;
   int TrendScore;
   int StructureScore;
   int LiquidityScore;
   int OBScore;
   int FVGScore;
   int PriceActionScore;
   int SpreadScore;
   int SessionScore;
   int ATRScore;
   double SpreadRatio;
   bool PassedAllFilters;
   string EntryReasons;
};

//+------------------------------------------------------------------+
//| Trade Metrics Structure                                         |
//+------------------------------------------------------------------+
struct TradeMetrics
{
   SetupMetrics Setup;
   double EntryPrice;
   double SL;
   double TP;
   double LotSize;
   int PositionType;
   double ResultPips;
   double ResultProfit;
   double MaxDrawdownTrade;
   int ExitType;  // 0=TP, 1=SL, 2=CHoCH, 3=Manual
   string ExitReason;
   datetime EntryTime;
   datetime ExitTime;
   int BarsHeld;
};

//+------------------------------------------------------------------+
//| Setup Record (for batch processing)                            |
//+------------------------------------------------------------------+
struct SetupRecord
{
   SetupMetrics Metrics;
   bool HasTrade;
   TradeMetrics Trade;
};

//+------------------------------------------------------------------+
//| Metrics Engine - Collect and Export Performance Data          |
//+------------------------------------------------------------------+

class CMetricsEngine
{
private:
   Array<SetupRecord> m_SetupQueue;
   Array<TradeMetrics> m_TradeQueue;
   int m_MaxQueueSize;
   string m_ExportPath;
   bool m_EnableMetrics;
   bool m_EnableCSVExport;
   int m_BatchSize;
   int m_TradesSinceLastExport;
   string m_LogFile;
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                    |
   //+------------------------------------------------------------------+
   void CMetricsEngine()
   {
      this.m_SetupQueue = Array<SetupRecord>();
      this.m_TradeQueue = Array<TradeMetrics>();
      this.m_MaxQueueSize = 100;
      this.m_ExportPath = "Reports\\";
      this.m_EnableMetrics = true;
      this.m_EnableCSVExport = true;
      this.m_BatchSize = 10;
      this.m_TradesSinceLastExport = 0;
      this.m_LogFile = "MetricsLog.csv";
   }
   
   //+------------------------------------------------------------------+
   //| Initialize metrics engine                                      |
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      // Ensure export directory exists
      if (!DirectoryExists(this.m_ExportPath))
      {
         if (!CreateDirectory(this.m_ExportPath))
            return false;
      }
      
      // Write CSV header if file doesn't exist
      string csvPath = this.m_ExportPath + this.m_LogFile;
      if (!FileIsExist(csvPath))
      {
         string header = "Timestamp,Session,MarketMode,ConfidenceScore,TrendScore,StructureScore,LiquidityScore,OBScore,FVGScore,PriceActionScore,SpreadRatio,PassedAllFilters,EntryPrice,SL,TP,LotSize,ResultPips,ResultProfit,ExitType,ExitReason\n";
         this.WriteLineToFile(csvPath, header);
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Record a setup analysis                                        |
   //+------------------------------------------------------------------+
   bool RecordSetup(SetupMetrics metrics)
   {
      if (!this.m_EnableMetrics)
         return true;
      
      SetupRecord record;
      record.Metrics = metrics;
      record.HasTrade = false;
      
      this.m_SetupQueue.Add(record);
      
      // Check if batch should be processed
      if (this.m_SetupQueue.Total() >= this.m_BatchSize)
         this.ProcessQueue();
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Record a trade result                                          |
   //+------------------------------------------------------------------+
   bool RecordTrade(TradeMetrics metrics)
   {
      if (!this.m_EnableMetrics)
         return true;
      
      this.m_TradeQueue.Add(metrics);
      this.m_TradesSinceLastExport++;
      
      // Check if batch should be exported
      if (this.m_TradesSinceLastExport >= this.m_BatchSize)
         this.ExportToCSV();
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Process setup queue                                            |
   //+------------------------------------------------------------------+
   bool ProcessQueue()
   {
      // Process setups here if needed
      // For now, just clear the queue
      this.m_SetupQueue.Clear();
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Export trades to CSV                                          |
   //+------------------------------------------------------------------+
   bool ExportToCSV()
   {
      if (!this.m_EnableCSVExport)
         return true;
      
      string csvPath = this.m_ExportPath + this.m_LogFile;
      string line = "";
      
      for (int i = 0; i < this.m_TradeQueue.Total(); i++)
      {
         TradeMetrics tm = this.m_TradeQueue[i];
         
         line += TimeToString(tm.Setup.Timestamp, TIME_DATE|TIME_MINUTE) + ",";
         line += tm.Setup.Session + ",";
         line += IntegerToString(tm.Setup.MarketMode) + ",";
         line += IntegerToString(tm.Setup.ConfidenceScore) + ",";
         line += IntegerToString(tm.Setup.TrendScore) + ",";
         line += IntegerToString(tm.Setup.StructureScore) + ",";
         line += IntegerToString(tm.Setup.LiquidityScore) + ",";
         line += IntegerToString(tm.Setup.OBScore) + ",";
         line += IntegerToString(tm.Setup.FVGScore) + ",";
         line += IntegerToString(tm.Setup.PriceActionScore) + ",";
         line += DoubleToString(tm.Setup.SpreadRatio, 2) + ",";
         line += (tm.Setup.PassedAllFilters ? "TRUE" : "FALSE") + ",";
         line += DoubleToString(tm.EntryPrice, 5) + ",";
         line += DoubleToString(tm.SL, 5) + ",";
         line += DoubleToString(tm.TP, 5) + ",";
         line += DoubleToString(tm.LotSize, 2) + ",";
         line += DoubleToString(tm.ResultPips, 1) + ",";
         line += DoubleToString(tm.ResultProfit, 2) + ",";
         line += IntegerToString(tm.ExitType) + ",";
         line += "\"" + tm.ExitReason + "\"";
         line += "\n";
      }
      
      this.WriteLineToFile(csvPath, line);
      
      // Clear queue after export
      this.m_TradeQueue.Clear();
      this.m_TradesSinceLastExport = 0;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Write line to file                                             |
   //+------------------------------------------------------------------+
   bool WriteLineToFile(string path, string line)
   {
      int handle = FileOpen(path, FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_READ|FILE_SHARE_WRITE);
      
      if (handle == INVALID_HANDLE)
         return false;
      
      FileSeek(handle, 0, SEEK_END);
      FileWrite(handle, line);
      FileClose(handle);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate win rate                                             |
   //+------------------------------------------------------------------+
   double GetWinRate()
   {
      if (this.m_TradeQueue.Total() == 0)
         return 0.0;
      
      int wins = 0;
      int total = this.m_TradeQueue.Total();
      
      for (int i = 0; i < total; i++)
      {
         if (this.m_TradeQueue[i].ResultProfit > 0)
            wins++;
      }
      
      return (double)wins / (double)total * 100.0;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate profit factor                                        |
   //+------------------------------------------------------------------+
   double GetProfitFactor()
   {
      if (this.m_TradeQueue.Total() == 0)
         return 0.0;
      
      double totalProfit = 0.0;
      double totalLoss = 0.0;
      
      for (int i = 0; i < this.m_TradeQueue.Total(); i++)
      {
         if (this.m_TradeQueue[i].ResultProfit > 0)
            totalProfit += this.m_TradeQueue[i].ResultProfit;
         else
            totalLoss += MathAbs(this.m_TradeQueue[i].ResultProfit);
      }
      
      if (totalLoss == 0)
         return totalProfit;
      
      return totalProfit / totalLoss;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate average risk-reward                                  |
   //+------------------------------------------------------------------+
   double GetAvgRiskReward()
   {
      if (this.m_TradeQueue.Total() == 0)
         return 0.0;
      
      double totalRR = 0.0;
      
      for (int i = 0; i < this.m_TradeQueue.Total(); i++)
      {
         TradeMetrics tm = this.m_TradeQueue[i];
         if (tm.SL > 0)
         {
            double rr = tm.ResultPips / (tm.SL - tm.EntryPrice) * _Point;
            totalRR += rr;
         }
      }
      
      return totalRR / (double)this.m_TradeQueue.Total();
   }
   
   //+------------------------------------------------------------------+
   //| Calculate average confidence score                             |
   //+------------------------------------------------------------------+
   double GetAvgConfidencePassed()
   {
      if (this.m_TradeQueue.Total() == 0)
         return 0.0;
      
      double totalScore = 0.0;
      int count = 0;
      
      for (int i = 0; i < this.m_TradeQueue.Total(); i++)
      {
         if (this.m_TradeQueue[i].Setup.PassedAllFilters)
         {
            totalScore += this.m_TradeQueue[i].Setup.ConfidenceScore;
            count++;
         }
      }
      
      if (count == 0)
         return 0.0;
      
      return totalScore / (double)count;
   }
   
   //+------------------------------------------------------------------+
   //| Get win rate by session                                        |
   //+------------------------------------------------------------------+
   double GetWinRateBySession(string session)
   {
      if (this.m_TradeQueue.Total() == 0)
         return 0.0;
      
      int wins = 0;
      int total = 0;
      
      for (int i = 0; i < this.m_TradeQueue.Total(); i++)
      {
         if (this.m_TradeQueue[i].Setup.Session == session)
         {
            total++;
            if (this.m_TradeQueue[i].ResultProfit > 0)
               wins++;
         }
      }
      
      if (total == 0)
         return 0.0;
      
      return (double)wins / (double)total * 100.0;
   }
   
   //+------------------------------------------------------------------+
   //| Get performance summary as string                              |
   //+------------------------------------------------------------------+
   string GetSummary()
   {
      string output = "";
      
      output += "=== Performance Summary ===\n";
      output += StringFormat("Total Trades: %d\n", this.m_TradeQueue.Total());
      output += StringFormat("Win Rate: %.1f%%\n", this.GetWinRate());
      output += StringFormat("Profit Factor: %.2f\n", this.GetProfitFactor());
      output += StringFormat("Avg Confidence (passed): %.1f\n", this.GetAvgConfidencePassed());
      
      output += "\n=== Win Rate by Session ===\n";
      output += StringFormat("London: %.1f%%\n", this.GetWinRateBySession("London"));
      output += StringFormat("New York: %.1f%%\n", this.GetWinRateBySession("New York"));
      output += StringFormat("Overlap: %.1f%%\n", this.GetWinRateBySession("Overlap"));
      
      return output;
   }
   
   //+------------------------------------------------------------------+
   //| Enable/disable metrics                                         |
   //+------------------------------------------------------------------+
   void Enable(bool value)
   {
      this.m_EnableMetrics = value;
   }
   
   //+------------------------------------------------------------------+
   //| Enable/disable CSV export                                      |
   //+------------------------------------------------------------------+
   void EnableCSVExport(bool value)
   {
      this.m_EnableCSVExport = value;
   }
};

//+------------------------------------------------------------------+
//| Global Metrics Engine Instance                                   |
//+------------------------------------------------------------------+
CMetricsEngine g_MetricsEngine;

//+------------------------------------------------------------------+
//| Initialize metrics engine                                        |
//+------------------------------------------------------------------+
bool InitializeMetricsEngine()
{
   return g_MetricsEngine.Initialize();
}

//+------------------------------------------------------------------+
//| Get metrics summary                                             |
//+------------------------------------------------------------------+
string GetMetricsSummary()
{
   return g_MetricsEngine.GetSummary();
}
//+------------------------------------------------------------------+

#endif // __CORE_METRICSENGINE_MHQ__
