import { app, BrowserWindow, ipcMain, dialog } from 'electron';
import path from 'node:path';
import fs from 'node:fs/promises';
import { PrismaClient } from '@prisma/client';

const userData = app.getPath('userData');
const dbPath = path.join(userData, 'trading-os.sqlite');
process.env.DATABASE_URL = `file:${dbPath}`;
const prisma = new PrismaClient();

async function ensureDirs() { await fs.mkdir(path.join(userData, 'screenshots'), { recursive: true }); await fs.mkdir(path.join(userData, 'backups'), { recursive: true }); }
function createWindow() { const win = new BrowserWindow({ width: 1500, height: 950, backgroundColor: '#070b12', webPreferences: { preload: path.join(__dirname, 'preload.js') } }); if (process.env.VITE_DEV_SERVER_URL) win.loadURL(process.env.VITE_DEV_SERVER_URL); else win.loadFile(path.join(__dirname, '../dist/renderer/index.html')); }
app.whenReady().then(async()=>{ await ensureDirs(); createWindow(); });
app.on('window-all-closed',()=>{ if(process.platform!=='darwin') app.quit(); });

ipcMain.handle('app:paths',()=>({ userData, dbPath, screenshots:path.join(userData,'screenshots') }));
ipcMain.handle('backup:create', async()=>{ await ensureDirs(); const name=`trading-os-${new Date().toISOString().replace(/[:.]/g,'-')}.sqlite`; const target=path.join(userData,'backups',name); try { await fs.copyFile(dbPath,target); } catch { await fs.writeFile(target,''); } return target; });
ipcMain.handle('backup:restore', async()=>{ const result=await dialog.showOpenDialog({filters:[{name:'SQLite',extensions:['sqlite','db']}],properties:['openFile']}); if(result.canceled) return null; await fs.copyFile(result.filePaths[0], dbPath); return dbPath; });
ipcMain.handle('db:dashboard', async()=>{ const days=await prisma.tradingDay.findMany({orderBy:{date:'desc'},take:10,include:{trades:true,timelineEvents:true,emotions:true}}); return days; });
ipcMain.handle('db:analytics', async()=>{ const trades=await prisma.trade.findMany({include:{setup:true,mistakes:true}}); const wins=trades.filter(t=>t.pnl>0), losses=trades.filter(t=>t.pnl<0); const grossWin=wins.reduce((s,t)=>s+t.pnl,0), grossLoss=Math.abs(losses.reduce((s,t)=>s+t.pnl,0)); return { totalTrades:trades.length, winRate:trades.length?wins.length/trades.length:0, profitFactor:grossLoss?grossWin/grossLoss:0, expectancy:trades.length?trades.reduce((s,t)=>s+t.pnl,0)/trades.length:0, averageR:trades.length?trades.reduce((s,t)=>s+(t.rMultiple??0),0)/trades.length:0 }; });
