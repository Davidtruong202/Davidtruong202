//+------------------------------------------------------------------+
//|                                                  TradeLogger.mq5 |
//| Ghi lai toan bo lenh cua tai khoan dang dang nhap (ke ca dang    |
//| nhap bang mat khau investor / Passview) kem boi canh thi truong  |
//| tai thoi diem vao lenh, xuat ra CSV de phan tich bang            |
//| tools/analyze_trades.py.                                         |
//|                                                                  |
//| EA KHONG dat lenh, chi doc lich su + trang thai tai khoan.       |
//|                                                                  |
//| 2.00: them dac trung rieng cua bot DCA (EMA/CCI/nen dung khung   |
//| cua file .set), boi canh ro lenh (lenh thu may, cach lenh truoc  |
//| bao nhieu pip, he so lot), bat su kien tuc thi bang               |
//| OnTradeTransaction, loc theo magic, xuat nen M1 kem dac trung     |
//| bot (de so sanh luc vao lenh vs luc khong vao).                   |
//+------------------------------------------------------------------+
#property copyright "TradeLogger"
#property version   "2.00"
#property description "Ghi log lenh (deal/order/position) + dac trung thi truong ra CSV."
#property description "Chay duoc voi tai khoan dang nhap bang mat khau investor (chi doc)."

input group "Tệp xuất (MQL5/Files)"
input string          InpFilePrefix       = "tradelog"; // Tiền tố tên file
input bool            InpUseCommonFolder  = false;      // Ghi vào thư mục Common\Files

input group "Đặc trưng thị trường"
input ENUM_TIMEFRAMES InpFeatureTF        = PERIOD_M5;  // Khung tính đặc trưng lúc vào lệnh
input ENUM_TIMEFRAMES InpBiasTF           = PERIOD_H1;  // Khung xu hướng lớn

input group "Xuất nến để so sánh (vào lệnh vs không vào lệnh)"
input bool            InpExportBars       = true;       // Xuất toàn bộ nến kèm đặc trưng
input string          InpBarSymbols       = "";         // Symbol cần xuất, cách nhau dấu phẩy (trống = tự lấy từ lịch sử lệnh)
input int             InpBarsLookbackDays = 3;          // Lấy thêm N ngày trước lệnh đầu tiên
input int             InpBarsRefreshHours = 6;          // Xuất lại file nến mỗi N giờ

input group "Theo dõi"
input int             InpTimerSeconds     = 5;          // Chu kỳ kiểm tra (giây)
input int             InpLiveWindowSec    = 10;         // Deal mới trong N giây -> ghi thêm bid/ask/EMA tức thời

input group "Lọc lệnh"
input long            InpMagicFilter      = 0;          // Chỉ ghi magic này (0 = tất cả)
input string          InpSymbolFilter     = "";         // Chỉ ghi symbol này (trống = tất cả)
input double          InpPipSize          = 0;          // Cỡ pip (0 = tự động, XAU/GOLD = 0.1)

input group "Đặc trưng riêng bot DCA (mặc định khớp file .set BE Nha Trang)"
input bool            InpBotFeatures      = true;       // Ghi đặc trưng bot vào deals
input ENUM_TIMEFRAMES InpBotEmaTF         = PERIOD_M6;  // EMA chính: khung (InpEMATF)
input int             InpBotEmaFast       = 34;         // EMA chính: nhanh
input int             InpBotEmaSlow       = 89;         // EMA chính: chậm
input ENUM_TIMEFRAMES InpBotF1TF          = PERIOD_M12; // Lọc phụ 1: khung (InpM1TF)
input int             InpBotF1Fast        = 10;
input int             InpBotF1Slow        = 20;
input ENUM_TIMEFRAMES InpBotF2TF          = PERIOD_M6;  // Lọc phụ 2: khung (InpM15TF)
input int             InpBotF2Fast        = 34;
input int             InpBotF2Slow        = 89;
input ENUM_TIMEFRAMES InpBotCciTF         = PERIOD_M1;  // CCI: khung
input int             InpBotCciPeriod     = 14;
input ENUM_TIMEFRAMES InpBotDcaTF         = PERIOD_M1;  // Khung nến DCA (InpDCATF)
input ENUM_TIMEFRAMES InpBotPaTF          = PERIOD_M10; // Khung Price Action
input bool            InpExportBotBars    = true;       // Xuất nến khung DCA kèm đặc trưng bot (nối thêm liên tục)

//--- bo chi bao cho moi cap (symbol, timeframe)
struct IndSet
  {
   string            sym;
   ENUM_TIMEFRAMES   tf;
   int               atr, rsi, ema20, ema50, ema200, bb, macd, stoch;
  };
IndSet   g_ind[];

//--- trang thai
bool     g_initialDone = false;
ulong    g_loggedDeals[];
datetime g_lastDealTime = 0;
datetime g_lastBarsExport = 0;
bool     g_snapInit = false;
int      g_waitTicks = 0;

//--- bo chi bao rieng cua bot DCA cho moi symbol
struct BotSet
  {
   string            sym;
   int               emaF, emaS, f1F, f1S, f2F, f2S, cci;
  };
BotSet   g_bot[];

//--- phat lai lich su deal -> vi the dang mo (de tinh boi canh ro lenh)
ulong    g_pId[];
string   g_pSym[];
long     g_pMagic[];
int      g_pSide[];      // 0 = BUY, 1 = SELL
double   g_pPrice[], g_pVol[];
int      g_pIdx[], g_pBasket[];
string   g_bKey[];
int      g_bCur[];
int      g_basketSeq = 0;

bool     g_ordersDirty = false;
string   g_bbSym[];       // file nen bot: symbol -> thoi gian nen cuoi da ghi
datetime g_bbLast[];

//--- snapshot vi the / lenh cho (mang song song)
ulong    g_sTicket[];
bool     g_sIsOrder[];
string   g_sSym[];
string   g_sType[];
long     g_sMagic[];
double   g_sVol[], g_sPrice[], g_sSL[], g_sTP[];

//+------------------------------------------------------------------+
string FName(const string what) { return InpFilePrefix + "_" + what + ".csv"; }

int OpenOut(const string name, const bool append)
  {
   int flags = FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ;
   if(append)
      flags |= FILE_READ;
   if(InpUseCommonFolder)
      flags |= FILE_COMMON;
   int h = FileOpen(name, flags);
   if(h == INVALID_HANDLE)
      PrintFormat("[TradeLogger] Khong mo duoc file %s, loi %d", name, GetLastError());
   else if(append)
      FileSeek(h, 0, SEEK_END);
   return h;
  }

void WriteLine(const int h, const string line) { FileWriteString(h, line + "\r\n"); }

string Clean(string s)
  {
   StringReplace(s, ",", ";");
   StringReplace(s, "\r", " ");
   StringReplace(s, "\n", " ");
   return s;
  }

string D(const double v, const int digits = 5) { return DoubleToString(v, digits); }

string TS(const datetime t) { return TimeToString(t, TIME_DATE | TIME_SECONDS); }

bool Valid(const double v) { return v != EMPTY_VALUE && MathIsValidNumber(v); }

//--- so hop le -> chuoi, khong hop le -> o trong
string VD(const double v, const int digits) { return Valid(v) ? DoubleToString(v, digits) : ""; }

//--- chuoi n-1 dau phay cho mot header n cot
string EmptyCols(const string header)
  {
   string parts[];
   int n = StringSplit(header, ',', parts);
   string s = "";
   for(int i = 1; i < n; i++)
      s += ",";
   return s;
  }

string TfName(const ENUM_TIMEFRAMES tf)
  {
   string s = EnumToString(tf == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : tf);
   StringReplace(s, "PERIOD_", "");
   return s;
  }

double PipOf(const string sym)
  {
   if(InpPipSize > 0)
      return InpPipSize;
   string s = sym;
   StringToUpper(s);
   if(StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0)
      return 0.1;
   int    d  = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(pt <= 0)
      return 0.0001;
   return (d == 3 || d == 5) ? 10.0 * pt : pt;
  }

bool PassFilter(const string sym, const long magic)
  {
   if(InpMagicFilter != 0 && magic != InpMagicFilter)
      return false;
   if(StringLen(InpSymbolFilter) > 0 && sym != InpSymbolFilter)
      return false;
   return true;
  }

//+------------------------------------------------------------------+
int IndIndex(const string sym, const ENUM_TIMEFRAMES tf)
  {
   int n = ArraySize(g_ind);
   for(int i = 0; i < n; i++)
      if(g_ind[i].sym == sym && g_ind[i].tf == tf)
         return i;
   SymbolSelect(sym, true);
   ArrayResize(g_ind, n + 1);
   g_ind[n].sym    = sym;
   g_ind[n].tf     = tf;
   g_ind[n].atr    = iATR(sym, tf, 14);
   g_ind[n].rsi    = iRSI(sym, tf, 14, PRICE_CLOSE);
   g_ind[n].ema20  = iMA(sym, tf, 20, 0, MODE_EMA, PRICE_CLOSE);
   g_ind[n].ema50  = iMA(sym, tf, 50, 0, MODE_EMA, PRICE_CLOSE);
   g_ind[n].ema200 = iMA(sym, tf, 200, 0, MODE_EMA, PRICE_CLOSE);
   g_ind[n].bb     = iBands(sym, tf, 20, 0, 2.0, PRICE_CLOSE);
   g_ind[n].macd   = iMACD(sym, tf, 12, 26, 9, PRICE_CLOSE);
   g_ind[n].stoch  = iStochastic(sym, tf, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
   return n;
  }

string g_notReady = ""; // ly do chua san sang, de in ra tab Experts

bool IndReady(const int k)
  {
   int h[8];
   string names[8] = {"ATR", "RSI", "EMA20", "EMA50", "EMA200", "BB", "MACD", "STOCH"};
   h[0] = g_ind[k].atr;   h[1] = g_ind[k].rsi;  h[2] = g_ind[k].ema20; h[3] = g_ind[k].ema50;
   h[4] = g_ind[k].ema200; h[5] = g_ind[k].bb;  h[6] = g_ind[k].macd;  h[7] = g_ind[k].stoch;
   for(int i = 0; i < 8; i++)
      if(h[i] == INVALID_HANDLE || BarsCalculated(h[i]) <= 0)
        {
         g_notReady = StringFormat("%s %s %s: handle=%d calculated=%d bars=%d synced=%s",
                                   g_ind[k].sym, EnumToString(g_ind[k].tf), names[i], h[i],
                                   h[i] == INVALID_HANDLE ? -1 : BarsCalculated(h[i]),
                                   Bars(g_ind[k].sym, g_ind[k].tf),
                                   SeriesInfoInteger(g_ind[k].sym, g_ind[k].tf, SERIES_SYNCHRONIZED) ? "yes" : "no");
         return false;
        }
   return true;
  }

bool SymbolReady(const string sym)
  {
   bool ok = IndReady(IndIndex(sym, InpFeatureTF)) && IndReady(IndIndex(sym, InpBiasTF));
   if(ok && (InpBotFeatures || InpExportBotBars))
      ok = BotReady(BotIndex(sym));
   return ok;
  }

double Buf(const int handle, const int buffer, const int shift)
  {
   double v[1];
   if(CopyBuffer(handle, buffer, shift, 1, v) != 1)
      return EMPTY_VALUE;
   return v[0];
  }

//+------------------------------------------------------------------+
//| Dac trung thi truong. Tat ca tinh tren nen DA DONG (shift >= 1   |
//| khi dung cho lenh) de khong nhin truoc tuong lai.                 |
//+------------------------------------------------------------------+
string FeatureHeader()
  {
   return "feat_bar_time,f_hour,f_minute,f_weekday,f_close,f_atr,"
          "f_body_atr,f_range_atr,f_upwick_atr,f_lowwick_atr,f_streak,"
          "f_rsi,f_dist_ema20_atr,f_dist_ema50_atr,f_dist_ema200_atr,"
          "f_ema20_slope_atr,f_ema50_slope_atr,f_ema_stack,"
          "f_bb_pctb,f_bb_width_atr,f_macd_hist_atr,f_macd_main_atr,f_stoch_k,f_stoch_d,"
          "f_dist_hh20_atr,f_dist_ll20_atr,f_break_hh20,f_break_ll20,"
          "f_dist_pdh_atr,f_dist_pdl_atr,f_dist_dopen_atr,f_pos_day_range,"
          "f_dist_today_hi_atr,f_dist_today_lo_atr,"
          "f_bias_rsi,f_bias_dist_ema50_atr,f_bias_dist_ema200_atr,f_bias_ema50_slope_atr";
  }

string EmptyFeatures()
  {
   string parts[];
   int n = StringSplit(FeatureHeader(), ',', parts);
   string s = "";
   for(int i = 1; i < n; i++)
      s += ",";
   return s;
  }

bool Features(const string sym, const int shift, string &out)
  {
   out = "";
   const ENUM_TIMEFRAMES tf = InpFeatureTF;
   if(shift < 0)
      return false;
   int k  = IndIndex(sym, tf);
   int kb = IndIndex(sym, InpBiasTF);

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(sym, tf, shift, 25, r) < 25)
      return false;

   double atr = Buf(g_ind[k].atr, 0, shift);
   if(!Valid(atr) || atr <= 0)
      return false;

   const double c = r[0].close, o = r[0].open, hi = r[0].high, lo = r[0].low;

   //--- chuoi nen cung mau
   int dir = (c > o) ? 1 : (c < o ? -1 : 0);
   int streak = 0;
   if(dir != 0)
      for(int i = 0; i < 25; i++)
        {
         int d = (r[i].close > r[i].open) ? 1 : (r[i].close < r[i].open ? -1 : 0);
         if(d != dir)
            break;
         streak++;
        }
   streak *= dir;

   double rsi   = Buf(g_ind[k].rsi, 0, shift);
   double e20   = Buf(g_ind[k].ema20, 0, shift);
   double e20p  = Buf(g_ind[k].ema20, 0, shift + 5);
   double e50   = Buf(g_ind[k].ema50, 0, shift);
   double e50p  = Buf(g_ind[k].ema50, 0, shift + 5);
   double e200  = Buf(g_ind[k].ema200, 0, shift);
   double bbu   = Buf(g_ind[k].bb, 1, shift);
   double bbl   = Buf(g_ind[k].bb, 2, shift);
   double mMain = Buf(g_ind[k].macd, 0, shift);
   double mSig  = Buf(g_ind[k].macd, 1, shift);
   double stK   = Buf(g_ind[k].stoch, 0, shift);
   double stD   = Buf(g_ind[k].stoch, 1, shift);
   if(!Valid(rsi) || !Valid(e20) || !Valid(e20p) || !Valid(e50) || !Valid(e50p) || !Valid(e200) ||
      !Valid(bbu) || !Valid(bbl) || !Valid(mMain) || !Valid(mSig) || !Valid(stK) || !Valid(stD))
      return false;

   int stack = (e20 > e50 && e50 > e200) ? 1 : ((e20 < e50 && e50 < e200) ? -1 : 0);
   double pctb = (bbu > bbl) ? (c - bbl) / (bbu - bbl) : 0.5;

   //--- dinh/day 20 nen truoc do (khong tinh nen hien tai)
   double hh = r[1].high, ll = r[1].low;
   for(int i = 2; i <= 20; i++)
     {
      hh = MathMax(hh, r[i].high);
      ll = MathMin(ll, r[i].low);
     }

   //--- thong tin ngay (D1)
   int d1s = iBarShift(sym, PERIOD_D1, r[0].time, false);
   if(d1s < 0)
      return false;
   double pdh   = iHigh(sym, PERIOD_D1, d1s + 1);
   double pdl   = iLow(sym, PERIOD_D1, d1s + 1);
   double dopen = iOpen(sym, PERIOD_D1, d1s);
   datetime dayStart = iTime(sym, PERIOD_D1, d1s);
   if(pdh <= 0 || pdl <= 0 || dopen <= 0 || dayStart <= 0)
      return false;

   double thi = hi, tlo = lo;
   MqlRates dr[];
   int nd = CopyRates(sym, tf, dayStart, r[0].time, dr);
   for(int i = 0; i < nd; i++)
     {
      thi = MathMax(thi, dr[i].high);
      tlo = MathMin(tlo, dr[i].low);
     }
   double posDay = (thi > tlo) ? (c - tlo) / (thi - tlo) : 0.5;

   //--- thoi diem ra quyet dinh = luc nen dac trung dong cua
   datetime tclose = r[0].time + PeriodSeconds(tf);
   MqlDateTime mt;
   TimeToStruct(tclose, mt);

   //--- khung xu huong lon: nen da dong gan nhat tai tclose
   int bs = iBarShift(sym, InpBiasTF, tclose, false);
   if(bs < 0)
      return false;
   bs += 1;
   double batr  = Buf(g_ind[kb].atr, 0, bs);
   double brsi  = Buf(g_ind[kb].rsi, 0, bs);
   double be50  = Buf(g_ind[kb].ema50, 0, bs);
   double be50p = Buf(g_ind[kb].ema50, 0, bs + 5);
   double be200 = Buf(g_ind[kb].ema200, 0, bs);
   double bcl   = iClose(sym, InpBiasTF, bs);
   if(!Valid(batr) || batr <= 0 || !Valid(brsi) || !Valid(be50) || !Valid(be50p) || !Valid(be200) || bcl <= 0)
      return false;

   out = TS(r[0].time) + "," + IntegerToString(mt.hour) + "," + IntegerToString(mt.min) + "," +
         IntegerToString(mt.day_of_week) + "," + D(c, 8) + "," + D(atr, 8) + "," +
         D((c - o) / atr, 4) + "," + D((hi - lo) / atr, 4) + "," +
         D((hi - MathMax(o, c)) / atr, 4) + "," + D((MathMin(o, c) - lo) / atr, 4) + "," +
         IntegerToString(streak) + "," +
         D(rsi, 2) + "," + D((c - e20) / atr, 4) + "," + D((c - e50) / atr, 4) + "," + D((c - e200) / atr, 4) + "," +
         D((e20 - e20p) / atr, 4) + "," + D((e50 - e50p) / atr, 4) + "," + IntegerToString(stack) + "," +
         D(pctb, 4) + "," + D((bbu - bbl) / atr, 4) + "," + D((mMain - mSig) / atr, 4) + "," + D(mMain / atr, 4) + "," +
         D(stK, 2) + "," + D(stD, 2) + "," +
         D((hh - c) / atr, 4) + "," + D((c - ll) / atr, 4) + "," + IntegerToString(c > hh ? 1 : 0) + "," +
         IntegerToString(c < ll ? 1 : 0) + "," +
         D((c - pdh) / atr, 4) + "," + D((c - pdl) / atr, 4) + "," + D((c - dopen) / atr, 4) + "," + D(posDay, 4) + "," +
         D((thi - c) / atr, 4) + "," + D((c - tlo) / atr, 4) + "," +
         D(brsi, 2) + "," + D((bcl - be50) / batr, 4) + "," + D((bcl - be200) / batr, 4) + "," +
         D((be50 - be50p) / batr, 4);
   return true;
  }

//+------------------------------------------------------------------+
//| Dac trung rieng cua bot DCA: dung khung/chu ky trong file .set.   |
//| Moi gia tri lay tren nen DA DONG ngay truoc thoi diem t, nen      |
//| tinh lai tu lich su cung ra dung gia tri bot da thay luc do.      |
//+------------------------------------------------------------------+
int BotIndex(const string sym)
  {
   int n = ArraySize(g_bot);
   for(int i = 0; i < n; i++)
      if(g_bot[i].sym == sym)
         return i;
   SymbolSelect(sym, true);
   ArrayResize(g_bot, n + 1);
   g_bot[n].sym = sym;
   g_bot[n].emaF = iMA(sym, InpBotEmaTF, InpBotEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   g_bot[n].emaS = iMA(sym, InpBotEmaTF, InpBotEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   g_bot[n].f1F  = iMA(sym, InpBotF1TF, InpBotF1Fast, 0, MODE_EMA, PRICE_CLOSE);
   g_bot[n].f1S  = iMA(sym, InpBotF1TF, InpBotF1Slow, 0, MODE_EMA, PRICE_CLOSE);
   g_bot[n].f2F  = iMA(sym, InpBotF2TF, InpBotF2Fast, 0, MODE_EMA, PRICE_CLOSE);
   g_bot[n].f2S  = iMA(sym, InpBotF2TF, InpBotF2Slow, 0, MODE_EMA, PRICE_CLOSE);
   g_bot[n].cci  = iCCI(sym, InpBotCciTF, InpBotCciPeriod, PRICE_TYPICAL);
   return n;
  }

bool BotReady(const int k)
  {
   int h[7];
   h[0] = g_bot[k].emaF; h[1] = g_bot[k].emaS; h[2] = g_bot[k].f1F; h[3] = g_bot[k].f1S;
   h[4] = g_bot[k].f2F;  h[5] = g_bot[k].f2S;  h[6] = g_bot[k].cci;
   for(int i = 0; i < 7; i++)
      if(h[i] == INVALID_HANDLE || BarsCalculated(h[i]) <= 0)
        {
         g_notReady = StringFormat("%s bot indicator #%d: handle=%d", g_bot[k].sym, i, h[i]);
         return false;
        }
   return true;
  }

string BotHeader()
  {
   return "b_hour,b_sec_in_dca_bar,b_sec_in_ema_bar,"
          "b_ema_bar,b_ema_fast,b_ema_slow,b_ema_gap_pct,b_px_dist_fast_pct,b_ema_dir,"
          "b_f1_fast,b_f1_slow,b_f1_dir,b_f2_fast,b_f2_slow,b_f2_dir,b_cci1,b_cci2,"
          "b_dca_bar,b_dca_o,b_dca_h,b_dca_l,b_dca_c,b_pa_body_pct,b_pa_dir";
  }

int Dir(const double a, const double b)
  {
   if(!Valid(a) || !Valid(b))
      return 0;
   return a > b ? 1 : (a < b ? -1 : 0);
  }

//--- t/tmsc: thoi diem ra quyet dinh; price: gia de do khoang cach toi EMA
bool BotFeatures(const string sym, const datetime t, const long tmsc, const double price, string &out)
  {
   out = "";
   int k  = BotIndex(sym);
   int se = iBarShift(sym, InpBotEmaTF, t, false);
   int s1 = iBarShift(sym, InpBotF1TF, t, false);
   int s2 = iBarShift(sym, InpBotF2TF, t, false);
   int sc = iBarShift(sym, InpBotCciTF, t, false);
   int sd = iBarShift(sym, InpBotDcaTF, t, false);
   int sp = iBarShift(sym, InpBotPaTF, t, false);
   if(se < 0 || s1 < 0 || s2 < 0 || sc < 0 || sd < 0 || sp < 0)
      return false;
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   if(digits <= 0)
      digits = 5;

   double ef  = Buf(g_bot[k].emaF, 0, se + 1), es = Buf(g_bot[k].emaS, 0, se + 1);
   double f1f = Buf(g_bot[k].f1F, 0, s1 + 1),  f1s = Buf(g_bot[k].f1S, 0, s1 + 1);
   double f2f = Buf(g_bot[k].f2F, 0, s2 + 1),  f2s = Buf(g_bot[k].f2S, 0, s2 + 1);
   double c1  = Buf(g_bot[k].cci, 0, sc + 1),  c2  = Buf(g_bot[k].cci, 0, sc + 2);

   double gap  = (Valid(ef) && Valid(es) && price > 0) ? (ef - es) / price * 100.0 : EMPTY_VALUE;
   double dist = (Valid(ef) && price > 0) ? (price - ef) / price * 100.0 : EMPTY_VALUE;

   datetime dcaOpen = iTime(sym, InpBotDcaTF, sd);
   datetime emaOpen = iTime(sym, InpBotEmaTF, se);
   double secDca = dcaOpen > 0 ? (tmsc - (long)dcaOpen * 1000) / 1000.0 : EMPTY_VALUE;
   double secEma = emaOpen > 0 ? (tmsc - (long)emaOpen * 1000) / 1000.0 : EMPTY_VALUE;

   datetime dT = iTime(sym, InpBotDcaTF, sd + 1);
   double dO = iOpen(sym, InpBotDcaTF, sd + 1), dH = iHigh(sym, InpBotDcaTF, sd + 1);
   double dL = iLow(sym, InpBotDcaTF, sd + 1),  dC = iClose(sym, InpBotDcaTF, sd + 1);

   double pO = iOpen(sym, InpBotPaTF, sp + 1), pC = iClose(sym, InpBotPaTF, sp + 1);
   double pH = iHigh(sym, InpBotPaTF, sp + 1), pL = iLow(sym, InpBotPaTF, sp + 1);
   double body = (pH > pL) ? MathAbs(pC - pO) / (pH - pL) * 100.0 : EMPTY_VALUE;

   MqlDateTime mt;
   TimeToStruct(t, mt);

   out = IntegerToString(mt.hour) + "," + VD(secDca, 3) + "," + VD(secEma, 3) + "," +
         TS(iTime(sym, InpBotEmaTF, se + 1)) + "," + VD(ef, digits + 2) + "," + VD(es, digits + 2) + "," +
         VD(gap, 5) + "," + VD(dist, 5) + "," + IntegerToString(Dir(ef, es)) + "," +
         VD(f1f, digits + 2) + "," + VD(f1s, digits + 2) + "," + IntegerToString(Dir(f1f, f1s)) + "," +
         VD(f2f, digits + 2) + "," + VD(f2s, digits + 2) + "," + IntegerToString(Dir(f2f, f2s)) + "," +
         VD(c1, 2) + "," + VD(c2, 2) + "," +
         (dT > 0 ? TS(dT) : "") + "," + VD(dO, digits) + "," + VD(dH, digits) + "," + VD(dL, digits) + "," +
         VD(dC, digits) + "," + VD(body, 2) + "," + IntegerToString(Dir(pC, pO));
   return true;
  }

//+------------------------------------------------------------------+
//| Boi canh ro lenh: phat lai deal theo thu tu thoi gian, gom vi the |
//| dang mo theo (symbol, magic, chieu) = mot "ro" DCA.               |
//+------------------------------------------------------------------+
string BasketHeader()
  {
   return "k_side,k_basket,k_idx,k_count_before,k_vol_before,k_avg_before,k_last_price,k_last_lot,"
          "k_dist_last_pips,k_dist_avg_pips,k_lot_ratio,k_pos_pips,k_count_after,k_pip";
  }

void ResetReplay()
  {
   ArrayResize(g_pId, 0); ArrayResize(g_pSym, 0); ArrayResize(g_pMagic, 0); ArrayResize(g_pSide, 0);
   ArrayResize(g_pPrice, 0); ArrayResize(g_pVol, 0); ArrayResize(g_pIdx, 0); ArrayResize(g_pBasket, 0);
   ArrayResize(g_bKey, 0); ArrayResize(g_bCur, 0);
   g_basketSeq = 0;
  }

int FindPos(const ulong id)
  {
   for(int i = ArraySize(g_pId) - 1; i >= 0; i--)
      if(g_pId[i] == id)
         return i;
   return -1;
  }

void RemovePos(const int i)
  {
   int n = ArraySize(g_pId);
   for(int j = i; j < n - 1; j++)
     {
      g_pId[j] = g_pId[j + 1];   g_pSym[j] = g_pSym[j + 1];     g_pMagic[j] = g_pMagic[j + 1];
      g_pSide[j] = g_pSide[j + 1]; g_pPrice[j] = g_pPrice[j + 1]; g_pVol[j] = g_pVol[j + 1];
      g_pIdx[j] = g_pIdx[j + 1];  g_pBasket[j] = g_pBasket[j + 1];
     }
   ArrayResize(g_pId, n - 1); ArrayResize(g_pSym, n - 1); ArrayResize(g_pMagic, n - 1); ArrayResize(g_pSide, n - 1);
   ArrayResize(g_pPrice, n - 1); ArrayResize(g_pVol, n - 1); ArrayResize(g_pIdx, n - 1); ArrayResize(g_pBasket, n - 1);
  }

//--- mang vi the giu thu tu mo lenh, nen phan tu cuoi cung khop = lenh moi nhat
void BasketStats(const string sym, const long magic, const int side,
                 int &cnt, double &vol, double &avg, double &lastP, double &lastL)
  {
   cnt = 0; vol = 0; avg = 0; lastP = 0; lastL = 0;
   double pv = 0;
   for(int i = 0; i < ArraySize(g_pId); i++)
     {
      if(g_pSym[i] != sym || g_pMagic[i] != magic || g_pSide[i] != side)
         continue;
      cnt++;
      vol += g_pVol[i];
      pv  += g_pPrice[i] * g_pVol[i];
      lastP = g_pPrice[i];
      lastL = g_pVol[i];
     }
   if(vol > 0)
      avg = pv / vol;
  }

int BasketSlot(const string key)
  {
   for(int i = 0; i < ArraySize(g_bKey); i++)
      if(g_bKey[i] == key)
         return i;
   int n = ArraySize(g_bKey);
   ArrayResize(g_bKey, n + 1);
   ArrayResize(g_bCur, n + 1);
   g_bKey[n] = key;
   g_bCur[n] = 0;
   return n;
  }

//--- cap nhat trang thai theo deal t, tra ve cot boi canh ro va magic cua vi the
string Replay(const ulong t, long &magic)
  {
   long   type  = HistoryDealGetInteger(t, DEAL_TYPE);
   long   entry = HistoryDealGetInteger(t, DEAL_ENTRY);
   ulong  pid   = (ulong)HistoryDealGetInteger(t, DEAL_POSITION_ID);
   string sym   = HistoryDealGetString(t, DEAL_SYMBOL);
   double price = HistoryDealGetDouble(t, DEAL_PRICE);
   double vol   = HistoryDealGetDouble(t, DEAL_VOLUME);
   magic = HistoryDealGetInteger(t, DEAL_MAGIC);

   int pi = FindPos(pid);
   int side;
   if(entry == DEAL_ENTRY_IN)
      side = (type == DEAL_TYPE_BUY) ? 0 : 1;
   else
      side = (pi >= 0) ? g_pSide[pi] : ((type == DEAL_TYPE_BUY) ? 1 : 0);
   if(pi >= 0)
      magic = g_pMagic[pi]; // deal dong boi SL/TP co the khong mang magic

   double pip = PipOf(sym);
   double dir = (side == 0) ? 1.0 : -1.0;
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   if(digits <= 0)
      digits = 5;

   int cnt; double bvol, avg, lastP, lastL;
   BasketStats(sym, magic, side, cnt, bvol, avg, lastP, lastL);
   int slot = BasketSlot(sym + "|" + IntegerToString(magic) + "|" + IntegerToString(side));

   double distLast = EMPTY_VALUE, distAvg = EMPTY_VALUE, ratio = EMPTY_VALUE, posPips = EMPTY_VALUE;
   int basket = -1, idx = 0, after = cnt;

   if(entry == DEAL_ENTRY_IN)
     {
      if(cnt == 0)
         g_bCur[slot] = ++g_basketSeq;
      basket = g_bCur[slot];
      idx = cnt + 1;
      if(cnt > 0)
        {
         distLast = dir * (lastP - price) / pip;   // duong = vao lenh o gia tot hon lenh truoc
         distAvg  = dir * (avg - price) / pip;
         if(lastL > 0)
            ratio = vol / lastL;
        }
      int n = ArraySize(g_pId);
      ArrayResize(g_pId, n + 1); ArrayResize(g_pSym, n + 1); ArrayResize(g_pMagic, n + 1); ArrayResize(g_pSide, n + 1);
      ArrayResize(g_pPrice, n + 1); ArrayResize(g_pVol, n + 1); ArrayResize(g_pIdx, n + 1); ArrayResize(g_pBasket, n + 1);
      g_pId[n] = pid; g_pSym[n] = sym; g_pMagic[n] = magic; g_pSide[n] = side;
      g_pPrice[n] = price; g_pVol[n] = vol; g_pIdx[n] = idx; g_pBasket[n] = basket;
      after = cnt + 1;
     }
   else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
     {
      if(pi >= 0)
        {
         basket  = g_pBasket[pi];
         idx     = g_pIdx[pi];
         posPips = dir * (price - g_pPrice[pi]) / pip;   // duong = lenh nay dong co lai
         g_pVol[pi] -= vol;
         if(g_pVol[pi] <= 1e-8)
            RemovePos(pi);
        }
      if(cnt > 0)
         distAvg = dir * (price - avg) / pip;            // duong = dong tren gia trung binh (lai)
      int c2; double v2, a2, l2, ll2;
      BasketStats(sym, magic, side, c2, v2, a2, l2, ll2);
      after = c2;
     }
   else
      return (side == 0 ? "BUY" : "SELL") + EmptyCols(BasketHeader()); // INOUT (tai khoan netting): bo qua

   return (side == 0 ? "BUY" : "SELL") + "," + IntegerToString(basket) + "," + IntegerToString(idx) + "," +
          IntegerToString(cnt) + "," + D(bvol, 2) + "," + (cnt > 0 ? D(avg, digits + 2) : "") + "," +
          (cnt > 0 ? D(lastP, digits) : "") + "," + (cnt > 0 ? D(lastL, 2) : "") + "," +
          VD(distLast, 1) + "," + VD(distAvg, 1) + "," + VD(ratio, 4) + "," + VD(posPips, 1) + "," +
          IntegerToString(after) + "," + D(pip, 6);
  }

//+------------------------------------------------------------------+
//| Deals                                                             |
//+------------------------------------------------------------------+
string LiveHeader()
  {
   return "live_lag_sec,live_bid,live_ask,live_spread_pts,live_ema_fast0,live_ema_slow0";
  }

string DealHeader()
  {
   return "deal_ticket,order_ticket,position_id,time,time_msc,symbol,type,entry,volume,price,sl,tp,"
          "profit,commission,swap,fee,magic,reason,comment," + FeatureHeader() + "," +
          BasketHeader() + "," + BotHeader() + "," + LiveHeader();
  }

bool IsLogged(const ulong ticket)
  {
   int n = ArraySize(g_loggedDeals);
   for(int i = n - 1; i >= 0; i--)
      if(g_loggedDeals[i] == ticket)
         return true;
   return false;
  }

//--- live = deal vua xay ra (goi tu OnTradeTransaction/OnTimer): ghi them gia/EMA tuc thoi
bool DealLine(const ulong t, string &line, const bool live = false)
  {
   long type = HistoryDealGetInteger(t, DEAL_TYPE);
   if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL)
      return false; // bo qua nap/rut tien, credit...

   //--- luon phat lai (ke ca deal bi loc) de trang thai ro lenh dung
   long posMagic;
   string basketCols = Replay(t, posMagic);

   string sym  = HistoryDealGetString(t, DEAL_SYMBOL);
   if(!PassFilter(sym, posMagic))
      return false;
   int digits  = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   if(digits <= 0)
      digits = 5;
   datetime tm = (datetime)HistoryDealGetInteger(t, DEAL_TIME);
   long entry  = HistoryDealGetInteger(t, DEAL_ENTRY);
   string es   = entry == DEAL_ENTRY_IN ? "IN" : entry == DEAL_ENTRY_OUT ? "OUT" :
                 entry == DEAL_ENTRY_INOUT ? "INOUT" : "OUT_BY";

   line = IntegerToString((long)t) + "," +
          IntegerToString(HistoryDealGetInteger(t, DEAL_ORDER)) + "," +
          IntegerToString(HistoryDealGetInteger(t, DEAL_POSITION_ID)) + "," +
          TS(tm) + "," + IntegerToString(HistoryDealGetInteger(t, DEAL_TIME_MSC)) + "," +
          sym + "," + (type == DEAL_TYPE_BUY ? "BUY" : "SELL") + "," + es + "," +
          D(HistoryDealGetDouble(t, DEAL_VOLUME), 2) + "," +
          D(HistoryDealGetDouble(t, DEAL_PRICE), digits) + "," +
          D(HistoryDealGetDouble(t, DEAL_SL), digits) + "," +
          D(HistoryDealGetDouble(t, DEAL_TP), digits) + "," +
          D(HistoryDealGetDouble(t, DEAL_PROFIT), 2) + "," +
          D(HistoryDealGetDouble(t, DEAL_COMMISSION), 2) + "," +
          D(HistoryDealGetDouble(t, DEAL_SWAP), 2) + "," +
          D(HistoryDealGetDouble(t, DEAL_FEE), 2) + "," +
          IntegerToString(posMagic) + "," +
          EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(t, DEAL_REASON)) + "," +
          Clean(HistoryDealGetString(t, DEAL_COMMENT)) + ",";

   //--- dac trung o nen da dong ngay truoc thoi diem khop lenh
   string f;
   int s = iBarShift(sym, InpFeatureTF, tm, false);
   if(s >= 0 && Features(sym, s + 1, f))
      line += f;
   else
      line += EmptyFeatures();

   line += "," + basketCols + ",";

   string b;
   long   tmsc  = HistoryDealGetInteger(t, DEAL_TIME_MSC);
   double price = HistoryDealGetDouble(t, DEAL_PRICE);
   if(InpBotFeatures && BotFeatures(sym, tm, tmsc, price, b))
      line += b;
   else
      line += EmptyCols(BotHeader());

   line += ",";
   long lag = (long)(TimeCurrent() - tm);
   if(live && lag <= InpLiveWindowSec)
     {
      double bid = SymbolInfoDouble(sym, SYMBOL_BID), ask = SymbolInfoDouble(sym, SYMBOL_ASK);
      double pt  = SymbolInfoDouble(sym, SYMBOL_POINT);
      int k = BotIndex(sym);
      line += IntegerToString(lag) + "," + D(bid, digits) + "," + D(ask, digits) + "," +
              (pt > 0 ? D((ask - bid) / pt, 0) : "") + "," +
              VD(Buf(g_bot[k].emaF, 0, 0), digits + 2) + "," + VD(Buf(g_bot[k].emaS, 0, 0), digits + 2);
     }
   else
      line += EmptyCols(LiveHeader());
   return true;
  }

//--- tap symbol xuat hien trong lich su
void HistorySymbols(string &syms[])
  {
   ArrayResize(syms, 0);
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong t = HistoryDealGetTicket(i);
      long type = HistoryDealGetInteger(t, DEAL_TYPE);
      if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL)
         continue;
      string s = HistoryDealGetString(t, DEAL_SYMBOL);
      bool found = false;
      for(int j = 0; j < ArraySize(syms); j++)
         if(syms[j] == s) { found = true; break; }
      if(!found)
        {
         int n = ArraySize(syms);
         ArrayResize(syms, n + 1);
         syms[n] = s;
        }
     }
  }

void BarSymbols(string &syms[])
  {
   if(StringLen(InpSymbolFilter) > 0)
     {
      ArrayResize(syms, 1);
      syms[0] = InpSymbolFilter;
      return;
     }
   if(StringLen(InpBarSymbols) > 0)
     {
      string parts[];
      int n = StringSplit(InpBarSymbols, ',', parts);
      ArrayResize(syms, 0);
      for(int i = 0; i < n; i++)
        {
         string s = parts[i];
         StringTrimLeft(s);
         StringTrimRight(s);
         if(StringLen(s) == 0)
            continue;
         int m = ArraySize(syms);
         ArrayResize(syms, m + 1);
         syms[m] = s;
        }
      return;
     }
   HistorySelect(0, TimeCurrent() + 86400);
   HistorySymbols(syms);
   if(ArraySize(syms) == 0)
     {
      ArrayResize(syms, 1);
      syms[0] = _Symbol;
     }
  }

void DumpAllDeals()
  {
   HistorySelect(0, TimeCurrent() + 86400);
   int h = OpenOut(FName("deals"), false);
   if(h == INVALID_HANDLE)
      return;
   WriteLine(h, DealHeader());
   ArrayResize(g_loggedDeals, 0);
   ResetReplay();
   int total = HistoryDealsTotal(), written = 0;
   for(int i = 0; i < total; i++)
     {
      ulong t = HistoryDealGetTicket(i);
      string line;
      bool ok = DealLine(t, line);
      // danh dau ca deal bi loc: neu khong, AppendNewDeals se phat lai lan 2 -> sai trang thai ro
      int n = ArraySize(g_loggedDeals);
      ArrayResize(g_loggedDeals, n + 1, 1000);
      g_loggedDeals[n] = t;
      g_lastDealTime = MathMax(g_lastDealTime, (datetime)HistoryDealGetInteger(t, DEAL_TIME));
      if(!ok)
         continue;
      WriteLine(h, line);
      written++;
     }
   FileClose(h);
   PrintFormat("[TradeLogger] Da ghi %d deal vao %s", written, FName("deals"));
  }

bool AppendNewDeals(const bool live = true)
  {
   datetime from = (g_lastDealTime > 60) ? g_lastDealTime - 60 : 0;
   HistorySelect(from, TimeCurrent() + 86400);
   int total = HistoryDealsTotal();
   int h = INVALID_HANDLE, added = 0;
   for(int i = 0; i < total; i++)
     {
      ulong t = HistoryDealGetTicket(i);
      if(IsLogged(t))
         continue;
      string line;
      if(!DealLine(t, line, live))
        {
         int n = ArraySize(g_loggedDeals);
         ArrayResize(g_loggedDeals, n + 1, 1000);
         g_loggedDeals[n] = t;
         continue;
        }
      if(h == INVALID_HANDLE)
        {
         h = OpenOut(FName("deals"), true);
         if(h == INVALID_HANDLE)
            return false;
        }
      WriteLine(h, line);
      added++;
      int n = ArraySize(g_loggedDeals);
      ArrayResize(g_loggedDeals, n + 1, 1000);
      g_loggedDeals[n] = t;
      g_lastDealTime = MathMax(g_lastDealTime, (datetime)HistoryDealGetInteger(t, DEAL_TIME));
      PrintFormat("[TradeLogger] Deal moi: %s", line);
     }
   if(h != INVALID_HANDLE)
      FileClose(h);
   return added > 0;
  }

//+------------------------------------------------------------------+
//| Lich su order (cho biet dung lenh market hay lenh cho limit/stop) |
//+------------------------------------------------------------------+
void DumpOrders()
  {
   HistorySelect(0, TimeCurrent() + 86400);
   int h = OpenOut(FName("orders"), false);
   if(h == INVALID_HANDLE)
      return;
   WriteLine(h, "order_ticket,position_id,time_setup,time_done,symbol,type,state,reason,"
             "volume_initial,volume_current,price_open,sl,tp,price_current,magic,comment");
   int total = HistoryOrdersTotal();
   for(int i = 0; i < total; i++)
     {
      ulong t = HistoryOrderGetTicket(i);
      string sym = HistoryOrderGetString(t, ORDER_SYMBOL);
      if(sym == "")
         continue;
      if(!PassFilter(sym, HistoryOrderGetInteger(t, ORDER_MAGIC)))
         continue;
      int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      if(digits <= 0)
         digits = 5;
      WriteLine(h, IntegerToString((long)t) + "," +
                IntegerToString(HistoryOrderGetInteger(t, ORDER_POSITION_ID)) + "," +
                TS((datetime)HistoryOrderGetInteger(t, ORDER_TIME_SETUP)) + "," +
                TS((datetime)HistoryOrderGetInteger(t, ORDER_TIME_DONE)) + "," + sym + "," +
                EnumToString((ENUM_ORDER_TYPE)HistoryOrderGetInteger(t, ORDER_TYPE)) + "," +
                EnumToString((ENUM_ORDER_STATE)HistoryOrderGetInteger(t, ORDER_STATE)) + "," +
                EnumToString((ENUM_ORDER_REASON)HistoryOrderGetInteger(t, ORDER_REASON)) + "," +
                D(HistoryOrderGetDouble(t, ORDER_VOLUME_INITIAL), 2) + "," +
                D(HistoryOrderGetDouble(t, ORDER_VOLUME_CURRENT), 2) + "," +
                D(HistoryOrderGetDouble(t, ORDER_PRICE_OPEN), digits) + "," +
                D(HistoryOrderGetDouble(t, ORDER_SL), digits) + "," +
                D(HistoryOrderGetDouble(t, ORDER_TP), digits) + "," +
                D(HistoryOrderGetDouble(t, ORDER_PRICE_CURRENT), digits) + "," +
                IntegerToString(HistoryOrderGetInteger(t, ORDER_MAGIC)) + "," +
                Clean(HistoryOrderGetString(t, ORDER_COMMENT)));
     }
   FileClose(h);
  }

//+------------------------------------------------------------------+
//| Thong so symbol (point, digits...) de doi ra pip                  |
//+------------------------------------------------------------------+
void DumpSymbols()
  {
   string syms[];
   BarSymbols(syms);
   int h = OpenOut(FName("symbols"), false);
   if(h == INVALID_HANDLE)
      return;
   WriteLine(h, "symbol,digits,point,contract_size,tick_size,tick_value,volume_min,volume_step,"
             "feature_tf,bias_tf,account_currency,account_leverage,server,pip,magic_filter,"
             "bot_ema_tf,bot_ema,bot_f1_tf,bot_f1,bot_f2_tf,bot_f2,bot_cci_tf,bot_cci,bot_dca_tf,bot_pa_tf");
   for(int i = 0; i < ArraySize(syms); i++)
     {
      string s = syms[i];
      WriteLine(h, s + "," + IntegerToString(SymbolInfoInteger(s, SYMBOL_DIGITS)) + "," +
                D(SymbolInfoDouble(s, SYMBOL_POINT), 10) + "," +
                D(SymbolInfoDouble(s, SYMBOL_TRADE_CONTRACT_SIZE), 2) + "," +
                D(SymbolInfoDouble(s, SYMBOL_TRADE_TICK_SIZE), 10) + "," +
                D(SymbolInfoDouble(s, SYMBOL_TRADE_TICK_VALUE), 6) + "," +
                D(SymbolInfoDouble(s, SYMBOL_VOLUME_MIN), 2) + "," +
                D(SymbolInfoDouble(s, SYMBOL_VOLUME_STEP), 2) + "," +
                EnumToString(InpFeatureTF) + "," + EnumToString(InpBiasTF) + "," +
                AccountInfoString(ACCOUNT_CURRENCY) + "," +
                IntegerToString(AccountInfoInteger(ACCOUNT_LEVERAGE)) + "," +
                Clean(AccountInfoString(ACCOUNT_SERVER)) + "," + D(PipOf(s), 6) + "," +
                IntegerToString(InpMagicFilter) + "," +
                TfName(InpBotEmaTF) + "," + IntegerToString(InpBotEmaFast) + "/" + IntegerToString(InpBotEmaSlow) + "," +
                TfName(InpBotF1TF) + "," + IntegerToString(InpBotF1Fast) + "/" + IntegerToString(InpBotF1Slow) + "," +
                TfName(InpBotF2TF) + "," + IntegerToString(InpBotF2Fast) + "/" + IntegerToString(InpBotF2Slow) + "," +
                TfName(InpBotCciTF) + "," + IntegerToString(InpBotCciPeriod) + "," +
                TfName(InpBotDcaTF) + "," + TfName(InpBotPaTF));
     }
   FileClose(h);
  }

//+------------------------------------------------------------------+
//| Xuat moi nen kem dac trung -> so sanh luc vao lenh vs khong       |
//+------------------------------------------------------------------+
datetime FirstDealTime()
  {
   HistorySelect(0, TimeCurrent() + 86400);
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong t = HistoryDealGetTicket(i);
      long type = HistoryDealGetInteger(t, DEAL_TYPE);
      if(type == DEAL_TYPE_BUY || type == DEAL_TYPE_SELL)
         return (datetime)HistoryDealGetInteger(t, DEAL_TIME);
     }
   return TimeCurrent() - 30 * 86400;
  }

void ExportBars()
  {
   string syms[];
   BarSymbols(syms);
   datetime start = FirstDealTime() - InpBarsLookbackDays * 86400;
   string tfName = EnumToString(InpFeatureTF == PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : InpFeatureTF);
   StringReplace(tfName, "PERIOD_", "");
   for(int i = 0; i < ArraySize(syms); i++)
     {
      string s = syms[i];
      int first = iBarShift(s, InpFeatureTF, start, false);
      int avail = Bars(s, InpFeatureTF);
      if(first < 0 || first > avail - 30)
         first = avail - 30;
      if(first < 1)
        {
         PrintFormat("[TradeLogger] %s: chua du du lieu nen de xuat", s);
         continue;
        }
      string name = FName("bars_" + s + "_" + tfName);
      int h = OpenOut(name, false);
      if(h == INVALID_HANDLE)
         continue;
      WriteLine(h, "symbol," + FeatureHeader());
      int written = 0;
      for(int sh = first; sh >= 1; sh--)
        {
         string f;
         if(Features(s, sh, f))
           {
            WriteLine(h, s + "," + f);
            written++;
           }
        }
      FileClose(h);
      PrintFormat("[TradeLogger] Da xuat %d nen %s vao %s", written, s, name);
     }
   g_lastBarsExport = TimeCurrent();
  }

//+------------------------------------------------------------------+
//| Nen khung DCA kem dac trung bot, tinh tai thoi diem nen dong.     |
//| Lan dau ghi tu truoc lenh dau tien; sau do chi noi them nen moi.  |
//+------------------------------------------------------------------+
string BotBarHeader()
  {
   return "symbol,bar_time,open,high,low,close,spread,tick_volume," + BotHeader();
  }

void ExportBotBars()
  {
   string syms[];
   BarSymbols(syms);
   const ENUM_TIMEFRAMES tf = InpBotDcaTF;
   const int per = PeriodSeconds(tf);
   for(int i = 0; i < ArraySize(syms); i++)
     {
      string s = syms[i];
      string name = FName("botbars_" + s + "_" + TfName(tf));
      int slot = -1;
      for(int j = 0; j < ArraySize(g_bbSym); j++)
         if(g_bbSym[j] == s) { slot = j; break; }

      int h, first;
      if(slot < 0)
        {
         datetime start = FirstDealTime() - InpBarsLookbackDays * 86400;
         int avail = Bars(s, tf);
         first = iBarShift(s, tf, start, false);
         if(first < 0 || first > avail - 2)
           {
            first = avail - 2;
            PrintFormat("[TradeLogger] %s %s: chi co %d nen, khong du tu %s (tang 'Max bars in chart')",
                        s, TfName(tf), avail, TS(start));
           }
         if(first < 1)
            continue;
         h = OpenOut(name, false);
         if(h == INVALID_HANDLE)
            continue;
         WriteLine(h, BotBarHeader());
         slot = ArraySize(g_bbSym);
         ArrayResize(g_bbSym, slot + 1);
         ArrayResize(g_bbLast, slot + 1);
         g_bbSym[slot]  = s;
         g_bbLast[slot] = 0;
        }
      else
        {
         first = iBarShift(s, tf, g_bbLast[slot], false);
         if(first <= 1)
            continue; // chua co nen moi dong
         h = OpenOut(name, true);
         if(h == INVALID_HANDLE)
            continue;
        }

      MqlRates r[];
      ArraySetAsSeries(r, true);
      int got = CopyRates(s, tf, 1, first, r);
      int written = 0;
      for(int k = got - 1; k >= 0; k--)
        {
         if(r[k].time <= g_bbLast[slot])
            continue;
         datetime tclose = r[k].time + per;
         string f;
         if(!BotFeatures(s, tclose, (long)tclose * 1000, r[k].close, f))
            f = EmptyCols(BotHeader());
         int digits = (int)SymbolInfoInteger(s, SYMBOL_DIGITS);
         WriteLine(h, s + "," + TS(r[k].time) + "," + D(r[k].open, digits) + "," + D(r[k].high, digits) + "," +
                   D(r[k].low, digits) + "," + D(r[k].close, digits) + "," + IntegerToString(r[k].spread) + "," +
                   IntegerToString(r[k].tick_volume) + "," + f);
         g_bbLast[slot] = r[k].time;
         written++;
        }
      FileClose(h);
      if(written > 1)
         PrintFormat("[TradeLogger] Da ghi %d nen bot %s vao %s", written, s, name);
     }
  }

//+------------------------------------------------------------------+
//| Theo doi vi the / lenh cho dang mo: moi, sua SL/TP, dong          |
//+------------------------------------------------------------------+
int FindSnap(const ulong ticket, const bool isOrder)
  {
   for(int i = 0; i < ArraySize(g_sTicket); i++)
      if(g_sTicket[i] == ticket && g_sIsOrder[i] == isOrder)
         return i;
   return -1;
  }

void WriteEvent(int &h, const string ev, const bool isOrder, const ulong ticket, const long magic, const string sym,
                const string type, const double vol, const double price, const double sl, const double tp)
  {
   if(!PassFilter(sym, magic))
      return;
   if(h == INVALID_HANDLE)
     {
      // file moi (v2) vi them cot time_msc, magic: khong ghi chung file cu
      h = OpenOut(FName("events_v2"), true);
      if(h == INVALID_HANDLE)
         return;
      if(FileSize(h) == 0)
         WriteLine(h, "time,time_msc,kind,event,ticket,magic,symbol,type,volume,price,sl,tp,bid,ask");
     }
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   if(digits <= 0)
      digits = 5;
   MqlTick tk;
   long msc = SymbolInfoTick(sym, tk) ? (long)tk.time_msc : (long)TimeCurrent() * 1000;
   WriteLine(h, TS(TimeCurrent()) + "," + IntegerToString(msc) + "," + (isOrder ? "ORDER" : "POSITION") + "," + ev + "," +
             IntegerToString((long)ticket) + "," + IntegerToString(magic) + "," + sym + "," + type + "," + D(vol, 2) + "," +
             D(price, digits) + "," + D(sl, digits) + "," + D(tp, digits) + "," +
             D(SymbolInfoDouble(sym, SYMBOL_BID), digits) + "," + D(SymbolInfoDouble(sym, SYMBOL_ASK), digits));
  }

void Snapshot()
  {
   ulong  cT[];
   bool   cO[];
   string cS[], cY[];
   long   cM[];
   double cV[], cP[], cL[], cTP[];
   int n = 0;

   int pt = PositionsTotal();
   for(int i = 0; i < pt; i++)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      ArrayResize(cT, n + 1); ArrayResize(cO, n + 1); ArrayResize(cS, n + 1); ArrayResize(cY, n + 1);
      ArrayResize(cV, n + 1); ArrayResize(cP, n + 1); ArrayResize(cL, n + 1); ArrayResize(cTP, n + 1);
      ArrayResize(cM, n + 1);
      cT[n] = t; cO[n] = false;
      cM[n] = PositionGetInteger(POSITION_MAGIC);
      cS[n] = PositionGetString(POSITION_SYMBOL);
      cY[n] = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL";
      cV[n] = PositionGetDouble(POSITION_VOLUME);
      cP[n] = PositionGetDouble(POSITION_PRICE_OPEN);
      cL[n] = PositionGetDouble(POSITION_SL);
      cTP[n] = PositionGetDouble(POSITION_TP);
      n++;
     }
   int ot = OrdersTotal();
   for(int i = 0; i < ot; i++)
     {
      ulong t = OrderGetTicket(i);
      if(t == 0)
         continue;
      ArrayResize(cT, n + 1); ArrayResize(cO, n + 1); ArrayResize(cS, n + 1); ArrayResize(cY, n + 1);
      ArrayResize(cV, n + 1); ArrayResize(cP, n + 1); ArrayResize(cL, n + 1); ArrayResize(cTP, n + 1);
      ArrayResize(cM, n + 1);
      cT[n] = t; cO[n] = true;
      cM[n] = OrderGetInteger(ORDER_MAGIC);
      cS[n] = OrderGetString(ORDER_SYMBOL);
      string ty = EnumToString((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE));
      StringReplace(ty, "ORDER_TYPE_", "");
      cY[n] = ty;
      cV[n] = OrderGetDouble(ORDER_VOLUME_CURRENT);
      cP[n] = OrderGetDouble(ORDER_PRICE_OPEN);
      cL[n] = OrderGetDouble(ORDER_SL);
      cTP[n] = OrderGetDouble(ORDER_TP);
      n++;
     }

   int h = INVALID_HANDLE;
   for(int i = 0; i < n; i++)
     {
      int j = FindSnap(cT[i], cO[i]);
      if(!g_snapInit)
         WriteEvent(h, "EXISTING", cO[i], cT[i], cM[i], cS[i], cY[i], cV[i], cP[i], cL[i], cTP[i]);
      else if(j < 0)
         WriteEvent(h, "NEW", cO[i], cT[i], cM[i], cS[i], cY[i], cV[i], cP[i], cL[i], cTP[i]);
      else if(g_sVol[j] != cV[i] || g_sPrice[j] != cP[i] || g_sSL[j] != cL[i] || g_sTP[j] != cTP[i])
         WriteEvent(h, "MODIFY", cO[i], cT[i], cM[i], cS[i], cY[i], cV[i], cP[i], cL[i], cTP[i]);
     }
   for(int j = 0; j < ArraySize(g_sTicket); j++)
     {
      bool still = false;
      for(int i = 0; i < n; i++)
         if(cT[i] == g_sTicket[j] && cO[i] == g_sIsOrder[j]) { still = true; break; }
      if(!still)
         WriteEvent(h, "GONE", g_sIsOrder[j], g_sTicket[j], g_sMagic[j], g_sSym[j], g_sType[j], g_sVol[j], g_sPrice[j], g_sSL[j], g_sTP[j]);
     }
   if(h != INVALID_HANDLE)
      FileClose(h);

   ArrayResize(g_sTicket, n); ArrayResize(g_sIsOrder, n); ArrayResize(g_sSym, n); ArrayResize(g_sType, n);
   ArrayResize(g_sVol, n); ArrayResize(g_sPrice, n); ArrayResize(g_sSL, n); ArrayResize(g_sTP, n);
   ArrayResize(g_sMagic, n);
   for(int i = 0; i < n; i++)
     {
      g_sTicket[i] = cT[i]; g_sIsOrder[i] = cO[i]; g_sSym[i] = cS[i]; g_sType[i] = cY[i]; g_sMagic[i] = cM[i];
      g_sVol[i] = cV[i]; g_sPrice[i] = cP[i]; g_sSL[i] = cL[i]; g_sTP[i] = cTP[i];
     }
   g_snapInit = true;
  }

//+------------------------------------------------------------------+
bool AllSymbolsReady()
  {
   string syms[];
   BarSymbols(syms);
   bool ok = true;
   for(int i = 0; i < ArraySize(syms); i++)
      if(!SymbolReady(syms[i]))
         ok = false;
   return ok;
  }

int OnInit()
  {
   string dir = InpUseCommonFolder ? TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files"
                                   : TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files";
   // EA co the duoc khoi dong lai (doi tham so/khung) ma bien toan cuc van giu gia tri cu
   ArrayResize(g_ind, 0);
   ArrayResize(g_bot, 0);
   ArrayResize(g_bbSym, 0);
   ArrayResize(g_bbLast, 0);
   ArrayResize(g_sMagic, 0);
   ResetReplay();
   g_ordersDirty = false;
   ArrayResize(g_loggedDeals, 0);
   ArrayResize(g_sTicket, 0); ArrayResize(g_sIsOrder, 0); ArrayResize(g_sSym, 0); ArrayResize(g_sType, 0);
   ArrayResize(g_sVol, 0); ArrayResize(g_sPrice, 0); ArrayResize(g_sSL, 0); ArrayResize(g_sTP, 0);
   g_initialDone = false;
   g_snapInit = false;
   g_lastDealTime = 0;
   g_lastBarsExport = 0;
   g_waitTicks = 0;
   PrintFormat("[TradeLogger] Tai khoan %I64d (%s), trade_allowed=%s. File se ghi vao %s",
               AccountInfoInteger(ACCOUNT_LOGIN), AccountInfoString(ACCOUNT_SERVER),
               AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) ? "true" : "false (investor)", dir);
   EventSetTimer(MathMax(1, InpTimerSeconds));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   for(int i = 0; i < ArraySize(g_ind); i++)
     {
      IndicatorRelease(g_ind[i].atr);   IndicatorRelease(g_ind[i].rsi);
      IndicatorRelease(g_ind[i].ema20); IndicatorRelease(g_ind[i].ema50);
      IndicatorRelease(g_ind[i].ema200); IndicatorRelease(g_ind[i].bb);
      IndicatorRelease(g_ind[i].macd);  IndicatorRelease(g_ind[i].stoch);
     }
   for(int i = 0; i < ArraySize(g_bot); i++)
     {
      IndicatorRelease(g_bot[i].emaF); IndicatorRelease(g_bot[i].emaS);
      IndicatorRelease(g_bot[i].f1F);  IndicatorRelease(g_bot[i].f1S);
      IndicatorRelease(g_bot[i].f2F);  IndicatorRelease(g_bot[i].f2S);
      IndicatorRelease(g_bot[i].cci);
     }
  }

void OnTimer()
  {
   if(!g_initialDone)
     {
      // Lan dau: doi chi bao cua moi symbol tinh xong roi moi dump toan bo
      // Doi toi da ~5 phut; qua thoi gian do van ghi file (dac trung nao chua co se de trong)
      int maxWait = MathMax(1, 300 / MathMax(1, InpTimerSeconds));
      if(!AllSymbolsReady() && g_waitTicks < maxWait)
        {
         if(g_waitTicks % 12 == 0)
            PrintFormat("[TradeLogger] Dang cho du lieu (%d/%d): %s", g_waitTicks, maxWait, g_notReady);
         g_waitTicks++;
         return;
        }
      if(g_waitTicks >= maxWait)
         PrintFormat("[TradeLogger] Het thoi gian cho, van ghi file. Con thieu: %s", g_notReady);
      DumpSymbols();
      DumpAllDeals();
      DumpOrders();
      if(InpExportBars)
         ExportBars();
      if(InpExportBotBars)
         ExportBotBars();
      Snapshot();
      g_initialDone = true;
      return;
     }

   Snapshot();
   if(AppendNewDeals())
      g_ordersDirty = true;
   // ghi lai orders/symbols o nhip timer, khong ghi moi deal (ro DCA dong 20 lenh cung luc)
   if(g_ordersDirty)
     {
      DumpOrders();
      DumpSymbols();
      g_ordersDirty = false;
     }
   if(InpExportBotBars)
      ExportBotBars();
   if(InpExportBars && TimeCurrent() - g_lastBarsExport >= InpBarsRefreshHours * 3600)
      ExportBars();
  }

//+------------------------------------------------------------------+
//| Bat su kien ngay khi xay ra (khong phai doi timer 5 giay):        |
//| deal moi -> ghi kem bid/ask/EMA tuc thoi; sua SL/TP -> events.    |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(!g_initialDone)
      return;
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      if(AppendNewDeals(true))
         g_ordersDirty = true;
      Snapshot();
     }
   else if(trans.type == TRADE_TRANSACTION_POSITION || trans.type == TRADE_TRANSACTION_ORDER_ADD ||
           trans.type == TRADE_TRANSACTION_ORDER_UPDATE || trans.type == TRADE_TRANSACTION_ORDER_DELETE)
      Snapshot();
  }

void OnTick() {}
//+------------------------------------------------------------------+
