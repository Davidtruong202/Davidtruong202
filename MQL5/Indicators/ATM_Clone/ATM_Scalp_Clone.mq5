//+------------------------------------------------------------------+
//|                                            ATM_Scalp_Clone.mq5   |
//| Ban sao DON GIAN logic vao lenh cua chi bao DTRADE$ ATM SCALP AI |
//| (tim bang phan tich buffer, docs/atm_scalp_ai/PHAN_TICH.md):     |
//|  BUY khi (SELL doi xung):                                        |
//|   1 EMA21 > EMA55          2 ADX(14) Wilder > 20                 |
//|   3 close > EMA9           4 EMA9 > EMA21                        |
//|   5 nen tang               6 close > high nen truoc              |
//|   7 trong 7 nen gan nhat co nen low <= EMA14 (nhip hoi)          |
//|   8 chua co lenh BUY (dang SELL -> dao chieu)                    |
//|  ENTRY = close, SL = 3 x ATR(14) Wilder, TP1/2/3 = 1R/2R/3R.     |
//|  Lenh ao dong khi cham SL hoac TP3; cham TP1 thi doi SL ve entry.|
//|                                                                  |
//| 0.20: them BO LOC (docs/atm_scalp_ai/CAI_TIEN.md) - tuy chon:    |
//|  - chi vao lenh trong khung gio server [InpHourStart, InpHourEnd)|
//|  - xu huong khung lon cung chieu (EMA21 > EMA55 khung lon)       |
//|  Tin hieu bi loc ve mui ten XAM. Tu tinh ket qua lenh ao tren    |
//|  lich su (WR, R/lenh) cho ban goc va ban co loc.                 |
//|                                                                  |
//| CHI BAO: chi ve, KHONG dat lenh.                                 |
//+------------------------------------------------------------------+
#property copyright "ATM clone test"
#property version   "0.20"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

input group "Hiển thị & so sánh"
input int    InpHistoryBars   = 7000;                      // Số nến lịch sử vẽ lại / thống kê
input int    InpWarmupBars    = 600;                       // Nến khởi động cho EMA/ATR/ADX
input int    InpLineBars      = 15;                        // Độ dài đường ENTRY/SL/TP (nến)
input bool   InpCompare       = true;                      // So với chỉ báo gốc
input string InpOrigIndicator = "DTRADE$ - ATM SCALP AI";  // Tên chỉ báo gốc (trong MQL5\Indicators)
input bool   InpUseOrigState  = true;                      // Khi so sánh: dùng trạng thái lệnh (b2) của bản gốc cho điều kiện 8
input int    InpMaxMismatch   = 30;                        // Số nến lệch in ra tab Experts

input group "Tham số quy tắc"
input double InpAdxMin        = 20;                        // ADX tối thiểu
input double InpSlAtr         = 3.0;                       // SL = x lần ATR
input int    InpPullbackBars  = 7;                         // Cửa sổ nhịp hồi (số nến, tính cả nến hiện tại)

input group "Bộ lọc cải tiến"
input bool   InpHourFilter    = true;                      // Chỉ vào lệnh trong khung giờ server
input int    InpHourStart     = 0;                         // Giờ bắt đầu (server, tính cả)
input int    InpHourEnd       = 7;                         // Giờ kết thúc (server, không tính)
input bool   InpHtfFilter     = true;                      // Xu hướng khung lớn cùng chiều
input ENUM_TIMEFRAMES InpHtf  = PERIOD_CURRENT;            // Khung lớn (CURRENT = tự chọn: M1-M3→M15, M4-M10→H1, M12-M30→H4, H1+→D1)
input bool   InpShowFiltered  = true;                      // Vẽ tín hiệu bị lọc (mũi tên xám)
input double InpSpreadCost    = 0;                         // Spread trừ vào thống kê (giá, 0 = spread hiện tại)
input bool   InpAlert         = true;                      // Báo Alert khi có tín hiệu (đã lọc) mới

int hE9 = INVALID_HANDLE, hE14 = INVALID_HANDLE, hE21 = INVALID_HANDLE, hE55 = INVALID_HANDLE;
int hADX = INVALID_HANDLE, hOrig = INVALID_HANDLE, hH21 = INVALID_HANDLE, hH55 = INVALID_HANDLE;
ENUM_TIMEFRAMES g_htf = PERIOD_H1;
datetime g_lastBar = 0;
bool     g_doneHistory = false;
string   PFX = "ATMC_";

//--- lenh ao
struct VPos
  {
   int    dir;
   double e, sl, t1, t2, t3, R;
   bool   tp1, tp2;
  };
struct VStat
  {
   int    n, win;
   double sumR, sumCost;
  };

//+------------------------------------------------------------------+
bool IsSig(const double v) { return v != EMPTY_VALUE && v != 0 && MathIsValidNumber(v); }

string LogName()
  {
   return "TradeLogger\\ATM Clone\\ATM Clone_compare_" + _Symbol + "_" + StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period), 7) + ".csv";
  }

ENUM_TIMEFRAMES AutoHtf()
  {
   int m = PeriodSeconds(_Period) / 60;
   if(m <= 3)  return PERIOD_M15;
   if(m <= 10) return PERIOD_H1;
   if(m <= 30) return PERIOD_H4;
   return PERIOD_D1;
  }

void VOpen(VPos &p, const int dir, const double e, const double R)
  {
   p.dir = dir; p.e = e; p.R = R; p.tp1 = false; p.tp2 = false;
   p.sl = e - dir * R; p.t1 = e + dir * R; p.t2 = e + dir * 2 * R; p.t3 = e + dir * 3 * R;
  }

//--- ket qua R (chot 1/3 moi TP, sau TP1 SL ve entry)
void VClose(VPos &p, VStat &st, const double res, const double cost)
  {
   st.n++;
   if(p.tp1) st.win++;
   st.sumR += res;
   st.sumCost += cost / p.R;
   p.dir = 0;
  }

//--- kiem tra SL/TP trong nen; SL va TP cung nen -> tinh SL
void VStep(VPos &p, VStat &st, const MqlRates &b, const double cost)
  {
   if(p.dir == 0) return;
   int d = p.dir;
   bool hitSL = d > 0 ? b.low <= p.sl : b.high >= p.sl;
   if(hitSL) { VClose(p, st, !p.tp1 ? -1.0 : (p.tp2 ? 1.0 : 1.0 / 3.0), cost); return; }
   bool h3 = d > 0 ? b.high >= p.t3 : b.low <= p.t3;
   if(h3) { p.tp1 = true; p.tp2 = true; VClose(p, st, 2.0, cost); return; }
   if(!p.tp1 && (d > 0 ? b.high >= p.t1 : b.low <= p.t1)) { p.tp1 = true; p.sl = p.e; }
   if(p.tp1 && !p.tp2 && (d > 0 ? b.high >= p.t2 : b.low <= p.t2)) p.tp2 = true;
  }

//--- dong lenh khi dao chieu tai gia px
void VReverse(VPos &p, VStat &st, const double px, const double cost)
  {
   if(p.dir == 0) return;
   double pr = (px - p.e) * p.dir / p.R;
   //--- sau TP1 con 2/3 khoi luong, sau TP2 con 1/3
   double res = !p.tp1 ? pr : (1.0 / 3.0 + (p.tp2 ? 2.0 / 3.0 + pr / 3.0 : 2.0 * pr / 3.0));
   VClose(p, st, res, cost);
  }

string StatStr(const VStat &st)
  {
   if(st.n == 0) return "0 lenh";
   return StringFormat("%d lenh, WR(TP1) %.1f%%, R/lenh %+.3f (sau spread %+.3f), tong %+.1fR",
                       st.n, 100.0 * st.win / st.n, st.sumR / st.n, (st.sumR - st.sumCost) / st.n, st.sumR - st.sumCost);
  }

void DrawSignal(const datetime t, const datetime tEnd, const int dir, const double low, const double high,
                const VPos &p, const bool filteredOut)
  {
   string id = PFX + IntegerToString((long)t) + "_";
   if(ObjectFind(0, id + "A") >= 0)
      return;
   ObjectCreate(0, id + "A", dir > 0 ? OBJ_ARROW_BUY : OBJ_ARROW_SELL, 0, t, dir > 0 ? low : high);
   ObjectSetInteger(0, id + "A", OBJPROP_COLOR, filteredOut ? clrDimGray : (dir > 0 ? clrLime : clrRed));
   ObjectSetInteger(0, id + "A", OBJPROP_WIDTH, filteredOut ? 1 : 2);
   ObjectSetString(0, id + "A", OBJPROP_TOOLTIP, filteredOut ? "Tin hieu bi loc" : (dir > 0 ? "BUY" : "SELL"));
   if(filteredOut)
      return;
   string nm[5] = {"E", "SL", "T1", "T2", "T3"};
   double pr[5];
   pr[0] = p.e; pr[1] = p.e - dir * p.R; pr[2] = p.t1; pr[3] = p.t2; pr[4] = p.t3;
   color  cl[5] = {clrWhite, clrRed, clrLime, clrLime, clrLime};
   for(int k = 0; k < 5; k++)
     {
      ObjectCreate(0, id + nm[k], OBJ_TREND, 0, t, pr[k], tEnd, pr[k]);
      ObjectSetInteger(0, id + nm[k], OBJPROP_COLOR, cl[k]);
      ObjectSetInteger(0, id + nm[k], OBJPROP_STYLE, k == 0 ? STYLE_SOLID : STYLE_DOT);
      ObjectSetInteger(0, id + nm[k], OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, id + nm[k], OBJPROP_SELECTABLE, false);
      ObjectSetString(0, id + nm[k], OBJPROP_TOOLTIP, nm[k] + " " + DoubleToString(pr[k], _Digits));
     }
  }

//--- xu huong khung lon tai luc nen t vua dong: +1 / -1 / 0 (chua co du lieu)
int HtfTrend(const datetime tClose)
  {
   int sh = iBarShift(_Symbol, g_htf, tClose, false);
   if(sh < 0) return 0;
   double a[1], b[1];
   if(CopyBuffer(hH21, 0, sh + 1, 1, a) != 1 || CopyBuffer(hH55, 0, sh + 1, 1, b) != 1) return 0;
   return a[0] > b[0] ? 1 : (a[0] < b[0] ? -1 : 0);
  }

bool PassFilters(const datetime barTime, const int dir)
  {
   if(InpHourFilter)
     {
      MqlDateTime mt;
      TimeToStruct(barTime, mt);
      bool in = InpHourStart <= InpHourEnd ? (mt.hour >= InpHourStart && mt.hour < InpHourEnd)
                                           : (mt.hour >= InpHourStart || mt.hour < InpHourEnd);
      if(!in) return false;
     }
   if(InpHtfFilter && HtfTrend(barTime + (datetime)PeriodSeconds(_Period)) != dir)
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//| Tinh lai toan bo cua so N nen da dong (cu -> moi).                |
//| live = true: chi hanh dong voi nen moi nhat; false: ve + thong ke |
//+------------------------------------------------------------------+
bool Recompute(const bool live)
  {
   int N = InpHistoryBars + InpWarmupBars;
   int avail = Bars(_Symbol, _Period) - 2;
   if(avail < 200)
      return false;
   if(N > avail)
      N = avail;

   MqlRates r[];
   double e9[], e14[], e21[], e55[], adx[], ob0[], ob1[], ob2[];
   ArraySetAsSeries(r, false);
   if(CopyRates(_Symbol, _Period, 1, N, r) != N) return false;
   if(CopyBuffer(hE9, 0, 1, N, e9) != N) return false;
   if(CopyBuffer(hE14, 0, 1, N, e14) != N) return false;
   if(CopyBuffer(hE21, 0, 1, N, e21) != N) return false;
   if(CopyBuffer(hE55, 0, 1, N, e55) != N) return false;
   if(CopyBuffer(hADX, 0, 1, N, adx) != N) return false;
   if(InpHtfFilter && (BarsCalculated(hH21) <= 0 || BarsCalculated(hH55) <= 0)) return false;
   bool cmp = InpCompare && hOrig != INVALID_HANDLE;
   if(cmp)
     {
      if(CopyBuffer(hOrig, 0, 1, N, ob0) != N || CopyBuffer(hOrig, 1, 1, N, ob1) != N ||
         CopyBuffer(hOrig, 2, 1, N, ob2) != N)
         cmp = false;
     }

   //--- ATR(14) kieu Wilder
   double atr[];
   ArrayResize(atr, N);
   double s = 0;
   for(int i = 0; i < N; i++)
     {
      double tr = (i == 0) ? r[i].high - r[i].low
                           : MathMax(r[i].high, r[i - 1].close) - MathMin(r[i].low, r[i - 1].close);
      if(i < 14) { s += tr; atr[i] = s / (i + 1); }
      else       atr[i] = (atr[i - 1] * 13.0 + tr) / 14.0;
     }
   double cost = InpSpreadCost > 0 ? InpSpreadCost
                                   : SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   VPos  pRaw, pFil;
   VStat sRaw, sFil;
   ZeroMemory(pRaw); ZeroMemory(pFil); ZeroMemory(sRaw); ZeroMemory(sFil);
   int tp = 0, fp = 0, fn = 0, origFirst = -1, nMis = 0;
   string mis = "";
   int fh = INVALID_HANDLE;
   if(!live)
     {
      fh = FileOpen(LogName(), FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ);
      if(fh != INVALID_HANDLE)
         FileWriteString(fh, "bar_time,clone,orig,clone_loc\r\n");
     }
   if(cmp)
      for(int i = 0; i < N; i++)
         if(IsSig(ob0[i]) || IsSig(ob1[i])) { origFirst = i; break; }

   int start = MathMax(InpWarmupBars, InpPullbackBars + 1);
   for(int i = start; i < N; i++)
     {
      //--- 1) lenh ao dang mo: SL / TP trong nen i
      VStep(pRaw, sRaw, r[i], cost);
      VStep(pFil, sFil, r[i], cost);

      //--- 2) tin hieu goc (dieu kien 1-7), dk 8 xet rieng cho tung ban
      int cond = 0;
      for(int d = 1; d >= -1; d -= 2)
        {
         if((e21[i] - e55[i]) * d <= 0) continue;                    // dk 1
         if(adx[i] <= InpAdxMin) continue;                           // dk 2
         if((r[i].close - e9[i]) * d <= 0) continue;                 // dk 3
         if((e9[i] - e21[i]) * d <= 0) continue;                     // dk 4
         if((r[i].close - r[i].open) * d <= 0) continue;             // dk 5
         if(d > 0 ? r[i].close <= r[i - 1].high : r[i].close >= r[i - 1].low) continue;  // dk 6
         bool pull = false;                                          // dk 7
         for(int j = i - InpPullbackBars + 1; j <= i && !pull; j++)
            pull = d > 0 ? r[j].low <= e14[j] : r[j].high >= e14[j];
         if(!pull) continue;
         cond = d;
         break;
        }

      //--- ban sao khong loc (de so sanh voi ban goc)
      int posRaw = pRaw.dir;
      if(cmp && InpUseOrigState && origFirst >= 0 && i >= origFirst)
         posRaw = (MathIsValidNumber(ob2[i - 1]) && ob2[i - 1] != EMPTY_VALUE) ? (int)MathRound(ob2[i - 1]) : 0;
      int sig = (cond != 0 && posRaw != cond) ? cond : 0;
      if(sig != 0 && pRaw.dir != sig)
        {
         VReverse(pRaw, sRaw, r[i].close, cost);
         VOpen(pRaw, sig, r[i].close, InpSlAtr * atr[i]);
        }

      //--- ban co loc
      int sigF = 0;
      bool filteredOut = false;
      if(cond != 0 && pFil.dir != cond)
        {
         if(PassFilters(r[i].time, cond)) sigF = cond;
         else filteredOut = true;
        }
      if(sigF != 0)
        {
         VReverse(pFil, sFil, r[i].close, cost);
         VOpen(pFil, sigF, r[i].close, InpSlAtr * atr[i]);
        }

      bool newest = (i == N - 1);
      if(!live || newest)
        {
         datetime tEnd = r[i].time + (datetime)(InpLineBars * PeriodSeconds(_Period));
         if(sigF != 0)
            DrawSignal(r[i].time, tEnd, sigF, r[i].low, r[i].high, pFil, false);
         else if(filteredOut && InpShowFiltered)
            DrawSignal(r[i].time, tEnd, cond, r[i].low, r[i].high, pFil, true);
        }
      if(live && newest && sigF != 0)
        {
         string msg = StringFormat("ATM clone %s %s %s entry=%.3f SL=%.3f TP1=%.3f TP2=%.3f TP3=%.3f", _Symbol,
                                   StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period), 7), sigF > 0 ? "BUY" : "SELL",
                                   pFil.e, pFil.sl, pFil.t1, pFil.t2, pFil.t3);
         Print("[ATM clone] ", msg);
         if(InpAlert) Alert(msg);
        }

      //--- 3) so sanh ban KHONG loc voi ban goc
      int orig = 0;
      if(cmp)
         orig = IsSig(ob0[i]) ? 1 : (IsSig(ob1[i]) ? -1 : 0);
      if(cmp && origFirst >= 0 && i >= origFirst)
        {
         if(sig != 0 && sig == orig) tp++;
         else
           {
            if(sig != 0) fp++;
            if(orig != 0) fn++;
            if((sig != 0 || orig != 0) && nMis < InpMaxMismatch)
              {
               mis += StringFormat("\n   %s  clone=%s  goc=%s  adx=%.1f", TimeToString(r[i].time),
                                   sig > 0 ? "BUY " : (sig < 0 ? "SELL" : " -  "), orig > 0 ? "BUY " : (orig < 0 ? "SELL" : " -  "), adx[i]);
               nMis++;
              }
           }
        }
      if(fh != INVALID_HANDLE && (sig != 0 || orig != 0 || sigF != 0))
         FileWriteString(fh, TimeToString(r[i].time, TIME_DATE | TIME_MINUTES) + "," + IntegerToString(sig) + "," +
                         IntegerToString(orig) + "," + IntegerToString(sigF) + "\r\n");
     }
   if(fh != INVALID_HANDLE)
      FileClose(fh);

   if(!live)
     {
      PrintFormat("[ATM clone] Lenh ao tren %d nen (spread %.3f): KHONG loc: %s", N - start, cost, StatStr(sRaw));
      PrintFormat("[ATM clone]                                 CO loc (gio %s, khung lon %s): %s",
                  InpHourFilter ? StringFormat("%02d-%02dh", InpHourStart, InpHourEnd) : "tat",
                  InpHtfFilter ? StringSubstr(EnumToString(g_htf), 7) : "tat", StatStr(sFil));
      if(cmp && origFirst >= 0)
        {
         PrintFormat("[ATM clone] So voi chi bao goc tu %s (ban KHONG loc): TRUNG %d | clone thua %d | clone thieu %d  "
                     "=> bat duoc %.0f%% tin hieu goc, %.0f%% tin hieu clone la dung. File: Common\\Files\\%s",
                     TimeToString(r[origFirst].time), tp, fp, fn,
                     tp + fn > 0 ? 100.0 * tp / (tp + fn) : 0, tp + fp > 0 ? 100.0 * tp / (tp + fp) : 0, LogName());
         if(nMis > 0)
            Print("[ATM clone] Cac nen lech (toi da ", InpMaxMismatch, "):", mis);
        }
      else if(InpCompare)
         Print("[ATM clone] Khong doc duoc tin hieu chi bao goc - chi ve tin hieu clone.");
     }
   return true;
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   hE9  = iMA(_Symbol, _Period, 9, 0, MODE_EMA, PRICE_CLOSE);
   hE14 = iMA(_Symbol, _Period, 14, 0, MODE_EMA, PRICE_CLOSE);
   hE21 = iMA(_Symbol, _Period, 21, 0, MODE_EMA, PRICE_CLOSE);
   hE55 = iMA(_Symbol, _Period, 55, 0, MODE_EMA, PRICE_CLOSE);
   hADX = iADXWilder(_Symbol, _Period, 14);
   if(hE9 == INVALID_HANDLE || hE14 == INVALID_HANDLE || hE21 == INVALID_HANDLE || hE55 == INVALID_HANDLE || hADX == INVALID_HANDLE)
      return INIT_FAILED;
   g_htf = (InpHtf == PERIOD_CURRENT) ? AutoHtf() : InpHtf;
   if(InpHtfFilter)
     {
      hH21 = iMA(_Symbol, g_htf, 21, 0, MODE_EMA, PRICE_CLOSE);
      hH55 = iMA(_Symbol, g_htf, 55, 0, MODE_EMA, PRICE_CLOSE);
      if(hH21 == INVALID_HANDLE || hH55 == INVALID_HANDLE)
         return INIT_FAILED;
     }
   if(InpCompare)
     {
      hOrig = iCustom(_Symbol, _Period, InpOrigIndicator);
      if(hOrig == INVALID_HANDLE)
         PrintFormat("[ATM clone] Khong mo duoc chi bao goc '%s' - van chay, chi khong so sanh", InpOrigIndicator);
     }
   FolderCreate("TradeLogger", FILE_COMMON);
   FolderCreate("TradeLogger\\ATM Clone", FILE_COMMON);
   g_doneHistory = false;
   g_lastBar = 0;
   EventSetTimer(3);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, PFX);
   int h[8];
   h[0] = hE9; h[1] = hE14; h[2] = hE21; h[3] = hE55; h[4] = hADX; h[5] = hOrig; h[6] = hH21; h[7] = hH55;
   for(int i = 0; i < 8; i++)
      if(h[i] != INVALID_HANDLE)
         IndicatorRelease(h[i]);
  }

//--- ve lich su lan dau khi du lieu/chi bao san sang (ca khi thi truong dong cua)
void OnTimer()
  {
   if(g_doneHistory)
      return;
   if(Recompute(false))
     {
      g_doneHistory = true;
      g_lastBar = iTime(_Symbol, _Period, 0);
      ChartRedraw();
     }
  }

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[],
                const double &high[], const double &low[], const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
  {
   if(!g_doneHistory)
      return rates_total;           // lich su duoc ve trong OnTimer khi du lieu san sang
   datetime b = iTime(_Symbol, _Period, 0);
   if(b != g_lastBar)
     {
      g_lastBar = b;
      Recompute(true);
     }
   return rates_total;
  }
//+------------------------------------------------------------------+
