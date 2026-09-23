//+------------------------------------------------------------------+
//|                                                  TradeLogger.mq5 |
//| Ghi lai toan bo lenh cua tai khoan dang dang nhap (ke ca dang    |
//| nhap bang mat khau investor / Passview) kem boi canh thi truong  |
//| tai thoi diem vao lenh, xuat ra CSV de phan tich bang            |
//| tools/analyze_trades.py.                                         |
//|                                                                  |
//| EA KHONG dat lenh, chi doc lich su + trang thai tai khoan.       |
//+------------------------------------------------------------------+
#property copyright "TradeLogger"
#property version   "1.00"
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

//--- snapshot vi the / lenh cho (mang song song)
ulong    g_sTicket[];
bool     g_sIsOrder[];
string   g_sSym[];
string   g_sType[];
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

bool IndReady(const int k)
  {
   int h[8];
   h[0] = g_ind[k].atr;   h[1] = g_ind[k].rsi;  h[2] = g_ind[k].ema20; h[3] = g_ind[k].ema50;
   h[4] = g_ind[k].ema200; h[5] = g_ind[k].bb;  h[6] = g_ind[k].macd;  h[7] = g_ind[k].stoch;
   for(int i = 0; i < 8; i++)
      if(h[i] == INVALID_HANDLE || BarsCalculated(h[i]) <= 0)
         return false;
   return true;
  }

bool SymbolReady(const string sym)
  {
   return IndReady(IndIndex(sym, InpFeatureTF)) && IndReady(IndIndex(sym, InpBiasTF));
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
//| Deals                                                             |
//+------------------------------------------------------------------+
string DealHeader()
  {
   return "deal_ticket,order_ticket,position_id,time,time_msc,symbol,type,entry,volume,price,sl,tp,"
          "profit,commission,swap,fee,magic,reason,comment," + FeatureHeader();
  }

bool IsLogged(const ulong ticket)
  {
   int n = ArraySize(g_loggedDeals);
   for(int i = n - 1; i >= 0; i--)
      if(g_loggedDeals[i] == ticket)
         return true;
   return false;
  }

bool DealLine(const ulong t, string &line)
  {
   long type = HistoryDealGetInteger(t, DEAL_TYPE);
   if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL)
      return false; // bo qua nap/rut tien, credit...

   string sym  = HistoryDealGetString(t, DEAL_SYMBOL);
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
          IntegerToString(HistoryDealGetInteger(t, DEAL_MAGIC)) + "," +
          EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(t, DEAL_REASON)) + "," +
          Clean(HistoryDealGetString(t, DEAL_COMMENT)) + ",";

   //--- dac trung o nen da dong ngay truoc thoi diem khop lenh
   string f;
   int s = iBarShift(sym, InpFeatureTF, tm, false);
   if(s >= 0 && Features(sym, s + 1, f))
      line += f;
   else
      line += EmptyFeatures();
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
   int total = HistoryDealsTotal(), written = 0;
   for(int i = 0; i < total; i++)
     {
      ulong t = HistoryDealGetTicket(i);
      string line;
      if(!DealLine(t, line))
         continue;
      WriteLine(h, line);
      written++;
      int n = ArraySize(g_loggedDeals);
      ArrayResize(g_loggedDeals, n + 1, 1000);
      g_loggedDeals[n] = t;
      g_lastDealTime = MathMax(g_lastDealTime, (datetime)HistoryDealGetInteger(t, DEAL_TIME));
     }
   FileClose(h);
   PrintFormat("[TradeLogger] Da ghi %d deal vao %s", written, FName("deals"));
  }

bool AppendNewDeals()
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
      if(!DealLine(t, line))
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
             "feature_tf,bias_tf,account_currency,account_leverage,server");
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
                Clean(AccountInfoString(ACCOUNT_SERVER)));
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
//| Theo doi vi the / lenh cho dang mo: moi, sua SL/TP, dong          |
//+------------------------------------------------------------------+
int FindSnap(const ulong ticket, const bool isOrder)
  {
   for(int i = 0; i < ArraySize(g_sTicket); i++)
      if(g_sTicket[i] == ticket && g_sIsOrder[i] == isOrder)
         return i;
   return -1;
  }

void WriteEvent(int &h, const string ev, const bool isOrder, const ulong ticket, const string sym,
                const string type, const double vol, const double price, const double sl, const double tp)
  {
   if(h == INVALID_HANDLE)
     {
      h = OpenOut(FName("events"), true);
      if(h == INVALID_HANDLE)
         return;
      if(FileSize(h) == 0)
         WriteLine(h, "time,kind,event,ticket,symbol,type,volume,price,sl,tp,bid,ask");
     }
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   if(digits <= 0)
      digits = 5;
   WriteLine(h, TS(TimeCurrent()) + "," + (isOrder ? "ORDER" : "POSITION") + "," + ev + "," +
             IntegerToString((long)ticket) + "," + sym + "," + type + "," + D(vol, 2) + "," +
             D(price, digits) + "," + D(sl, digits) + "," + D(tp, digits) + "," +
             D(SymbolInfoDouble(sym, SYMBOL_BID), digits) + "," + D(SymbolInfoDouble(sym, SYMBOL_ASK), digits));
  }

void Snapshot()
  {
   ulong  cT[];
   bool   cO[];
   string cS[], cY[];
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
      cT[n] = t; cO[n] = false;
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
      cT[n] = t; cO[n] = true;
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
         WriteEvent(h, "EXISTING", cO[i], cT[i], cS[i], cY[i], cV[i], cP[i], cL[i], cTP[i]);
      else if(j < 0)
         WriteEvent(h, "NEW", cO[i], cT[i], cS[i], cY[i], cV[i], cP[i], cL[i], cTP[i]);
      else if(g_sVol[j] != cV[i] || g_sPrice[j] != cP[i] || g_sSL[j] != cL[i] || g_sTP[j] != cTP[i])
         WriteEvent(h, "MODIFY", cO[i], cT[i], cS[i], cY[i], cV[i], cP[i], cL[i], cTP[i]);
     }
   for(int j = 0; j < ArraySize(g_sTicket); j++)
     {
      bool still = false;
      for(int i = 0; i < n; i++)
         if(cT[i] == g_sTicket[j] && cO[i] == g_sIsOrder[j]) { still = true; break; }
      if(!still)
         WriteEvent(h, "GONE", g_sIsOrder[j], g_sTicket[j], g_sSym[j], g_sType[j], g_sVol[j], g_sPrice[j], g_sSL[j], g_sTP[j]);
     }
   if(h != INVALID_HANDLE)
      FileClose(h);

   ArrayResize(g_sTicket, n); ArrayResize(g_sIsOrder, n); ArrayResize(g_sSym, n); ArrayResize(g_sType, n);
   ArrayResize(g_sVol, n); ArrayResize(g_sPrice, n); ArrayResize(g_sSL, n); ArrayResize(g_sTP, n);
   for(int i = 0; i < n; i++)
     {
      g_sTicket[i] = cT[i]; g_sIsOrder[i] = cO[i]; g_sSym[i] = cS[i]; g_sType[i] = cY[i];
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
  }

void OnTimer()
  {
   if(!g_initialDone)
     {
      // Lan dau: doi chi bao cua moi symbol tinh xong roi moi dump toan bo
      if(!AllSymbolsReady())
        {
         Print("[TradeLogger] Dang cho chi bao/du lieu lich su tai xong...");
         return;
        }
      DumpSymbols();
      DumpAllDeals();
      DumpOrders();
      if(InpExportBars)
         ExportBars();
      Snapshot();
      g_initialDone = true;
      return;
     }

   Snapshot();
   if(AppendNewDeals())
     {
      DumpOrders();
      DumpSymbols();
     }
   if(InpExportBars && TimeCurrent() - g_lastBarsExport >= InpBarsRefreshHours * 3600)
      ExportBars();
  }

void OnTick() {}
//+------------------------------------------------------------------+
