# TradingView Market Profile / Volume Profile (Native Style)

`MarketProfile.pine` is a Pine Script v5 overlay indicator that recreates a TradingView-native-style session profile for use on TradingView charts.

## What it draws

- Session-based horizontal profile on the price chart.
- Volume Profile mode using TradingView volume/tick-volume data.
- TPO mode for a classic Market Profile-style count.
- POC, VAH, and VAL levels.
- Configurable Value Area percentage, row sizing, profile width, placement, colors, and labels.
- Up/Down split display or Total display, similar to TradingView profile tools.

## Installation

1. Open **TradingView → Pine Editor**.
2. Copy all contents of `TradingView/MarketProfile.pine` into the editor.
3. Click **Save** and then **Add to chart**.
4. Open the indicator settings and adjust the session, timezone, row sizing, width, colors, and display mode.

## Important settings

- **Session**: TradingView session string, for example `0000-2359`, `0930-1600`, or your custom market hours.
- **Session timezone**: Defaults to the symbol timezone. Change it if you want the profile session to follow another timezone.
- **Profiles to show**: Number of recent sessions to draw.
- **Profile source**:
  - `Volume`: behaves more like TradingView's native Volume Profile and uses the chart's available volume. Forex symbols usually provide tick volume.
  - `TPO`: behaves more like classic Market Profile by counting each candle as one observation.
- **Row size mode**:
  - `Number of rows`: similar to native fixed row count.
  - `Ticks per row`: fixed price increment per row.
- **Value Area %**: Default is 70%, matching common profile defaults.
- **Volume display**: `Up / Down` splits bullish and bearish candle contribution; `Total` draws one histogram color.

## Notes and limitations

TradingView Pine scripts cannot create the exact built-in chart type UI or access every internal feature of TradingView's native paid Volume Profile tools. This script is an overlay approximation with comparable controls and visual behavior, and it recalculates from the loaded chart bars so it works naturally in TradingView Bar Replay.
