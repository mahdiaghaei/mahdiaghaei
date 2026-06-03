# MarketProfile.mq5

`MarketProfile.mq5` is a MetaTrader 5 chart-window indicator that draws a session-based Market Profile / TPO histogram directly on the price chart.

## Features

- Draws the most recent configurable number of broker-time sessions.
- Builds price buckets from each candle's high/low range.
- Highlights the value area, with the default set to 70% of counted TPOs.
- Draws Point of Control (POC), Value Area High (VAH), and Value Area Low (VAL) levels.
- Exposes inputs for session start/end, bucket size, maximum rows, colors, labels, and chart-time anchoring.
- Uses MT5 chart APIs (`ChartGetInteger`, `ObjectCreate`, `ObjectSet*`) and an `MP5_` object prefix so it does not collide with the MT4 version's objects.

## Installation

1. Copy `MarketProfile.mq5` to your terminal's `MQL5/Indicators` folder.
2. Restart MetaTrader 5 or refresh the Navigator panel.
3. Attach **Market Profile (Session TPO)** to a chart.
4. Adjust `SessionStartHour`, `SessionEndHour`, and `PointsPerPriceStep` for your symbol and broker server time.
5. Keep `UseVisibleChartTime` enabled when using the MT5 Strategy Tester visual chart so profiles are anchored to the visible/tested chart date instead of the broker/server current date.

## Notes

- This indicator uses candle high/low ranges as TPO coverage, not exchange volume.
- `UseVisibleChartTime` makes the profile follow the chart's right edge; if the chart APIs are not available, the latest calculated bar time is used as the fallback anchor.
- Lower `PointsPerPriceStep` values create more detailed profiles but can draw more chart objects.
- If a profile is too dense, increase `PointsPerPriceStep` or lower `MaxProfileRows`.
