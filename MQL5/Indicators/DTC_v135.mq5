//+------------------------------------------------------------------+
//|                                              DTC_v135.mq5        |
//|  1:1 visual port of the "DTC - v1.35" Pine Script indicator:     |
//|  6-EMA trend-alignment system with trend-colored EMA lines,      |
//|  BUY/SELL signal labels, Entry/SL/TP1/TP2 lines+labels for the   |
//|  latest signal (matches the EA, which only trades TP1/TP2), a    |
//|  15M/30M/1H/4H/D trend dashboard, and an optional Telegram       |
//|  alert on each new confirmed signal. This is a                   |
//|  display-only indicator (no auto-trading) - see DTC_v135_EA.mq5  |
//|  in MQL5/Experts for the auto-trading version. See README.md.    |
//+------------------------------------------------------------------+
#property copyright "Custom Indicator"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 12
#property indicator_plots   6

#property indicator_label1  "EMA 1"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrGray,clrLime,clrRed
#property indicator_width1  3
#property indicator_label2  "EMA 2"
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  clrGray,clrLime,clrRed
#property indicator_width2  2
#property indicator_label3  "EMA 3"
#property indicator_type3   DRAW_COLOR_LINE
#property indicator_color3  clrGray,clrLime,clrRed
#property indicator_width3  2
#property indicator_label4  "EMA 4"
#property indicator_type4   DRAW_COLOR_LINE
#property indicator_color4  clrGray,clrLime,clrRed
#property indicator_width4  1
#property indicator_label5  "EMA 5"
#property indicator_type5   DRAW_COLOR_LINE
#property indicator_color5  clrGray,clrLime,clrRed
#property indicator_width5  1
#property indicator_label6  "EMA 6"
#property indicator_type6   DRAW_COLOR_LINE
#property indicator_color6  clrGray,clrLime,clrRed
#property indicator_width6  1

//====================================================================
// Inputs (mirrors the Pine Script's input groups)
//====================================================================
input group "=== EMA Settings ==="
input int    InpLen1 = 30;
input int    InpLen2 = 35;
input int    InpLen3 = 40;
input int    InpLen4 = 45;
input int    InpLen5 = 50;
input int    InpLen6 = 60;

input group "=== Multi-Timeframe Settings ==="
input ENUM_TIMEFRAMES InpTf1 = PERIOD_M15;
input ENUM_TIMEFRAMES InpTf2 = PERIOD_M30;
input ENUM_TIMEFRAMES InpTf3 = PERIOD_H1;
input ENUM_TIMEFRAMES InpTf4 = PERIOD_H4;
input ENUM_TIMEFRAMES InpTf5 = PERIOD_D1;

input group "=== Risk Management (levels drawn for the latest signal, matches the EA) ==="
input double InpStopLossPercent = 0.25;
input double InpTP1Multiplier   = 1.0;
input double InpTP2Multiplier   = 2.0;

input group "=== Display ==="
input int    InpLineLength  = 1;    // bars the entry/SL/TP lines extend to the right
input bool   InpShowNumbers = true;
input bool   InpShowLabels  = true;

input group "=== Dashboard ==="
input bool   InpShowDashboard   = true;
input ENUM_BASE_CORNER InpDashboardCorner = CORNER_LEFT_UPPER;
input int    InpDashboardFontSize = 9;

input group "=== Telegram Alert ==="
input bool   InpTelegramEnabled  = false;
input string InpTelegramBotToken = ""; // from @BotFather
input string InpTelegramChatId   = "";

input group "=== Win-Rate Stats Table ==="
input bool   InpShowStatsTable = true; // historical % of signals that reached TP1/TP2 vs hit SL first

//====================================================================
// Buffers
//====================================================================
double Ema1Buf[], Ema1Clr[];
double Ema2Buf[], Ema2Clr[];
double Ema3Buf[], Ema3Clr[];
double Ema4Buf[], Ema4Clr[];
double Ema5Buf[], Ema5Clr[];
double Ema6Buf[], Ema6Clr[];

//====================================================================
// Globals
//====================================================================
int handleEma1, handleEma2, handleEma3, handleEma4, handleEma5, handleEma6, handleAtr;
int handleHtf1Fast, handleHtf1Slow, handleHtf2Fast, handleHtf2Slow, handleHtf3Fast, handleHtf3Slow,
    handleHtf4Fast, handleHtf4Slow, handleHtf5Fast, handleHtf5Slow;

double g_entry=0, g_sl=0, g_tp1=0, g_tp2=0;
bool   g_haveSignal = false;
datetime g_lastAlertBarTime = 0;
bool   g_firstCalc = true;

#define OBJ_PREFIX "DTC135_"

//====================================================================
// Win-rate stats: forward-simulate each historical signal (SL moves to
// breakeven once TP1 is reached, same as the EA) until it resolves as
// either a loss (SL hit before TP1) or reaches TP1/TP2.
//====================================================================
struct PendingSignal
{
   bool   bullish;
   double entry, sl, tp1, tp2;
   int    phase;       // next target index: 0=TP1, 1=TP2
   double stopLevel;   // sl initially, moves to entry (breakeven) after TP1
   int    lastScanned; // last bar index already scanned (inclusive)
};
PendingSignal g_pending[];
long   g_statTotal = 0;
long   g_statReached[2] = {0,0};
long   g_statSL = 0;

//====================================================================
// Init / Deinit
//====================================================================
int OnInit()
{
   SetIndexBuffer(0, Ema1Buf, INDICATOR_DATA);  SetIndexBuffer(1, Ema1Clr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, Ema2Buf, INDICATOR_DATA);  SetIndexBuffer(3, Ema2Clr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4, Ema3Buf, INDICATOR_DATA);  SetIndexBuffer(5, Ema3Clr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(6, Ema4Buf, INDICATOR_DATA);  SetIndexBuffer(7, Ema4Clr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(8, Ema5Buf, INDICATOR_DATA);  SetIndexBuffer(9, Ema5Clr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(10,Ema6Buf, INDICATOR_DATA);  SetIndexBuffer(11,Ema6Clr, INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(Ema1Buf,false); ArraySetAsSeries(Ema2Buf,false); ArraySetAsSeries(Ema3Buf,false);
   ArraySetAsSeries(Ema4Buf,false); ArraySetAsSeries(Ema5Buf,false); ArraySetAsSeries(Ema6Buf,false);

   handleEma1 = iMA(_Symbol, PERIOD_CURRENT, InpLen1, 0, MODE_EMA, PRICE_CLOSE);
   handleEma2 = iMA(_Symbol, PERIOD_CURRENT, InpLen2, 0, MODE_EMA, PRICE_CLOSE);
   handleEma3 = iMA(_Symbol, PERIOD_CURRENT, InpLen3, 0, MODE_EMA, PRICE_CLOSE);
   handleEma4 = iMA(_Symbol, PERIOD_CURRENT, InpLen4, 0, MODE_EMA, PRICE_CLOSE);
   handleEma5 = iMA(_Symbol, PERIOD_CURRENT, InpLen5, 0, MODE_EMA, PRICE_CLOSE);
   handleEma6 = iMA(_Symbol, PERIOD_CURRENT, InpLen6, 0, MODE_EMA, PRICE_CLOSE);
   handleAtr  = iATR(_Symbol, PERIOD_CURRENT, 14);

   handleHtf1Fast = iMA(_Symbol, InpTf1, 20, 0, MODE_EMA, PRICE_CLOSE);
   handleHtf1Slow = iMA(_Symbol, InpTf1, 50, 0, MODE_EMA, PRICE_CLOSE);
   handleHtf2Fast = iMA(_Symbol, InpTf2, 20, 0, MODE_EMA, PRICE_CLOSE);
   handleHtf2Slow = iMA(_Symbol, InpTf2, 50, 0, MODE_EMA, PRICE_CLOSE);
   handleHtf3Fast = iMA(_Symbol, InpTf3, 20, 0, MODE_EMA, PRICE_CLOSE);
   handleHtf3Slow = iMA(_Symbol, InpTf3, 50, 0, MODE_EMA, PRICE_CLOSE);
   handleHtf4Fast = iMA(_Symbol, InpTf4, 20, 0, MODE_EMA, PRICE_CLOSE);
   handleHtf4Slow = iMA(_Symbol, InpTf4, 50, 0, MODE_EMA, PRICE_CLOSE);
   handleHtf5Fast = iMA(_Symbol, InpTf5, 20, 0, MODE_EMA, PRICE_CLOSE);
   handleHtf5Slow = iMA(_Symbol, InpTf5, 50, 0, MODE_EMA, PRICE_CLOSE);

   if(handleEma1==INVALID_HANDLE || handleEma2==INVALID_HANDLE || handleEma3==INVALID_HANDLE ||
      handleEma4==INVALID_HANDLE || handleEma5==INVALID_HANDLE || handleEma6==INVALID_HANDLE ||
      handleAtr==INVALID_HANDLE)
   {
      Print("[DTC-Ind] Failed to create indicator handles");
      return INIT_FAILED;
   }

   IndicatorSetString(INDICATOR_SHORTNAME, "DTC - v1.35");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, OBJ_PREFIX);
   Comment("");
}

//====================================================================
// Helpers
//====================================================================
color ColorFromIndex(int idx) { return idx==1 ? clrLime : (idx==2 ? clrRed : clrGray); }

void DeleteObj(string name) { ObjectDelete(0, name); }

void DrawHLine(string name, datetime t1, double price, datetime t2, color clr)
{
   DeleteObj(name);
   ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void DrawPriceLabel(string name, datetime t, double price, string text, color clr)
{
   DeleteObj(name);
   ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void DrawSignalLabel(string name, datetime t, double price, bool isBuy)
{
   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, isBuy?233:234);
   ObjectSetInteger(0, name, OBJPROP_COLOR, isBuy?clrLime:clrRed);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, isBuy?"BUY":"SELL");
}

void SendTelegramAlert(string signalType, double entry, double sl, double t1, double t2)
{
   if(!InpTelegramEnabled || InpTelegramBotToken=="" || InpTelegramChatId=="") return;

   string msg = signalType + " Signal - " + _Symbol + " (" + EnumToString((ENUM_TIMEFRAMES)Period()) + ")" +
      "\nEntry: " + DoubleToString(entry, _Digits) +
      "\nSL: " + DoubleToString(sl, _Digits) +
      "\nTP1: " + DoubleToString(t1, _Digits) +
      "\nTP2: " + DoubleToString(t2, _Digits);

   string url = "https://api.telegram.org/bot" + InpTelegramBotToken + "/sendMessage";
   string json = "{\"chat_id\":\"" + InpTelegramChatId + "\",\"text\":\"" + msg + "\"}";

   char post[], result[];
   string headers = "Content-Type: application/json\r\n", resultHeaders;
   StringToCharArray(json, post, 0, StringLen(json));
   int res = WebRequest("POST", url, headers, 5000, post, result, resultHeaders);
   if(res==-1)
      PrintFormat("[DTC-Ind] Telegram WebRequest failed, error=%d. Add %s to Tools>Options>Expert Advisors>Allow WebRequest.", GetLastError(), url);
}

void QueueSignalForStats(bool bullish, double entry, double sl, double tp1, double tp2, int barIndex)
{
   int idx = ArraySize(g_pending);
   ArrayResize(g_pending, idx+1);
   g_pending[idx].bullish = bullish;
   g_pending[idx].entry = entry; g_pending[idx].sl = sl;
   g_pending[idx].tp1 = tp1; g_pending[idx].tp2 = tp2;
   g_pending[idx].phase = 0;
   g_pending[idx].stopLevel = sl;
   g_pending[idx].lastScanned = barIndex;
}

// Advances every pending (not-yet-resolved) signal using bars that are now available,
// moves the stop to breakeven once TP1 is reached (mirrors the EA), and commits
// resolved signals (loss at SL, or exit/close after reaching TP1/TP2) into the
// win-rate counters. Unresolved (still-open) signals are kept for the next call.
void ResolvePendingSignals(const double &high[], const double &low[], int rates_total)
{
   int n = ArraySize(g_pending);
   if(n==0) return;

   bool resolved[];
   ArrayResize(resolved, n);
   ArrayInitialize(resolved, false);
   double tp[2];

   for(int p=0; p<n; p++)
   {
      tp[0]=g_pending[p].tp1; tp[1]=g_pending[p].tp2;
      int j = g_pending[p].lastScanned+1;
      for(; j<rates_total; j++)
      {
         bool hitStop   = g_pending[p].bullish ? (low[j] <= g_pending[p].stopLevel) : (high[j] >= g_pending[p].stopLevel);
         bool hitTarget = g_pending[p].bullish ? (high[j] >= tp[g_pending[p].phase])  : (low[j]  <= tp[g_pending[p].phase]);
         if(hitStop && hitTarget) hitTarget = false; // both touched same bar: assume the stop was hit first (conservative)

         if(hitStop)
         {
            g_statTotal++;
            if(g_pending[p].phase==0) g_statSL++; // full loss only if SL hit before ever reaching TP1
            resolved[p] = true;
            break;
         }
         if(hitTarget)
         {
            g_statReached[g_pending[p].phase]++;
            g_pending[p].phase++;
            g_pending[p].stopLevel = g_pending[p].entry; // breakeven after TP1, same as the EA
            if(g_pending[p].phase>=2) { g_statTotal++; resolved[p]=true; break; }
         }
      }
      g_pending[p].lastScanned = MathMin(j, rates_total-1);
   }

   // rebuild the pending array keeping only the still-unresolved signals
   PendingSignal keep[];
   for(int p=0; p<n; p++)
      if(!resolved[p])
      {
         int k = ArraySize(keep);
         ArrayResize(keep, k+1);
         keep[k] = g_pending[p];
      }
   ArrayFree(g_pending);
   ArrayResize(g_pending, ArraySize(keep));
   for(int k=0; k<ArraySize(keep); k++) g_pending[k] = keep[k];
}

// Win-rate table drawn right below the MTF rows: % of resolved historical signals
// that reached TP1/TP2, and % that hit SL before ever reaching TP1.
void UpdateStatsTable(int rowOffset)
{
   if(!InpShowStatsTable) { ObjectsDeleteAll(0, OBJ_PREFIX+"dash_stat"); return; }

   // clean up TP3/TP4 rows left over from older versions of this indicator
   DeleteObj(OBJ_PREFIX+"dash_stat_row4"); DeleteObj(OBJ_PREFIX+"dash_stat_row5");

   long total = g_statTotal;
   string rows[4];
   color  clrs[4];
   rows[0] = "Win Rate (n=" + IntegerToString((int)total) + ")"; clrs[0] = clrWhite;

   string tpLabel[2] = {"TP1","TP2"};
   for(int k=0; k<2; k++)
   {
      double pct = (total>0) ? (100.0*g_statReached[k]/total) : 0.0;
      rows[k+1] = tpLabel[k] + "  " + DoubleToString(pct,1) + "%  (" + IntegerToString((int)g_statReached[k]) + ")";
      clrs[k+1] = clrLime;
   }
   double slPct = (total>0) ? (100.0*g_statSL/total) : 0.0;
   rows[3] = "SL   " + DoubleToString(slPct,1) + "%  (" + IntegerToString((int)g_statSL) + ")";
   clrs[3] = clrRed;

   for(int r=0; r<4; r++)
   {
      string name = OBJ_PREFIX+"dash_stat_row"+IntegerToString(r);
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, InpDashboardCorner);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 10 + (rowOffset+r)*(InpDashboardFontSize+6));
         ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpDashboardFontSize);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      }
      ObjectSetString(0, name, OBJPROP_TEXT, rows[r]);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrs[r]);
   }
}

void UpdateDashboard()
{
   if(!InpShowDashboard) { ObjectsDeleteAll(0, OBJ_PREFIX+"dash_"); return; }

   double f1[1],s1[1],f2[1],s2[1],f3[1],s3[1],f4[1],s4[1],f5[1],s5[1];
   if(CopyBuffer(handleHtf1Fast,0,0,1,f1)<=0 || CopyBuffer(handleHtf1Slow,0,0,1,s1)<=0) return;
   if(CopyBuffer(handleHtf2Fast,0,0,1,f2)<=0 || CopyBuffer(handleHtf2Slow,0,0,1,s2)<=0) return;
   if(CopyBuffer(handleHtf3Fast,0,0,1,f3)<=0 || CopyBuffer(handleHtf3Slow,0,0,1,s3)<=0) return;
   if(CopyBuffer(handleHtf4Fast,0,0,1,f4)<=0 || CopyBuffer(handleHtf4Slow,0,0,1,s4)<=0) return;
   if(CopyBuffer(handleHtf5Fast,0,0,1,f5)<=0 || CopyBuffer(handleHtf5Slow,0,0,1,s5)<=0) return;

   string rows[6];
   rows[0] = "DTC V - 1.35";
   rows[1] = "15   " + (f1[0]>s1[0] ? "Bullish" : "Bearish");
   rows[2] = "30   " + (f2[0]>s2[0] ? "Bullish" : "Bearish");
   rows[3] = "60   " + (f3[0]>s3[0] ? "Bullish" : "Bearish");
   rows[4] = "240  " + (f4[0]>s4[0] ? "Bullish" : "Bearish");
   rows[5] = "D    " + (f5[0]>s5[0] ? "Bullish" : "Bearish");
   bool bull[6];
   bull[0]=true; bull[1]=(f1[0]>s1[0]); bull[2]=(f2[0]>s2[0]); bull[3]=(f3[0]>s3[0]); bull[4]=(f4[0]>s4[0]); bull[5]=(f5[0]>s5[0]);

   for(int r=0; r<6; r++)
   {
      string name = OBJ_PREFIX+"dash_row"+IntegerToString(r);
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, InpDashboardCorner);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 10 + r*(InpDashboardFontSize+6));
         ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpDashboardFontSize);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      }
      ObjectSetString(0, name, OBJPROP_TEXT, rows[r]);
      ObjectSetInteger(0, name, OBJPROP_COLOR, r==0 ? clrWhite : (bull[r]?clrLime:clrRed));
   }

   UpdateStatsTable(6);
}

//====================================================================
// Main calculation
//====================================================================
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                 const double &open[], const double &high[], const double &low[], const double &close[],
                 const long &tick_volume[], const long &volume[], const int &spread[])
{
   int minBars = InpLen6+2;
   if(rates_total < minBars) return 0;

   ArraySetAsSeries(time,false); ArraySetAsSeries(open,false); ArraySetAsSeries(high,false);
   ArraySetAsSeries(low,false);  ArraySetAsSeries(close,false);

   double e1[], e2[], e3[], e4[], e5[], e6[], atrArr[];
   ArraySetAsSeries(e1,false); ArraySetAsSeries(e2,false); ArraySetAsSeries(e3,false);
   ArraySetAsSeries(e4,false); ArraySetAsSeries(e5,false); ArraySetAsSeries(e6,false); ArraySetAsSeries(atrArr,false);

   if(CopyBuffer(handleEma1,0,0,rates_total,e1)<=0) return prev_calculated;
   if(CopyBuffer(handleEma2,0,0,rates_total,e2)<=0) return prev_calculated;
   if(CopyBuffer(handleEma3,0,0,rates_total,e3)<=0) return prev_calculated;
   if(CopyBuffer(handleEma4,0,0,rates_total,e4)<=0) return prev_calculated;
   if(CopyBuffer(handleEma5,0,0,rates_total,e5)<=0) return prev_calculated;
   if(CopyBuffer(handleEma6,0,0,rates_total,e6)<=0) return prev_calculated;
   if(CopyBuffer(handleAtr,0,0,rates_total,atrArr)<=0) return prev_calculated;

   if(prev_calculated==0) // fresh (re)load: reset the win-rate stats so history isn't double-counted
   {
      ArrayFree(g_pending);
      g_statTotal=0; g_statSL=0;
      ArrayInitialize(g_statReached, 0);
   }

   int start = (prev_calculated>1) ? prev_calculated-1 : 0;
   int lastClosedBar = rates_total-2; // last fully closed bar (current bar is still forming)

   for(int i=start; i<rates_total; i++)
   {
      bool bull = (e1[i]>e2[i] && e2[i]>e3[i] && e3[i]>e4[i] && e4[i]>e5[i] && e5[i]>e6[i]);
      bool bear = (e1[i]<e2[i] && e2[i]<e3[i] && e3[i]<e4[i] && e4[i]<e5[i] && e5[i]<e6[i]);
      int clrIdx = bull ? 1 : (bear ? 2 : 0);

      Ema1Buf[i]=e1[i]; Ema1Clr[i]=clrIdx;
      Ema2Buf[i]=e2[i]; Ema2Clr[i]=clrIdx;
      Ema3Buf[i]=e3[i]; Ema3Clr[i]=clrIdx;
      Ema4Buf[i]=e4[i]; Ema4Clr[i]=clrIdx;
      Ema5Buf[i]=e5[i]; Ema5Clr[i]=clrIdx;
      Ema6Buf[i]=e6[i]; Ema6Clr[i]=clrIdx;

      if(i<1 || i>lastClosedBar) continue; // only fire signals on confirmed (closed) bars

      bool bullPrev = (e1[i-1]>e2[i-1] && e2[i-1]>e3[i-1] && e3[i-1]>e4[i-1] && e4[i-1]>e5[i-1] && e5[i-1]>e6[i-1]);
      bool bearPrev = (e1[i-1]<e2[i-1] && e2[i-1]<e3[i-1] && e3[i-1]<e4[i-1] && e4[i-1]<e5[i-1] && e5[i-1]<e6[i-1]);
      bool longSignal  = bull && !bullPrev;
      bool shortSignal = bear && !bearPrev;
      if(!longSignal && !shortSignal) continue;

      double entry = close[i];
      double sl, tp1, tp2;
      if(longSignal)
      {
         sl  = entry*(1 - InpStopLossPercent/100.0);
         tp1 = entry*(1 + InpStopLossPercent*InpTP1Multiplier/100.0);
         tp2 = entry*(1 + InpStopLossPercent*InpTP2Multiplier/100.0);
      }
      else
      {
         sl  = entry*(1 + InpStopLossPercent/100.0);
         tp1 = entry*(1 - InpStopLossPercent*InpTP1Multiplier/100.0);
         tp2 = entry*(1 - InpStopLossPercent*InpTP2Multiplier/100.0);
      }

      if(InpShowLabels)
      {
         string sigName = OBJ_PREFIX+"sig_"+IntegerToString((int)time[i]);
         double sigPrice = longSignal ? low[i]-atrArr[i]*0.5 : high[i]+atrArr[i]*0.5;
         DrawSignalLabel(sigName, time[i], sigPrice, longSignal);
      }

      datetime t2 = time[i] + PeriodSeconds()*InpLineLength;
      DrawHLine(OBJ_PREFIX+"entryLine", time[i], entry, t2, clrBlue);
      DrawHLine(OBJ_PREFIX+"slLine",    time[i], sl,    t2, clrRed);
      DrawHLine(OBJ_PREFIX+"tp1Line",   time[i], tp1,   t2, clrGreen);
      DrawHLine(OBJ_PREFIX+"tp2Line",   time[i], tp2,   t2, clrGreen);
      DeleteObj(OBJ_PREFIX+"tp3Line"); DeleteObj(OBJ_PREFIX+"tp4Line"); // clean up leftovers from older versions

      if(InpShowNumbers)
      {
         DrawPriceLabel(OBJ_PREFIX+"entryLbl", t2, entry, "ENTRY "+DoubleToString(entry,_Digits), clrBlue);
         DrawPriceLabel(OBJ_PREFIX+"slLbl",    t2, sl,    "SL "+DoubleToString(sl,_Digits),        clrRed);
         DrawPriceLabel(OBJ_PREFIX+"tp1Lbl",   t2, tp1,   "TP1 "+DoubleToString(tp1,_Digits),      clrGreen);
         DrawPriceLabel(OBJ_PREFIX+"tp2Lbl",   t2, tp2,   "TP2 "+DoubleToString(tp2,_Digits),      clrGreen);
         DeleteObj(OBJ_PREFIX+"tp3Lbl"); DeleteObj(OBJ_PREFIX+"tp4Lbl");
      }

      g_entry=entry; g_sl=sl; g_tp1=tp1; g_tp2=tp2;
      g_haveSignal = true;
      QueueSignalForStats(longSignal, entry, sl, tp1, tp2, i);

      // Only alert for the newest closed bar, and never on the indicator's first (historical) calc pass
      if(i==lastClosedBar && !g_firstCalc && time[i]>g_lastAlertBarTime)
      {
         SendTelegramAlert(longSignal?"BUY":"SELL", entry, sl, tp1, tp2);
         g_lastAlertBarTime = time[i];
      }
   }

   ResolvePendingSignals(high, low, rates_total);

   // Keep the latest signal's lines extended to the current bar, like the Pine script does every bar
   if(g_haveSignal)
   {
      datetime tExt = time[rates_total-1] + PeriodSeconds()*InpLineLength;
      string lineNames[4] = {"entryLine","slLine","tp1Line","tp2Line"};
      for(int k=0;k<4;k++)
      {
         string nm = OBJ_PREFIX+lineNames[k];
         if(ObjectFind(0, nm)>=0) ObjectSetInteger(0, nm, OBJPROP_TIME, 1, tExt);
      }
      if(InpShowNumbers)
      {
         string lblNames[4] = {"entryLbl","slLbl","tp1Lbl","tp2Lbl"};
         for(int k=0;k<4;k++)
         {
            string nm = OBJ_PREFIX+lblNames[k];
            if(ObjectFind(0, nm)>=0) ObjectSetInteger(0, nm, OBJPROP_TIME, tExt);
         }
      }
   }

   UpdateDashboard();
   g_firstCalc = false;
   return rates_total;
}
