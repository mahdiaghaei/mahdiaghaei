# MarketProfile.mq4

`MarketProfile.mq4` is a MetaTrader 4 chart-window indicator that draws a session-based Market Profile / TPO histogram directly on the price chart.

## Features

- Draws the most recent configurable number of broker-time sessions.
- Builds price buckets from each candle's high/low range.
- Highlights the value area, with the default set to 70% of counted TPOs.
- Draws Point of Control (POC), Value Area High (VAH), and Value Area Low (VAL) levels.
- Exposes inputs for session start/end, bucket size, maximum rows, colors, and labels.

## Installation

1. Copy `MarketProfile.mq4` to your terminal's `MQL4/Indicators` folder.
2. Restart MetaTrader 4 or refresh the Navigator panel.
3. Attach **Market Profile (Session TPO)** to a chart.
4. Adjust `SessionStartHour`, `SessionEndHour`, and `PointsPerPriceStep` for your symbol and broker server time.

## Notes

- This indicator uses candle high/low ranges as TPO coverage, not exchange volume.
- Lower `PointsPerPriceStep` values create more detailed profiles but can draw more chart objects.
- If a profile is too dense, increase `PointsPerPriceStep` or lower `MaxProfileRows`.
