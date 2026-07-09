# 📝 Changelog

## XAU SMC Scalper Pro — Version History

All notable changes to the XAU SMC Scalper Pro EA are documented in this file.

---

## [1.1] — 2026-07-09

### 🏗️ Architecture Overhaul

#### Fixed
- **Duplicate definitions resolved**: Separated `NewsService.mqh` (Services) from `NewsFilter.mqh` (Rules). The News Service (`CFileNewsService`) handles event data and timing, while the News Filter (`CNewsFilter`) implements the `IRule` interface for rule engine integration.
- **RiskManager 100× multiplier bug removed**: `CalculateLotSize()` previously applied an incorrect `× 100` factor, resulting in 100× oversized positions. Removed; now uses `riskAmount / (slDistance × tickValue)` directly.
- **NewsFilter dependency removed**: `CNewsFilter` no longer depends on a global `g_NewsService` variable. It delegates to the standalone `IsNewsActive()` wrapper function provided by `NewsService.mqh`.
- **Logger duplicate macros cleaned**: Removed conflicting macro definitions that caused compilation errors when Logger.mqh was included from multiple translation units.
- **Parameters conflicting definitions removed**: Eliminated duplicate struct/function definitions that caused "redefinition" errors on recompilation.
- **Missing `Rules\` directory in Install.bat**: Fixed directory creation path for Rules subfolder.

#### Added
- **MarketMode detection** (`Core/ATR.mqh`): Introduced `ATRMode` enum (`ATR_LOW`, `ATR_NORMAL`, `ATR_HIGH`, `ATR_EXTREME`) with `DetermineATRMode()` and `IsATRAcceptable()`. Market mode now gates entry — trading blocked during EXTREME and LOW volatility.
- **Proper TradeManager** (`Core/TradeManager.mqh`): Full implementation of:
  - **Partial Close at TP1**: 50% of position closed when price reaches 1R (entry ± (entry-SL)). Uses `PositionClosePartial()`.
  - **Break-Even move**: After partial close, SL moves to entry + 10-point buffer (spread protection).
  - **Trailing Stop**: Swing-point-based trailing with ATR buffer, only activates after TP1.
  - **CHoCH Exit**: Closes position when `g_TradeContext.CurrentTrend` reverses against position direction.
  - **Session End Exit**: Closes all positions when session becomes inactive.
- **Partial Close tracking** (`g_PC_Tickets[]`): Array-based tracking to prevent double partial closes. Max 50 tracked positions with FIFO eviction.
- **Execution service** (`Core/Execution.mqh`): Retry logic (max 2 retries), `IsExecutionAllowed()` pre-checks, `IsMarketNormal()` validation.
- **MetricsEngine** (`Core/MetricsEngine.mqh`): CSV export of trade metrics including confidence score breakdown, session info, R:R, and exit type.
- **TimeService** (`Services/TimeService.mqh`): New bar detection for M5/M15/H1, daily counter reset, bars-per-day calculation.
- **SymbolService** (`Services/SymbolService.mqh`): Normalized lot/price functions, symbol validation, margin checks.

#### Changed
- **Trade execution flow** restructured: `ExecuteTradingCycle()` now follows strict 8-step pipeline: Filters → Entry check → Trade limits → SL calculation → Lot sizing → Execution → Metrics → Logging.
- **SL calculation**: Now swing-based with ATR buffer fallback. `CalculateStopLoss()` uses `GetNearestSwingLow/High()` ± `GetATRBuffer()`, falling back to `DefaultSL` if no swing found.
- **TP calculation**: `CalculateTakeProfit()` uses 1.5× SL distance as default.
- **Confidence scoring**: Updated weight distribution to match Rule Engine implementation:
  - Trend: 20 | BOS: 15 | Liquidity: 15 | OB: 15 | FVG: 10 | PA: 10 | Spread: 5 | Session: 5 | News: 10

#### Removed
- **Redundant `MarketMode` detection** from `NewsService.mqh`: Market mode now determined solely by ATR analysis.
- **Manual news timing functions** replaced by `NewsService` interface.

---

## [1.0] — 2026-06-01

### 🎉 Initial Release

#### Added
- **Main EA framework** (`XAU_SMC_SCALPER.mq5`): OnInit/OnDeinit/OnTick lifecycle.
- **Multi-timeframe architecture**: H1 (trend/swing), M15 (structure/POI), M5 (entry/candle).
- **IRule interface** with Check/Name/Weight/Reason pattern.
- **Rule Engine** (`RuleEngine.mqh`): 4-level rule evaluation (Filter → Market → Entry → Risk).
- **Core modules**:
  - `ATR.mqh`: ATR(14) calculation, buffer management.
  - `DataCache.mqh`: Cached swing points, OBs, liquidity, FVGs.
  - `Session.mqh`: London (08:00-16:00 UTC), NY (13:00-21:00 UTC), Overlap.
  - `Risk.mqh`: Lot sizing, risk-reward calculation, margin validation.
  - `TradeContext.mqh`: Central state management, trend detection, price action.
  - `Logger.mqh`: File + terminal logging, CSV format.
- **Rule implementations**:
  - `TrendFilter.mqh`: H1 swing structure (HH/HL → BUY, LH/LL → SELL).
  - `BOSFilter.mqh`: Break of Structure on M15.
  - `LiquidityFilter.mqh`: Liquidity sweep detection.
  - `OrderBlockFilter.mqh`: Institutional OB identification.
  - `FVGFilter.mqh`: Fair Value Gap detection.
  - `PriceActionFilter.mqh`: Engulfing, Pin Bar, Rejection patterns.
  - `SpreadFilter.mqh`: Spread ratio validation.
  - `SessionFilter.mqh`: Trading session enforcement.
  - `NewsFilter.mqh`: High-impact news avoidance.
- **Model definitions**:
  - `Swing.mqh`: Swing point structure (SWING_HIGH, SWING_LOW).
  - `OrderBlock.mqh`: OB structure (bullish/bearish, mitigated status).
  - `LiquidityModel.mqh`: Liquidity levels and sweeps.
  - `ScoreModel.mqh`: FVG, PriceAction pattern types and quality scoring.
- **Configuration** (`Parameters.mqh`): All EA inputs with structured access.
- **Documentation**:
  - `PRD_XAU_SMC_Scalping_Pro.md`: Product requirements.
  - `MQL_Software_Arsitektur_XAU.md`: Software architecture.
  - `ASD_XAU_SMC_Scalping_Pro.md`: Application structure design.

---

*MotionMind — https://motionmind.store*
