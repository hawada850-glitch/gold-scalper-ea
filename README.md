# Gold Scalper EA - MT5 Expert Advisor

A fully automated **gold scalping bot** for MetaTrader 5 using multi-timeframe EMA crossovers with ATR-based risk management.

## 🎯 Strategy Overview

**Gold Scalper** is a high-frequency trading EA that:
- Uses **EMA 9/21 crossover on M1** (1-minute) for entry signals
- Confirms trades with **EMA 20/50 trend on M5** (5-minute)
- Sizes positions based on **1% account risk** per trade
- Uses **ATR (14)** to calculate dynamic stop-loss and take-profit levels
- Implements **trailing stops** to lock in profits
- Respects daily profit/loss limits to prevent overtrading

---

## 📊 How It Works

### Entry Logic
1. **Trend Filter (M5)**: Fast EMA must be above (uptrend) or below (downtrend) slow EMA
2. **Entry Signal (M1)**: Fast EMA crosses above (buy) or below (sell) slow EMA
3. **Confirmation**: Entry signal must align with M5 trend (no counter-trend trades)

### Risk Management
- **Position Size**: Calculated from account equity, risk %, and ATR stop distance
- **Stop Loss**: `ATR × 1.2` pips below entry (buy) or above entry (sell)
- **Take Profit**: `ATR × 1.2 × 1.5` pips above entry (buy) or below entry (sell)
- **Trailing Stop**: Activates at +$1 profit, trails by 150 pips
- **Daily Limits**: Stops trading after +$5 profit or -$2 loss

### Position Management
- Max 1 open position at a time
- All trades tagged with Magic Number `505050` for identification
- Includes swap and commission in daily P&L calculations

---

## ⚙️ Input Parameters

### Risk & Position Management
| Parameter | Default | Description |
|-----------|---------|-------------|
| `RiskPercent` | 1.0 | Risk per trade as % of account equity |
| `MaxPositions` | 1 | Maximum concurrent open positions |
| `MaxDailyProfit` | 5.0 | Stop trading after this profit ($) |
| `MaxDailyLoss` | 2.0 | Stop trading after this loss ($) |

### Trailing Stop
| Parameter | Default | Description |
|-----------|---------|-------------|
| `UseTrailing` | true | Enable trailing stop functionality |
| `TrailStartProfit` | 1.0 | Profit threshold to activate trailing ($) |
| `TrailDistancePts` | 150 | Distance trailing stop follows price (pips) |

### M1 (Entry) Indicators
| Parameter | Default | Description |
|-----------|---------|-------------|
| `FastEMA_M1` | 9 | Fast EMA period on M1 |
| `SlowEMA_M1` | 21 | Slow EMA period on M1 |

### M5 (Trend) Indicators
| Parameter | Default | Description |
|-----------|---------|-------------|
| `FastEMA_M5` | 20 | Fast EMA period on M5 |
| `SlowEMA_M5` | 50 | Slow EMA period on M5 |

### ATR & Profit Target
| Parameter | Default | Description |
|-----------|---------|-------------|
| `ATRPeriod` | 14 | ATR lookback period |
| `SL_ATR_Mult` | 1.2 | Stop-loss multiplier (SL = ATR × this value) |
| `TP_RR` | 1.5 | Risk/Reward ratio (TP = SL × this value) |
| `MagicNumber` | 505050 | Unique identifier for trades |

---

## 📋 Core Functions

### `OnInit()`
- Initializes all indicators (EMA & ATR handles)
- Sets magic number for trade identification
- Records the trading day start time
- Returns `INIT_FAILED` if any indicator fails to load

### `TrendDirection()`
Returns:
- `1` = Uptrend (Fast EMA > Slow EMA on M5)
- `-1` = Downtrend (Fast EMA < Slow EMA on M5)
- `0` = No clear trend

### `EntrySignal()`
Returns:
- `1` = Bullish crossover (Buy signal on M1)
- `-1` = Bearish crossover (Sell signal on M1)
- `0` = No crossover detected

### `DailyProfit()`
Calculates total daily P&L including:
- Realized profit/loss
- Swap charges
- Broker commissions

### `OpenPositions()`
Counts active positions for this EA (filtered by magic number and symbol)

### `CalculateLot(double stopPoints)`
Computes position size based on:
- Account equity
- Risk percentage
- Stop-loss distance in points
- Broker lot constraints (min, max, step)

### `ManageTrailing()`
Adjusts stop-loss to trail price when:
- Trade profit exceeds `TrailStartProfit`
- Price moves favorably beyond current SL + trail distance

### `OnTick()`
Main trading loop that:
1. Manages trailing stops
2. Checks daily P&L limits
3. Validates position count
4. Analyzes trend and entry signals
5. Executes trades with calculated lot size

---

## 🚀 Installation & Setup

1. **Download**: Clone or download `GoldScalper.mq5`
2. **Place in MT5 folder**: `...\MetaTrader 5\MQL5\Experts\`
3. **Compile**: Open MetaEditor, compile the file (F5)
4. **Attach to Chart**: 
   - Open XAUUSD (gold) chart in MT5
   - Drag EA from Navigator to the chart
   - Configure inputs as desired
   - Click **OK** to run

---

## ⚠️ Important Notes

- **Symbol**: Designed for **XAUUSD** (gold); adjust inputs for other symbols
- **Timeframe**: Attach to **any timeframe chart** (EA reads M1 & M5 internally)
- **Account Type**: Works on micro/mini/standard lots; adjust `RiskPercent` for small accounts
- **Spread**: Requires tight spreads (<2 pips) for consistent profits
- **Slippage**: May occur during high volatility; consider volatility filters in live trading
- **Backtest First**: Always backtest on historical data before live trading

---

## 📈 Optimization Tips

- **Reduce daily limits** if equity is small
- **Increase `TrailStartProfit`** to let winners run further
- **Adjust EMA periods** for different market conditions (faster = more trades, slower = fewer, higher-quality signals)
- **Increase `SL_ATR_Mult`** to allow more room for price swings (reduces stops, increases wins)

---

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| EA won't attach | Recompile or check chart symbol is XAUUSD |
| No trades executed | Check if trend/signal conditions are met; verify indicator handles |
| Trailing not working | Ensure `UseTrailing = true` and profit > `TrailStartProfit` |
| Lots too small | Increase `RiskPercent` or check broker lot step constraints |

---

## 📄 License

Free to use and modify for personal trading. No warranties.

---

**Version**: 1.00  
**Language**: MQL5  
**Author**: Gold Scalper Community  
**Last Updated**: 2026-09-01
