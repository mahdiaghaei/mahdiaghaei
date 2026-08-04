import { app, BrowserWindow, dialog, ipcMain } from 'electron';
import path from 'node:path';
import fs from 'node:fs';
import Database from 'better-sqlite3';
import { fileURLToPath } from 'node:url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, '..');
const dataDir = path.join(root, 'data');
const dbPath = path.join(dataDir, 'trading_os.db');
const tables = new Set(['daily_ops','trades','playbook','market_notes','settings']);
let db: Database.Database;
function now(){ return new Date().toISOString(); }
function ensureDb(){ fs.mkdirSync(dataDir,{recursive:true}); db = new Database(dbPath); db.pragma('journal_mode = WAL'); db.exec(`CREATE TABLE IF NOT EXISTS migrations(id INTEGER PRIMARY KEY, name TEXT UNIQUE, applied_at TEXT DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS daily_ops(id INTEGER PRIMARY KEY AUTOINCREMENT,date TEXT,market TEXT,macro_context TEXT,economic_events TEXT,vix_state TEXT,dollar_context TEXT,weekly_context TEXT,daily_context TEXT,market_regime TEXT,previous_day_type TEXT,overnight_high TEXT,overnight_low TEXT,previous_day_high TEXT,previous_day_low TEXT,vah TEXT,val TEXT,poc TEXT,key_levels TEXT,primary_scenario TEXT,secondary_scenario TEXT,invalidation_points TEXT,pre_market_notes TEXT,post_market_review TEXT,created_at TEXT DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS trades(id INTEGER PRIMARY KEY AUTOINCREMENT,date TEXT,instrument TEXT,session TEXT,direction TEXT,quantity REAL,entry_price REAL,stop_price REAL,target_price REAL,exit_price REAL,result_points REAL,result_money REAL,risk_reward REAL,setup_type TEXT,market_context_score REAL,location_score REAL,orderflow_score REAL,execution_score REAL,entry_reason TEXT,exit_reason TEXT,mistake TEXT,lesson TEXT,emotion TEXT,screenshot_before TEXT,screenshot_entry TEXT,screenshot_exit TEXT,created_at TEXT DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS playbook(id INTEGER PRIMARY KEY AUTOINCREMENT,setup_name TEXT,market TEXT,description TEXT,conditions TEXT,entry_rules TEXT,invalidation TEXT,target_logic TEXT,examples TEXT,number_of_trades INTEGER DEFAULT 0,win_rate REAL DEFAULT 0,average_R REAL DEFAULT 0,created_at TEXT DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS market_notes(id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT,category TEXT,content TEXT,tags TEXT,date TEXT,created_at TEXT DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY,value TEXT,created_at TEXT DEFAULT CURRENT_TIMESTAMP);`); seed(); }
function seed(){ const count = db.prepare('SELECT COUNT(*) c FROM playbook').get() as {c:number}; if(count.c) return; const stmt=db.prepare('INSERT INTO playbook(setup_name,market,description,conditions,entry_rules,invalidation,target_logic,examples,number_of_trades,win_rate,average_R) VALUES(@setup_name,@market,@description,@conditions,@entry_rules,@invalidation,@target_logic,@examples,0,0,0)'); ['CL Failed Auction','ES Value Area Rejection','Opening Range Breakout','Absorption Reversal'].forEach((setup_name)=>stmt.run({setup_name,market:setup_name.split(' ')[0],description:`Baseline rules for ${setup_name}.`,conditions:'Define context and location before entry.',entry_rules:'Wait for confirmation and execute only at planned levels.',invalidation:'Exit when auction thesis is invalidated.',target_logic:'Scale at opposing liquidity or value references.',examples:''})); db.prepare("INSERT OR IGNORE INTO migrations(name,applied_at) VALUES('initial_schema',?)").run(now()); }
function assertTable(t:string){ if(!tables.has(t)) throw new Error('Invalid table'); }
function safe<T>(fn:()=>T){ try{return fn();} catch(e){ console.error(e); throw e; } }
function rowById(table:string,id:any){ return db.prepare(`SELECT * FROM ${table} WHERE ${table==='settings'?'key':'id'}=?`).get(id); }
function createWindow(){ const win=new BrowserWindow({width:1440,height:920,title:'Trading OS',webPreferences:{preload:path.join(__dirname,'preload.js'),contextIsolation:true,nodeIntegration:false,sandbox:false}}); const dev=process.env.VITE_DEV_SERVER_URL; dev?win.loadURL(dev):win.loadFile(path.join(root,'dist/index.html')); }
app.whenReady().then(()=>{ ensureDb(); createWindow(); }); app.on('window-all-closed',()=>{ if(process.platform!=='darwin') app.quit(); });
ipcMain.handle('db:list',(_,table,filters={})=>safe(()=>{ assertTable(table); let sql=`SELECT * FROM ${table}`; const vals:any[]=[]; const clauses=Object.entries(filters).filter(([,v])=>v); if(clauses.length){ sql+=' WHERE '+clauses.map(([k])=>`${k}=?`).join(' AND '); vals.push(...clauses.map(([,v])=>v)); } return db.prepare(sql+' ORDER BY created_at DESC').all(...vals); }));
ipcMain.handle('db:get',(_,table,id)=>safe(()=>{assertTable(table); return rowById(table,id)||null;}));
ipcMain.handle('db:create',(_,table,record)=>safe(()=>{assertTable(table); const keys=Object.keys(record); const stmt=db.prepare(`INSERT INTO ${table}(${keys.join(',')}) VALUES(${keys.map(k=>'@'+k).join(',')})`); const info=stmt.run(record); return rowById(table, table==='settings'?record.key:info.lastInsertRowid);}));
ipcMain.handle('db:update',(_,table,id,record)=>safe(()=>{assertTable(table); const keys=Object.keys(record).filter(k=>k!=='id'&&k!=='created_at'); db.prepare(`UPDATE ${table} SET ${keys.map(k=>`${k}=@${k}`).join(',')} WHERE ${table==='settings'?'key':'id'}=@id`).run({...record,id}); return rowById(table,id);}));
ipcMain.handle('db:remove',(_,table,id)=>safe(()=>{assertTable(table); db.prepare(`DELETE FROM ${table} WHERE ${table==='settings'?'key':'id'}=?`).run(id); return true;}));
ipcMain.handle('db:analytics',(_,filters={})=>safe(()=>db.prepare('SELECT * FROM trades ORDER BY date ASC, id ASC').all().filter((r:any)=>Object.entries(filters).every(([k,v])=>!v || (k==='dateFrom'?r.date>=v:k==='dateTo'?r.date<=v:r[k]===v)))));
ipcMain.handle('file:selectImage',async()=>{ const r=await dialog.showOpenDialog({properties:['openFile'],filters:[{name:'Images',extensions:['png','jpg','jpeg','gif','webp']}]}); return r.canceled?null:r.filePaths[0]; });
function copyDb(kind:string){ const target=path.join(dataDir,`trading_os_${kind}_${Date.now()}.db`); fs.copyFileSync(dbPath,target); return target; }
ipcMain.handle('file:backupDatabase',()=>safe(()=>copyDb('backup'))); ipcMain.handle('file:exportDatabase',()=>safe(()=>copyDb('export'))); ipcMain.handle('file:getDatabasePath',()=>dbPath);
ipcMain.handle('file:importDatabase',async()=>{ const r=await dialog.showOpenDialog({properties:['openFile'],filters:[{name:'SQLite DB',extensions:['db','sqlite']}]}); if(r.canceled) return ''; db.close(); fs.copyFileSync(r.filePaths[0],dbPath); ensureDb(); return dbPath; });
