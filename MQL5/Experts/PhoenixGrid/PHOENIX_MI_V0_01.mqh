//+------------------------------------------------------------------+
//|                                           PHOENIX_MI_V0_01.mqh   |
//|                     DAVID HUNTER – PHOENIX GRID – 0941920986     |
//|                                                                  |
//|  PHOENIX MARKET INTELLIGENCE + BREAKOUT DEFENSE CONTROLLER       |
//|  MI V0.01 — TEST 1: SHADOW / LOG ONLY.                           |
//|  Module KHÔNG gửi lệnh, KHÔNG sửa lệnh, KHÔNG can thiệp EA nào.  |
//|  Chỉ đọc giá, chỉ báo, vị thế của basket cần theo dõi, rồi ghi   |
//|  log PMI_V001_<symbol>_d<điểm>n<số nến>[_tester]_<YYYYMMDD>.csv  |
//|  log mỗi nến đóng: trạng thái thị trường, điểm breakout, bằng    |
//|  chứng, và quyết định phòng thủ "sẽ làm" (khóa DCA, tỷ lệ hedge).|
//|  Mọi điều kiện là công thức định lượng, không có yếu tố chủ quan.|
//|  Đặc tả: docs/phoenix_grid/07_MI_BREAKOUT_DEFENSE.md             |
//+------------------------------------------------------------------+
#define PMI_PHIEN_BAN        "MI V0.01 SHADOW"

//--- Tiêu đề log (48 cột)
#define PMI_TIEU_DE "thoi_gian;su_kien;market_state;trend;trend_score;structure;structure_score;bos;range_high;range_low;range_w_atr;breakout_direction;breakout_score;bang_chung;so_nen_ngoai;so_nen_tu_breakout;bb_mid;bb_width;bb_width_atr;bb_squeeze;bb_expand;bb_ngoai;bb_doc;bb_score;fib_dau;fib_cuoi;fib_ratio;fib_zone;nen;momentum_atr;momentum_score;adx;atr;close;basket_direction;basket_buy_volume;basket_sell_volume;basket_volume;net_exposure;hedge_volume;hedge_ratio;hedge_target_ratio;hedge_target_volume;dca_lock;trim_action;defense_state;hedge_context;reason"

//--- Giá trị nội bộ (định lượng, ghi trong đặc tả; chưa đưa ra input để tránh quá nhiều tham số)
#define PMI_ATR_CHU_KY       14
#define PMI_ADX_CHU_KY       14
#define PMI_BB_CHU_KY        20        // Bollinger: MA20
#define PMI_BB_LECH          2.0
#define PMI_EMA_CHU_KY       50        // xu hướng
#define PMI_EMA_DOC          10        // độ dốc EMA đo trên 10 nến
#define PMI_ER_NEN           24        // hiệu suất xu hướng (ER) và độ dốc hồi quy
#define PMI_RANGE_MIN_ATR    1.5       // độ rộng range tối thiểu (× ATR)
#define PMI_ER_MAX           0.30
#define PMI_DOC_MAX          0.05      // độ dốc tối đa khi sideway (ATR mỗi nến)
#define PMI_TAU              0.15      // dung sai chạm biên (× độ rộng range)
#define PMI_CHAM_MIN         2         // số đỉnh / đáy swing tối thiểu sát mỗi biên
#define PMI_H_TRANG_THAI     2         // số nến liên tiếp để nhận / bỏ SIDEWAY (chống nhấp nháy)
#define PMI_CLOSE_ATR        0.10      // close ngoài biên tối thiểu (× ATR)
#define PMI_RECLAIM_W        0.25      // reclaim: close vào trong range ≥ 25% độ rộng tính từ biên bị phá
#define PMI_HET_HAN_NGHI     12        // số nến tối đa ở BREAKOUT SUSPECTED
#define PMI_THEO_DOI_MAX     288       // số nến tối đa theo dõi sau BREAKOUT CONFIRMED
#define PMI_BW_TANG          1.20      // Band Width tăng: BW ≥ 1,2 × BW 3 nến trước
#define PMI_MOM_ATR          1.00      // momentum: (C − C[3]) ≥ 1 ATR theo hướng breakout
#define PMI_THAN_R           0.60      // nến thân mạnh: thân ≥ 60% biên độ ...
#define PMI_THAN_ATR         0.50      // ... và ≥ 0,5 ATR
#define PMI_TIEP_W           1.00      // tiếp diễn mạnh (cấp 2): giá cách biên bị phá ≥ max(1 × độ rộng range, 2 ATR)
#define PMI_TIEP_ATR         2.00
#define PMI_KHOANG_ATR       1.00      // khoảng cách giá tối thiểu giữa 2 lần đổi cấp hedge (× ATR)
#define PMI_NEN_KHOI_DONG    300       // số nến dựng lại trạng thái khi khởi động
#define PMI_SWING_MAX        64

//--- Trạng thái thị trường
enum PMI_TT
  {
   PMI_NORMAL  = 0,
   PMI_SIDEWAY = 1,
   PMI_BO_NGHI = 2,      // BREAKOUT SUSPECTED
   PMI_BO_XN   = 3,      // BREAKOUT CONFIRMED
   PMI_RECLAIM = 4       // giá đã vào lại range sau breakout xác nhận, đang chờ đủ nến
  };

//--- Trạng thái phòng thủ (shadow: chỉ là quyết định "sẽ làm")
enum PMI_PT
  {
   PMI_IDLE     = 0,
   PMI_DEF1     = 1,     // DEFENSE cấp 1: khóa DCA, hedge tỷ lệ ban đầu
   PMI_DEF2     = 2,     // DEFENSE cấp 2: hedge tỷ lệ cấp 2
   PMI_PHUC_HOI = 3      // RECOVERY: tháo hedge có kiểm soát, chờ trở lại NORMAL
  };

//--- Cấu hình do EA truyền vào (chỉ số, không có chuỗi)
struct PMI_CAU_HINH
  {
   ENUM_TIMEFRAMES tf;
   bool            phongThu;       // Breakout Defense
   bool            khoaDCA;        // khóa DCA khi breakout ngược basket
   bool            marketHedge;    // Market Hedge
   double          hedgeTyLe1;     // % exposure basket
   double          hedgeTyLe2;
   int             giuPhut;        // thời gian giữ hedge tối thiểu
   int             cooldownPhut;
   int             diemXacNhan;    // 0..100
   int             soNenXacNhan;
   bool            fib, bb, nen;   // bộ lọc ngữ cảnh
   int             soNenRange;
   double          rangeMaxATR;
   double          rangeADXMax;
   long            magic;          // basket cần theo dõi: 0 = mọi vị thế của symbol
   bool            giaLapBasket;   // Strategy Tester: giả lập basket ngược mỗi breakout xác nhận
   bool            ghiLog;
  };

//--- Số liệu một nến đóng
struct PMI_NEN
  {
   datetime t;
   double   o, h, l, c;
   double   atr, adx, dip, dim, ema, emaTruoc;
   double   bbM, bbU, bbL, bw, bwTruoc3, bwP20;
   bool     bbMo;                  // hai dải cùng mở ra so với nến trước
   int      bbNgoai;               // +1 đóng trên dải trên, −1 đóng dưới dải dưới
   int      bbDoc;                 // +1 / −1 giá chạy dọc dải trên / dưới
   double   mom;                   // (C − C[3]) / ATR
   double   U, L, W;               // hộp giá soNenRange nến
   datetime tHop;                  // giờ mở nến đầu của hộp
   int      tU, tL;
   double   er, beta;
   bool     sideway;
   double   sh1, sh2, sl1, sl2;    // hai đỉnh / đáy swing gần nhất
   string   cauTruc;               // HH / LH - HL / LL
   int      bos;                   // +1 / −1: nến này đóng phá swing gần nhất
   string   nen;                   // mẫu nến
   int      nenHuong;
  };

//+------------------------------------------------------------------+
//| CPhoenixMI                                                       |
//+------------------------------------------------------------------+
class CPhoenixMI
  {
private:
   PMI_CAU_HINH      m_cfg;
   int               m_hATR, m_hADX, m_hEMA, m_hBB;
   double            m_step, m_point;
   int               m_digits;
   datetime          m_nenCuoi;
   bool              m_san;
   //--- swing trong cửa sổ của nến đang xét
   datetime          m_swT[PMI_SWING_MAX];
   double            m_swP[PMI_SWING_MAX];
   int               m_swLoai[PMI_SWING_MAX];
   int               m_swN;
   double            m_rLow[], m_rHigh[];
   datetime          m_rTime[];
   //--- trạng thái thị trường
   PMI_TT            m_tt;
   double            m_rU, m_rL, m_rW;
   int               m_swDem, m_saiDem;
   int               m_boHuong, m_boSoNen, m_ngoai, m_reclaimDem;
   datetime          m_boBatDau, m_xnLuc;
   bool              m_boThanManh;
   int               m_diem;
   string            m_bangChung;
   int               m_tiepDem;
   //--- phòng thủ
   PMI_PT            m_pt;
   datetime          m_ptLuc, m_capLuc, m_cooldownDen;
   double            m_ptGia;
   int               m_giamDem, m_phucHoiDem;
   bool              m_daBaoCooldown;
   int               m_giaLapHuong;
   //--- basket
   int               m_bkHuong;
   double            m_bkBuy, m_bkSell;
   //--- ngữ cảnh / Fib
   double            m_fibDau, m_fibCuoi, m_fibTyLe;
   string            m_fibVung, m_ngucanh, m_lyDo, m_suKien;
   //--- log
   int               m_log;
   string            m_logKy, m_gv, m_nhan;
   bool              m_tester;

   //--- tiện ích
   string            F(const double v)      { return DoubleToString(v, m_digits); }
   string            F2(const double v)     { return DoubleToString(v, 2); }
   double            Kep(const double v, const double a, const double b) { return MathMax(a, MathMin(b, v)); }
   void              SuKien(const string s)  { m_suKien = (m_suKien == "") ? s : m_suKien + "+" + s; }

   void              ThemSwing(const datetime t, const double p, const int loai)
     {
      if(m_swN >= PMI_SWING_MAX)
        {
         for(int i = 1; i < PMI_SWING_MAX; i++)
           {
            m_swT[i - 1] = m_swT[i];
            m_swP[i - 1] = m_swP[i];
            m_swLoai[i - 1] = m_swLoai[i];
           }
         m_swN = PMI_SWING_MAX - 1;
        }
      m_swT[m_swN] = t;
      m_swP[m_swN] = p;
      m_swLoai[m_swN] = loai;
      m_swN++;
     }

   //--- Mẫu nến tại nến k (r theo thứ tự thời gian). Công thức: R biên độ, B thân, UW / LW bấc trên / dưới
   void              NhanDienNen(const MqlRates &r[], const int k, const double atr, string &ten, int &huong)
     {
      ten = "";
      huong = 0;
      double o1 = r[k].open, c1 = r[k].close, h1 = r[k].high, l1 = r[k].low, R = h1 - l1;
      if(R <= 0.0 || atr <= 0.0)
         return;
      double B = MathAbs(c1 - o1), UW = h1 - MathMax(o1, c1), LW = MathMin(o1, c1) - l1;
      double o2 = r[k - 1].open, c2 = r[k - 1].close, B2 = MathAbs(c2 - o2);
      double o3 = r[k - 2].open, c3 = r[k - 2].close, B3 = MathAbs(c3 - o3);
      // Engulfing: nến 1 ngược màu nến 2, thân nến 1 bao trọn thân nến 2 và lớn hơn
      if(c1 > o1 && c2 < o2 && c1 >= o2 && o1 <= c2 && B > B2)
        { ten = "BULLISH_ENGULFING"; huong = 1; return; }
      if(c1 < o1 && c2 > o2 && c1 <= o2 && o1 >= c2 && B > B2)
        { ten = "BEARISH_ENGULFING"; huong = -1; return; }
      // Morning / Evening star: nến 3 thân ≥ 0,5 ATR, nến 2 thân ≤ 50% thân nến 3, nến 1 đóng quá giữa thân nến 3
      if(B3 >= 0.5 * atr && B2 <= 0.5 * B3)
        {
         double giua3 = (o3 + c3) / 2.0;
         if(c3 < o3 && c1 > o1 && c1 > giua3)
           { ten = "MORNING_STAR"; huong = 1; return; }
         if(c3 > o3 && c1 < o1 && c1 < giua3)
           { ten = "EVENING_STAR"; huong = -1; return; }
        }
      // Pin bar / Shooting star: bấc ≥ 60% R, thân ≤ 30% R, bấc còn lại ≤ 20% R
      if(LW >= 0.6 * R && B <= 0.3 * R && UW <= 0.2 * R)
        { ten = "PIN_BAR"; huong = 1; return; }
      if(UW >= 0.6 * R && B <= 0.3 * R && LW <= 0.2 * R)
        { ten = "SHOOTING_STAR"; huong = -1; return; }
      // Rejection: bấc ≥ 45% R và giá đóng ở nửa ngược lại của biên độ
      if(LW >= 0.45 * R && c1 >= l1 + 0.5 * R)
        { ten = "BULLISH_REJECTION"; huong = 1; return; }
      if(UW >= 0.45 * R && c1 <= h1 - 0.5 * R)
        { ten = "BEARISH_REJECTION"; huong = -1; return; }
     }

   //--- Tính mọi số đo của nến tại shift s
   bool              TinhNen(const int s, PMI_NEN &x)
     {
      int nb = m_cfg.soNenRange;
      int N  = MathMax(2 * nb, 100) + 6;
      MqlRates r[];
      if(CopyRates(_Symbol, m_cfg.tf, s, N, r) < N)
         return false;
      int k = N - 1;
      double a[], ad[], dp[], dm[], e[], bm[], bu[], bl[];
      if(CopyBuffer(m_hATR, 0, s, 1, a) < 1 || a[0] <= 0.0 ||
         CopyBuffer(m_hADX, 0, s, 1, ad) < 1 || CopyBuffer(m_hADX, 1, s, 1, dp) < 1 || CopyBuffer(m_hADX, 2, s, 1, dm) < 1 ||
         CopyBuffer(m_hEMA, 0, s, PMI_EMA_DOC + 1, e) < PMI_EMA_DOC + 1 || CopyBuffer(m_hBB, 0, s, 1, bm) < 1 ||
         CopyBuffer(m_hBB, 1, s, 100, bu) < 100 || CopyBuffer(m_hBB, 2, s, 100, bl) < 100)
         return false;
      x.t = r[k].time;
      x.o = r[k].open;
      x.h = r[k].high;
      x.l = r[k].low;
      x.c = r[k].close;
      x.atr = a[0];
      x.adx = ad[0];
      x.dip = dp[0];
      x.dim = dm[0];
      x.ema = e[PMI_EMA_DOC];
      x.emaTruoc = e[0];
      // Bollinger (mảng theo thứ tự thời gian: phần tử 99 là nến đang xét)
      x.bbM = bm[0];
      x.bbU = bu[99];
      x.bbL = bl[99];
      x.bw  = bu[99] - bl[99];
      x.bwTruoc3 = bu[96] - bl[96];
      double w[100];
      for(int i = 0; i < 100; i++)
         w[i] = bu[i] - bl[i];
      ArraySort(w);
      x.bwP20 = w[19];
      x.bbMo = (bu[99] > bu[98] && bl[99] < bl[98]);
      x.bbNgoai = (x.c > x.bbU) ? 1 : ((x.c < x.bbL) ? -1 : 0);
      int len = 0, xuong = 0;
      for(int i = 0; i < 5; i++)
        {
         double c = r[k - i].close, up = bu[99 - i], lo = bl[99 - i], giua = (up + lo) / 2.0;
         if(c >= giua + 0.8 * (up - giua))
            len++;
         if(c <= giua - 0.8 * (giua - lo))
            xuong++;
        }
      x.bbDoc = (len >= 3) ? 1 : ((xuong >= 3) ? -1 : 0);
      x.mom = (r[k].close - r[k - 3].close) / x.atr;
      // hộp giá nb nến cuối
      int dau = N - nb;
      x.U = r[dau].high;
      x.L = r[dau].low;
      for(int i = dau + 1; i < N; i++)
        {
         x.U = MathMax(x.U, r[i].high);
         x.L = MathMin(x.L, r[i].low);
        }
      x.W = x.U - x.L;
      x.tHop = r[dau].time;
      // swing (fractal 2 nến mỗi bên) trên cả cửa sổ; chạm biên chỉ tính trong hộp
      m_swN = 0;
      x.tU = 0;
      x.tL = 0;
      for(int i = 2; i <= N - 3; i++)
        {
         bool dinh = r[i].high > r[i - 1].high && r[i].high > r[i - 2].high && r[i].high >= r[i + 1].high && r[i].high >= r[i + 2].high;
         bool day  = r[i].low < r[i - 1].low && r[i].low < r[i - 2].low && r[i].low <= r[i + 1].low && r[i].low <= r[i + 2].low;
         if(dinh)
           {
            ThemSwing(r[i].time, r[i].high, 1);
            if(i >= dau && r[i].high >= x.U - PMI_TAU * x.W)
               x.tU++;
           }
         if(day)
           {
            ThemSwing(r[i].time, r[i].low, -1);
            if(i >= dau && r[i].low <= x.L + PMI_TAU * x.W)
               x.tL++;
           }
        }
      // ER và độ dốc hồi quy trên PMI_ER_NEN nến
      int ne = PMI_ER_NEN;
      double tuSo = MathAbs(r[k].close - r[k - ne].close), mauSo = 0.0;
      for(int i = N - ne; i < N; i++)
         mauSo += MathAbs(r[i].close - r[i - 1].close);
      x.er = (mauSo > 0.0) ? tuSo / mauSo : 0.0;
      double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
      for(int j = 0; j < ne; j++)
        {
         double xv = j, yv = r[N - ne + j].close;
         sx += xv;
         sy += yv;
         sxx += xv * xv;
         sxy += xv * yv;
        }
      double md = ne * sxx - sx * sx;
      x.beta = (md != 0.0) ? ((ne * sxy - sx * sy) / md) / x.atr : 0.0;
      double wAtr = x.W / x.atr;
      x.sideway = wAtr >= PMI_RANGE_MIN_ATR && wAtr <= m_cfg.rangeMaxATR && x.adx < m_cfg.rangeADXMax &&
                  x.er < PMI_ER_MAX && x.tU >= PMI_CHAM_MIN && x.tL >= PMI_CHAM_MIN && MathAbs(x.beta) < PMI_DOC_MAX;
      // cấu trúc: hai đỉnh và hai đáy swing gần nhất
      x.sh1 = 0.0;
      x.sh2 = 0.0;
      x.sl1 = 0.0;
      x.sl2 = 0.0;
      for(int j = m_swN - 1; j >= 0; j--)
        {
         if(m_swLoai[j] > 0)
           {
            if(x.sh1 == 0.0)
               x.sh1 = m_swP[j];
            else
               if(x.sh2 == 0.0)
                  x.sh2 = m_swP[j];
           }
         else
           {
            if(x.sl1 == 0.0)
               x.sl1 = m_swP[j];
            else
               if(x.sl2 == 0.0)
                  x.sl2 = m_swP[j];
           }
        }
      string sH = (x.sh1 > 0.0 && x.sh2 > 0.0) ? ((x.sh1 > x.sh2) ? "HH" : "LH") : "?";
      string sL = (x.sl1 > 0.0 && x.sl2 > 0.0) ? ((x.sl1 > x.sl2) ? "HL" : "LL") : "?";
      x.cauTruc = sH + "-" + sL;
      x.bos = 0;
      if(x.sh1 > 0.0 && r[k].close > x.sh1 && r[k - 1].close <= x.sh1)
         x.bos = 1;
      if(x.sl1 > 0.0 && r[k].close < x.sl1 && r[k - 1].close >= x.sl1)
         x.bos = -1;
      NhanDienNen(r, k, x.atr, x.nen, x.nenHuong);
      // giữ giá cao / thấp của cửa sổ cho Fib nhịp breakout
      ArrayResize(m_rLow, N);
      ArrayResize(m_rHigh, N);
      ArrayResize(m_rTime, N);
      for(int i = 0; i < N; i++)
        {
         m_rLow[i] = r[i].low;
         m_rHigh[i] = r[i].high;
         m_rTime[i] = r[i].time;
        }
      return true;
     }

   //--- Điểm của các thành phần (−100…+100, dương = nghiêng tăng)
   int               DiemXuHuong(const PMI_NEN &x) { return ((x.c > x.ema) ? 50 : -50) + ((x.ema > x.emaTruoc) ? 50 : -50); }
   int               DiemCauTruc(const PMI_NEN &x)
     {
      int d = 0;
      if(StringFind(x.cauTruc, "HH") == 0)
         d += 50;
      if(StringFind(x.cauTruc, "LH") == 0)
         d -= 50;
      if(StringFind(x.cauTruc, "HL") > 0)
         d += 50;
      if(StringFind(x.cauTruc, "LL") > 0)
         d -= 50;
      return d;
     }
   int               DiemMomentum(const PMI_NEN &x) { return (int)MathRound(Kep(x.mom * 50.0, -100.0, 100.0)); }
   int               DiemBB(const PMI_NEN &x)
     {
      double nua = (x.bbU - x.bbM);
      return (nua > 0.0) ? (int)MathRound(Kep((x.c - x.bbM) / nua * 100.0, -100.0, 100.0)) : 0;
     }
   string            TenXuHuong(const PMI_NEN &x)
     {
      int d = DiemXuHuong(x);
      return (d >= 100) ? "TANG" : ((d <= -100) ? "GIAM" : "HON_HOP");
     }

   bool              Ngoai(const PMI_NEN &x, const int d)
     {
      return (d > 0) ? (x.c > m_rU + PMI_CLOSE_ATR * x.atr) : (x.c < m_rL - PMI_CLOSE_ATR * x.atr);
     }
   bool              ReclaimSau(const PMI_NEN &x, const int d)
     {
      return (d > 0) ? (x.c <= m_rU - PMI_RECLAIM_W * m_rW) : (x.c >= m_rL + PMI_RECLAIM_W * m_rW);
     }
   bool              TrongRange(const PMI_NEN &x) { return x.c <= m_rU && x.c >= m_rL; }
   bool              ThanManh(const PMI_NEN &x, const int d)
     {
      double R = x.h - x.l, B = (x.c - x.o) * d;
      return R > 0.0 && B >= PMI_THAN_R * R && B >= PMI_THAN_ATR * x.atr;
     }

   //--- Điểm breakout 0–100 theo hướng d, bằng chứng ghi thành chuỗi
   int               DiemBreakout(const PMI_NEN &x, const int d, string &bc)
     {
      int diem = 0, tong = 0;
      bc = "";
      tong += 20;
      if(Ngoai(x, d))
        {
         diem += 20;
         bc += "CLOSE_NGOAI ";
        }
      // phá swing quan trọng: swing cao nhất (thấp nhất) của cửa sổ, hình thành trước lúc nghi vấn breakout
      double sw = (d > 0) ? m_rU : m_rL;
      for(int j = 0; j < m_swN; j++)
         if(m_swT[j] < m_boBatDau && m_swLoai[j] == d)
            sw = (d > 0) ? MathMax(sw, m_swP[j]) : MathMin(sw, m_swP[j]);
      tong += 15;
      if((d > 0 && x.c > sw) || (d < 0 && x.c < sw))
        {
         diem += 15;
         bc += "PHA_SWING ";
        }
      if(m_cfg.bb)
        {
         tong += 25;
         if(x.bwTruoc3 > 0.0 && x.bw >= PMI_BW_TANG * x.bwTruoc3)
           {
            diem += 15;
            bc += "BW_TANG ";
           }
         if(x.bbMo && x.bbNgoai == d)
           {
            diem += 10;
            bc += "BAND_MO ";
           }
        }
      tong += 15;
      if(x.mom * d >= PMI_MOM_ATR && ((d > 0) ? x.dip > x.dim : x.dim > x.dip))
        {
         diem += 15;
         bc += "MOMENTUM ";
        }
      tong += 10;
      if(m_boThanManh)
        {
         diem += 10;
         bc += "THAN_MANH ";
        }
      tong += 15;
      if(m_ngoai >= m_cfg.soNenXacNhan)
        {
         diem += 15;
         bc += "KHONG_RECLAIM ";
        }
      StringTrimRight(bc);
      return (tong > 0) ? (int)MathRound(diem * 100.0 / tong) : 0;
     }

   //--- Fib: nhịp breakout khi đang có breakout, ngược lại là nhịp swing gần nhất
   void              TinhFib(const PMI_NEN &x)
     {
      m_fibDau = 0.0;
      m_fibCuoi = 0.0;
      m_fibTyLe = -1.0;
      m_fibVung = "";
      int d = m_boHuong;
      if(d != 0)
        {
         // điểm đầu: swing ngược chiều gần nhất trước lúc nghi vấn (không có thì lấy biên đối diện của range)
         double dau = (d < 0) ? m_rU : m_rL;
         for(int j = m_swN - 1; j >= 0; j--)
            if(m_swT[j] <= m_boBatDau && m_swLoai[j] == -d)
              {
               dau = m_swP[j];
               break;
              }
         // điểm cuối: cực trị theo hướng breakout kể từ lúc nghi vấn
         double cuoi = (d < 0) ? x.l : x.h;
         for(int i = 0; i < ArraySize(m_rTime); i++)
            if(m_rTime[i] >= m_boBatDau)
               cuoi = (d < 0) ? MathMin(cuoi, m_rLow[i]) : MathMax(cuoi, m_rHigh[i]);
         m_fibDau = dau;
         m_fibCuoi = cuoi;
        }
      else
        {
         int j1 = m_swN - 1;
         if(j1 < 1)
            return;
         int j0 = -1;
         for(int j = j1 - 1; j >= 0; j--)
            if(m_swLoai[j] != m_swLoai[j1])
              {
               j0 = j;
               break;
              }
         if(j0 < 0)
            return;
         m_fibDau = m_swP[j0];
         m_fibCuoi = m_swP[j1];
        }
      double song = MathAbs(m_fibCuoi - m_fibDau);
      if(song <= 0.0)
         return;
      // tỷ lệ hồi tính từ điểm cuối: 0 = tại điểm cuối, 1 = về điểm đầu, âm = vượt điểm cuối (mở rộng)
      m_fibTyLe = (m_fibCuoi > m_fibDau) ? (m_fibCuoi - x.c) / song : (x.c - m_fibCuoi) / song;
      double r = m_fibTyLe;
      if(r < 0.0)
         m_fibVung = (1.0 - r >= 1.618) ? "EXT_161.8+" : ((1.0 - r >= 1.272) ? "EXT_127.2-161.8" : "EXT_100-127.2");
      else
         if(r < 0.382)
            m_fibVung = "0-38.2";
         else
            if(r < 0.5)
               m_fibVung = "38.2-50";
            else
               if(r <= 0.618)
                  m_fibVung = "50-61.8";
               else
                  if(r <= 0.786)
                     m_fibVung = "61.8-78.6";
                  else
                     m_fibVung = (r <= 1.0) ? "78.6-100" : "VUOT_100";
     }

   //--- Ngữ cảnh hedge khi đang phòng thủ (basket ngược breakout). GIU / GIAM / TRUNG_TINH
   string            NguCanhHedge(const PMI_NEN &x)
     {
      int d = m_boHuong;                    // hướng breakout = hướng hedge
      if(d == 0 || m_fibTyLe < 0.0)
         return "TRUNG_TINH";
      // GIỮ hedge: giá hồi về vùng Fib 50–61,8% (dung sai 0,05) + tới dải giữa / dải ngược + nến từ chối theo hướng breakout
      bool fibGiu = !m_cfg.fib || (m_fibTyLe >= 0.45 && m_fibTyLe <= 0.668);
      bool bbGiu  = !m_cfg.bb || ((d < 0) ? x.h >= x.bbM - 0.1 * x.atr : x.l <= x.bbM + 0.1 * x.atr);
      bool nenGiu = !m_cfg.nen || x.nenHuong == d;
      if(fibGiu && bbGiu && nenGiu && (m_cfg.fib || m_cfg.bb || m_cfg.nen))
         return "GIU";
      // GIẢM hedge: giá hồi quá 78,6% nhịp breakout hoặc đóng qua swing gần nhất ngược chiều + nến ngược hướng breakout
      bool fibGiam = m_fibTyLe > 0.786;
      bool cauTruc = (d < 0) ? (x.sh1 > 0.0 && x.c > x.sh1) : (x.sl1 > 0.0 && x.c < x.sl1);
      bool nenGiam = !m_cfg.nen || x.nenHuong == -d;
      if((fibGiam || cauTruc) && nenGiam)
         return "GIAM";
      return "TRUNG_TINH";
     }

   //--- Chuyển trạng thái thị trường theo nến vừa đóng
   void              XuLyThiTruong(const PMI_NEN &x)
     {
      switch(m_tt)
        {
         case PMI_NORMAL:
            m_swDem = x.sideway ? m_swDem + 1 : 0;
            if(m_swDem >= PMI_H_TRANG_THAI)
              {
               m_tt = PMI_SIDEWAY;
               m_rU = x.U;
               m_rL = x.L;
               m_rW = x.W;
               m_saiDem = 0;
               SuKien("SIDEWAY_BAT_DAU");
               m_lyDo = "Hộp " + IntegerToString(m_cfg.soNenRange) + " nến đạt điều kiện sideway " + IntegerToString(PMI_H_TRANG_THAI) + " nến liên tiếp";
              }
            break;
         case PMI_SIDEWAY:
           {
            int d = Ngoai(x, 1) ? 1 : (Ngoai(x, -1) ? -1 : 0);
            if(d != 0)
              {
               m_tt = PMI_BO_NGHI;
               m_boHuong = d;
               m_boBatDau = x.t;
               m_boSoNen = 1;
               m_ngoai = 1;
               m_boThanManh = ThanManh(x, d);
               SuKien("BO_NGHI_VAN");
               m_lyDo = "Close " + F(x.c) + ((d > 0) ? " > biên trên " + F(m_rU) : " < biên dưới " + F(m_rL)) + " + 0,1 ATR";
               break;
              }
            if(x.sideway)
              {
               m_rU = x.U;
               m_rL = x.L;
               m_rW = x.W;
               m_saiDem = 0;
              }
            else
              {
               m_saiDem++;
               if(m_saiDem >= PMI_H_TRANG_THAI)
                 {
                  m_tt = PMI_NORMAL;
                  m_swDem = 0;
                  SuKien("SIDEWAY_KET_THUC");
                  m_lyDo = "Hộp không còn điều kiện sideway " + IntegerToString(PMI_H_TRANG_THAI) + " nến liên tiếp, không có breakout";
                 }
              }
            break;
           }
         case PMI_BO_NGHI:
            m_boSoNen++;
            m_ngoai = Ngoai(x, m_boHuong) ? m_ngoai + 1 : 0;
            if(Ngoai(x, m_boHuong) && ThanManh(x, m_boHuong))
               m_boThanManh = true;
            if(ReclaimSau(x, m_boHuong))
              {
               m_tt = PMI_SIDEWAY;
               m_saiDem = 0;
               SuKien("BO_THAT_BAI");
               m_lyDo = "Breakout giả: close " + F(x.c) + " quay vào range ≥ 25% độ rộng";
               KetThucBreakout();
               break;
              }
            m_diem = DiemBreakout(x, m_boHuong, m_bangChung);
            if(m_diem >= m_cfg.diemXacNhan && m_ngoai >= m_cfg.soNenXacNhan)
              {
               m_tt = PMI_BO_XN;
               m_xnLuc = x.t;
               m_tiepDem = 0;
               SuKien("BO_XAC_NHAN");
               m_lyDo = "Điểm " + IntegerToString(m_diem) + " ≥ " + IntegerToString(m_cfg.diemXacNhan) + ", " +
                        IntegerToString(m_ngoai) + " nến đóng ngoài range";
               break;
              }
            if(m_boSoNen >= PMI_HET_HAN_NGHI)
              {
               bool trong = TrongRange(x);
               m_tt = trong ? PMI_SIDEWAY : PMI_NORMAL;
               SuKien(trong ? "BO_HET_HAN_VE_RANGE" : "BO_HET_HAN");
               m_lyDo = IntegerToString(PMI_HET_HAN_NGHI) + " nến chưa đủ bằng chứng xác nhận (điểm " + IntegerToString(m_diem) + ")";
               KetThucBreakout();
               if(!trong)
                  m_swDem = 0;
              }
            break;
         case PMI_BO_XN:
            m_boSoNen++;
            m_ngoai = Ngoai(x, m_boHuong) ? m_ngoai + 1 : 0;
            m_diem = DiemBreakout(x, m_boHuong, m_bangChung);
            if(ReclaimSau(x, m_boHuong))
              {
               m_tt = PMI_RECLAIM;
               m_reclaimDem = 1;
               SuKien("RECLAIM_BAT_DAU");
               m_lyDo = "Close " + F(x.c) + " vào lại range ≥ 25% độ rộng sau breakout xác nhận";
               break;
              }
            if(x.sideway && x.tHop >= m_boBatDau)
              {
               m_tt = PMI_SIDEWAY;
               m_rU = x.U;
               m_rL = x.L;
               m_rW = x.W;
               m_saiDem = 0;
               SuKien("VUNG_MOI");
               m_lyDo = "Range mới hình thành hoàn toàn sau breakout: " + F(x.L) + " – " + F(x.U);
               KetThucBreakout();
               break;
              }
            if(m_boSoNen >= PMI_THEO_DOI_MAX)
              {
               m_tt = PMI_NORMAL;
               m_swDem = 0;
               SuKien("BO_HET_THEO_DOI");
               m_lyDo = IntegerToString(PMI_THEO_DOI_MAX) + " nến sau breakout chưa có range mới";
               KetThucBreakout();
              }
            break;
         case PMI_RECLAIM:
            m_boSoNen++;
            if(Ngoai(x, m_boHuong))
              {
               m_tt = PMI_BO_XN;
               m_ngoai = 1;
               SuKien("RECLAIM_THAT_BAI");
               m_lyDo = "Giá đóng lại ngoài biên theo hướng breakout";
               m_diem = DiemBreakout(x, m_boHuong, m_bangChung);
               break;
              }
            if(Ngoai(x, -m_boHuong))
              {
               // giá xuyên qua cả range sang phía đối diện: breakout cũ kết thúc, nghi vấn breakout ngược chiều
               int d = -m_boHuong;
               SuKien("RECLAIM_XAC_NHAN");
               KetThucBreakout();
               m_tt = PMI_BO_NGHI;
               m_boHuong = d;
               m_boBatDau = x.t;
               m_boSoNen = 1;
               m_ngoai = 1;
               m_boThanManh = ThanManh(x, d);
               SuKien("BO_NGHI_VAN");
               m_lyDo = "Giá xuyên qua range sang biên đối diện: nghi vấn breakout " + ((d > 0) ? "TĂNG" : "GIẢM");
               break;
              }
            m_reclaimDem = TrongRange(x) ? m_reclaimDem + 1 : m_reclaimDem;
            if(m_reclaimDem >= m_cfg.soNenXacNhan + 1)
              {
               m_tt = PMI_SIDEWAY;
               m_saiDem = 0;
               SuKien("RECLAIM_XAC_NHAN");
               m_lyDo = IntegerToString(m_reclaimDem) + " nến ở trong range: giá đã reclaim range";
               KetThucBreakout();
              }
            else
               if(m_boSoNen >= PMI_THEO_DOI_MAX)
                 {
                  m_tt = PMI_NORMAL;
                  m_swDem = 0;
                  SuKien("BO_HET_THEO_DOI");
                  m_lyDo = IntegerToString(PMI_THEO_DOI_MAX) + " nến sau breakout chưa reclaim xong, chưa có range mới";
                  KetThucBreakout();
                 }
            break;
        }
     }

   void              KetThucBreakout()
     {
      m_boHuong = 0;
      m_boSoNen = 0;
      m_ngoai = 0;
      m_reclaimDem = 0;
      m_boThanManh = false;
      m_boBatDau = 0;
      m_diem = 0;
      m_bangChung = "";
     }

   //--- Basket cần theo dõi: tổng lot BUY / SELL của symbol (lọc magic nếu có)
   void              DocBasket()
     {
      m_bkBuy = 0.0;
      m_bkSell = 0.0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong tk = PositionGetTicket(i);
         if(tk == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(m_cfg.magic != 0 && PositionGetInteger(POSITION_MAGIC) != m_cfg.magic)
            continue;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            m_bkBuy += PositionGetDouble(POSITION_VOLUME);
         else
            m_bkSell += PositionGetDouble(POSITION_VOLUME);
        }
      m_bkHuong = (m_bkBuy > m_bkSell + 1e-9) ? 1 : ((m_bkSell > m_bkBuy + 1e-9) ? -1 : 0);
      // Strategy Tester không có basket thật: giả lập basket ngược mỗi breakout xác nhận để kiểm tra luồng phòng thủ
      if(m_bkHuong == 0 && m_cfg.giaLapBasket)
        {
         if(m_pt == PMI_IDLE)
            m_giaLapHuong = (m_tt == PMI_BO_XN) ? -m_boHuong : 0;
         m_bkHuong = m_giaLapHuong;
         if(m_bkHuong > 0)
            m_bkBuy = 0.10;
         if(m_bkHuong < 0)
            m_bkSell = 0.10;
        }
     }

   double            TyLeMucTieu()
     {
      if(!m_cfg.marketHedge)
         return 0.0;
      if(m_pt == PMI_DEF1)
         return m_cfg.hedgeTyLe1;
      if(m_pt == PMI_DEF2)
         return m_cfg.hedgeTyLe2;
      return 0.0;
     }

   double            LotMucTieu()
     {
      double vol = (m_bkHuong > 0) ? m_bkBuy : ((m_bkHuong < 0) ? m_bkSell : 0.0);
      double v = vol * TyLeMucTieu() / 100.0;
      if(m_step > 0.0)
         v = MathFloor(v / m_step + 1e-7) * m_step;
      return v;
     }

   //--- Bộ điều phối phòng thủ (shadow): quyết định "sẽ làm", có xác nhận, trễ, giữ tối thiểu, cooldown, khoảng cách
   void              XuLyPhongThu(const PMI_NEN &x)
     {
      m_ngucanh = (m_pt == PMI_DEF1 || m_pt == PMI_DEF2) ? NguCanhHedge(x) : "";
      if(!m_cfg.phongThu)
         return;
      bool nguoc = (m_bkHuong != 0 && m_boHuong == -m_bkHuong);
      long daGiu = (long)(x.t - m_ptLuc);
      long giu = (long)m_cfg.giuPhut * 60;
      switch(m_pt)
        {
         case PMI_IDLE:
            if(m_tt == PMI_BO_XN && nguoc)
              {
               if(x.t < m_cooldownDen)
                 {
                  if(!m_daBaoCooldown)
                    {
                     SuKien("DEF_CHAN_COOLDOWN");
                     m_lyDo = "Breakout xác nhận ngược basket nhưng đang cooldown tới " + TimeToString(m_cooldownDen, TIME_DATE | TIME_MINUTES);
                     m_daBaoCooldown = true;
                    }
                  break;
                 }
               m_pt = PMI_DEF1;
               m_ptLuc = x.t;
               m_capLuc = x.t;
               m_ptGia = x.c;
               m_giamDem = 0;
               SuKien("DEF_BAT_DAU");
               m_lyDo = "Breakout " + ((m_boHuong > 0) ? "TĂNG" : "GIẢM") + " xác nhận ngược basket " + ((m_bkHuong > 0) ? "BUY" : "SELL") +
                        ": khóa DCA, hedge " + DoubleToString(m_cfg.hedgeTyLe1, 0) + "%";
               LuuTrangThai();
              }
            break;
         case PMI_DEF1:
         case PMI_DEF2:
           {
            if(m_bkHuong == 0)
              {
               m_pt = PMI_IDLE;
               SuKien("DEF_HUY");
               m_lyDo = "Basket đã đóng";
               LuuTrangThai();
               break;
              }
            // breakout ngược basket đã hết: giá reclaim range, hoặc breakout mới cùng hướng basket
            bool reclaim = (m_tt == PMI_SIDEWAY || m_tt == PMI_NORMAL || (m_boHuong != 0 && m_boHuong == m_bkHuong));
            if(reclaim)
              {
               if(daGiu >= giu)
                 {
                  m_pt = PMI_PHUC_HOI;
                  m_phucHoiDem = 0;
                  SuKien("DEF_PHUC_HOI");
                  m_lyDo = "Breakout thất bại / reclaim range, đã giữ " + IntegerToString(daGiu / 60) + " phút: tháo hedge có kiểm soát";
                  LuuTrangThai();
                 }
               else
                  m_lyDo = "Reclaim nhưng chưa đủ thời gian giữ tối thiểu (" + IntegerToString(daGiu / 60) + "/" + IntegerToString(m_cfg.giuPhut) + " phút)";
               break;
              }
            bool xa = MathAbs(x.c - m_ptGia) >= PMI_KHOANG_ATR * x.atr;
            bool duGiuCap = (long)(x.t - m_capLuc) >= giu;
            if(m_pt == PMI_DEF1)
              {
               double bien = (m_boHuong > 0) ? m_rU : m_rL;
               bool tiep = m_tt == PMI_BO_XN && (x.c - bien) * m_boHuong >= MathMax(PMI_TIEP_W * m_rW, PMI_TIEP_ATR * x.atr) &&
                           m_diem >= m_cfg.diemXacNhan;
               m_tiepDem = tiep ? m_tiepDem + 1 : 0;
               if(m_tiepDem >= m_cfg.soNenXacNhan && duGiuCap && xa)
                 {
                  m_pt = PMI_DEF2;
                  m_capLuc = x.t;
                  m_ptGia = x.c;
                  m_giamDem = 0;
                  SuKien("DEF_CAP_2");
                  m_lyDo = "Trend tiếp diễn: giá cách biên bị phá ≥ max(1 × range, 2 ATR) " + IntegerToString(m_tiepDem) +
                           " nến, hedge " + DoubleToString(m_cfg.hedgeTyLe2, 0) + "%";
                  LuuTrangThai();
                 }
              }
            else
              {
               m_giamDem = (m_ngucanh == "GIAM") ? m_giamDem + 1 : 0;
               if(m_giamDem >= m_cfg.soNenXacNhan && duGiuCap && xa)
                 {
                  m_pt = PMI_DEF1;
                  m_capLuc = x.t;
                  m_ptGia = x.c;
                  m_tiepDem = 0;
                  SuKien("DEF_GIAM_CAP");
                  m_lyDo = "Ngữ cảnh GIẢM " + IntegerToString(m_giamDem) + " nến (Fib > 78,6% hoặc phá swing ngược + nến ngược): về hedge " +
                           DoubleToString(m_cfg.hedgeTyLe1, 0) + "%";
                  LuuTrangThai();
                 }
              }
            break;
           }
         case PMI_PHUC_HOI:
            if(m_tt == PMI_BO_XN && nguoc)
              {
               m_pt = PMI_DEF1;
               m_ptLuc = x.t;
               m_capLuc = x.t;
               m_ptGia = x.c;
               SuKien("DEF_TAI_KICH_HOAT");
               m_lyDo = "Breakout xác nhận lại ngược basket trong lúc phục hồi";
               LuuTrangThai();
               break;
              }
            m_phucHoiDem++;
            if(m_bkHuong == 0 || m_phucHoiDem >= m_cfg.soNenXacNhan)
              {
               m_pt = PMI_IDLE;
               m_cooldownDen = (datetime)((long)x.t + (long)m_cfg.cooldownPhut * 60);
               m_daBaoCooldown = false;
               SuKien("DEF_KET_THUC");
               m_lyDo = "Trở lại NORMAL, cooldown " + IntegerToString(m_cfg.cooldownPhut) + " phút";
               LuuTrangThai();
              }
            break;
        }
     }

   //--- Lưu / đọc trạng thái phòng thủ (trạng thái thị trường được dựng lại từ lịch sử nến khi khởi động)
   void              LuuTrangThai()
     {
      if(m_tester || m_gv == "")
         return;
      GlobalVariableSet(m_gv + "pt", (double)m_pt);
      GlobalVariableSet(m_gv + "pt_luc", (double)m_ptLuc);
      GlobalVariableSet(m_gv + "cap_luc", (double)m_capLuc);
      GlobalVariableSet(m_gv + "pt_gia", m_ptGia);
      GlobalVariableSet(m_gv + "cooldown", (double)m_cooldownDen);
      GlobalVariableSet(m_gv + "luu_luc", (double)TimeCurrent());
      GlobalVariablesFlush();
     }

   void              DocTrangThai()
     {
      if(m_tester || m_gv == "" || !GlobalVariableCheck(m_gv + "pt"))
         return;
      m_pt          = (PMI_PT)(int)GlobalVariableGet(m_gv + "pt");
      m_ptLuc       = (datetime)(long)GlobalVariableGet(m_gv + "pt_luc");
      m_capLuc      = (datetime)(long)GlobalVariableGet(m_gv + "cap_luc");
      m_ptGia       = GlobalVariableGet(m_gv + "pt_gia");
      m_cooldownDen = (datetime)(long)GlobalVariableGet(m_gv + "cooldown");
     }

   //--- Log: PMI_V001_<symbol>[_tester]_<YYYYMMDD>.csv trong Common\Files\<thư mục>
   void              GhiDong(const PMI_NEN &x, const string thuMuc)
     {
      if(!m_cfg.ghiLog || (bool)MQLInfoInteger(MQL_OPTIMIZATION))
         return;
      MqlDateTime dt;
      TimeToStruct(x.t, dt);
      string ky = StringFormat("%04d%02d%02d", dt.year, dt.mon, dt.day);
      if(m_log == INVALID_HANDLE || ky != m_logKy)
        {
         if(m_log != INVALID_HANDLE)
            FileClose(m_log);
         string ten = thuMuc + "\\PMI_V001_" + _Symbol + "_" + m_nhan + (m_tester ? "_tester_" : "_") + ky + ".csv";
         int co = FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ;
         if(!m_tester)
            co |= FILE_READ;
         m_log = FileOpen(ten, co, ';', CP_UTF8);
         if(m_log == INVALID_HANDLE)
           {
            PrintFormat("PMI: không mở được log %s (lỗi %d)", ten, GetLastError());
            return;
           }
         if(FileSize(m_log) == 0)
            FileWriteString(m_log, PMI_TIEU_DE + "\r\n");
         FileSeek(m_log, 0, SEEK_END);
         m_logKy = ky;
        }
      bool coRange = (m_tt != PMI_NORMAL);
      double hedgeTyLe = TyLeMucTieu();
      string s1 = StringFormat("%s;%s;%s;%s;%d;%s;%d;%d;%s;%s;%s;%s;%d;%s;%d;%d",
                               TimeToString(x.t, TIME_DATE | TIME_MINUTES), (m_suKien == "") ? "NEN" : m_suKien, TenTT(),
                               TenXuHuong(x), DiemXuHuong(x), x.cauTruc, DiemCauTruc(x), x.bos,
                               coRange ? F(m_rU) : "", coRange ? F(m_rL) : "", coRange ? F2(m_rW / x.atr) : "",
                               (m_boHuong > 0) ? "TANG" : ((m_boHuong < 0) ? "GIAM" : ""), m_diem, m_bangChung, m_ngoai, m_boSoNen);
      string s2 = StringFormat("%s;%s;%s;%d;%d;%d;%d;%d;%s;%s;%s;%s;%s;%s;%d;%s;%s",
                               F(x.bbM), F(x.bw), F2(x.bw / x.atr), (x.bw <= x.bwP20) ? 1 : 0, x.bbMo ? 1 : 0, x.bbNgoai, x.bbDoc, DiemBB(x),
                               (m_fibTyLe >= 0.0 || m_fibVung != "") ? F(m_fibDau) : "", (m_fibTyLe >= 0.0 || m_fibVung != "") ? F(m_fibCuoi) : "",
                               (m_fibVung != "") ? DoubleToString(m_fibTyLe, 3) : "", m_fibVung, x.nen, F2(x.mom), DiemMomentum(x),
                               F2(x.adx), DoubleToString(x.atr, 3));
      string s3 = StringFormat("%s;%s;%s;%s;%s;%s;%s;%s;%s;%s;%d;%s;%s;%s;%s",
                               F(x.c), (m_bkHuong > 0) ? "BUY" : ((m_bkHuong < 0) ? "SELL" : ""),
                               DoubleToString(m_bkBuy, 2), DoubleToString(m_bkSell, 2), DoubleToString(MathMax(m_bkBuy, m_bkSell), 2),
                               DoubleToString(m_bkBuy - m_bkSell, 2), "0.00", "0", DoubleToString(hedgeTyLe, 0),
                               DoubleToString(LotMucTieu(), 2), (m_cfg.khoaDCA && (m_pt == PMI_DEF1 || m_pt == PMI_DEF2)) ? 1 : 0,
                               "SHADOW_KHONG_TIA", TenPT(), m_ngucanh, m_lyDo);
      FileWriteString(m_log, s1 + ";" + s2 + ";" + s3 + "\r\n");
      FileFlush(m_log);
     }

public:
                     CPhoenixMI()
     {
      m_hATR = INVALID_HANDLE;
      m_hADX = INVALID_HANDLE;
      m_hEMA = INVALID_HANDLE;
      m_hBB = INVALID_HANDLE;
      m_log = INVALID_HANDLE;
      DatLai();
     }

   void              DatLai()
     {
      m_nenCuoi = 0;
      m_san = false;
      m_swN = 0;
      m_tt = PMI_NORMAL;
      m_rU = 0.0;
      m_rL = 0.0;
      m_rW = 0.0;
      m_swDem = 0;
      m_saiDem = 0;
      KetThucBreakout();
      m_xnLuc = 0;
      m_tiepDem = 0;
      m_pt = PMI_IDLE;
      m_ptLuc = 0;
      m_capLuc = 0;
      m_cooldownDen = 0;
      m_ptGia = 0.0;
      m_giamDem = 0;
      m_phucHoiDem = 0;
      m_daBaoCooldown = false;
      m_giaLapHuong = 0;
      m_bkHuong = 0;
      m_bkBuy = 0.0;
      m_bkSell = 0.0;
      m_fibDau = 0.0;
      m_fibCuoi = 0.0;
      m_fibTyLe = -1.0;
      m_fibVung = "";
      m_ngucanh = "";
      m_lyDo = "";
      m_suKien = "";
      m_logKy = "";
     }

   bool              Init(const PMI_CAU_HINH &cfg)
     {
      DatLai();
      m_cfg = cfg;
      m_tester = (bool)MQLInfoInteger(MQL_TESTER);
      m_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      m_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      m_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      // nhãn cấu hình: nhiều chart shadow với ngưỡng khác nhau không ghi đè log / trạng thái của nhau
      m_nhan = "d" + IntegerToString(m_cfg.diemXacNhan) + "n" + IntegerToString(m_cfg.soNenXacNhan);
      m_gv = "PMI_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + _Symbol + "_" + IntegerToString(m_cfg.magic) + "_" + m_nhan + "_";
      m_hATR = iATR(_Symbol, m_cfg.tf, PMI_ATR_CHU_KY);
      m_hADX = iADX(_Symbol, m_cfg.tf, PMI_ADX_CHU_KY);
      m_hEMA = iMA(_Symbol, m_cfg.tf, PMI_EMA_CHU_KY, 0, MODE_EMA, PRICE_CLOSE);
      m_hBB  = iBands(_Symbol, m_cfg.tf, PMI_BB_CHU_KY, 0, PMI_BB_LECH, PRICE_CLOSE);
      return m_hATR != INVALID_HANDLE && m_hADX != INVALID_HANDLE && m_hEMA != INVALID_HANDLE && m_hBB != INVALID_HANDLE;
     }

   void              Deinit()
     {
      if(m_hATR != INVALID_HANDLE)
         IndicatorRelease(m_hATR);
      if(m_hADX != INVALID_HANDLE)
         IndicatorRelease(m_hADX);
      if(m_hEMA != INVALID_HANDLE)
         IndicatorRelease(m_hEMA);
      if(m_hBB != INVALID_HANDLE)
         IndicatorRelease(m_hBB);
      m_hATR = INVALID_HANDLE;
      m_hADX = INVALID_HANDLE;
      m_hEMA = INVALID_HANDLE;
      m_hBB = INVALID_HANDLE;
      if(m_log != INVALID_HANDLE)
         FileClose(m_log);
      m_log = INVALID_HANDLE;
      LuuTrangThai();
     }

   //--- Gọi mỗi tick và mỗi giây. Xử lý nến vừa đóng của khung MI; lần đầu dựng lại trạng thái từ lịch sử.
   //--- Trả về true khi vừa xử lý một nến mới.
   bool              CapNhat(const string thuMuc)
     {
      datetime t0 = iTime(_Symbol, m_cfg.tf, 0);
      if(t0 == 0 || t0 == m_nenCuoi)
         return false;
      int bars = Bars(_Symbol, m_cfg.tf);
      if(BarsCalculated(m_hATR) < bars || BarsCalculated(m_hADX) < bars || BarsCalculated(m_hEMA) < bars || BarsCalculated(m_hBB) < bars)
         return false;                               // chờ chỉ báo tính xong nến mới
      PMI_NEN x;
      if(!m_san)
        {
         // khởi động: chạy lại tối đa PMI_NEN_KHOI_DONG nến đã đóng, không ghi log, không xét phòng thủ
         int tu = MathMin(PMI_NEN_KHOI_DONG, bars - MathMax(2 * m_cfg.soNenRange, 100) - 10);
         for(int s = tu; s >= 2; s--)
            if(TinhNen(s, x))
              {
               m_suKien = "";
               XuLyThiTruong(x);
              }
         DocTrangThai();
         m_san = true;
        }
      if(!TinhNen(1, x))
         return false;
      m_nenCuoi = t0;
      m_suKien = "";
      m_lyDo = "";
      XuLyThiTruong(x);
      TinhFib(x);
      DocBasket();
      XuLyPhongThu(x);
      if(m_lyDo == "")
         m_lyDo = LyDoMacDinh();
      GhiDong(x, thuMuc);
      return true;
     }

   string            LyDoMacDinh()
     {
      if(m_pt == PMI_DEF1 || m_pt == PMI_DEF2)
         return "Đang phòng thủ, ngữ cảnh " + m_ngucanh;
      if(m_tt == PMI_BO_NGHI)
         return "Chờ xác nhận: điểm " + IntegerToString(m_diem) + "/" + IntegerToString(m_cfg.diemXacNhan) + ", " +
                IntegerToString(m_ngoai) + "/" + IntegerToString(m_cfg.soNenXacNhan) + " nến ngoài";
      if(m_tt == PMI_BO_XN && m_bkHuong == 0)
         return "Breakout xác nhận, không có basket để phòng thủ";
      if(m_tt == PMI_BO_XN && m_boHuong == m_bkHuong)
         return "Breakout cùng hướng basket: không phòng thủ";
      return "";
     }

   //--- Truy vấn cho EA chủ (các bản sau dùng để khóa DCA / điều khiển hedge)
   PMI_TT            TrangThai()      { return m_tt; }
   PMI_PT            PhongThu()       { return m_pt; }
   int               HuongBreakout()  { return m_boHuong; }
   int               DiemBO()         { return m_diem; }
   bool              KhoaDCA()        { return m_cfg.khoaDCA && (m_pt == PMI_DEF1 || m_pt == PMI_DEF2); }
   double            HedgeTyLe()      { return TyLeMucTieu(); }
   double            HedgeLot()       { return LotMucTieu(); }

   string            TenTT()
     {
      switch(m_tt)
        {
         case PMI_SIDEWAY:
            return "SIDEWAY";
         case PMI_BO_NGHI:
            return "BREAKOUT_SUSPECTED";
         case PMI_BO_XN:
            return "BREAKOUT_CONFIRMED";
         case PMI_RECLAIM:
            return "RECLAIM";
        }
      return "NORMAL";
     }

   string            TenPT()
     {
      switch(m_pt)
        {
         case PMI_DEF1:
            return "DEFENSE_1";
         case PMI_DEF2:
            return "DEFENSE_2";
         case PMI_PHUC_HOI:
            return "RECOVERY";
        }
      return "IDLE";
     }

   //--- Dòng mô tả ngắn cho Comment() trên chart
   string            MoTa()
     {
      string s = PMI_PHIEN_BAN + " — CHỈ GHI LOG, KHÔNG GỬI LỆNH\n";
      s += "Thị trường: " + TenTT();
      if(m_tt != PMI_NORMAL)
         s += "  range " + F(m_rL) + " – " + F(m_rU);
      if(m_boHuong != 0)
         s += "  breakout " + ((m_boHuong > 0) ? "TĂNG" : "GIẢM") + " điểm " + IntegerToString(m_diem) + " [" + m_bangChung + "]";
      s += "\nBasket: " + ((m_bkHuong > 0) ? "BUY " : ((m_bkHuong < 0) ? "SELL " : "không có ")) +
           DoubleToString(MathMax(m_bkBuy, m_bkSell), 2) + " lot, net " + DoubleToString(m_bkBuy - m_bkSell, 2);
      s += "\nPhòng thủ (sẽ làm): " + TenPT() + (KhoaDCA() ? "  KHÓA DCA" : "") +
           ((TyLeMucTieu() > 0.0) ? "  hedge " + DoubleToString(TyLeMucTieu(), 0) + "% = " + DoubleToString(LotMucTieu(), 2) + " lot" : "") +
           ((m_ngucanh != "") ? "  ngữ cảnh " + m_ngucanh : "");
      s += "\nFib: " + ((m_fibVung != "") ? m_fibVung + " (" + DoubleToString(m_fibTyLe, 3) + ")" : "—") + "   Lý do: " + m_lyDo;
      return s;
     }
  };

//+------------------------------------------------------------------+
