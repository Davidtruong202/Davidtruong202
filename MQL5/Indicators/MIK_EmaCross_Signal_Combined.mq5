//+------------------------------------------------------------------+
//|                             MIK_EmaCross_Signal_Combined.mq5     |
//|  Ban GOP 2 file thanh 1. Ly do phai lach: MQL5 khong cho 1 file  |
//|  vua ve tren chart chinh (indicator_chart_window) vua ve buffer  |
//|  that trong cua so rieng (indicator_separate_window) - day la    |
//|  gioi han cua chinh property #property, khong phai loi.          |
//|  Cach lach: EMA9/EMA20 + arrow Buy/Sell/Exit van la buffer that   |
//|  tren chart chinh; rieng panel RSI14/EMA9(RSI)/WMA45(RSI) duoc   |
//|  VE BANG CANVAS (anh de len chart) thay vi buffer that - dung    |
//|  dung ky thuat "canvas over chart" ma ban PDF v3.2 mo ta.         |
//|  Danh doi: panel RSI la HINH VE, KHONG re chuot xem duoc gia tri  |
//|  chinh xac tung diem nhu buffer that.                             |
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

#include <Canvas\Canvas.mqh>

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
// 5) RSI Panel (ve bang Canvas, KHONG phai cua so rieng that)
//====================================================================
input group "5) RSI Panel (canvas ve de len chart chinh)"
input bool   InpShowRsiPanel  = true;   // Bat/tat panel RSI
input int    InpPanelX        = 10;     // Khoang cach tu goc trai (px)
input int    InpPanelY        = 10;     // Khoang cach tu goc duoi (px)
input int    InpPanelW        = 320;    // Chieu rong panel (px)
input int    InpPanelH        = 110;    // Chieu cao panel (px)
input int    InpPanelBars     = 150;    // So nen ve trong panel
input int    InpLevelHigh     = 70;     // Muc tham chieu tren (chi de quan sat)
input int    InpLevelLow      = 30;     // Muc tham chieu duoi (chi de quan sat)

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

CCanvas RsiCanvas;
string  g_panelName  = "MIK_RsiPanel_Combined";
bool    g_panelReady = false;

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
      Print("MIK_EmaCross_Signal_Combined: khong tao duoc indicator handle");
      return INIT_FAILED;
   }

   CreateRsiPanel();

   IndicatorSetString(INDICATOR_SHORTNAME, "MIK EmaCross Signal (Combined)");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if (rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if (atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if (g_panelReady) RsiCanvas.Destroy();
}

//+------------------------------------------------------------------+
//| Panel RSI - tao/xoa canvas (anh de len chart, khong phai buffer) |
//+------------------------------------------------------------------+
void CreateRsiPanel()
{
   if (!InpShowRsiPanel) return;
   if (!RsiCanvas.CreateBitmapLabel(g_panelName, InpPanelX, InpPanelY, InpPanelW, InpPanelH, COLOR_FORMAT_ARGB_NORMALIZE))
   {
      Print("MIK_EmaCross_Signal_Combined: khong tao duoc RSI canvas panel");
      return;
   }
   ObjectSetInteger(0, g_panelName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, g_panelName, OBJPROP_XDISTANCE, InpPanelX);
   ObjectSetInteger(0, g_panelName, OBJPROP_YDISTANCE, InpPanelY);
   ObjectSetInteger(0, g_panelName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, g_panelName, OBJPROP_BACK, false);
   ObjectSetInteger(0, g_panelName, OBJPROP_HIDDEN, true);
   g_panelReady = true;
}

int YFromVal(const double v, const int h)
{
   double vv = v;
   if (vv < 0)   vv = 0;
   if (vv > 100) vv = 100;
   return h - (int)(vv / 100.0 * h);
}

//+------------------------------------------------------------------+
//| Ve panel RSI/EMA(RSI)/WMA(RSI) bang canvas - chi la hinh anh,    |
//| khong re chuot xem duoc gia tri nhu buffer that.                  |
//+------------------------------------------------------------------+
void DrawRsiPanel(const double &raw[], const double &ema[], const double &wma[], const int ratesTotal)
{
   if (!InpShowRsiPanel || !g_panelReady) return;

   int n = MathMin(InpPanelBars, ratesTotal);
   if (n < 2) return;

   int w = InpPanelW, h = InpPanelH;

   RsiCanvas.Erase(ColorToARGB(clrBlack, 180));

   // Vien panel
   RsiCanvas.Rectangle(0, 0, w - 1, h - 1, ColorToARGB(clrDimGray, 255));

   // Muc tham chieu 30/70 (chi de quan sat, khong dung trong logic tin hieu)
   int yHigh = YFromVal(InpLevelHigh, h);
   int yLow  = YFromVal(InpLevelLow,  h);
   RsiCanvas.LineHorizontal(0, w - 1, yHigh, ColorToARGB(clrDimGray, 150));
   RsiCanvas.LineHorizontal(0, w - 1, yLow,  ColorToARGB(clrDimGray, 150));

   int start = ratesTotal - n;
   double stepX = (double)(w - 1) / (n - 1);

   for (int i = 1; i < n; i++)
   {
      int idx0 = start + i - 1;
      int idx1 = start + i;
      int x0 = (int)((i - 1) * stepX);
      int x1 = (int)(i * stepX);

      RsiCanvas.LineAA(x0, YFromVal(raw[idx0], h), x1, YFromVal(raw[idx1], h), ColorToARGB(clrSilver, 255));
      RsiCanvas.LineAA(x0, YFromVal(ema[idx0], h), x1, YFromVal(ema[idx1], h), ColorToARGB(clrDodgerBlue, 255));
      RsiCanvas.LineAA(x0, YFromVal(wma[idx0], h), x1, YFromVal(wma[idx1], h), ColorToARGB(clrRed, 255));
   }

   RsiCanvas.Update();
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

   DrawRsiPanel(rsiRaw, rsiEma, rsiWma, rates_total);

   return rates_total;
}
