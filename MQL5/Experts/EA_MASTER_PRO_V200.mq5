//+------------------------------------------------------------------+
//|                                          EA_MASTER_PRO_V200.mq5  |
//|  EA MASTER PRO - bản chạy TÀI KHOẢN THẬT (hỗ trợ tài khoản Cent)  |
//|                                                                  |
//|  - Bộ máy PP2 (SMC Order Block) + PP4 (Quasimodo) giữ nguyên từ   |
//|    EA_MASTER_SETAO_V100 (đã backtest).                            |
//|  - Mỗi SET chọn chế độ: THAT=1 vào lệnh thật, THAT=0 chạy ảo để   |
//|    tiếp tục so sánh. Mặc định chỉ F6 vào lệnh thật.               |
//|  - Lệnh thật luôn có SL/TP trên server, magic riêng từng SET/PP:  |
//|    Magic = Magic_Goc*100 + số SET*10 + PP (26 -> SET6 PP2 = 2662).|
//|  - Bảo vệ: rủi ro % mỗi lệnh, chốt chặn lỗ tại SL, giới hạn số    |
//|    lệnh, DD ngày, DD tổng, lọc spread.                            |
//+------------------------------------------------------------------+
#property copyright "EA MASTER PRO"
#property version   "2.00"
#property description "EA MASTER PRO - PP2 SMC + PP4 QM, nhiều SET (thật / ảo), hỗ trợ tài khoản Cent."
#property description "Lệnh thật luôn có SL. Hãy chạy demo trước khi dùng tiền thật."

#include <Trade\Trade.mqh>

#define MAX_SET     8
#define DIR_BULL    1
#define DIR_BEAR    -1
#define OBJ_PREFIX  "EAMP_"
#define EA_VER      "2.00"

//+------------------------------------------------------------------+
//| INPUT                                                            |
//+------------------------------------------------------------------+
input group "=== 1. LỆNH THẬT ==="
input long   Magic_Goc         = 26;    // Magic gốc (lệnh SET n, PP p = Magic_Goc*100 + n*10 + p)
input double RuiRo_That_PT     = 1.0;   // Rủi ro mỗi lệnh THẬT (% Balance) - backtest dùng 3%
input double Lot_ToiDa_That    = 5.0;   // Lot tối đa cho 1 lệnh thật
input double ChotChan_PT       = 5.0;   // Bỏ lệnh thật nếu lỗ tại SL > % Balance này
input int    MaxLenhThat_Tong  = 4;     // Tối đa tổng số lệnh thật đang mở
input int    TruotGia_Points   = 50;    // Trượt giá tối đa (points)
input double Spread_ToiDa_Pips = 50.0;  // Spread tối đa để vào lệnh (pip; XAU 1 pip = 0.10 giá)

input group "=== 2. BẢO VỆ TÀI KHOẢN (chỉ chặn lệnh MỚI) ==="
input bool   Bat_DDNgay        = true;  // Bật giới hạn DD trong ngày
input double DDNgay_PT         = 10.0;  // DD ngày tối đa (% balance đầu ngày)
input bool   Bat_DDTong        = true;  // Bật giới hạn DD tổng (từ đỉnh equity)
input double DDTong_PT         = 30.0;  // DD tổng tối đa (%)
input bool   DongHetKhiVuotDD  = false; // Đóng toàn bộ lệnh thật của EA khi vượt DD

input group "=== 3. SET ẢO (so sánh) ==="
input double VonAo_MoiSet      = 0.0;   // Vốn ảo mỗi SET (0 = bằng Balance lúc bắt đầu)
input double Risk_PT           = 3.0;   // Rủi ro mỗi lệnh ẢO (% vốn ảo)

input group "=== 4. CHUNG ==="
input string MaPhien               = "PRO1"; // Mã phiên (tên file kết quả / trạng thái)
input double KichThuocPip_TuyChinh = 0.0;    // Kích thước 1 pip (0 = tự động, XAU = 0.10)
input bool   ResetTrangThai        = false;  // Đếm lại số liệu SET từ đầu
input bool   GhiCSV                = true;   // Ghi nhật ký lệnh + tổng kết ra CSV (Common\Files)
input bool   HienThiBang           = true;   // Hiển thị bảng điều khiển trên chart
input bool   InLog                 = true;   // In log mở/đóng lệnh

input group "=== 5. CÁC SET (THAT=1 = lệnh thật, THAT=0 = ảo, để trống = tắt) ==="
input string Set1 = "TEN=F1_PP2H1_PP4H1;THAT=0;PP2=H1;OB=IN;RR=1.5;XN=1;SLD=10;PP4=H1;RR4=2;E2=1;BE=1";      // SET 1
input string Set2 = "TEN=F2_PP2H1ALL_PP4H1;THAT=0;PP2=H1;OB=ALL;RR=1.5;XN=1;SLD=5;PP4=H1;RR4=2;E2=1;BE=1";   // SET 2
input string Set3 = "TEN=F3_PP2H1;THAT=0;PP2=H1;OB=IN;RR=1.5;XN=1;SLD=10;BE=1";                               // SET 3
input string Set4 = "TEN=F4_PP2M15SW_RR3;THAT=0;PP2=M15;OB=SW;RR=3;XN=0;SLD=5;BE=0";                           // SET 4
input string Set5 = "TEN=F5_PP2H1_PP4H1RR3;THAT=0;PP2=H1;OB=IN;RR=1.5;XN=1;SLD=10;PP4=H1;RR4=3;E2=1;BE=1";   // SET 5
input string Set6 = "TEN=F6_PP2H1_PP4H1_NOBE;THAT=1;PP2=H1;OB=IN;RR=1.5;XN=1;SLD=10;PP4=H1;RR4=3;E2=0;BE=0"; // SET 6 (THẬT)
input string Set7 = "";                                                                                         // SET 7
input string Set8 = "";                                                                                         // SET 8

struct SPivotSMC
  {
   double   level;
   double   lastLevel;
   bool     crossed;
   datetime barTime;
   int      barIndex;
  };

struct SOBSMC
  {
   double   hi;
   double   lo;
   datetime barTime;
   datetime confirmTime;
   int      bias;
   bool     daGiaoDich;
  };

struct SPivotQM
  {
   bool     isHigh;
   double   price;
   datetime time;
  };

struct SSetupQM
  {
   bool     isActive;
   bool     isBull;
   double   qmLinePrice;
   double   headPrice;
   double   targetPrice;
   double   legPrice;
   datetime shoulderTime;
   datetime legTime;
   datetime headTime;
   datetime bosTime;
   double   shoulderPrice;
   datetime armedTime;
   bool     lineBroken;
   double   entry2Price;
   bool     entry2Valid;
   bool     entry2Broken;
  };

struct SSetAo
  {
   bool   on;
   bool   that;       // true = vào lệnh THẬT, false = lệnh ẢO
   long   magic;      // magic gốc của SET (lệnh PP = magic*10 + PP)
   string ten;
   string cauHinh;
   bool   be;
   double beR;
   double beK;
   int    maxLenh;
   double bal;
   double peak;
   double maxDD;
   int    trades;
   int    wins;
   double gp;
   double gl;
   double eq;
  };

struct SViThe
  {
   ulong    id;
   int      set;
   int      pp;
   int      dir;
   double   lot;
   double   entry;
   double   sl;
   double   tp;
   double   risk;
   datetime tOpen;
   bool     be;
   string   ghiChu;
  };

//+------------------------------------------------------------------+
//| Biến toàn cục chung                                              |
//+------------------------------------------------------------------+
double g_pip    = 0.1;
int    g_digits = 2;
bool   g_veDuoc = true;
bool   g_tester = false;
uint   g_dbLast = 0;
datetime g_lastSave = 0;
bool   g_canLuu = false;
string g_fileLenh = "", g_fileTongKet = "", g_fileTrangThai = "";

string D(const double v)  { return DoubleToString(v, g_digits); }
string D2(const double v) { return DoubleToString(v, 2); }
double P2G(const double pips) { return pips * g_pip; }
double G2P(const double gia)  { return (g_pip > 0.0 ? gia / g_pip : 0.0); }

string TfStr(const ENUM_TIMEFRAMES tf)
  {
   string s = EnumToString(tf);
   StringReplace(s, "PERIOD_", "");
   return s;
  }

double TinhKichThuocPip()
  {
   if(KichThuocPip_TuyChinh > 0.0) return KichThuocPip_TuyChinh;
   string s = _Symbol;
   StringToUpper(s);
   if(StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0) return 0.10;
   if(StringFind(s, "XAG") >= 0 || StringFind(s, "SILVER") >= 0) return 0.01;
   if(_Digits == 3 || _Digits == 5) return 10.0 * _Point;
   return _Point;
  }

double LayGiaTriChiBao(const int handle, const int buffer, const int shift)
  {
   if(handle == INVALID_HANDLE) return EMPTY_VALUE;
   double v[];
   if(CopyBuffer(handle, buffer, shift, 1, v) < 1) return EMPTY_VALUE;
   return v[0];
  }

//--- Hệ số đổi tiền lợi nhuận symbol -> tiền tài khoản (Cent USC/USD)
double HeSoTienTe()
  {
   string tk = AccountInfoString(ACCOUNT_CURRENCY);
   string ln = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
   if(tk == ln) return 1.0;
   if(ln == "USD" && tk == "USC") return 100.0;
   if(ln == "USC" && tk == "USD") return 0.01;
   return 0.0;
  }

//--- Lỗ khi 1 lot chạm SL: lấy giá trị lớn nhất của 3 cách tính (an toàn)
double TinhLoMoiLot(const int huong, const double giaVao, const double sl)
  {
   double kc = MathAbs(giaVao - sl);
   double a = 0.0, b = 0.0, c = 0.0, p = 0.0;
   ENUM_ORDER_TYPE ot = (huong == DIR_BULL ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(OrderCalcProfit(ot, _Symbol, 1.0, giaVao, sl, p) && p < 0.0) a = -p;
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tv <= 0.0) tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tv > 0.0 && ts > 0.0) b = kc / ts * tv;
   double cs = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double hs = HeSoTienTe();
   if(cs > 0.0 && hs > 0.0) c = kc * cs * hs;
   return MathMax(a, MathMax(b, c));
  }

//--- Lợi nhuận của 1 lệnh ảo khi đóng ở giá 'giaRa'
double TinhLoiNhuan(const int dir, const double lot, const double giaVao, const double giaRa)
  {
   double p = 0.0;
   ENUM_ORDER_TYPE ot = (dir == DIR_BULL ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(OrderCalcProfit(ot, _Symbol, lot, giaVao, giaRa, p)) return p;
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tv <= 0.0 || ts <= 0.0) return 0.0;
   return (giaRa - giaVao) * dir / ts * tv * lot;
  }

double LotTheoRuiRo(const int dir, const double giaVao, const double sl, const double von, const double riskPT)
  {
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;
   double lo1 = TinhLoMoiLot(dir, giaVao, sl);
   if(lo1 <= 0.0 || von <= 0.0) return vmin;
   double lot = von * riskPT / 100.0 / lo1;
   lot = MathFloor(lot / step + 1e-9) * step;
   if(lot < vmin) lot = vmin;
   if(vmax > 0.0 && lot > vmax) lot = vmax;
   return NormalizeDouble(lot, 2);
  }

ENUM_TIMEFRAMES TfTuChuoi(string s, bool &ok)
  {
   StringToUpper(s);
   ok = true;
   if(s == "M1")  return PERIOD_M1;
   if(s == "M5")  return PERIOD_M5;
   if(s == "M15") return PERIOD_M15;
   if(s == "M30") return PERIOD_M30;
   if(s == "H1")  return PERIOD_H1;
   if(s == "H4")  return PERIOD_H4;
   ok = false;
   return PERIOD_CURRENT;
  }

//+------------------------------------------------------------------+
//| BỘ MÁY PP2 - SMC Order Block (chuyển từ EA_MASTER_4PP v1.40)      |
//+------------------------------------------------------------------+
class CPP2Engine
  {
public:
   bool              on;
   ENUM_TIMEFRAMES   tf;
   int               swingLen;
   int               intLen;
   int               napLS;
   int               nOB;
   int               loaiOB;       // 0 nội bộ, 1 swing, 2 cả hai
   bool              theoTrend;
   bool              xacNhan;
   double            slDem;
   double            slMin;
   double            rr;
   int               openCount;
   //--- trạng thái
   SPivotSMC         swH, swL, inH, inL;
   int               swTr, inTr;
   SOBSMC            swOB[];
   SOBSMC            inOB[];
   double            hi[];
   double            lo[];
   double            pH[];
   double            pL[];
   datetime          t[];
   int               n;
   datetime          lastTime;
   datetime          lastBarOpen;
   MqlRates          lastBar;
   bool              ready;
   int               hATR;
   //--- tín hiệu
   bool              hasSig;
   int               sigDir;
   double            sigSL;
   double            sigTP;
   string            sigWhy;

                     CPP2Engine(void)
     {
      on = false; tf = PERIOD_H1; swingLen = 50; intLen = 5; napLS = 1000; nOB = 5; loaiOB = 2;
      theoTrend = true; xacNhan = true; slDem = 10.0; slMin = 30.0; rr = 2.0; openCount = 0;
      n = 0; lastTime = 0; lastBarOpen = 0; ready = false; hATR = INVALID_HANDLE;
      hasSig = false; sigDir = 0; sigSL = 0.0; sigTP = 0.0; sigWhy = "";
      swTr = 0; inTr = 0;
     }

   bool              Start(void)
     {
      if(!on) return true;
      hATR = iATR(_Symbol, tf, 200);
      Reset();
      ready = false;
      return (hATR != INVALID_HANDLE);
     }

   void              Stop(void)
     {
      if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
      hATR = INVALID_HANDLE;
     }

   void              ResetPivot(SPivotSMC &p)
     {
      p.level = EMPTY_VALUE; p.lastLevel = EMPTY_VALUE; p.crossed = false; p.barTime = 0; p.barIndex = -1;
     }

   void              Reset(void)
     {
      ResetPivot(swH); ResetPivot(swL); ResetPivot(inH); ResetPivot(inL);
      swTr = 0; inTr = 0;
      ArrayResize(swOB, 0); ArrayResize(inOB, 0);
      ArrayResize(hi, 0); ArrayResize(lo, 0); ArrayResize(pH, 0); ArrayResize(pL, 0); ArrayResize(t, 0);
      n = 0; lastTime = 0;
     }

   void              GanPivot(SPivotSMC &p, const double level, const int idx)
     {
      p.lastLevel = p.level; p.level = level; p.crossed = false; p.barTime = t[idx]; p.barIndex = idx;
     }

   void              CapNhatPivot(const int size, const bool internal, const int barIdx)
     {
      int pivIdx = barIdx - size;
      if(pivIdx < size) return;
      if(pivIdx + size >= n) return;
      double pivHi = hi[pivIdx], pivLo = lo[pivIdx];
      bool isH = true, isL = true;
      for(int i = pivIdx - size; i < pivIdx; i++)
        {
         if(hi[i] >= pivHi) isH = false;
         if(lo[i] <= pivLo) isL = false;
        }
      for(int i = pivIdx + 1; i <= pivIdx + size; i++)
        {
         if(hi[i] >= pivHi) isH = false;
         if(lo[i] <= pivLo) isL = false;
        }
      if(!isH && !isL) return;
      if(internal)
        {
         if(isL) GanPivot(inL, pivLo, pivIdx);
         if(isH) GanPivot(inH, pivHi, pivIdx);
        }
      else
        {
         if(isL) GanPivot(swL, pivLo, pivIdx);
         if(isH) GanPivot(swH, pivHi, pivIdx);
        }
     }

   void              ChenOB(SOBSMC &arr[], SOBSMC &ob)
     {
      int sz = ArraySize(arr);
      if(sz >= 100) sz = 99;
      ArrayResize(arr, sz + 1);
      for(int i = sz; i > 0; i--) arr[i] = arr[i - 1];
      arr[0] = ob;
     }

   void              XoaOB(SOBSMC &arr[], const int idx)
     {
      int sz = ArraySize(arr);
      for(int i = idx; i < sz - 1; i++) arr[i] = arr[i + 1];
      ArrayResize(arr, sz - 1);
     }

   void              LuuOB(SPivotSMC &p, const bool internal, const int bias, const int bosIdx)
     {
      int si = p.barIndex, ei = bosIdx;
      if(si < 0 || si >= ei) return;
      int    best_i = si;
      double best   = (bias == DIR_BEAR ? -DBL_MAX : DBL_MAX);
      for(int i = si; i < ei && i < n; i++)
        {
         if(bias == DIR_BEAR && pH[i] > best) { best = pH[i]; best_i = i; }
         if(bias == DIR_BULL && pL[i] < best) { best = pL[i]; best_i = i; }
        }
      SOBSMC ob;
      ob.hi = hi[best_i]; ob.lo = lo[best_i]; ob.barTime = t[best_i];
      ob.confirmTime = t[bosIdx]; ob.bias = bias; ob.daGiaoDich = false;
      if(internal) ChenOB(inOB, ob);
      else ChenOB(swOB, ob);
     }

   void              XuLyCauTruc(const bool internal, const double c, const int barIdx)
     {
      SPivotSMC ph, pl;
      int tr;
      if(internal) { ph = inH; pl = inL; tr = inTr; }
      else         { ph = swH; pl = swL; tr = swTr; }
      if(ph.level != EMPTY_VALUE && !ph.crossed)
        {
         bool ex = (internal ? (inH.level != swH.level) : true);
         if(c > ph.level && ex)
           {
            ph.crossed = true;
            tr = DIR_BULL;
            LuuOB(ph, internal, DIR_BULL, barIdx);
           }
        }
      if(pl.level != EMPTY_VALUE && !pl.crossed)
        {
         bool ex = (internal ? (inL.level != swL.level) : true);
         if(c < pl.level && ex)
           {
            pl.crossed = true;
            tr = DIR_BEAR;
            LuuOB(pl, internal, DIR_BEAR, barIdx);
           }
        }
      if(internal) { inH = ph; inL = pl; inTr = tr; }
      else         { swH = ph; swL = pl; swTr = tr; }
     }

   void              GiamThieuOB(SOBSMC &arr[], const double h, const double l)
     {
      for(int i = ArraySize(arr) - 1; i >= 0; i--)
        {
         bool mit = (arr[i].bias == DIR_BEAR && h > arr[i].hi) || (arr[i].bias == DIR_BULL && l < arr[i].lo);
         if(mit) XoaOB(arr, i);
        }
     }

   void              XuLyNen(MqlRates &r, const double atr)
     {
      int i = n;
      ArrayResize(hi, i + 1, 5000);
      ArrayResize(lo, i + 1, 5000);
      ArrayResize(pH, i + 1, 5000);
      ArrayResize(pL, i + 1, 5000);
      ArrayResize(t,  i + 1, 5000);
      bool hv = (atr > 0.0 && (r.high - r.low) >= 2.0 * atr);
      hi[i] = r.high; lo[i] = r.low;
      pH[i] = (hv ? r.low : r.high);
      pL[i] = (hv ? r.high : r.low);
      t[i]  = r.time;
      n = i + 1;
      CapNhatPivot(swingLen, false, i);
      CapNhatPivot(intLen, true, i);
      XuLyCauTruc(true, r.close, i);
      XuLyCauTruc(false, r.close, i);
      GiamThieuOB(inOB, r.high, r.low);
      GiamThieuOB(swOB, r.high, r.low);
      lastBar = r;
     }

   bool              Warmup(void)
     {
      if(hATR == INVALID_HANDLE) return false;
      if(BarsCalculated(hATR) <= 0) return false;
      int tong = Bars(_Symbol, tf);
      int can  = MathMin(napLS, tong - 2);
      if(can < swingLen * 2 + 10) return false;
      MqlRates r[];
      ArraySetAsSeries(r, false);
      int got = CopyRates(_Symbol, tf, 1, can, r);
      if(got < swingLen * 2 + 10) return false;
      double atr[];
      ArraySetAsSeries(atr, false);
      int gotA = CopyBuffer(hATR, 0, 1, got, atr);
      if(gotA < 0) gotA = 0;
      Reset();
      for(int i = 0; i < got; i++)
        {
         int    ai = i - (got - gotA);
         double a  = ((gotA > 0 && ai >= 0 && ai < gotA) ? atr[ai] : 0.0);
         XuLyNen(r[i], a);
        }
      lastTime = r[got - 1].time;
      ready = true;
      return true;
     }

   int               CapNhatNenMoi(void)
     {
      int shiftCu = iBarShift(_Symbol, tf, lastTime, false);
      if(shiftCu < 0) return 0;
      int soMoi = shiftCu - 1;
      if(soMoi <= 0) return 0;
      if(soMoi > 500) soMoi = 500;
      MqlRates r[];
      ArraySetAsSeries(r, false);
      int got = CopyRates(_Symbol, tf, 1, soMoi, r);
      if(got <= 0) return 0;
      double atr[];
      ArraySetAsSeries(atr, false);
      int gotA = CopyBuffer(hATR, 0, 1, got, atr);
      if(gotA < 0) gotA = 0;
      int dem = 0;
      for(int i = 0; i < got; i++)
        {
         if(r[i].time <= lastTime) continue;
         int    ai = i - (got - gotA);
         double a  = ((gotA > 0 && ai >= 0 && ai < gotA) ? atr[ai] : 0.0);
         XuLyNen(r[i], a);
         lastTime = r[i].time;
         dem++;
        }
      return dem;
     }

   int               TimOBCham(SOBSMC &arr[], const int bias, MqlRates &r)
     {
      int lim = MathMin(ArraySize(arr), nOB);
      for(int i = 0; i < lim; i++)
        {
         if(arr[i].bias != bias || arr[i].daGiaoDich) continue;
         if(arr[i].confirmTime >= r.time) continue;
         if(bias == DIR_BULL)
           {
            if(r.low <= arr[i].hi && (!xacNhan || r.close > r.open)) return i;
           }
         else
           {
            if(r.high >= arr[i].lo && (!xacNhan || r.close < r.open)) return i;
           }
        }
      return -1;
     }

   void              DanhGia(void)
     {
      MqlRates r = lastBar;
      bool choMua = true, choBan = true;
      if(theoTrend) { choMua = (swTr == DIR_BULL); choBan = (swTr == DIR_BEAR); }
      if(!choMua && !choBan) return;
      MqlTick tk;
      if(!SymbolInfoTick(_Symbol, tk)) return;
      for(int lan = 0; lan < 2; lan++)
        {
         int bias = (lan == 0 ? DIR_BULL : DIR_BEAR);
         if(bias == DIR_BULL && !choMua) continue;
         if(bias == DIR_BEAR && !choBan) continue;
         int  idx = -1;
         bool laSwing = false;
         if(loaiOB != 0)
           {
            idx = TimOBCham(swOB, bias, r);
            if(idx >= 0) laSwing = true;
           }
         if(idx < 0 && loaiOB != 1) idx = TimOBCham(inOB, bias, r);
         if(idx < 0) continue;
         double obHi, obLo;
         if(laSwing) { obHi = swOB[idx].hi; obLo = swOB[idx].lo; swOB[idx].daGiaoDich = true; }
         else        { obHi = inOB[idx].hi; obLo = inOB[idx].lo; inOB[idx].daGiaoDich = true; }
         double minSL = P2G(slMin);
         double entry, sl, tp;
         if(bias == DIR_BULL)
           {
            entry = tk.ask;
            sl = obLo - P2G(slDem);
            if(entry - sl < minSL) sl = entry - minSL;
            tp = entry + rr * (entry - sl);
           }
         else
           {
            entry = tk.bid;
            sl = obHi + P2G(slDem);
            if(sl - entry < minSL) sl = entry + minSL;
            tp = entry - rr * (sl - entry);
           }
         hasSig = true;
         sigDir = bias;
         sigSL  = sl;
         sigTP  = tp;
         sigWhy = StringFormat("Retest OB %s %s [%s-%s]", (laSwing ? "swing" : "noi bo"),
                               (bias == DIR_BULL ? "tang" : "giam"), D(obLo), D(obHi));
         return;
        }
     }

   void              XuLyTick(void)
     {
      hasSig = false;
      if(!on) return;
      if(!ready)
        {
         if(!Warmup()) return;
         lastBarOpen = iTime(_Symbol, tf, 0);
         return;
        }
      datetime t0 = iTime(_Symbol, tf, 0);
      if(t0 == 0 || t0 == lastBarOpen) return;
      lastBarOpen = t0;
      if(CapNhatNenMoi() <= 0) return;
      DanhGia();
     }
  };

//+------------------------------------------------------------------+
//| BỘ MÁY PP4 - Quasimodo (chuyển từ EA_MASTER_4PP v1.40)            |
//+------------------------------------------------------------------+
class CPP4Engine
  {
public:
   bool              on;
   ENUM_TIMEFRAMES   tf;
   int               lookback;
   double            rr;
   double            slDem;
   bool              e2;
   int               choToiDa;
   int               napLS;
   int               openCount;
   SPivotQM          piv[];
   int               maxPiv;
   double            lastHigh;
   datetime          lastHighT;
   double            lastLow;
   datetime          lastLowT;
   SSetupQM          st;
   datetime          lastBosT;
   datetime          lastShoulderT;
   bool              ready;
   int               hATR;
   datetime          lastBarOpen;
   bool              hasSig;
   int               sigDir;
   double            sigSL;
   double            sigTP;
   string            sigWhy;

                     CPP4Engine(void)
     {
      on = false; tf = PERIOD_H1; lookback = 5; rr = 2.0; slDem = 20.0; e2 = true; choToiDa = 30; napLS = 1000;
      openCount = 0; maxPiv = 24; lastHigh = 0.0; lastHighT = 0; lastLow = 0.0; lastLowT = 0;
      lastBosT = 0; lastShoulderT = 0; ready = false; hATR = INVALID_HANDLE; lastBarOpen = 0;
      hasSig = false; sigDir = 0; sigSL = 0.0; sigTP = 0.0; sigWhy = "";
      st.isActive = false;
     }

   bool              Start(void)
     {
      if(!on) return true;
      hATR = iATR(_Symbol, tf, 14);
      ArrayResize(piv, 0);
      st.isActive = false;
      ready = false;
      return (hATR != INVALID_HANDLE);
     }

   void              Stop(void)
     {
      if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
      hATR = INVALID_HANDLE;
     }

   void              AddPivot(const bool isHigh, const double price, const datetime time)
     {
      int count = ArraySize(piv);
      if(count == 0)
        {
         ArrayResize(piv, 1);
         piv[0].isHigh = isHigh; piv[0].price = price; piv[0].time = time;
         return;
        }
      if(piv[count - 1].isHigh == isHigh)
        {
         bool moreExtreme = (isHigh ? (price > piv[count - 1].price) : (price < piv[count - 1].price));
         if(moreExtreme) { piv[count - 1].price = price; piv[count - 1].time = time; }
         return;
        }
      ArrayResize(piv, count + 1);
      piv[count].isHigh = isHigh; piv[count].price = price; piv[count].time = time;
      if(ArraySize(piv) > maxPiv)
        {
         int drop = ArraySize(piv) - maxPiv;
         for(int i = 0; i < ArraySize(piv) - drop; i++) piv[i] = piv[i + drop];
         ArrayResize(piv, maxPiv);
        }
     }

   bool              TrendTruoc(const bool isBull, const int shoulderIndex)
     {
      int oldest = shoulderIndex - 2;
      if(oldest < 0) return false;
      for(int i = oldest; i + 2 <= shoulderIndex; i++)
        {
         double earlier = piv[i].price, later = piv[i + 2].price;
         if(!isBull) { if(!(later > earlier)) return false; }
         else        { if(!(later < earlier)) return false; }
        }
      return true;
     }

   double            NenNguocMau(const datetime pivotTime, const bool wantBearish, const int maxLook)
     {
      int shift = iBarShift(_Symbol, tf, pivotTime);
      if(shift < 0) return 0.0;
      for(int i = 0; i <= maxLook; i++)
        {
         double o = iOpen(_Symbol, tf, shift + i);
         double c = iClose(_Symbol, tf, shift + i);
         if(wantBearish && c < o) return c;
         if(!wantBearish && c > o) return c;
        }
      return 0.0;
     }

   void              Arm(const bool isBull, const SPivotQM &shoulder, const SPivotQM &leg, const SPivotQM &head, const SPivotQM &bos)
     {
      if(openCount > 0) return;
      st.isActive = true;
      st.isBull = isBull;
      st.qmLinePrice = shoulder.price;
      st.shoulderPrice = shoulder.price;
      st.headPrice = head.price;
      st.targetPrice = bos.price;
      st.legPrice = leg.price;
      st.shoulderTime = shoulder.time;
      st.legTime = leg.time;
      st.headTime = head.time;
      st.bosTime = bos.time;
      st.armedTime = iTime(_Symbol, tf, 0);
      st.lineBroken = false;
      st.entry2Price = (e2 ? NenNguocMau(head.time, isBull, lookback + 2) : 0.0);
      st.entry2Valid = (st.entry2Price > 0.0);
      st.entry2Broken = false;
      lastBosT = bos.time;
      lastShoulderT = shoulder.time;
     }

   void              KiemTraMoHinh(void)
     {
      int count = ArraySize(piv);
      if(count < 4) return;
      SPivotQM shoulder = piv[count - 4];
      SPivotQM leg      = piv[count - 3];
      SPivotQM head     = piv[count - 2];
      SPivotQM bos      = piv[count - 1];
      if(shoulder.isHigh && !leg.isHigh && head.isHigh && !bos.isHigh)
        {
         if(head.price > shoulder.price && leg.price < shoulder.price && bos.price < leg.price)
            if(bos.time != lastBosT && shoulder.time != lastShoulderT && TrendTruoc(false, count - 4))
               Arm(false, shoulder, leg, head, bos);
         return;
        }
      if(!shoulder.isHigh && leg.isHigh && !head.isHigh && bos.isHigh)
        {
         if(head.price < shoulder.price && leg.price > shoulder.price && bos.price > leg.price)
            if(bos.time != lastBosT && shoulder.time != lastShoulderT && TrendTruoc(true, count - 4))
               Arm(true, shoulder, leg, head, bos);
        }
     }

   void              TaoTinHieu(const bool isBull, const string tag)
     {
      if(openCount > 0) return;
      MqlTick tk;
      if(!SymbolInfoTick(_Symbol, tk)) return;
      double buf = P2G(slDem);
      double atr = LayGiaTriChiBao(hATR, 0, 1);
      if(atr == EMPTY_VALUE) atr = 0.0;
      double entry, stop, tp;
      if(isBull)
        {
         entry = tk.ask;
         double s1 = st.headPrice - buf;
         double s2 = (atr > 0.0 ? entry - atr : s1);
         stop = MathMin(s1, s2);
        }
      else
        {
         entry = tk.bid;
         double s1 = st.headPrice + buf;
         double s2 = (atr > 0.0 ? entry + atr : s1);
         stop = MathMax(s1, s2);
        }
      double rd = (isBull ? entry - stop : stop - entry);
      if(rd <= 0.0) { st.isActive = false; return; }
      tp = (isBull ? entry + rr * rd : entry - rr * rd);
      hasSig = true;
      sigDir = (isBull ? DIR_BULL : DIR_BEAR);
      sigSL  = stop;
      sigTP  = tp;
      sigWhy = StringFormat("QM %s %s | QM line=%s Head=%s", (isBull ? "tang" : "giam"), tag, D(st.qmLinePrice), D(st.headPrice));
      st.isActive = false;
     }

   void              KiemTraVaoLenh(void)
     {
      double c = iClose(_Symbol, tf, 1);
      int el = iBarShift(_Symbol, tf, st.armedTime);
      if(el > choToiDa) { st.isActive = false; return; }
      if(openCount > 0) return;
      if(st.isBull)
        {
         if(c < st.headPrice) { st.isActive = false; return; }
         if(c <= st.qmLinePrice) TaoTinHieu(true, "E1");
         if(st.isActive && st.entry2Valid && c <= st.entry2Price) TaoTinHieu(true, "E2");
        }
      else
        {
         if(c > st.headPrice) { st.isActive = false; return; }
         if(c >= st.qmLinePrice) TaoTinHieu(false, "E1");
         if(st.isActive && st.entry2Valid && c >= st.entry2Price) TaoTinHieu(false, "E2");
        }
     }

   void              DanhGiaPivot(const int shift)
     {
      datetime pt = iTime(_Symbol, tf, shift);
      double   ph = iHigh(_Symbol, tf, shift);
      double   pl = iLow(_Symbol, tf, shift);
      bool isH = true, isL = true;
      for(int j = 1; j <= lookback; j++)
        {
         if(iHigh(_Symbol, tf, shift - j) >= ph || iHigh(_Symbol, tf, shift + j) >= ph) isH = false;
         if(iLow(_Symbol, tf, shift - j) <= pl || iLow(_Symbol, tf, shift + j) <= pl) isL = false;
        }
      if(isH && pt != lastHighT)
        {
         lastHigh = ph; lastHighT = pt;
         AddPivot(true, ph, pt);
         KiemTraMoHinh();
        }
      if(isL && pt != lastLowT)
        {
         lastLow = pl; lastLowT = pt;
         AddPivot(false, pl, pt);
         KiemTraMoHinh();
        }
     }

   bool              NapLichSu(void)
     {
      int avail = iBars(_Symbol, tf);
      if(avail < lookback * 2 + 2) return false;
      int minShift = lookback + 1;
      int maxShift = MathMin(napLS, avail - lookback - 2);
      for(int s = maxShift; s >= minShift; s--) DanhGiaPivot(s);
      st.isActive = false;   // setup dựng từ lịch sử không được giao dịch (như bản gốc)
      return true;
     }

   void              XuLyTick(void)
     {
      hasSig = false;
      if(!on) return;
      if(!ready)
        {
         if(!NapLichSu()) return;
         ready = true;
         lastBarOpen = iTime(_Symbol, tf, 0);
         return;
        }
      datetime t0 = iTime(_Symbol, tf, 0);
      if(t0 == 0 || t0 == lastBarOpen) return;
      lastBarOpen = t0;
      DanhGiaPivot(lookback + 1);
      KiemTraMoHinh();
      if(st.isActive) KiemTraVaoLenh();
     }
  };

//+------------------------------------------------------------------+
//| Quản lý SET ảo                                                   |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Quản lý SET (thật + ảo)                                          |
//+------------------------------------------------------------------+
SSetAo     g_set[MAX_SET];
CPP2Engine g_e2[MAX_SET];
CPP4Engine g_e4[MAX_SET];
SViThe     g_pos[];
ulong      g_nextId = 1;
CTrade     g_trade;

//--- Bảo vệ tài khoản
datetime g_ngay       = 0;
double   g_balDauNgay = 0.0;
double   g_dinhEq     = 0.0;
double   g_ddNgay     = 0.0;
double   g_ddTong     = 0.0;
bool     g_khoaNgay   = false;
bool     g_khoaTong   = false;
string   g_lyDoKhoa   = "";
string   g_gvDinh     = "";
datetime g_lanSuaLoi  = 0;

string CauHinhInput(const int i)
  {
   switch(i)
     {
      case 0: return Set1;
      case 1: return Set2;
      case 2: return Set3;
      case 3: return Set4;
      case 4: return Set5;
      case 5: return Set6;
      case 6: return Set7;
      case 7: return Set8;
     }
   return "";
  }

bool DocCauHinh(const int i, string cfg)
  {
   g_set[i].on = false;
   g_set[i].that = false;
   g_set[i].magic = Magic_Goc * 10 + (i + 1);
   g_set[i].ten = "SET" + IntegerToString(i + 1);
   g_set[i].cauHinh = cfg;
   g_set[i].be = true; g_set[i].beR = 1.0; g_set[i].beK = 5.0; g_set[i].maxLenh = 1;
   g_set[i].trades = 0; g_set[i].wins = 0; g_set[i].gp = 0.0; g_set[i].gl = 0.0; g_set[i].maxDD = 0.0;
   g_e2[i].on = false;
   g_e4[i].on = false;
   StringTrimLeft(cfg);
   StringTrimRight(cfg);
   if(cfg == "") return true;
   string items[];
   int k = StringSplit(cfg, StringGetCharacter(";", 0), items);
   for(int j = 0; j < k; j++)
     {
      string kv[];
      if(StringSplit(items[j], StringGetCharacter("=", 0), kv) < 2) continue;
      string key = kv[0], val = kv[1];
      StringTrimLeft(key); StringTrimRight(key); StringToUpper(key);
      StringTrimLeft(val); StringTrimRight(val);
      string vu = val;
      StringToUpper(vu);
      bool ok = false;
      if(key == "TEN") g_set[i].ten = val;
      else if(key == "THAT") g_set[i].that = (StringToInteger(val) != 0);
      else if(key == "PP2")  { ENUM_TIMEFRAMES f = TfTuChuoi(vu, ok); g_e2[i].on = ok; if(ok) g_e2[i].tf = f; }
      else if(key == "OB")   g_e2[i].loaiOB = (vu == "IN" ? 0 : (vu == "SW" ? 1 : 2));
      else if(key == "RR")   g_e2[i].rr = StringToDouble(val);
      else if(key == "XN")   g_e2[i].xacNhan = (StringToInteger(val) != 0);
      else if(key == "SLD")  g_e2[i].slDem = StringToDouble(val);
      else if(key == "SLM")  g_e2[i].slMin = StringToDouble(val);
      else if(key == "SW")   g_e2[i].swingLen = (int)StringToInteger(val);
      else if(key == "NOB")  g_e2[i].nOB = (int)StringToInteger(val);
      else if(key == "TREND")g_e2[i].theoTrend = (StringToInteger(val) != 0);
      else if(key == "PP4")  { ENUM_TIMEFRAMES f = TfTuChuoi(vu, ok); g_e4[i].on = ok; if(ok) g_e4[i].tf = f; }
      else if(key == "RR4")  g_e4[i].rr = StringToDouble(val);
      else if(key == "E2")   g_e4[i].e2 = (StringToInteger(val) != 0);
      else if(key == "SLD4") g_e4[i].slDem = StringToDouble(val);
      else if(key == "LB")   g_e4[i].lookback = (int)StringToInteger(val);
      else if(key == "CHO")  g_e4[i].choToiDa = (int)StringToInteger(val);
      else if(key == "BE")   g_set[i].be = (StringToInteger(val) != 0);
      else if(key == "BER")  g_set[i].beR = StringToDouble(val);
      else if(key == "BEK")  g_set[i].beK = StringToDouble(val);
      else if(key == "MAX")  g_set[i].maxLenh = (int)MathMax(1.0, (double)StringToInteger(val));
      else Print("SET ", i + 1, ": bỏ qua khóa không hiểu '", key, "'");
     }
   if(g_e2[i].rr <= 0.0 || g_e4[i].rr <= 0.0 || g_e2[i].swingLen < 2 || g_e4[i].lookback < 1)
     {
      Print("LỖI cấu hình SET ", i + 1, ": RR/SW/LB không hợp lệ -> ", cfg);
      return false;
     }
   g_set[i].on = (g_e2[i].on || g_e4[i].on);
   double von = AccountInfoDouble(ACCOUNT_BALANCE);
   if(!g_set[i].that && VonAo_MoiSet > 0.0) von = VonAo_MoiSet;
   g_set[i].bal = von; g_set[i].peak = von; g_set[i].eq = von;
   return true;
  }

long MagicPP(const int s, const int pp) { return g_set[s].magic * 10 + pp; }

//--- Magic lệnh -> (SET, PP). Chỉ nhận SET đang bật ở chế độ THẬT
bool TachMagic(const long m, int &s, int &pp)
  {
   pp = (int)(m % 10);
   long k = m / 10 - Magic_Goc * 10;
   if(k < 1 || k > MAX_SET || (pp != 2 && pp != 4)) return false;
   s = (int)k - 1;
   return (g_set[s].on && g_set[s].that);
  }

int DemViThe(const int set, const int pp)
  {
   int c = 0;
   for(int i = 0; i < ArraySize(g_pos); i++)
      if(g_pos[i].set == set && (pp == 0 || g_pos[i].pp == pp)) c++;
   return c;
  }

//--- Đếm lệnh THẬT: set = -1 -> mọi SET; pp = 0 -> mọi PP
int DemLenhThat(const int set, const int pp)
  {
   int c = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      int s, p;
      if(!TachMagic(PositionGetInteger(POSITION_MAGIC), s, p)) continue;
      if(set >= 0 && s != set) continue;
      if(pp != 0 && p != pp) continue;
      c++;
     }
   return c;
  }

int DemLenh(const int s, const int pp) { return (g_set[s].that ? DemLenhThat(s, pp) : DemViThe(s, pp)); }

void GhiDongCSV(const string file, const string dong, const string header)
  {
   if(!GhiCSV) return;
   int h = FileOpen(file, FILE_READ | FILE_WRITE | FILE_TXT | FILE_UNICODE | FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE) return;
   if(FileSize(h) <= 2) FileWriteString(h, header + "\r\n");
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, dong + "\r\n");
   FileClose(h);
  }

#define CSV_HEADER "Mo luc;Dong luc;SET;Che do;PP;Huong;Lot;Gia vao;Gia ra;SL;TP;Loi nhuan;R;Ly do;Balance SET;Ghi chu"

//+------------------------------------------------------------------+
//| BẢO VỆ TÀI KHOẢN                                                 |
//+------------------------------------------------------------------+
void DongHetLenhThat(const string lyDo)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      int s, p;
      if(!TachMagic(PositionGetInteger(POSITION_MAGIC), s, p)) continue;
      if(!g_trade.PositionClose(tk))
         Print("LỖI đóng lệnh #", tk, ": ", g_trade.ResultRetcodeDescription());
     }
   Print("BẢO VỆ: đã đóng toàn bộ lệnh thật. Lý do: ", lyDo);
  }

void KiemTraAnToan()
  {
   long t = (long)TimeCurrent();
   datetime ngay = (datetime)(t - t % 86400);
   if(ngay != g_ngay)
     {
      g_ngay = ngay;
      g_balDauNgay = AccountInfoDouble(ACCOUNT_BALANCE);
      if(g_khoaNgay) Print("BẢO VỆ: sang ngày mới -> mở khóa DD ngày");
      g_khoaNgay = false;
     }
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_dinhEq)
     {
      g_dinhEq = eq;
      if(!g_tester) GlobalVariableSet(g_gvDinh, g_dinhEq);
     }
   g_ddNgay = (g_balDauNgay > 0.0 ? MathMax(0.0, (g_balDauNgay - eq) / g_balDauNgay * 100.0) : 0.0);
   g_ddTong = (g_dinhEq > 0.0 ? MathMax(0.0, (g_dinhEq - eq) / g_dinhEq * 100.0) : 0.0);
   if(!g_khoaNgay && Bat_DDNgay && g_ddNgay >= DDNgay_PT)
     {
      g_khoaNgay = true;
      g_lyDoKhoa = StringFormat("DD ngày %.1f%% >= %.1f%%", g_ddNgay, DDNgay_PT);
      Print("BẢO VỆ: ngừng mở lệnh thật tới hết ngày - ", g_lyDoKhoa);
      if(DongHetKhiVuotDD) DongHetLenhThat(g_lyDoKhoa);
     }
   if(!g_khoaTong && Bat_DDTong && g_ddTong >= DDTong_PT)
     {
      g_khoaTong = true;
      g_lyDoKhoa = StringFormat("DD tổng %.1f%% >= %.1f%%", g_ddTong, DDTong_PT);
      Print("BẢO VỆ: ngừng mở lệnh thật (khởi động lại EA để chạy tiếp) - ", g_lyDoKhoa);
      if(DongHetKhiVuotDD) DongHetLenhThat(g_lyDoKhoa);
     }
  }

//+------------------------------------------------------------------+
//| LỆNH THẬT                                                        |
//+------------------------------------------------------------------+
void MoLenhThat(const int s, const int pp, const int dir, double sl, double tp, const string why)
  {
   string ten = g_set[s].ten;
   if(g_khoaNgay || g_khoaTong) { if(InLog) Print("[", ten, "] bỏ tín hiệu: ", g_lyDoKhoa); return; }
   if(DemLenhThat(-1, 0) >= MaxLenhThat_Tong) { if(InLog) Print("[", ten, "] bỏ tín hiệu: đã đủ ", MaxLenhThat_Tong, " lệnh thật"); return; }
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;
   double sp = G2P(tk.ask - tk.bid);
   if(sp > Spread_ToiDa_Pips) { if(InLog) Print("[", ten, "] bỏ tín hiệu: spread ", DoubleToString(sp, 1), " pip"); return; }
   bool   mua   = (dir == DIR_BULL);
   double entry = (mua ? tk.ask : tk.bid);
   double minD  = (double)(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) + 2) * _Point;
   if(mua)
     {
      if(sl >= entry) return;
      if(tk.bid - sl < minD) sl = tk.bid - minD;
      if(tp > 0.0 && tp <= entry) return;
      if(tp > 0.0 && tp - tk.bid < minD) tp = tk.bid + minD;
     }
   else
     {
      if(sl <= entry) return;
      if(sl - tk.ask < minD) sl = tk.ask + minD;
      if(tp > 0.0 && tp >= entry) return;
      if(tp > 0.0 && tk.ask - tp < minD) tp = tk.ask - minD;
     }
   sl = NormalizeDouble(sl, g_digits);
   tp = NormalizeDouble(tp, g_digits);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double lot = LotTheoRuiRo(dir, entry, sl, bal, RuiRo_That_PT);
   if(lot > Lot_ToiDa_That) lot = MathFloor(Lot_ToiDa_That / SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)) * SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = NormalizeDouble(lot, 2);
   double loSL = TinhLoMoiLot(dir, entry, sl) * lot;
   double ruiPT = (bal > 0.0 ? loSL / bal * 100.0 : 100.0);
   if(ChotChan_PT > 0.0 && ruiPT > ChotChan_PT)
     {
      Print("[", ten, "] CHỐT CHẶN: lot ", D2(lot), " lỗ tại SL ", D2(loSL), " = ", DoubleToString(ruiPT, 2), "% > ", DoubleToString(ChotChan_PT, 1), "% -> bỏ lệnh");
      return;
     }
   string cmt = StringSubstr(ten, 0, 18) + "_PP" + IntegerToString(pp) + (mua ? "_BUY" : "_SELL");
   g_trade.SetExpertMagicNumber((ulong)MagicPP(s, pp));
   bool ok = (mua ? g_trade.Buy(lot, _Symbol, 0.0, sl, tp, cmt) : g_trade.Sell(lot, _Symbol, 0.0, sl, tp, cmt));
   uint rc = g_trade.ResultRetcode();
   if(!ok || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_DONE_PARTIAL && rc != TRADE_RETCODE_PLACED))
     {
      Print("[", ten, "] LỖI mở lệnh thật: retcode=", rc, " ", g_trade.ResultRetcodeDescription(), " | lot=", D2(lot), " SL=", D(sl), " TP=", D(tp));
      return;
     }
   if(InLog)
      Print("[", ten, "] MỞ THẬT PP", pp, (mua ? " BUY" : " SELL"), " lot=", D2(lot), " giá=", D(g_trade.ResultPrice()), " SL=", D(sl), " TP=", D(tp),
            " rủi ro=", DoubleToString(ruiPT, 2), "% spread=", DoubleToString(sp, 1), " | magic ", MagicPP(s, pp), " | ", why);
  }

//--- Dời SL hòa vốn cho lệnh thật
void QuanLyLenhThat(const MqlTick &tk)
  {
   if(g_lanSuaLoi > 0 && TimeCurrent() - g_lanSuaLoi < 10) return;
   double stopD = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      int s, p;
      if(!TachMagic(PositionGetInteger(POSITION_MAGIC), s, p)) continue;
      if(!g_set[s].be) continue;
      bool   mua   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);
      double risk  = (mua ? entry - sl : sl - entry);
      if(sl <= 0.0 || risk <= 0.0) continue;   // đã hòa vốn hoặc không có SL
      double profitR = (mua ? (tk.bid - entry) : (entry - tk.ask)) / risk;
      if(profitR < g_set[s].beR) continue;
      double moi = NormalizeDouble(mua ? entry + P2G(g_set[s].beK) : entry - P2G(g_set[s].beK), g_digits);
      if(mua ? (tk.bid - moi <= stopD) : (moi - tk.ask <= stopD)) continue;
      if(g_trade.PositionModify(ticket, moi, tp))
        {
         if(InLog) Print("[", g_set[s].ten, "] Dời SL hòa vốn #", ticket, " -> ", D(moi));
        }
      else
        {
         g_lanSuaLoi = TimeCurrent();
         Print("[", g_set[s].ten, "] LỖI dời hòa vốn #", ticket, ": ", g_trade.ResultRetcodeDescription());
        }
     }
  }

//+------------------------------------------------------------------+
//| LỆNH ẢO                                                          |
//+------------------------------------------------------------------+
void MoViThe(const int s, const int pp, const int dir, const double sl, const double tp, const string why)
  {
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;
   double sp = G2P(tk.ask - tk.bid);
   if(sp > Spread_ToiDa_Pips) return;
   double entry = (dir == DIR_BULL ? tk.ask : tk.bid);
   double risk  = (dir == DIR_BULL ? entry - sl : sl - entry);
   if(risk <= 0.0) return;
   if(tp > 0.0 && ((dir == DIR_BULL && tp <= entry) || (dir == DIR_BEAR && tp >= entry))) return;
   int k = ArraySize(g_pos);
   ArrayResize(g_pos, k + 1);
   g_pos[k].id = g_nextId++;
   g_pos[k].set = s;
   g_pos[k].pp = pp;
   g_pos[k].dir = dir;
   g_pos[k].lot = LotTheoRuiRo(dir, entry, sl, g_set[s].bal, Risk_PT);
   g_pos[k].entry = entry;
   g_pos[k].sl = sl;
   g_pos[k].tp = tp;
   g_pos[k].risk = risk;
   g_pos[k].tOpen = TimeCurrent();
   g_pos[k].be = false;
   g_pos[k].ghiChu = why;
   g_canLuu = true;
   if(InLog)
      Print("[", g_set[s].ten, "] MỞ ẢO PP", pp, (dir == DIR_BULL ? " BUY" : " SELL"), " lot=", D2(g_pos[k].lot), " giá=", D(entry),
            " SL=", D(sl), " TP=", D(tp), " | ", why);
  }

void DongViThe(const int k, const double giaRa, const string lyDo)
  {
   int s = g_pos[k].set;
   double p = TinhLoiNhuan(g_pos[k].dir, g_pos[k].lot, g_pos[k].entry, giaRa);
   double r = (g_pos[k].risk > 0.0 ? (giaRa - g_pos[k].entry) * g_pos[k].dir / g_pos[k].risk : 0.0);
   g_set[s].bal += p;
   g_set[s].trades++;
   if(p > 0.0) { g_set[s].wins++; g_set[s].gp += p; }
   else g_set[s].gl += -p;
   GhiDongCSV(g_fileLenh, TimeToString(g_pos[k].tOpen, TIME_DATE | TIME_SECONDS) + ";" + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS)
              + ";" + g_set[s].ten + ";AO;PP" + IntegerToString(g_pos[k].pp) + ";" + (g_pos[k].dir == DIR_BULL ? "BUY" : "SELL")
              + ";" + D2(g_pos[k].lot) + ";" + D(g_pos[k].entry) + ";" + D(giaRa) + ";" + D(g_pos[k].sl) + ";" + D(g_pos[k].tp)
              + ";" + D2(p) + ";" + DoubleToString(r, 2) + ";" + lyDo + ";" + D2(g_set[s].bal) + ";" + g_pos[k].ghiChu, CSV_HEADER);
   if(InLog)
      Print("[", g_set[s].ten, "] ĐÓNG ẢO ", lyDo, " giá=", D(giaRa), " LN=", D2(p), " (", DoubleToString(r, 2), "R)");
   int n = ArraySize(g_pos);
   for(int j = k; j < n - 1; j++) g_pos[j] = g_pos[j + 1];
   ArrayResize(g_pos, n - 1);
   g_canLuu = true;
  }

void QuanLyViThe(const MqlTick &tk)
  {
   for(int k = ArraySize(g_pos) - 1; k >= 0; k--)
     {
      int s = g_pos[k].set;
      if(g_pos[k].dir == DIR_BULL)
        {
         if(tk.bid <= g_pos[k].sl) { DongViThe(k, tk.bid, (g_pos[k].be ? "Cham SL hoa von" : "Cham SL")); continue; }
         if(g_pos[k].tp > 0.0 && tk.bid >= g_pos[k].tp) { DongViThe(k, tk.bid, "Cham TP"); continue; }
         if(g_set[s].be && !g_pos[k].be && (tk.bid - g_pos[k].entry) / g_pos[k].risk >= g_set[s].beR)
           {
            double moi = g_pos[k].entry + P2G(g_set[s].beK);
            if(moi > g_pos[k].sl) g_pos[k].sl = moi;
            g_pos[k].be = true;
            g_canLuu = true;
           }
        }
      else
        {
         if(tk.ask >= g_pos[k].sl) { DongViThe(k, tk.ask, (g_pos[k].be ? "Cham SL hoa von" : "Cham SL")); continue; }
         if(g_pos[k].tp > 0.0 && tk.ask <= g_pos[k].tp) { DongViThe(k, tk.ask, "Cham TP"); continue; }
         if(g_set[s].be && !g_pos[k].be && (g_pos[k].entry - tk.ask) / g_pos[k].risk >= g_set[s].beR)
           {
            double moi = g_pos[k].entry - P2G(g_set[s].beK);
            if(moi < g_pos[k].sl) g_pos[k].sl = moi;
            g_pos[k].be = true;
            g_canLuu = true;
           }
        }
     }
  }

void CapNhatEquity(const MqlTick &tk)
  {
   for(int s = 0; s < MAX_SET; s++)
     {
      if(!g_set[s].on) continue;
      double fl = 0.0;
      if(g_set[s].that)
        {
         for(int i = PositionsTotal() - 1; i >= 0; i--)
           {
            ulong t = PositionGetTicket(i);
            if(t == 0 || !PositionSelectByTicket(t)) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            int ss, pp;
            if(!TachMagic(PositionGetInteger(POSITION_MAGIC), ss, pp) || ss != s) continue;
            fl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
           }
        }
      else
        {
         for(int k = 0; k < ArraySize(g_pos); k++)
           {
            if(g_pos[k].set != s) continue;
            double gia = (g_pos[k].dir == DIR_BULL ? tk.bid : tk.ask);
            fl += TinhLoiNhuan(g_pos[k].dir, g_pos[k].lot, g_pos[k].entry, gia);
           }
        }
      g_set[s].eq = g_set[s].bal + fl;
      if(g_set[s].eq > g_set[s].peak) g_set[s].peak = g_set[s].eq;
      double dd = (g_set[s].peak > 0.0 ? (g_set[s].peak - g_set[s].eq) / g_set[s].peak * 100.0 : 0.0);
      if(dd > g_set[s].maxDD) g_set[s].maxDD = dd;
     }
  }

//+------------------------------------------------------------------+
//| Lưu / nạp trạng thái                                             |
//+------------------------------------------------------------------+
void LuuTrangThai()
  {
   g_canLuu = false;
   if(g_tester) return;
   int h = FileOpen(g_fileTrangThai, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE) return;
   FileWriteString(h, "V2;" + IntegerToString((long)g_nextId) + "\r\n");
   for(int s = 0; s < MAX_SET; s++)
     {
      if(!g_set[s].on) continue;
      FileWriteString(h, "SET;" + IntegerToString(s) + ";" + g_set[s].ten + ";" + (g_set[s].that ? "1" : "0") + ";"
                         + DoubleToString(g_set[s].bal, 2) + ";" + DoubleToString(g_set[s].peak, 2) + ";"
                         + DoubleToString(g_set[s].maxDD, 4) + ";" + IntegerToString(g_set[s].trades) + ";"
                         + IntegerToString(g_set[s].wins) + ";" + DoubleToString(g_set[s].gp, 2) + ";" + DoubleToString(g_set[s].gl, 2) + "\r\n");
     }
   for(int k = 0; k < ArraySize(g_pos); k++)
      FileWriteString(h, "POS;" + IntegerToString((long)g_pos[k].id) + ";" + IntegerToString(g_pos[k].set) + ";"
                         + IntegerToString(g_pos[k].pp) + ";" + IntegerToString(g_pos[k].dir) + ";"
                         + DoubleToString(g_pos[k].lot, 2) + ";" + DoubleToString(g_pos[k].entry, g_digits) + ";"
                         + DoubleToString(g_pos[k].sl, g_digits) + ";" + DoubleToString(g_pos[k].tp, g_digits) + ";"
                         + DoubleToString(g_pos[k].risk, g_digits) + ";" + IntegerToString((long)g_pos[k].tOpen) + ";"
                         + (g_pos[k].be ? "1" : "0") + "\r\n");
   FileClose(h);
   g_lastSave = TimeCurrent();
  }

void NapTrangThai()
  {
   if(g_tester || ResetTrangThai) return;
   if(!FileIsExist(g_fileTrangThai, FILE_COMMON)) return;
   int h = FileOpen(g_fileTrangThai, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE) return;
   bool setOk[MAX_SET];
   for(int i = 0; i < MAX_SET; i++) setOk[i] = false;
   int soSet = 0, soPos = 0;
   while(!FileIsEnding(h))
     {
      string line = FileReadString(h);
      string f[];
      int k = StringSplit(line, StringGetCharacter(";", 0), f);
      if(k < 2) continue;
      if(f[0] == "V2") g_nextId = (ulong)StringToInteger(f[1]);
      else if(f[0] == "SET" && k >= 11)
        {
         int s = (int)StringToInteger(f[1]);
         if(s < 0 || s >= MAX_SET || !g_set[s].on || g_set[s].ten != f[2]) continue;
         if((g_set[s].that ? "1" : "0") != f[3]) continue;   // đổi chế độ thật/ảo -> đếm lại
         g_set[s].bal = StringToDouble(f[4]);
         g_set[s].peak = StringToDouble(f[5]);
         g_set[s].maxDD = StringToDouble(f[6]);
         g_set[s].trades = (int)StringToInteger(f[7]);
         g_set[s].wins = (int)StringToInteger(f[8]);
         g_set[s].gp = StringToDouble(f[9]);
         g_set[s].gl = StringToDouble(f[10]);
         g_set[s].eq = g_set[s].bal;
         setOk[s] = true;
         soSet++;
        }
      else if(f[0] == "POS" && k >= 12)
        {
         int s = (int)StringToInteger(f[2]);
         if(s < 0 || s >= MAX_SET || !setOk[s] || g_set[s].that) continue;
         int n = ArraySize(g_pos);
         ArrayResize(g_pos, n + 1);
         g_pos[n].id = (ulong)StringToInteger(f[1]);
         g_pos[n].set = s;
         g_pos[n].pp = (int)StringToInteger(f[3]);
         g_pos[n].dir = (int)StringToInteger(f[4]);
         g_pos[n].lot = StringToDouble(f[5]);
         g_pos[n].entry = StringToDouble(f[6]);
         g_pos[n].sl = StringToDouble(f[7]);
         g_pos[n].tp = StringToDouble(f[8]);
         g_pos[n].risk = StringToDouble(f[9]);
         g_pos[n].tOpen = (datetime)StringToInteger(f[10]);
         g_pos[n].be = (f[11] == "1");
         g_pos[n].ghiChu = "nap lai sau khoi dong";
         soPos++;
        }
     }
   FileClose(h);
   Print("Nạp trạng thái: ", soSet, " SET, ", soPos, " lệnh ảo đang mở");
  }

void GhiTongKet()
  {
   if(!GhiCSV) return;
   int h = FileOpen(g_fileTongKet, FILE_WRITE | FILE_TXT | FILE_UNICODE | FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE) return;
   FileWriteString(h, "Cap nhat;" + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + ";Tien;" + AccountInfoString(ACCOUNT_CURRENCY)
                      + ";Risk that %;" + DoubleToString(RuiRo_That_PT, 2) + ";Risk ao %;" + DoubleToString(Risk_PT, 2) + "\r\n");
   FileWriteString(h, "SET;Che do;So lenh;Thang %;PF;Loi nhuan;Balance SET;Equity SET;Max DD %;Dang mo;Cau hinh\r\n");
   for(int s = 0; s < MAX_SET; s++)
     {
      if(!g_set[s].on) continue;
      double wr = (g_set[s].trades > 0 ? 100.0 * g_set[s].wins / g_set[s].trades : 0.0);
      string pf = (g_set[s].gl > 0.0 ? DoubleToString(g_set[s].gp / g_set[s].gl, 2) : "-");
      string cfg = g_set[s].cauHinh;
      StringReplace(cfg, ";", " ");
      FileWriteString(h, g_set[s].ten + ";" + (g_set[s].that ? "THAT" : "AO") + ";" + IntegerToString(g_set[s].trades) + ";"
                         + DoubleToString(wr, 1) + ";" + pf + ";" + D2(g_set[s].gp - g_set[s].gl) + ";" + D2(g_set[s].bal) + ";"
                         + D2(g_set[s].eq) + ";" + DoubleToString(g_set[s].maxDD, 2) + ";" + IntegerToString(DemLenh(s, 0)) + ";" + cfg + "\r\n");
     }
   FileClose(h);
  }

//+------------------------------------------------------------------+
//| BẢNG ĐIỀU KHIỂN                                                  |
//+------------------------------------------------------------------+
#define UI_FONT   "Segoe UI"
#define UI_FONTB  "Segoe UI Semibold"
#define C_BG      C'13,17,26'
#define C_HEAD    C'22,30,46'
#define C_CARD    C'20,27,40'
#define C_LINE    C'42,54,74'
#define C_ROW1    C'18,24,36'
#define C_ROW2    C'15,20,31'
#define C_TEXT    C'226,232,240'
#define C_MUTED   C'136,150,170'
#define C_GOLD    C'246,196,82'
#define C_GREEN   C'64,214,124'
#define C_RED     C'255,95,95'
#define C_BLUE    C'100,178,255'
#define C_REAL    C'26,120,72'
#define C_VIRT    C'58,68,88'

void UiRect(const string id, const int x, const int y, const int w, const int h, const color bg, const color bd)
  {
   string n = OBJ_PREFIX + id;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_BACK, false);
     }
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_COLOR, bd);
  }

void UiText(const string id, const string text, const int x, const int y, const int size, const color clr, const string font, const bool right = false)
  {
   string n = OBJ_PREFIX + id;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_BACK, false);
     }
   ObjectSetInteger(0, n, OBJPROP_ANCHOR, (right ? ANCHOR_RIGHT_UPPER : ANCHOR_LEFT_UPPER));
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   ObjectSetString(0, n, OBJPROP_FONT, font);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
  }

string Tien(const double v) { return (v > 0.005 ? "+" : "") + DoubleToString(v, 2); }

void UpdateDashboard()
  {
   if(!HienThiBang || !g_veDuoc) return;
   uint now = GetTickCount();
   if(g_dbLast != 0 && now - g_dbLast < 1000) return;
   g_dbLast = now;

   int X = 10, Y = 22, W = 840;
   string cur = AccountInfoString(ACCOUNT_CURRENCY);
   bool cent = (cur == "USC" || StringFind(cur, "C") == 2);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   double ngay = eq - g_balDauNgay;
   int    soThat = DemLenhThat(-1, 0);
   bool   khoa = (g_khoaNgay || g_khoaTong);

   //--- sắp xếp SET theo lợi nhuận
   int idx[MAX_SET];
   int m = 0;
   for(int s = 0; s < MAX_SET; s++) if(g_set[s].on) idx[m++] = s;
   for(int a = 0; a < m - 1; a++)
      for(int b = a + 1; b < m; b++)
        {
         double pa = g_set[idx[a]].eq - (g_set[idx[a]].bal - (g_set[idx[a]].gp - g_set[idx[a]].gl));
         double pb = g_set[idx[b]].eq - (g_set[idx[b]].bal - (g_set[idx[b]].gp - g_set[idx[b]].gl));
         if(pb > pa) { int t = idx[a]; idx[a] = idx[b]; idx[b] = t; }
        }

   int H = 48 + 70 + 30 + m * 26 + 40;
   UiRect("BG", X, Y, W, H, C_BG, C_LINE);
   //--- Tiêu đề
   UiRect("HEAD", X, Y, W, 48, C_HEAD, C_LINE);
   UiText("TITLE", "EA MASTER PRO", X + 14, Y + 6, 14, C_GOLD, UI_FONTB);
   UiText("SUB", _Symbol + "  •  v" + EA_VER + "  •  " + (cent ? "Tài khoản CENT (" + cur + ")" : "Tài khoản " + cur) + "  •  "
          + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES), X + 15, Y + 29, 8, C_MUTED, UI_FONT);
   UiRect("BADGE", X + W - 210, Y + 12, 196, 24, (khoa ? C'120,70,20' : C'20,90,56'), (khoa ? C'200,120,40' : C_GREEN));
   UiText("BADGE_T", (khoa ? "■ TẠM DỪNG LỆNH MỚI" : "● ĐANG CHẠY"), X + W - 112, Y + 16, 9, C_TEXT, UI_FONTB);
   ObjectSetInteger(0, OBJ_PREFIX + "BADGE_T", OBJPROP_ANCHOR, ANCHOR_UPPER);

   //--- Thẻ số liệu
   string tt[5] = {"BALANCE", "EQUITY", "LÃI/LỖ HÔM NAY", "DD HIỆN TẠI", "LỆNH THẬT ĐANG MỞ"};
   string vv[5];
   color  cc[5];
   vv[0] = DoubleToString(bal, 2) + " " + cur;   cc[0] = C_TEXT;
   vv[1] = DoubleToString(eq, 2) + " " + cur;    cc[1] = (eq >= bal ? C_GREEN : C_RED);
   vv[2] = Tien(ngay);                            cc[2] = (ngay >= 0.0 ? C_GREEN : C_RED);
   vv[3] = DoubleToString(g_ddTong, 2) + "%";     cc[3] = (g_ddTong < 5.0 ? C_GREEN : (g_ddTong < 15.0 ? C_GOLD : C_RED));
   vv[4] = IntegerToString(soThat) + " / " + IntegerToString(MaxLenhThat_Tong); cc[4] = C_BLUE;
   int cw = (W - 28 - 4 * 8) / 5;
   for(int i = 0; i < 5; i++)
     {
      int cx = X + 14 + i * (cw + 8);
      UiRect("CARD" + IntegerToString(i), cx, Y + 58, cw, 54, C_CARD, C_LINE);
      UiText("CARDT" + IntegerToString(i), tt[i], cx + 10, Y + 64, 7, C_MUTED, UI_FONT);
      UiText("CARDV" + IntegerToString(i), vv[i], cx + 10, Y + 80, 12, cc[i], UI_FONTB);
     }

   //--- Bảng SET
   int ty = Y + 124;
   int col[9] = {14, 40, 250, 330, 390, 455, 515, 640, 735};
   string hd[9] = {"#", "SET", "CHẾ ĐỘ", "LỆNH", "THẮNG", "PF", "LỢI NHUẬN", "MAX DD", "ĐANG MỞ"};
   UiRect("THEAD", X + 8, ty, W - 16, 24, C_HEAD, C_LINE);
   for(int c = 0; c < 9; c++) UiText("TH" + IntegerToString(c), hd[c], X + col[c], ty + 5, 8, C_MUTED, UI_FONTB);
   for(int r = 0; r < MAX_SET; r++)
     {
      string rid = IntegerToString(r);
      if(r >= m)
        {
         ObjectDelete(0, OBJ_PREFIX + "ROW" + rid);
         ObjectDelete(0, OBJ_PREFIX + "MODE" + rid);
         for(int c = 0; c < 9; c++) ObjectDelete(0, OBJ_PREFIX + "C" + rid + "_" + IntegerToString(c));
         continue;
        }
      int s = idx[r];
      int ry = ty + 26 + r * 26;
      double ln = g_set[s].eq - (g_set[s].bal - (g_set[s].gp - g_set[s].gl));
      double wr = (g_set[s].trades > 0 ? 100.0 * g_set[s].wins / g_set[s].trades : 0.0);
      string pf = (g_set[s].gl > 0.0 ? DoubleToString(g_set[s].gp / g_set[s].gl, 2) : "-");
      UiRect("ROW" + rid, X + 8, ry, W - 16, 24, (r % 2 == 0 ? C_ROW1 : C_ROW2), (r % 2 == 0 ? C_ROW1 : C_ROW2));
      UiRect("MODE" + rid, X + col[2] - 4, ry + 4, 56, 16, (g_set[s].that ? C_REAL : C_VIRT), (g_set[s].that ? C_GREEN : C_LINE));
      UiText("C" + rid + "_0", IntegerToString(r + 1), X + col[0], ry + 4, 9, (r < 3 ? C_GOLD : C_MUTED), UI_FONTB);
      UiText("C" + rid + "_1", StringSubstr(g_set[s].ten, 0, 26), X + col[1], ry + 4, 9, C_TEXT, UI_FONT);
      UiText("C" + rid + "_2", (g_set[s].that ? "THẬT" : "ẢO"), X + col[2] + 24, ry + 5, 8, C_TEXT, UI_FONTB);
      ObjectSetInteger(0, OBJ_PREFIX + "C" + rid + "_2", OBJPROP_ANCHOR, ANCHOR_UPPER);
      UiText("C" + rid + "_3", IntegerToString(g_set[s].trades), X + col[3], ry + 4, 9, C_TEXT, UI_FONT);
      UiText("C" + rid + "_4", DoubleToString(wr, 1) + "%", X + col[4], ry + 4, 9, (wr >= 45.0 ? C_GREEN : C_TEXT), UI_FONT);
      UiText("C" + rid + "_5", pf, X + col[5], ry + 4, 9, (g_set[s].gl > 0.0 && g_set[s].gp > g_set[s].gl ? C_GREEN : C_TEXT), UI_FONT);
      UiText("C" + rid + "_6", Tien(ln) + " " + cur, X + col[6], ry + 4, 9, (ln >= 0.0 ? C_GREEN : C_RED), UI_FONTB);
      UiText("C" + rid + "_7", DoubleToString(g_set[s].maxDD, 2) + "%", X + col[7], ry + 4, 9, (g_set[s].maxDD < 15.0 ? C_TEXT : C_RED), UI_FONT);
      UiText("C" + rid + "_8", IntegerToString(DemLenh(s, 0)), X + col[8], ry + 4, 9, C_BLUE, UI_FONT);
     }

   //--- Chân bảng
   int fy = ty + 26 + m * 26 + 6;
   UiText("FOOT1", StringFormat("Lệnh THẬT: rủi ro %.1f%%/lệnh • chốt chặn %.1f%% • tối đa %d lệnh • spread ≤ %.0f pip • DD ngày %s • DD tổng %s",
                                RuiRo_That_PT, ChotChan_PT, MaxLenhThat_Tong, Spread_ToiDa_Pips,
                                (Bat_DDNgay ? DoubleToString(DDNgay_PT, 0) + "%" : "tắt"), (Bat_DDTong ? DoubleToString(DDTong_PT, 0) + "%" : "tắt")),
          X + 14, fy, 8, C_MUTED, UI_FONT);
   UiText("FOOT2", (khoa ? "Tạm dừng: " + g_lyDoKhoa : "Lợi nhuận SET ẢO tính trên vốn ảo, rủi ro " + DoubleToString(Risk_PT, 1)
          + "%. Nhật ký: Common\\Files\\" + g_fileLenh), X + 14, fy + 16, 8, (khoa ? C_GOLD : C_MUTED), UI_FONT);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Sự kiện                                                          |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_digits = _Digits;
   g_pip = TinhKichThuocPip();
   g_tester = (MQLInfoInteger(MQL_TESTER) != 0);
   g_veDuoc = !(g_tester && MQLInfoInteger(MQL_VISUAL_MODE) == 0);
   if(Magic_Goc <= 0 || RuiRo_That_PT <= 0.0 || RuiRo_That_PT > 10.0 || Risk_PT <= 0.0 || Risk_PT > 20.0 || MaxLenhThat_Tong < 1)
     {
      Print("LỖI INPUT: Magic_Goc > 0, RuiRo_That_PT (0;10], Risk_PT (0;20], MaxLenhThat_Tong >= 1");
      return INIT_PARAMETERS_INCORRECT;
     }
   g_trade.SetDeviationInPoints(TruotGia_Points);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetMarginMode();
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   string hauTo = (g_tester ? "_TESTER" : "");
   g_fileLenh      = "EAM_PRO_" + MaPhien + hauTo + "_LENH.csv";
   g_fileTongKet   = "EAM_PRO_" + MaPhien + hauTo + "_TONGKET.csv";
   g_fileTrangThai = "EAM_PRO_" + MaPhien + "_TRANGTHAI.txt";
   if(g_tester && GhiCSV) FileDelete(g_fileLenh, FILE_COMMON);

   int soSet = 0, soThat = 0;
   for(int i = 0; i < MAX_SET; i++)
     {
      if(!DocCauHinh(i, CauHinhInput(i))) return INIT_PARAMETERS_INCORRECT;
      if(!g_set[i].on) continue;
      if(!g_e2[i].Start() || !g_e4[i].Start())
        {
         Print("LỖI: không tạo được chỉ báo cho SET ", i + 1);
         return INIT_FAILED;
        }
      soSet++;
      if(g_set[i].that) soThat++;
      Print(StringFormat("SET %d [%s] %s | PP2=%s PP4=%s | magic %I64d/%I64d | %s", i + 1, g_set[i].ten, (g_set[i].that ? "THẬT" : "ẢO"),
                         (g_e2[i].on ? TfStr(g_e2[i].tf) : "tắt"), (g_e4[i].on ? TfStr(g_e4[i].tf) : "tắt"),
                         MagicPP(i, 2), MagicPP(i, 4), g_set[i].cauHinh));
     }
   if(soSet == 0) { Print("LỖI: chưa có SET nào"); return INIT_PARAMETERS_INCORRECT; }
   if(soThat > 1) Print("CẢNH BÁO: ", soThat, " SET đang chạy THẬT. Các SET dùng chung tín hiệu PP2 H1 sẽ mở trùng lệnh -> rủi ro cộng dồn.");
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      Print("CẢNH BÁO: tài khoản NETTING - các lệnh cùng symbol sẽ gộp vị thế. Nên dùng tài khoản HEDGING.");

   ArrayResize(g_pos, 0);
   NapTrangThai();

   g_gvDinh = "EAMPRO_" + IntegerToString(Magic_Goc) + "_DINH";
   g_dinhEq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(!g_tester && GlobalVariableCheck(g_gvDinh) && !ResetTrangThai) g_dinhEq = MathMax(g_dinhEq, GlobalVariableGet(g_gvDinh));
   g_ngay = 0;
   KiemTraAnToan();

   double p10 = TinhLoMoiLot(DIR_BULL, 2000.0, 2000.0 - P2G(10.0));
   Print("EA MASTER PRO v", EA_VER, " | ", soSet, " SET (", soThat, " thật) | tiền ", AccountInfoString(ACCOUNT_CURRENCY),
         " | 1 lot đi ngược 10 pip = ", D2(p10), " ", AccountInfoString(ACCOUNT_CURRENCY), " | rủi ro thật ", DoubleToString(RuiRo_That_PT, 1), "%");
   if(HienThiBang && g_veDuoc)
     {
      EventSetTimer(1);
      UpdateDashboard();
     }
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   LuuTrangThai();
   GhiTongKet();
   Print("========== TỔNG KẾT EA MASTER PRO (", _Symbol, ") ==========");
   for(int s = 0; s < MAX_SET; s++)
     {
      if(!g_set[s].on) continue;
      double wr = (g_set[s].trades > 0 ? 100.0 * g_set[s].wins / g_set[s].trades : 0.0);
      string pf = (g_set[s].gl > 0.0 ? DoubleToString(g_set[s].gp / g_set[s].gl, 2) : "-");
      Print(StringFormat("%-26s %-4s | lệnh %4d | thắng %5.1f%% | PF %s | lợi nhuận %10.2f | max DD %6.2f%%",
                         g_set[s].ten, (g_set[s].that ? "THẬT" : "ẢO"), g_set[s].trades, wr, pf, g_set[s].gp - g_set[s].gl, g_set[s].maxDD));
      g_e2[s].Stop();
      g_e4[s].Stop();
     }
   ObjectsDeleteAll(0, OBJ_PREFIX);
   ChartRedraw(0);
  }

//--- Thống kê lệnh THẬT khi đóng (SL/TP trên server, đóng tay...)
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;
   int s, pp;
   if(!TachMagic(HistoryDealGetInteger(trans.deal, DEAL_MAGIC), s, pp)) return;
   double p = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
            + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION) + HistoryDealGetDouble(trans.deal, DEAL_FEE);
   g_set[s].bal += p;
   ENUM_DEAL_ENTRY en = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(en == DEAL_ENTRY_OUT || en == DEAL_ENTRY_OUT_BY || en == DEAL_ENTRY_INOUT)
     {
      g_set[s].trades++;
      if(p > 0.0) { g_set[s].wins++; g_set[s].gp += p; }
      else g_set[s].gl += -p;
      ENUM_DEAL_REASON rs = (ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON);
      string lyDo = (rs == DEAL_REASON_SL ? "Cham SL" : (rs == DEAL_REASON_TP ? "Cham TP" : (rs == DEAL_REASON_EXPERT ? "EA dong" : "Khac")));
      string huong = (HistoryDealGetInteger(trans.deal, DEAL_TYPE) == DEAL_TYPE_SELL ? "BUY" : "SELL");
      GhiDongCSV(g_fileLenh, ";" + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + ";" + g_set[s].ten + ";THAT;PP" + IntegerToString(pp)
                 + ";" + huong + ";" + D2(HistoryDealGetDouble(trans.deal, DEAL_VOLUME)) + ";;" + D(HistoryDealGetDouble(trans.deal, DEAL_PRICE))
                 + ";;;" + D2(p) + ";;" + lyDo + ";" + D2(g_set[s].bal) + ";#" + IntegerToString(HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID)),
                 CSV_HEADER);
      if(InLog) Print("[", g_set[s].ten, "] ĐÓNG THẬT PP", pp, " ", lyDo, " LN=", D2(p), " ", AccountInfoString(ACCOUNT_CURRENCY));
     }
   g_canLuu = true;
  }

void OnTick()
  {
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;
   KiemTraAnToan();
   QuanLyLenhThat(tk);
   QuanLyViThe(tk);
   for(int s = 0; s < MAX_SET; s++)
     {
      if(!g_set[s].on) continue;
      if(g_e2[s].on)
        {
         g_e2[s].openCount = DemLenh(s, 2);
         g_e2[s].XuLyTick();
         if(g_e2[s].hasSig && g_e2[s].openCount < g_set[s].maxLenh && DemLenh(s, 0) < 4)
           {
            if(g_set[s].that) MoLenhThat(s, 2, g_e2[s].sigDir, g_e2[s].sigSL, g_e2[s].sigTP, g_e2[s].sigWhy);
            else MoViThe(s, 2, g_e2[s].sigDir, g_e2[s].sigSL, g_e2[s].sigTP, g_e2[s].sigWhy);
           }
        }
      if(g_e4[s].on)
        {
         g_e4[s].openCount = DemLenh(s, 4);
         g_e4[s].XuLyTick();
         if(g_e4[s].hasSig && DemLenh(s, 0) < 4)
           {
            if(g_set[s].that) MoLenhThat(s, 4, g_e4[s].sigDir, g_e4[s].sigSL, g_e4[s].sigTP, g_e4[s].sigWhy);
            else MoViThe(s, 4, g_e4[s].sigDir, g_e4[s].sigSL, g_e4[s].sigTP, g_e4[s].sigWhy);
           }
        }
     }
   CapNhatEquity(tk);
   if(g_canLuu || TimeCurrent() - g_lastSave >= 300)
     {
      LuuTrangThai();
      if(!g_tester) GhiTongKet();
     }
   UpdateDashboard();
  }

void OnTimer()
  {
   if(g_dbLast != 0 && GetTickCount() - g_dbLast < 2000) return;
   g_dbLast = 0;
   UpdateDashboard();
  }

double OnTester()
  {
   GhiTongKet();
   return TesterStatistics(STAT_PROFIT);
  }
//+------------------------------------------------------------------+
