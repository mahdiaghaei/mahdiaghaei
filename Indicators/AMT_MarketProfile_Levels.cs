#region Using declarations
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Windows.Media;
using System.Xml.Serialization;
using NinjaTrader.Core.FloatingPoint;
using NinjaTrader.Gui.Chart;
using NinjaTrader.Gui.Tools;
using NinjaTrader.NinjaScript;
using NinjaTrader.NinjaScript.Indicators;
using SharpDX;
using D2D = SharpDX.Direct2D1;
using DW = SharpDX.DirectWrite;
#endregion

// This indicator is intentionally self-contained so it can be imported as a
// single NinjaScript file.  Helper classes are placed in the same namespace as
// the indicator for maximum NinjaTrader 8 compatibility.
namespace NinjaTrader.NinjaScript.Indicators
{
    /// <summary>
    /// AMT_MarketProfile_Levels renders Auction Market Theory, Volume Profile
    /// and VWAP reference levels directly on the chart price scale using
    /// SharpDX.  The profile engine stores volume by instrument tick price and
    /// calculates VPOC/VAH/VAL with a 70% value area.
    /// </summary>
    public class AMT_MarketProfile_Levels : Indicator
    {
        private const double ValueAreaPercent = 0.70;

        private LevelManager levelManager;
        private LabelRenderer labelRenderer;
        private VolumeProfileCalculator currentWeekProfile;
        private VolumeProfileCalculator currentMonthProfile;
        private VolumeProfileCalculator previousWeekProfile;
        private VolumeProfileCalculator previousMonthProfile;
        private VolumeProfileCalculator rolling5DayProfile;
        private VolumeProfileCalculator rolling20DayProfile;
        private VolumeProfileCalculator rolling200DayProfile;
        private VWAPCalculator weeklyVwap;
        private VWAPCalculator monthlyVwap;

        private readonly Dictionary<DateTime, VolumeProfileCalculator> sessionProfiles = new Dictionary<DateTime, VolumeProfileCalculator>();
        private readonly Queue<DateTime> sessionOrder = new Queue<DateTime>();

        private DateTime activeSessionDate = Core.Globals.MinDate;
        private DateTime activeWeekStart = Core.Globals.MinDate;
        private DateTime activeMonthStart = Core.Globals.MinDate;
        private double currentWeekHigh = double.MinValue;
        private double currentWeekLow = double.MaxValue;
        private double currentMonthHigh = double.MinValue;
        private double currentMonthLow = double.MaxValue;
        private double previousWeekHigh = double.NaN;
        private double previousWeekLow = double.NaN;
        private double previousMonthHigh = double.NaN;
        private double previousMonthLow = double.NaN;

        private readonly List<LevelDefinition> renderSnapshot = new List<LevelDefinition>();

        #region User settings
        [NinjaScriptProperty]
        [Display(Name = "Show Previous Week Levels", GroupName = "Visibility", Order = 0)]
        public bool ShowPreviousWeekLevels { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Show Previous Month Levels", GroupName = "Visibility", Order = 1)]
        public bool ShowPreviousMonthLevels { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Show Weekly Profile", GroupName = "Visibility", Order = 2)]
        public bool ShowWeeklyProfile { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Show Monthly Profile", GroupName = "Visibility", Order = 3)]
        public bool ShowMonthlyProfile { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Show VWAP Levels", GroupName = "Visibility", Order = 4)]
        public bool ShowVwapLevels { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Show VPOCs", GroupName = "Visibility", Order = 5)]
        public bool ShowVpocs { get; set; }

        [NinjaScriptProperty]
        [Range(6, 36)]
        [Display(Name = "Label Font Size", GroupName = "Style", Order = 10)]
        public int LabelFontSize { get; set; }

        [NinjaScriptProperty]
        [Range(1, 10)]
        [Display(Name = "Line Width", GroupName = "Style", Order = 11)]
        public int LineWidth { get; set; }

        [Display(Name = "Line Style", GroupName = "Style", Order = 12)]
        public DashStyleHelper LineStyle { get; set; }

        [XmlIgnore]
        [Display(Name = "Previous Week Background", GroupName = "Colors", Order = 20)]
        public Brush PreviousWeekBackground { get; set; }
        [Browsable(false)]
        public string PreviousWeekBackgroundSerializable { get { return Serialize.BrushToString(PreviousWeekBackground); } set { PreviousWeekBackground = Serialize.StringToBrush(value); } }

        [XmlIgnore]
        [Display(Name = "Previous Month Background", GroupName = "Colors", Order = 21)]
        public Brush PreviousMonthBackground { get; set; }
        [Browsable(false)]
        public string PreviousMonthBackgroundSerializable { get { return Serialize.BrushToString(PreviousMonthBackground); } set { PreviousMonthBackground = Serialize.StringToBrush(value); } }

        [XmlIgnore]
        [Display(Name = "Weekly VWAP Background", GroupName = "Colors", Order = 22)]
        public Brush WeeklyVwapBackground { get; set; }
        [Browsable(false)]
        public string WeeklyVwapBackgroundSerializable { get { return Serialize.BrushToString(WeeklyVwapBackground); } set { WeeklyVwapBackground = Serialize.StringToBrush(value); } }

        [XmlIgnore]
        [Display(Name = "Monthly VWAP Background", GroupName = "Colors", Order = 23)]
        public Brush MonthlyVwapBackground { get; set; }
        [Browsable(false)]
        public string MonthlyVwapBackgroundSerializable { get { return Serialize.BrushToString(MonthlyVwapBackground); } set { MonthlyVwapBackground = Serialize.StringToBrush(value); } }

        [XmlIgnore]
        [Display(Name = "5-Day VPOC Background", GroupName = "Colors", Order = 24)]
        public Brush FiveDayVpocBackground { get; set; }
        [Browsable(false)]
        public string FiveDayVpocBackgroundSerializable { get { return Serialize.BrushToString(FiveDayVpocBackground); } set { FiveDayVpocBackground = Serialize.StringToBrush(value); } }

        [XmlIgnore]
        [Display(Name = "20-Day VPOC Background", GroupName = "Colors", Order = 25)]
        public Brush TwentyDayVpocBackground { get; set; }
        [Browsable(false)]
        public string TwentyDayVpocBackgroundSerializable { get { return Serialize.BrushToString(TwentyDayVpocBackground); } set { TwentyDayVpocBackground = Serialize.StringToBrush(value); } }

        [XmlIgnore]
        [Display(Name = "200-Day VPOC Background", GroupName = "Colors", Order = 26)]
        public Brush TwoHundredDayVpocBackground { get; set; }
        [Browsable(false)]
        public string TwoHundredDayVpocBackgroundSerializable { get { return Serialize.BrushToString(TwoHundredDayVpocBackground); } set { TwoHundredDayVpocBackground = Serialize.StringToBrush(value); } }

        [XmlIgnore]
        [Display(Name = "Previous Week High/Low Background", GroupName = "Colors", Order = 27)]
        public Brush PreviousWeekHighLowBackground { get; set; }
        [Browsable(false)]
        public string PreviousWeekHighLowBackgroundSerializable { get { return Serialize.BrushToString(PreviousWeekHighLowBackground); } set { PreviousWeekHighLowBackground = Serialize.StringToBrush(value); } }

        [XmlIgnore]
        [Display(Name = "Previous Month High/Low Background", GroupName = "Colors", Order = 28)]
        public Brush PreviousMonthHighLowBackground { get; set; }
        [Browsable(false)]
        public string PreviousMonthHighLowBackgroundSerializable { get { return Serialize.BrushToString(PreviousMonthHighLowBackground); } set { PreviousMonthHighLowBackground = Serialize.StringToBrush(value); } }

        [XmlIgnore]
        [Display(Name = "Current Week Background", GroupName = "Colors", Order = 29)]
        public Brush CurrentWeekBackground { get; set; }
        [Browsable(false)]
        public string CurrentWeekBackgroundSerializable { get { return Serialize.BrushToString(CurrentWeekBackground); } set { CurrentWeekBackground = Serialize.StringToBrush(value); } }

        [XmlIgnore]
        [Display(Name = "Current Month Background", GroupName = "Colors", Order = 30)]
        public Brush CurrentMonthBackground { get; set; }
        [Browsable(false)]
        public string CurrentMonthBackgroundSerializable { get { return Serialize.BrushToString(CurrentMonthBackground); } set { CurrentMonthBackground = Serialize.StringToBrush(value); } }
        #endregion

        protected override void OnStateChange()
        {
            if (State == State.SetDefaults)
            {
                Description = "Professional AMT, Volume Profile and VWAP right-scale level labels.";
                Name = "AMT_MarketProfile_Levels";
                Calculate = Calculate.OnBarClose;
                IsOverlay = true;
                DisplayInDataBox = false;
                DrawOnPricePanel = true;
                PaintPriceMarkers = false;
                IsSuspendedWhileInactive = true;

                ShowPreviousWeekLevels = true;
                ShowPreviousMonthLevels = true;
                ShowWeeklyProfile = true;
                ShowMonthlyProfile = true;
                ShowVwapLevels = true;
                ShowVpocs = true;
                LabelFontSize = 12;
                LineWidth = 2;
                LineStyle = DashStyleHelper.Solid;

                PreviousWeekBackground = Brushes.DarkBlue;
                PreviousMonthBackground = Brushes.LightBlue;
                WeeklyVwapBackground = Brushes.Purple;
                MonthlyVwapBackground = Brushes.Magenta;
                FiveDayVpocBackground = Brushes.Orange;
                TwentyDayVpocBackground = Brushes.Gold;
                TwoHundredDayVpocBackground = Brushes.DarkOrange;
                PreviousWeekHighLowBackground = Brushes.Green;
                PreviousMonthHighLowBackground = Brushes.Brown;
                CurrentWeekBackground = Brushes.Cyan;
                CurrentMonthBackground = Brushes.Pink;
            }
            else if (State == State.DataLoaded)
            {
                levelManager = new LevelManager();
                labelRenderer = new LabelRenderer();
                ResetCalculators();
            }
            else if (State == State.Terminated)
            {
                if (labelRenderer != null)
                    labelRenderer.Dispose();
            }
        }

        protected override void OnBarUpdate()
        {
            if (CurrentBar < 1 || Bars == null || BarsPeriod.BarsPeriodType == BarsPeriodType.Day)
                return;

            DateTime barTime = Times[0][0];
            DateTime sessionDate = Bars.GetTradingDayFromLocal(barTime).Date;
            DateTime weekStart = GetWeekStart(sessionDate);
            DateTime monthStart = new DateTime(sessionDate.Year, sessionDate.Month, 1);

            if (activeSessionDate == Core.Globals.MinDate)
                InitializeFirstBar(sessionDate, weekStart, monthStart);

            if (sessionDate != activeSessionDate)
                StartNewSession(sessionDate);

            if (weekStart != activeWeekStart)
                StartNewWeek(weekStart);

            if (monthStart != activeMonthStart)
                StartNewMonth(monthStart);

            AddBarToProfiles();
            UpdateHighLowTrackers();
            RebuildLevels();
        }

        protected override void OnRender(ChartControl chartControl, ChartScale chartScale)
        {
            base.OnRender(chartControl, chartScale);

            if (ChartPanel == null || RenderTarget == null || labelRenderer == null || levelManager == null)
                return;

            renderSnapshot.Clear();
            renderSnapshot.AddRange(levelManager.ActiveLevels);
            labelRenderer.Render(RenderTarget, ChartPanel, chartScale, renderSnapshot, LabelFontSize, LineWidth, LineStyle);
        }

        public override void OnRenderTargetChanged()
        {
            if (labelRenderer != null)
                labelRenderer.OnRenderTargetChanged();
        }

        private void ResetCalculators()
        {
            currentWeekProfile = NewProfile();
            currentMonthProfile = NewProfile();
            previousWeekProfile = NewProfile();
            previousMonthProfile = NewProfile();
            rolling5DayProfile = NewProfile();
            rolling20DayProfile = NewProfile();
            rolling200DayProfile = NewProfile();
            weeklyVwap = new VWAPCalculator();
            monthlyVwap = new VWAPCalculator();
            sessionProfiles.Clear();
            sessionOrder.Clear();
        }

        private VolumeProfileCalculator NewProfile()
        {
            return new VolumeProfileCalculator(TickSize, ValueAreaPercent);
        }

        private void InitializeFirstBar(DateTime sessionDate, DateTime weekStart, DateTime monthStart)
        {
            activeSessionDate = sessionDate;
            activeWeekStart = weekStart;
            activeMonthStart = monthStart;
            currentWeekHigh = double.MinValue;
            currentWeekLow = double.MaxValue;
            currentMonthHigh = double.MinValue;
            currentMonthLow = double.MaxValue;
            EnsureSessionProfile(sessionDate);
        }

        private void StartNewSession(DateTime newSessionDate)
        {
            activeSessionDate = newSessionDate;
            EnsureSessionProfile(newSessionDate);
            RebuildRollingProfile(5, rolling5DayProfile);
            RebuildRollingProfile(20, rolling20DayProfile);
            RebuildRollingProfile(200, rolling200DayProfile);
        }

        private void StartNewWeek(DateTime newWeekStart)
        {
            previousWeekProfile = currentWeekProfile;
            previousWeekHigh = currentWeekHigh;
            previousWeekLow = currentWeekLow;
            currentWeekProfile = NewProfile();
            weeklyVwap = new VWAPCalculator();
            currentWeekHigh = double.MinValue;
            currentWeekLow = double.MaxValue;
            activeWeekStart = newWeekStart;
        }

        private void StartNewMonth(DateTime newMonthStart)
        {
            previousMonthProfile = currentMonthProfile;
            previousMonthHigh = currentMonthHigh;
            previousMonthLow = currentMonthLow;
            currentMonthProfile = NewProfile();
            monthlyVwap = new VWAPCalculator();
            currentMonthHigh = double.MinValue;
            currentMonthLow = double.MaxValue;
            activeMonthStart = newMonthStart;
        }

        private void EnsureSessionProfile(DateTime sessionDate)
        {
            if (sessionProfiles.ContainsKey(sessionDate))
                return;

            sessionProfiles[sessionDate] = NewProfile();
            sessionOrder.Enqueue(sessionDate);

            while (sessionOrder.Count > 220)
            {
                DateTime oldSession = sessionOrder.Dequeue();
                sessionProfiles.Remove(oldSession);
            }
        }

        private void AddBarToProfiles()
        {
            double high = High[0];
            double low = Low[0];
            double close = Close[0];
            double volume = Math.Max(0, Volume[0]);

            // NinjaTrader's standard bars do not expose historical bid/ask VAP.
            // This distributes bar volume across touched ticks so the indicator
            // works on every intraday bar type; real-time tick bars naturally add
            // actual traded volume at the traded price because High == Low/Close.
            currentWeekProfile.AddBar(low, high, close, volume);
            currentMonthProfile.AddBar(low, high, close, volume);
            sessionProfiles[activeSessionDate].AddBar(low, high, close, volume);
            rolling5DayProfile.AddBar(low, high, close, volume);
            rolling20DayProfile.AddBar(low, high, close, volume);
            rolling200DayProfile.AddBar(low, high, close, volume);
            weeklyVwap.Add(close, volume);
            monthlyVwap.Add(close, volume);
        }

        private void UpdateHighLowTrackers()
        {
            currentWeekHigh = Math.Max(currentWeekHigh, High[0]);
            currentWeekLow = Math.Min(currentWeekLow, Low[0]);
            currentMonthHigh = Math.Max(currentMonthHigh, High[0]);
            currentMonthLow = Math.Min(currentMonthLow, Low[0]);
        }

        private void RebuildRollingProfile(int sessionCount, VolumeProfileCalculator target)
        {
            target.Clear();
            foreach (DateTime sessionDate in sessionOrder.Reverse().Take(sessionCount).Reverse())
            {
                VolumeProfileCalculator profile;
                if (sessionProfiles.TryGetValue(sessionDate, out profile))
                    target.Merge(profile);
            }
        }

        private void RebuildLevels()
        {
            levelManager.Clear();

            ProfileLevels levels;
            if (ShowPreviousWeekLevels && previousWeekProfile.TryGetLevels(out levels))
            {
                AddLevel("Prev Week VAH", levels.VAH, PreviousWeekBackground, Brushes.White);
                AddLevel("Prev Week VAL", levels.VAL, PreviousWeekBackground, Brushes.White);
            }

            if (ShowPreviousMonthLevels && previousMonthProfile.TryGetLevels(out levels))
            {
                AddLevel("Prev Month VAH", levels.VAH, PreviousMonthBackground, Brushes.Black);
                AddLevel("Prev Month VAL", levels.VAL, PreviousMonthBackground, Brushes.Black);
            }

            if (ShowVpocs)
            {
                if (rolling5DayProfile.TryGetLevels(out levels))
                    AddLevel("5D VPOC", levels.VPOC, FiveDayVpocBackground, Brushes.Black);
                if (rolling20DayProfile.TryGetLevels(out levels))
                    AddLevel("20D VPOC", levels.VPOC, TwentyDayVpocBackground, Brushes.Black);
                if (rolling200DayProfile.TryGetLevels(out levels))
                    AddLevel("200D VPOC", levels.VPOC, TwoHundredDayVpocBackground, Brushes.White);
            }

            if (ShowVwapLevels)
            {
                if (weeklyVwap.IsValid)
                    AddLevel("Weekly VWAP", weeklyVwap.Value, WeeklyVwapBackground, Brushes.White);
                if (monthlyVwap.IsValid)
                    AddLevel("Monthly VWAP", monthlyVwap.Value, MonthlyVwapBackground, Brushes.White);
            }

            if (ShowPreviousWeekLevels)
            {
                AddLevelIfValid("Prev Week High", previousWeekHigh, PreviousWeekHighLowBackground, Brushes.White);
                AddLevelIfValid("Prev Week Low", previousWeekLow, PreviousWeekHighLowBackground, Brushes.White);
            }

            if (ShowPreviousMonthLevels)
            {
                AddLevelIfValid("Prev Month High", previousMonthHigh, PreviousMonthHighLowBackground, Brushes.White);
                AddLevelIfValid("Prev Month Low", previousMonthLow, PreviousMonthHighLowBackground, Brushes.White);
            }

            if (ShowWeeklyProfile && currentWeekProfile.TryGetLevels(out levels))
            {
                AddLevel("Weekly VAH", levels.VAH, CurrentWeekBackground, Brushes.Black);
                AddLevel("Weekly VAL", levels.VAL, CurrentWeekBackground, Brushes.Black);
            }

            if (ShowMonthlyProfile && currentMonthProfile.TryGetLevels(out levels))
            {
                AddLevel("Monthly VAH", levels.VAH, CurrentMonthBackground, Brushes.Black);
                AddLevel("Monthly VAL", levels.VAL, CurrentMonthBackground, Brushes.Black);
            }
        }

        private void AddLevelIfValid(string name, double price, Brush background, Brush text)
        {
            if (!double.IsNaN(price) && !double.IsInfinity(price))
                AddLevel(name, price, background, text);
        }

        private void AddLevel(string name, double price, Brush background, Brush text)
        {
            levelManager.Add(new LevelDefinition(name, Instrument.MasterInstrument.RoundToTickSize(price), background, text));
        }

        private static DateTime GetWeekStart(DateTime date)
        {
            int diff = (7 + (date.DayOfWeek - DayOfWeek.Monday)) % 7;
            return date.Date.AddDays(-diff);
        }
    }

    public sealed class LevelManager
    {
        private readonly List<LevelDefinition> activeLevels = new List<LevelDefinition>();
        public IEnumerable<LevelDefinition> ActiveLevels { get { return activeLevels.OrderByDescending(level => level.Price); } }
        public void Add(LevelDefinition level) { activeLevels.Add(level); }
        public void Clear() { activeLevels.Clear(); }
    }

    public sealed class LevelDefinition
    {
        public LevelDefinition(string name, double price, Brush background, Brush text)
        {
            Name = name;
            Price = price;
            Background = background;
            Text = text;
        }

        public string Name { get; private set; }
        public double Price { get; private set; }
        public Brush Background { get; private set; }
        public Brush Text { get; private set; }
    }

    public sealed class VolumeProfileCalculator
    {
        private readonly SortedDictionary<long, double> volumeByTick = new SortedDictionary<long, double>();
        private readonly double tickSize;
        private readonly double valueAreaPercent;
        private double totalVolume;

        public VolumeProfileCalculator(double tickSize, double valueAreaPercent)
        {
            this.tickSize = tickSize.ApproxCompare(0) <= 0 ? 0.01 : tickSize;
            this.valueAreaPercent = valueAreaPercent;
        }

        public void AddBar(double low, double high, double close, double volume)
        {
            if (volume <= 0 || double.IsNaN(low) || double.IsNaN(high))
                return;

            long lowTick = ToTick(Math.Min(low, high));
            long highTick = ToTick(Math.Max(low, high));
            if (highTick < lowTick)
                return;

            long tickCount = Math.Max(1, highTick - lowTick + 1);
            double volumePerTick = volume / tickCount;
            for (long tick = lowTick; tick <= highTick; tick++)
                AddTickVolume(tick, volumePerTick);
        }

        public void Merge(VolumeProfileCalculator other)
        {
            foreach (KeyValuePair<long, double> item in other.volumeByTick)
                AddTickVolume(item.Key, item.Value);
        }

        public void Clear()
        {
            volumeByTick.Clear();
            totalVolume = 0;
        }

        public bool TryGetLevels(out ProfileLevels levels)
        {
            levels = new ProfileLevels();
            if (volumeByTick.Count == 0 || totalVolume <= 0)
                return false;

            long vpocTick = volumeByTick.OrderByDescending(item => item.Value).ThenBy(item => item.Key).First().Key;
            double targetVolume = totalVolume * valueAreaPercent;
            double accumulated = volumeByTick[vpocTick];
            long lower = vpocTick;
            long upper = vpocTick;

            while (accumulated < targetVolume && (volumeByTick.ContainsKey(lower - 1) || volumeByTick.ContainsKey(upper + 1)))
            {
                double below = volumeByTick.ContainsKey(lower - 1) ? volumeByTick[lower - 1] : -1;
                double above = volumeByTick.ContainsKey(upper + 1) ? volumeByTick[upper + 1] : -1;

                if (above >= below)
                {
                    upper++;
                    if (above > 0)
                        accumulated += above;
                }
                else
                {
                    lower--;
                    if (below > 0)
                        accumulated += below;
                }
            }

            levels = new ProfileLevels(ToPrice(vpocTick), ToPrice(upper), ToPrice(lower));
            return true;
        }

        private void AddTickVolume(long tick, double volume)
        {
            double existing;
            volumeByTick.TryGetValue(tick, out existing);
            volumeByTick[tick] = existing + volume;
            totalVolume += volume;
        }

        private long ToTick(double price) { return (long)Math.Round(price / tickSize, MidpointRounding.AwayFromZero); }
        private double ToPrice(long tick) { return tick * tickSize; }
    }

    public struct ProfileLevels
    {
        public ProfileLevels(double vpoc, double vah, double val)
        {
            VPOC = vpoc;
            VAH = vah;
            VAL = val;
        }

        public double VPOC;
        public double VAH;
        public double VAL;
    }

    public sealed class VWAPCalculator
    {
        private double volumePrice;
        private double volume;

        public bool IsValid { get { return volume > 0; } }
        public double Value { get { return IsValid ? volumePrice / volume : double.NaN; } }

        public void Add(double price, double barVolume)
        {
            if (barVolume <= 0 || double.IsNaN(price))
                return;

            volumePrice += price * barVolume;
            volume += barVolume;
        }
    }

    public sealed class LabelRenderer : IDisposable
    {
        private readonly Dictionary<string, SharpDX.Direct2D1.Brush> brushCache = new Dictionary<string, SharpDX.Direct2D1.Brush>();
        private DW.TextFormat textFormat;

        public void Render(D2D.RenderTarget renderTarget, ChartPanel chartPanel, ChartScale chartScale, IList<LevelDefinition> levels, int fontSize, int lineWidth, DashStyleHelper lineStyle)
        {
            if (levels == null || levels.Count == 0)
                return;

            EnsureTextFormat(fontSize);
            D2D.StrokeStyle strokeStyle = CreateStrokeStyle(renderTarget.Factory, lineStyle);

            try
            {
                foreach (LevelDefinition level in levels)
                    RenderLevel(renderTarget, chartPanel, chartScale, level, lineWidth, strokeStyle);
            }
            finally
            {
                if (strokeStyle != null)
                    strokeStyle.Dispose();
            }
        }

        public void OnRenderTargetChanged()
        {
            foreach (SharpDX.Direct2D1.Brush brush in brushCache.Values)
                brush.Dispose();
            brushCache.Clear();
        }

        public void Dispose()
        {
            OnRenderTargetChanged();
            if (textFormat != null)
                textFormat.Dispose();
        }

        private void RenderLevel(D2D.RenderTarget renderTarget, ChartPanel chartPanel, ChartScale chartScale, LevelDefinition level, int lineWidth, D2D.StrokeStyle strokeStyle)
        {
            float y = (float)chartScale.GetYByValue(level.Price);
            float chartLeft = chartPanel.X;
            float chartRight = chartPanel.X + chartPanel.W;
            float labelX = chartRight + 2;
            float labelHeight = Math.Max(18, textFormat.FontSize + 6);
            float labelWidth = 162;
            float top = y - labelHeight / 2f;
            float bottom = y + labelHeight / 2f;

            SharpDX.Direct2D1.Brush background = GetBrush(renderTarget, level.Background);
            SharpDX.Direct2D1.Brush text = GetBrush(renderTarget, level.Text);

            // Horizontal ray extends leftward from the price scale into the chart.
            renderTarget.DrawLine(new Vector2(chartLeft, y), new Vector2(chartRight, y), background, lineWidth, strokeStyle);

            RectangleF rect = new RectangleF(labelX, top, labelWidth, labelHeight);
            renderTarget.FillRectangle(rect, background);

            string label = string.Format("{0,-16} {1:0.00}", level.Name, level.Price);
            RectangleF textRect = new RectangleF(labelX + 4, top + 1, labelWidth - 8, labelHeight - 2);
            renderTarget.DrawText(label, textFormat, textRect, text);
        }

        private void EnsureTextFormat(int fontSize)
        {
            if (textFormat != null && Math.Abs(textFormat.FontSize - fontSize) < 0.1)
                return;

            if (textFormat != null)
                textFormat.Dispose();

            textFormat = new DW.TextFormat(Core.Globals.DirectWriteFactory, "Segoe UI", DW.FontWeight.SemiBold, DW.FontStyle.Normal, fontSize)
            {
                TextAlignment = DW.TextAlignment.Leading,
                ParagraphAlignment = DW.ParagraphAlignment.Center,
                WordWrapping = DW.WordWrapping.NoWrap
            };
        }

        private SharpDX.Direct2D1.Brush GetBrush(D2D.RenderTarget renderTarget, Brush mediaBrush)
        {
            SolidColorBrush solid = mediaBrush as SolidColorBrush;
            Color color = solid != null ? solid.Color : Colors.White;
            string key = string.Format("{0}:{1}:{2}:{3}", color.A, color.R, color.G, color.B);

            SharpDX.Direct2D1.Brush dxBrush;
            if (brushCache.TryGetValue(key, out dxBrush))
                return dxBrush;

            dxBrush = new SharpDX.Direct2D1.SolidColorBrush(renderTarget, new Color4(color.ScR, color.ScG, color.ScB, color.ScA));
            brushCache[key] = dxBrush;
            return dxBrush;
        }

        private D2D.StrokeStyle CreateStrokeStyle(D2D.Factory factory, DashStyleHelper lineStyle)
        {
            D2D.DashStyle dashStyle = D2D.DashStyle.Solid;
            if (lineStyle == DashStyleHelper.Dash)
                dashStyle = D2D.DashStyle.Dash;
            else if (lineStyle == DashStyleHelper.Dot)
                dashStyle = D2D.DashStyle.Dot;
            else if (lineStyle == DashStyleHelper.DashDot)
                dashStyle = D2D.DashStyle.DashDot;
            else if (lineStyle == DashStyleHelper.DashDotDot)
                dashStyle = D2D.DashStyle.DashDotDot;

            return new D2D.StrokeStyle(factory, new D2D.StrokeStyleProperties { DashStyle = dashStyle });
        }
    }
}
