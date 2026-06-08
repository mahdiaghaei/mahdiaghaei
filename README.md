# MarketProfileTPO for MetaTrader 5

`MarketProfileTPO.mq5` is a MetaTrader 5 custom indicator that draws TPO-based Market Profile distributions directly on the price chart.

## Features

- Daily profiles split by US exchange sessions:
  - RTH: default `09:30-16:00` New York time.
  - Overnight ETH: default `18:00-09:30` New York time, assigned to the next trading date.
  - Optional full ETH day: default `18:00-17:00` New York time.
- Weekly market profile.
- Monthly market profile.
- TPO row counts, optional TPO letters, POC, VAH, and VAL.
- Configurable source timeframe, bracket minutes, price row size, number of profiles, colors, and chart placement.

## Installation

1. Open MetaTrader 5.
2. Go to **File → Open Data Folder**.
3. Copy `MarketProfileTPO.mq5` into `MQL5/Indicators/`.
4. Open MetaEditor, compile the file, and attach the indicator to a chart.

## Important timezone setting

MetaTrader symbols use broker/server time, so the indicator exposes `InpServerToNewYorkMinutes`.
Set it so that:

```text
server time + InpServerToNewYorkMinutes = New York time
```

For example, if server time is UTC and New York is UTC-4, set `InpServerToNewYorkMinutes = -240`. If New York is UTC-5, set `-300`.

## Practical notes

- For futures-style profiles, use a liquid intraday chart and keep `InpSourceTimeframe` at `PERIOD_M5` or lower.
- Increase `InpTicksPerPriceRow` if the symbol has too many price rows.
- Disable `InpShowTpoLetters` if the chart becomes crowded or slow.
