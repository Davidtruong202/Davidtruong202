//+------------------------------------------------------------------+
//|                                       EA_MASTER_SETAO_V100.mq5   |
//|  EA MASTER - SET ẢO: 1 chart chạy song song tối đa 8 SET ảo       |
//|                                                                  |
//|  - Mỗi SET có bộ máy PP2 (SMC Order Block) và/hoặc PP4 (QM) riêng |
//|    (logic chuyển nguyên từ EA_MASTER_4PP v1.40).                  |
//|  - Lệnh ẢO: không gửi lệnh lên sàn. Vào giá Ask/Bid thật, đóng    |
//|    khi giá Bid/Ask chạm SL/TP, có dời hòa vốn.                    |
//|  - Mỗi SET có vốn ảo riêng, rủi ro % theo vốn ảo, thống kê riêng. |
//|  - Ghi mọi lệnh ảo + bảng tổng kết ra Common\Files, lưu trạng    |
//|    thái để chạy tiếp sau khi khởi động lại MT5.                   |
//|                                                                  |
//|  Cấu hình SET: chuỗi KHÓA=GIÁ TRỊ cách nhau bởi dấu ;            |
//|   TEN=tên | PP2=OFF/M5/M15/M30/H1/H4 | OB=IN/SW/ALL | RR=1.5     |
//|   XN=1/0 (nến xác nhận) | SLD=đệm SL pip | SLM=SL tối thiểu pip   |
//|   SW=độ dài swing | NOB=số OB xét | TREND=1/0                     |
//|   PP4=OFF/M15/M30/H1/H4 | RR4=2 | E2=1/0 | SLD4=20 | LB=5 | CHO=30 |
//|   BE=1/0 | BER=1.0 (R) | BEK=5 (pip khóa) | MAX=1 (lệnh/PP)        |
//+------------------------------------------------------------------+
#property copyright "EA MASTER SET AO"
#property version   "1.00"
#property description "1 chart - nhiều SET ảo PP2/PP4. Lệnh ảo, không gửi lệnh lên sàn."
#property description "Kết quả: Common\\Files\\EAM_SETAO_<Mã phiên>_*.csv"

#define MAX_SET     8
#define DIR_BULL    1
#define DIR_BEAR    -1
#define OBJ_PREFIX  "EAMSA_"
#define EA_VER      "1.00"

//+------------------------------------------------------------------+
//| INPUT                                                            |
//+------------------------------------------------------------------+
input group "=== CHUNG ==="
input string MaPhien               = "SETAO1"; // Mã phiên (tên file kết quả / trạng thái)
input double VonAo_MoiSet          = 5000.0;   // Vốn ảo mỗi SET (USD)
input double Risk_PT               = 3.0;      // Rủi ro mỗi lệnh (% vốn ảo của SET)
input double Spread_ToiDa_Pips     = 50.0;     // Spread tối đa để vào lệnh (pip; XAU 1 pip = 0.10)
input double KichThuocPip_TuyChinh = 0.0;      // Kích thước 1 pip (0 = tự động)
input bool   ResetTrangThai        = false;    // Bắt đầu lại từ đầu (bỏ số liệu đã lưu)
input bool   GhiCSV                = true;     // Ghi lệnh ảo + tổng kết ra CSV
input bool   HienThiBang           = true;     // Hiển thị bảng xếp hạng trên chart
input bool   InLog                 = true;     // In log mở/đóng lệnh ảo

input group "=== CÁC SET ẢO (để trống = tắt) ==="
input string Set1 = "TEN=F1_PP2H1_PP4H1;PP2=H1;OB=IN;RR=1.5;XN=1;SLD=10;PP4=H1;RR4=2;E2=1;BE=1";       // SET 1
input string Set2 = "TEN=F2_PP2H1ALL_PP4H1;PP2=H1;OB=ALL;RR=1.5;XN=1;SLD=5;PP4=H1;RR4=2;E2=1;BE=1";    // SET 2
input string Set3 = "TEN=F3_PP2H1;PP2=H1;OB=IN;RR=1.5;XN=1;SLD=10;BE=1";                                // SET 3
input string Set4 = "TEN=F4_PP2M15SW_RR3;PP2=M15;OB=SW;RR=3;XN=0;SLD=5;BE=0";                            // SET 4
input string Set5 = "TEN=F5_PP2H1_PP4H1RR3;PP2=H1;OB=IN;RR=1.5;XN=1;SLD=10;PP4=H1;RR4=3;E2=1;BE=1";    // SET 5
input string Set6 = "TEN=F6_PP2H1_PP4H1_NOBE;PP2=H1;OB=IN;RR=1.5;XN=1;SLD=10;PP4=H1;RR4=3;E2=0;BE=0";  // SET 6
input string Set7 = "";                                                                                    // SET 7
input string Set8 = "";                                                                                    // SET 8

//+------------------------------------------------------------------+
//| Cấu trúc                                                         |
//+------------------------------------------------------------------+
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

double LotTheoRuiRo(const int dir, const double giaVao, const double sl, const double von)
  {
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;
   double lo1 = TinhLoMoiLot(dir, giaVao, sl);
   if(lo1 <= 0.0 || von <= 0.0) return vmin;
   double lot = von * Risk_PT / 100.0 / lo1;
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
SSetAo     g_set[MAX_SET];
CPP2Engine g_e2[MAX_SET];
CPP4Engine g_e4[MAX_SET];
SViThe     g_pos[];
ulong      g_nextId = 1;

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
   g_set[i].ten = "SET" + IntegerToString(i + 1);
   g_set[i].cauHinh = cfg;
   g_set[i].be = true; g_set[i].beR = 1.0; g_set[i].beK = 5.0; g_set[i].maxLenh = 1;
   g_set[i].bal = VonAo_MoiSet; g_set[i].peak = VonAo_MoiSet; g_set[i].maxDD = 0.0;
   g_set[i].trades = 0; g_set[i].wins = 0; g_set[i].gp = 0.0; g_set[i].gl = 0.0; g_set[i].eq = VonAo_MoiSet;
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
   return true;
  }

int DemViThe(const int set, const int pp)
  {
   int c = 0;
   for(int i = 0; i < ArraySize(g_pos); i++)
      if(g_pos[i].set == set && (pp == 0 || g_pos[i].pp == pp)) c++;
   return c;
  }

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

void MoViThe(const int s, const int pp, const int dir, const double sl, const double tp, const string why)
  {
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;
   double sp = G2P(tk.ask - tk.bid);
   if(sp > Spread_ToiDa_Pips)
     {
      if(InLog) Print("[", g_set[s].ten, "] PP", pp, " bỏ tín hiệu: spread ", DoubleToString(sp, 1), " pip");
      return;
     }
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
   g_pos[k].lot = LotTheoRuiRo(dir, entry, sl, g_set[s].bal);
   g_pos[k].entry = entry;
   g_pos[k].sl = sl;
   g_pos[k].tp = tp;
   g_pos[k].risk = risk;
   g_pos[k].tOpen = TimeCurrent();
   g_pos[k].be = false;
   g_pos[k].ghiChu = why;
   g_canLuu = true;
   if(InLog)
      Print("[", g_set[s].ten, "] MỞ ẢO PP", pp, " ", (dir == DIR_BULL ? "BUY" : "SELL"), " #", g_pos[k].id,
            " lot=", D2(g_pos[k].lot), " giá=", D(entry), " SL=", D(sl), " TP=", D(tp),
            " spread=", DoubleToString(sp, 1), " | ", why);
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
   string dong = TimeToString(g_pos[k].tOpen, TIME_DATE | TIME_SECONDS) + ";" + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS)
               + ";" + g_set[s].ten + ";PP" + IntegerToString(g_pos[k].pp) + ";" + (g_pos[k].dir == DIR_BULL ? "BUY" : "SELL")
               + ";" + D2(g_pos[k].lot) + ";" + D(g_pos[k].entry) + ";" + D(giaRa) + ";" + D(g_pos[k].sl) + ";" + D(g_pos[k].tp)
               + ";" + D2(p) + ";" + DoubleToString(r, 2) + ";" + lyDo + ";" + D2(g_set[s].bal) + ";" + g_pos[k].ghiChu;
   GhiDongCSV(g_fileLenh, dong, "Mo luc;Dong luc;SET;PP;Huong;Lot;Gia vao;Gia ra;SL;TP;Loi nhuan;R;Ly do;Balance ao;Ghi chu");
   if(InLog)
      Print("[", g_set[s].ten, "] ĐÓNG ẢO #", g_pos[k].id, " ", lyDo, " giá=", D(giaRa), " LN=", D2(p),
            " (", DoubleToString(r, 2), "R) | balance ảo=", D2(g_set[s].bal));
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
      for(int k = 0; k < ArraySize(g_pos); k++)
        {
         if(g_pos[k].set != s) continue;
         double gia = (g_pos[k].dir == DIR_BULL ? tk.bid : tk.ask);
         fl += TinhLoiNhuan(g_pos[k].dir, g_pos[k].lot, g_pos[k].entry, gia);
        }
      g_set[s].eq = g_set[s].bal + fl;
      if(g_set[s].eq > g_set[s].peak) g_set[s].peak = g_set[s].eq;
      double dd = (g_set[s].peak > 0.0 ? (g_set[s].peak - g_set[s].eq) / g_set[s].peak * 100.0 : 0.0);
      if(dd > g_set[s].maxDD) g_set[s].maxDD = dd;
     }
  }

//+------------------------------------------------------------------+
//| Lưu / nạp trạng thái (chạy tiếp sau khi khởi động lại)           |
//+------------------------------------------------------------------+
void LuuTrangThai()
  {
   if(g_tester) return;
   int h = FileOpen(g_fileTrangThai, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE) return;
   FileWriteString(h, "V1;" + IntegerToString((long)g_nextId) + "\r\n");
   for(int s = 0; s < MAX_SET; s++)
     {
      if(!g_set[s].on) continue;
      FileWriteString(h, "SET;" + IntegerToString(s) + ";" + g_set[s].ten + ";" + DoubleToString(g_set[s].bal, 2) + ";"
                         + DoubleToString(g_set[s].peak, 2) + ";" + DoubleToString(g_set[s].maxDD, 4) + ";"
                         + IntegerToString(g_set[s].trades) + ";" + IntegerToString(g_set[s].wins) + ";"
                         + DoubleToString(g_set[s].gp, 2) + ";" + DoubleToString(g_set[s].gl, 2) + "\r\n");
     }
   for(int k = 0; k < ArraySize(g_pos); k++)
     {
      FileWriteString(h, "POS;" + IntegerToString((long)g_pos[k].id) + ";" + IntegerToString(g_pos[k].set) + ";"
                         + IntegerToString(g_pos[k].pp) + ";" + IntegerToString(g_pos[k].dir) + ";"
                         + DoubleToString(g_pos[k].lot, 2) + ";" + DoubleToString(g_pos[k].entry, g_digits) + ";"
                         + DoubleToString(g_pos[k].sl, g_digits) + ";" + DoubleToString(g_pos[k].tp, g_digits) + ";"
                         + DoubleToString(g_pos[k].risk, g_digits) + ";" + IntegerToString((long)g_pos[k].tOpen) + ";"
                         + (g_pos[k].be ? "1" : "0") + "\r\n");
     }
   FileClose(h);
   g_lastSave = TimeCurrent();
   g_canLuu = false;
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
      if(f[0] == "V1") g_nextId = (ulong)StringToInteger(f[1]);
      else if(f[0] == "SET" && k >= 10)
        {
         int s = (int)StringToInteger(f[1]);
         if(s < 0 || s >= MAX_SET || !g_set[s].on || g_set[s].ten != f[2]) continue;
         g_set[s].bal = StringToDouble(f[3]);
         g_set[s].peak = StringToDouble(f[4]);
         g_set[s].maxDD = StringToDouble(f[5]);
         g_set[s].trades = (int)StringToInteger(f[6]);
         g_set[s].wins = (int)StringToInteger(f[7]);
         g_set[s].gp = StringToDouble(f[8]);
         g_set[s].gl = StringToDouble(f[9]);
         setOk[s] = true;
         soSet++;
        }
      else if(f[0] == "POS" && k >= 12)
        {
         int s = (int)StringToInteger(f[2]);
         if(s < 0 || s >= MAX_SET || !setOk[s]) continue;
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
   Print("Nạp trạng thái: ", soSet, " SET, ", soPos, " lệnh ảo đang mở (", g_fileTrangThai, ")");
  }

void GhiTongKet()
  {
   if(!GhiCSV) return;
   int h = FileOpen(g_fileTongKet, FILE_WRITE | FILE_TXT | FILE_UNICODE | FILE_COMMON | FILE_SHARE_READ);
   if(h == INVALID_HANDLE) return;
   FileWriteString(h, "Cap nhat;" + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + ";Von ao;" + D2(VonAo_MoiSet)
                      + ";Risk %;" + DoubleToString(Risk_PT, 2) + "\r\n");
   FileWriteString(h, "SET;So lenh;Thang %;PF;Loi nhuan;Balance ao;Equity ao;Max DD %;Dang mo;Cau hinh\r\n");
   for(int s = 0; s < MAX_SET; s++)
     {
      if(!g_set[s].on) continue;
      double wr = (g_set[s].trades > 0 ? 100.0 * g_set[s].wins / g_set[s].trades : 0.0);
      string pf = (g_set[s].gl > 0.0 ? DoubleToString(g_set[s].gp / g_set[s].gl, 2) : "-");
      string cfg = g_set[s].cauHinh;
      StringReplace(cfg, ";", " ");
      FileWriteString(h, g_set[s].ten + ";" + IntegerToString(g_set[s].trades) + ";" + DoubleToString(wr, 1) + ";" + pf
                         + ";" + D2(g_set[s].bal - VonAo_MoiSet) + ";" + D2(g_set[s].bal) + ";" + D2(g_set[s].eq)
                         + ";" + DoubleToString(g_set[s].maxDD, 2) + ";" + IntegerToString(DemViThe(s, 0)) + ";" + cfg + "\r\n");
     }
   FileClose(h);
  }

//+------------------------------------------------------------------+
//| Bảng xếp hạng                                                    |
//+------------------------------------------------------------------+
void DB_Dong(const int i, const string text, const color clr)
  {
   string name = OBJ_PREFIX + "DB_" + IntegerToString(i);
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
     }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 18);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 30 + i * 16);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
  }

void UpdateDashboard()
  {
   if(!HienThiBang || !g_veDuoc) return;
   uint now = GetTickCount();
   if(g_dbLast != 0 && now - g_dbLast < 1000) return;
   g_dbLast = now;
   int idx[MAX_SET];
   int m = 0;
   for(int s = 0; s < MAX_SET; s++) if(g_set[s].on) idx[m++] = s;
   for(int a = 0; a < m - 1; a++)
      for(int b = a + 1; b < m; b++)
         if(g_set[idx[b]].eq > g_set[idx[a]].eq) { int tmp = idx[a]; idx[a] = idx[b]; idx[b] = tmp; }
   string bg = OBJ_PREFIX + "BG";
   if(ObjectFind(0, bg) < 0)
     {
      ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'16,20,30');
      ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);
     }
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, 22);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE, 760);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE, 16 * (m + 3) + 12);
   DB_Dong(0, "EA MASTER SET ẢO v" + EA_VER + " | " + _Symbol + " | Vốn ảo " + D2(VonAo_MoiSet) + "/SET | Risk " +
              DoubleToString(Risk_PT, 1) + "% | Lệnh ảo đang mở: " + IntegerToString(ArraySize(g_pos)), clrGold);
   DB_Dong(1, StringFormat("%-2s %-24s %6s %6s %5s %10s %10s %7s %4s", "#", "SET", "LỆNH", "WR%", "PF", "LỢI NHUẬN", "EQUITY", "MAXDD%", "MỞ"), clrSilver);
   for(int r = 0; r < m; r++)
     {
      int s = idx[r];
      double wr = (g_set[s].trades > 0 ? 100.0 * g_set[s].wins / g_set[s].trades : 0.0);
      string pf = (g_set[s].gl > 0.0 ? DoubleToString(g_set[s].gp / g_set[s].gl, 2) : "-");
      double ln = g_set[s].eq - VonAo_MoiSet;
      DB_Dong(r + 2, StringFormat("%-2d %-24s %6d %6.1f %5s %10.2f %10.2f %7.2f %4d", r + 1, StringSubstr(g_set[s].ten, 0, 24),
                                  g_set[s].trades, wr, pf, ln, g_set[s].eq, g_set[s].maxDD, DemViThe(s, 0)),
              (ln >= 0.0 ? clrLime : clrTomato));
     }
   DB_Dong(m + 2, "Lệnh ẢO - không gửi lệnh lên sàn. File: Common\\Files\\" + g_fileTongKet, clrGray);
   for(int r = m + 3; r < MAX_SET + 3; r++) ObjectDelete(0, OBJ_PREFIX + "DB_" + IntegerToString(r));
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
   if(VonAo_MoiSet <= 0.0 || Risk_PT <= 0.0 || Risk_PT > 20.0)
     {
      Print("LỖI INPUT: Vốn ảo phải > 0, Risk_PT trong (0; 20]");
      return INIT_PARAMETERS_INCORRECT;
     }
   string hauTo = (g_tester ? "_TESTER" : "");
   g_fileLenh      = "EAM_SETAO_" + MaPhien + hauTo + "_LENH.csv";
   g_fileTongKet   = "EAM_SETAO_" + MaPhien + hauTo + "_TONGKET.csv";
   g_fileTrangThai = "EAM_SETAO_" + MaPhien + "_TRANGTHAI.txt";
   if(g_tester && GhiCSV) FileDelete(g_fileLenh, FILE_COMMON);

   int soSet = 0;
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
      Print(StringFormat("SET %d [%s]: PP2=%s PP4=%s | %s", i + 1, g_set[i].ten,
                         (g_e2[i].on ? TfStr(g_e2[i].tf) : "tắt"), (g_e4[i].on ? TfStr(g_e4[i].tf) : "tắt"), g_set[i].cauHinh));
     }
   if(soSet == 0)
     {
      Print("LỖI: chưa có SET nào được cấu hình");
      return INIT_PARAMETERS_INCORRECT;
     }
   ArrayResize(g_pos, 0);
   NapTrangThai();
   Print("EA MASTER SET ẢO v", EA_VER, ": ", soSet, " SET | vốn ảo ", D2(VonAo_MoiSet), " | risk ", DoubleToString(Risk_PT, 1),
         "% | pip=", D(g_pip), " | lệnh ẢO, không gửi lệnh lên sàn");
   if(HienThiBang && g_veDuoc) EventSetTimer(1);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   LuuTrangThai();
   GhiTongKet();
   Print("========== TỔNG KẾT SET ẢO (", _Symbol, ") ==========");
   for(int s = 0; s < MAX_SET; s++)
     {
      if(!g_set[s].on) continue;
      double wr = (g_set[s].trades > 0 ? 100.0 * g_set[s].wins / g_set[s].trades : 0.0);
      string pf = (g_set[s].gl > 0.0 ? DoubleToString(g_set[s].gp / g_set[s].gl, 2) : "-");
      Print(StringFormat("%-26s | lệnh %4d | thắng %5.1f%% | PF %s | lợi nhuận %10.2f | max DD %6.2f%% | đang mở %d",
                         g_set[s].ten, g_set[s].trades, wr, pf, g_set[s].bal - VonAo_MoiSet, g_set[s].maxDD, DemViThe(s, 0)));
      g_e2[s].Stop();
      g_e4[s].Stop();
     }
   ObjectsDeleteAll(0, OBJ_PREFIX);
  }

void OnTick()
  {
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;
   QuanLyViThe(tk);
   for(int s = 0; s < MAX_SET; s++)
     {
      if(!g_set[s].on) continue;
      if(g_e2[s].on)
        {
         g_e2[s].openCount = DemViThe(s, 2);
         g_e2[s].XuLyTick();
         if(g_e2[s].hasSig && g_e2[s].openCount < g_set[s].maxLenh && DemViThe(s, 0) < 4)
            MoViThe(s, 2, g_e2[s].sigDir, g_e2[s].sigSL, g_e2[s].sigTP, g_e2[s].sigWhy);
        }
      if(g_e4[s].on)
        {
         g_e4[s].openCount = DemViThe(s, 4);
         g_e4[s].XuLyTick();
         if(g_e4[s].hasSig && DemViThe(s, 0) < 4)
            MoViThe(s, 4, g_e4[s].sigDir, g_e4[s].sigSL, g_e4[s].sigTP, g_e4[s].sigWhy);
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
   double tong = 0.0;
   for(int s = 0; s < MAX_SET; s++)
      if(g_set[s].on) tong += g_set[s].bal - VonAo_MoiSet;
   return tong;
  }
//+------------------------------------------------------------------+
