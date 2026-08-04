declare global { interface Window { tradingOS?: { paths():Promise<Record<string,string>>; createBackup():Promise<string>; restoreBackup():Promise<string|null>; dashboard():Promise<any[]>; analytics():Promise<any>; } } }
export {};
