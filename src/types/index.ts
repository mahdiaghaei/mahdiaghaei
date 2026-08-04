export type Id = number;
export type MarketRegime = 'Trend' | 'Balance' | 'Transition';
export type PreviousDayType = 'Normal Day' | 'Normal Variation' | 'Trend Day' | 'Double Distribution' | 'Neutral Day';
export type SetupType = 'Failed Auction' | 'Responsive Trade' | 'Initiative Continuation' | 'Breakout' | 'Breakout Failure' | 'Pullback' | 'Absorption' | 'Delta Divergence' | 'Other';
export type Direction = 'Long' | 'Short' | 'Flat';
export type Session = 'Asia' | 'London' | 'New York AM' | 'New York PM' | 'Globex';
export interface DailyOps { id?: Id; date:string; market:string; macro_context:string; economic_events:string; vix_state:string; dollar_context:string; weekly_context:string; daily_context:string; market_regime:MarketRegime; previous_day_type:PreviousDayType; overnight_high:string; overnight_low:string; previous_day_high:string; previous_day_low:string; vah:string; val:string; poc:string; key_levels:string; primary_scenario:string; secondary_scenario:string; invalidation_points:string; pre_market_notes:string; post_market_review:string; created_at?:string; }
export interface Trade { id?: Id; date:string; instrument:string; session:string; direction:string; quantity:number; entry_price:number; stop_price:number; target_price:number; exit_price:number; result_points:number; result_money:number; risk_reward:number; setup_type:string; market_context_score:number; location_score:number; orderflow_score:number; execution_score:number; entry_reason:string; exit_reason:string; mistake:string; lesson:string; emotion:string; screenshot_before:string; screenshot_entry:string; screenshot_exit:string; created_at?:string; }
export interface Playbook { id?: Id; setup_name:string; market:string; description:string; conditions:string; entry_rules:string; invalidation:string; target_logic:string; examples:string; number_of_trades:number; win_rate:number; average_R:number; created_at?:string; }
export interface MarketNote { id?: Id; title:string; category:string; content:string; tags:string; date:string; created_at?:string; }
export interface Setting { key:string; value:string; }
export interface AnalyticsFilters { dateFrom?:string; dateTo?:string; instrument?:string; setup_type?:string; direction?:string; session?:string; }
export type TableName = 'daily_ops'|'trades'|'playbook'|'market_notes'|'settings';
