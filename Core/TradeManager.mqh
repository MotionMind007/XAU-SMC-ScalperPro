#ifndef __CORE_TRADEMANAGER_MHQ__
#define __CORE_TRADEMANAGER_MHQ__
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
//| Partial Close Tracking                                           |
//| Track which positions have already been partially closed.        |
//| Uses ticket array since MQL5 CTrade.PositionModify has no        |
//| comment parameter.                                               |
//+------------------------------------------------------------------+
#define MAX_TRACKED_POSITIONS 50
ulong g_PC_Tickets[];
int    g_PC_Count = 0;

//+------------------------------------------------------------------+
//| Check if position was already partially closed                   |
//+------------------------------------------------------------------+
bool IsPartialClosed(ulong ticket)
{
   for (int i = 0; i < g_PC_Count; i++)
   {
      if (g_PC_Tickets[i] == ticket)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Mark position as partially closed                                |
//+------------------------------------------------------------------+
void MarkPartialClosed(ulong ticket)
{
   // Check if already tracked
   if (IsPartialClosed(ticket))
      return;

   if (g_PC_Count >= MAX_TRACKED_POSITIONS)
   {
      // Shift array to make room (remove oldest)
      for (int i = 0; i < g_PC_Count - 1; i++)
         g_PC_Tickets[i] = g_PC_Tickets[i + 1];
      g_PC_Count = g_PC_Count - 1;
   }

   ArrayResize(g_PC_Tickets, g_PC_Count + 1);
   g_PC_Tickets[g_PC_Count] = ticket;
   g_PC_Count++;
}

//+------------------------------------------------------------------+
//| Remove tracking for a closed position (cleanup)                  |
//+------------------------------------------------------------------+
void UntrackPartialClose(ulong ticket)
{
   for (int i = 0; i < g_PC_Count; i++)
   {
      if (g_PC_Tickets[i] == ticket)
      {
         for (int j = i; j < g_PC_Count - 1; j++)
            g_PC_Tickets[j] = g_PC_Tickets[j + 1];
         g_PC_Count--;
         ArrayResize(g_PC_Tickets, g_PC_Count);
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Initialize trade manager                                        |
//+------------------------------------------------------------------+
bool InitializeTradeManager()
{
   g_PC_Count = 0;
   ArrayResize(g_PC_Tickets, 0);
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

   // --- 1. Daily limits / CHoCH early exit (highest priority) ---
   if (ShouldEarlyExit(ticket))
   {
      ClosePosition(ticket, "Early Exit - CHoCH or Daily Limits");
      UntrackPartialClose(ticket);
      return;
   }

   // --- 2. Session end exit ---
   if (!IsSessionActive(g_TradeContext.Session))
   {
      ClosePosition(ticket, "Session End");
      UntrackPartialClose(ticket);
      return;
   }

   // --- 3. Partial close at TP1 (before BE/trailing) ---
   // Must check partial close FIRST, because BE depends on it being done
   if (ShouldPartialClose(ticket))
   {
      PartialClose(ticket);
      // Do NOT return — continue to check if BE should also apply this tick
   }

   // --- 4. Break-even move (only after partial close done) ---
   if (ShouldMoveToBreakEven(ticket))
   {
      MoveToBreakEven(ticket);
   }

   // --- 5. Trailing stop (only after TP1 hit) ---
   if (ShouldTrailStop(ticket))
   {
      ApplyTrailingStop(ticket);
   }
}

//+------------------------------------------------------------------+
//| Calculate TP1 price for a position (1R from entry)              |
//| BUY:  TP1 = entry + (entry - SL)                                |
//| SELL: TP1 = entry - (SL - entry)                                |
//+------------------------------------------------------------------+
double CalculateTP1(ulong ticket)
{
   if (!OrderSelect(ticket, SELECT_BY_TICKET))
      return 0.0;

   double entry = OrderOpenPrice();
   double sl    = OrderStopLoss();

   if (OrderType() == ORDER_TYPE_BUY)
      return entry + (entry - sl);      // 1R upward
   else
      return entry - (sl - entry);       // 1R downward
}

//+------------------------------------------------------------------+
//| Check if should partial close at TP1 (50% of position)          |
//| Returns true when:                                              |
//|   - Price has reached TP1 (1R from entry)                       |
//|   - Partial close has NOT been done yet for this ticket         |
//+------------------------------------------------------------------+
bool ShouldPartialClose(ulong ticket)
{
   if (!OrderSelect(ticket, SELECT_BY_TICKET))
      return false;

   // Already partial-closed? Skip.
   if (IsPartialClosed(ticket))
      return false;

   double tp1 = CalculateTP1(ticket);
   if (tp1 == 0.0)
      return false;

   if (OrderType() == ORDER_TYPE_BUY)
   {
      double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if (currentBid >= tp1)
         return true;
   }
   else if (OrderType() == ORDER_TYPE_SELL)
   {
      double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if (currentAsk <= tp1)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Partially close position at TP1 (close 50%)                    |
//+------------------------------------------------------------------+
bool PartialClose(ulong ticket)
{
   if (!OrderSelect(ticket, SELECT_BY_TICKET))
      return false;

   double halfLot = OrderLots() / 2.0;
   halfLot = NormalizeLot(halfLot);

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if (halfLot < minLot)
   {
      Logger_Log(WARNING, "Partial close skipped: halfLot " + DoubleToString(halfLot, 2) +
                 " < minLot " + DoubleToString(minLot, 2));
      return false;
   }

   // Use PositionClosePartial for proper MQL5 partial close
   if (g_TradeManagerTrade.PositionClosePartial(ticket, halfLot))
   {
      MarkPartialClosed(ticket);
      Logger_Log(INFO, "Partial close TP1: " + DoubleToString(halfLot, 2) +
                 " lots closed on ticket " + IntegerToString(ticket));
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Check if should move to break-even                              |
//| Returns true only when:                                         |
//|   - Partial close already happened (TP1 hit)                    |
//|   - Price has moved at least 1R from entry (redundant safety)   |
//+------------------------------------------------------------------+
bool ShouldMoveToBreakEven(ulong ticket)
{
   // Must have done partial close first
   if (!IsPartialClosed(ticket))
      return false;

   if (!OrderSelect(ticket, SELECT_BY_TICKET))
      return false;

   double entry = OrderOpenPrice();
   double sl    = OrderStopLoss();
   double oneR  = MathAbs(entry - sl);

   if (OrderType() == ORDER_TYPE_BUY)
   {
      double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      // Price must be at least 1R above entry (safety — partial close already implies this)
      if (currentBid >= entry + oneR)
      {
         // Only move BE if current SL is still below entry (not already at BE)
         if (sl < entry)
            return true;
      }
   }
   else if (OrderType() == ORDER_TYPE_SELL)
   {
      double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if (currentAsk <= entry - oneR)
      {
         if (sl > entry)
            return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Move position to break-even                                     |
//| SL moves to entry + small buffer (10 points for spread)         |
//+------------------------------------------------------------------+
bool MoveToBreakEven(ulong ticket)
{
   if (!OrderSelect(ticket, SELECT_BY_TICKET))
      return false;

   double entryPrice = OrderOpenPrice();
   double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double beBuffer   = 10 * point;   // 10 points buffer for spread
   double newSL      = 0.0;

   if (OrderType() == ORDER_TYPE_BUY)
      newSL = entryPrice + beBuffer;
   else
      newSL = entryPrice - beBuffer;

   // Normalize to tick size
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if (tickSize > 0)
      newSL = MathRound(newSL / tickSize) * tickSize;

   // Only modify if new SL is better than current SL
   if ((OrderType() == ORDER_TYPE_BUY && newSL > OrderStopLoss()) ||
       (OrderType() == ORDER_TYPE_SELL && newSL < OrderStopLoss()))
   {
      if (g_TradeManagerTrade.OrderModify(ticket, newSL, OrderTakeProfit(), 0))
      {
         Logger_Log(INFO, "Position " + IntegerToString(ticket) +
                    " moved to BE at " + DoubleToString(newSL,
                    (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Check if should apply trailing stop                             |
//| Returns true only when:                                         |
//|   - TP1 was hit (partial close done)                            |
//|   - Trail using nearest swing + ATR buffer                      |
//|   - Only moves SL if new SL improves (already in ApplyTrailing) |
//+------------------------------------------------------------------+
bool ShouldTrailStop(ulong ticket)
{
   // Trailing only active after TP1 / partial close
   if (!IsPartialClosed(ticket))
      return false;

   if (!OrderSelect(ticket, SELECT_BY_TICKET))
      return false;

   double currentPrice = (OrderType() == ORDER_TYPE_BUY) ?
      SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double atrBuffer = GetATRBuffer();
   double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double newSL     = 0.0;

   if (OrderType() == ORDER_TYPE_BUY)
   {
      double swingLow = GetNearestSwingLow(currentPrice);
      if (swingLow > 0)
         newSL = swingLow + atrBuffer;
      else
         newSL = currentPrice - atrBuffer;

      // Only trail if new SL improves current SL and price has moved enough
      if (newSL > OrderStopLoss() && newSL > OrderOpenPrice())
         return true;
   }
   else if (OrderType() == ORDER_TYPE_SELL)
   {
      double swingHigh = GetNearestSwingHigh(currentPrice);
      if (swingHigh > 0)
         newSL = swingHigh - atrBuffer;
      else
         newSL = currentPrice + atrBuffer;

      if (newSL < OrderStopLoss() && newSL < OrderOpenPrice())
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Apply trailing stop to position                                 |
//| Uses nearest swing point + ATR buffer for stop placement        |
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
         newSL = currentPrice - atrBuffer;
   }
   else
   {
      double swingHigh = GetNearestSwingHigh(currentPrice);
      if (swingHigh > 0)
         newSL = swingHigh - atrBuffer;
      else
         newSL = currentPrice + atrBuffer;
   }

   // Normalize SL
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if (tickSize > 0)
      newSL = MathRound(newSL / tickSize) * tickSize;

   // Only update if SL is better
   if ((OrderType() == ORDER_TYPE_BUY && newSL > OrderStopLoss()) ||
       (OrderType() == ORDER_TYPE_SELL && newSL < OrderStopLoss()))
   {
      if (g_TradeManagerTrade.OrderModify(ticket, newSL, OrderTakeProfit(), 0))
      {
         Logger_Log(DEBUG, "Trailing stop updated for " + IntegerToString(ticket) +
                    " -> " + DoubleToString(newSL,
                    (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Check if should early exit                                      |
//| CHoCH: exit when trend reverses against the position direction  |
//| Daily Limits: exit when daily loss/profit/trade limits hit      |
//+------------------------------------------------------------------+
bool ShouldEarlyExit(ulong ticket)
{
   // --- Daily limits check ---
   if (g_TradeContext.DailyLimitsReached())
   {
      Logger_Log(INFO, "Daily limits reached — early exit triggered");
      return true;
   }

   // --- CHoCH reversal check ---
   if (!OrderSelect(ticket, SELECT_BY_TICKET))
      return false;

   int positionType = (int)OrderType();   // ORDER_TYPE_BUY=0, ORDER_TYPE_SELL=1
   int trend        = g_TradeContext.CurrentTrend;

   // BUY position (0) + trend reverses to SELL (-1) → bearish CHoCH
   if (positionType == ORDER_TYPE_BUY && trend == DIRECTION_SELL)
      return true;

   // SELL position (1) + trend reverses to BUY (1) → bullish CHoCH
   if (positionType == ORDER_TYPE_SELL && trend == DIRECTION_BUY)
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
      UntrackPartialClose(ticket);
      return true;
   }

   return false;
}
//+------------------------------------------------------------------+

#endif // __CORE_TRADEMANAGER_MHQ__
