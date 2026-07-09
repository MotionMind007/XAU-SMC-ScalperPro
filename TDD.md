# 📋 TDD — Test Design Document

## XAU SMC Scalper Pro — Test Cases

> **Version**: 1.1  
> **Last Updated**: 2026-07-09  
> **Test Framework**: Manual MQL5 assertion-based  
> **Symbol**: XAUUSD · **Timeframe**: M5 (primary)

---

## Table of Contents

1. [Unit Tests](#1-unit-tests)
2. [Integration Tests](#2-integration-tests)
3. [Edge Cases](#3-edge-cases)
4. [Performance Tests](#4-performance-tests)
5. [Backtest Scenarios](#5-backtest-scenarios)

---

## 1. Unit Tests

### 1.1 `GetATRBuffer()` — ATR Buffer Calculation

| ID | Given | When | Then |
|----|-------|------|------|
| U-ATR-01 | `g_ATR_Buffer = 1.5`, `g_ATR_14 = 20.0` | Call `GetATRBuffer()` | Returns `1.5 × 20.0 = 30.0` (non-zero, positive) |
| U-ATR-02 | `g_ATR_Buffer = 1.5`, `g_ATR_14 = 0.0` | Call `GetATRBuffer()` | Returns `0.0` (edge: no ATR data) |
| U-ATR-03 | `g_ATR_Buffer = 1.5`, `g_ATR_14 = 50.0` | Call `GetATRBuffer()` | Returns `75.0` (extreme volatility) |
| U-ATR-04 | ATR(14) indicator initialized with handle | Call `CalculateATR(14)` | Returns positive value, `g_ATR_14` updated |

### 1.2 `CalculateTP1()` — Take Profit 1 Calculation

| ID | Given | When | Then |
|----|-------|------|------|
| U-TP1-01 | BUY order, `entry = 2400.00`, `sl = 2390.00` | Call `CalculateTP1(ticket)` | Returns `2400.00 + (2400.00 - 2390.00) = 2410.00` (1R upward) |
| U-TP1-02 | SELL order, `entry = 2400.00`, `sl = 2410.00` | Call `CalculateTP1(ticket)` | Returns `2400.00 - (2410.00 - 2400.00) = 2390.00` (1R downward) |
| U-TP1-03 | BUY order, `sl = 0` | Call `CalculateTP1(ticket)` | Returns `0.0` (invalid SL, no trade) |
| U-TP1-04 | SELL order, `entry = sl` | Call `CalculateTP1(ticket)` | Returns `entry` (zero R distance) |

### 1.3 `NormalizeLot()` — Lot Size Normalization

| ID | Given | When | Then |
|----|-------|------|------|
| U-LOT-01 | `minLot = 0.01`, `maxLot = 100.0`, `lotStep = 0.01` | `NormalizeLot(0.0543)` | Returns `0.05` (floored to step) |
| U-LOT-02 | `minLot = 0.01` | `NormalizeLot(0.001)` | Returns `0.01` (clamped to min) |
| U-LOT-03 | `maxLot = 100.0` | `NormalizeLot(150.0)` | Returns `100.0` (clamped to max) |
| U-LOT-04 | `lotStep = 0.01` | `NormalizeLot(0.015)` | Returns `0.01` (floored to nearest step) |
| U-LOT-05 | `minLot = 0.01`, `lotStep = 0.01` | `NormalizeLot(0.00)` | Returns `0.01` (minimum enforced) |

### 1.4 `CalculateLotSize()` / `CalculatePositionSizeFromSL()` — Risk Calculation

| ID | Given | When | Then |
|----|-------|------|------|
| U-RISK-01 | Balance `$10,000`, risk `0.5%`, `slDistance = 100pts`, `tickValue = 1.0` | Call `CalculateLotSize(0.5, 100)` | Returns `0.50` lots (`$50 / (100 × 1.0)`) |
| U-RISK-02 | Balance `$10,000`, risk `1.0%`, `slDistance = 200pts`, `tickValue = 1.0` | Call `CalculateLotSize(1.0, 200)` | Returns `0.50` lots (`$100 / (200 × 1.0)`) |
| U-RISK-03 | `tickValue = 0` | Call `CalculateLotSize(0.5, 100)` | Returns `0.0` (division-by-zero guard) |
| U-RISK-04 | `slDistance = 0` | Call `CalculateLotSize(0.5, 100)` | Returns `0.0` (division-by-zero guard) |
| U-RISK-05 | Balance `$10,000`, risk `0.5%`, `slDistance = 100` | Call `CalculateRiskAmount(0.5, 100)` | Returns `50.0` (risk amount = `lotSize × slDistance × tickValue`) |

### 1.5 `IsSessionActive()` — Session Window Check

| ID | Given | When | Then |
|----|-------|------|------|
| U-SES-01 | Server time `10:00 UTC` (London session) | `GetCurrentSession()` | Returns `SESSION_LONDON` |
| U-SES-02 | Server time `14:30 UTC` (overlap) | `GetCurrentSession()` | Returns `SESSION_OVERLAP` |
| U-SES-03 | Server time `18:00 UTC` (NY session) | `GetCurrentSession()` | Returns `SESSION_NEWYORK` |
| U-SES-04 | Server time `05:00 UTC` (Asia/off hours) | `GetCurrentSession()` | Returns `SESSION_NONE` |
| U-SES-05 | Server time `23:00 UTC` (off hours) | `GetCurrentSession()` | Returns `SESSION_NONE` |
| U-SES-06 | `session = SESSION_LONDON` | `IsSessionActive(session)` | Returns `true` |
| U-SES-07 | `session = SESSION_NONE` | `IsSessionActive(session)` | Returns `false` |
| U-SES-08 | `session = SESSION_OVERLAP` | `IsSessionActive(session)` | Returns `true` |

### 1.6 `IsOrderBlock()` — Order Block Detection

| ID | Given | When | Then |
|----|-------|------|------|
| U-OB-01 | M15 candle[i] is bearish, M15 candle[i+1] is bullish impulse (>0.5× bearish body) | `IsBullishOrderBlock(i)` | Returns `true` |
| U-OB-02 | M15 candle[i] is bullish, M15 candle[i+1] is bearish impulse (>0.5× bullish body) | `IsBearishOrderBlock(i)` | Returns `true` |
| U-OB-03 | M15 candle[i] is bullish, M15 candle[i+1] is bullish | `IsBullishOrderBlock(i)` | Returns `false` (no displacement) |
| U-OB-04 | M15 candle[i] is bearish, M15 candle[i+1] is bearish | `IsBearishOrderBlock(i)` | Returns `false` (no displacement) |
| U-OB-05 | `i` is at array boundary | `IsBullishOrderBlock(i)` | Returns `false` (bounds check) |

### 1.7 `IsFairValueGap()` — FVG Detection

| ID | Given | When | Then |
|----|-------|------|------|
| U-FVG-01 | 3 M5 candles: candle[2].low > candle[0].high | `UpdateFVG()` scan | Detects bullish FVG (gap up) |
| U-FVG-02 | 3 M5 candles: candle[2].high < candle[0].low | `UpdateFVG()` scan | Detects bearish FVG (gap down) |
| U-FVG-03 | 3 M5 candles with no gap (overlapping ranges) | `UpdateFVG()` scan | No FVG detected |
| U-FVG-04 | Bullish FVG detected, candle[1].low > candle[0].high and < candle[2].low | `UpdateFVG()` | FVG marked as `FVG_PARTIAL` |

### 1.8 `DetectTrend()` — H1 Market Bias (Swing-Based HH/HL Detection)

| ID | Given | When | Then |
|----|-------|------|------|
| U-TRD-01 | H1: last swing high > prev swing high, last swing low > prev swing low (HH + HL) | `DetectTrend()` | `CurrentTrend = DIRECTION_BUY`, `TrendScore = 20` |
| U-TRD-02 | H1: last swing high < prev swing high, last swing low < prev swing low (LH + LL) | `DetectTrend()` | `CurrentTrend = DIRECTION_SELL`, `TrendScore = 20` |
| U-TRD-03 | H1: less than 2 swing highs or 2 swing lows detected | `DetectTrend()` | `CurrentTrend = DIRECTION_NONE`, `TrendScore = 0` |
| U-TRD-04 | H1: conflicting (HH + LL) | `DetectTrend()` | `CurrentTrend = DIRECTION_NONE`, `TrendScore = 0` |
| U-TRD-05 | H1: H1Rates array has fewer than 50 bars | `DetectTrend()` | Returns without modification (insufficient data) |

### 1.9 `DetectCHoCH()` / `ShouldEarlyExit()` — Change of Character

| ID | Given | When | Then |
|----|-------|------|------|
| U-CHOC-01 | BUY position open, `g_TradeContext.CurrentTrend` becomes `DIRECTION_SELL` | `ShouldEarlyExit(ticket)` | Returns `true` (bearish CHoCH against BUY) |
| U-CHOC-02 | SELL position open, `g_TradeContext.CurrentTrend` becomes `DIRECTION_BUY` | `ShouldEarlyExit(ticket)` | Returns `true` (bullish CHoCH against SELL) |
| U-CHOC-03 | BUY position open, trend remains `DIRECTION_BUY` | `ShouldEarlyExit(ticket)` | Returns `false` (no reversal) |
| U-CHOC-04 | BUY position open, trend becomes `DIRECTION_NONE` | `ShouldEarlyExit(ticket)` | Returns `false` (CHoCH only on opposing direction) |

### 1.10 `GetConsecutiveCandleDirection()` — Candle Pattern Analysis

| ID | Given | When | Then |
|----|-------|------|------|
| U-CCD-01 | Last 3 M5 candles are all bullish (close > open) | Check consecutive direction | Returns `3` (bullish count) |
| U-CCD-02 | Last 2 candles bullish, 3rd is bearish | Check consecutive direction | Returns `2` (interrupted) |
| U-CCD-03 | Last 4 M5 candles are all bearish (close < open) | Check consecutive direction | Returns `-4` (bearish count) |
| U-CCD-04 | Alternating bullish/bearish | Check consecutive direction | Returns `1` or `-1` (no continuation) |

### 1.11 `GetNextHighImpactNews()` — News Timing

| ID | Given | When | Then |
|----|-------|------|------|
| U-NEWS-01 | NFP scheduled for 2026-07-03 12:30 UTC, current time is 2026-07-03 11:00 UTC | `GetNextHighImpactNews()` | Returns `2026-07-03 12:30 UTC` |
| U-NEWS-02 | NFP scheduled for 2026-07-03 12:30 UTC, current time is 2026-07-03 13:00 UTC | `GetNextHighImpactNews()` | Returns next future event (not past) |
| U-NEWS-03 | No events loaded | `GetNextHighImpactNews()` | Returns `0` |
| U-NEWS-04 | NFP event at 12:30 UTC, current time is 12:15 UTC | `IsNewsActive()` | Returns `true` (within 30-minute window) |
| U-NEWS-05 | NFP event at 12:30 UTC, current time is 13:15 UTC | `IsNewsActive()` | Returns `true` (within 30-minute after window) |
| U-NEWS-06 | NFP event at 12:30 UTC, current time is 11:55 UTC | `IsNewsActive()` | Returns `false` (more than 30 min before) |

---

## 2. Integration Tests

### 2.1 Signal Generation — All Rules Fire

| ID | Given | When | Then |
|----|-------|------|------|
| I-SIG-01 | H1 trend = BUY, BOS confirmed, liquidity swept, fresh OB, fresh FVG, price action detected, spread < max, active session, no news | `g_RuleEngine.CheckEntry()` | `decision.Allowed = true`, `ConfidenceScore ≥ 75` |
| I-SIG-02 | All filters pass, confidence score = 95 (Trend 20 + BOS 15 + Liquidity 15 + OB 15 + FVG 10 + PA 10 + Spread 5 + Session 5) | `CheckEntry()` | Score = 95 ≥ 75 → entry allowed |
| I-SIG-03 | Only Trend + BOS + OB pass (score = 50) | `CheckEntry()` | `decision.Allowed = false` (50 < 75) |
| I-SIG-04 | Trend passes but BOS, Liquidity, OB all fail | `CheckEntry()` | Score ≤ 20 → entry blocked |

### 2.2 Trend Filter — Multi-Timeframe Conflict

| ID | Given | When | Then |
|----|-------|------|------|
| I-TRD-01 | H1 trend = `DIRECTION_SELL`, M5 shows bullish engulfing | `CTrendFilter.Check()` | Returns `false` (trend filter passes since trend exists, but direction is SELL — buy entry blocked by direction) |
| I-TRD-02 | H1 trend = `DIRECTION_NONE` | `CTrendFilter.Check()` | Returns `false` (no trend = no entry) |
| I-TRD-03 | H1 trend = `DIRECTION_BUY`, M5 bullish signal | `CTrendFilter.Check()` | Returns `true` (aligned) |

### 2.3 Risk Check — Concurrent Trade Limits

| ID | Given | When | Then |
|----|-------|------|------|
| I-RSK-01 | `ActiveTrades = 0`, `TradesToday = 3`, `MaxTradesPerDay = 5` | `ExecuteTradingCycle()` | Trade allowed (daily limit not reached) |
| I-RSK-02 | `ActiveTrades = 3` | `ExecuteTradingCycle()` | Trade blocked ("Max trades reached") |
| I-RSK-03 | `TradesToday = 5`, `MaxTradesPerDay = 5` | `DailyLimitsReached()` | Returns `true` |
| I-RSK-04 | `DailyLoss = $300`, `BalanceAtDayStart = $10,000`, `DailyLossLimit = 3%` | `DailyLimitsReached()` | Returns `true` (loss = 3% of balance) |

### 2.4 Session Filter — Outside Hours

| ID | Given | When | Then |
|----|-------|------|------|
| I-SES-01 | Server time `05:00 UTC` (off hours) | `CSessionFilter.Check()` | Returns `false` (SESSION_NONE) |
| I-SES-02 | Server time `10:00 UTC` (London) | `CSessionFilter.Check()` | Returns `true` (London active) |
| I-SES-03 | Server time `14:30 UTC` (Overlap) | `CSessionFilter.Check()` | Returns `true` (Overlap active) |
| I-SES-04 | London session disabled in filter constructor | `CSessionFilter.Check()` during London | Returns `false` (London disallowed) |

### 2.5 News Filter — NFP Blocking

| ID | Given | When | Then |
|----|-------|------|------|
| I-NEWS-01 | NFP event at 12:30 UTC, current time 12:15 UTC | `CNewsFilter.Check()` | Returns `false` (news active → blocked) |
| I-NEWS-02 | NFP event at 12:30 UTC, current time 11:00 UTC | `CNewsFilter.Check()` | Returns `true` (outside 30-min window) |
| I-NEWS-03 | NFP event at 12:30 UTC, current time 12:45 UTC | `CNewsFilter.Check()` | Returns `false` (within after window) |
| I-NEWS-04 | No upcoming news events | `CNewsFilter.Check()` | Returns `true` (no news → safe) |

### 2.6 Trade Management — TP1 → Partial Close → BE → Trailing

| ID | Given | When | Then |
|----|-------|------|------|
| I-MGT-01 | BUY at `2400.00`, SL at `2390.00`, price reaches `2410.00` (TP1 = 1R) | `ShouldPartialClose()` | Returns `true` → 50% position closed |
| I-MGT-02 | Position partially closed at TP1, price = `2410.00`, entry = `2400.00` | `ShouldMoveToBreakEven()` | Returns `true` → SL moved to `2400.10` (entry + 10pt buffer) |
| I-MGT-03 | Position at BE, price = `2420.00`, nearest swing low = `2412.00` | `ShouldTrailStop()` | Returns `true` → SL trails to `2412.00 + ATR_buffer` |
| I-MGT-04 | Position NOT yet partially closed, price at TP1 | `ShouldMoveToBreakEven()` | Returns `false` (requires partial close first) |
| I-MGT-05 | Position partially closed, but current SL already at/beyond entry | `ShouldMoveToBreakEven()` | Returns `false` (SL already at BE or better) |
| I-MGT-06 | BUY position, trend reverses to `DIRECTION_SELL` | `ShouldEarlyExit()` | Returns `true` → position closed (CHoCH exit) |

---

## 3. Edge Cases

### 3.1 First Tick / Cold Start

| ID | Given | When | Then |
|----|-------|------|------|
| E-01 | EA just initialized, `g_TradeContext.LastUpdate = 0`, no market data loaded | First `OnTick()` | `UpdateTradeContext()` loads fresh data, no crash |
| E-02 | `g_ATR_14 = 0.0` (ATR not yet calculated) | `GetATRBuffer()` called | Returns `0.0`, SL falls back to `DefaultSL` |
| E-03 | `DataCache.SwingHighs` empty, `SwingLows` empty | `CBOSFilter.Check()` | Returns `false` (insufficient swing data) |
| E-04 | `H1Rates` array has fewer than 50 bars | `DetectTrend()` | Returns without modifying trend (no crash) |

### 3.2 All Rules Score 0

| ID | Given | When | Then |
|----|-------|------|------|
| E-05 | All M5/M15/H1 data shows no pattern, no trend, no OB, no FVG | `g_RuleEngine.CheckEntry()` | `ConfidenceScore = 0`, `Allowed = false` |
| E-06 | `CheckEntry()` with all rules returning false | Verify score | Total score = 0, no entry executed |

### 3.3 Max Concurrent Trades

| ID | Given | When | Then |
|----|-------|------|------|
| E-07 | 3 BUY positions open simultaneously | New signal arrives | `ActiveTrades = 3 ≥ MaxTradesPerDay` → no new trade |
| E-08 | 2 positions open, 1 closes on same tick | New signal arrives | `ActiveTrades` decreases → new trade allowed |

### 3.4 Daily Loss Limit

| ID | Given | When | Then |
|----|-------|------|------|
| E-09 | `BalanceAtDayStart = $10,000`, cumulative losses = `$300` | `DailyLimitsReached()` | Returns `true` (3% daily loss limit) |
| E-10 | Daily profit target hit: `dailyGain ≥ 2%` of balance | `DailyLimitsReached()` | Returns `true` (daily target reached) |
| E-11 | Open position at -$250, daily loss limit = $300 | `ShouldEarlyExit()` | Returns `true` → early exit to prevent breach |

### 3.5 Volatility Spike (ATR > 5× Normal)

| ID | Given | When | Then |
|----|-------|------|------|
| E-12 | `g_ATR_14 = 50.0` (extreme) | `DetermineATRMode()` | Returns `ATR_EXTREME` |
| E-13 | ATR mode = `ATR_EXTREME` | `IsATRAcceptable()` | Returns `false`, `MarketMode = MODE_NO_TRADE` |
| E-14 | ATR mode = `ATR_HIGH` (15-30 range) | `IsATRAcceptable()` | Returns `true`, `MarketMode = MODE_VOLATILE` |
| E-15 | ATR mode = `ATR_LOW` (<5.0) | `IsATRAcceptable()` | Returns `false`, `MarketMode = MODE_NO_TRADE` |

### 3.6 Market Gap / Missing Data

| ID | Given | When | Then |
|----|-------|------|------|
| E-16 | Weekend gap: no M5 candles for 48 hours | `UpdateDataCache()` | Returns `true`, cache uses last available data |
| E-17 | `CopyMarketData()` fails (connection issue) | `UpdateTradeContext()` | Returns `false`, error logged, no trade |
| E-18 | M5Rates array has fewer than 7 bars | `DetectPriceAction()` | Returns without modification (insufficient data) |

### 3.7 Invalid Position State

| ID | Given | When | Then |
|----|-------|------|------|
| E-19 | Position SL = 0 (invalid) | `CalculateTP1()` | Returns `0.0`, position management skipped |
| E-20 | Position already closed, ticket invalid | `ManageSinglePosition()` | `OrderSelect()` fails → function exits |
| E-21 | Partial close lot < `SYMBOL_VOLUME_MIN` | `PartialClose()` | Skips close, logs warning |
| E-22 | Position ticket not found in partial close tracking | `IsPartialClosed()` | Returns `false` (treated as not yet closed) |

---

## 4. Performance Tests

### 4.1 OnTick Execution Time

| ID | Given | When | Then |
|----|-------|------|------|
| P-01 | Normal market conditions, M5 new bar | `OnTick()` completes | Execution time < 100ms |
| P-02 | All rules evaluated, 3 OBs + 5 FVGs in cache | `CheckEntry()` completes | Score calculation < 50ms |
| P-03 | 3 positions managed simultaneously | `ManagePositions()` completes | Position management < 100ms |

### 4.2 DataCache Hit Rate

| ID | Given | When | Then |
|----|-------|------|------|
| P-04 | 1000 M5 ticks, only 12 new M5 bars | Track cache refresh | Cache hit rate > 90% (only refreshes on new bar) |
| P-05 | New M5 bar, M15/H1 unchanged | `UpdateIfNewCandle()` | M5 data refreshed, M15/H1 preserved |

### 4.3 Memory Usage

| ID | Given | When | Then |
|----|-------|------|------|
| P-06 | EA running for 24 hours with 50+ trades | Check memory | `DataCache` + `TradeContext` + arrays < 50MB |
| P-07 | `g_PC_Tickets` reaches `MAX_TRACKED_POSITIONS` (50) | New partial close | Oldest entry removed, array does not grow unbounded |
| P-08 | `MetricsEngine` with 1000+ trades in queue | `ExportToCSV()` | Queue cleared after batch export, memory freed |

---

## 5. Backtest Scenarios

### 5.1 Trending Market — London Session

| ID | Given | When | Then |
|----|-------|------|------|
| B-01 | XAUUSD trending up, H1 showing HH/HL, London session 08:00-16:00 UTC | Run backtest 3 months | Win rate ≥ 55%, multiple BUY entries at OB/FVG zones |
| B-02 | Strong bearish H1 trend, London session | Run backtest 3 months | SELL entries only, CHoCH exits on reversals |

### 5.2 Ranging Market — Asia Session

| ID | Given | When | Then |
|----|-------|------|------|
| B-03 | XAUUSD range-bound, no clear H1 trend (DIRECTION_NONE) | Run backtest during Asia hours | Zero trades (trend filter blocks all entries) |
| B-04 | Choppy M5 price action, multiple false breakouts | Run backtest | Low trade count, high-confidence filter prevents losses |

### 5.3 News Spike — NFP

| ID | Given | When | Then |
|----|-------|------|------|
| B-05 | NFP event at 12:30 UTC, position open at 12:15 UTC | Price moves 50+ pips in seconds | No new entry, existing position protected by CHoCH exit |
| B-06 | No position open, NFP window active (±30 min) | `CheckFilters()` | NewsFilter blocks → no trade during volatility spike |

### 5.4 Multiple Position Management

| ID | Given | When | Then |
|----|-------|------|------|
| B-07 | 3 positions open, all at profit (TP1 hit) | `ManagePositions()` | All 3 partially closed, all 3 moved to BE, trailing active on all |
| B-08 | 2 positions: one at profit, one at loss | Session ends | Both closed ("Session End"), PnL recorded correctly |
| B-09 | Position at TP1, second position hits SL same tick | `ManagePositions()` | Partial close succeeds on first, second closed by SL — no conflict |

---

## Appendix: Assertion Format (MQL5)

```mql5
// Unit test assertion helper
#define ASSERT(condition, testName) \
   if(!(condition)) { \
      Print("FAIL: " + testName); \
      testFailures++; \
   } else { \
      Print("PASS: " + testName); \
      testPasses++; \
   }

// Usage example:
// ASSERT(GetATRBuffer() == 30.0, "U-ATR-01: ATR Buffer = 1.5 * 20.0");
// ASSERT(lotSize >= minLot && lotSize <= maxLot, "U-LOT-01: Lot within bounds");
```

---

*Document generated from XAU SMC Scalper Pro v1.1 source code analysis.*
