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
//| CHI BAO: chi ve mui ten + duong ENTRY/SL/TP, KHONG dat lenh.     |
//| Neu bat InpCompare: doc mui ten cua chi bao goc tren cung chart  |
//| de dem trung / lech, in ra tab Experts + file CSV.               |
//+------------------------------------------------------------------+
#property copyright "ATM clone test"
#property version   "0.11"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

input group "Hiển thị & so sánh"
input int    InpHistoryBars   = 7000;                      // Số nến lịch sử vẽ lại / so sánh
input int    InpWarmupBars    = 600;                       // Nến khởi động cho EMA/ATR/ADX
input int    InpLineBars      = 15;                        // Độ dài đường ENTRY/SL/TP (nến)
input bool   InpCompare       = true;                      // So với chỉ báo gốc
input string InpOrigIndicator = "DTRADE$ - ATM SCALP AI";  // Tên chỉ báo gốc (trong MQL5\Indicators)
input bool   InpUseOrigState  = true;                      // Khi so sánh: dùng trạng thái lệnh (b2) của bản gốc cho điều kiện 8
input bool   InpDrawOnlyWindow= true;                      // Khi so sánh: chỉ vẽ trong vùng bản gốc có tính
input int    InpMaxMismatch   = 30;                        // Số nến lệch in ra tab Experts

input group "Tham số quy tắc"
input double InpAdxMin        = 20;                        // ADX tối thiểu
input double InpSlAtr         = 3.0;                       // SL = x lần ATR
input int    InpPullbackBars  = 7;                         // Cửa sổ nhịp hồi (số nến, tính cả nến hiện tại)

int hE9 = INVALID_HANDLE, hE14 = INVALID_HANDLE, hE21 = INVALID_HANDLE, hE55 = INVALID_HANDLE;
int hADX = INVALID_HANDLE, hOrig = INVALID_HANDLE;
datetime g_lastBar = 0;
bool     g_doneHistory = false;
string   PFX = "ATMC_";

//--- trang thai lenh ao
int    vDir = 0;
double vEntry = 0, vSL = 0, vTP1 = 0, vTP2 = 0, vTP3 = 0;
bool   vTp1Hit = false;

//+------------------------------------------------------------------+
bool IsSig(const double v) { return v != EMPTY_VALUE && v != 0 && MathIsValidNumber(v); }

string LogName()
  {
   return "TradeLogger\\ATM Clone\\ATM Clone_compare_" + _Symbol + "_" + StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period), 7) + ".csv";
  }

void DrawSignal(const datetime t, const datetime tEnd, const int dir, const double low, const double high,
                const double e, const double sl, const double t1, const double t2, const double t3)
  {
   string id = PFX + IntegerToString((long)t) + "_";
   if(ObjectFind(0, id + "A") >= 0)
      return;
   ObjectCreate(0, id + "A", dir > 0 ? OBJ_ARROW_BUY : OBJ_ARROW_SELL, 0, t, dir > 0 ? low : high);
   ObjectSetInteger(0, id + "A", OBJPROP_COLOR, dir > 0 ? clrLime : clrRed);
   ObjectSetInteger(0, id + "A", OBJPROP_WIDTH, 2);
   string nm[5] = {"E", "SL", "T1", "T2", "T3"};
   double pr[5];
   pr[0] = e; pr[1] = sl; pr[2] = t1; pr[3] = t2; pr[4] = t3;
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

//+------------------------------------------------------------------+
//| Tinh lai toan bo cua so N nen da dong (cu -> moi), lenh ao chay   |
//| tu dau. live = true: chi hanh dong (ve/dat lenh/ghi) voi nen moi  |
//| nhat; false: ve + so sanh toan bo lich su.                        |
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
   bool cmp = InpCompare && hOrig != INVALID_HANDLE;
   if(cmp)
     {
      if(CopyBuffer(hOrig, 0, 1, N, ob0) != N || CopyBuffer(hOrig, 1, 1, N, ob1) != N ||
         CopyBuffer(hOrig, 2, 1, N, ob2) != N)
         cmp = false;
     }

   //--- ATR(14) kieu Wilder (khoi tao bang trung binh 14 TR dau, sau vai tram nen sai so ve 0)
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

   vDir = 0; vTp1Hit = false;
   int tp = 0, fp = 0, fn = 0, origFirst = -1, nMis = 0;
   string mis = "";
   int fh = INVALID_HANDLE;
   if(!live)
     {
      fh = FileOpen(LogName(), FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ);
      if(fh != INVALID_HANDLE)
         FileWriteString(fh, "bar_time,clone,orig,entry,sl,tp1,tp2,tp3\r\n");
     }
   if(cmp)
      for(int i = 0; i < N; i++)
         if(IsSig(ob0[i]) || IsSig(ob1[i])) { origFirst = i; break; }

   int start = MathMax(InpWarmupBars, InpPullbackBars + 1);
   for(int i = start; i < N; i++)
     {
      //--- 1) lenh ao dang mo: kiem tra SL / TP1 / TP3 trong nen i
      if(vDir > 0)
        {
         if(r[i].low <= vSL) vDir = 0;
         else if(r[i].high >= vTP3) vDir = 0;
         else if(!vTp1Hit && r[i].high >= vTP1) { vTp1Hit = true; vSL = vEntry; }
        }
      else if(vDir < 0)
        {
         if(r[i].high >= vSL) vDir = 0;
         else if(r[i].low <= vTP3) vDir = 0;
         else if(!vTp1Hit && r[i].low <= vTP1) { vTp1Hit = true; vSL = vEntry; }
        }

      //--- 2) tin hieu
      //    trang thai lenh cho dk 8: cua ban goc (khi so sanh) hoac lenh ao cua ban sao
      int posDir = vDir;
      if(cmp && InpUseOrigState && origFirst >= 0 && i >= origFirst)
         posDir = (MathIsValidNumber(ob2[i - 1]) && ob2[i - 1] != EMPTY_VALUE) ? (int)MathRound(ob2[i - 1]) : 0;
      int sig = 0;
      for(int d = 1; d >= -1; d -= 2)
        {
         if(posDir == d) continue;                                   // dk 8
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
         sig = d;
         break;
        }

      int orig = 0;
      if(cmp)
         orig = IsSig(ob0[i]) ? 1 : (IsSig(ob1[i]) ? -1 : 0);

      if(sig != 0)
        {
         double R = InpSlAtr * atr[i];
         vDir = sig; vEntry = r[i].close; vTp1Hit = false;
         vSL  = vEntry - sig * R;
         vTP1 = vEntry + sig * R; vTP2 = vEntry + sig * 2 * R; vTP3 = vEntry + sig * 3 * R;
         bool newest = (i == N - 1);
         bool inWin  = !(cmp && InpDrawOnlyWindow) || (origFirst >= 0 && i >= origFirst);
         if((!live && inWin) || newest)
           {
            datetime tEnd = r[i].time + (datetime)(InpLineBars * PeriodSeconds(_Period));
            DrawSignal(r[i].time, tEnd, sig, r[i].low, r[i].high, vEntry, vSL, vTP1, vTP2, vTP3);
           }
         if(live && newest)
           {
            PrintFormat("[ATM clone] %s %s entry=%.3f SL=%.3f TP1=%.3f TP2=%.3f TP3=%.3f | goc: %s",
                        TimeToString(r[i].time), sig > 0 ? "BUY" : "SELL", vEntry, vSL, vTP1, vTP2, vTP3,
                        orig == sig ? "TRUNG" : (orig == 0 ? "khong co" : "NGUOC"));
           }
        }

      //--- 3) so sanh (chi tinh tu tin hieu goc dau tien tro di)
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
      if(fh != INVALID_HANDLE && (sig != 0 || orig != 0))
         FileWriteString(fh, TimeToString(r[i].time, TIME_DATE | TIME_MINUTES) + "," + IntegerToString(sig) + "," +
                         IntegerToString(orig) + "," + (sig != 0 ? DoubleToString(vEntry, _Digits) + "," +
                         DoubleToString(vSL, _Digits) + "," + DoubleToString(vTP1, _Digits) + "," +
                         DoubleToString(vTP2, _Digits) + "," + DoubleToString(vTP3, _Digits) : ",,,,") + "\r\n");
     }
   if(fh != INVALID_HANDLE)
      FileClose(fh);

   if(!live)
     {
      if(cmp && origFirst >= 0)
         PrintFormat("[ATM clone] So voi chi bao goc tu %s: TRUNG %d | clone thua %d | clone thieu %d  "
                     "=> bat duoc %.0f%% tin hieu goc, %.0f%% tin hieu clone la dung. File: Common\\Files\\%s",
                     TimeToString(r[origFirst].time), tp, fp, fn,
                     tp + fn > 0 ? 100.0 * tp / (tp + fn) : 0, tp + fp > 0 ? 100.0 * tp / (tp + fp) : 0, LogName());
      if(cmp && origFirst >= 0 && nMis > 0)
         Print("[ATM clone] Cac nen lech (toi da ", InpMaxMismatch, "):", mis);
      else if(InpCompare)
         Print("[ATM clone] Khong doc duoc tin hieu chi bao goc (kiem tra InpOrigIndicator) - chi ve tin hieu clone.");
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
   int h[6];
   h[0] = hE9; h[1] = hE14; h[2] = hE21; h[3] = hE55; h[4] = hADX; h[5] = hOrig;
   for(int i = 0; i < 6; i++)
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
