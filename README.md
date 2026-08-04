# Trading Operating System (Trading OS)

Trading OS is an offline-first Windows desktop application for discretionary futures traders. It combines a trading journal, Daily Ops planning, market analysis, screenshot annotation, notes, playbook management, mistake tracking, emotion tracking, market database, reports, and statistics in one local institutional-style workspace.

## Architecture

- **Desktop shell:** Electron main/preload processes in `electron/`.
- **Frontend:** React + TypeScript + Material UI in `src/`.
- **Database:** SQLite through Prisma in `prisma/schema.prisma`.
- **Rich notes:** Tiptap editor.
- **Analytics charts:** Apache ECharts.
- **Screenshot annotation:** Fabric.js canvas.
- **Storage:** User data, database, screenshots, and backups are stored locally via Electron `app.getPath('userData')`.

## Implemented Modules

The navigation shell includes Dashboard, Calendar, Daily Ops, Trading Journal, Trade Review, Timeline, Notes, Screenshot Manager, Playbook, Statistics, Market Database, Reports, and Settings.

Core screens currently provide professional workflow scaffolding for Daily Ops, trade tickets, timeline events, notes, screenshots, analytics, backup/restore hooks, and future CRUD integration.

## Database Model

The Prisma schema defines the relational foundation for Users, TradingDays, DailyOps, Trades, Screenshots, TimelineEvents, Notes, Setups, Mistakes, Emotions, MarketConditions, Reviews, and Reports.

## Local Development

```bash
npm install
npm run typecheck
npm run dev
```

Before first database use, generate Prisma client and push the SQLite schema:

```bash
npm run prisma:generate
npm run db:push
```

## Future Integrations

The app is structured for CSV trade import, NinjaTrader/Rithmic import adapters, AI trade review, automated statistics, and market replay modules.
