import type { DailyOps, Trade } from '../types';
export const aiAnalysisService = {
  analyzeDailyReview: (ops: DailyOps[]) => ({ summary: `Reviewed ${ops.length} daily plans.`, themes: ['Context alignment', 'Scenario quality'], nextActions: ['Compare post-market review with primary thesis'] }),
  analyzeMistakes: (trades: Trade[]) => ({ totalMistakes: trades.filter(t=>t.mistake).length, commonMistakes: [...new Set(trades.map(t=>t.mistake).filter(Boolean))].slice(0,5), recommendation: 'Tag every execution error consistently before enabling AI analysis.' }),
  detectPatterns: (trades: Trade[]) => ({ sampleSize: trades.length, patterns: ['Placeholder: setup/session clustering', 'Placeholder: emotion versus P&L'], confidence: 'local-placeholder' }),
  suggestPerformanceImprovements: (trades: Trade[]) => ({ focusAreas: ['Reduce low-score trades', 'Review negative expectancy setups'], actions: [`Audit ${trades.filter(t=>t.result_money<0).length} losing trades`] })
};
