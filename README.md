# 🏆 XAU SMC Scalper Pro

### Smart Money Concepts EA for Gold (XAUUSD) on MetaTrader 5

[![Version](https://img.shields.io/badge/Version-1.1-blue.svg)]()
[![Platform](https://img.shields.io/badge/Platform-MetaTrader%205-orange.svg)]()
[![Symbol](https://img.shields.io/badge/Symbol-XAUUSD-gold.svg)]()
[![Copyright](https://img.shields.io/badge/Copyright-MotionMind-green.svg)]()

---

> **⚠️ Disclaimer**: Trading foreign exchange on margin carries a high level of risk and may not be suitable for all investors. Past performance is not indicative of future results. You should be aware of all the risks associated with trading and seek advice from an independent financial advisor if you have any doubts.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🧠 **Smart Money Concepts** | Order Blocks, Fair Value Gaps, Liquidity Sweeps, Break of Structure |
| 📊 **Multi-Timeframe Analysis** | H1 (trend) → M15 (structure) → M5 (entry) |
| 🎯 **Confidence Scoring** | 9 weighted rules produce a 0-105 score; threshold 75 for entry |
| 🛡️ **Advanced Risk Management** | ATR-based SL, partial close at TP1, break-even, trailing stop |
| 📰 **News Filter** | Auto-blocks trading during NFP, FOMC, and high-impact events |
| ⏰ **Session Awareness** | London, New York, Overlap sessions with time-based filtering |
| 📈 **CHoCH Exit** | Automatic exit when market structure reverses against position |
| 📋 **CSV Metrics Export** | Detailed trade-by-trade performance logging |
| 🔄 **Partial Close Tracking** | Prevents double partial closes with ticket-based tracking |
| ⚡ **Optimized Execution** | Only processes on new M5 bars (CPU efficient) |

---

## 📦 Installation

### Option A: Automated Install (Windows)

1. Download or clone this repository
2. Double-click `Install.bat`
3. The installer will:
   - Auto-detect your MT5 Data Folder
   - Copy EA to `MQL5\Experts\`
   - Copy includes to `MQL5\Include\SMC_Scalper\`
4. Open MetaTrader 5 → Press **F4** (MetaEditor) → Press **F7** (Compile)
5. Drag "XAU SMC Scalper Pro" onto a **XAUUSD M5** chart
6. Enable **"Allow Algo Trading"**

### Option B: Manual Install

1. Copy `Experts\XAU_SMC_SCALPER.mq5` to:
   ```
   %APPDATA%\MetaQuotes\Terminal\<ID>\MQL5\Experts\
   ```

2. Copy all folders (`Core\`, `Config\`, `Models\`, `Rules\`, `Services\`) to:
   ```
   %APPDATA%\MetaQuotes\Terminal\<ID>\MQL5\Include\SMC_Scalper\
   ```

3. In MetaEditor: **File → Open** → Navigate to the EA → **Compile** (F7)

4. In MT5: Drag EA onto XAUUSD M5 chart → Enable Algo Trading

---

## ⚙️ Configuration

### Input Parameters

All parameters are configurable via MT5's Inputs tab. Here's a guide:

#### Trading Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `RiskPercent` | 0.5% | Risk per trade as % of balance. Range: 0.1% - 5.0% |
| `DailyLossLimit` | 3% | Maximum daily loss as % of day-start balance |
| `DailyProfitTarget` | 2% | Daily profit target — stop trading after hit |
| `MaxTradesPerDay` | 5 | Maximum trades opened per day |
| `MagicNumber` | 20240701 | Unique identifier for EA's trades |

#### Confidence Score Weights

| Rule | Default Weight | Description |
|------|---------------|-------------|
| `TrendWeight` | 20 | H1 market structure (HH/HL or LH/LL) |
| `StructureWeight` | 15 | Break of Structure on M15 |
| `LiquidityWeight` | 15 | Liquidity sweep detection |
| `OBWeight` | 15 | Order Block proximity |
| `FVGWeight` | 10 | Fair Value Gap presence |
| `PriceActionWeight` | 10 | Candlestick patterns (Engulfing, Pin Bar, etc.) |
| `SpreadWeight` | 5 | Spread quality |
| `SessionWeight` | 5 | Active trading session |

#### Risk Management

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MinConfidenceScore` | 75 | Minimum score for entry (out of ~105 max) |
| `DefaultSL` | 100 points | Fallback stop loss when no swing found |
| `DefaultTP` | 150 points | Take profit = 1.5× SL distance |
| `TrailingStart` | 100 points | Points before trailing activates |

---

## 🔄 How It Works

### Signal Flow

```
┌─────────────────────────────────────────────────────────┐
│                      ON NEW M5 BAR                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│  │ H1 Data  │───▶│ Trend    │───▶│ Trend    │         │
│  │ (Swings) │    │ Detection│    │ Score:20 │         │
│  └──────────┘    └──────────┘    └──────────┘         │
│                                                          │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│  │ M15 Data │───▶│ Structure│───▶│ BOS    │         │
│  │ (Swings) │    │ Analysis │    │ Score:15 │         │
│  └──────────┘    └──────────┘    └──────────┘         │
│                                                          │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│  │ M5 Data  │───▶│ Entry    │───▶│ OB + FVG  │         │
│  │ (Candles)│    │ Patterns │    │ PA Scores │         │
│  └──────────┘    └──────────┘    └──────────┘         │
│                                                          │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│  │ Filters  │───▶│ Session  │───▶│ Hard      │         │
│  │ Check    │    │ News     │    │ Stop Gate │         │
│  └──────────┘    │ Spread   │    └──────────┘         │
│                   └──────────┘                          │
│                          │                              │
│                          ▼                              │
│               ┌──────────────────┐                     │
│               │ Confidence Score │                     │
│               │    ≥ 75?         │                     │
│               └──────┬───────────┘                     │
│                      │ YES                             │
│                      ▼                                 │
│         ┌────────────────────────┐                     │
│         │ Calculate SL (Swing)   │                     │
│         │ Calculate TP (1.5×R)   │                     │
│         │ Calculate Lot (Risk%)  │                     │
│         │ Execute Market Order   │                     │
│         └────────────────────────┘                     │
│                      │                                 │
│                      ▼                                 │
│         ┌────────────────────────┐                     │
│         │    MANAGE POSITION     │                     │
│         │ • Partial close @ TP1  │                     │
│         │ • Break-even after TP1 │                     │
│         │ • Trailing (swing+ATR) │                     │
│         │ • CHoCH exit           │                     │
│         └────────────────────────┘                     │
└─────────────────────────────────────────────────────────┘
```

### Trading Sessions (UTC)

| Session | UTC Hours | WIB (UTC+7) | Status |
|---------|-----------|-------------|--------|
| 🌏 **Asia** | 00:00 - 08:00 | 07:00 - 15:00 | ❌ No Trading |
| 🇬🇧 **London** | 08:00 - 16:00 | 15:00 - 23:00 | ✅ Trading |
| 🇺🇸 **New York** | 13:00 - 21:00 | 20:00 - 04:00 | ✅ Trading |
| 🔄 **Overlap** | 13:00 - 16:00 | 20:00 - 23:00 | ✅ Best Session |

---

## 🛡️ Risk Management

### Position Sizing

The EA calculates lot size based on:

```
Lot Size = (Balance × Risk%) / (SL Distance × Tick Value)
```

- **0.5% risk** on $10,000 = $50 max loss per trade
- SL distance determines lot size inversely (wider SL = smaller lot)

### Trade Management Lifecycle

1. **Entry**: Market order with swing-based SL + 1.5R TP
2. **TP1 (1R)**: Close 50% of position, lock in profit
3. **Break-Even**: Move SL to entry + 10pt buffer
4. **Trailing**: Trail SL using nearest swing + ATR buffer
5. **CHoCH Exit**: Close if trend reverses against position
6. **Session End**: Close all positions when session ends

### Daily Limits

- **Max 3 concurrent positions**
- **Max 5 trades per day**
- **3% daily loss limit** (hard stop)
- **2% daily profit target** (optional stop)

---

## 📊 Backtesting

### Quick Start

1. Open MT5 → **Strategy Tester** (Ctrl+R)
2. Select: `XAU SMC Scalper Pro`
3. Symbol: **XAUUSD**
4. Period: **M5**
5. Date range: **2024.01.01 — 2025.12.31**
6. Modeling: **Every tick based on real ticks**
7. Deposit: **$10,000**
8. Click **Start**

### Expected Metrics

| Metric | Target |
|--------|--------|
| Win Rate | 55-65% |
| Risk:Reward | 1:1.5 (avg) |
| Monthly Return | 8-15% |
| Max Drawdown | < 10% |
| Profit Factor | > 1.5 |

See [BacktestReport.md](BacktestReport.md) for detailed analysis.

---

## 🐛 Troubleshooting

| Error | Cause | Solution |
|-------|-------|----------|
| `INIT_FAILED` | Missing include files | Ensure all `.mqh` files are in `MQL5\Include\SMC_Scalper\` |
| `Failed to initialize symbol service` | Symbol not found | Verify XAUUSD is available on your broker |
| `Error: Risk percent must be between 0.1% and 5%` | Invalid input | Adjust RiskPercent in EA inputs |
| `Order execution failed` | Broker rejection | Check spread, margin, and trading permissions |
| Compilation error: `redefinition` | Old files present | Delete old `.mqh` files and re-copy from this package |
| EA not trading | Session/News filter | Check if within trading hours; verify no news event |
| `Max trades reached` | Trade limit hit | Wait for positions to close or reduce MaxTradesPerDay |
| No entries in trending market | Confidence below threshold | Lower MinConfidenceScore (try 70) or adjust weights |

### Common Fixes

```mql5
// If EA shows "not trading" — check:
1. Is Allow Algo Trading enabled on chart?
2. Is the current time within London/NY session?
3. Are there high-impact news events nearby?
4. Is the H1 trend detectable (needs 50+ bars)?
5. Check the EA log for specific filter failures
```

---

## 📁 Project Structure

```
XAU-SMC-ScalperPro/
├── Experts/
│   └── XAU_SMC_SCALPER.mq5        # Main EA file
├── Core/
│   ├── ATR.mqh                     # ATR calculation & volatility modes
│   ├── DataCache.mqh               # Cached analysis results
│   ├── Execution.mqh               # Order execution with retry
│   ├── Logger.mqh                  # File + terminal logging
│   ├── MetricsEngine.mqh           # Trade metrics & CSV export
│   ├── Risk.mqh                    # Position sizing & risk calc
│   ├── Session.mqh                 # London/NY session management
│   ├── TradeContext.mqh            # Central state & trend detection
│   └── TradeManager.mqh            # TP1/BE/trailing/CHoCH management
├── Config/
│   └── Parameters.mqh              # EA input parameters
├── Models/
│   ├── LiquidityModel.mqh          # Liquidity levels & sweeps
│   ├── OrderBlockModel.mqh         # Order block structures
│   ├── ScoreModel.mqh              # FVG, PA pattern models
│   └── Swing.mqh                   # Swing point structures
├── Rules/
│   ├── BOSFilter.mqh               # Break of Structure rule
│   ├── FVGFilter.mqh               # Fair Value Gap rule
│   ├── IRule.mqh                   # Rule interface (Check/Name/Weight)
│   ├── LiquidityFilter.mqh         # Liquidity sweep rule
│   ├── NewsFilter.mqh              # News avoidance rule
│   ├── OrderBlockFilter.mqh        # Order Block proximity rule
│   ├── PriceActionFilter.mqh       # Candlestick pattern rule
│   ├── RuleEngine.mqh              # Rule evaluation engine
│   ├── SessionFilter.mqh           # Trading session rule
│   ├── SpreadFilter.mqh            # Spread quality rule
│   └── TrendFilter.mqh             # H1 trend direction rule
├── Services/
│   ├── NewsService.mqh             # News event data & timing
│   ├── SymbolService.mqh           # Symbol info & normalization
│   └── TimeService.mqh             # Bar tracking & time utilities
├── Docs/
│   ├── PRD_XAU_SMC_Scalping_Pro.md
│   ├── MQL_Software_Arsitektur_XAU.md
│   └── ASD_XAU_SMC_Scalping_Pro.md
├── Install.bat                      # Windows installer
├── README.md                        # This file
├── TDD.md                           # Test design document
├── BacktestReport.md                # Backtest methodology & results
├── CHANGELOG.md                     # Version history
└── .gitignore                       # Git ignore rules
```

---

## 📄 License

Copyright © 2026 MotionMind. All rights reserved.
https://motionmind.store

This software is provided as-is for educational and trading purposes. Use at your own risk.

---

## 🤝 Support

- 🌐 Website: [motionmind.store](https://motionmind.store)
- 📧 Email: support@motionmind.store
- 📖 Documentation: See `Docs/` folder for architecture and design documents

---

*Built with 💎 for the Smart Money community*
