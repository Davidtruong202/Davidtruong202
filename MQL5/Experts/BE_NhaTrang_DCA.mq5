//+------------------------------------------------------------------+
//|                                             BE_NhaTrang_DCA.mq5  |
//|  Bản viết lại logic của bot DCA "BE Nha Trang v1.0.4" dựa trên   |
//|  TÊN và GIÁ TRỊ tham số trong file .set (không có mã nguồn gốc). |
//|  Tên input giữ nguyên 100% để nạp được file .set gốc.            |
//|  Các điểm phải SUY LUẬN được ghi rõ trong                         |
//|  docs/be_nha_trang/README.md — đọc trước khi dùng.               |
//+------------------------------------------------------------------+
#property copyright "Custom EA"
#property version   "1.00"
#property description "DCA 2 chiều (rổ Buy / rổ Sell độc lập), lọc EMA đa khung,"
#property description "DCA nhân/cộng theo bậc số lệnh, TP/Trailing cả rổ, tỉa lệnh."

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// Enums
//====================================================================
enum ENUM_DCA_MODE
{
   DCA_MULTIPLY = 0, // DCA nhân (lot trước x hệ số)
   DCA_ADD      = 1  // DCA cộng (lot trước + InpAddLot)
};
enum ENUM_PA_MODE
{
   PA_STRONG_BODY = 0, // Nến thân mạnh cùng chiều
   PA_ENGULFING   = 1, // Nến nhấn chìm
   PA_ANY         = 2  // Một trong hai
};

//====================================================================
// Inputs — tên & thứ tự khớp file .set của BE Nha Trang v1.0.4
//====================================================================
input group "Cài đặt chung"
input long            InpMagic               = 967488838;
input bool            InpBotEnabled          = true;
input double          InpInitialLot          = 0.02;
input double          InpMaxLot              = 2.3;
input int             InpMaxPositionsBuy     = 20;
input int             InpMaxPositionsSell    = 17;
input int             InpSlippagePoints      = 20;
input bool            InpAllowBuy            = true;
input bool            InpAllowSell           = true;

input group "Bộ lọc CCI đảo chiều"
input bool            InpUseCCIFilter        = false;
input ENUM_TIMEFRAMES InpCCITF               = PERIOD_M1;
input int             InpCCIPeriod           = 14;
input double          InpCCIOversold         = -95;
input double          InpCCIOverbought       = 95;

input group "EMA M2 - xác nhận xu hướng"
input bool            InpUseEMAFilter        = true;
input ENUM_TIMEFRAMES InpEMATF               = PERIOD_M6;
input int             InpEMAShortPeriod      = 34;
input int             InpEMALongPeriod       = 89;
input double          InpAPercent            = 0.1;   // A%: độ tách tối thiểu EMA ngắn/dài (% giá)
input double          InpBPercent            = 0.35;  // B%: giá cách EMA ngắn tối đa (% giá)
input bool            InpOneEntryPerBar      = true;

input group "EMA M1 - bộ lọc phụ"
input bool            InpUseM1Filter         = true;
input ENUM_TIMEFRAMES InpM1TF                = PERIOD_M12;
input int             InpM1EMAShort          = 10;
input int             InpM1EMALong           = 20;

input group "EMA M15 - bộ lọc phụ"
input bool            InpUseM15Filter        = true;
input ENUM_TIMEFRAMES InpM15TF               = PERIOD_M6;
input int             InpM15EMAShort         = 34;
input int             InpM15EMALong          = 89;

input group "Bộ lọc Hành động giá (Price Action)"
input bool            InpUsePriceAction      = false;
input ENUM_TIMEFRAMES InpPriceActionTF       = PERIOD_M10;
input ENUM_PA_MODE    InpPriceActionMode     = PA_STRONG_BODY;
input double          InpPriceActionMinBody  = 85;    // % thân nến / biên độ nến

input group "DCA - cài đặt dùng chung"
input bool            InpUseDCA              = true;
input ENUM_DCA_MODE   InpDCAMode             = DCA_MULTIPLY;

input group "Bộ lọc DCA theo nến đã đóng"
input ENUM_TIMEFRAMES InpDCATF               = PERIOD_M1;

input group "DCA nhân - 5 hệ số theo số lệnh đang có"
input int             InpDCATrigger1         = 1;
input double          InpMultiplier1         = 1.7;
input int             InpDCATrigger2         = 20;
input double          InpMultiplier2         = 1.3;
input int             InpDCATrigger3         = 8;
input double          InpMultiplier3         = 1.0;
input int             InpDCATrigger4         = 11;
input double          InpMultiplier4         = 1.3;
input int             InpDCATrigger5         = 99;
input double          InpMultiplier5         = 1.5;

input group "Khoảng cách DCA (pip) - 5 bước và số lệnh kích hoạt riêng"
input int             InpDistanceTrigger1    = 1;
input double          InpDistance1           = 150;
input int             InpDistanceTrigger2    = 12;
input double          InpDistance2           = 200;
input int             InpDistanceTrigger3    = 8;
input double          InpDistance3           = 250;
input int             InpDistanceTrigger4    = 18;
input double          InpDistance4           = 300;
input int             InpDistanceTrigger5    = 9;
input double          InpDistance5           = 350;

input group "DCA cộng"
input double          InpAddLot              = 0.01;

input group "TP / SL cho cả rổ lệnh (pip chuẩn XAU)"
input double          InpTakeProfit          = 150;
input double          InpStopLoss            = 0;

input group "TP riêng cho lệnh đầu (pip chuẩn XAU)"
input double          InpFirstOrderTakeProfit = 0;

input group "Trailing cho cả rổ lệnh (pip)"
input bool            InpUseTrailing         = false;
input double          InpTrailingStart       = 150;
input double          InpTrailingDistance    = 110;
input double          InpTrailingStep        = 50;

input group "Tỉa lệnh cùng chuỗi"
input bool            InpUsePruning          = false;
input bool            InpPruneIgnoreMagic    = false;
input int             InpPruneTrigger1       = 12;
input int             InpPruneTrigger2       = 15;
input int             InpPruneOldestCount    = 2;
input int             InpPruneMaxNewest      = 0;     // 0 = không giới hạn
input double          InpPruneProfitPercent  = 10;
input double          InpPruneProfitMoney    = 10;
input double          InpPruneTakeProfitPips = 5;
input double          InpPruneMultiplier     = 1.15;

input group "Tỉa một phần lệnh đầu"
input bool            InpUsePartialPruning      = false;
input double          InpPartialExitLossPercent = -30;
input int             InpPartialPruneTrigger    = 20;
input double          InpPartialOldLotPercent   = 30;
input double          InpPartialProfitPercent   = 20;
input double          InpPartialProfitMoney     = 10;
input int             InpPartialMaxNewest       = 0;  // 0 = không giới hạn

input group "Giới hạn giờ giao dịch (giờ máy chủ broker)"
input bool            InpUseTradingHours      = false;
input int             InpStartHour            = 0;
input int             InpEndHour              = 23;
input bool            InpAllowDCAOutsideHours = true;

input group "Giảm lot theo khung giờ máy chủ"
input bool            InpUseLotReduction       = true;
input int             InpLotReductionStartHour = 11;
input int             InpLotReductionEndHour   = 5;
input double          InpLotReductionFactor    = 0.3;

input group "Hiển thị bảng quản lý trên chart"
input bool            InpShowTrailingPanel   = false;
input int             InpPanelUpdateSeconds  = 99999;
input bool            InpShowTradeLevels     = false;

input group "Mở rộng (không có trong bản gốc)"
input double          InpPipSize             = 0;     // 0 = tự động (XAU/GOLD: 0.1)

//====================================================================
// Structs & globals
//====================================================================
struct PosInfo
{
   ulong  ticket;
   long   tmsc;
   double price;
   double volume;
   double profit;   // profit + swap, tiền tài khoản
   double sl;
   double tp;
};

// index 0 = Buy, 1 = Sell
int      g_hEmaS = INVALID_HANDLE, g_hEmaL = INVALID_HANDLE;
int      g_hM1S  = INVALID_HANDLE, g_hM1L  = INVALID_HANDLE;
int      g_hM15S = INVALID_HANDLE, g_hM15L = INVALID_HANDLE;
int      g_hCCI  = INVALID_HANDLE;

double   g_pip = 0.1;
datetime g_lastEntryBar[2] = {0, 0};
datetime g_lastDcaBar[2]   = {0, 0};
double   g_trailSL[2]      = {0, 0};
datetime g_lastPanel       = 0;

int      g_dcaTrig[5];  double g_dcaMult[5];
int      g_distTrig[5]; double g_dist[5];

// Thống kê in ra khi kết thúc (giúp debug "0 lệnh")
int      g_statFirst = 0, g_statDca = 0, g_statBasketClose = 0;
int      g_statPrune = 0, g_statPartial = 0, g_statFilterBlock = 0;

//====================================================================
// Tiện ích
//====================================================================
int    SideIdx(bool buy) { return buy ? 0 : 1; }
string SideStr(bool buy) { return buy ? "BUY" : "SELL"; }

double DetectPip()
{
   if(InpPipSize > 0) return InpPipSize;
   string s = _Symbol;
   StringToUpper(s);
   if(StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0) return 0.1;
   if(_Digits == 3 || _Digits == 5) return 10.0 * _Point;
   return _Point;
}

int ServerHour()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.hour;
}

// Khung giờ [start..end] tính cả giờ end, hỗ trợ qua nửa đêm (vd 11 -> 5)
bool InHourWindow(int start, int end)
{
   int h = ServerHour();
   if(start <= end) return (h >= start && h <= end);
   return (h >= start || h <= end);
}

double NormPrice(double p) { return NormalizeDouble(p, _Digits); }

int VolumeDigits()
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0) return 2;
   return (int)MathMax(0, MathCeil(-MathLog10(step) - 1e-9));
}

// Làm tròn lot về bước khối lượng (gần nhất), kẹp theo min/max của sàn và InpMaxLot
double NormLot(double lot)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double mn   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double mx   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0) step = 0.01;
   if(InpMaxLot > 0) lot = MathMin(lot, InpMaxLot);
   lot = MathRound(lot / step) * step;
   lot = MathMax(lot, mn);
   lot = MathMin(lot, mx);
   return NormalizeDouble(lot, VolumeDigits());
}

// Giá trị theo bậc: lấy bậc có trigger lớn nhất mà <= n (các trigger không cần sắp xếp)
double TierValue(int n, const int &trig[], const double &val[], double below)
{
   int    best = -1;
   double v    = below;
   for(int i = 0; i < ArraySize(trig); i++)
      if(trig[i] <= n && trig[i] > best) { best = trig[i]; v = val[i]; }
   return v;
}

// Hệ số nhân khi mở lệnh DCA thứ n+1 (đang có n lệnh)
double MultFor(int n)
{
   if(InpUsePruning && n >= InpPruneTrigger1) return InpPruneMultiplier;
   return TierValue(n, g_dcaTrig, g_dcaMult, 1.0);
}

// Khoảng cách DCA (pip) khi đang có n lệnh
double DistanceFor(int n)
{
   // n nhỏ hơn mọi trigger: dùng bậc có trigger nhỏ nhất
   int    minT = INT_MAX;
   double minV = g_dist[0];
   for(int i = 0; i < 5; i++) if(g_distTrig[i] < minT) { minT = g_distTrig[i]; minV = g_dist[i]; }
   return TierValue(n, g_distTrig, g_dist, minV);
}

// Lot lý thuyết (chưa làm tròn) của lệnh thứ n+1 trong chuỗi, tính từ lot gốc.
// Tính từ lot gốc thay vì lot đã làm tròn để 0.006 x 1.7 không bị kẹt ở min lot.
double ChainLot(double base, int n)
{
   double lot = base;
   for(int k = 1; k <= n; k++)
   {
      if(InpDCAMode == DCA_MULTIPLY) lot *= MultFor(k);
      else                           lot += InpAddLot;
   }
   return lot;
}

string BaseGVName(bool buy)
{
   return StringFormat("BENT_%I64d_%s_base_%s", InpMagic, _Symbol, buy ? "B" : "S");
}

void SaveBase(bool buy, double base) { GlobalVariableSet(BaseGVName(buy), base); }
void ClearBase(bool buy)
{
   if(GlobalVariableCheck(BaseGVName(buy))) GlobalVariableDel(BaseGVName(buy));
}
double LoadBase(bool buy, const PosInfo &p[], int n)
{
   if(GlobalVariableCheck(BaseGVName(buy))) return GlobalVariableGet(BaseGVName(buy));
   return (n > 0 ? p[0].volume : InpInitialLot); // khôi phục sau khi khởi động lại
}

//====================================================================
// Vị thế
//====================================================================
int CollectSide(bool buy, bool anyMagic, PosInfo &arr[])
{
   ArrayResize(arr, 0);
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(!anyMagic && PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if(buy  && type != POSITION_TYPE_BUY)  continue;
      if(!buy && type != POSITION_TYPE_SELL) continue;

      ArrayResize(arr, n + 1);
      arr[n].ticket = t;
      arr[n].tmsc   = PositionGetInteger(POSITION_TIME_MSC);
      arr[n].price  = PositionGetDouble(POSITION_PRICE_OPEN);
      arr[n].volume = PositionGetDouble(POSITION_VOLUME);
      arr[n].profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      arr[n].sl     = PositionGetDouble(POSITION_SL);
      arr[n].tp     = PositionGetDouble(POSITION_TP);
      n++;
   }
   // Sắp xếp cũ -> mới (insertion sort, n nhỏ)
   for(int i = 1; i < n; i++)
   {
      PosInfo key = arr[i];
      int j = i - 1;
      while(j >= 0 && (arr[j].tmsc > key.tmsc || (arr[j].tmsc == key.tmsc && arr[j].ticket > key.ticket)))
      {
         arr[j + 1] = arr[j];
         j--;
      }
      arr[j + 1] = key;
   }
   return n;
}

double AvgPrice(const PosInfo &p[], int n, double &totalVol)
{
   double pv = 0;
   totalVol = 0;
   for(int i = 0; i < n; i++) { pv += p[i].price * p[i].volume; totalVol += p[i].volume; }
   return (totalVol > 0 ? pv / totalVol : 0);
}

double SumProfit(const PosInfo &p[], int n)
{
   double s = 0;
   for(int i = 0; i < n; i++) s += p[i].profit;
   return s;
}

void CloseAll(const PosInfo &p[], int n, string why)
{
   for(int i = n - 1; i >= 0; i--)
      if(!trade.PositionClose(p[i].ticket, InpSlippagePoints))
         PrintFormat("[BENT] Đóng #%I64u lỗi: %d %s", p[i].ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
   PrintFormat("[BENT] Đóng rổ %d lệnh: %s", n, why);
}

bool OpenOrder(bool buy, double lot, string comment)
{
   double price = buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double margin = 0;
   if(OrderCalcMargin(buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, lot, price, margin) &&
      margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
   {
      PrintFormat("[BENT] Không đủ ký quỹ cho %s %.2f lot (cần %.2f, còn %.2f)",
                  SideStr(buy), lot, margin, AccountInfoDouble(ACCOUNT_MARGIN_FREE));
      return false;
   }
   bool ok = buy ? trade.Buy(lot, _Symbol, 0, 0, 0, comment)
                 : trade.Sell(lot, _Symbol, 0, 0, 0, comment);
   uint rc = trade.ResultRetcode();
   if(!ok || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_PLACED))
   {
      PrintFormat("[BENT] Mở %s %.2f lỗi: %u %s", SideStr(buy), lot, rc, trade.ResultRetcodeDescription());
      return false;
   }
   return true;
}

//====================================================================
// Bộ lọc vào lệnh đầu tiên
//====================================================================
bool ReadBuf(int handle, int shift, double &v)
{
   double b[];
   if(handle == INVALID_HANDLE) return false;
   if(CopyBuffer(handle, 0, shift, 1, b) != 1) return false;
   v = b[0];
   return true;
}

bool EmaPairDir(int hS, int hL, bool buy)
{
   double s, l;
   if(!ReadBuf(hS, 1, s) || !ReadBuf(hL, 1, l)) return false;
   return buy ? (s > l) : (s < l);
}

bool FilterEMA(bool buy)
{
   double s, l;
   if(!ReadBuf(g_hEmaS, 1, s) || !ReadBuf(g_hEmaL, 1, l)) return false;
   double price = buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0) return false;
   if(buy  && !(s > l)) return false;
   if(!buy && !(s < l)) return false;
   double gapPct  = MathAbs(s - l) / price * 100.0;       // độ mạnh xu hướng
   double distPct = MathAbs(price - s) / price * 100.0;   // không đuổi giá
   if(gapPct < InpAPercent) return false;
   if(InpBPercent > 0 && distPct > InpBPercent) return false;
   return true;
}

// CCI đảo chiều: Buy khi CCI vừa cắt lên khỏi vùng quá bán, Sell khi vừa cắt xuống khỏi vùng quá mua
bool FilterCCI(bool buy)
{
   double c1, c2;
   if(!ReadBuf(g_hCCI, 1, c1) || !ReadBuf(g_hCCI, 2, c2)) return false;
   if(buy) return (c2 <= InpCCIOversold && c1 > InpCCIOversold);
   return (c2 >= InpCCIOverbought && c1 < InpCCIOverbought);
}

bool FilterPriceAction(bool buy)
{
   ENUM_TIMEFRAMES tf = InpPriceActionTF;
   double o1 = iOpen(_Symbol, tf, 1), c1 = iClose(_Symbol, tf, 1);
   double h1 = iHigh(_Symbol, tf, 1), l1 = iLow(_Symbol, tf, 1);
   double o2 = iOpen(_Symbol, tf, 2), c2 = iClose(_Symbol, tf, 2);
   if(o1 == 0 || o2 == 0) return false;

   bool strong = false, engulf = false;
   double range = h1 - l1;
   if(range > 0)
   {
      double bodyPct = MathAbs(c1 - o1) / range * 100.0;
      strong = (bodyPct >= InpPriceActionMinBody) && (buy ? c1 > o1 : c1 < o1);
   }
   if(buy) engulf = (c2 < o2) && (c1 > o1) && (c1 >= o2) && (o1 <= c2);
   else    engulf = (c2 > o2) && (c1 < o1) && (c1 <= o2) && (o1 >= c2);

   switch(InpPriceActionMode)
   {
      case PA_STRONG_BODY: return strong;
      case PA_ENGULFING:   return engulf;
      default:             return strong || engulf;
   }
}

bool FiltersOK(bool buy)
{
   if(InpUseEMAFilter   && !FilterEMA(buy))                          return false;
   if(InpUseM1Filter    && !EmaPairDir(g_hM1S, g_hM1L, buy))         return false;
   if(InpUseM15Filter   && !EmaPairDir(g_hM15S, g_hM15L, buy))       return false;
   if(InpUseCCIFilter   && !FilterCCI(buy))                          return false;
   if(InpUsePriceAction && !FilterPriceAction(buy))                  return false;
   return true;
}

//====================================================================
// Lệnh đầu tiên
//====================================================================
void CheckFirstEntry(bool buy)
{
   int s = SideIdx(buy);
   if(buy && !InpAllowBuy)   return;
   if(!buy && !InpAllowSell) return;
   if(InpUseTradingHours && !InHourWindow(InpStartHour, InpEndHour)) return;

   datetime bar = iTime(_Symbol, InpEMATF, 0);
   if(bar == 0) return;
   if(InpOneEntryPerBar && bar == g_lastEntryBar[s]) return;

   if(!FiltersOK(buy))
   {
      g_statFilterBlock++;
      return;
   }

   double base = InpInitialLot;
   if(InpUseLotReduction && InHourWindow(InpLotReductionStartHour, InpLotReductionEndHour))
      base *= InpLotReductionFactor;

   double lot = NormLot(base);
   if(OpenOrder(buy, lot, StringFormat("BENT %s #1", buy ? "B" : "S")))
   {
      g_lastEntryBar[s] = bar;
      g_lastDcaBar[s]   = iTime(_Symbol, InpDCATF, 0); // không DCA ngay trên cùng nến
      g_trailSL[s]      = 0;
      SaveBase(buy, base);
      g_statFirst++;
   }
}

//====================================================================
// DCA
//====================================================================
void CheckDCA(bool buy, const PosInfo &p[], int n)
{
   int s = SideIdx(buy);
   if(!InpUseDCA || n == 0) return;
   int maxPos = buy ? InpMaxPositionsBuy : InpMaxPositionsSell;
   if(n >= maxPos) return;
   if(InpUseTradingHours && !InpAllowDCAOutsideHours && !InHourWindow(InpStartHour, InpEndHour)) return;

   // Chỉ xét 1 lần mỗi nến DCATF, dùng giá đóng cửa của nến vừa đóng
   datetime bar = iTime(_Symbol, InpDCATF, 0);
   if(bar == 0 || bar == g_lastDcaBar[s]) return;

   double closed = iClose(_Symbol, InpDCATF, 1);
   if(closed <= 0) return;

   double last = p[n - 1].price;                 // lệnh mới nhất
   double dist = DistanceFor(n) * g_pip;
   double cur  = buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   bool trigger = buy ? (closed <= last - dist && cur <= last)
                      : (closed >= last + dist && cur >= last);
   if(!trigger)
   {
      g_lastDcaBar[s] = bar;
      return;
   }

   double base = LoadBase(buy, p, n);
   double lot  = NormLot(ChainLot(base, n));
   if(OpenOrder(buy, lot, StringFormat("BENT %s #%d", buy ? "B" : "S", n + 1)))
   {
      g_lastDcaBar[s] = bar;
      g_statDca++;
      PrintFormat("[BENT] DCA %s #%d lot=%.2f dist=%.0f pip (last=%.2f close=%.2f)",
                  SideStr(buy), n + 1, lot, DistanceFor(n), last, closed);
   }
}

//====================================================================
// TP / SL / Trailing cả rổ. Trả về true nếu đã đóng rổ.
//====================================================================
bool ManageBasketExit(bool buy, const PosInfo &p[], int n)
{
   int    s   = SideIdx(buy);
   double vol = 0;
   double avg = AvgPrice(p, n, vol);
   if(avg <= 0) return false;
   double cur = buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double dir = buy ? 1.0 : -1.0;

   // --- TP
   double tpPips = (n == 1 && InpFirstOrderTakeProfit > 0) ? InpFirstOrderTakeProfit : InpTakeProfit;
   double tp = (tpPips > 0) ? NormPrice(avg + dir * tpPips * g_pip) : 0;

   // --- SL cố định cả rổ
   double sl = (InpStopLoss > 0) ? NormPrice(avg - dir * InpStopLoss * g_pip) : 0;

   // --- Trailing cả rổ
   if(InpUseTrailing)
   {
      if(g_trailSL[s] == 0) // khôi phục sau khởi động lại
         for(int i = 0; i < n; i++)
            if(p[i].sl > 0 && dir * (p[i].sl - avg) > 0) { g_trailSL[s] = p[i].sl; break; }

      double profitPips = dir * (cur - avg) / g_pip;
      if(profitPips >= InpTrailingStart)
      {
         double cand = NormPrice(cur - dir * InpTrailingDistance * g_pip);
         if(g_trailSL[s] == 0 || dir * (cand - g_trailSL[s]) >= InpTrailingStep * g_pip)
            g_trailSL[s] = cand;
      }
      if(g_trailSL[s] > 0 && (sl == 0 || dir * (g_trailSL[s] - sl) > 0)) sl = g_trailSL[s];
   }

   // --- Thoát ảo (phòng khi SL/TP server không đặt được)
   if(tp > 0 && dir * (cur - tp) >= 0) { CloseAll(p, n, StringFormat("TP rổ %s", SideStr(buy))); g_statBasketClose++; g_trailSL[s] = 0; return true; }
   if(sl > 0 && dir * (cur - sl) <= 0) { CloseAll(p, n, StringFormat("SL/Trailing rổ %s", SideStr(buy))); g_statBasketClose++; g_trailSL[s] = 0; return true; }

   // --- Đồng bộ SL/TP lên server
   double stopLvl = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   bool tpValid = (tp == 0) || (dir * (tp - cur) > stopLvl);
   bool slValid = (sl == 0) || (dir * (cur - sl) > stopLvl);
   for(int i = 0; i < n; i++)
   {
      double newTp = tpValid ? tp : p[i].tp;
      double newSl = slValid ? sl : p[i].sl;
      if(MathAbs(newTp - p[i].tp) < _Point / 2 && MathAbs(newSl - p[i].sl) < _Point / 2) continue;
      if(!trade.PositionModify(p[i].ticket, newSl, newTp))
         PrintFormat("[BENT] Sửa SL/TP #%I64u lỗi: %u %s", p[i].ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
   }
   return false;
}

//====================================================================
// Tỉa lệnh cùng chuỗi: dùng lãi các lệnh mới nhất để đóng các lệnh cũ nhất đang lỗ
//====================================================================
bool DoPrune(bool buy)
{
   PosInfo p[];
   int n = CollectSide(buy, InpPruneIgnoreMagic, p);
   if(n < InpPruneTrigger1 || InpPruneOldestCount <= 0) return false;

   int k = MathMin(InpPruneOldestCount, n - 1);
   if(k <= 0) return false;

   double oldLoss = 0;
   for(int i = 0; i < k; i++) oldLoss += p[i].profit;
   if(oldLoss >= 0) return false;

   double need = (n >= InpPruneTrigger2)
                 ? InpPruneProfitMoney
                 : MathMax(InpPruneProfitMoney, MathAbs(oldLoss) * InpPruneProfitPercent / 100.0);

   double dir = buy ? 1.0 : -1.0;
   double cur = buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   ulong  win[];
   int    w = 0;
   double sumWin = 0;
   for(int i = n - 1; i >= k; i--)
   {
      if(InpPruneMaxNewest > 0 && w >= InpPruneMaxNewest) break;
      double pips = dir * (cur - p[i].price) / g_pip;
      if(p[i].profit <= 0 || pips < InpPruneTakeProfitPips) continue;
      ArrayResize(win, w + 1);
      win[w++] = p[i].ticket;
      sumWin += p[i].profit;
      if(sumWin + oldLoss >= need) break;
   }
   if(w == 0 || sumWin + oldLoss < need) return false;

   for(int i = 0; i < w; i++) trade.PositionClose(win[i], InpSlippagePoints);
   for(int i = 0; i < k; i++) trade.PositionClose(p[i].ticket, InpSlippagePoints);
   g_statPrune++;
   PrintFormat("[BENT] Tỉa %s: đóng %d lệnh cũ (lỗ %.2f) bằng %d lệnh mới (lãi %.2f), ròng %.2f",
               SideStr(buy), k, oldLoss, w, sumWin, sumWin + oldLoss);
   return true;
}

//====================================================================
// Tỉa một phần lệnh đầu: đóng X% lot lệnh cũ nhất bằng lãi các lệnh mới nhất
//====================================================================
bool DoPartialPrune(bool buy)
{
   PosInfo p[];
   int n = CollectSide(buy, false, p);
   if(n < 2) return false;

   double bal   = AccountInfoDouble(ACCOUNT_BALANCE);
   double ddPct = (bal > 0) ? SumProfit(p, n) / bal * 100.0 : 0;
   if(n < InpPartialPruneTrigger && ddPct > InpPartialExitLossPercent) return false;

   PosInfo old = p[0];
   if(old.profit >= 0) return false;

   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double mn   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(step <= 0) step = 0.01;
   double cv = MathFloor(old.volume * InpPartialOldLotPercent / 100.0 / step + 1e-9) * step;
   if(cv < mn) cv = mn;
   if(old.volume - cv < mn - 1e-9) cv = old.volume;   // phần còn lại quá nhỏ -> đóng hết
   cv = NormalizeDouble(cv, VolumeDigits());

   double partLoss = old.profit * cv / old.volume;
   double need = MathMax(InpPartialProfitMoney, MathAbs(partLoss) * InpPartialProfitPercent / 100.0);

   ulong  win[];
   int    w = 0;
   double sumWin = 0;
   for(int i = n - 1; i >= 1; i--)
   {
      if(InpPartialMaxNewest > 0 && w >= InpPartialMaxNewest) break;
      if(p[i].profit <= 0) continue;
      ArrayResize(win, w + 1);
      win[w++] = p[i].ticket;
      sumWin += p[i].profit;
      if(sumWin + partLoss >= need) break;
   }
   if(w == 0 || sumWin + partLoss < need) return false;

   for(int i = 0; i < w; i++) trade.PositionClose(win[i], InpSlippagePoints);
   bool ok = (cv >= old.volume) ? trade.PositionClose(old.ticket, InpSlippagePoints)
                                : trade.PositionClosePartial(old.ticket, cv, InpSlippagePoints);
   if(!ok) PrintFormat("[BENT] Đóng một phần #%I64u lỗi: %u", old.ticket, trade.ResultRetcode());
   g_statPartial++;
   PrintFormat("[BENT] Tỉa một phần %s: đóng %.2f/%.2f lot lệnh đầu (lỗ %.2f) bằng %d lệnh (lãi %.2f)",
               SideStr(buy), cv, old.volume, partLoss, w, sumWin);
   return true;
}

//====================================================================
// Hiển thị
//====================================================================
void DrawLine(string name, double price, color clr)
{
   if(price <= 0) { ObjectDelete(0, name); return; }
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
   else ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
}

string SideSummary(bool buy)
{
   PosInfo p[];
   int n = CollectSide(buy, false, p);
   if(n == 0)
   {
      if(InpShowTradeLevels) { DrawLine("BENT_AVG_" + SideStr(buy), 0, clrNONE); DrawLine("BENT_NEXT_" + SideStr(buy), 0, clrNONE); }
      return StringFormat("%s: 0 lệnh\n", SideStr(buy));
   }
   double vol = 0, avg = AvgPrice(p, n, vol);
   double dir  = buy ? 1.0 : -1.0;
   double next = p[n - 1].price - dir * DistanceFor(n) * g_pip;
   double nextLot = NormLot(ChainLot(LoadBase(buy, p, n), n));
   if(InpShowTradeLevels)
   {
      DrawLine("BENT_AVG_" + SideStr(buy), avg, buy ? clrDodgerBlue : clrOrangeRed);
      DrawLine("BENT_NEXT_" + SideStr(buy), next, clrGray);
   }
   return StringFormat("%s: %d lệnh | %.2f lot | TB %.2f | lãi/lỗ %.2f | DCA kế: %.2f @ %.2f | trail %.2f\n",
                       SideStr(buy), n, vol, avg, SumProfit(p, n), nextLot, next, g_trailSL[SideIdx(buy)]);
}

void UpdateDisplay()
{
   if(!InpShowTrailingPanel && !InpShowTradeLevels) return;
   datetime now = TimeCurrent();
   if(g_lastPanel != 0 && now - g_lastPanel < MathMax(1, InpPanelUpdateSeconds)) return;
   g_lastPanel = now;
   string txt = "BE Nha Trang DCA (bản viết lại)\n" + SideSummary(true) + SideSummary(false);
   if(InpShowTrailingPanel) Comment(txt);
}

//====================================================================
// Vòng chính
//====================================================================
void ProcessSide(bool buy)
{
   PosInfo p[];
   int n = CollectSide(buy, false, p);
   if(n > 0)
   {
      if(ManageBasketExit(buy, p, n)) return;
      if(!InpBotEnabled) return;
      if(InpUsePartialPruning && DoPartialPrune(buy)) return;
      if(InpUsePruning && DoPrune(buy)) return;
      CheckDCA(buy, p, n);
   }
   else
   {
      g_trailSL[SideIdx(buy)] = 0;
      ClearBase(buy);
      if(InpBotEnabled) CheckFirstEntry(buy);
   }
}

int MakeEMA(ENUM_TIMEFRAMES tf, int period)
{
   int h = iMA(_Symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if(h == INVALID_HANDLE) PrintFormat("[BENT] Không tạo được EMA(%d) %s", period, EnumToString(tf));
   return h;
}

int OnInit()
{
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Print("[BENT] Cần tài khoản HEDGING (rổ Buy và rổ Sell chạy song song).");
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber((ulong)InpMagic);
   trade.SetDeviationInPoints(InpSlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);

   g_pip = DetectPip();

   g_dcaTrig[0] = InpDCATrigger1; g_dcaMult[0] = InpMultiplier1;
   g_dcaTrig[1] = InpDCATrigger2; g_dcaMult[1] = InpMultiplier2;
   g_dcaTrig[2] = InpDCATrigger3; g_dcaMult[2] = InpMultiplier3;
   g_dcaTrig[3] = InpDCATrigger4; g_dcaMult[3] = InpMultiplier4;
   g_dcaTrig[4] = InpDCATrigger5; g_dcaMult[4] = InpMultiplier5;

   g_distTrig[0] = InpDistanceTrigger1; g_dist[0] = InpDistance1;
   g_distTrig[1] = InpDistanceTrigger2; g_dist[1] = InpDistance2;
   g_distTrig[2] = InpDistanceTrigger3; g_dist[2] = InpDistance3;
   g_distTrig[3] = InpDistanceTrigger4; g_dist[3] = InpDistance4;
   g_distTrig[4] = InpDistanceTrigger5; g_dist[4] = InpDistance5;

   if(InpUseEMAFilter)
   {
      g_hEmaS = MakeEMA(InpEMATF, InpEMAShortPeriod);
      g_hEmaL = MakeEMA(InpEMATF, InpEMALongPeriod);
      if(g_hEmaS == INVALID_HANDLE || g_hEmaL == INVALID_HANDLE) return INIT_FAILED;
   }
   if(InpUseM1Filter)
   {
      g_hM1S = MakeEMA(InpM1TF, InpM1EMAShort);
      g_hM1L = MakeEMA(InpM1TF, InpM1EMALong);
      if(g_hM1S == INVALID_HANDLE || g_hM1L == INVALID_HANDLE) return INIT_FAILED;
   }
   if(InpUseM15Filter)
   {
      g_hM15S = MakeEMA(InpM15TF, InpM15EMAShort);
      g_hM15L = MakeEMA(InpM15TF, InpM15EMALong);
      if(g_hM15S == INVALID_HANDLE || g_hM15L == INVALID_HANDLE) return INIT_FAILED;
   }
   if(InpUseCCIFilter)
   {
      g_hCCI = iCCI(_Symbol, InpCCITF, InpCCIPeriod, PRICE_TYPICAL);
      if(g_hCCI == INVALID_HANDLE) return INIT_FAILED;
   }

   PrintFormat("[BENT] Khởi động %s pip=%.5f magic=%I64d lot đầu=%.2f", _Symbol, g_pip, InpMagic, InpInitialLot);
   // In bảng lot/khoảng cách lý thuyết để đối chiếu với bot gốc
   string row = "";
   for(int n = 0; n < MathMax(InpMaxPositionsBuy, InpMaxPositionsSell); n++)
      row += StringFormat("#%d:%.2f/%.0fp ", n + 1, NormLot(ChainLot(InpInitialLot, n)), (n > 0 ? DistanceFor(n) : 0.0));
   Print("[BENT] Chuỗi lot/khoảng cách: ", row);
   return INIT_SUCCEEDED;
}

void ReleaseHandle(int &h)
{
   if(h != INVALID_HANDLE) IndicatorRelease(h);
   h = INVALID_HANDLE;
}

void OnDeinit(const int reason)
{
   ReleaseHandle(g_hEmaS); ReleaseHandle(g_hEmaL);
   ReleaseHandle(g_hM1S);  ReleaseHandle(g_hM1L);
   ReleaseHandle(g_hM15S); ReleaseHandle(g_hM15L);
   ReleaseHandle(g_hCCI);
   ObjectsDeleteAll(0, "BENT_");
   Comment("");
   PrintFormat("[BENT Summary] lệnh đầu=%d DCA=%d đóng rổ=%d tỉa=%d tỉa-một-phần=%d tick bị bộ lọc chặn=%d",
               g_statFirst, g_statDca, g_statBasketClose, g_statPrune, g_statPartial, g_statFilterBlock);
}

void OnTick()
{
   ProcessSide(true);
   ProcessSide(false);
   UpdateDisplay();
}
//+------------------------------------------------------------------+
