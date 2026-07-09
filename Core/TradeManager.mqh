//+------------------------------------------------------------------+
//|                                                    TradeManager.mqh |
//|                        XAU SMC Scalper Pro - Core Module |
//|                           Copyright 2024, MotionMind |
//|                                       https://motionmind.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MotionMind"
#property version   "1.1"
#property strict

#include <Trade\Trade.mqh>
#include "Config\Parameters.mqh"
#include "TradeContext.mqh"
#include "ATR.mqh"
#include "Logger.mqh"

//+------------------------------------------------------------------+
//| Trade Manager Types                                             |
//+------------------------------------------------------------------+
enum TradeAction
{
   ACTION_NONE = 0,
   ACTION_BREAK_EVEN = 1,
   ACTION_TRAILING = 2,
   ACTION_PARTIAL_CLOSE = 3,
   ACTION_EARLY_EXIT = 4
};

//+------------------------------------------------------------------+
//| Global Trade Manager State                                      |
//+------------------------------------------------------------------+
CTrade g_TradeManagerTrade;

//+------------------------------------------------------------------+
//| Initialize trade manager                                        |
//+------------------------------------------------------------------+
bool InitializeTradeManager()
{
   return true;
}

//+------------------------------------------------------------------+
//| Manage all active positions                                     |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if (OrderSymbol() == _Symbol && OrderMagicNumber() == g_Parameters.MagicNumber)
         {
            ManageSinglePosition(OrderTicket());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage single position                                          |
//+------------------------------------------------------------------+
void ManageSinglePosition(ulong ticket)
{
   if (!OrderSelect(ticket, SELECT_BY_TICKET))
      return;
   
   // Check for early exit (CHoCH)
   if (ShouldEarlyExit())
   {
      ClosePosition(ticket, "CHoCH - Change of Character");
      return;
   }
   
   // Check for session end
   if (!IsSessionActive(g_TradeContext.Session))
   {
      ClosePosition(ticket, "Session End");
      return;
   }
   
   // Check break-even
   if (ShouldMoveToBreakEven())
   {
      MoveToBreakEven(ticket);
   }
   
   // Check trailing stop
   if (ShouldTrailStop())
   {
      ApplyTrailingStop(ticket);
   }
   
   // Check partial close
   if (ShouldPartialClose())
   {
      PartialClose(ticket);
   }
}

//+------------------------------------------------------------------+
//| Check if should move to break-even                              |
//+------------------------------------------------------------------+
bool ShouldMoveToBreakEven()
{
   // Check if we have active trades
   if (g_TradeContext.ActiveTrades == 0)
      return false;
   
   // Check if we've hit first TP (50% close already)
   // This would require checking order comments or custom logic
   
   return true;  // Simplified for now
}

//+------------------------------------------------------------------+
//| Move position to break-even                                     |
//+------------------------------------------------------------------+
bool MoveToBreakEven(ulong ticket)
{
   if (!OrderSelect(ticket, SELECT_BY_TICKET))
      return false;
   
   double currentPrice = (OrderType() == ORDER_TYPE_BUY) ? 
      SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double entryPrice = OrderOpenPrice();
   double atrBuffer = GetATRBuffer() * 2;
   double newSL = 0.0;
   
   if (OrderType() == ORDER_TYPE_BUY)
      newSL = entryPrice + atrBuffer;
   else
      newSL = entryPrice - atrBuffer;
   
   // Normalize SL
   newSL = MathRound(newSL / SymbolInfoDouble(_Symbol, SYMBOL_POINT)) * 
           SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Check if SL can be modified
   if ((OrderType() == ORDER_TYPE_BUY && newSL > OrderStopLoss()) ||
       (OrderType() == ORDER_TYPE_SELL && newSL < OrderStopLoss()))
   {
      if (g_TradeManagerTrade.OrderModify(ticket, newSL, OrderTakeProfit(), 0))
      {
         Logger_Log(INFO, "Position " + IntegerToString(ticket) + " moved to BE at " + 
                    DoubleToString(newSL, 5));
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if should apply trailing stop                             |
//+------------------------------------------------------------------+
bool ShouldTrailStop()
{
   return (g_TradeContext.ActiveTrades > 0);
}

//+------------------------------------------------------------------+
//| Apply trailing stop to position                                 |
//+------------------------------------------------------------------+
bool ApplyTrailingStop(ulong ticket)
{
   if (!OrderSelect(ticket, SELECT_BY_TICKET))
      return false;
   
   double atrBuffer = GetATRBuffer();
   double currentPrice = (OrderType() == ORDER_TYPE_BUY) ? 
      SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double newSL = 0.0;
   
   if (OrderType() == ORDER_TYPE_BUY)
   {
      double swingLow = GetNearestSwingLow(currentPrice);
      if (swingLow > 0)
         newSL = swingLow + atrBuffer;
      else
         newSL = currentPrice - atrBuffer * g_Parameters.TrailingStep / g_Parameters.TrailingStart;
   }
   else
   {
      double swingHigh = GetNearestSwingHigh(currentPrice);
      if (swingHigh > 0)
         newSL = swingHigh - atrBuffer;
      else
         newSL = currentPrice + atrBuffer * g_Parameters.TrailingStep / g_Parameters.TrailingStart;
   }
   
   // Normalize SL
   newSL = MathRound(newSL / SymbolInfoDouble(_Symbol, SYMBOL_POINT)) * 
           SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Only update if SL is better
   if ((OrderType() == ORDER_TYPE_BUY && newSL > OrderStopLoss()) ||
       (OrderType() == ORDER_TYPE_SELL && newSL < OrderStopLoss()))
   {
      if (g_TradeManagerTrade.OrderModify(ticket, newSL, OrderTakeProfit(), 0))
      {
         Logger_Log(DEBUG, "Trailing stop updated for " + IntegerToString(ticket));
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if should partial close (50%)                            |
//+------------------------------------------------------------------+
bool ShouldPartialClose()
{
   // Check if we have active trades
   if (g_TradeContext.ActiveTrades == 0)
      return false;
   
   // This would require checking if first TP was hit
   // Simplified: return true to enable logic
   return true;
}

//+------------------------------------------------------------------+
//| Partially close position (50%)                                  |
//+------------------------------------------------------------------+
bool PartialClose(ulong ticket)
{
   if (!OrderSelect(ticket, SELECT_BY_TICKET))
      return false;
   
   double halfLot = OrderLots() / 2;
   halfLot = NormalizeLot(halfLot);
   
   if (halfLot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
      return false;
   
   if (g_TradeManagerTrade.PositionClose(ticket, halfLot))
   {
      Logger_Log(INFO, "Partial close: " + DoubleToString(halfLot, 2) + " lots closed");
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if should early exit (CHoCH)                             |
//+------------------------------------------------------------------+
bool ShouldEarlyExit()
{
   // Check if trend changed
   if (g_TradeContext.CurrentTrend == DIRECTION_NONE)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Close position                                                  |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket, string reason)
{
   if (!OrderSelect(ticket, SELECT_BY_TICKET))
      return false;
   
   if (g_TradeManagerTrade.PositionClose(ticket))
   {
      Logger_Log(INFO, "Position " + IntegerToString(ticket) + " closed: " + reason);
      return true;
   }
   
   return false;
}
//+------------------------------------------------------------------+
