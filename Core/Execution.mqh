#ifndef __CORE_EXECUTION_MHQ__
#define __CORE_EXECUTION_MHQ__
//+------------------------------------------------------------------+
//|                                                      Execution.mqh |
//|                        XAU SMC Scalper Pro - Core Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include <Trade\Trade.mqh>
#include <stderror.mqh>
#include "Config\Parameters.mqh"
#include "TradeContext.mqh"
#include "../Services/SymbolService.mqh"
#include "Logger.mqh"

//+------------------------------------------------------------------+
//| Execution State                                                 |
//+------------------------------------------------------------------+
int g_ExecutionRetries = 0;
int g_MaxRetries = 2;
datetime g_LastExecutionTime = 0;

//+------------------------------------------------------------------+
//| Initialize execution service                                    |
//+------------------------------------------------------------------+
bool InitializeExecution()
{
   g_ExecutionRetries = 0;
   g_MaxRetries = 2;
   g_LastExecutionTime = 0;
   return true;
}

//+------------------------------------------------------------------+
//| Check if execution is allowed                                   |
//+------------------------------------------------------------------+
bool IsExecutionAllowed()
{
   // Check if trade context is valid
   if (!g_TradeContext.IsValid())
   {
      g_TradeContext.AddError("Invalid trade context");
      return false;
   }
   
   // Check spread
   if (!g_TradeContext.IsSpreadAcceptable())
   {
      g_TradeContext.AddError("Spread too high: " + DoubleToString(g_TradeContext.SpreadRatio, 2) + "%");
      return false;
   }
   
   // Check session
   if (!g_TradeContext.SessionActive)
   {
      g_TradeContext.AddError("Outside trading hours");
      return false;
   }
   
   // Check news
   if (g_TradeContext.NewsActive)
   {
      g_TradeContext.AddError("High impact news active");
      return false;
   }
   
   // Check margin
   if (!g_TradeContext.HasSufficientMargin(0))
   {
      g_TradeContext.AddError("Insufficient margin");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Execute buy order                                               |
//+------------------------------------------------------------------+
bool ExecuteBuy(double lotSize, double sl, double tp, string comment = "")
{
   if (!IsExecutionAllowed())
      return false;
   
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return ExecuteOrder(ORDER_TYPE_BUY, lotSize, price, sl, tp, comment);
}

//+------------------------------------------------------------------+
//| Execute sell order                                              |
//+------------------------------------------------------------------+
bool ExecuteSell(double lotSize, double sl, double tp, string comment = "")
{
   if (!IsExecutionAllowed())
      return false;
   
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return ExecuteOrder(ORDER_TYPE_SELL, lotSize, price, sl, tp, comment);
}

//+------------------------------------------------------------------+
//| Execute order with retry logic                                  |
//+------------------------------------------------------------------+
bool ExecuteOrder(int orderType, double lotSize, double price, double sl, double tp, string comment)
{
   CTrade trade;
   int retryCount = 0;
   
   while (retryCount <= g_MaxRetries)
   {
      bool result = false;
      
      switch (orderType)
      {
         case ORDER_TYPE_BUY:
            result = trade.Buy(lotSize, _Symbol, price, sl, tp, comment, g_Parameters.MagicNumber);
            break;
            
         case ORDER_TYPE_SELL:
            result = trade.Sell(lotSize, _Symbol, price, sl, tp, comment, g_Parameters.MagicNumber);
            break;
      }
      
      if (result)
      {
         g_ExecutionRetries = 0;
         g_LastExecutionTime = TimeCurrent();
         Logger_Log(INFO, "Order executed: " + IntegerToString(orderType) + 
                    ", Lot: " + DoubleToString(lotSize, 2));
         return true;
      }
      
      // Log error and retry
      int errorCode = GetLastError();
      Logger_Log(WARNING, "Order execution failed: " + ErrorDescription(errorCode) + 
                 " (Attempt " + IntegerToString(retryCount + 1) + "/" + IntegerToString(g_MaxRetries + 1) + ")");
      
      retryCount++;
      
      // Short delay before retry
      Sleep(100);
   }
   
   // All retries failed
   g_TradeContext.AddError("Order execution failed after " + IntegerToString(g_MaxRetries + 1) + " attempts");
   Logger_Log(ERROR, "Order execution permanently failed");
   return false;
}

//+------------------------------------------------------------------+
//| Modify order                                                    |
//+------------------------------------------------------------------+
bool ModifyOrder(ulong ticket, double sl, double tp)
{
   if (!OrderSelect(ticket, SELECT_BY_TICKET))
      return false;
   
   int retryCount = 0;
   
   while (retryCount <= g_MaxRetries)
   {
      CTrade trade;
      bool result = trade.OrderModify(ticket, sl, tp, 0);
      
      if (result)
      {
         Logger_Log(INFO, "Order " + IntegerToString(ticket) + " modified: SL=" + 
                    DoubleToString(sl, 5) + ", TP=" + DoubleToString(tp, 5));
         return true;
      }
      
      int errorCode = GetLastError();
      Logger_Log(WARNING, "Order modification failed: " + ErrorDescription(errorCode));
      
      retryCount++;
      Sleep(100);
   }
   
   Logger_Log(ERROR, "Order modification permanently failed");
   return false;
}

//+------------------------------------------------------------------+
//| Close order                                                     |
//+------------------------------------------------------------------+
bool CloseOrder(ulong ticket, double lots = 0)
{
   if (!OrderSelect(ticket, SELECT_BY_TICKET))
      return false;
   
   double closeLot = (lots > 0) ? lots : OrderLots();
   int retryCount = 0;
   
   while (retryCount <= g_MaxRetries)
   {
      CTrade trade;
      bool result = trade.PositionClose(ticket, closeLot);
      
      if (result)
      {
         Logger_Log(INFO, "Order " + IntegerToString(ticket) + " closed: " + 
                    DoubleToString(closeLot, 2) + " lots");
         return true;
      }
      
      int errorCode = GetLastError();
      Logger_Log(WARNING, "Order close failed: " + ErrorDescription(errorCode));
      
      retryCount++;
      Sleep(100);
   }
   
   Logger_Log(ERROR, "Order close permanently failed");
   return false;
}

//+------------------------------------------------------------------+
//| Validate trade context for execution                            |
//+------------------------------------------------------------------+
bool ValidateTradeContext()
{
   if (!g_TradeContext.IsValid())
   {
      Logger_Log(ERROR, "Trade context invalid");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if market is normal                                       |
//+------------------------------------------------------------------+
bool IsMarketNormal()
{
   // Check spread
   double spread = SymbolInfoDouble(_Symbol, SYMBOL_SPREAD);
   double maxSpread = g_Parameters.MaxSpreadRatio * g_Parameters.DefaultSL * SymbolInfoDouble(_Symbol, SYMBOL_POINT) / 100;
   
   if (spread > maxSpread)
   {
      Logger_Log(WARNING, "Spread too high: " + IntegerToString((int)spread) + " points");
      return false;
   }
   
   // Check volatility
   if (g_TradeContext.MarketMode == MODE_VOLATILE || g_TradeContext.MarketMode == MODE_NO_TRADE)
   {
      Logger_Log(WARNING, "Market mode not suitable: " + IntegerToString(g_TradeContext.MarketMode));
      return false;
   }
   
   return true;
}
//+------------------------------------------------------------------+

#endif // __CORE_EXECUTION_MHQ__
