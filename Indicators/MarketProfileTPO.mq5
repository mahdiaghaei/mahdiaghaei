//+------------------------------------------------------------------+
//|                                             MarketProfileTPO.mq5 |
//|                 TPO Market Profile for MetaTrader 5              |
//+------------------------------------------------------------------+
#property copyright "OpenAI"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//--- profile visibility
enum ENUM_PROFILE_SCOPE
  {
   SCOPE_DAILY=0,       // Daily only
   SCOPE_WEEKLY=1,      // Weekly only
   SCOPE_MONTHLY=2,     // Monthly only
   SCOPE_ALL=3          // Daily + Weekly + Monthly
  };

enum ENUM_DAILY_SESSION
  {
   DAILY_RTH=0,         // RTH only
   DAILY_ETH=1,         // ETH / overnight only
   DAILY_ETH_RTH=2      // ETH and RTH separately
  };

input ENUM_PROFILE_SCOPE  ProfileScope        = SCOPE_ALL;       // Profile scope
input ENUM_DAILY_SESSION  DailySessions       = DAILY_ETH_RTH;   // Daily session profiles
input int                 MaxBarsToProcess    = 2500;            // Maximum bars to process
input int                 TpoMinutes          = 30;              // TPO letter period, minutes
input double              RowSizeInTicks      = 4.0;             // Price row size, ticks
input bool                ShowValueArea       = true;            // Highlight 70% value area rows
input double              ValueAreaPercent    = 70.0;            // Value area percentage
input bool                ShowPOC             = true;            // Highlight point of control
input bool                ShowLabels          = true;            // Show profile labels
input int                 MaxTextPerRow       = 42;              // Max visible TPO letters per row

//--- US/New York session settings, expressed in New York clock time
input int                 RTHStartHourNY      = 9;               // RTH start hour NY
input int                 RTHStartMinuteNY    = 30;              // RTH start minute NY
input int                 RTHEndHourNY        = 16;              // RTH end hour NY
input int                 RTHEndMinuteNY      = 0;               // RTH end minute NY
input int                 ETHStartHourNY      = 18;              // ETH evening start hour NY
input int                 ETHStartMinuteNY    = 0;               // ETH evening start minute NY
input int                 ETHEndHourNY        = 9;               // ETH morning end hour NY
input int                 ETHEndMinuteNY      = 30;              // ETH morning end minute NY
input bool                SkipWeekendProfiles = true;            // Skip Saturday/Sunday daily profiles

//--- rendering
input int                 DailyOffsetBars     = 8;               // Daily profile horizontal offset, bars
input int                 WeeklyOffsetBars    = 68;              // Weekly profile horizontal offset, bars
input int                 MonthlyOffsetBars   = 138;             // Monthly profile horizontal offset, bars
input int                 RowTextStepBars     = 1;               // One text column equals this many bars
input int                 FontSize            = 8;               // TPO font size
input string              FontName            = "Consolas";      // TPO font
input color               RTHColor            = clrDodgerBlue;   // Daily RTH TPO color
input color               ETHColor            = clrDarkOrange;   // Daily ETH TPO color
input color               WeeklyColor         = clrMediumSeaGreen;// Weekly TPO color
input color               MonthlyColor        = clrMediumPurple; // Monthly TPO color
input color               POCColor            = clrRed;          // POC color
input color               ValueAreaColor      = clrGold;         // Value area color
input color               LabelColor          = clrSilver;       // Label color

#define PREFIX "MP_TPO_"
#define LETTERS "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

struct SRow
  {
   long              index;
   string            letters;
   int               count;
   bool              value_area;
  };

struct SProfile
  {
   string            key;
   string            title;
   int               kind;          // 0 daily RTH, 1 daily ETH, 2 weekly, 3 monthly
   datetime          first_time;
   datetime          last_time;
   int               first_slot;
   SRow              rows[];
  };

SProfile g_profiles[];
datetime g_last_redraw=0;

//+------------------------------------------------------------------+
int OnInit()
  {
   IndicatorSetString(INDICATOR_SHORTNAME,"Market Profile TPO (ETH/RTH/W/M)");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DeleteProfileObjects();
  }

//+------------------------------------------------------------------+
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
   if(rates_total<=0)
      return(rates_total);

   BuildProfiles(rates_total,time,high,low);
   DrawProfiles(time,rates_total);
   return(rates_total);
  }

//+------------------------------------------------------------------+
void BuildProfiles(const int rates_total,
                   const datetime &time[],
                   const double &high[],
                   const double &low[])
  {
   ArrayResize(g_profiles,0);
   bool as_series=ArrayGetAsSeries(time);
   int bars=MathMin(rates_total,MaxBarsToProcess);
   int first=(as_series ? bars-1 : rates_total-bars);
   int last=(as_series ? 0 : rates_total-1);
   int step=(as_series ? -1 : 1);

   for(int i=first;(as_series ? i>=last : i<=last);i+=step)
     {
      datetime bar_time=time[i];
      datetime ny_time=ServerToNewYork(bar_time);
      MqlDateTime ny;
      TimeToStruct(ny_time,ny);

      if(ProfileScope==SCOPE_DAILY || ProfileScope==SCOPE_ALL)
         AddDailyBar(bar_time,ny_time,ny,high[i],low[i]);

      if(ProfileScope==SCOPE_WEEKLY || ProfileScope==SCOPE_ALL)
        {
         string week_key=WeekKey(ny_time);
         string week_title="W " + week_key;
         AddBarToProfile(week_key,week_title,2,bar_time,high[i],low[i]);
        }

      if(ProfileScope==SCOPE_MONTHLY || ProfileScope==SCOPE_ALL)
        {
         string month_key=StringFormat("M-%04d-%02d",ny.year,ny.mon);
         string month_title=StringFormat("M %04d-%02d",ny.year,ny.mon);
         AddBarToProfile(month_key,month_title,3,bar_time,high[i],low[i]);
        }
     }

   for(int p=0;p<ArraySize(g_profiles);p++)
      CalculateValueArea(p);
  }

//+------------------------------------------------------------------+
void AddDailyBar(datetime server_time,datetime ny_time,MqlDateTime &ny,double high_price,double low_price)
  {
   int minutes=ny.hour*60+ny.min;
   int rth_start=RTHStartHourNY*60+RTHStartMinuteNY;
   int rth_end=RTHEndHourNY*60+RTHEndMinuteNY;
   int eth_start=ETHStartHourNY*60+ETHStartMinuteNY;
   int eth_end=ETHEndHourNY*60+ETHEndMinuteNY;

   bool in_rth=(minutes>=rth_start && minutes<rth_end);
   bool in_eth=false;

   if(eth_start>eth_end)
      in_eth=(minutes>=eth_start || minutes<eth_end);
   else
      in_eth=(minutes>=eth_start && minutes<eth_end);

   if(in_rth && (DailySessions==DAILY_RTH || DailySessions==DAILY_ETH_RTH))
     {
      if(SkipWeekendProfiles && (ny.day_of_week==0 || ny.day_of_week==6))
         return;

      string key=StringFormat("D-RTH-%04d-%02d-%02d",ny.year,ny.mon,ny.day);
      string title=StringFormat("RTH %04d-%02d-%02d",ny.year,ny.mon,ny.day);
      AddBarToProfile(key,title,0,server_time,high_price,low_price);
      return;
     }

   if(in_eth && (DailySessions==DAILY_ETH || DailySessions==DAILY_ETH_RTH))
     {
      MqlDateTime trade_date=ny;
      if(minutes>=eth_start)
        {
         datetime next_day=ny_time+86400;
         TimeToStruct(next_day,trade_date);
        }

      if(SkipWeekendProfiles && (trade_date.day_of_week==0 || trade_date.day_of_week==6))
         return;

      string key=StringFormat("D-ETH-%04d-%02d-%02d",trade_date.year,trade_date.mon,trade_date.day);
      string title=StringFormat("ETH %04d-%02d-%02d",trade_date.year,trade_date.mon,trade_date.day);
      AddBarToProfile(key,title,1,server_time,high_price,low_price);
     }
  }

//+------------------------------------------------------------------+
void AddBarToProfile(string key,string title,int kind,datetime bar_time,double high_price,double low_price)
  {
   int p=FindOrCreateProfile(key,title,kind,bar_time);
   if(bar_time<g_profiles[p].first_time)
      g_profiles[p].first_time=bar_time;
   if(bar_time>g_profiles[p].last_time)
      g_profiles[p].last_time=bar_time;

   int slot=(int)((bar_time-g_profiles[p].first_time)/(MathMax(1,TpoMinutes)*60));
   if(slot<0)
      slot=0;
   int letter_index=slot%StringLen(LETTERS);
   string letter=StringSubstr(LETTERS,letter_index,1);

   double row_size=PriceRowSize();
   long first_row=(long)MathFloor(low_price/row_size);
   long last_row=(long)MathFloor(high_price/row_size);
   for(long row=first_row;row<=last_row;row++)
      AddLetterToRow(p,row,letter);
  }

//+------------------------------------------------------------------+
int FindOrCreateProfile(string key,string title,int kind,datetime first_time)
  {
   for(int i=0;i<ArraySize(g_profiles);i++)
     {
      if(g_profiles[i].key==key)
         return(i);
     }

   int n=ArraySize(g_profiles);
   ArrayResize(g_profiles,n+1);
   g_profiles[n].key=key;
   g_profiles[n].title=title;
   g_profiles[n].kind=kind;
   g_profiles[n].first_time=first_time;
   g_profiles[n].last_time=first_time;
   g_profiles[n].first_slot=0;
   ArrayResize(g_profiles[n].rows,0);
   return(n);
  }

//+------------------------------------------------------------------+
void AddLetterToRow(int profile_index,long row_index,string letter)
  {
   int r=FindOrCreateRow(profile_index,row_index);
   if(StringFind(g_profiles[profile_index].rows[r].letters,letter)<0)
     {
      g_profiles[profile_index].rows[r].letters+=letter;
      g_profiles[profile_index].rows[r].count++;
     }
  }

//+------------------------------------------------------------------+
int FindOrCreateRow(int profile_index,long row_index)
  {
   int size=ArraySize(g_profiles[profile_index].rows);
   for(int i=0;i<size;i++)
     {
      if(g_profiles[profile_index].rows[i].index==row_index)
         return(i);
     }

   ArrayResize(g_profiles[profile_index].rows,size+1);
   g_profiles[profile_index].rows[size].index=row_index;
   g_profiles[profile_index].rows[size].letters="";
   g_profiles[profile_index].rows[size].count=0;
   g_profiles[profile_index].rows[size].value_area=false;
   return(size);
  }

//+------------------------------------------------------------------+
void CalculateValueArea(int profile_index)
  {
   int row_count=ArraySize(g_profiles[profile_index].rows);
   if(row_count<=0)
      return;

   SortRows(profile_index);

   int poc=POCRow(profile_index);
   int total=0;
   for(int i=0;i<row_count;i++)
     {
      total+=g_profiles[profile_index].rows[i].count;
      g_profiles[profile_index].rows[i].value_area=false;
     }

   int target=(int)MathCeil(total*MathMax(1.0,MathMin(100.0,ValueAreaPercent))/100.0);
   int collected=g_profiles[profile_index].rows[poc].count;
   g_profiles[profile_index].rows[poc].value_area=true;

   int upper=poc+1;
   int lower=poc-1;
   while(collected<target && (upper<row_count || lower>=0))
     {
      int upper_count=(upper<row_count ? g_profiles[profile_index].rows[upper].count : -1);
      int lower_count=(lower>=0 ? g_profiles[profile_index].rows[lower].count : -1);

      if(upper_count>=lower_count)
        {
         if(upper<row_count)
           {
            g_profiles[profile_index].rows[upper].value_area=true;
            collected+=g_profiles[profile_index].rows[upper].count;
            upper++;
           }
         else
            lower_count=999999;
        }
      else
        {
         if(lower>=0)
           {
            g_profiles[profile_index].rows[lower].value_area=true;
            collected+=g_profiles[profile_index].rows[lower].count;
            lower--;
           }
        }
     }
  }

//+------------------------------------------------------------------+
int POCRow(int profile_index)
  {
   int poc=0;
   int max_count=-1;
   int row_count=ArraySize(g_profiles[profile_index].rows);
   for(int i=0;i<row_count;i++)
     {
      if(g_profiles[profile_index].rows[i].count>max_count)
        {
         max_count=g_profiles[profile_index].rows[i].count;
         poc=i;
        }
     }
   return(poc);
  }

//+------------------------------------------------------------------+
void SortRows(int profile_index)
  {
   int n=ArraySize(g_profiles[profile_index].rows);
   for(int i=1;i<n;i++)
     {
      SRow current=g_profiles[profile_index].rows[i];
      int j=i-1;
      while(j>=0 && g_profiles[profile_index].rows[j].index>current.index)
        {
         g_profiles[profile_index].rows[j+1]=g_profiles[profile_index].rows[j];
         j--;
        }
      g_profiles[profile_index].rows[j+1]=current;
     }
  }

//+------------------------------------------------------------------+
void DrawProfiles(const datetime &time[],const int rates_total)
  {
   DeleteProfileObjects();
   bool as_series=ArrayGetAsSeries(time);
   datetime anchor=(as_series ? time[0] : time[rates_total-1]);
   int period_seconds=PeriodSeconds(_Period);
   if(period_seconds<=0)
      period_seconds=60;

   for(int p=0;p<ArraySize(g_profiles);p++)
     {
      int rows=ArraySize(g_profiles[p].rows);
      if(rows<=0)
         continue;

      int offset=OffsetForKind(g_profiles[p].kind);
      datetime profile_anchor=anchor + offset*period_seconds;
      int poc=POCRow(p);
      color base=ColorForKind(g_profiles[p].kind);

      if(ShowLabels)
        {
         double label_price=g_profiles[p].rows[rows-1].index*PriceRowSize()+PriceRowSize();
         DrawText(g_profiles[p].key+"_LABEL",profile_anchor,label_price,g_profiles[p].title,LabelColor,FontSize+1);
        }

      for(int r=0;r<rows;r++)
        {
         string letters=g_profiles[p].rows[r].letters;
         if(StringLen(letters)>MaxTextPerRow)
            letters=StringSubstr(letters,0,MaxTextPerRow)+"...";

         color row_color=base;
         if(ShowValueArea && g_profiles[p].rows[r].value_area)
            row_color=ValueAreaColor;
         if(ShowPOC && r==poc)
            row_color=POCColor;

         double price=g_profiles[p].rows[r].index*PriceRowSize();
         datetime text_time=profile_anchor + (StringLen(letters)*RowTextStepBars*period_seconds/2);
         DrawText(g_profiles[p].key+"_"+(string)g_profiles[p].rows[r].index,text_time,price,letters,row_color,FontSize);
        }
     }
  }

//+------------------------------------------------------------------+
void DrawText(string suffix,datetime when,double price,string text,color clr,int size)
  {
   string name=PREFIX+suffix;
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_TEXT,0,when,price);
   ObjectSetInteger(0,name,OBJPROP_TIME,when);
   ObjectSetDouble(0,name,OBJPROP_PRICE,price);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,FontName);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

//+------------------------------------------------------------------+
void DeleteProfileObjects()
  {
   int total=ObjectsTotal(0,0,-1);
   for(int i=total-1;i>=0;i--)
     {
      string name=ObjectName(0,i,0,-1);
      if(StringFind(name,PREFIX)==0)
         ObjectDelete(0,name);
     }
  }

//+------------------------------------------------------------------+
int OffsetForKind(int kind)
  {
   if(kind==2)
      return(WeeklyOffsetBars);
   if(kind==3)
      return(MonthlyOffsetBars);
   return(DailyOffsetBars + kind*28);
  }

//+------------------------------------------------------------------+
color ColorForKind(int kind)
  {
   if(kind==0)
      return(RTHColor);
   if(kind==1)
      return(ETHColor);
   if(kind==2)
      return(WeeklyColor);
   return(MonthlyColor);
  }

//+------------------------------------------------------------------+
double PriceRowSize()
  {
   return(MathMax(_Point,RowSizeInTicks*_Point));
  }

//+------------------------------------------------------------------+
datetime ServerToNewYork(datetime server_time)
  {
   datetime gmt=server_time-(TimeCurrent()-TimeGMT());
   return(gmt+NewYorkUtcOffsetSeconds(gmt));
  }

//+------------------------------------------------------------------+
int NewYorkUtcOffsetSeconds(datetime gmt_time)
  {
   MqlDateTime gmt;
   TimeToStruct(gmt_time,gmt);

   datetime dst_start=UsDstStartUtc(gmt.year);
   datetime dst_end=UsDstEndUtc(gmt.year);
   if(gmt_time>=dst_start && gmt_time<dst_end)
      return(-4*3600);
   return(-5*3600);
  }

//+------------------------------------------------------------------+
datetime UsDstStartUtc(int year)
  {
   // US DST starts at 02:00 local New York time, second Sunday in March.
   return(NthWeekdayUtc(year,3,0,2,7));
  }

//+------------------------------------------------------------------+
datetime UsDstEndUtc(int year)
  {
   // US DST ends at 02:00 local New York time, first Sunday in November.
   return(NthWeekdayUtc(year,11,0,1,6));
  }

//+------------------------------------------------------------------+
datetime NthWeekdayUtc(int year,int month,int weekday,int nth,int utc_hour)
  {
   MqlDateTime dt;
   dt.year=year;
   dt.mon=month;
   dt.day=1;
   dt.hour=utc_hour;
   dt.min=0;
   dt.sec=0;
   datetime first=StructToTime(dt);
   MqlDateTime first_struct;
   TimeToStruct(first,first_struct);
   int delta=(weekday-first_struct.day_of_week+7)%7;
   dt.day=1+delta+(nth-1)*7;
   return(StructToTime(dt));
  }

//+------------------------------------------------------------------+
string WeekKey(datetime ny_time)
  {
   MqlDateTime ny;
   TimeToStruct(ny_time,ny);
   datetime monday=ny_time-(ny.day_of_week==0 ? 6 : ny.day_of_week-1)*86400;
   MqlDateTime wk;
   TimeToStruct(monday,wk);
   return(StringFormat("W-%04d-%02d-%02d",wk.year,wk.mon,wk.day));
  }
//+------------------------------------------------------------------+
