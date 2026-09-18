//+------------------------------------------------------------------+
//|                                      MIK_EmaCross_Signal.mq5     |
//|  Gan len CHART CHINH. Toan bo logic tin hieu nam trong file nay: |
//|  EMA9 vs EMA20 tren gia (Close) + EMA9 vs WMA45 ap len RSI14.    |
//|  Ca 2 ve phai cung dong y moi phat tin hieu Buy/Sell; chi 1 ve   |
//|  gay la phat Exit. Tinh theo tung tick tren nen dang hinh thanh  |
//|  (khong doi dong nen) - dung theo dung tai lieu spec goc.        |
//|  Xay lai tu tai lieu mo ta (khong co source goc kem theo).       |
//+------------------------------------------------------------------+
#property copyright "Rebuilt from spec"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   5

#property indicator_label1  "EMA9"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  1

#property indicator_label2  "EMA20"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_width2  1

#property indicator_label3  "Buy"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrDodgerBlue

#property indicator_label4  "Sell"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed

#property indicator_label5  "Exit"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrGray

//====================================================================
// 1) Indi Characteristics
//====================================================================
input group "1) Indi Characteristics"
input int    InpEma9Period    = 9;    // Chu ky EMA9 tren chart
input int    InpEma20Period   = 20;   // Chu ky EMA20 tren chart
input int    InpRsiPeriod     = 14;   // Chu ky RSI
input int    InpRsiEmaPeriod  = 9;    // Chu ky EMA ap dung tren RSI
input int    InpRsiWmaPeriod  = 45;   // Chu ky WMA ap dung tren RSI
input int    InpArrowSize     = 2;    // Do day arrow Buy/Sell

//====================================================================
// 2) Filters - chua co, de trong theo dung spec (danh cho mo rong sau)
//====================================================================

//====================================================================
// 3) Entry / Signal
//====================================================================
input group "3) Entry / Signal"
input bool   InpShowArrows    = true;  // Bat/tat ve arrow Buy/Sell/Exit
input double InpArrowGapATR   = 0.5;   // Khoang cach arrow so voi nen, boi so ATR14

//====================================================================
// 4) Alert
//====================================================================
input group "4) Alert"
input bool   InpAlertPopup    = true;      // Popup alert trong terminal
input bool   InpAlertPush     = false;     // Push notification ra dien thoai
input bool   InpAlertSound    = false;     // Phat am thanh
input string InpSoundFile     = "alert.wav"; // Ten file am thanh (trong thu muc Sounds)

//====================================================================
// Buffers & globals
//====================================================================
double Ema9Buf[];
double Ema20Buf[];
double BuyBuf[];
double SellBuf[];
double ExitBuf[];

int rsiHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;
#define ATR_PERIOD_FIXED 14   // spec khong cho input rieng, dung co dinh ATR14 nhu tai lieu mo ta

datetime g_lastAlertBarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, Ema9Buf,  INDICATOR_DATA);
   SetIndexBuffer(1, Ema20Buf, INDICATOR_DATA);
   SetIndexBuffer(2, BuyBuf,   INDICATOR_DATA);
   SetIndexBuffer(3, SellBuf,  INDICATOR_DATA);
   SetIndexBuffer(4, ExitBuf,  INDICATOR_DATA);

   ArraySetAsSeries(Ema9Buf,  false);
   ArraySetAsSeries(Ema20Buf, false);
   ArraySetAsSeries(BuyBuf,   false);
   ArraySetAsSeries(SellBuf,  false);
   ArraySetAsSeries(ExitBuf,  false);

   PlotIndexSetInteger(2, PLOT_ARROW, 233); // mui ten len (Wingdings)
   PlotIndexSetInteger(3, PLOT_ARROW, 234); // mui ten xuong
   PlotIndexSetInteger(4, PLOT_ARROW, 251); // dau X
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, InpArrowSize);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, InpArrowSize);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, InpRsiPeriod, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATR_PERIOD_FIXED);
   if (rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
   {
      Print("MIK_EmaCross_Signal: khong tao duoc indicator handle");
      return INIT_FAILED;
   }

   IndicatorSetString(INDICATOR_SHORTNAME, "MIK EmaCross Signal");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if (rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if (atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
//| Trang thai 1 nen: 1=Buy, -1=Sell, 0=Flat/Exit                    |
//| Ca 2 ve (gia + RSI) phai cung dong y moi ra Buy/Sell              |
//+------------------------------------------------------------------+
int BarState(const int i, const double &e9[], const double &e20[],
             const double &re[], const double &rw[])
{
   bool priceBuy  = e9[i] > e20[i];
   bool priceSell = e9[i] < e20[i];
   bool rsiBuy    = re[i] > rw[i];
   bool rsiSell   = re[i] < rw[i];

   if (priceBuy  && rsiBuy)  return 1;
   if (priceSell && rsiSell) return -1;
   return 0;
}

void FireAlert(const int stCur, const double price)
{
   string txt;
   if (stCur == 1)       txt = "MIK EmaCross: BUY "  + _Symbol + " @ " + DoubleToString(price, _Digits);
   else if (stCur == -1) txt = "MIK EmaCross: SELL " + _Symbol + " @ " + DoubleToString(price, _Digits);
   else                    txt = "MIK EmaCross: EXIT " + _Symbol + " @ " + DoubleToString(price, _Digits);

   if (InpAlertPopup) Alert(txt);
   if (InpAlertPush)  SendNotification(txt);
   if (InpAlertSound) PlaySound(InpSoundFile);
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                 const int prev_calculated,
                 const datetime &time[],
                 const double &open[],
                 const double &high[],
                 const double &low[],
                 const double &close[],
                 const long &tick_volume[],
                 const long &volume[],
                 const int &spread[])
{
   int minBars = InpRsiPeriod + InpRsiWmaPeriod + InpEma20Period + 5;
   if (rates_total < minBars) return 0;

   double rsiRaw[];
   ArraySetAsSeries(rsiRaw, false);
   if (CopyBuffer(rsiHandle, 0, 0, rates_total, rsiRaw) <= 0) return 0;

   double atrVal[];
   ArraySetAsSeries(atrVal, false);
   CopyBuffer(atrHandle, 0, 0, rates_total, atrVal);

   // EMA(RSI) va WMA(RSI) la smoothing de quy/cua so - giu lai giua cac lan
   // goi OnCalculate de khong phai tinh lai tu dau moi tick.
   static double rsiEma[];
   static double rsiWma[];
   if (ArraySize(rsiEma) < rates_total) ArrayResize(rsiEma, rates_total);
   if (ArraySize(rsiWma) < rates_total) ArrayResize(rsiWma, rates_total);

   int start = (prev_calculated == 0) ? 0 : prev_calculated - 2;
   if (start < 0) start = 0;

   double kEma9   = 2.0 / (InpEma9Period   + 1.0);
   double kEma20  = 2.0 / (InpEma20Period  + 1.0);
   double kRsiEma = 2.0 / (InpRsiEmaPeriod + 1.0);
   int    wn      = InpRsiWmaPeriod;

   for (int i = start; i < rates_total; i++)
   {
      if (i == 0)
      {
         Ema9Buf[i]  = close[i];
         Ema20Buf[i] = close[i];
         rsiEma[i]   = rsiRaw[i];
      }
      else
      {
         Ema9Buf[i]  = close[i] * kEma9  + Ema9Buf[i-1]  * (1.0 - kEma9);
         Ema20Buf[i] = close[i] * kEma20 + Ema20Buf[i-1] * (1.0 - kEma20);
         rsiEma[i]   = rsiRaw[i] * kRsiEma + rsiEma[i-1] * (1.0 - kRsiEma);
      }

      if (i + 1 < wn)
      {
         rsiWma[i] = rsiRaw[i];
      }
      else
      {
         double sumW = 0, sumWX = 0;
         for (int k = 0; k < wn; k++)
         {
            double w = (wn - k);
            sumWX += w * rsiRaw[i - k];
            sumW  += w;
         }
         rsiWma[i] = sumWX / sumW;
      }

      BuyBuf[i]  = EMPTY_VALUE;
      SellBuf[i] = EMPTY_VALUE;
      ExitBuf[i] = EMPTY_VALUE;
   }

   // Chi ve/bat alert khi trang thai THUC SU doi so voi nen truoc (chong spam)
   int loopStart = MathMax(start, 1);
   for (int i = loopStart; i < rates_total; i++)
   {
      int stPrev = BarState(i - 1, Ema9Buf, Ema20Buf, rsiEma, rsiWma);
      int stCur  = BarState(i,     Ema9Buf, Ema20Buf, rsiEma, rsiWma);

      if (stCur != stPrev)
      {
         double gap = (atrVal[i] > 0 ? atrVal[i] : _Point * 10) * InpArrowGapATR;
         if (InpShowArrows)
         {
            if (stCur == 1)       BuyBuf[i]  = low[i]  - gap;
            else if (stCur == -1) SellBuf[i] = high[i] + gap;
            else                    ExitBuf[i] = (stPrev == 1) ? low[i] - gap : high[i] + gap;
         }

         // Chi bat alert cho nen cuoi cung (dang hinh thanh/vua cap nhat),
         // tranh ban lai hang loat tin hieu cu khi indicator moi duoc gan vao chart.
         if (i == rates_total - 1 && time[i] != g_lastAlertBarTime)
         {
            FireAlert(stCur, close[i]);
            g_lastAlertBarTime = time[i];
         }
      }
   }

   return rates_total;
}
