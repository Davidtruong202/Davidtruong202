//+------------------------------------------------------------------+
//|                                       DAVID_CRT_V1_BASELINE.mq5  |
//|  DAVID CRT V1 BASELINE - Candle Range Theory                     |
//|                                                                  |
//|  H4[1] (vừa đóng)  = Reference Candle -> CRT High / CRT Low      |
//|  H4[0] (đang chạy) = Active H4 -> tìm Sweep (realtime)           |
//|  M15[1] (vừa đóng) = Confirmation (Close quay lại trong Range)   |
//|                                                                  |
//|  Bản Baseline: KHÔNG FVG, OB, EMA, RSI, MACD, ADX, MSS/CHOCH,    |
//|  Session, News, BE, Trailing, Partial, DCA, Grid, Martingale,    |
//|  Hedge. Timeframe chiến lược cố định PERIOD_H4 / PERIOD_M15,     |
//|  không phụ thuộc _Period của chart.                              |
//+------------------------------------------------------------------+
#property copyright   "David Truong"
#property version     "1.00"
#property description "DAVID CRT V1 BASELINE - Candle Range Theory (H4 Range + M15 Confirmation)"

#include <Trade\Trade.mqh>

//--- Timeframe cố định của chiến lược (KHÔNG BAO GIỜ dùng _Period)
#define CRT_TF_RANGE    PERIOD_H4
#define CRT_TF_CONFIRM  PERIOD_M15
#define CRT_TF_REPLAY   PERIOD_M1
#define CRT_PREFIX      "DAVIDCRT_"
#define CRT_EA_NAME     "DAVID CRT V1 BASELINE"

//====================================================================
// INPUT (tên hiển thị tiếng Việt nằm ở comment phía sau mỗi input)
//====================================================================
input group "=== CHUNG ==="
input ulong  InpMagic             = 71001;  // Magic_Number
input uint   InpDeviationPoints   = 50;     // Độ_trượt_giá_tối_đa_(points)

input group "=== KHỐI LƯỢNG & RỦI RO ==="
input double InpFixedLot          = 0.01;   // Khối_lượng_cố_định
input bool   InpUseRiskEquity     = false;  // Sử_dụng_Risk_Theo_Equity
input double InpRiskPercent       = 1.0;    // Rủi_ro_mỗi_lệnh_%

input group "=== SL & BỘ LỌC (đơn vị GIÁ, 0 = tắt) ==="
input double InpSLBuffer          = 0.0;    // Khoảng_đệm_SL (giá)
input double InpMaxSpread         = 0.50;   // Spread_tối_đa (giá, 0 = tắt)
input double InpMinSweep          = 0.0;    // Sweep_tối_thiểu (giá, 0 = tắt)
input double InpMaxSweep          = 0.0;    // Sweep_tối_đa (giá, 0 = tắt)
input double InpMinRR             = 0.0;    // RR_tối_thiểu (0 = tắt)
input bool   InpAllowBuy          = true;   // Cho_phép_BUY
input bool   InpAllowSell         = true;   // Cho_phép_SELL

input group "=== HIỂN THỊ ==="
input bool   InpShowCRT           = true;   // Hiển_thị_CRT_trên_Chart
input bool   InpShowReference     = true;   // Hiển_thị_Reference_H4
input int    InpHistoryCount      = 100;    // Số_setup_lịch_sử_hiển_thị

input group "=== LOG ==="
input bool   InpDebug             = true;   // Chế_độ_Debug_CRT
input bool   InpVerboseLog        = true;   // Ghi_Log_Chi_Tiết

//====================================================================
// ENUM
//====================================================================
enum ENUM_CRT_BIAS
{
   CRT_BIAS_NONE = 0,
   CRT_BIAS_BUY  = 1,
   CRT_BIAS_SELL = 2,
   CRT_BIAS_BOTH = 3
};

enum ENUM_CRT_STATUS
{
   ST_WAITING_RANGE = 0,
   ST_WAITING_SWEEP,
   ST_LOW_SWEPT,          // Low đã bị sweep nhưng BUY không được phép (bias / input)
   ST_HIGH_SWEPT,         // High đã bị sweep nhưng SELL không được phép (bias / input)
   ST_WAITING_M15,        // Đã sweep đúng phía có quyền trade, chờ M15 đóng trong Range
   ST_BUY_CONFIRMED,
   ST_SELL_CONFIRMED,
   ST_BUY_ACTIVE,
   ST_SELL_ACTIVE,
   ST_TRADED,
   ST_INVALID_BOTH,
   ST_EXPIRED,
   ST_RANGE_ERROR,
   ST_SIGNAL_SKIPPED      // Có tín hiệu nhưng bị bỏ do bộ lọc / lỗi broker / offline (Range đã dùng)
};

//====================================================================
// STATE CỦA RANGE ĐANG HOẠT ĐỘNG
//====================================================================
struct CRTState
{
   bool     valid;
   datetime refTime;          // Open time của H4[1] (Reference)
   datetime refEnd;           // refTime + 4h
   datetime activeStart;      // Open time của H4[0] (Active)
   datetime activeEnd;        // activeStart + 4h
   double   crtHigh;          // High H4[1] - KHÓA
   double   crtLow;           // Low  H4[1] - KHÓA
   double   h2High;           // High H4[2]
   double   h2Low;            // Low  H4[2]
   int      bias;             // ENUM_CRT_BIAS

   bool     lowSwept;
   bool     highSwept;
   double   sweepLow;
   double   sweepHigh;
   datetime sweepLowTime;
   datetime sweepHighTime;

   bool     confirmed;
   int      confirmDir;       // +1 BUY, -1 SELL
   datetime confirmBarTime;   // Open time của nến M15 xác nhận
   double   confirmClose;

   bool     traded;
   int      tradeDir;
   ulong    positionId;
   datetime entryTime;
   double   entryPrice;       // Giá khớp thực tế
   double   slPrice;
   double   tpPrice;
   double   rr;
   double   lots;

   int      status;           // ENUM_CRT_STATUS
   string   skipReason;

   datetime lastM1Processed;  // M1 đã đóng cuối cùng được quét sweep
   datetime lastM15Processed; // M15 đã đóng cuối cùng được xét confirmation
};

//====================================================================
// GLOBAL
//====================================================================
CTrade   g_trade;
CRTState g;
bool     g_ready          = false;
bool     g_dirty          = false;
bool     g_isTester       = false;
bool     g_drawEnabled    = true;
datetime g_lastM1Seen     = 0;
datetime g_lastDashboard  = 0;
double   g_point          = 0.0;
string   g_stateFile      = "";

//====================================================================
// TIỆN ÍCH SO SÁNH GIÁ (tránh sai số double, vẫn giữ quy tắc < / > tuyệt đối)
//====================================================================
double PriceEps()                      { return g_point * 0.5; }
bool   PriceLess(double a, double b)   { return (a < b - PriceEps()); }
bool   PriceGreater(double a, double b){ return (a > b + PriceEps()); }
bool   PriceEqual(double a, double b)  { return (MathAbs(a - b) <= PriceEps()); }

string Px(double p)        { return DoubleToString(p, _Digits); }
string TimeHM(datetime t)  { return (t <= 0 ? "-" : StringSubstr(TimeToString(t, TIME_DATE | TIME_MINUTES), 11)); }
string TimeFull(datetime t){ return (t <= 0 ? "-" : TimeToString(t, TIME_DATE | TIME_MINUTES)); }
string YesNo(bool b)       { return (b ? "YES" : "NO"); }

string RangeId(datetime refTime)
{
   MqlDateTime d;
   TimeToStruct(refTime, d);
   return StringFormat("%04d%02d%02d_%02d%02d", d.year, d.mon, d.day, d.hour, d.min);
}

string ObjName(string type)
{
   return CRT_PREFIX + type + "_" + _Symbol + "_" + RangeId(g.refTime);
}

string StatusText(int s)
{
   switch(s)
   {
      case ST_WAITING_RANGE:  return "WAITING RANGE";
      case ST_WAITING_SWEEP:  return "WAITING SWEEP";
      case ST_LOW_SWEPT:      return "LOW SWEPT";
      case ST_HIGH_SWEPT:     return "HIGH SWEPT";
      case ST_WAITING_M15:    return "WAITING M15 CONFIRM";
      case ST_BUY_CONFIRMED:  return "BUY CONFIRMED";
      case ST_SELL_CONFIRMED: return "SELL CONFIRMED";
      case ST_BUY_ACTIVE:     return "BUY ACTIVE";
      case ST_SELL_ACTIVE:    return "SELL ACTIVE";
      case ST_TRADED:         return "TRADED";
      case ST_INVALID_BOTH:   return "INVALID BOTH SIDES";
      case ST_EXPIRED:        return "EXPIRED";
      case ST_RANGE_ERROR:    return "RANGE ERROR";
      case ST_SIGNAL_SKIPPED: return "SIGNAL SKIPPED";
   }
   return "UNKNOWN";
}

string BiasText(int b)
{
   switch(b)
   {
      case CRT_BIAS_BUY:  return "BUY";
      case CRT_BIAS_SELL: return "SELL";
      case CRT_BIAS_BOTH: return "BOTH";
   }
   return "NONE";
}

bool BuyPermitted()  { return (InpAllowBuy  && (g.bias == CRT_BIAS_BUY  || g.bias == CRT_BIAS_BOTH)); }
bool SellPermitted() { return (InpAllowSell && (g.bias == CRT_BIAS_SELL || g.bias == CRT_BIAS_BOTH)); }

//--- Range còn sống: được phép cập nhật sweep / xét confirmation / vào lệnh
bool RangeIsLive()
{
   if(!g.valid || g.traded)
      return false;
   return (g.status == ST_WAITING_SWEEP || g.status == ST_LOW_SWEPT ||
           g.status == ST_HIGH_SWEPT    || g.status == ST_WAITING_M15);
}

//====================================================================
// LOG
//====================================================================
void WriteCRTLog(string msg, bool detailOnly = false)
{
   if(detailOnly && !InpVerboseLog)
      return;
   Print("[DAVID CRT] ", msg);
}

void WriteCRTDebug(string msg)
{
   if(!InpDebug)
      return;
   Print("[CRT DEBUG] ", msg);
}

void MarkDirty() { g_dirty = true; }

//====================================================================
// RESET STATE
//====================================================================
void ResetState()
{
   g.valid            = false;
   g.refTime          = 0;
   g.refEnd           = 0;
   g.activeStart      = 0;
   g.activeEnd        = 0;
   g.crtHigh          = 0.0;
   g.crtLow           = 0.0;
   g.h2High           = 0.0;
   g.h2Low            = 0.0;
   g.bias             = CRT_BIAS_NONE;
   g.lowSwept         = false;
   g.highSwept        = false;
   g.sweepLow         = 0.0;
   g.sweepHigh        = 0.0;
   g.sweepLowTime     = 0;
   g.sweepHighTime    = 0;
   g.confirmed        = false;
   g.confirmDir       = 0;
   g.confirmBarTime   = 0;
   g.confirmClose     = 0.0;
   g.traded           = false;
   g.tradeDir         = 0;
   g.positionId       = 0;
   g.entryTime        = 0;
   g.entryPrice       = 0.0;
   g.slPrice          = 0.0;
   g.tpPrice          = 0.0;
   g.rr               = 0.0;
   g.lots             = 0.0;
   g.status           = ST_WAITING_RANGE;
   g.skipReason       = "";
   g.lastM1Processed  = 0;
   g.lastM15Processed = 0;
}

//====================================================================
// H4: PHÁT HIỆN CÂY H4 MỚI
// Trả về true khi H4[0] (theo đúng timestamp broker) khác Active hiện tại.
//====================================================================
bool DetectNewH4Bar()
{
   datetime h4Open0 = iTime(_Symbol, CRT_TF_RANGE, 0);
   if(h4Open0 <= 0)
      return false;               // dữ liệu H4 chưa sẵn sàng
   return (h4Open0 > g.activeStart);
}

//====================================================================
// H4: ĐỌC H4[0], H4[1], H4[2] (rates[0]=H4[0], rates[1]=H4[1], rates[2]=H4[2])
//====================================================================
bool LoadReferenceH4(MqlRates &h4[])
{
   ArraySetAsSeries(h4, true);
   ResetLastError();
   int copied = CopyRates(_Symbol, CRT_TF_RANGE, 0, 3, h4);
   if(copied != 3)
   {
      WriteCRTLog(StringFormat("CopyRates H4 thất bại (copied=%d, err=%d) - thử lại tick sau", copied, GetLastError()), true);
      return false;
   }
   if(!(h4[0].time > h4[1].time && h4[1].time > h4[2].time))
   {
      WriteCRTLog("Dữ liệu H4 sai thứ tự thời gian - thử lại tick sau", true);
      return false;
   }
   return true;
}

//====================================================================
// H4: BIAS - High H4[1] > High H4[2] => BUY ; Low H4[1] < Low H4[2] => SELL
//====================================================================
int DetectH4Bias(double h1High, double h1Low, double h2High, double h2Low)
{
   bool buy  = PriceGreater(h1High, h2High);
   bool sell = PriceLess(h1Low, h2Low);
   if(buy && sell) return CRT_BIAS_BOTH;
   if(buy)         return CRT_BIAS_BUY;
   if(sell)        return CRT_BIAS_SELL;
   return CRT_BIAS_NONE;
}

//====================================================================
// TẠO CRT RANGE TỪ H4[1] - chỉ gọi khi H4 mới bắt đầu (H4[1] đã đóng)
//====================================================================
void CreateCRTRange(const MqlRates &h4[])
{
   ResetState();
   int h4Sec = PeriodSeconds(CRT_TF_RANGE);

   g.refTime     = h4[1].time;
   g.refEnd      = h4[1].time + h4Sec;
   g.activeStart = h4[0].time;
   g.activeEnd   = h4[0].time + h4Sec;

   //--- CHỈ High / Low của Reference. Không Open/Close, không 50%, không ATR, không buffer.
   g.crtHigh = h4[1].high;
   g.crtLow  = h4[1].low;
   g.h2High  = h4[2].high;
   g.h2Low   = h4[2].low;

   g.lastM1Processed  = g.activeStart - PeriodSeconds(CRT_TF_REPLAY);
   g.lastM15Processed = 0;

   if(!(PriceGreater(g.crtHigh, g.crtLow)))
   {
      g.valid  = false;
      g.status = ST_RANGE_ERROR;
      WriteCRTLog(StringFormat("RANGE ERROR: Reference %s High=%s Low=%s không hợp lệ",
                               TimeFull(g.refTime), Px(g.crtHigh), Px(g.crtLow)));
      MarkDirty();
      return;
   }

   g.bias   = DetectH4Bias(g.crtHigh, g.crtLow, g.h2High, g.h2Low);
   g.valid  = true;
   g.status = ST_WAITING_SWEEP;
   MarkDirty();

   WriteCRTLog(StringFormat("CRT RANGE MỚI %s | Reference %s-%s | Active %s-%s | High=%s Low=%s | Bias=%s",
                            RangeId(g.refTime), TimeFull(g.refTime), TimeHM(g.refEnd),
                            TimeFull(g.activeStart), TimeHM(g.activeEnd),
                            Px(g.crtHigh), Px(g.crtLow), BiasText(g.bias)));
   WriteCRTDebug(StringFormat("Reference H4 Start: %s | Reference H4 End: %s | Reference High: %s | Reference Low: %s",
                              TimeFull(g.refTime), TimeFull(g.refEnd), Px(g.crtHigh), Px(g.crtLow)));
   WriteCRTDebug(StringFormat("Active Start: %s | Active End: %s | H4[2] (%s) High: %s | H4[2] Low: %s | Bias: %s",
                              TimeFull(g.activeStart), TimeFull(g.activeEnd), TimeFull(h4[2].time),
                              Px(g.h2High), Px(g.h2Low), BiasText(g.bias)));
}

//====================================================================
// CẬP NHẬT TRẠNG THÁI SAU KHI SWEEP THAY ĐỔI
//====================================================================
void RefreshStatusAfterSweep()
{
   if(!RangeIsLive())
      return;
   if(g.lowSwept && g.highSwept)
   {
      g.status = ST_INVALID_BOTH;
      WriteCRTLog(StringFormat("INVALID BOTH SIDES: Range %s - Sweep Low %s (%s) và Sweep High %s (%s) trước Entry",
                               RangeId(g.refTime), Px(g.sweepLow), TimeFull(g.sweepLowTime),
                               Px(g.sweepHigh), TimeFull(g.sweepHighTime)));
   }
   else if(g.lowSwept)
      g.status = (BuyPermitted() ? ST_WAITING_M15 : ST_LOW_SWEPT);
   else if(g.highSwept)
      g.status = (SellPermitted() ? ST_WAITING_M15 : ST_HIGH_SWEPT);
   else
      g.status = ST_WAITING_SWEEP;
   MarkDirty();
}

//====================================================================
// CẬP NHẬT CỰC TRỊ SWEEP (chỉ cập nhật khi xuyên sâu hơn - không look-ahead)
//====================================================================
bool UpdateSweepExtreme(bool isLow, double price, datetime t)
{
   if(isLow)
   {
      if(PriceLess(price, g.sweepLow))
      {
         g.sweepLow     = price;
         g.sweepLowTime = t;
         WriteCRTLog(StringFormat("Sweep Low cập nhật: %s @ %s", Px(price), TimeToString(t, TIME_DATE | TIME_SECONDS)), true);
         return true;
      }
   }
   else
   {
      if(PriceGreater(price, g.sweepHigh))
      {
         g.sweepHigh     = price;
         g.sweepHighTime = t;
         WriteCRTLog(StringFormat("Sweep High cập nhật: %s @ %s", Px(price), TimeToString(t, TIME_DATE | TIME_SECONDS)), true);
         return true;
      }
   }
   return false;
}

//====================================================================
// NHẬN DIỆN SWEEP: Low < CRT_Low (strict) ; High > CRT_High (strict)
// low/high: giá đã thực sự xảy ra (tick Bid hoặc M1 đã đóng trong Active).
//====================================================================
void DetectLiquiditySweep(double low, double high, datetime tLow, datetime tHigh)
{
   if(!RangeIsLive())
      return;

   bool changed = false;

   if(PriceLess(low, g.crtLow))
   {
      if(!g.lowSwept)
      {
         g.lowSwept     = true;
         g.sweepLow     = low;
         g.sweepLowTime = tLow;
         changed        = true;
         WriteCRTLog(StringFormat("SWEEP LOW: %s < CRT Low %s @ %s", Px(low), Px(g.crtLow),
                                  TimeToString(tLow, TIME_DATE | TIME_SECONDS)));
      }
      else if(UpdateSweepExtreme(true, low, tLow))
         changed = true;
   }

   if(PriceGreater(high, g.crtHigh))
   {
      if(!g.highSwept)
      {
         g.highSwept     = true;
         g.sweepHigh     = high;
         g.sweepHighTime = tHigh;
         changed         = true;
         WriteCRTLog(StringFormat("SWEEP HIGH: %s > CRT High %s @ %s", Px(high), Px(g.crtHigh),
                                  TimeToString(tHigh, TIME_DATE | TIME_SECONDS)));
      }
      else if(UpdateSweepExtreme(false, high, tHigh))
         changed = true;
   }

   if(changed)
   {
      RefreshStatusAfterSweep();
      if(g.lowSwept)  DrawSweepMarker(true);
      if(g.highSwept) DrawSweepMarker(false);
      MarkDirty();
   }
}

//====================================================================
// BỎ TÍN HIỆU (Range coi như đã dùng)
//====================================================================
void SkipSignal(string reason)
{
   g.status     = ST_SIGNAL_SKIPPED;
   g.skipReason = reason;
   WriteCRTLog(reason + " | Range " + RangeId(g.refTime) + " coi như đã dùng");
   MarkDirty();
}

//====================================================================
// QUÉT LẠI CÁC NẾN M1 ĐÃ ĐÓNG TRONG ACTIVE H4
//  - Bù tick bị lỡ khi live / khôi phục khi restart.
//  - evaluateConfirm = true: (chỉ khi khởi tạo / restart) xét luôn các nến M15
//    đã đóng trong khoảng offline. Nếu có confirmation bị lỡ -> SIGNAL SKIPPED
//    (KHÔNG vào lệnh muộn).
//  - Chỉ dùng nến M1 ĐÃ ĐÓNG (time < M1[0]) -> không look-ahead.
//====================================================================
void ReplayClosedM1(bool evaluateConfirm)
{
   if(!g.valid)
      return;

   int      m1Sec  = PeriodSeconds(CRT_TF_REPLAY);
   int      m15Sec = PeriodSeconds(CRT_TF_CONFIRM);
   datetime m1Open0 = iTime(_Symbol, CRT_TF_REPLAY, 0);
   if(m1Open0 <= 0)
      return;

   datetime from = g.lastM1Processed + m1Sec;
   if(from < g.activeStart)
      from = g.activeStart;
   datetime to = m1Open0 - 1;            // chỉ nến đã đóng
   if(to > g.activeEnd - 1)
      to = g.activeEnd - 1;             // không vượt Active End
   if(from > to)
      return;

   MqlRates m1[];
   ArraySetAsSeries(m1, false);
   ResetLastError();
   int n = CopyRates(_Symbol, CRT_TF_REPLAY, from, to, m1);
   if(n <= 0)
   {
      WriteCRTLog(StringFormat("CopyRates M1 thất bại (%s -> %s, err=%d)", TimeFull(from), TimeFull(to), GetLastError()), true);
      return;
   }

   for(int i = 0; i < n; i++)
   {
      if(m1[i].time < from || m1[i].time > to)
         continue;

      if(RangeIsLive())
         DetectLiquiditySweep(m1[i].low, m1[i].high, m1[i].time, m1[i].time);

      g.lastM1Processed = m1[i].time;

      if(evaluateConfirm)
      {
         datetime endT = m1[i].time + m1Sec;
         if(((long)endT % m15Sec) == 0)
         {
            datetime m15Open = endT - m15Sec;
            if(m15Open > g.lastM15Processed)
            {
               double c = m1[i].close;
               int sh = iBarShift(_Symbol, CRT_TF_CONFIRM, m15Open, true);
               if(sh >= 1)
                  c = iClose(_Symbol, CRT_TF_CONFIRM, sh);
               if(RangeIsLive())
                  CheckM15Confirmation(m15Open, c, false);
               g.lastM15Processed = m15Open;
            }
         }
      }
   }
   MarkDirty();
}

//====================================================================
// M15: PHÁT HIỆN NẾN M15 MỚI ĐÓNG -> trả về M15[1]
//====================================================================
bool DetectNewM15Bar(MqlRates &closedBar)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, CRT_TF_CONFIRM, 1, 1, r) != 1)   // shift 1 = nến vừa đóng
      return false;
   if(r[0].time <= g.lastM15Processed)
      return false;
   closedBar = r[0];
   g.lastM15Processed = r[0].time;
   MarkDirty();
   return true;
}

//====================================================================
// M15 CONFIRMATION
//  BUY : đã Sweep Low, chưa Sweep High, BUY được phép,
//        CRT_Low < Close < CRT_High
//  SELL: đã Sweep High, chưa Sweep Low, SELL được phép,
//        CRT_Low < Close < CRT_High
//  Nến M15 phải nằm trong Active và ĐÓNG TRƯỚC Active End.
//  liveMode=false: confirmation xảy ra lúc EA offline -> bỏ (không vào muộn).
//====================================================================
bool CheckM15Confirmation(datetime barOpen, double barClose, bool liveMode)
{
   if(!RangeIsLive())
      return false;

   int      m15Sec   = PeriodSeconds(CRT_TF_CONFIRM);
   datetime barClose_t = barOpen + m15Sec;

   if(barOpen < g.activeStart || barClose_t >= g.activeEnd)
      return false;

   if(!g.lowSwept && !g.highSwept)
      return false;   // chưa có sweep -> không cần xét

   int  dir    = 0;
   bool inside = (PriceGreater(barClose, g.crtLow) && PriceLess(barClose, g.crtHigh));

   if(g.lowSwept && !g.highSwept && BuyPermitted() && inside)
      dir = +1;
   else if(g.highSwept && !g.lowSwept && SellPermitted() && inside)
      dir = -1;

   WriteCRTDebug(StringFormat("Last Closed M15: %s-%s | M15 Close: %s | CRT %s-%s | Bias: %s | Sweep Low: %s (%s) | Sweep High: %s (%s) | Confirmation: %s",
                              TimeFull(barOpen), TimeHM(barClose_t), Px(barClose),
                              Px(g.crtLow), Px(g.crtHigh), BiasText(g.bias),
                              YesNo(g.lowSwept),  (g.lowSwept  ? Px(g.sweepLow)  : "-"),
                              YesNo(g.highSwept), (g.highSwept ? Px(g.sweepHigh) : "-"),
                              (dir > 0 ? "VALID BUY" : (dir < 0 ? "VALID SELL" : "NO"))));

   if(dir == 0)
      return false;

   //--- Sweep phải xảy ra trước khi nến xác nhận đóng
   datetime sweepT = (dir > 0 ? g.sweepLowTime : g.sweepHighTime);
   if(sweepT >= barClose_t)
      return false;

   //--- Bộ lọc độ sâu sweep (mặc định tắt)
   double depth = (dir > 0 ? g.crtLow - g.sweepLow : g.sweepHigh - g.crtHigh);
   if(InpMinSweep > 0.0 && depth < InpMinSweep - PriceEps())
   {
      WriteCRTLog(StringFormat("Confirmation bị bỏ qua: độ sâu sweep %s < Sweep_tối_thiểu %s (tiếp tục chờ)",
                               DoubleToString(depth, _Digits), DoubleToString(InpMinSweep, _Digits)));
      return false;
   }

   g.confirmed      = true;
   g.confirmDir     = dir;
   g.confirmBarTime = barOpen;
   g.confirmClose   = barClose;
   g.status         = (dir > 0 ? ST_BUY_CONFIRMED : ST_SELL_CONFIRMED);
   MarkDirty();
   DrawConfirmationMarker();

   WriteCRTLog(StringFormat("M15 CONFIRM %s: nến %s-%s Close=%s nằm trong %s-%s | Sweep=%s",
                            (dir > 0 ? "BUY" : "SELL"), TimeFull(barOpen), TimeHM(barClose_t), Px(barClose),
                            Px(g.crtLow), Px(g.crtHigh), Px(dir > 0 ? g.sweepLow : g.sweepHigh)));

   if(InpMaxSweep > 0.0 && depth > InpMaxSweep + PriceEps())
   {
      SkipSignal(StringFormat("CRT SIGNAL BỊ BỎ QUA DO SWEEP QUÁ SÂU (%s > %s)",
                              DoubleToString(depth, _Digits), DoubleToString(InpMaxSweep, _Digits)));
      return false;
   }

   if(!liveMode)
   {
      SkipSignal("CRT SIGNAL BỊ BỎ QUA: CONFIRMATION XẢY RA KHI EA OFFLINE - KHÔNG VÀO LỆNH MUỘN");
      return false;
   }
   return true;
}

//====================================================================
// VALIDATE RANGE NGAY TRƯỚC ORDERSEND
//====================================================================
bool ValidateCRTRangeBeforeTrade(datetime now)
{
   if(!g.valid)
      return false;

   //--- H4[0] vẫn phải là Active, H4[1] vẫn phải là Reference
   datetime h4Open0 = iTime(_Symbol, CRT_TF_RANGE, 0);
   if(h4Open0 != g.activeStart)
   {
      WriteCRTLog(StringFormat("CRT RANGE VALIDATION FAILED: H4[0]=%s khác Active Start=%s",
                               TimeFull(h4Open0), TimeFull(g.activeStart)));
      return false;
   }

   int shift = iBarShift(_Symbol, CRT_TF_RANGE, g.refTime, true);
   if(shift != 1)
   {
      WriteCRTLog(StringFormat("CRT RANGE VALIDATION FAILED: Reference %s không phải H4[1] (shift=%d)",
                               TimeFull(g.refTime), shift));
      return false;
   }

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, CRT_TF_RANGE, 1, 2, r) != 2)
   {
      WriteCRTLog("CRT RANGE VALIDATION FAILED: không đọc lại được H4[1]/H4[2]");
      return false;
   }
   if(r[0].time != g.refTime || !PriceEqual(r[0].high, g.crtHigh) || !PriceEqual(r[0].low, g.crtLow))
   {
      WriteCRTLog(StringFormat("CRT RANGE VALIDATION FAILED: stored %s-%s / source %s High=%s Low=%s",
                               Px(g.crtLow), Px(g.crtHigh), TimeFull(r[0].time), Px(r[0].high), Px(r[0].low)));
      return false;
   }
   if(DetectH4Bias(r[0].high, r[0].low, r[1].high, r[1].low) != g.bias)
   {
      WriteCRTLog("CRT RANGE VALIDATION FAILED: Bias đọc lại khác Bias đã lưu");
      return false;
   }
   if(now < g.activeStart || now >= g.activeEnd)
   {
      WriteCRTLog(StringFormat("CRT RANGE VALIDATION FAILED: thời gian %s ngoài Active %s-%s",
                               TimeFull(now), TimeFull(g.activeStart), TimeHM(g.activeEnd)));
      return false;
   }
   if(g.lowSwept && g.highSwept)
   {
      WriteCRTLog("CRT RANGE VALIDATION FAILED: cả hai phía đã bị sweep");
      return false;
   }
   if(g.traded)
   {
      WriteCRTLog("CRT RANGE VALIDATION FAILED: Range đã TRADED");
      return false;
   }
   return true;
}

//====================================================================
// KHỐI LƯỢNG
//====================================================================
int VolumeDigits(double step)
{
   int    d = 0;
   double s = step;
   while(d < 8 && MathAbs(s - MathRound(s)) > 1e-9)
   {
      s *= 10.0;
      d++;
   }
   return d;
}

double NormalizeVolumeDown(double lots)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0)
      step = 0.01;
   double v = MathFloor(lots / step + 1e-9) * step;
   return NormalizeDouble(v, VolumeDigits(step));
}

// Trả về lot hợp lệ, hoặc 0 nếu phải bỏ lệnh (lý do ghi vào reason)
double CalculateRiskLot(int dir, double entry, double sl, string &reason)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lots   = 0.0;

   if(!InpUseRiskEquity)
   {
      lots = NormalizeVolumeDown(InpFixedLot);
      if(lots < minLot - 1e-9)
      {
         reason = StringFormat("Khối_lượng_cố_định %.4f < Volume Min %.4f", InpFixedLot, minLot);
         return 0.0;
      }
      if(lots > maxLot)
      {
         WriteCRTLog(StringFormat("Khối lượng %.4f > Volume Max %.4f -> dùng Volume Max", lots, maxLot));
         lots = NormalizeVolumeDown(maxLot);
      }
      return lots;
   }

   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * InpRiskPercent / 100.0;
   double distance  = MathAbs(entry - sl);
   if(riskMoney <= 0.0 || distance <= 0.0)
   {
      reason = "Không tính được risk (equity / khoảng cách SL = 0)";
      return 0.0;
   }

   //--- Lỗ cho 1 lot nếu chạm SL: ưu tiên OrderCalcProfit (đã gồm quy đổi tiền tệ)
   double lossPerLot = 0.0;
   double profit     = 0.0;
   ENUM_ORDER_TYPE type = (dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(OrderCalcProfit(type, _Symbol, 1.0, entry, sl, profit) && profit < 0.0)
      lossPerLot = -profit;
   else
   {
      double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
      if(tickValue <= 0.0)
         tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tickSize > 0.0 && tickValue > 0.0)
         lossPerLot = (distance / tickSize) * tickValue;
   }
   if(lossPerLot <= 0.0)
   {
      reason = "Không tính được giá trị lỗ mỗi lot (tick size / tick value)";
      return 0.0;
   }

   double rawLots = riskMoney / lossPerLot;
   lots = NormalizeVolumeDown(rawLots);   // làm tròn XUỐNG -> không vượt risk

   WriteCRTLog(StringFormat("Risk lot: Equity=%.2f Risk=%.2f%% (%.2f) | SL dist=%s | Loss/lot=%.2f | Raw=%.4f -> %.4f",
                            equity, InpRiskPercent, riskMoney, DoubleToString(distance, _Digits),
                            lossPerLot, rawLots, lots), true);

   if(lots < minLot - 1e-9)
   {
      reason = StringFormat("Lot theo risk %.4f < Volume Min %.4f (dùng Min sẽ lỗ %.2f > risk %.2f)",
                            rawLots, minLot, minLot * lossPerLot, riskMoney);
      return 0.0;
   }
   if(lots > maxLot)
      lots = NormalizeVolumeDown(maxLot);
   return lots;
}

//====================================================================
// GIÁ
//====================================================================
double NormalizePrice(double p)
{
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts > 0.0)
      p = MathRound(p / ts) * ts;
   return NormalizeDouble(p, _Digits);
}

//====================================================================
// TÌM POSITION THEO ID (chỉ Symbol + Magic của EA)
//====================================================================
bool SelectPositionById(ulong posId)
{
   if(posId == 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic)
         continue;
      if((ulong)PositionGetInteger(POSITION_IDENTIFIER) == posId)
         return true;
   }
   return false;
}

//====================================================================
// THỰC HIỆN LỆNH
//====================================================================
bool ExecuteCRTTrade(int dir, const MqlTick &tick)
{
   if(g.traded)
      return false;

   string side = (dir > 0 ? "BUY" : "SELL");

   //--- 1. Spread
   double spread = tick.ask - tick.bid;
   if(InpMaxSpread > 0.0 && spread > InpMaxSpread + PriceEps())
   {
      SkipSignal(StringFormat("CRT SIGNAL BỊ BỎ QUA DO SPREAD (%s > %s)",
                              DoubleToString(spread, _Digits), DoubleToString(InpMaxSpread, _Digits)));
      return false;
   }

   //--- 2. Validate Range
   if(!ValidateCRTRangeBeforeTrade(tick.time))
   {
      g.status     = ST_RANGE_ERROR;
      g.skipReason = "CRT RANGE VALIDATION FAILED";
      MarkDirty();
      return false;
   }

   //--- 3. Entry / SL / TP theo chiến lược
   double price = (dir > 0 ? tick.ask : tick.bid);
   double sl    = NormalizePrice(dir > 0 ? g.sweepLow - InpSLBuffer : g.sweepHigh + InpSLBuffer);
   double tp    = NormalizePrice(dir > 0 ? g.crtHigh : g.crtLow);

   if(dir > 0 && !(sl < price && price < tp))
   {
      SkipSignal(StringFormat("BUY bỏ: hình học không hợp lệ (SL %s / Ask %s / TP %s)", Px(sl), Px(price), Px(tp)));
      return false;
   }
   if(dir < 0 && !(tp < price && price < sl))
   {
      SkipSignal(StringFormat("SELL bỏ: hình học không hợp lệ (TP %s / Bid %s / SL %s)", Px(tp), Px(price), Px(sl)));
      return false;
   }

   //--- 4. StopsLevel / FreezeLevel (SL/TP của BUY so với Bid, của SELL so với Ask)
   long   stopsLevel  = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long   freezeLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double minDist     = (double)MathMax(stopsLevel, freezeLevel) * g_point;
   double ref         = (dir > 0 ? tick.bid : tick.ask);
   double slDist      = MathAbs(ref - sl);
   double tpDist      = MathAbs(tp - ref);
   if(slDist < minDist || tpDist < minDist)
   {
      SkipSignal(StringFormat("%s bỏ: SL/TP vi phạm StopsLevel/FreezeLevel (SL dist %s, TP dist %s, min %s) - không tự sửa SL chiến lược",
                              side, DoubleToString(slDist, _Digits), DoubleToString(tpDist, _Digits), DoubleToString(minDist, _Digits)));
      return false;
   }

   //--- 5. RR dự kiến
   double risk   = MathAbs(price - sl);
   double reward = MathAbs(tp - price);
   double rr     = (risk > 0.0 ? reward / risk : 0.0);
   if(InpMinRR > 0.0 && rr < InpMinRR)
   {
      SkipSignal(StringFormat("CRT SIGNAL BỊ BỎ QUA DO RR %.2f < RR_tối_thiểu %.2f", rr, InpMinRR));
      return false;
   }

   //--- 6. Khối lượng
   string lotReason = "";
   double lots = CalculateRiskLot(dir, price, sl, lotReason);
   if(lots <= 0.0)
   {
      SkipSignal("CRT SIGNAL BỊ BỎ QUA DO VOLUME: " + lotReason);
      return false;
   }

   //--- 7. Margin
   double margin = 0.0;
   if(OrderCalcMargin(dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, lots, price, margin))
   {
      if(margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
      {
         SkipSignal(StringFormat("CRT SIGNAL BỊ BỎ QUA DO KHÔNG ĐỦ MARGIN (cần %.2f)", margin));
         return false;
      }
   }

   //--- 8. Khóa Range TRƯỚC khi gửi lệnh -> không bao giờ gửi lệnh lặp
   g.traded   = true;
   g.tradeDir = dir;
   MarkDirty();
   SaveCRTState();

   string comment = "DAVID_CRT_" + side + "_" + StringSubstr(RangeId(g.refTime), 9, 4);

   WriteCRTLog(StringFormat("GỬI %s %.2f lot | Giá tham chiếu %s | SL %s | TP %s | RR dự kiến 1:%.2f | Spread %s",
                            side, lots, Px(price), Px(sl), Px(tp), rr, DoubleToString(spread, _Digits)));

   bool sent = (dir > 0 ? g_trade.Buy(lots, _Symbol, 0.0, sl, tp, comment)
                        : g_trade.Sell(lots, _Symbol, 0.0, sl, tp, comment));
   uint rc = g_trade.ResultRetcode();

   if(!sent || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_DONE_PARTIAL && rc != TRADE_RETCODE_PLACED))
   {
      g.traded = false;   // không có lệnh thật
      SkipSignal(StringFormat("ORDER %s THẤT BẠI retcode=%u (%s) - không gửi lại", side, rc, g_trade.ResultRetcodeDescription()));
      return false;
   }

   //--- 9. Đọc giá khớp THỰC TẾ
   double   fill  = g_trade.ResultPrice();
   datetime ft    = tick.time;
   ulong    deal  = g_trade.ResultDeal();
   ulong    posId = 0;
   double   vol   = g_trade.ResultVolume();

   if(deal > 0 && HistoryDealSelect(deal))
   {
      double dp = HistoryDealGetDouble(deal, DEAL_PRICE);
      if(dp > 0.0)
         fill = dp;
      ft    = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      posId = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      double dv = HistoryDealGetDouble(deal, DEAL_VOLUME);
      if(dv > 0.0)
         vol = dv;
   }
   if(posId == 0)
      posId = g_trade.ResultOrder();

   double actualSL = sl;
   double actualTP = tp;
   if(SelectPositionById(posId))
   {
      double po = PositionGetDouble(POSITION_PRICE_OPEN);
      if(po > 0.0)
         fill = po;
      actualSL = PositionGetDouble(POSITION_SL);
      actualTP = PositionGetDouble(POSITION_TP);
   }
   if(fill <= 0.0)
      fill = price;   // dự phòng cuối cùng; sẽ được làm mới từ position ở tick sau

   g.positionId = posId;
   g.entryTime  = ft;
   g.entryPrice = fill;
   g.slPrice    = actualSL;
   g.tpPrice    = actualTP;
   g.lots       = (vol > 0.0 ? vol : lots);
   double aRisk   = MathAbs(fill - actualSL);
   double aReward = MathAbs(actualTP - fill);
   g.rr         = (aRisk > 0.0 ? aReward / aRisk : 0.0);
   g.status     = (dir > 0 ? ST_BUY_ACTIVE : ST_SELL_ACTIVE);
   MarkDirty();

   WriteCRTLog(StringFormat("%s ENTRY KHỚP %s @ %s | SL %s | TP %s | Risk %s | Reward %s | RR 1:%.2f | Position #%I64u",
                            side, DoubleToString(g.lots, 2), Px(fill), Px(actualSL), Px(actualTP),
                            DoubleToString(aRisk, _Digits), DoubleToString(aReward, _Digits), g.rr, posId));

   DrawEntrySLTP();
   SaveCRTState();
   return true;
}

//====================================================================
// THEO DÕI POSITION CỦA RANGE HIỆN TẠI
//====================================================================
void MonitorPosition()
{
   if(!g.traded)
      return;
   if(g.status != ST_BUY_ACTIVE && g.status != ST_SELL_ACTIVE)
      return;

   if(SelectPositionById(g.positionId))
   {
      double po = PositionGetDouble(POSITION_PRICE_OPEN);
      if(po > 0.0 && !PriceEqual(po, g.entryPrice))
      {
         g.entryPrice = po;
         double r = MathAbs(g.entryPrice - g.slPrice);
         g.rr = (r > 0.0 ? MathAbs(g.tpPrice - g.entryPrice) / r : 0.0);
         DrawEntrySLTP();
         MarkDirty();
      }
      return;
   }

   g.status = ST_TRADED;
   WriteCRTLog(StringFormat("Position #%I64u của Range %s đã đóng -> TRADED", g.positionId, RangeId(g.refTime)));
   MarkDirty();
}

//====================================================================
// KHÔI PHỤC TRẠNG THÁI ĐÃ TRADE TỪ TERMINAL (position / history)
// Lệnh của Range = deal IN có Symbol + Magic đúng, thời gian trong Active.
//====================================================================
void RestoreTradeFromTerminal()
{
   if(!g.valid)
      return;

   //--- Position đang mở
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != (long)InpMagic)
         continue;
      datetime pt = (datetime)PositionGetInteger(POSITION_TIME);
      if(pt < g.activeStart || pt >= g.activeEnd)
         continue;

      g.traded     = true;
      g.tradeDir   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1);
      g.positionId = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      g.entryTime  = pt;
      g.entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      g.slPrice    = PositionGetDouble(POSITION_SL);
      g.tpPrice    = PositionGetDouble(POSITION_TP);
      g.lots       = PositionGetDouble(POSITION_VOLUME);
      double r     = MathAbs(g.entryPrice - g.slPrice);
      g.rr         = (r > 0.0 ? MathAbs(g.tpPrice - g.entryPrice) / r : 0.0);
      g.status     = (g.tradeDir > 0 ? ST_BUY_ACTIVE : ST_SELL_ACTIVE);
      MarkDirty();
      WriteCRTLog(StringFormat("KHÔI PHỤC: Range %s đã có position mở #%I64u -> %s", RangeId(g.refTime), g.positionId, StatusText(g.status)));
      return;
   }

   //--- Deal đã đóng trong lịch sử
   if(!HistorySelect(g.activeStart, TimeCurrent() + 60))
      return;
   int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0)
         continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol || HistoryDealGetInteger(d, DEAL_MAGIC) != (long)InpMagic)
         continue;
      if(HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_IN)
         continue;
      datetime dt = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
      if(dt < g.activeStart || dt >= g.activeEnd)
         continue;

      g.traded     = true;
      g.tradeDir   = (HistoryDealGetInteger(d, DEAL_TYPE) == DEAL_TYPE_BUY ? 1 : -1);
      g.positionId = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);
      g.entryTime  = dt;
      g.entryPrice = HistoryDealGetDouble(d, DEAL_PRICE);
      g.slPrice    = HistoryDealGetDouble(d, DEAL_SL);
      g.tpPrice    = HistoryDealGetDouble(d, DEAL_TP);
      g.lots       = HistoryDealGetDouble(d, DEAL_VOLUME);
      double r     = MathAbs(g.entryPrice - g.slPrice);
      g.rr         = (r > 0.0 ? MathAbs(g.tpPrice - g.entryPrice) / r : 0.0);
      g.status     = (SelectPositionById(g.positionId) ? (g.tradeDir > 0 ? ST_BUY_ACTIVE : ST_SELL_ACTIVE) : ST_TRADED);
      MarkDirty();
      WriteCRTLog(StringFormat("KHÔI PHỤC: Range %s đã có deal vào lệnh #%I64u -> %s", RangeId(g.refTime), d, StatusText(g.status)));
      return;
   }
}

//====================================================================
// LƯU / KHÔI PHỤC STATE (file text trong MQL5\Files)
//====================================================================
void WriteKV(int h, string key, string value)
{
   FileWriteString(h, key + "=" + value + "\r\n");
}

string D2S(double v)    { return DoubleToString(v, 8); }
string T2S(datetime t)  { return IntegerToString((long)t); }
string B2S(bool b)      { return (b ? "1" : "0"); }

void SaveCRTState()
{
   if(g_isTester)          // Strategy Tester không có restart -> không ghi file
      return;
   if(g.refTime <= 0)
      return;

   int h = FileOpen(g_stateFile, FILE_WRITE | FILE_TXT | FILE_UNICODE);
   if(h == INVALID_HANDLE)
   {
      WriteCRTLog(StringFormat("Không ghi được state file %s (err=%d)", g_stateFile, GetLastError()), true);
      return;
   }
   WriteKV(h, "version",          "1");
   WriteKV(h, "symbol",           _Symbol);
   WriteKV(h, "magic",            IntegerToString((long)InpMagic));
   WriteKV(h, "valid",            B2S(g.valid));
   WriteKV(h, "refTime",          T2S(g.refTime));
   WriteKV(h, "activeStart",      T2S(g.activeStart));
   WriteKV(h, "crtHigh",          D2S(g.crtHigh));
   WriteKV(h, "crtLow",           D2S(g.crtLow));
   WriteKV(h, "lowSwept",         B2S(g.lowSwept));
   WriteKV(h, "highSwept",        B2S(g.highSwept));
   WriteKV(h, "sweepLow",         D2S(g.sweepLow));
   WriteKV(h, "sweepHigh",        D2S(g.sweepHigh));
   WriteKV(h, "sweepLowTime",     T2S(g.sweepLowTime));
   WriteKV(h, "sweepHighTime",    T2S(g.sweepHighTime));
   WriteKV(h, "confirmed",        B2S(g.confirmed));
   WriteKV(h, "confirmDir",       IntegerToString(g.confirmDir));
   WriteKV(h, "confirmBarTime",   T2S(g.confirmBarTime));
   WriteKV(h, "confirmClose",     D2S(g.confirmClose));
   WriteKV(h, "traded",           B2S(g.traded));
   WriteKV(h, "tradeDir",         IntegerToString(g.tradeDir));
   WriteKV(h, "positionId",       IntegerToString((long)g.positionId));
   WriteKV(h, "entryTime",        T2S(g.entryTime));
   WriteKV(h, "entryPrice",       D2S(g.entryPrice));
   WriteKV(h, "slPrice",          D2S(g.slPrice));
   WriteKV(h, "tpPrice",          D2S(g.tpPrice));
   WriteKV(h, "rr",               D2S(g.rr));
   WriteKV(h, "lots",             D2S(g.lots));
   WriteKV(h, "status",           IntegerToString(g.status));
   WriteKV(h, "skipReason",       g.skipReason);
   WriteKV(h, "lastM1Processed",  T2S(g.lastM1Processed));
   WriteKV(h, "lastM15Processed", T2S(g.lastM15Processed));
   FileClose(h);
}

// Chỉ khôi phục khi state file thuộc ĐÚNG Range hiện tại (cùng Reference time + High/Low)
bool RestoreCRTState()
{
   if(g_isTester || !g.valid)
      return false;
   if(!FileIsExist(g_stateFile))
      return false;

   int h = FileOpen(g_stateFile, FILE_READ | FILE_TXT | FILE_UNICODE);
   if(h == INVALID_HANDLE)
      return false;

   string keys[];
   string vals[];
   int    n = 0;
   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      int p = StringFind(line, "=");
      if(p <= 0)
         continue;
      ArrayResize(keys, n + 1);
      ArrayResize(vals, n + 1);
      keys[n] = StringSubstr(line, 0, p);
      vals[n] = StringSubstr(line, p + 1);
      StringTrimRight(vals[n]);
      n++;
   }
   FileClose(h);

   string sSymbol = "", sMagic = "", sRef = "", sHigh = "", sLow = "";
   for(int i = 0; i < n; i++)
   {
      if(keys[i] == "symbol")  sSymbol = vals[i];
      if(keys[i] == "magic")   sMagic  = vals[i];
      if(keys[i] == "refTime") sRef    = vals[i];
      if(keys[i] == "crtHigh") sHigh   = vals[i];
      if(keys[i] == "crtLow")  sLow    = vals[i];
   }
   if(sSymbol != _Symbol || sMagic != IntegerToString((long)InpMagic))
      return false;
   if((datetime)StringToInteger(sRef) != g.refTime)
   {
      WriteCRTLog("State file thuộc Range cũ -> bỏ qua, dùng Range mới từ H4[1]", true);
      return false;
   }
   if(!PriceEqual(StringToDouble(sHigh), g.crtHigh) || !PriceEqual(StringToDouble(sLow), g.crtLow))
   {
      WriteCRTLog("State file có High/Low khác dữ liệu H4[1] -> bỏ qua state", true);
      return false;
   }

   for(int i = 0; i < n; i++)
   {
      string k = keys[i];
      string v = vals[i];
      if(k == "lowSwept")         g.lowSwept         = (v == "1");
      if(k == "highSwept")        g.highSwept        = (v == "1");
      if(k == "sweepLow")         g.sweepLow         = StringToDouble(v);
      if(k == "sweepHigh")        g.sweepHigh        = StringToDouble(v);
      if(k == "sweepLowTime")     g.sweepLowTime     = (datetime)StringToInteger(v);
      if(k == "sweepHighTime")    g.sweepHighTime    = (datetime)StringToInteger(v);
      if(k == "confirmed")        g.confirmed        = (v == "1");
      if(k == "confirmDir")       g.confirmDir       = (int)StringToInteger(v);
      if(k == "confirmBarTime")   g.confirmBarTime   = (datetime)StringToInteger(v);
      if(k == "confirmClose")     g.confirmClose     = StringToDouble(v);
      if(k == "traded")           g.traded           = (v == "1");
      if(k == "tradeDir")         g.tradeDir         = (int)StringToInteger(v);
      if(k == "positionId")       g.positionId       = (ulong)StringToInteger(v);
      if(k == "entryTime")        g.entryTime        = (datetime)StringToInteger(v);
      if(k == "entryPrice")       g.entryPrice       = StringToDouble(v);
      if(k == "slPrice")          g.slPrice          = StringToDouble(v);
      if(k == "tpPrice")          g.tpPrice          = StringToDouble(v);
      if(k == "rr")               g.rr               = StringToDouble(v);
      if(k == "lots")             g.lots             = StringToDouble(v);
      if(k == "status")           g.status           = (int)StringToInteger(v);
      if(k == "skipReason")       g.skipReason       = v;
      if(k == "lastM1Processed")  g.lastM1Processed  = (datetime)StringToInteger(v);
      if(k == "lastM15Processed") g.lastM15Processed = (datetime)StringToInteger(v);
   }

   //--- Restart giữa Confirmation và Entry: không gửi lại / không vào muộn.
   //    Nếu lệnh thực sự đã khớp, RestoreTradeFromTerminal() sẽ ghi đè trạng thái.
   if(g.status == ST_BUY_CONFIRMED || g.status == ST_SELL_CONFIRMED)
   {
      g.status     = ST_SIGNAL_SKIPPED;
      g.skipReason = "EA restart giữa Confirmation và Entry - không vào lệnh muộn";
   }
   if(g.lastM1Processed < g.activeStart - PeriodSeconds(CRT_TF_REPLAY))
      g.lastM1Processed = g.activeStart - PeriodSeconds(CRT_TF_REPLAY);

   WriteCRTLog(StringFormat("KHÔI PHỤC STATE Range %s: CRT %s-%s | Low Swept %s (%s) | High Swept %s (%s) | Status %s",
                            RangeId(g.refTime), Px(g.crtLow), Px(g.crtHigh),
                            YesNo(g.lowSwept), (g.lowSwept ? Px(g.sweepLow) : "-"),
                            YesNo(g.highSwept), (g.highSwept ? Px(g.sweepHigh) : "-"),
                            StatusText(g.status)));
   return true;
}

//====================================================================
// VẼ - HELPER
//====================================================================
void EnsureRect(string name, datetime t1, double p1, datetime t2, double p2, color clr, bool fill, ENUM_LINE_STYLE style, string tip)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, fill);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString (0, name, OBJPROP_TOOLTIP, tip);
}

void EnsureSegment(string name, datetime t1, double p1, datetime t2, double p2, color clr, ENUM_LINE_STYLE style, int width, string tip)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, p1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString (0, name, OBJPROP_TOOLTIP, tip);
}

void EnsureText(string name, datetime t, double p, string text, color clr, ENUM_ANCHOR_POINT anchor)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, p);
   ObjectSetString (0, name, OBJPROP_TEXT, text);
   ObjectSetString (0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void EnsureArrow(string name, ENUM_OBJECT type, datetime t, double p, color clr, ENUM_ARROW_ANCHOR anchor, string tip)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, type, 0, t, p);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t);
   ObjectSetDouble (0, name, OBJPROP_PRICE, 0, p);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString (0, name, OBJPROP_TOOLTIP, tip);
}

//====================================================================
// VẼ REFERENCE CANDLE (khung riêng, nhãn REFERENCE ONLY, tại refTime -> refEnd)
//====================================================================
void DrawReferenceCandle()
{
   if(!g_drawEnabled || !InpShowReference || !g.valid)
      return;
   string tip = StringFormat("CRT REFERENCE (REFERENCE ONLY) %s-%s H=%s L=%s",
                             TimeFull(g.refTime), TimeHM(g.refEnd), Px(g.crtHigh), Px(g.crtLow));
   EnsureRect(ObjName("REF"), g.refTime, g.crtHigh, g.refEnd, g.crtLow, clrDimGray, false, STYLE_DOT, tip);
   EnsureText(ObjName("REFLBL"), g.refTime, g.crtHigh, "CRT REFERENCE - REFERENCE ONLY", clrDimGray, ANCHOR_LEFT_LOWER);
}

//====================================================================
// VẼ ACTIVE CRT RECTANGLE: Time1 = Active Start @ CRT High, Time2 = Active End @ CRT Low
//====================================================================
void DrawCRTRange()
{
   if(!g_drawEnabled || !g.valid)
      return;
   string tip = StringFormat("ACTIVE CRT %s-%s | High %s | Low %s | Bias %s",
                             TimeFull(g.activeStart), TimeHM(g.activeEnd), Px(g.crtHigh), Px(g.crtLow), BiasText(g.bias));
   EnsureRect(ObjName("RANGE"), g.activeStart, g.crtHigh, g.activeEnd, g.crtLow, C'32,48,72', true, STYLE_SOLID, tip);
   EnsureText(ObjName("RANGELBL"), g.activeStart, g.crtHigh,
              "ACTIVE CRT " + TimeHM(g.activeStart) + "-" + TimeHM(g.activeEnd) + " [" + BiasText(g.bias) + "]",
              clrSilver, ANCHOR_LEFT_LOWER);
}

//====================================================================
// VẼ CRT HIGH / LOW: đoạn thẳng (không ray) Active Start -> Active End
//====================================================================
void DrawCRTHighLow()
{
   if(!g_drawEnabled || !g.valid)
      return;
   EnsureSegment(ObjName("HIGH"), g.activeStart, g.crtHigh, g.activeEnd, g.crtHigh, clrDodgerBlue, STYLE_SOLID, 2,
                 "CRT HIGH " + Px(g.crtHigh));
   EnsureSegment(ObjName("LOW"),  g.activeStart, g.crtLow,  g.activeEnd, g.crtLow,  clrOrangeRed, STYLE_SOLID, 2,
                 "CRT LOW " + Px(g.crtLow));
}

//====================================================================
// VẼ SWEEP MARKER tại (thời điểm, giá) cực trị sweep THỰC TẾ
//====================================================================
void DrawSweepMarker(bool isLow)
{
   if(!g_drawEnabled || !g.valid)
      return;
   if(isLow && g.lowSwept)
   {
      EnsureArrow(ObjName("SWEEPLOW"), OBJ_ARROW_UP, g.sweepLowTime, g.sweepLow, clrOrange, ANCHOR_TOP,
                  "SWEEP LOW " + Px(g.sweepLow) + " @ " + TimeToString(g.sweepLowTime, TIME_DATE | TIME_SECONDS));
      EnsureText(ObjName("SWEEPLOWLBL"), g.sweepLowTime, g.sweepLow, "SWEEP LOW " + Px(g.sweepLow), clrOrange, ANCHOR_LEFT_UPPER);
   }
   if(!isLow && g.highSwept)
   {
      EnsureArrow(ObjName("SWEEPHIGH"), OBJ_ARROW_DOWN, g.sweepHighTime, g.sweepHigh, clrOrange, ANCHOR_BOTTOM,
                  "SWEEP HIGH " + Px(g.sweepHigh) + " @ " + TimeToString(g.sweepHighTime, TIME_DATE | TIME_SECONDS));
      EnsureText(ObjName("SWEEPHIGHLBL"), g.sweepHighTime, g.sweepHigh, "SWEEP HIGH " + Px(g.sweepHigh), clrOrange, ANCHOR_LEFT_LOWER);
   }
}

//====================================================================
// VẼ M15 CONFIRMATION: đoạn ngang trên đúng nến M15 đã đóng (open -> open+15m) @ Close
//====================================================================
void DrawConfirmationMarker()
{
   if(!g_drawEnabled || !g.confirmed)
      return;
   datetime t2   = g.confirmBarTime + PeriodSeconds(CRT_TF_CONFIRM);
   string   side = (g.confirmDir > 0 ? "BUY" : "SELL");
   color    clr  = (g.confirmDir > 0 ? clrLime : clrMagenta);
   string   tip  = StringFormat("M15 CONFIRM %s | nến %s-%s | Close %s", side, TimeFull(g.confirmBarTime), TimeHM(t2), Px(g.confirmClose));
   EnsureSegment(ObjName("CONFIRM"), g.confirmBarTime, g.confirmClose, t2, g.confirmClose, clr, STYLE_SOLID, 4, tip);
   EnsureText(ObjName("CONFIRMLBL"), g.confirmBarTime, g.confirmClose,
              "M15 CONFIRM " + side + " " + Px(g.confirmClose), clr,
              (g.confirmDir > 0 ? ANCHOR_RIGHT_UPPER : ANCHOR_RIGHT_LOWER));
}

//====================================================================
// VẼ ENTRY (giá khớp thật) / SL / TP
//====================================================================
void DrawEntrySLTP()
{
   if(!g_drawEnabled || !g.traded || g.entryPrice <= 0.0)
      return;
   string   side = (g.tradeDir > 0 ? "BUY" : "SELL");
   datetime tEnd = g.activeEnd;
   if(tEnd <= g.entryTime)
      tEnd = g.entryTime + PeriodSeconds(CRT_TF_CONFIRM);

   EnsureArrow(ObjName("ENTRY"), (g.tradeDir > 0 ? OBJ_ARROW_BUY : OBJ_ARROW_SELL), g.entryTime, g.entryPrice,
               (g.tradeDir > 0 ? clrLime : clrMagenta), ANCHOR_TOP, side + " ENTRY " + Px(g.entryPrice));
   EnsureText(ObjName("ENTRYLBL"), g.entryTime, g.entryPrice, "  " + side + " ENTRY " + Px(g.entryPrice),
              (g.tradeDir > 0 ? clrLime : clrMagenta), ANCHOR_LEFT);
   if(g.slPrice > 0.0)
   {
      EnsureSegment(ObjName("SL"), g.entryTime, g.slPrice, tEnd, g.slPrice, clrRed, STYLE_DASH, 1, "SL " + Px(g.slPrice));
      EnsureText(ObjName("SLLBL"), tEnd, g.slPrice, "SL " + Px(g.slPrice), clrRed, ANCHOR_RIGHT_UPPER);
   }
   if(g.tpPrice > 0.0)
   {
      EnsureSegment(ObjName("TP"), g.entryTime, g.tpPrice, tEnd, g.tpPrice, clrLimeGreen, STYLE_DASH, 1, "TP " + Px(g.tpPrice));
      EnsureText(ObjName("TPLBL"), tEnd, g.tpPrice, "TP " + Px(g.tpPrice), clrLimeGreen, ANCHOR_RIGHT_LOWER);
   }
}

void DrawAllForCurrentRange()
{
   if(!g_drawEnabled || !g.valid)
      return;
   DrawReferenceCandle();
   DrawCRTRange();
   DrawCRTHighLow();
   DrawSweepMarker(true);
   DrawSweepMarker(false);
   DrawConfirmationMarker();
   DrawEntrySLTP();
   ChartRedraw(0);
}

//====================================================================
// XÓA OBJECT CỦA CÁC RANGE CŨ NHẤT (giữ InpHistoryCount Range gần nhất)
// Tên object: DAVIDCRT_<TYPE>_<SYMBOL>_<YYYYMMDD>_<HHMM>
//====================================================================
long ObjectRangeKey(string name)
{
   int len = StringLen(name);
   if(len < 13)
      return -1;
   string id = StringSubstr(name, len - 13);      // YYYYMMDD_HHMM
   if(StringSubstr(id, 8, 1) != "_")
      return -1;
   return StringToInteger(StringSubstr(id, 0, 8) + StringSubstr(id, 9, 4));
}

void DeleteOldCRTObjects()
{
   if(!g_drawEnabled)
      return;
   int keep = MathMax(1, InpHistoryCount);
   string symTag = "_" + _Symbol + "_";

   long keys[];
   int  nk = 0;
   int  total = ObjectsTotal(0, -1, -1);
   for(int i = 0; i < total; i++)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, CRT_PREFIX) != 0 || StringFind(name, symTag) < 0)
         continue;
      long k = ObjectRangeKey(name);
      if(k <= 0)
         continue;
      bool found = false;
      for(int j = 0; j < nk; j++)
         if(keys[j] == k) { found = true; break; }
      if(!found)
      {
         ArrayResize(keys, nk + 1);
         keys[nk++] = k;
      }
   }
   if(nk <= keep)
      return;

   ArraySort(keys);                     // tăng dần: cũ nhất trước
   long threshold = keys[nk - keep];    // giữ các key >= threshold

   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, CRT_PREFIX) != 0 || StringFind(name, symTag) < 0)
         continue;
      long k = ObjectRangeKey(name);
      if(k > 0 && k < threshold)
         ObjectDelete(0, name);
   }
}

//====================================================================
// DASHBOARD
//====================================================================
void UpdateDashboard(const MqlTick &tick)
{
   if(g_isTester && !MQLInfoInteger(MQL_VISUAL_MODE))
      return;

   double spread = tick.ask - tick.bid;
   string confirmTxt = "-";
   if(g.confirmed)
      confirmTxt = StringFormat("%s %s (nến %s-%s, Close %s)", (g.confirmDir > 0 ? "BUY" : "SELL"),
                                TimeHM(g.confirmBarTime + PeriodSeconds(CRT_TF_CONFIRM)),
                                TimeHM(g.confirmBarTime), TimeHM(g.confirmBarTime + PeriodSeconds(CRT_TF_CONFIRM)),
                                Px(g.confirmClose));

   //--- RR: thực tế nếu đã vào lệnh, dự kiến (theo giá hiện tại) nếu đang chờ
   string rrTxt = "-", entryTxt = "-", slTxt = "-", tpTxt = "-";
   if(g.traded && g.entryPrice > 0.0)
   {
      rrTxt    = StringFormat("1 : %.2f", g.rr);
      entryTxt = Px(g.entryPrice) + " (" + (g.tradeDir > 0 ? "BUY" : "SELL") + ", khớp thật)";
      slTxt    = Px(g.slPrice);
      tpTxt    = Px(g.tpPrice);
   }
   else if(RangeIsLive() && g.status == ST_WAITING_M15)
   {
      int    dir = (g.lowSwept ? 1 : -1);
      double e   = (dir > 0 ? tick.ask : tick.bid);
      double sl  = (dir > 0 ? g.sweepLow - InpSLBuffer : g.sweepHigh + InpSLBuffer);
      double tp  = (dir > 0 ? g.crtHigh : g.crtLow);
      double r   = MathAbs(e - sl);
      rrTxt = (r > 0.0 ? StringFormat("1 : %.2f (ước tính theo giá hiện tại)", MathAbs(tp - e) / r) : "-");
      slTxt = Px(sl) + " (dự kiến)";
      tpTxt = Px(tp) + " (dự kiến)";
   }

   string s = "";
   s += CRT_EA_NAME + "\n";
   s += "Symbol: " + _Symbol + "   Magic: " + IntegerToString((long)InpMagic) + "\n";
   if(g.refTime > 0)
   {
      s += "Reference H4: " + TimeFull(g.refTime) + " - " + TimeHM(g.refEnd) + "\n";
      s += "Active H4:    " + TimeFull(g.activeStart) + " - " + TimeHM(g.activeEnd) + "\n";
      s += "CRT High: " + Px(g.crtHigh) + "   CRT Low: " + Px(g.crtLow) + "\n";
      s += "H4[2] High: " + Px(g.h2High) + "   H4[2] Low: " + Px(g.h2Low) + "\n";
      s += "Bias: " + BiasText(g.bias) + "\n";
      s += "Low Swept: " + YesNo(g.lowSwept) + "   Sweep Low: " + (g.lowSwept ? Px(g.sweepLow) + " @ " + TimeToString(g.sweepLowTime, TIME_MINUTES | TIME_SECONDS) : "-") + "\n";
      s += "High Swept: " + YesNo(g.highSwept) + "   Sweep High: " + (g.highSwept ? Px(g.sweepHigh) + " @ " + TimeToString(g.sweepHighTime, TIME_MINUTES | TIME_SECONDS) : "-") + "\n";
      s += "M15 Confirm: " + confirmTxt + "\n";
      s += "Entry: " + entryTxt + "\n";
      s += "SL: " + slTxt + "   TP: " + tpTxt + "\n";
      s += "RR: " + rrTxt + "\n";
   }
   s += "Spread: " + DoubleToString(spread, _Digits) + (InpMaxSpread > 0.0 ? " (max " + DoubleToString(InpMaxSpread, _Digits) + ")" : " (lọc tắt)") + "\n";
   s += "Status: " + StatusText(g.status) + "\n";
   if(g.skipReason != "")
      s += "Lý do: " + g.skipReason + "\n";
   Comment(s);
}

//====================================================================
// KẾT THÚC RANGE HIỆN TẠI (Active H4 hết hạn)
//====================================================================
void ExpireCurrentRange(string why)
{
   if(RangeIsLive())
   {
      g.status = ST_EXPIRED;
      WriteCRTLog(StringFormat("EXPIRED: Range %s (%s) - Low Swept %s, High Swept %s",
                               RangeId(g.refTime), why, YesNo(g.lowSwept), YesNo(g.highSwept)));
      MarkDirty();
   }
   else if(g.valid && (g.status == ST_BUY_ACTIVE || g.status == ST_SELL_ACTIVE))
      WriteCRTLog(StringFormat("Range %s kết thúc Active window, position #%I64u vẫn được quản lý bởi SL/TP broker",
                               RangeId(g.refTime), g.positionId), true);
}

//====================================================================
// KHỞI TẠO RANGE (khi H4 mới hoặc khi EA khởi động / restart)
//====================================================================
bool InitializeRange(bool tryRestore)
{
   MqlRates h4[];
   if(!LoadReferenceH4(h4))
      return false;

   CreateCRTRange(h4);

   if(g.valid)
   {
      if(tryRestore)
         RestoreCRTState();
      RestoreTradeFromTerminal();

      //--- Bù các nến M1/M15 đã đóng trong Active (offline / khởi động giữa chừng)
      if(RangeIsLive())
         ReplayClosedM1(true);

      //--- Đánh dấu M15[1] hiện tại là đã xử lý: không bao giờ vào lệnh muộn từ nến cũ
      datetime m15Open1 = iTime(_Symbol, CRT_TF_CONFIRM, 1);
      if(m15Open1 > g.lastM15Processed)
         g.lastM15Processed = m15Open1;
   }

   g_lastM1Seen = iTime(_Symbol, CRT_TF_REPLAY, 0);
   MarkDirty();
   DrawAllForCurrentRange();
   DeleteOldCRTObjects();
   SaveCRTState();
   return true;
}

//====================================================================
// ONINIT / ONDEINIT
//====================================================================
int OnInit()
{
   g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(g_point <= 0.0)
      g_point = _Point;

   g_isTester    = (bool)MQLInfoInteger(MQL_TESTER);
   g_drawEnabled = InpShowCRT && (!g_isTester || (bool)MQLInfoInteger(MQL_VISUAL_MODE));
   g_stateFile   = "DAVIDCRT_" + _Symbol + "_" + IntegerToString((long)InpMagic) + ".state";

   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(InpDeviationPoints);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   if(InpFixedLot <= 0.0 && !InpUseRiskEquity)
   {
      Print("[DAVID CRT] Khối_lượng_cố_định phải > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpUseRiskEquity && InpRiskPercent <= 0.0)
   {
      Print("[DAVID CRT] Rủi_ro_mỗi_lệnh_% phải > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpSLBuffer < 0.0 || InpMaxSpread < 0.0 || InpMinSweep < 0.0 || InpMaxSweep < 0.0 || InpMinRR < 0.0)
   {
      Print("[DAVID CRT] Các tham số giá / bộ lọc không được âm");
      return INIT_PARAMETERS_INCORRECT;
   }

   ResetState();
   g_ready = false;

   WriteCRTLog(StringFormat("%s khởi động | %s | chart TF %s (chiến lược luôn dùng H4 + M15) | Tester=%s",
                            CRT_EA_NAME, _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period), YesNo(g_isTester)));

   //--- Thử khởi tạo ngay; nếu dữ liệu chưa sẵn sàng sẽ thử lại ở OnTick
   g_ready = InitializeRange(true);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   SaveCRTState();
   //--- Không xóa object Range (giữ lịch sử, đổi TF không làm mất/dịch chuyển Range)
   Comment("");
}

//====================================================================
// ONTICK
//====================================================================
void OnTick()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;
   datetime now = tick.time;

   //--- 0. Khởi tạo (dữ liệu H4 có thể chưa sẵn sàng ở OnInit)
   if(!g_ready)
   {
      g_ready = InitializeRange(true);
      if(!g_ready)
      {
         UpdateDashboard(tick);
         return;
      }
   }

   //--- 1. H4 mới -> Range cũ hết hạn, tạo Range mới từ H4[1] vừa đóng
   if(DetectNewH4Bar())
   {
      ExpireCurrentRange("H4 mới bắt đầu");
      SaveCRTState();
      InitializeRange(false);
   }

   //--- Hết Active window nhưng series H4 chưa cập nhật -> hết hạn ngay, không chờ
   if(RangeIsLive() && now >= g.activeEnd)
      ExpireCurrentRange("quá Active End");

   //--- 2. Bù sweep từ các nến M1 vừa đóng (không look-ahead: chỉ nến đã đóng)
   datetime m1Open0 = iTime(_Symbol, CRT_TF_REPLAY, 0);
   if(g.valid && m1Open0 > 0 && m1Open0 != g_lastM1Seen)
   {
      g_lastM1Seen = m1Open0;
      if(RangeIsLive())
         ReplayClosedM1(false);
   }

   //--- 3. M15 vừa đóng -> xét Confirmation trên M15[1] -> Entry tại tick này
   if(g.valid)
   {
      MqlRates m15Closed;
      if(DetectNewM15Bar(m15Closed))
      {
         if(CheckM15Confirmation(m15Closed.time, m15Closed.close, true))
            ExecuteCRTTrade(g.confirmDir, tick);
      }
   }

   //--- 4. Sweep realtime theo Bid của tick hiện tại
   //       (bỏ qua tick nếu series M15 chưa sang nến mới để tick sau giờ đóng
   //        không làm ảnh hưởng confirmation của nến vừa đóng)
   if(RangeIsLive() && now >= g.activeStart && now < g.activeEnd)
   {
      int      m15Sec      = PeriodSeconds(CRT_TF_CONFIRM);
      datetime tickM15Open = (datetime)((long)now - ((long)now % m15Sec));
      datetime m15Open0    = iTime(_Symbol, CRT_TF_CONFIRM, 0);
      if(m15Open0 >= tickM15Open)
         DetectLiquiditySweep(tick.bid, tick.bid, now, now);
   }

   //--- 5. Theo dõi position của Range
   MonitorPosition();

   //--- 6. Lưu state + dashboard
   if(g_dirty)
   {
      SaveCRTState();
      DrawAllForCurrentRange();
      g_dirty = false;
      UpdateDashboard(tick);
      g_lastDashboard = now;
   }
   else if(now != g_lastDashboard)
   {
      UpdateDashboard(tick);
      g_lastDashboard = now;
   }
}
//+------------------------------------------------------------------+
