//+------------------------------------------------------------------+
//|                    EA_MAGIC_DASHBOARD_V3_30_TEST.mq5             |
//|              Dashboard thong ke EA theo Magic Number - MT5       |
//|                                                                  |
//| Muc dich: CHI GIAM SAT - KHONG GUI / SUA / DONG LENH            |
//+------------------------------------------------------------------+
#property copyright "EA PRO"
#property version   "3.30"
#property description "Bang thong ke cac EA tren MT5 theo Magic Number."
#property description "Chi doc Position / Order / Deal, khong can thiep giao dich."

//====================================================================
// INPUT - TOAN BO TEN HIEN THI BANG TIENG VIET CO DAU
//====================================================================
input group "===== NHẬN DIỆN & CẬP NHẬT ====="
input(name="Chu kỳ cập nhật bảng (giây)") int    InpRefreshSeconds = 15;
input(name="Số ngày coi Magic còn hoạt động") int InpActiveDays = 7;
input(name="Bao gồm Magic = 0 (lệnh thủ công)") bool InpIncludeMagic0 = false;
input(name="Danh sách Magic đang chạy") string InpActiveMagics = "";
input(name="Đặt tên EA theo Magic") string InpMagicNames = "";

input group "===== VỐN ẢO SO SÁNH SET ====="
input(name="Vốn ảo ban đầu cho mỗi Magic (USD)") double InpVirtualCapital = 5000.0;
input(name="Mốc bắt đầu tính vốn ảo") datetime InpVirtualStart = D'2026.10.01 00:00';
input(name="Giữ trạng thái CHÁY sau khi đã chạm 0") bool InpKeepBurnedState = true;

input group "===== GIAO DIỆN BẢNG ====="
input(name="Số dòng Magic tối đa") int     InpMaxRows = 20;
input(name="Chiều rộng bảng tối đa (pixel)") int InpPanelWidth = 2200;
input(name="Cỡ chữ cơ sở") int             InpFontSize = 11;
input(name="Màu đơn sắc của chart") color  InpChartMonoColor = C'7,10,15';
input(name="Khôi phục màu chart khi gỡ EA") bool InpRestoreChartOnRemove = true;

//====================================================================
// HẰNG SỐ GIAO DIỆN
//====================================================================
const string PREFIX = "MAGIC_MONITOR_V330_";

const color COL_PANEL       = C'15,20,29';
const color COL_PANEL_2     = C'20,27,39';
const color COL_HEADER      = C'28,38,54';
const color COL_ROW_A       = C'18,24,34';
const color COL_ROW_B       = C'21,28,39';
const color COL_TOTAL       = C'31,43,60';
const color COL_BORDER      = C'53,67,87';
const color COL_TEXT        = C'230,235,243';
const color COL_MUTED       = C'148,160,177';
const color COL_GREEN       = C'64,214,124';
const color COL_RED         = C'255,95,95';
const color COL_YELLOW      = C'246,196,82';
const color COL_BLUE        = C'100,178,255';
const color COL_BURN        = C'185,36,46';
const color COL_BURN_TEXT   = C'255,255,255';
const color COL_TOP1        = C'96,78,22';
const color COL_TOP2        = C'69,75,87';
const color COL_TOP3        = C'92,55,31';

//====================================================================
// CẤU TRÚC DỮ LIỆU
//====================================================================
struct MagicStat
{
   long     magic;
   string   symbols;
   int      symbol_count;

   int      open_positions;
   int      buy_positions;
   int      sell_positions;
   double   open_lots;

   int      pending_orders;
   double   pending_lots;

   double   floating_profit;
   double   swap_open;

   double   result_today;
   double   result_month;
   double   result_all;

   int      exits_today;
   int      wins_today;
   int      losses_today;

   int      exits_all;
   int      wins_all;
   int      losses_all;
   double   gross_profit_all;
   double   gross_loss_all;
   double   closed_lots_all;

   datetime last_deal_time;
};

MagicStat g_hist[];
MagicStat g_stats[];

bool      g_history_dirty = true;
datetime  g_last_history_refresh = 0;
int       g_last_day_key = -1;
int       g_last_month_key = -1;
int       g_last_drawn_rows = 0;

//====================================================================
// LƯU GIAO DIỆN CHART GỐC
//====================================================================
long g_orig_bg, g_orig_fg, g_orig_grid, g_orig_volume;
long g_orig_up, g_orig_down, g_orig_line;
long g_orig_bull, g_orig_bear, g_orig_bid, g_orig_ask, g_orig_last;
long g_orig_show_grid, g_orig_show_ohlc, g_orig_show_bid;
long g_orig_show_ask, g_orig_show_last, g_orig_show_period;
long g_orig_show_trade_levels, g_orig_show_volumes;

//====================================================================
// TIỆN ÍCH CHUNG
//====================================================================
string TrimText(string s)
{
   StringTrimLeft(s);
   StringTrimRight(s);
   return s;
}
//--------------------------------------------------------------------
int MaxInt(const int a, const int b)
{
   return (a > b ? a : b);
}
//--------------------------------------------------------------------
int MinInt(const int a, const int b)
{
   return (a < b ? a : b);
}
//--------------------------------------------------------------------
string ShortText(string s, const int max_len)
{
   if(max_len <= 3 || StringLen(s) <= max_len)
      return s;
   return StringSubstr(s, 0, max_len - 3) + "...";
}
//--------------------------------------------------------------------
bool IsMagicAllowed(const long magic)
{
   if(magic == 0 && !InpIncludeMagic0)
      return false;
   return true;
}
//--------------------------------------------------------------------
void ResetStat(MagicStat &s, const long magic)
{
   s.magic             = magic;
   s.symbols           = "";
   s.symbol_count      = 0;
   s.open_positions    = 0;
   s.buy_positions     = 0;
   s.sell_positions    = 0;
   s.open_lots         = 0.0;
   s.pending_orders    = 0;
   s.pending_lots      = 0.0;
   s.floating_profit   = 0.0;
   s.swap_open         = 0.0;
   s.result_today      = 0.0;
   s.result_month      = 0.0;
   s.result_all        = 0.0;
   s.exits_today       = 0;
   s.wins_today        = 0;
   s.losses_today      = 0;
   s.exits_all         = 0;
   s.wins_all          = 0;
   s.losses_all        = 0;
   s.gross_profit_all  = 0.0;
   s.gross_loss_all    = 0.0;
   s.closed_lots_all   = 0.0;
   s.last_deal_time    = 0;
}
//--------------------------------------------------------------------
int FindMagic(MagicStat &arr[], const long magic)
{
   int n = ArraySize(arr);
   for(int i = 0; i < n; i++)
      if(arr[i].magic == magic)
         return i;
   return -1;
}
//--------------------------------------------------------------------
int EnsureMagic(MagicStat &arr[], const long magic)
{
   int idx = FindMagic(arr, magic);
   if(idx >= 0)
      return idx;

   int n = ArraySize(arr);
   if(ArrayResize(arr, n + 1) != n + 1)
      return -1;

   ResetStat(arr[n], magic);
   return n;
}
//--------------------------------------------------------------------
void AddSymbol(MagicStat &s, const string symbol)
{
   if(symbol == "")
      return;

   string haystack = "|" + s.symbols + "|";
   string needle   = "|" + symbol + "|";

   if(StringFind(haystack, needle) >= 0)
      return;

   if(s.symbols != "")
      s.symbols += "|";

   s.symbols += symbol;
   s.symbol_count++;
}
//--------------------------------------------------------------------
datetime DayStart(const datetime t)
{
   MqlDateTime d;
   TimeToStruct(t, d);
   d.hour = 0;
   d.min  = 0;
   d.sec  = 0;
   return StructToTime(d);
}
//--------------------------------------------------------------------
datetime MonthStart(const datetime t)
{
   MqlDateTime d;
   TimeToStruct(t, d);
   d.day  = 1;
   d.hour = 0;
   d.min  = 0;
   d.sec  = 0;
   return StructToTime(d);
}
//--------------------------------------------------------------------
int DayKey(const datetime t)
{
   MqlDateTime d;
   TimeToStruct(t, d);
   return d.year * 10000 + d.mon * 100 + d.day;
}
//--------------------------------------------------------------------
int MonthKey(const datetime t)
{
   MqlDateTime d;
   TimeToStruct(t, d);
   return d.year * 100 + d.mon;
}
//--------------------------------------------------------------------
bool IsExitEntry(const long entry)
{
   return (entry == DEAL_ENTRY_OUT ||
           entry == DEAL_ENTRY_OUT_BY ||
           entry == DEAL_ENTRY_INOUT);
}
//--------------------------------------------------------------------
color ProfitColor(const double value)
{
   if(value > 0.005)  return COL_GREEN;
   if(value < -0.005) return COL_RED;
   return COL_TEXT;
}
//--------------------------------------------------------------------
string MoneyText(const double value)
{
   if(value > 0.005)
      return "+" + DoubleToString(value, 2);
   return DoubleToString(value, 2);
}
//--------------------------------------------------------------------
string MagicText(const long magic)
{
   return StringFormat("%I64d", magic);
}

//====================================================================
// TÊN EA THEO MAGIC
// InpMagicNames vi du:
// 68999=DAVID HUNTER;2026001=PHOENIX
//====================================================================
string GetMagicName(const long magic)
{
   if(magic == 0)
      return "THỦ CÔNG";

   string items[];
   ushort semi = StringGetCharacter(";", 0);
   int count = StringSplit(InpMagicNames, semi, items);

   for(int i = 0; i < count; i++)
   {
      string item = TrimText(items[i]);
      if(item == "")
         continue;

      string kv[];
      ushort eq = StringGetCharacter("=", 0);
      int parts = StringSplit(item, eq, kv);
      if(parts < 2)
         continue;

      long m = (long)StringToInteger(TrimText(kv[0]));
      if(m == magic)
         return ShortText(TrimText(kv[1]), 28);
   }

   return "EA #" + MagicText(magic);
}
//--------------------------------------------------------------------
bool HasActiveMagicFilter()
{
   string s = TrimText(InpActiveMagics);
   return (s != "");
}
//--------------------------------------------------------------------
bool IsActiveMagic(const long magic)
{
   if(!HasActiveMagicFilter())
      return true;

   string normalized = InpActiveMagics;
   StringReplace(normalized, ";", ",");

   string parts[];
   ushort comma = StringGetCharacter(",", 0);
   int count = StringSplit(normalized, comma, parts);

   for(int i = 0; i < count; i++)
   {
      string s = TrimText(parts[i]);
      if(s == "")
         continue;

      long m = (long)StringToInteger(s);
      if(m == magic)
         return true;
   }

   return false;
}
//--------------------------------------------------------------------
void AddActiveMagics(MagicStat &arr[])
{
   if(!HasActiveMagicFilter())
      return;

   string normalized = InpActiveMagics;
   StringReplace(normalized, ";", ",");

   string parts[];
   ushort comma = StringGetCharacter(",", 0);
   int count = StringSplit(normalized, comma, parts);

   for(int i = 0; i < count; i++)
   {
      string s = TrimText(parts[i]);
      if(s == "")
         continue;

      long m = (long)StringToInteger(s);
      if(IsMagicAllowed(m))
         EnsureMagic(arr, m);
   }
}

//====================================================================
// LỊCH SỬ DEAL THEO MAGIC
// KQ ngày/tháng = tổng DEAL_PROFIT + COMMISSION + SWAP + FEE
// của các deal BUY/SELL trong khoảng thời gian tương ứng.
//====================================================================
void BuildHistoryCache()
{
   datetime now = TimeTradeServer();
   if(now <= 0)
      now = TimeCurrent();

   datetime day_start   = DayStart(now);
   datetime month_start = MonthStart(now);

   int active_days = MaxInt(1, InpActiveDays);
   datetime active_from = now - (datetime)(active_days * 86400);

   datetime history_from = 0;
   if(InpVirtualStart > 0)
      history_from = InpVirtualStart;

   // Đảm bảo vẫn đủ dữ liệu để xác định Magic còn hoạt động và KQ tháng/ngày.
   if(history_from == 0 || active_from < history_from)
      history_from = active_from;
   if(month_start < history_from)
      history_from = month_start;

   ArrayResize(g_hist, 0);

   if(!HistorySelect(history_from, now))
   {
      g_last_history_refresh = now;
      g_history_dirty = false;
      return;
   }

   int total = HistoryDealsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      long deal_type = HistoryDealGetInteger(ticket, DEAL_TYPE);
      if(deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL)
         continue;

      long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
      if(!IsMagicAllowed(magic))
         continue;
      if(!IsActiveMagic(magic))
         continue;

      int idx = EnsureMagic(g_hist, magic);
      if(idx < 0)
         continue;

      string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      AddSymbol(g_hist[idx], symbol);

      datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(deal_time > g_hist[idx].last_deal_time)
         g_hist[idx].last_deal_time = deal_time;

      double net = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                 + HistoryDealGetDouble(ticket, DEAL_COMMISSION)
                 + HistoryDealGetDouble(ticket, DEAL_SWAP)
                 + HistoryDealGetDouble(ticket, DEAL_FEE);

      long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);

      if(InpVirtualStart <= 0 || deal_time >= InpVirtualStart)
      {
         g_hist[idx].result_all += net;

         if(IsExitEntry(entry))
         {
            g_hist[idx].exits_all++;
            g_hist[idx].closed_lots_all += HistoryDealGetDouble(ticket, DEAL_VOLUME);

            if(net > 0.005)
            {
               g_hist[idx].wins_all++;
               g_hist[idx].gross_profit_all += net;
            }
            else if(net < -0.005)
            {
               g_hist[idx].losses_all++;
               g_hist[idx].gross_loss_all += -net;
            }
         }
      }

      if(deal_time >= month_start)
         g_hist[idx].result_month += net;

      if(deal_time >= day_start)
      {
         g_hist[idx].result_today += net;

         if(IsExitEntry(entry))
         {
            g_hist[idx].exits_today++;

            if(net > 0.005)
               g_hist[idx].wins_today++;
            else if(net < -0.005)
               g_hist[idx].losses_today++;
         }
      }
   }

   g_last_history_refresh = now;
   g_history_dirty = false;
   g_last_day_key = DayKey(now);
   g_last_month_key = MonthKey(now);
}

//====================================================================
// SAO CHÉP CACHE LỊCH SỬ -> DỮ LIỆU HIỆN TẠI
//====================================================================
void LoadStatsFromHistory()
{
   int n = ArraySize(g_hist);
   ArrayResize(g_stats, n);

   for(int i = 0; i < n; i++)
      g_stats[i] = g_hist[i];

   AddActiveMagics(g_stats);
}

//====================================================================
// QUÉT POSITION ĐANG MỞ
//====================================================================
void ScanOpenPositions()
{
   int total = PositionsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      long magic = PositionGetInteger(POSITION_MAGIC);
      if(!IsMagicAllowed(magic))
         continue;
      if(!IsActiveMagic(magic))
         continue;

      int idx = EnsureMagic(g_stats, magic);
      if(idx < 0)
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      AddSymbol(g_stats[idx], symbol);

      long type = PositionGetInteger(POSITION_TYPE);
      double lot = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double swap = PositionGetDouble(POSITION_SWAP);

      g_stats[idx].open_positions++;
      g_stats[idx].open_lots += lot;
      g_stats[idx].floating_profit += profit + swap;
      g_stats[idx].swap_open += swap;

      if(type == POSITION_TYPE_BUY)
         g_stats[idx].buy_positions++;
      else if(type == POSITION_TYPE_SELL)
         g_stats[idx].sell_positions++;
   }
}

//====================================================================
// QUÉT PENDING ORDER
//====================================================================
void ScanPendingOrders()
{
   int total = OrdersTotal();

   for(int i = 0; i < total; i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;

      long magic = OrderGetInteger(ORDER_MAGIC);
      if(!IsMagicAllowed(magic))
         continue;
      if(!IsActiveMagic(magic))
         continue;

      int idx = EnsureMagic(g_stats, magic);
      if(idx < 0)
         continue;

      string symbol = OrderGetString(ORDER_SYMBOL);
      AddSymbol(g_stats[idx], symbol);

      g_stats[idx].pending_orders++;
      g_stats[idx].pending_lots += OrderGetDouble(ORDER_VOLUME_CURRENT);
   }
}

//====================================================================
// LỌC MAGIC CẦN HIỂN THỊ
//====================================================================
void CompactActiveStats(const datetime now)
{
   datetime threshold = now - (datetime)(MaxInt(1, InpActiveDays) * 86400);

   int n = ArraySize(g_stats);
   int out = 0;

   for(int i = 0; i < n; i++)
   {
      bool keep = false;

      if(HasActiveMagicFilter())
      {
         keep = IsActiveMagic(g_stats[i].magic);
      }
      else
      {
         // Fallback nếu để trống danh sách: tương thích cơ chế cũ.
         bool active_now = (g_stats[i].open_positions > 0 ||
                            g_stats[i].pending_orders > 0);
         bool recent = (g_stats[i].last_deal_time >= threshold);
         keep = (active_now || recent);
      }

      if(!keep)
         continue;

      if(out != i)
         g_stats[out] = g_stats[i];

      out++;
   }

   ArrayResize(g_stats, out);
}

//====================================================================
// XẾP HẠNG DUY NHẤT: HIỆU QUẢ THỰC CHIẾN
//====================================================================
bool ComesBefore(const MagicStat &a, const MagicStat &b)
{
   bool burn_a = IsMagicBurned(a);
   bool burn_b = IsMagicBurned(b);

   if(burn_a != burn_b)
      return !burn_a;

   double score_a = PracticalScore(a);
   double score_b = PracticalScore(b);

   if(MathAbs(score_a - score_b) > 0.000001)
      return (score_a > score_b);

   double pf_a = ProfitFactorAll(a);
   double pf_b = ProfitFactorAll(b);

   if(MathAbs(pf_a - pf_b) > 0.000001)
      return (pf_a > pf_b);

   double exp_a = ExpectancyAll(a);
   double exp_b = ExpectancyAll(b);

   if(MathAbs(exp_a - exp_b) > 0.000001)
      return (exp_a > exp_b);

   if(a.exits_all != b.exits_all)
      return (a.exits_all > b.exits_all);

   return (a.magic < b.magic);
}
//--------------------------------------------------------------------
void SortStats()
{
   int n = ArraySize(g_stats);

   for(int i = 0; i < n - 1; i++)
   {
      for(int j = i + 1; j < n; j++)
      {
         if(!ComesBefore(g_stats[i], g_stats[j]))
         {
            MagicStat tmp = g_stats[i];
            g_stats[i] = g_stats[j];
            g_stats[j] = tmp;
         }
      }
   }
}

//====================================================================
// THỐNG KÊ TỔNG
//====================================================================
void BuildTotalStat(MagicStat &t)
{
   ResetStat(t, -1);

   int n = ArraySize(g_stats);

   for(int i = 0; i < n; i++)
   {
      t.open_positions  += g_stats[i].open_positions;
      t.buy_positions   += g_stats[i].buy_positions;
      t.sell_positions  += g_stats[i].sell_positions;
      t.open_lots       += g_stats[i].open_lots;

      t.pending_orders  += g_stats[i].pending_orders;
      t.pending_lots    += g_stats[i].pending_lots;

      t.floating_profit += g_stats[i].floating_profit;
      t.swap_open       += g_stats[i].swap_open;

      t.result_today    += g_stats[i].result_today;
      t.result_month    += g_stats[i].result_month;
      t.result_all      += g_stats[i].result_all;

      t.exits_today     += g_stats[i].exits_today;
      t.wins_today      += g_stats[i].wins_today;
      t.losses_today    += g_stats[i].losses_today;

      t.exits_all       += g_stats[i].exits_all;
      t.wins_all        += g_stats[i].wins_all;
      t.losses_all      += g_stats[i].losses_all;
      t.gross_profit_all+= g_stats[i].gross_profit_all;
      t.gross_loss_all  += g_stats[i].gross_loss_all;
      t.closed_lots_all += g_stats[i].closed_lots_all;
   }
}

//====================================================================
// ĐẾM EA GẮN TRÊN CÁC CHART
// CHART_EXPERT_NAME chỉ cho biết tên EA, không cung cấp Magic.
//====================================================================
void GetAttachedEAInfo(int &count, string &names)
{
   count = 0;
   names = "";

   long current_chart = ChartID();
   int shown = 0;

   for(long chart_id = ChartFirst(); chart_id >= 0; chart_id = ChartNext(chart_id))
   {
      if(chart_id == current_chart)
         continue;

      string expert = ChartGetString(chart_id, CHART_EXPERT_NAME);
      if(expert == "")
         continue;

      count++;

      if(shown < 4)
      {
         if(names != "")
            names += " | ";
         names += ShortText(expert, 24);
         shown++;
      }
   }

   if(count > shown)
      names += " | +" + IntegerToString(count - shown);
}

//====================================================================
// THỐNG KÊ TÀI KHOẢN HIỆN TẠI
//====================================================================
void GetAccountOpenStats(double &floating_all, double &lots_all, int &positions_all)
{
   floating_all = 0.0;
   lots_all = 0.0;
   positions_all = PositionsTotal();

   for(int i = 0; i < positions_all; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      floating_all += PositionGetDouble(POSITION_PROFIT)
                    + PositionGetDouble(POSITION_SWAP);

      lots_all += PositionGetDouble(POSITION_VOLUME);
   }
}
//--------------------------------------------------------------------
string AccountModeText()
{
   long mode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);

   if(mode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      return "HEDGING";
   if(mode == ACCOUNT_MARGIN_MODE_RETAIL_NETTING)
      return "NETTING";
   if(mode == ACCOUNT_MARGIN_MODE_EXCHANGE)
      return "EXCHANGE";

   return "KHÁC";
}

//====================================================================
// VỐN ẢO / EQUITY ẢO / TRẠNG THÁI CHÁY
//====================================================================
string VirtualKey(const long magic, const string suffix)
{
   long login = AccountInfoInteger(ACCOUNT_LOGIN);
   return "MAGICMON_V330_" + StringFormat("%I64d", login) + "_" + MagicText(magic) + "_" + suffix;
}
//--------------------------------------------------------------------
double VirtualEquity(const MagicStat &s)
{
   return InpVirtualCapital + s.result_all + s.floating_profit;
}
//--------------------------------------------------------------------
double UpdateAndGetVirtualPeak(const MagicStat &s)
{
   double eq = VirtualEquity(s);
   string key = VirtualKey(s.magic, "PEAK");

   double peak = MathMax(InpVirtualCapital, eq);

   if(GlobalVariableCheck(key))
      peak = MathMax(peak, GlobalVariableGet(key));

   if(eq > peak)
      peak = eq;

   GlobalVariableSet(key, peak);
   return peak;
}
//--------------------------------------------------------------------
double UpdateAndGetVirtualMaxDD(const MagicStat &s)
{
   double eq = VirtualEquity(s);
   double peak = UpdateAndGetVirtualPeak(s);

   double dd_pct = 0.0;
   if(peak > 0.0 && eq < peak)
      dd_pct = (peak - eq) / peak * 100.0;

   string key = VirtualKey(s.magic, "MAXDD");
   double max_dd = dd_pct;

   if(GlobalVariableCheck(key))
      max_dd = MathMax(max_dd, GlobalVariableGet(key));

   GlobalVariableSet(key, max_dd);
   return max_dd;
}
//--------------------------------------------------------------------
double CurrentVirtualDDUSD(const MagicStat &s)
{
   double eq = VirtualEquity(s);
   double peak = UpdateAndGetVirtualPeak(s);

   if(eq >= peak)
      return 0.0;

   return peak - eq;
}
//--------------------------------------------------------------------
double UpdateAndGetVirtualMaxDDUSD(const MagicStat &s)
{
   double dd_usd = CurrentVirtualDDUSD(s);
   string key = VirtualKey(s.magic, "MAXDDUSD");

   double max_dd_usd = dd_usd;
   if(GlobalVariableCheck(key))
      max_dd_usd = MathMax(max_dd_usd, GlobalVariableGet(key));

   GlobalVariableSet(key, max_dd_usd);
   return max_dd_usd;
}
//--------------------------------------------------------------------
bool IsMagicBurned(const MagicStat &s)
{
   double eq = VirtualEquity(s);
   string key = VirtualKey(s.magic, "BURN");

   bool burned = (eq <= 0.0);

   if(InpKeepBurnedState && GlobalVariableCheck(key) && GlobalVariableGet(key) > 0.5)
      burned = true;

   if(InpKeepBurnedState && eq <= 0.0)
      GlobalVariableSet(key, 1.0);

   return burned;
}


//====================================================================
// CHỈ SỐ HIỆU QUẢ THỰC CHIẾN
// Dùng duy nhất một chế độ xếp hạng:
// Hiệu suất vốn ảo / Max DD ảo. SET cháy luôn xuống cuối.
// Khi bằng nhau: PF -> Expectancy -> số lệnh.
//====================================================================
double ProfitPct(const MagicStat &s)
{
   if(InpVirtualCapital <= 0.0)
      return 0.0;
   return (VirtualEquity(s) - InpVirtualCapital) / InpVirtualCapital * 100.0;
}
//--------------------------------------------------------------------
double CurrentVirtualDDPct(const MagicStat &s)
{
   double eq = VirtualEquity(s);
   double peak = UpdateAndGetVirtualPeak(s);

   if(peak <= 0.0 || eq >= peak)
      return 0.0;

   return (peak - eq) / peak * 100.0;
}
//--------------------------------------------------------------------
double ProfitFactorAll(const MagicStat &s)
{
   if(s.gross_loss_all > 0.000001)
      return s.gross_profit_all / s.gross_loss_all;

   if(s.gross_profit_all > 0.000001)
      return 99.99;

   return 0.0;
}
//--------------------------------------------------------------------
double ExpectancyAll(const MagicStat &s)
{
   if(s.exits_all <= 0)
      return 0.0;
   return s.result_all / (double)s.exits_all;
}
//--------------------------------------------------------------------
double PracticalScore(const MagicStat &s)
{
   if(IsMagicBurned(s))
      return -1000000.0;

   double profit_pct = ProfitPct(s);
   double max_dd = UpdateAndGetVirtualMaxDD(s);

   // Recovery-style score: lợi nhuận % trên mỗi 1% Max DD.
   // Floor 1% để tránh SET mới có DD = 0 bị điểm vô hạn.
   double risk_base = MathMax(1.0, max_dd);
   return profit_pct / risk_base;
}

//====================================================================
// QUẢN LÝ OBJECT
//====================================================================
bool EnsureRect(const string name)
{
   if(ObjectFind(0, name) >= 0)
      return true;

   if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
      return false;

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);

   return true;
}
//--------------------------------------------------------------------
void SetRect(const string suffix,
             const int x,
             const int y,
             const int w,
             const int h,
             const color bg,
             const color border)
{
   string name = PREFIX + suffix;
   if(!EnsureRect(name))
      return;

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
}
//--------------------------------------------------------------------
bool EnsureLabel(const string name)
{
   if(ObjectFind(0, name) >= 0)
      return true;

   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
      return false;

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");

   return true;
}
//--------------------------------------------------------------------
void SetLabel(const string suffix,
              const string text,
              const int x,
              const int y,
              const int font_size,
              const color clr)
{
   string name = PREFIX + suffix;
   if(!EnsureLabel(name))
      return;

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}
//--------------------------------------------------------------------
void DeleteRowObjects(const int row)
{
   ObjectDelete(0, PREFIX + "ROW_BG_" + IntegerToString(row));
   ObjectDelete(0, PREFIX + "MAGIC_BG_" + IntegerToString(row));
   ObjectDelete(0, PREFIX + "STATUS_BG_" + IntegerToString(row));
   ObjectDelete(0, PREFIX + "STATUS_BG_" + IntegerToString(row));

   for(int c = 0; c < 19; c++)
      ObjectDelete(0, PREFIX + "ROW_" + IntegerToString(row) + "_C_" + IntegerToString(c));
}

//====================================================================
// GIAO DIỆN CHART ĐƠN SẮC
//====================================================================
void SaveOriginalChartStyle()
{
   g_orig_bg     = ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   g_orig_fg     = ChartGetInteger(0, CHART_COLOR_FOREGROUND);
   g_orig_grid   = ChartGetInteger(0, CHART_COLOR_GRID);
   g_orig_volume = ChartGetInteger(0, CHART_COLOR_VOLUME);
   g_orig_up     = ChartGetInteger(0, CHART_COLOR_CHART_UP);
   g_orig_down   = ChartGetInteger(0, CHART_COLOR_CHART_DOWN);
   g_orig_line   = ChartGetInteger(0, CHART_COLOR_CHART_LINE);
   g_orig_bull   = ChartGetInteger(0, CHART_COLOR_CANDLE_BULL);
   g_orig_bear   = ChartGetInteger(0, CHART_COLOR_CANDLE_BEAR);
   g_orig_bid    = ChartGetInteger(0, CHART_COLOR_BID);
   g_orig_ask    = ChartGetInteger(0, CHART_COLOR_ASK);
   g_orig_last   = ChartGetInteger(0, CHART_COLOR_LAST);

   g_orig_show_grid         = ChartGetInteger(0, CHART_SHOW_GRID);
   g_orig_show_ohlc         = ChartGetInteger(0, CHART_SHOW_OHLC);
   g_orig_show_bid          = ChartGetInteger(0, CHART_SHOW_BID_LINE);
   g_orig_show_ask          = ChartGetInteger(0, CHART_SHOW_ASK_LINE);
   g_orig_show_last         = ChartGetInteger(0, CHART_SHOW_LAST_LINE);
   g_orig_show_period       = ChartGetInteger(0, CHART_SHOW_PERIOD_SEP);
   g_orig_show_trade_levels = ChartGetInteger(0, CHART_SHOW_TRADE_LEVELS);
   g_orig_show_volumes      = ChartGetInteger(0, CHART_SHOW_VOLUMES);
}
//--------------------------------------------------------------------
void ApplyMonoChartStyle()
{
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, InpChartMonoColor);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, InpChartMonoColor);
   ChartSetInteger(0, CHART_COLOR_GRID, InpChartMonoColor);
   ChartSetInteger(0, CHART_COLOR_VOLUME, InpChartMonoColor);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, InpChartMonoColor);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, InpChartMonoColor);
   ChartSetInteger(0, CHART_COLOR_CHART_LINE, InpChartMonoColor);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, InpChartMonoColor);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, InpChartMonoColor);
   ChartSetInteger(0, CHART_COLOR_BID, InpChartMonoColor);
   ChartSetInteger(0, CHART_COLOR_ASK, InpChartMonoColor);
   ChartSetInteger(0, CHART_COLOR_LAST, InpChartMonoColor);

   ChartSetInteger(0, CHART_SHOW_GRID, false);
   ChartSetInteger(0, CHART_SHOW_OHLC, false);
   ChartSetInteger(0, CHART_SHOW_BID_LINE, false);
   ChartSetInteger(0, CHART_SHOW_ASK_LINE, false);
   ChartSetInteger(0, CHART_SHOW_LAST_LINE, false);
   ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, false);
   ChartSetInteger(0, CHART_SHOW_TRADE_LEVELS, false);
   ChartSetInteger(0, CHART_SHOW_VOLUMES, CHART_VOLUME_HIDE);

   ChartRedraw(0);
}
//--------------------------------------------------------------------
void RestoreOriginalChartStyle()
{
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, g_orig_bg);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, g_orig_fg);
   ChartSetInteger(0, CHART_COLOR_GRID, g_orig_grid);
   ChartSetInteger(0, CHART_COLOR_VOLUME, g_orig_volume);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, g_orig_up);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, g_orig_down);
   ChartSetInteger(0, CHART_COLOR_CHART_LINE, g_orig_line);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, g_orig_bull);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, g_orig_bear);
   ChartSetInteger(0, CHART_COLOR_BID, g_orig_bid);
   ChartSetInteger(0, CHART_COLOR_ASK, g_orig_ask);
   ChartSetInteger(0, CHART_COLOR_LAST, g_orig_last);

   ChartSetInteger(0, CHART_SHOW_GRID, g_orig_show_grid);
   ChartSetInteger(0, CHART_SHOW_OHLC, g_orig_show_ohlc);
   ChartSetInteger(0, CHART_SHOW_BID_LINE, g_orig_show_bid);
   ChartSetInteger(0, CHART_SHOW_ASK_LINE, g_orig_show_ask);
   ChartSetInteger(0, CHART_SHOW_LAST_LINE, g_orig_show_last);
   ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, g_orig_show_period);
   ChartSetInteger(0, CHART_SHOW_TRADE_LEVELS, g_orig_show_trade_levels);
   ChartSetInteger(0, CHART_SHOW_VOLUMES, g_orig_show_volumes);

   ChartRedraw(0);
}

//====================================================================
// VẼ BẢNG
//====================================================================
void DrawDashboard()
{
   int chart_w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int chart_h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);

   if(chart_w <= 0) chart_w = 1600;
   if(chart_h <= 0) chart_h = 900;

   int panel_x = 0;
   int panel_y = 0;
   int panel_w = chart_w;
   int panel_h = chart_h;

   double scale = (double)panel_w / 2000.0;
   if(scale < 0.66) scale = 0.66;
   if(scale > 1.16) scale = 1.16;

   int fs       = (int)MathMax(8.0, MathRound(InpFontSize * scale));
   int fs_small = (int)MathMax(8.0, MathRound((InpFontSize - 1) * scale));
   int fs_title = (int)MathMax(16.0, MathRound(24 * scale));
   int fs_value = (int)MathMax(12.0, MathRound(17 * scale));

   int pad = (int)MathMax(8.0, MathRound(14 * scale));
   int inner_x = panel_x + pad;
   int inner_w = panel_w - pad * 2;

   int title_h = (int)MathRound(62 * scale);
   int cards_h = (int)MathRound(78 * scale);
   int header_h = (int)MathRound(38 * scale);
   int row_h = (int)MathRound(42 * scale);
   int footer_h = (int)MathRound(54 * scale);

   if(row_h < 32) row_h = 32;

   SetRect("PANEL", panel_x, panel_y, panel_w, panel_h, COL_PANEL, COL_PANEL);

   datetime now = TimeTradeServer();
   if(now <= 0) now = TimeCurrent();

   int y = panel_y + pad;
   SetLabel("TITLE", "EA SET RANKING  •  HIỆU QUẢ THỰC CHIẾN", inner_x, y, fs_title, COL_TEXT);

   string subtitle = "Chỉ hiển thị Magic đang chạy  •  Mỗi Magic = "
                   + DoubleToString(InpVirtualCapital, 0)
                   + " USD vốn ảo  •  Tiền demo thật chỉ dùng làm margin.";

   SetLabel("SUBTITLE", ShortText(subtitle, 190), inner_x,
            y + (int)MathRound(31 * scale), fs_small, COL_MUTED);

   SetLabel("CLOCK", TimeToString(now, TIME_DATE | TIME_SECONDS),
            panel_x + panel_w - (int)MathRound(205 * scale),
            y + 4, fs_small, COL_MUTED);

   y += title_h;

   int magic_count = ArraySize(g_stats);
   int burned_count = 0;
   int running_count = 0;
   double total_virtual_equity = 0.0;
   double total_closed = 0.0;
   double total_float = 0.0;

   for(int i = 0; i < magic_count; i++)
   {
      if(IsMagicBurned(g_stats[i])) burned_count++;
      else running_count++;

      total_virtual_equity += VirtualEquity(g_stats[i]);
      total_closed += g_stats[i].result_all;
      total_float += g_stats[i].floating_profit;
   }

   string top_name = "-";
   if(magic_count > 0)
      top_name = "#" + MagicText(g_stats[0].magic);

   string card_titles[6] =
   {
      "VỐN ẢO / MAGIC",
      "MAGIC ĐANG CHẠY",
      "SET CHƯA CHÁY",
      "SET ĐÃ CHÁY",
      "TỔNG EQUITY ẢO",
      "TOP HIỆN TẠI"
   };

   string card_values[6];
   card_values[0] = DoubleToString(InpVirtualCapital, 0) + " USD";
   card_values[1] = IntegerToString(magic_count);
   card_values[2] = IntegerToString(running_count);
   card_values[3] = IntegerToString(burned_count);
   card_values[4] = DoubleToString(total_virtual_equity, 2);
   card_values[5] = top_name;

   color card_colors[6] =
   {
      COL_TEXT,
      COL_BLUE,
      COL_GREEN,
      (burned_count > 0 ? COL_RED : COL_MUTED),
      ProfitColor(total_closed + total_float),
      COL_YELLOW
   };

   int gap = 7;
   int card_w = (inner_w - gap * 5) / 6;

   for(int i = 0; i < 6; i++)
   {
      int cx = inner_x + i * (card_w + gap);
      SetRect("CARD_" + IntegerToString(i), cx, y, card_w, cards_h - 7, COL_PANEL_2, COL_BORDER);
      SetLabel("CARD_T_" + IntegerToString(i), card_titles[i],
               cx + 10, y + 10, fs_small, COL_MUTED);
      SetLabel("CARD_V_" + IntegerToString(i), card_values[i],
               cx + 10, y + (int)MathRound(36 * scale), fs_value, card_colors[i]);
   }

   y += cards_h + 5;

   int fixed_h = y + header_h + footer_h + pad - panel_y;
   int max_rows_by_height = (chart_h - fixed_h) / row_h;
   if(max_rows_by_height < 1) max_rows_by_height = 1;

   int display_rows = MinInt(magic_count, InpMaxRows);
   display_rows = MinInt(display_rows, max_rows_by_height);

   SetRect("TABLE_HEADER", inner_x, y, inner_w, header_h, COL_HEADER, COL_BORDER);

   double frac[20] =
   {
      0.000, // TOP
      0.037, // TEN
      0.137, // MAGIC
      0.202, // VON
      0.260, // BAL
      0.322, // EQ
      0.388, // PEAK
      0.450, // P/L
      0.510, // FLOAT
      0.565, // LOT MO
      0.612, // TONG LOT
      0.662, // DD HT %
      0.712, // DD HT $
      0.762, // MAX DD %
      0.817, // MAX DD $
      0.872, // PF
      0.912, // EXP
      0.950, // LENH
      0.975, // TT
      1.000
   };

   string headers[19] =
   {
      "TOP",
      "EA / NHÃN",
      "MAGIC",
      "VỐN GỐC",
      "BAL ẢO",
      "EQUITY ẢO",
      "EQUITY ĐỈNH",
      "P/L CHỐT",
      "FLOAT",
      "LOT MỞ",
      "TỔNG LOT",
      "DD HT%",
      "DD HT $",
      "MAX DD%",
      "MAX DD $",
      "PF",
      "EXP",
      "LỆNH",
      "TT"
   };

   for(int c = 0; c < 19; c++)
   {
      int hx = inner_x + (int)MathRound(inner_w * frac[c]) + 5;
      SetLabel("HDR_" + IntegerToString(c), headers[c], hx, y + 10, fs_small, COL_MUTED);
   }

   y += header_h;

   for(int r = 0; r < display_rows; r++)
   {
      MagicStat s = g_stats[r];

      double virtual_balance = InpVirtualCapital + s.result_all;
      double virtual_equity = VirtualEquity(s);
      double peak_equity = UpdateAndGetVirtualPeak(s);
      double current_dd = CurrentVirtualDDPct(s);
      double current_dd_usd = CurrentVirtualDDUSD(s);
      double max_dd = UpdateAndGetVirtualMaxDD(s);
      double max_dd_usd = UpdateAndGetVirtualMaxDDUSD(s);
      double pf = ProfitFactorAll(s);
      double exp = ExpectancyAll(s);
      bool burned = IsMagicBurned(s);

      string status = "RUN";
      if(burned) status = "CHÁY";
      else if(virtual_equity < InpVirtualCapital) status = "ÂM";

      string values[19];
      values[0]  = "#" + IntegerToString(r + 1);
      values[1]  = ShortText(GetMagicName(s.magic), 18);
      values[2]  = MagicText(s.magic);
      values[3]  = DoubleToString(InpVirtualCapital, 0);
      values[4]  = DoubleToString(virtual_balance, 2);
      values[5]  = DoubleToString(virtual_equity, 2);
      values[6]  = DoubleToString(peak_equity, 2);
      values[7]  = MoneyText(s.result_all);
      values[8]  = MoneyText(s.floating_profit);
      values[9]  = DoubleToString(s.open_lots, 2);
      values[10] = DoubleToString(s.closed_lots_all, 2);
      values[11] = DoubleToString(current_dd, 2) + "%";
      values[12] = DoubleToString(current_dd_usd, 2);
      values[13] = DoubleToString(max_dd, 2) + "%";
      values[14] = DoubleToString(max_dd_usd, 2);
      values[15] = (pf >= 99.0 ? "∞" : DoubleToString(pf, 2));
      values[16] = DoubleToString(exp, 2);
      values[17] = IntegerToString(s.exits_all);
      values[18] = status;

      int row_index = r + 1;
      color row_bg = ((r % 2) == 0 ? COL_ROW_A : COL_ROW_B);

      if(r == 0 && !burned) row_bg = COL_TOP1;
      else if(r == 1 && !burned) row_bg = COL_TOP2;
      else if(r == 2 && !burned) row_bg = COL_TOP3;

      SetRect("ROW_BG_" + IntegerToString(row_index),
              inner_x, y, inner_w, row_h, row_bg, COL_BORDER);

      if(burned)
      {
         int magic_x = inner_x + (int)MathRound(inner_w * frac[2]);
         int magic_w = (int)MathRound(inner_w * (frac[3] - frac[2]));
         SetRect("MAGIC_BG_" + IntegerToString(row_index),
                 magic_x, y + 1, magic_w, row_h - 2, COL_BURN, COL_BURN);

         int st_x = inner_x + (int)MathRound(inner_w * frac[18]);
         int st_w = (int)MathRound(inner_w * (frac[19] - frac[18]));
         SetRect("STATUS_BG_" + IntegerToString(row_index),
                 st_x, y + 1, st_w, row_h - 2, COL_BURN, COL_BURN);
      }
      else
      {
         ObjectDelete(0, PREFIX + "MAGIC_BG_" + IntegerToString(row_index));
         ObjectDelete(0, PREFIX + "STATUS_BG_" + IntegerToString(row_index));
      }

      for(int c = 0; c < 19; c++)
      {
         color cc = COL_TEXT;

         if(c == 0)
            cc = (r < 3 && !burned ? COL_YELLOW : COL_MUTED);

         if(c == 2 && burned) cc = COL_BURN_TEXT;
         if(c == 4) cc = ProfitColor(virtual_balance - InpVirtualCapital);
         if(c == 5) cc = burned ? COL_RED : ProfitColor(virtual_equity - InpVirtualCapital);
         if(c == 6) cc = COL_YELLOW;
         if(c == 7) cc = ProfitColor(s.result_all);
         if(c == 8) cc = ProfitColor(s.floating_profit);
         if(c == 9 || c == 10) cc = COL_MUTED;
         if((c == 11 || c == 12) && current_dd > 0.0) cc = COL_RED;
         if((c == 13 || c == 14) && max_dd > 0.0) cc = COL_RED;
         if(c == 15 && pf > 1.0) cc = COL_GREEN;
         if(c == 16) cc = ProfitColor(exp);

         if(c == 18)
         {
            if(burned) cc = COL_BURN_TEXT;
            else if(status == "ÂM") cc = COL_RED;
            else cc = COL_GREEN;
         }

         int tx = inner_x + (int)MathRound(inner_w * frac[c]) + 5;
         SetLabel("ROW_" + IntegerToString(row_index) + "_C_" + IntegerToString(c),
                  values[c], tx, y + 11, fs, cc);
      }

      y += row_h;
   }

   for(int old = display_rows + 1; old < g_last_drawn_rows; old++)
      DeleteRowObjects(old);

   g_last_drawn_rows = display_rows + 1;

   y += 8;

   string footer1 = "XẾP HẠNG: Profit % / Max DD %. DD hiển thị cả % và USD. Bảng cập nhật mặc định 15 giây/lần.";
   SetLabel("FOOTER_1", ShortText(footer1, 190), inner_x, y, fs_small, COL_MUTED);

   string footer2 = "EQUITY ĐỈNH = Equity ảo cao nhất từng ghi nhận của Magic. "
                  + "Xóa Magic khỏi danh sách = biến mất khỏi bảng; thêm Magic mới = tự đọc lại History của Magic đó.";

   if(magic_count > display_rows)
      footer2 += "  •  Còn " + IntegerToString(magic_count - display_rows) + " Magic chưa hiển thị.";

   SetLabel("FOOTER_2", ShortText(footer2, 190), inner_x,
            y + (int)MathRound(20 * scale), fs_small, COL_YELLOW);

   ChartRedraw(0);
}

//====================================================================
// LÀM MỚI DỮ LIỆU
//====================================================================
void RefreshAll()
{
   datetime now = TimeTradeServer();
   if(now <= 0)
      now = TimeCurrent();

   int dk = DayKey(now);
   int mk = MonthKey(now);

   if(dk != g_last_day_key || mk != g_last_month_key)
      g_history_dirty = true;

   if(g_history_dirty || (now - g_last_history_refresh) >= 30)
      BuildHistoryCache();

   LoadStatsFromHistory();
   ScanOpenPositions();
   ScanPendingOrders();
   CompactActiveStats(now);
   SortStats();
   DrawDashboard();
}

//====================================================================
// SỰ KIỆN EA
//====================================================================
int OnInit()
{
   SaveOriginalChartStyle();
   ApplyMonoChartStyle();

   int timer_sec = MaxInt(1, InpRefreshSeconds);
   EventSetTimer(timer_sec);

   g_history_dirty = true;
   RefreshAll();

   Print("EA MAGIC MONITOR V3.30 TEST: da khoi dong. Chi giam sat, khong can thiep lenh.");
   return INIT_SUCCEEDED;
}
//--------------------------------------------------------------------
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, PREFIX);

   if(InpRestoreChartOnRemove)
      RestoreOriginalChartStyle();

   Print("EA MAGIC MONITOR V3.30 TEST: da dung.");
}
//--------------------------------------------------------------------
void OnTimer()
{
   RefreshAll();
}
//--------------------------------------------------------------------
void OnTick()
{
   // Khong can cap nhat theo moi tick de giam tai.
   // Timer + OnTradeTransaction du de theo doi tai khoan.
}
//--------------------------------------------------------------------
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Thiết kế nhẹ: chỉ đánh dấu dữ liệu thay đổi.
   // Bảng cập nhật ở nhịp Timer kế tiếp (mặc định 15 giây).
   g_history_dirty = true;
}
//--------------------------------------------------------------------
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
      DrawDashboard();
}
//+------------------------------------------------------------------+
