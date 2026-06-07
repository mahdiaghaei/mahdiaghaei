# MarketProfile.mq4

`MarketProfile.mq4` is a MetaTrader 4 chart-window indicator that draws a session-based Market Profile / TPO histogram directly on the price chart.

## Features

- Draws the most recent configurable number of broker-time sessions.
- Can also draw broker-time weekly profiles when `ShowWeeklyProfiles` is enabled.
- Builds price buckets from each candle's high/low range.
- Highlights the value area, with the default set to 70% of counted TPOs.
- Draws Point of Control (POC), Value Area High (VAH), and Value Area Low (VAL) levels.
- Supports fixed final POC/Value Area levels or dynamic developing POC/Value Area levels with `LevelMode`.
- Exposes inputs for session start/end, weekly profile count, bucket size, maximum rows, fixed/developing level mode, colors, labels, and chart-time anchoring.

## Installation

1. Copy `MarketProfile.mq4` to your terminal's `MQL4/Indicators` folder.
2. Restart MetaTrader 4 or refresh the Navigator panel.
3. Attach **Market Profile (Session TPO)** to a chart.
4. Adjust `SessionStartHour`, `SessionEndHour`, and `PointsPerPriceStep` for your symbol and broker server time.
5. Enable `ShowWeeklyProfiles` and set `WeeksToShow` if you also want one profile for each broker-time week. Weekly profiles start from Monday 00:00 broker time.
6. Set `LevelMode` to `LEVEL_MODE_FIXED` for final static POC/VA lines, or `LEVEL_MODE_DEVELOPING` for dynamic developing POC/VA segments.
7. Increase `DevelopingStepBars` if developing levels create too many chart objects on lower timeframes.
8. Keep `UseVisibleChartTime` enabled when using Soft4FX Forex Simulator or Strategy Tester so profiles are anchored to the visible/tested chart date instead of the broker/server current date.

## Notes

- This indicator uses candle high/low ranges as TPO coverage, not exchange volume.
- Weekly profiles use full broker-time weeks from Monday 00:00 through the next Monday 00:00.
- In `LEVEL_MODE_DEVELOPING`, the histogram still uses the full profile, while POC/VAH/VAL are drawn as developing segments as more candles are added to the session or week.
- `UseVisibleChartTime` makes the profile follow the chart's right edge; if the chart APIs are not available, the latest calculated bar time is used as the fallback anchor.
- Lower `PointsPerPriceStep` values create more detailed profiles but can draw more chart objects.
- If a profile is too dense, increase `PointsPerPriceStep` or lower `MaxProfileRows`.
