import { contextBridge, ipcRenderer } from 'electron';
contextBridge.exposeInMainWorld('tradingOS',{ paths:()=>ipcRenderer.invoke('app:paths'), createBackup:()=>ipcRenderer.invoke('backup:create'), restoreBackup:()=>ipcRenderer.invoke('backup:restore'), dashboard:()=>ipcRenderer.invoke('db:dashboard'), analytics:()=>ipcRenderer.invoke('db:analytics') });
