//+------------------------------------------------------------------+
//|                         EA_MAGIC_DASHBOARD_V3_40.mq5             |
//|              Dashboard thong ke EA theo Magic Number - MT5       |
//|                                                                  |
//| Muc dich: CHI GIAM SAT - KHONG GUI / SUA / DONG LENH            |
//|                                                                  |
//| V3.40 (nang cap tu V3.30):                                      |
//|  - Gop nhieu Magic thanh 1 SET (vd EA MASTER: 1601..1604 = 160) |
//|  - Che do SET + chi tiet tung PP ben duoi moi SET               |
//|  - So lenh toi thieu moi duoc xep hang (tranh xep hang do may)  |
//|  - Cot WR% thay cot VON GOC (von da co o the tren cung)          |
//|  - Chi so tinh 1 lan / lan cap nhat (truoc: tinh lai trong sort) |
//|  - Khoa GlobalVariable gom moc von ao -> doi moc = bat dau sach  |
//|  - Xuat CSV bang xep hang de so sanh sau                         |
//+------------------------------------------------------------------+
#property copyright "EA PRO"
#property version   "3.40"
#property description "Bang thong ke cac EA / SET tren MT5 theo Magic Number."
#property description "Chi doc Position / Order / Deal, khong can thiep giao dich."

//====================================================================
// KIỂU LIỆT KÊ
//====================================================================
enum ENUM_CHE_DO_NHOM
{
   NHOM_THEO_MAGIC   = 0, // Theo từng Magic (như V3.30)
   NHOM_THEO_SET     = 1, // Gộp theo SET (Magic / hệ số)
   NHOM_SET_CHI_TIET = 2  // SET + chi tiết từng PP
};

//====================================================================
// INPUT - TOAN BO TEN HIEN THI BANG TIENG VIET CO DAU
//====================================================================
input group "===== NHẬN DIỆN & CẬP NHẬT ====="
input(name="Chu kỳ cập nhật bảng (giây)") int    InpRefreshSeconds = 15;
input(name="Số ngày coi Magic còn hoạt động") int InpActiveDays = 7;
input(name="Bao gồm Magic = 0 (lệnh thủ công)") bool InpIncludeMagic0 = false;
input(name="Danh sách Magic / SET đang chạy") string InpActiveMagics = "";
input(name="Đặt tên EA theo Magic / SET") string InpMagicNames = "";

input group "===== GỘP SET (EA MASTER) ====="
input(name="Chế độ hiển thị") ENUM_CHE_DO_NHOM InpCheDoNhom = NHOM_THEO_MAGIC;
input(name="Hệ số gộp SET (SET = Magic / hệ số)") int InpHeSoSet = 10;

input group "===== VỐN ẢO SO SÁNH SET ====="
input(name="Vốn ảo ban đầu cho mỗi Magic / SET (USD)") double InpVirtualCapital = 5000.0;
input(name="Mốc bắt đầu tính vốn ảo") datetime InpVirtualStart = D'2026.10.01 00:00';
input(name="Giữ trạng thái CHÁY sau khi đã chạm 0") bool InpKeepBurnedState = true;
input(name="Số lệnh tối thiểu để được xếp hạng") int InpMinTrades = 30;

input group "===== XUẤT FILE ====="
input(name="Xuất CSV bảng xếp hạng (MQL5/Files)") bool InpXuatCSV = true;
input(name="Tên file CSV") string InpTenFileCSV = "EA_SET_RANKING.csv";

input group "===== GIAO DIỆN BẢNG ====="
input(name="Số dòng tối đa") int           InpMaxRows = 30;
input(name="Chiều rộng bảng tối đa (pixel)") int InpPanelWidth = 2200;
input(name="Cỡ chữ cơ sở") int             InpFontSize = 11;
input(name="Màu đơn sắc của chart") color  InpChartMonoColor = C'7,10,15';
input(name="Khôi phục màu chart khi gỡ EA") bool InpRestoreChartOnRemove = true;

//====================================================================
// HẰNG SỐ GIAO DIỆN
//====================================================================
const string PREFIX = "MAGIC_MONITOR_V340_";

const color COL_PANEL       = C'15,20,29';
const color COL_PANEL_2     = C'20,27,39';
const color COL_HEADER      = C'28,38,54';
const color COL_ROW_A       = C'18,24,34';
const color COL_ROW_B       = C'21,28,39';
const color COL_ROW_DETAIL  = C'12,16,24';
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
   long     magic;      // Magic (chế độ 0) hoặc mã SET (chế độ 1/2)
   bool     is_set;     // dòng gộp từ nhiều Magic
   int      level;      // 0 = dòng chính, 1 = dòng chi tiết PP
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

   //--- chỉ số tính 1 lần mỗi lượt cập nhật
   double   m_equity;
   double   m_peak;
   double   m_dd_pct;
   double   m_dd_usd;
   double   m_maxdd_pct;
   double   m_maxdd_usd;
   double   m_pf;
   double   m_exp;
   double   m_wr;
   double   m_score;
   bool     m_burned;
   bool     m_ranked;
};

MagicStat g_hist[];
MagicStat g_stats[];
MagicStat g_raw[];     // dữ liệu từng Magic trước khi gộp SET
MagicStat g_rows[];    // các dòng hiển thị
int       g_row_rank[];

bool      g_history_dirty = true;
datetime  g_last_history_refresh = 0;
int       g_last_day_key = -1;
int       g_last_month_key = -1;
int       g_last_drawn_rows = 0;
datetime  g_last_csv = 0;

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
bool IsGroupMode()
{
   return (InpCheDoNhom != NHOM_THEO_MAGIC);
}
//--------------------------------------------------------------------
long SetFactor()
{
   return (InpHeSoSet >= 2 ? (long)InpHeSoSet : 10);
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
   s.is_set            = false;
   s.level             = 0;
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
   s.m_equity          = 0.0;
   s.m_peak            = 0.0;
   s.m_dd_pct          = 0.0;
   s.m_dd_usd          = 0.0;
   s.m_maxdd_pct       = 0.0;
   s.m_maxdd_usd       = 0.0;
   s.m_pf              = 0.0;
   s.m_exp             = 0.0;
   s.m_wr              = 0.0;
   s.m_score           = 0.0;
   s.m_burned          = false;
   s.m_ranked          = false;
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
// DANH SÁCH MAGIC / SET ĐANG CHẠY
//====================================================================
bool HasActiveMagicFilter()
{
   string s = TrimText(InpActiveMagics);
   return (s != "");
}
//--------------------------------------------------------------------
// Id có nằm trong danh sách InpActiveMagics không
bool IsListed(const long id)
{
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

      if((long)StringToInteger(s) == id)
         return true;
   }

   return false;
}
//--------------------------------------------------------------------
// Magic thô có được theo dõi không (chế độ SET: chấp nhận cả Magic / hệ số)
bool IsActiveMagic(const long magic)
{
   if(!HasActiveMagicFilter())
      return true;

   if(IsListed(magic))
      return true;

   if(IsGroupMode() && IsListed(magic / SetFactor()))
      return true;

   return false;
}
//--------------------------------------------------------------------
// Mã nhóm của 1 Magic thô. Magic được liệt kê nguyên dạng thì giữ nguyên
// (để theo dõi chung EA thường với SET EA MASTER).
long GroupIdOf(const long magic)
{
   if(!IsGroupMode())
      return magic;

   if(HasActiveMagicFilter() && IsListed(magic))
      return magic;

   return magic / SetFactor();
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
// TÊN EA THEO MAGIC / SET
// InpMagicNames vi du:
// 68999=DAVID HUNTER;160=S01 PP1 RSI M1;1601=PP1 RSI
//====================================================================
bool FindCustomName(const long id, string &name)
{
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
      if(m == id)
      {
         name = TrimText(kv[1]);
         return true;
      }
   }

   return false;
}
//--------------------------------------------------------------------
string GetRowName(const MagicStat &s)
{
   if(s.level == 0 && s.magic == 0)
      return "THỦ CÔNG";

   string name = "";
   if(FindCustomName(s.magic, name))
      return ShortText(name, 28);

   if(s.level == 1)
      return "PP" + IntegerToString((int)(s.magic % SetFactor())) + " (#" + MagicText(s.magic) + ")";

   if(s.is_set)
      return "SET #" + MagicText(s.magic);

   return "EA #" + MagicText(s.magic);
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

   if(!IsGroupMode())
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
// GỘP MAGIC THÀNH SET
//====================================================================
void MergeStat(MagicStat &t, const MagicStat &s)
{
   string parts[];
   ushort bar = StringGetCharacter("|", 0);
   int n = StringSplit(s.symbols, bar, parts);
   for(int i = 0; i < n; i++)
      AddSymbol(t, parts[i]);

   t.open_positions   += s.open_positions;
   t.buy_positions    += s.buy_positions;
   t.sell_positions   += s.sell_positions;
   t.open_lots        += s.open_lots;
   t.pending_orders   += s.pending_orders;
   t.pending_lots     += s.pending_lots;
   t.floating_profit  += s.floating_profit;
   t.swap_open        += s.swap_open;
   t.result_today     += s.result_today;
   t.result_month     += s.result_month;
   t.result_all       += s.result_all;
   t.exits_today      += s.exits_today;
   t.wins_today       += s.wins_today;
   t.losses_today     += s.losses_today;
   t.exits_all        += s.exits_all;
   t.wins_all         += s.wins_all;
   t.losses_all       += s.losses_all;
   t.gross_profit_all += s.gross_profit_all;
   t.gross_loss_all   += s.gross_loss_all;
   t.closed_lots_all  += s.closed_lots_all;

   if(s.last_deal_time > t.last_deal_time)
      t.last_deal_time = s.last_deal_time;
}
//--------------------------------------------------------------------
void GroupStats()
{
   int n = ArraySize(g_stats);
   ArrayResize(g_raw, n);
   for(int i = 0; i < n; i++)
      g_raw[i] = g_stats[i];

   MagicStat groups[];
   ArrayResize(groups, 0);

   for(int i = 0; i < n; i++)
   {
      long gid = GroupIdOf(g_raw[i].magic);
      int idx = EnsureMagic(groups, gid);
      if(idx < 0)
         continue;

      if(gid != g_raw[i].magic)
         groups[idx].is_set = true;

      MergeStat(groups[idx], g_raw[i]);
   }

   AddActiveMagics(groups);

   int m = ArraySize(groups);
   ArrayResize(g_stats, m);
   for(int i = 0; i < m; i++)
      g_stats[i] = groups[i];
}

//====================================================================
// LỌC MAGIC / SET CẦN HIỂN THỊ
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
         keep = (IsGroupMode() ? IsListed(g_stats[i].magic) : IsActiveMagic(g_stats[i].magic));
      }
      else
      {
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
// VỐN ẢO / EQUITY ẢO / TRẠNG THÁI CHÁY
// Khóa GlobalVariable gồm loại dòng + mốc vốn ảo:
// đổi "Mốc bắt đầu tính vốn ảo" = bắt đầu đo DD/đỉnh mới, không lẫn số cũ.
//====================================================================
string VirtualKey(const MagicStat &s, const string suffix)
{
   long login = AccountInfoInteger(ACCOUNT_LOGIN);
   string kind = (s.level == 1 ? "P" : (s.is_set ? "S" : "M"));
   return "MMV340_" + StringFormat("%I64d", login) + "_" + kind + MagicText(s.magic)
          + "_" + IntegerToString((long)InpVirtualStart) + "_" + suffix;
}
//--------------------------------------------------------------------
double GVMax(const string key, const double value)
{
   double v = value;
   if(GlobalVariableCheck(key))
      v = MathMax(v, GlobalVariableGet(key));
   GlobalVariableSet(key, v);
   return v;
}
//--------------------------------------------------------------------
// Tính toàn bộ chỉ số của 1 dòng (gọi 1 lần mỗi lượt cập nhật)
void ComputeMetrics(MagicStat &s)
{
   double cap = InpVirtualCapital;
   double eq  = cap + s.result_all + s.floating_profit;
   s.m_equity = eq;

   s.m_peak = GVMax(VirtualKey(s, "PEAK"), MathMax(cap, eq));

   s.m_dd_usd = (eq < s.m_peak ? s.m_peak - eq : 0.0);
   s.m_dd_pct = (s.m_peak > 0.0 ? s.m_dd_usd / s.m_peak * 100.0 : 0.0);

   s.m_maxdd_pct = GVMax(VirtualKey(s, "MAXDD"), s.m_dd_pct);
   s.m_maxdd_usd = GVMax(VirtualKey(s, "MAXDDUSD"), s.m_dd_usd);

   bool burned = (eq <= 0.0);
   string burn_key = VirtualKey(s, "BURN");
   if(InpKeepBurnedState && GlobalVariableCheck(burn_key) && GlobalVariableGet(burn_key) > 0.5)
      burned = true;
   if(InpKeepBurnedState && eq <= 0.0)
      GlobalVariableSet(burn_key, 1.0);
   s.m_burned = burned;

   if(s.gross_loss_all > 0.000001)
      s.m_pf = s.gross_profit_all / s.gross_loss_all;
   else if(s.gross_profit_all > 0.000001)
      s.m_pf = 99.99;
   else
      s.m_pf = 0.0;

   s.m_exp = (s.exits_all > 0 ? s.result_all / (double)s.exits_all : 0.0);
   s.m_wr  = (s.exits_all > 0 ? 100.0 * s.wins_all / (double)s.exits_all : 0.0);

   s.m_ranked = (s.exits_all >= MaxInt(0, InpMinTrades));

   if(burned)
      s.m_score = -1000000.0;
   else
   {
      double profit_pct = (cap > 0.0 ? (eq - cap) / cap * 100.0 : 0.0);
      // Recovery-style: lợi nhuận % trên mỗi 1% Max DD (sàn 1% để SET mới không bị vô hạn)
      s.m_score = profit_pct / MathMax(1.0, s.m_maxdd_pct);
   }
}

//====================================================================
// XẾP HẠNG: HIỆU QUẢ THỰC CHIẾN
// Cháy -> cuối. Chưa đủ lệnh -> dưới các SET đủ lệnh.
// Sau đó: Score -> PF -> Expectancy -> số lệnh.
//====================================================================
bool ComesBefore(const MagicStat &a, const MagicStat &b)
{
   if(a.m_burned != b.m_burned)
      return !a.m_burned;

   if(a.m_ranked != b.m_ranked)
      return a.m_ranked;

   if(MathAbs(a.m_score - b.m_score) > 0.000001)
      return (a.m_score > b.m_score);

   if(MathAbs(a.m_pf - b.m_pf) > 0.000001)
      return (a.m_pf > b.m_pf);

   if(MathAbs(a.m_exp - b.m_exp) > 0.000001)
      return (a.m_exp > b.m_exp);

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
//--------------------------------------------------------------------
void AppendRow(MagicStat &s, const int rank)
{
   int n = ArraySize(g_rows);
   ArrayResize(g_rows, n + 1);
   ArrayResize(g_row_rank, n + 1);
   g_rows[n] = s;
   g_row_rank[n] = rank;
}
//--------------------------------------------------------------------
void BuildDisplayRows()
{
   ArrayResize(g_rows, 0);
   ArrayResize(g_row_rank, 0);

   int n = ArraySize(g_stats);
   for(int i = 0; i < n; i++)
   {
      AppendRow(g_stats[i], i + 1);

      if(InpCheDoNhom != NHOM_SET_CHI_TIET || !g_stats[i].is_set)
         continue;

      //--- dòng chi tiết từng Magic của SET, sắp theo Magic tăng dần
      MagicStat det[];
      ArrayResize(det, 0);
      int nr = ArraySize(g_raw);
      for(int k = 0; k < nr; k++)
      {
         if(g_raw[k].magic == g_stats[i].magic)
            continue;
         if(GroupIdOf(g_raw[k].magic) != g_stats[i].magic)
            continue;

         int d = ArraySize(det);
         ArrayResize(det, d + 1);
         det[d] = g_raw[k];
         det[d].level = 1;
         det[d].is_set = false;
         ComputeMetrics(det[d]);
      }

      int nd = ArraySize(det);
      for(int a = 0; a < nd - 1; a++)
         for(int b = a + 1; b < nd; b++)
            if(det[b].magic < det[a].magic)
            {
               MagicStat tmp = det[a];
               det[a] = det[b];
               det[b] = tmp;
            }

      for(int a = 0; a < nd; a++)
         AppendRow(det[a], 0);
   }
}

//====================================================================
// XUẤT CSV (MQL5/Files) - dùng để so sánh các SET sau này
//====================================================================
string StatusText(const MagicStat &s)
{
   if(s.m_burned)
      return "CHÁY";
   if(s.level == 0 && !s.m_ranked)
      return "ÍT LỆNH";
   if(s.m_equity < InpVirtualCapital)
      return "ÂM";
   return "RUN";
}
//--------------------------------------------------------------------
void WriteCSV()
{
   if(!InpXuatCSV || InpTenFileCSV == "")
      return;

   int h = FileOpen(InpTenFileCSV, FILE_WRITE | FILE_TXT | FILE_UNICODE);
   if(h == INVALID_HANDLE)
   {
      Print("Dashboard: không ghi được file CSV ", InpTenFileCSV, " (lỗi ", GetLastError(), ")");
      return;
   }

   datetime now = TimeTradeServer();
   if(now <= 0) now = TimeCurrent();

   FileWriteString(h, "Cap nhat;" + TimeToString(now, TIME_DATE | TIME_SECONDS)
                      + ";Von ao;" + DoubleToString(InpVirtualCapital, 2)
                      + ";Tu moc;" + TimeToString(InpVirtualStart, TIME_DATE | TIME_MINUTES) + "\r\n");
   FileWriteString(h, "Hang;Cap;Id;Ten;So lenh;WR%;PF;Expectancy;PL chot;Float;Equity ao;"
                      + "Equity dinh;DD HT%;Max DD%;Max DD $;Score;Lot da dong;Trang thai\r\n");

   int n = ArraySize(g_rows);
   for(int i = 0; i < n; i++)
   {
      MagicStat s = g_rows[i];
      string line = (g_row_rank[i] > 0 ? IntegerToString(g_row_rank[i]) : "")
                  + ";" + (s.level == 1 ? "PP" : (s.is_set ? "SET" : "MAGIC"))
                  + ";" + MagicText(s.magic)
                  + ";" + GetRowName(s)
                  + ";" + IntegerToString(s.exits_all)
                  + ";" + DoubleToString(s.m_wr, 1)
                  + ";" + DoubleToString(s.m_pf, 2)
                  + ";" + DoubleToString(s.m_exp, 2)
                  + ";" + DoubleToString(s.result_all, 2)
                  + ";" + DoubleToString(s.floating_profit, 2)
                  + ";" + DoubleToString(s.m_equity, 2)
                  + ";" + DoubleToString(s.m_peak, 2)
                  + ";" + DoubleToString(s.m_dd_pct, 2)
                  + ";" + DoubleToString(s.m_maxdd_pct, 2)
                  + ";" + DoubleToString(s.m_maxdd_usd, 2)
                  + ";" + DoubleToString(s.m_score, 3)
                  + ";" + DoubleToString(s.closed_lots_all, 2)
                  + ";" + StatusText(s) + "\r\n";
      FileWriteString(h, line);
   }

   FileClose(h);
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
   int panel_w = MinInt(chart_w, MaxInt(800, InpPanelWidth));
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

   bool group_mode = IsGroupMode();
   string unit = (group_mode ? "SET" : "Magic");

   int y = panel_y + pad;
   SetLabel("TITLE", "EA SET RANKING  •  HIỆU QUẢ THỰC CHIẾN", inner_x, y, fs_title, COL_TEXT);

   string subtitle = "Chỉ hiển thị " + unit + " đang chạy  •  Mỗi " + unit + " = "
                   + DoubleToString(InpVirtualCapital, 0)
                   + " USD vốn ảo  •  Xếp hạng khi đủ " + IntegerToString(InpMinTrades)
                   + " lệnh  •  Tiền demo thật chỉ dùng làm margin.";

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
      if(g_stats[i].m_burned) burned_count++;
      else running_count++;

      total_virtual_equity += g_stats[i].m_equity;
      total_closed += g_stats[i].result_all;
      total_float += g_stats[i].floating_profit;
   }

   string top_name = "-";
   if(magic_count > 0 && g_stats[0].m_ranked && !g_stats[0].m_burned)
      top_name = "#" + MagicText(g_stats[0].magic);

   string card_titles[6];
   card_titles[0] = "VỐN ẢO / " + (group_mode ? "SET" : "MAGIC");
   card_titles[1] = (group_mode ? "SET ĐANG CHẠY" : "MAGIC ĐANG CHẠY");
   card_titles[2] = "SET CHƯA CHÁY";
   card_titles[3] = "SET ĐÃ CHÁY";
   card_titles[4] = "TỔNG EQUITY ẢO";
   card_titles[5] = "TOP (ĐỦ LỆNH)";

   string card_values[6];
   card_values[0] = DoubleToString(InpVirtualCapital, 0) + " USD";
   card_values[1] = IntegerToString(magic_count);
   card_values[2] = IntegerToString(running_count);
   card_values[3] = IntegerToString(burned_count);
   card_values[4] = DoubleToString(total_virtual_equity, 2);
   card_values[5] = top_name;

   color card_colors[6];
   card_colors[0] = COL_TEXT;
   card_colors[1] = COL_BLUE;
   card_colors[2] = COL_GREEN;
   card_colors[3] = (burned_count > 0 ? COL_RED : COL_MUTED);
   card_colors[4] = ProfitColor(total_closed + total_float);
   card_colors[5] = COL_YELLOW;

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

   int row_count = ArraySize(g_rows);
   int display_rows = MinInt(row_count, InpMaxRows);
   display_rows = MinInt(display_rows, max_rows_by_height);

   SetRect("TABLE_HEADER", inner_x, y, inner_w, header_h, COL_HEADER, COL_BORDER);

   double frac[20] =
   {
      0.000, // TOP
      0.037, // TEN
      0.137, // MAGIC
      0.202, // WR
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
      "MAGIC / SET",
      "WR%",
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
      MagicStat s = g_rows[r];
      int  rank   = g_row_rank[r];
      bool detail = (s.level == 1);

      double virtual_balance = InpVirtualCapital + s.result_all;
      bool burned = (!detail && s.m_burned);
      string status = StatusText(s);

      string values[19];
      values[0]  = (detail ? "  ↳" : "#" + IntegerToString(rank));
      values[1]  = ShortText((detail ? "   " : "") + GetRowName(s), 22);
      values[2]  = MagicText(s.magic);
      values[3]  = (s.exits_all > 0 ? DoubleToString(s.m_wr, 1) + "%" : "-");
      values[4]  = DoubleToString(virtual_balance, 2);
      values[5]  = DoubleToString(s.m_equity, 2);
      values[6]  = DoubleToString(s.m_peak, 2);
      values[7]  = MoneyText(s.result_all);
      values[8]  = MoneyText(s.floating_profit);
      values[9]  = DoubleToString(s.open_lots, 2);
      values[10] = DoubleToString(s.closed_lots_all, 2);
      values[11] = DoubleToString(s.m_dd_pct, 2) + "%";
      values[12] = DoubleToString(s.m_dd_usd, 2);
      values[13] = DoubleToString(s.m_maxdd_pct, 2) + "%";
      values[14] = DoubleToString(s.m_maxdd_usd, 2);
      values[15] = (s.m_pf >= 99.0 ? "∞" : DoubleToString(s.m_pf, 2));
      values[16] = DoubleToString(s.m_exp, 2);
      values[17] = IntegerToString(s.exits_all);
      values[18] = (detail ? "" : status);

      int row_index = r + 1;
      color row_bg = ((r % 2) == 0 ? COL_ROW_A : COL_ROW_B);

      if(detail)
         row_bg = COL_ROW_DETAIL;
      else if(s.m_ranked && !burned && rank == 1) row_bg = COL_TOP1;
      else if(s.m_ranked && !burned && rank == 2) row_bg = COL_TOP2;
      else if(s.m_ranked && !burned && rank == 3) row_bg = COL_TOP3;

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
         color cc = (detail ? COL_MUTED : COL_TEXT);

         if(c == 0)
            cc = (!detail && rank <= 3 && s.m_ranked && !burned ? COL_YELLOW : COL_MUTED);

         if(c == 2 && burned) cc = COL_BURN_TEXT;
         if(c == 3 && s.exits_all > 0) cc = (s.m_wr >= 50.0 ? COL_GREEN : COL_TEXT);
         if(c == 4) cc = ProfitColor(virtual_balance - InpVirtualCapital);
         if(c == 5) cc = burned ? COL_RED : ProfitColor(s.m_equity - InpVirtualCapital);
         if(c == 6 && !detail) cc = COL_YELLOW;
         if(c == 7) cc = ProfitColor(s.result_all);
         if(c == 8) cc = ProfitColor(s.floating_profit);
         if(c == 9 || c == 10) cc = COL_MUTED;
         if((c == 11 || c == 12) && s.m_dd_pct > 0.0) cc = COL_RED;
         if((c == 13 || c == 14) && s.m_maxdd_pct > 0.0) cc = COL_RED;
         if(c == 15 && s.m_pf > 1.0) cc = COL_GREEN;
         if(c == 16) cc = ProfitColor(s.m_exp);

         if(c == 18)
         {
            if(burned) cc = COL_BURN_TEXT;
            else if(status == "ÂM") cc = COL_RED;
            else if(status == "ÍT LỆNH") cc = COL_YELLOW;
            else cc = COL_GREEN;
         }

         int tx = inner_x + (int)MathRound(inner_w * frac[c]) + 5;
         SetLabel("ROW_" + IntegerToString(row_index) + "_C_" + IntegerToString(c),
                  values[c], tx, y + 11, (detail ? fs_small : fs), cc);
      }

      y += row_h;
   }

   for(int old = display_rows + 1; old < g_last_drawn_rows; old++)
      DeleteRowObjects(old);

   g_last_drawn_rows = display_rows + 1;

   y += 8;

   string footer1 = "XẾP HẠNG: Profit % / Max DD % (chỉ " + unit + " đủ " + IntegerToString(InpMinTrades)
                  + " lệnh; ÍT LỆNH xếp sau). Max DD được lấy mẫu mỗi lần cập nhật bảng.";
   SetLabel("FOOTER_1", ShortText(footer1, 190), inner_x, y, fs_small, COL_MUTED);

   string footer2 = "EQUITY ĐỈNH = Equity ảo cao nhất từng ghi nhận. Đổi Mốc vốn ảo = đo lại từ đầu.";
   if(group_mode)
      footer2 += " SET = Magic / " + IntegerToString((int)SetFactor()) + ".";
   if(InpXuatCSV)
      footer2 += " CSV: MQL5/Files/" + InpTenFileCSV;

   if(row_count > display_rows)
      footer2 += "  •  Còn " + IntegerToString(row_count - display_rows) + " dòng chưa hiển thị.";

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

   if(IsGroupMode())
      GroupStats();
   else
      ArrayResize(g_raw, 0);

   CompactActiveStats(now);

   int n = ArraySize(g_stats);
   for(int i = 0; i < n; i++)
      ComputeMetrics(g_stats[i]);

   SortStats();
   BuildDisplayRows();
   DrawDashboard();

   if(InpXuatCSV && (now - g_last_csv) >= 60)
   {
      WriteCSV();
      g_last_csv = now;
   }
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
   g_last_csv = 0;
   RefreshAll();

   Print("EA MAGIC MONITOR V3.40: da khoi dong. Chi giam sat, khong can thiep lenh.");
   return INIT_SUCCEEDED;
}
//--------------------------------------------------------------------
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(InpXuatCSV)
      WriteCSV();
   ObjectsDeleteAll(0, PREFIX);

   if(InpRestoreChartOnRemove)
      RestoreOriginalChartStyle();

   Print("EA MAGIC MONITOR V3.40: da dung.");
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
}
//--------------------------------------------------------------------
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
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
