# MarketProfileTPO for MetaTrader 5

This repository contains a MetaTrader 5 custom indicator that draws TPO market profile text objects directly on the chart.

## Indicator

`Indicators/MarketProfileTPO.mq5` supports:

- Separate daily RTH and ETH/overnight profiles using New York session time.
- Weekly TPO market profiles.
- Monthly TPO market profiles.
- POC and 70% value-area highlighting.
- Configurable RTH/ETH session boundaries, row size, TPO period, colors, and rendering offsets.

## Installation

1. Copy `Indicators/MarketProfileTPO.mq5` into your MetaTrader 5 data folder under `MQL5/Indicators/`.
2. Open MetaEditor and compile the file.
3. Attach **MarketProfileTPO** to an intraday chart.

## Notes

The default session settings are based on New York time:

- RTH: 09:30 to 16:00
- ETH / overnight: 18:00 to 09:30, assigned to the next trading date for evening bars

For best TPO output, use an intraday chart timeframe such as M1, M5, M15, or M30.
