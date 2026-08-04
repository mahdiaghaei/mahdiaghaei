# Trading OS

Trading OS is a local-first Windows desktop application for futures and intraday traders. It is built with Electron, React, TypeScript, Vite, Recharts, and SQLite.

## Installation

```bash
npm install
```

## Development

```bash
npm run dev
```

This starts Vite and opens the Electron shell with secure renderer isolation.

## Build

```bash
npm run build
```

## Windows Packaging

```bash
npm run package:win
```

The project uses `electron-builder` with an NSIS Windows target. Build artifacts are written to `release/`.

## Database Location

The SQLite database is initialized automatically at:

```text
data/trading_os.db
```

Electron IPC exposes backup, export, and import flows from the Settings page. Backup and export create timestamped copies beside the main database.

## Privacy

Trading OS is local-first. Journal records, screenshots paths, settings, playbook entries, and analytics stay on the local machine. The AI analysis service is a placeholder and does not call external APIs.

## Modules

- **Dashboard**: Today, account/risk settings, market bias, scenarios, recent trades, mistakes, and performance summary.
- **Daily OPS**: Market prep plans with macro, context, scenarios, levels, and review fields.
- **Trades**: Trade journal with scoring, P&L, lessons, emotions, and screenshot attachment path support through Electron file picker.
- **Playbook**: Setup documentation seeded with CL Failed Auction, ES Value Area Rejection, Opening Range Breakout, and Absorption Reversal.
- **Analytics**: Filters, win/loss statistics, expectancy, average R, profit factor, equity curve, and performance charts.
- **Research**: Market notes, AMT concepts, trade ideas, lessons, and article notes.
- **Settings**: Default instrument, default risk, account info, database export, backup, and import.

## Manual MVP Verification

1. Run `npm install`.
2. Run `npm run dev` and confirm Electron opens.
3. Confirm `data/trading_os.db` is created automatically.
4. Create and edit records in Daily OPS, Trades, Playbook, and Research.
5. Add trades and confirm Analytics charts and metrics update.
6. Use Settings to export, backup, and import a local database file.
