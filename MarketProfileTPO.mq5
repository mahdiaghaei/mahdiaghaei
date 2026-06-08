//+------------------------------------------------------------------+
//|                                             MarketProfileTPO.mq5 |
//|                         TPO Market Profile for MetaTrader 5      |
//+------------------------------------------------------------------+
#property copyright "OpenAI"
#property link      ""
#property version   "1.00"
#property description "TPO Market Profile with daily US RTH/ETH overnight, weekly, and monthly profiles."
#property indicator_chart_window
#property indicator_plots 0

//--- Profile visibility
input bool InpShowDailyProfiles      = true;    // Show daily session profiles
input bool InpShowWeeklyProfiles     = true;    // Show weekly profiles
input bool InpShowMonthlyProfiles    = true;    // Show monthly profiles
input int  InpDaysToShow             = 20;      // Daily profiles to show
input int  InpWeeksToShow            = 12;      // Weekly profiles to show
input int  InpMonthsToShow           = 12;      // Monthly profiles to show

//--- US session settings. Times are New York exchange time.
input int  InpServerToNewYorkMinutes = -420;    // Server time + this offset = New York time
input bool InpDrawRTH                = true;    // Draw RTH session (09:30-16:00 NY)
input bool InpDrawOvernightETH       = true;    // Draw overnight ETH session (18:00-09:30 NY)
input bool InpDrawFullETH            = false;   // Draw full ETH day (18:00-17:00 NY)
input int  InpRTHStartHour           = 9;       // RTH start hour NY
input int  InpRTHStartMinute         = 30;      // RTH start minute NY
input int  InpRTHEndHour             = 16;      // RTH end hour NY
input int  InpRTHEndMinute           = 0;       // RTH end minute NY
input int  InpETHStartHour           = 18;      // ETH day start hour NY
input int  InpETHStartMinute         = 0;       // ETH day start minute NY
input int  InpETHEndHour             = 17;      // ETH day end hour NY
input int  InpETHEndMinute           = 0;       // ETH day end minute NY

//--- TPO settings
input ENUM_TIMEFRAMES InpSourceTimeframe = PERIOD_M5; // Source timeframe for TPO brackets
input int    InpBracketMinutes       = 30;      // TPO bracket size in minutes
input double InpPriceStepPoints      = 0.0;     // Price row step in points (0 = auto tick size)
input int    InpTicksPerPriceRow     = 1;       // Auto step: ticks per price row
input int    InpValueAreaPercent     = 70;      // Value Area percent
input int    InpProfileWidthBars     = 28;      // Max profile width in bars
input int    InpRightShiftBars       = 2;       // Shift profile to right by bars
input int    InpTransparency         = 65;      // Rectangle transparency 0-255
input bool   InpShowTpoLetters       = true;    // Show TPO letters when chart has room
input bool   InpShowSummaryLevels    = true;    // Draw POC/VAH/VAL labels and lines
input bool   InpShowProfileLabels    = true;    // Draw profile title labels
input bool   InpClearOnDeinit        = true;    // Delete objects when indicator is removed

//--- Colors
input color InpRTHColor              = clrDodgerBlue;      // RTH profile color
input color InpOvernightColor        = clrDarkOrange;      // Overnight ETH color
input color InpFullETHColor          = clrMediumPurple;    // Full ETH color
input color InpWeeklyColor           = clrSeaGreen;        // Weekly profile color
input color InpMonthlyColor          = clrCrimson;         // Monthly profile color
input color InpPOCColor              = clrGold;            // POC color
input color InpVAColor               = clrSilver;          // VAH/VAL color
input color InpTextColor             = clrWhite;           // Text color

string PREFIX = "MP_TPO_";
double g_step = 0.0;
int    g_digits = 0;

class CProfile
{
public:
   datetime start_time;
   datetime end_time;
   string   key;
   string   title;
   color    profile_color;
   int      row_min;
   int      row_max;
   int      bracket_count;
   int      bars_count;
   int      counts[];
   ulong    masks[];

   void Reset(const string profile_key,const string profile_title,const datetime start_dt,const datetime end_dt,const color clr)
   {
      key=profile_key;
      title=profile_title;
      start_time=start_dt;
      end_time=end_dt;
      profile_color=clr;
      row_min=INT_MAX;
      row_max=-INT_MAX;
      bracket_count=0;
      bars_count=0;
      ArrayResize(counts,0);
      ArrayResize(masks,0);
   }

   bool IsEmpty()
   {
      return(row_min==INT_MAX || row_max==-INT_MAX || ArraySize(counts)==0);
   }

   void AddBar(const double low_price,const double high_price,const int bracket_id)
   {
      if(g_step<=0.0 || low_price<=0.0 || high_price<=0.0)
         return;

      int from_row=(int)MathFloor(low_price/g_step + 0.0000001);
      int to_row=(int)MathFloor(high_price/g_step + 0.0000001);
      if(to_row<from_row)
      {
         int tmp=from_row;
         from_row=to_row;
         to_row=tmp;
      }

      EnsureRows(from_row,to_row);
      ulong bit=(ulong)1 << (bracket_id % 64);
      for(int row=from_row; row<=to_row; row++)
      {
         int idx=row-row_min;
         if((masks[idx] & bit)==0)
         {
            masks[idx] |= bit;
            counts[idx]++;
         }
      }
      if(bracket_id+1>bracket_count)
         bracket_count=bracket_id+1;
      bars_count++;
   }

   void EnsureRows(const int from_row,const int to_row)
   {
      if(IsEmpty())
      {
         row_min=from_row;
         row_max=to_row;
         int size=row_max-row_min+1;
         ArrayResize(counts,size);
         ArrayResize(masks,size);
         ArrayInitialize(counts,0);
         ArrayInitialize(masks,0);
         return;
      }

      if(from_row>=row_min && to_row<=row_max)
         return;

      int old_min=row_min;
      int old_max=row_max;
      int old_size=ArraySize(counts);
      int old_counts[];
      ulong old_masks[];
      ArrayResize(old_counts,old_size);
      ArrayResize(old_masks,old_size);
      ArrayCopy(old_counts,counts);
      ArrayCopy(old_masks,masks);

      row_min=(int)MathMin(row_min,from_row);
      row_max=(int)MathMax(row_max,to_row);
      int new_size=row_max-row_min+1;
      ArrayResize(counts,new_size);
      ArrayResize(masks,new_size);
      ArrayInitialize(counts,0);
      ArrayInitialize(masks,0);

      for(int i=0; i<old_size; i++)
      {
         int new_idx=(old_min+i)-row_min;
         counts[new_idx]=old_counts[i];
         masks[new_idx]=old_masks[i];
      }
   }

   int TotalTPO()
   {
      int total=0;
      for(int i=0; i<ArraySize(counts); i++)
         total+=counts[i];
      return(total);
   }

   int MaxCount()
   {
      int max_count=0;
      for(int i=0; i<ArraySize(counts); i++)
         if(counts[i]>max_count)
            max_count=counts[i];
      return(max_count);
   }

   int POCIndex()
   {
      int size=ArraySize(counts);
      if(size<=0)
         return(-1);

      int max_count=MaxCount();
      double mid=(double)(size-1)/2.0;
      int best=-1;
      double best_dist=DBL_MAX;
      for(int i=0; i<size; i++)
      {
         if(counts[i]==max_count)
         {
            double dist=MathAbs((double)i-mid);
            if(dist<best_dist)
            {
               best_dist=dist;
               best=i;
            }
         }
      }
      return(best);
   }
};

int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME,"Market Profile TPO ETH/RTH/W/M");
   g_digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   g_step=ResolvePriceStep();
   if(g_step<=0.0)
   {
      Print("MarketProfileTPO: invalid price step.");
      return(INIT_PARAMETERS_INCORRECT);
   }
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(InpClearOnDeinit)
      DeleteAllObjects();
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total<2)
      return(rates_total);

   g_digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   g_step=ResolvePriceStep();
   DeleteAllObjects();
   BuildAllProfiles();
   ChartRedraw(0);
   return(rates_total);
}

double ResolvePriceStep()
{
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick<=0.0)
      tick=point;
   if(InpPriceStepPoints>0.0)
      return(NormalizeDouble(InpPriceStepPoints*point,g_digits));
   return(NormalizeDouble(tick*MathMax(1,InpTicksPerPriceRow),g_digits));
}

void BuildAllProfiles()
{
   MqlRates rates[];
   int copied=0;

   if(InpShowDailyProfiles)
   {
      copied=CopyRatesForLookback((int)MathMax(1,InpDaysToShow)+3,rates);
      if(copied>0)
         BuildDailyProfiles(rates,copied);
   }

   if(InpShowWeeklyProfiles)
   {
      copied=CopyRatesForLookback((int)MathMax(1,InpWeeksToShow)*7+7,rates);
      if(copied>0)
         BuildCalendarProfiles(rates,copied,"W",InpWeeklyColor);
   }

   if(InpShowMonthlyProfiles)
   {
      copied=CopyRatesForLookback((int)MathMax(1,InpMonthsToShow)*31+31,rates);
      if(copied>0)
         BuildCalendarProfiles(rates,copied,"M",InpMonthlyColor);
   }
}

int CopyRatesForLookback(const int lookback_days,MqlRates &rates[])
{
   datetime from=TimeCurrent()-(datetime)lookback_days*86400;
   ArrayFree(rates);
   int copied=CopyRates(_Symbol,InpSourceTimeframe,from,TimeCurrent(),rates);
   if(copied<=0)
   {
      Print("MarketProfileTPO: no rates copied, error ",GetLastError());
      return(0);
   }
   ArraySetAsSeries(rates,false);
   return(copied);
}

void BuildDailyProfiles(const MqlRates &rates[],const int copied)
{
   string active_key_rth="";
   string active_key_on="";
   string active_key_eth="";
   CProfile rth;
   CProfile overnight;
   CProfile eth;

   for(int i=0; i<copied; i++)
   {
      datetime ny_time=ServerToNY(rates[i].time);
      string rth_key="";
      string on_key="";
      string eth_key="";

      bool in_rth=GetRTHKey(ny_time,rth_key);
      bool in_on=GetOvernightKey(ny_time,on_key);
      bool in_eth=GetFullETHKey(ny_time,eth_key);

      if(InpDrawRTH)
      {
         if(in_rth && rth_key!=active_key_rth)
         {
            if(active_key_rth!="" && !rth.IsEmpty())
            {
               DrawProfile(rth,"D_RTH_"+active_key_rth);
            }
            active_key_rth=rth_key;
            rth.Reset(active_key_rth,"RTH "+active_key_rth,rates[i].time,rates[i].time,InpRTHColor);
         }
         if(in_rth)
         {
            rth.end_time=rates[i].time+PeriodSeconds(InpSourceTimeframe);
            rth.AddBar(rates[i].low,rates[i].high,BracketIndex(ny_time,RTHStartMinutes()));
         }
      }

      if(InpDrawOvernightETH)
      {
         if(in_on && on_key!=active_key_on)
         {
            if(active_key_on!="" && !overnight.IsEmpty())
            {
               DrawProfile(overnight,"D_ON_"+active_key_on);
            }
            active_key_on=on_key;
            overnight.Reset(active_key_on,"ON ETH "+active_key_on,rates[i].time,rates[i].time,InpOvernightColor);
         }
         if(in_on)
         {
            overnight.end_time=rates[i].time+PeriodSeconds(InpSourceTimeframe);
            overnight.AddBar(rates[i].low,rates[i].high,BracketIndex(ny_time,InpETHStartHour*60+InpETHStartMinute));
         }
      }

      if(InpDrawFullETH)
      {
         if(in_eth && eth_key!=active_key_eth)
         {
            if(active_key_eth!="" && !eth.IsEmpty())
            {
               DrawProfile(eth,"D_ETH_"+active_key_eth);
            }
            active_key_eth=eth_key;
            eth.Reset(active_key_eth,"ETH "+active_key_eth,rates[i].time,rates[i].time,InpFullETHColor);
         }
         if(in_eth)
         {
            eth.end_time=rates[i].time+PeriodSeconds(InpSourceTimeframe);
            eth.AddBar(rates[i].low,rates[i].high,BracketIndex(ny_time,InpETHStartHour*60+InpETHStartMinute));
         }
      }
   }

   if(InpDrawRTH && active_key_rth!="" && !rth.IsEmpty())
      DrawProfile(rth,"D_RTH_"+active_key_rth);
   if(InpDrawOvernightETH && active_key_on!="" && !overnight.IsEmpty())
      DrawProfile(overnight,"D_ON_"+active_key_on);
   if(InpDrawFullETH && active_key_eth!="" && !eth.IsEmpty())
      DrawProfile(eth,"D_ETH_"+active_key_eth);
}

void BuildCalendarProfiles(const MqlRates &rates[],const int copied,const string mode,const color clr)
{
   string active_key="";
   CProfile profile;

   for(int i=0; i<copied; i++)
   {
      datetime ny_time=ServerToNY(rates[i].time);
      string key=(mode=="W") ? WeekKey(ny_time) : MonthKey(ny_time);
      if(key!=active_key)
      {
         if(active_key!="" && !profile.IsEmpty())
         {
            DrawProfile(profile,mode+"_"+active_key);
         }
         active_key=key;
         string title;
         if(mode=="W")
            title="Weekly "+active_key;
         else
            title="Monthly "+active_key;
         profile.Reset(active_key,title,rates[i].time,rates[i].time,clr);
      }
      profile.end_time=rates[i].time+PeriodSeconds(InpSourceTimeframe);
      profile.AddBar(rates[i].low,rates[i].high,BracketIndex(ny_time,0));
   }

   if(active_key!="" && !profile.IsEmpty())
      DrawProfile(profile,mode+"_"+active_key);
}

bool GetRTHKey(const datetime ny_time,string &key)
{
   int tod=MinutesOfDay(ny_time);
   int start=RTHStartMinutes();
   int end=InpRTHEndHour*60+InpRTHEndMinute;
   if(tod>=start && tod<end)
   {
      key=DateKey(ny_time);
      return(true);
   }
   return(false);
}

bool GetOvernightKey(const datetime ny_time,string &key)
{
   int tod=MinutesOfDay(ny_time);
   int eth_start=InpETHStartHour*60+InpETHStartMinute;
   int rth_start=RTHStartMinutes();
   if(tod>=eth_start || tod<rth_start)
   {
      datetime session_date=ny_time;
      if(tod>=eth_start)
         session_date=ny_time+86400;
      key=DateKey(session_date);
      return(true);
   }
   return(false);
}

bool GetFullETHKey(const datetime ny_time,string &key)
{
   int tod=MinutesOfDay(ny_time);
   int eth_start=InpETHStartHour*60+InpETHStartMinute;
   int eth_end=InpETHEndHour*60+InpETHEndMinute;
   bool in_session=(eth_start<eth_end) ? (tod>=eth_start && tod<eth_end) : (tod>=eth_start || tod<eth_end);
   if(in_session)
   {
      datetime session_date=ny_time;
      if(tod>=eth_start)
         session_date=ny_time+86400;
      key=DateKey(session_date);
      return(true);
   }
   return(false);
}

int BracketIndex(const datetime ny_time,const int session_start_minutes)
{
   int tod=MinutesOfDay(ny_time);
   int delta=tod-session_start_minutes;
   if(delta<0)
      delta+=1440;
   return(delta/MathMax(1,InpBracketMinutes));
}

int RTHStartMinutes()
{
   return(InpRTHStartHour*60+InpRTHStartMinute);
}

datetime ServerToNY(const datetime server_time)
{
   return(server_time+(datetime)InpServerToNewYorkMinutes*60);
}

int MinutesOfDay(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t,dt);
   return(dt.hour*60+dt.min);
}

string DateKey(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t,dt);
   return(StringFormat("%04d.%02d.%02d",dt.year,dt.mon,dt.day));
}

string MonthKey(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t,dt);
   return(StringFormat("%04d.%02d",dt.year,dt.mon));
}

string WeekKey(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t,dt);
   int dow=dt.day_of_week;
   int shift=(dow==0 ? 6 : dow-1);
   datetime monday=t-(datetime)shift*86400;
   return(DateKey(monday));
}

void DrawProfile(CProfile &profile,const string suffix)
{
   if(profile.IsEmpty())
      return;

   int max_count=profile.MaxCount();
   if(max_count<=0)
      return;

   int poc_idx=profile.POCIndex();
   int va_low_idx=0;
   int va_high_idx=ArraySize(profile.counts)-1;
   CalculateValueArea(profile,poc_idx,va_low_idx,va_high_idx);

   int period_sec=PeriodSeconds(_Period);
   if(period_sec<=0)
      period_sec=60;
   datetime x0=profile.end_time+(datetime)InpRightShiftBars*period_sec;
   int width_sec=InpProfileWidthBars*period_sec;

   for(int i=0; i<ArraySize(profile.counts); i++)
   {
      int count=profile.counts[i];
      if(count<=0)
         continue;

      double price1=NormalizeDouble((profile.row_min+i)*g_step,g_digits);
      double price2=NormalizeDouble(price1+g_step,g_digits);
      int row_width=(int)MathMax(period_sec,(double)width_sec*(double)count/(double)max_count);
      datetime x1=x0+(datetime)row_width;
      color row_color=profile.profile_color;
      if(i==poc_idx)
         row_color=InpPOCColor;
      else if(i>=va_low_idx && i<=va_high_idx)
         row_color=BlendColor(profile.profile_color,InpVAColor,0.45);

      string obj=PREFIX+suffix+"_ROW_"+(string)i;
      ObjectCreate(0,obj,OBJ_RECTANGLE,0,x0,price1,x1,price2);
      ObjectSetInteger(0,obj,OBJPROP_COLOR,ColorToARGB(row_color,InpTransparency));
      ObjectSetInteger(0,obj,OBJPROP_FILL,true);
      ObjectSetInteger(0,obj,OBJPROP_BACK,true);
      ObjectSetInteger(0,obj,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,obj,OBJPROP_HIDDEN,true);

      if(InpShowTpoLetters && count<=80)
         DrawLetters(profile,suffix,i,x1,price1,price2);
   }

   if(InpShowSummaryLevels)
      DrawSummary(profile,suffix,x0,x0+(datetime)width_sec,poc_idx,va_low_idx,va_high_idx);
   if(InpShowProfileLabels)
      DrawProfileLabel(profile,suffix,x0,x0+(datetime)width_sec);
}

void CalculateValueArea(CProfile &profile,const int poc_idx,int &va_low_idx,int &va_high_idx)
{
   int size=ArraySize(profile.counts);
   if(size<=0 || poc_idx<0)
      return;

   int target=(int)MathCeil((double)profile.TotalTPO()*(double)MathMax(1,MathMin(100,InpValueAreaPercent))/100.0);
   int total=profile.counts[poc_idx];
   va_low_idx=poc_idx;
   va_high_idx=poc_idx;

   while(total<target && (va_low_idx>0 || va_high_idx<size-1))
   {
      int below=(va_low_idx>0) ? profile.counts[va_low_idx-1] : -1;
      int above=(va_high_idx<size-1) ? profile.counts[va_high_idx+1] : -1;
      if(above>=below)
      {
         va_high_idx++;
         total+=profile.counts[va_high_idx];
      }
      else
      {
         va_low_idx--;
         total+=profile.counts[va_low_idx];
      }
   }
}

void DrawLetters(CProfile &profile,const string suffix,const int idx,const datetime x,const double price1,const double price2)
{
   string letters="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
   string txt="";
   ulong mask=profile.masks[idx];
   int max_letters=(int)MathMin(StringLen(letters),64);
   for(int b=0; b<max_letters; b++)
   {
      ulong bit=(ulong)1 << b;
      if((mask & bit)!=0)
         txt+=StringSubstr(letters,b,1);
   }
   if(txt=="")
      return;

   string obj=PREFIX+suffix+"_TXT_"+(string)idx;
   ObjectCreate(0,obj,OBJ_TEXT,0,x+(datetime)PeriodSeconds(_Period),price1+(price2-price1)/2.0);
   ObjectSetString(0,obj,OBJPROP_TEXT,txt);
   ObjectSetString(0,obj,OBJPROP_FONT,"Consolas");
   ObjectSetInteger(0,obj,OBJPROP_FONTSIZE,7);
   ObjectSetInteger(0,obj,OBJPROP_COLOR,InpTextColor);
   ObjectSetInteger(0,obj,OBJPROP_ANCHOR,ANCHOR_LEFT);
   ObjectSetInteger(0,obj,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,obj,OBJPROP_HIDDEN,true);
}

void DrawSummary(CProfile &profile,const string suffix,const datetime x0,const datetime x1,const int poc_idx,const int va_low_idx,const int va_high_idx)
{
   double poc_price=NormalizeDouble((profile.row_min+poc_idx)*g_step+g_step/2.0,g_digits);
   double vah_price=NormalizeDouble((profile.row_min+va_high_idx)*g_step+g_step,g_digits);
   double val_price=NormalizeDouble((profile.row_min+va_low_idx)*g_step,g_digits);
   DrawTrendLine(PREFIX+suffix+"_POC",x0,poc_price,x1,poc_price,InpPOCColor,2);
   DrawTrendLine(PREFIX+suffix+"_VAH",x0,vah_price,x1,vah_price,InpVAColor,1);
   DrawTrendLine(PREFIX+suffix+"_VAL",x0,val_price,x1,val_price,InpVAColor,1);
   DrawLevelText(PREFIX+suffix+"_POC_TXT","POC "+DoubleToString(poc_price,g_digits),x1,poc_price,InpPOCColor);
   DrawLevelText(PREFIX+suffix+"_VAH_TXT","VAH "+DoubleToString(vah_price,g_digits),x1,vah_price,InpVAColor);
   DrawLevelText(PREFIX+suffix+"_VAL_TXT","VAL "+DoubleToString(val_price,g_digits),x1,val_price,InpVAColor);
}

void DrawTrendLine(const string name,const datetime t1,const double p1,const datetime t2,const double p2,const color clr,const int width)
{
   ObjectCreate(0,name,OBJ_TREND,0,t1,p1,t2,p2);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void DrawLevelText(const string name,const string text,const datetime t,const double price,const color clr)
{
   ObjectCreate(0,name,OBJ_TEXT,0,t+(datetime)PeriodSeconds(_Period),price);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void DrawProfileLabel(CProfile &profile,const string suffix,const datetime x0,const datetime x1)
{
   double top=NormalizeDouble((profile.row_max+1)*g_step,g_digits);
   string obj=PREFIX+suffix+"_LABEL";
   ObjectCreate(0,obj,OBJ_TEXT,0,x0,top+g_step);
   ObjectSetString(0,obj,OBJPROP_TEXT,profile.title+" TPO="+(string)profile.TotalTPO());
   ObjectSetInteger(0,obj,OBJPROP_COLOR,profile.profile_color);
   ObjectSetInteger(0,obj,OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,obj,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0,obj,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,obj,OBJPROP_HIDDEN,true);
}

color BlendColor(const color a,const color b,const double ratio)
{
   int ar=(int)(a & 0xFF);
   int ag=(int)((a >> 8) & 0xFF);
   int ab=(int)((a >> 16) & 0xFF);
   int br=(int)(b & 0xFF);
   int bg=(int)((b >> 8) & 0xFF);
   int bb=(int)((b >> 16) & 0xFF);
   double r=MathMax(0.0,MathMin(1.0,ratio));
   int rr=(int)MathRound(ar*(1.0-r)+br*r);
   int rg=(int)MathRound(ag*(1.0-r)+bg*r);
   int rb=(int)MathRound(ab*(1.0-r)+bb*r);
   return((color)(rr | (rg << 8) | (rb << 16)));
}

void DeleteAllObjects()
{
   for(int i=ObjectsTotal(0,0,-1)-1; i>=0; i--)
   {
      string name=ObjectName(0,i,0,-1);
      if(StringFind(name,PREFIX)==0)
         ObjectDelete(0,name);
   }
}
//+------------------------------------------------------------------+
