//+------------------------------------------------------------------+
//|                                                MarketProfile.mq5  |
//|                       Session Market Profile indicator for MT5    |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_plots 0

input int    DaysToShow          = 5;        // Number of calendar days/sessions to draw
input int    SessionStartHour    = 0;        // Session start hour (broker time)
input int    SessionStartMinute  = 0;        // Session start minute
input int    SessionEndHour      = 23;       // Session end hour (broker time)
input int    SessionEndMinute    = 59;       // Session end minute
input int    PointsPerPriceStep  = 10;       // Price bucket size in points
input int    MaxProfileRows      = 180;      // Maximum rows per profile
input bool   UseVisibleChartTime = true;     // Anchor profiles to visible chart/tester time
input double ValueAreaPercent    = 70.0;     // Value area percentage
input double MaxWidthPercent     = 55.0;     // Maximum histogram width as % of session
input bool   ShowPOC             = true;     // Show point of control
input bool   ShowValueArea       = true;     // Show VAH and VAL
input bool   ShowLabels          = true;     // Show text labels
input color  ProfileColor        = clrSteelBlue;
input color  ValueAreaColor      = clrDodgerBlue;
input color  POCColor            = clrTomato;
input color  TextColor           = clrWhite;

string ObjectPrefix = "MP5_";

//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "Market Profile (Session TPO)");
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
   if(rates_total < 10)
      return(rates_total);

   DeleteProfileObjects();
   DrawProfiles(time, high, low, rates_total);
   ChartRedraw(0);

   return(rates_total);
}

//+------------------------------------------------------------------+
void DrawProfiles(const datetime &time[], const double &high[], const double &low[], const int rates_total)
{
   datetime anchor_time = GetProfileAnchorTime(time, rates_total);
   datetime anchor_session_day = GetAnchorSessionDay(anchor_time);

   for(int day = 0; day < DaysToShow; day++)
   {
      datetime session_day = anchor_session_day - (day * 86400);
      datetime session_start = session_day + (SessionStartHour * 3600) + (SessionStartMinute * 60);
      datetime session_end = session_day + (SessionEndHour * 3600) + (SessionEndMinute * 60);

      if(session_end <= session_start)
         session_end += 86400;

      BuildSessionProfile(day, session_start, session_end, time, high, low, rates_total);
   }
}

//+------------------------------------------------------------------+
datetime GetProfileAnchorTime(const datetime &time[], const int rates_total)
{
   datetime anchor_time = LatestBarTime(time, rates_total);

   if(!UseVisibleChartTime)
      return(anchor_time);

   long first_visible_bar = 0;
   long bars_per_chart = 0;

   if(!ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR, 0, first_visible_bar))
      return(anchor_time);

   if(!ChartGetInteger(0, CHART_WIDTH_IN_BARS, 0, bars_per_chart))
      return(anchor_time);

   if(first_visible_bar < 0 || bars_per_chart <= 0)
      return(anchor_time);

   int right_visible_bar = (int)(first_visible_bar - bars_per_chart + 1);

   if(right_visible_bar < 0)
      right_visible_bar = 0;

   datetime visible_time = iTime(_Symbol, _Period, right_visible_bar);
   if(visible_time > 0)
      return(visible_time);

   return(anchor_time);
}

//+------------------------------------------------------------------+
datetime LatestBarTime(const datetime &time[], const int rates_total)
{
   datetime latest_time = time[0];

   for(int i = 1; i < rates_total; i++)
   {
      if(time[i] > latest_time)
         latest_time = time[i];
   }

   return(latest_time);
}

//+------------------------------------------------------------------+
datetime GetAnchorSessionDay(const datetime anchor_time)
{
   datetime anchor_day = DateStart(anchor_time);
   datetime session_start = anchor_day + (SessionStartHour * 3600) + (SessionStartMinute * 60);
   datetime session_end = anchor_day + (SessionEndHour * 3600) + (SessionEndMinute * 60);

   if(session_end <= session_start)
   {
      session_end += 86400;

      if(anchor_time < session_start && anchor_time < session_end)
         anchor_day -= 86400;
   }

   return(anchor_day);
}

//+------------------------------------------------------------------+
void BuildSessionProfile(const int session_index,
                         const datetime session_start,
                         const datetime session_end,
                         const datetime &time[],
                         const double &high[],
                         const double &low[],
                         const int rates_total)
{
   double session_high = -DBL_MAX;
   double session_low = DBL_MAX;
   int bars_in_session = 0;

   for(int i = 0; i < rates_total; i++)
   {
      if(time[i] < session_start || time[i] >= session_end)
         continue;

      session_high = MathMax(session_high, high[i]);
      session_low = MathMin(session_low, low[i]);
      bars_in_session++;
   }

   if(bars_in_session <= 0 || session_high <= session_low)
      return;

   double step = MathMax(PointsPerPriceStep * _Point, _Point);
   int rows = (int)MathFloor((session_high - session_low) / step) + 1;

   if(rows > MaxProfileRows)
   {
      rows = MaxProfileRows;
      step = (session_high - session_low) / MathMax(rows - 1, 1);
   }

   int counts[];
   ArrayResize(counts, rows);
   ArrayInitialize(counts, 0);

   int total_tpos = 0;

   for(int bar = 0; bar < rates_total; bar++)
   {
      if(time[bar] < session_start || time[bar] >= session_end)
         continue;

      int first_row = PriceToRow(low[bar], session_low, step, rows);
      int last_row = PriceToRow(high[bar], session_low, step, rows);

      for(int row = first_row; row <= last_row; row++)
      {
         counts[row]++;
         total_tpos++;
      }
   }

   if(total_tpos <= 0)
      return;

   int poc_row = FindPOC(counts, rows);
   int value_low_row = poc_row;
   int value_high_row = poc_row;

   CalculateValueArea(counts, rows, total_tpos, poc_row, value_low_row, value_high_row);
   DrawSessionObjects(session_index, session_start, session_end, session_low, step, counts,
                      rows, poc_row, value_low_row, value_high_row);
}

//+------------------------------------------------------------------+
int PriceToRow(const double price, const double base_price, const double step, const int rows)
{
   int row = (int)MathFloor((price - base_price) / step);

   if(row < 0)
      return(0);

   if(row >= rows)
      return(rows - 1);

   return(row);
}

//+------------------------------------------------------------------+
int FindPOC(const int &counts[], const int rows)
{
   int poc_row = 0;
   int poc_count = counts[0];

   for(int row = 1; row < rows; row++)
   {
      if(counts[row] > poc_count)
      {
         poc_count = counts[row];
         poc_row = row;
      }
   }

   return(poc_row);
}

//+------------------------------------------------------------------+
void CalculateValueArea(const int &counts[],
                        const int rows,
                        const int total_tpos,
                        const int poc_row,
                        int &value_low_row,
                        int &value_high_row)
{
   double target = total_tpos * MathMax(1.0, MathMin(ValueAreaPercent, 100.0)) / 100.0;
   int included = counts[poc_row];
   int lower = poc_row - 1;
   int upper = poc_row + 1;

   while(included < target && (lower >= 0 || upper < rows))
   {
      int lower_count = (lower >= 0) ? counts[lower] : -1;
      int upper_count = (upper < rows) ? counts[upper] : -1;

      if(upper_count >= lower_count)
      {
         if(upper < rows)
         {
            included += counts[upper];
            value_high_row = upper;
            upper++;
         }
         else if(lower >= 0)
         {
            included += counts[lower];
            value_low_row = lower;
            lower--;
         }
      }
      else
      {
         if(lower >= 0)
         {
            included += counts[lower];
            value_low_row = lower;
            lower--;
         }
         else if(upper < rows)
         {
            included += counts[upper];
            value_high_row = upper;
            upper++;
         }
      }
   }
}

//+------------------------------------------------------------------+
void DrawSessionObjects(const int session_index,
                        const datetime session_start,
                        const datetime session_end,
                        const double session_low,
                        const double step,
                        const int &counts[],
                        const int rows,
                        const int poc_row,
                        const int value_low_row,
                        const int value_high_row)
{
   int max_count = 0;
   for(int row = 0; row < rows; row++)
   {
      if(counts[row] > max_count)
         max_count = counts[row];
   }

   if(max_count <= 0)
      return;

   int session_seconds = (int)(session_end - session_start);
   int max_width_seconds = (int)(session_seconds * MathMax(1.0, MathMin(MaxWidthPercent, 100.0)) / 100.0);

   for(int profile_row = 0; profile_row < rows; profile_row++)
   {
      if(counts[profile_row] <= 0)
         continue;

      double price_bottom = NormalizeDouble(session_low + (profile_row * step), _Digits);
      double price_top = NormalizeDouble(price_bottom + step, _Digits);
      int width_seconds = (int)(max_width_seconds * counts[profile_row] / max_count);
      if(width_seconds < PeriodSeconds(_Period))
         width_seconds = PeriodSeconds(_Period);
      datetime row_end = session_start + width_seconds;
      color row_color = (profile_row >= value_low_row && profile_row <= value_high_row) ? ValueAreaColor : ProfileColor;

      string rectangle_name = ObjectPrefix + IntegerToString(session_index) + "_ROW_" + IntegerToString(profile_row);
      ObjectCreate(0, rectangle_name, OBJ_RECTANGLE, 0, session_start, price_bottom, row_end, price_top);
      ObjectSetInteger(0, rectangle_name, OBJPROP_COLOR, row_color);
      ObjectSetInteger(0, rectangle_name, OBJPROP_BACK, true);
      ObjectSetInteger(0, rectangle_name, OBJPROP_FILL, true);
      ObjectSetInteger(0, rectangle_name, OBJPROP_WIDTH, 1);
   }

   double poc_price = NormalizeDouble(session_low + (poc_row * step) + (step / 2.0), _Digits);
   double vah_price = NormalizeDouble(session_low + (value_high_row * step) + (step / 2.0), _Digits);
   double val_price = NormalizeDouble(session_low + (value_low_row * step) + (step / 2.0), _Digits);

   if(ShowPOC)
      DrawLevel(session_index, "POC", session_start, session_end, poc_price, POCColor, STYLE_SOLID, 2);

   if(ShowValueArea)
   {
      DrawLevel(session_index, "VAH", session_start, session_end, vah_price, ValueAreaColor, STYLE_DOT, 1);
      DrawLevel(session_index, "VAL", session_start, session_end, val_price, ValueAreaColor, STYLE_DOT, 1);
   }

   if(ShowLabels)
   {
      if(ShowPOC)
         DrawLabel(session_index, "POC_LABEL", session_end, poc_price, "POC " + DoubleToString(poc_price, _Digits), POCColor);

      if(ShowValueArea)
      {
         DrawLabel(session_index, "VAH_LABEL", session_end, vah_price, "VAH " + DoubleToString(vah_price, _Digits), TextColor);
         DrawLabel(session_index, "VAL_LABEL", session_end, val_price, "VAL " + DoubleToString(val_price, _Digits), TextColor);
      }
   }
}

//+------------------------------------------------------------------+
void DrawLevel(const int session_index,
               const string suffix,
               const datetime session_start,
               const datetime session_end,
               const double price,
               const color line_color,
               const ENUM_LINE_STYLE line_style,
               const int line_width)
{
   string name = ObjectPrefix + IntegerToString(session_index) + "_" + suffix;
   ObjectCreate(0, name, OBJ_TREND, 0, session_start, price, session_end, price);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, name, OBJPROP_STYLE, line_style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, line_width);
}

//+------------------------------------------------------------------+
void DrawLabel(const int session_index,
               const string suffix,
               const datetime label_time,
               const double price,
               const string text,
               const color label_color)
{
   string name = ObjectPrefix + IntegerToString(session_index) + "_" + suffix;
   ObjectCreate(0, name, OBJ_TEXT, 0, label_time, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_COLOR, label_color);
}

//+------------------------------------------------------------------+
datetime DateStart(const datetime source_time)
{
   return(StringToTime(TimeToString(source_time, TIME_DATE)));
}

//+------------------------------------------------------------------+
void DeleteProfileObjects()
{
   const int total_objects = ObjectsTotal(0, 0, -1);

   for(int i = total_objects - 1; i >= 0; i--)
   {
      string object_name = ObjectName(0, i, 0, -1);
      if(StringFind(object_name, ObjectPrefix) == 0)
         ObjectDelete(0, object_name);
   }
}
//+------------------------------------------------------------------+
