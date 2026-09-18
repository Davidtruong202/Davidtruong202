//+------------------------------------------------------------------+
//|                                      MIK_RsiEmaWma_Sub.mq5       |
//|  Gan len CUA SO RIENG. CHI de quan sat truc quan RSI14, EMA9(RSI)|
//|  va WMA45(RSI) - KHONG chua logic tin hieu, khong ve arrow,      |
//|  khong bat alert. Go bo file nay khoi chart khong anh huong gi   |
//|  den tin hieu Buy/Sell (toan bo logic nam o MIK_EmaCross_Signal).|
//|  Xay lai tu tai lieu mo ta (khong co source goc kem theo).       |
//+------------------------------------------------------------------+
#property copyright "Rebuilt from spec"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3
#property indicator_minimum 0
#property indicator_maximum 100

#property indicator_label1  "RSI14"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSilver
#property indicator_width1  1

#property indicator_label2  "EMA9(RSI)"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_width2  2

#property indicator_label3  "WMA45(RSI)"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrRed
#property indicator_width3  2

input int InpRsiPeriod    = 14;  // Chu ky RSI
input int InpRsiEmaPeriod = 9;   // Chu ky EMA ap dung tren RSI
input int InpRsiWmaPeriod = 45;  // Chu ky WMA ap dung tren RSI
input int InpLevelHigh    = 70;  // Muc tham chieu quá mua (chi de quan sat)
input int InpLevelLow     = 30;  // Muc tham chieu quá bán (chi de quan sat)

double RsiBuf[];
double RsiEmaBuf[];
double RsiWmaBuf[];
int    rsiHandle = INVALID_HANDLE;

int OnInit()
{
   SetIndexBuffer(0, RsiBuf,    INDICATOR_DATA);
   SetIndexBuffer(1, RsiEmaBuf, INDICATOR_DATA);
   SetIndexBuffer(2, RsiWmaBuf, INDICATOR_DATA);
   ArraySetAsSeries(RsiBuf,    false);
   ArraySetAsSeries(RsiEmaBuf, false);
   ArraySetAsSeries(RsiWmaBuf, false);

   IndicatorSetInteger(INDICATOR_LEVELS, 2);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpLevelHigh);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpLevelLow);

   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, InpRsiPeriod, PRICE_CLOSE);
   if (rsiHandle == INVALID_HANDLE)
   {
      Print("MIK_RsiEmaWma_Sub: khong tao duoc RSI handle");
      return INIT_FAILED;
   }

   IndicatorSetString(INDICATOR_SHORTNAME, "MIK RSI EMA/WMA");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if (rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
}

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
   if (rates_total < InpRsiPeriod + InpRsiWmaPeriod + 2) return 0;

   double rsiRaw[];
   ArraySetAsSeries(rsiRaw, false);
   if (CopyBuffer(rsiHandle, 0, 0, rates_total, rsiRaw) <= 0) return 0;

   int start = (prev_calculated == 0) ? 0 : prev_calculated - 2;
   if (start < 0) start = 0;

   double kEma = 2.0 / (InpRsiEmaPeriod + 1.0);
   int    wn   = InpRsiWmaPeriod;

   for (int i = start; i < rates_total; i++)
   {
      RsiBuf[i] = rsiRaw[i];

      if (i == 0)
         RsiEmaBuf[i] = rsiRaw[i];
      else
         RsiEmaBuf[i] = rsiRaw[i] * kEma + RsiEmaBuf[i-1] * (1.0 - kEma);

      if (i + 1 < wn)
      {
         RsiWmaBuf[i] = rsiRaw[i];
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
         RsiWmaBuf[i] = sumWX / sumW;
      }
   }

   return rates_total;
}
