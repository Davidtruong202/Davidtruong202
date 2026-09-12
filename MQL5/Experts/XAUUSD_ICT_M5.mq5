//+------------------------------------------------------------------+
//|                                          XAUUSD_ICT_M5.mq5       |
//|  ICT / Smart Money Concepts automation: killzones, liquidity     |
//|  sweeps, Judas Swing, market structure (BOS/CHoCH), Order Block  |
//|  + FVG, Premium/Discount/OTE, ICT Score, and 4 documented        |
//|  setups (A: London Judas Reversal, B: NY AM Continuation,        |
//|  C: PDH/PDL Sweep Reversal, D: Turtle Soup on EQH/EQL).          |
//|  Base timeframe: M5. Bias timeframe: H4. Daily/weekly liquidity  |
//|  from D1/W1. See README.md for design notes and simplifications. |
//+------------------------------------------------------------------+
#property copyright "Custom EA"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// Enums
//====================================================================
enum ENUM_LEVEL_TYPE
{
   LVL_PDH, LVL_PDL, LVL_PWH, LVL_PWL,
   LVL_ASIAN_H, LVL_ASIAN_L, LVL_LONDON_H, LVL_LONDON_L,
   LVL_SWING_BSL, LVL_SWING_SSL, LVL_EQH, LVL_EQL
};
enum ENUM_ZONE_TYPE  { ZONE_OB_BULL, ZONE_OB_BEAR, ZONE_FVG_BULL, ZONE_FVG_BEAR };
enum ENUM_ZONE_STATE { ZONE_FRESH, ZONE_MITIGATED, ZONE_VOID };
enum ENUM_KZ         { KZ_NONE, KZ_ASIAN, KZ_LONDON, KZ_NYAM, KZ_LCLOSE, KZ_NYPM };
enum ENUM_SETUP      { SETUP_NONE=-1, SETUP_A=0, SETUP_B=1, SETUP_C=2, SETUP_D=3 };

//====================================================================
// Structs
//====================================================================
struct SwingPoint
{
   datetime t;
   double   price;
   bool     isHigh;
   bool     broken;
   bool     usedInEQ;
};
struct LiqLevel
{
   ENUM_LEVEL_TYPE type;
   double          price;
   bool            isBuySide; // true = resistance-type (BSL), sweep = wick above then close below
   bool            swept;
   datetime        formed;
};
struct Zone
{
   ENUM_ZONE_TYPE  type;
   double          top;
   double          bottom;
   ENUM_ZONE_STATE state;
   bool            hasFVGPair;
   bool            reactedThisBar;
   datetime        formed;
};
struct SweepEvt
{
   ENUM_LEVEL_TYPE srcType;
   bool            bullishExpectation;
   double          levelPrice;
   double          extremePrice;      // the wick extreme that swept the level
   double          sweepBarOpposite;  // opposite extreme of the same candle (used by Setup D)
   datetime        t;
   bool            isJudas;
   bool            usedForEntry;
};
struct StructEvt
{
   bool     isChoch;
   bool     bullish;
   datetime t;
};

//====================================================================
// Inputs
//====================================================================
input group "=== Timezone (NY) ==="
input bool   InpBrokerFixedNYOffset  = true;  // true: server is always InpServerToNY_Hours ahead of NY
input double InpServerToNY_Hours     = 7.0;   // used when InpBrokerFixedNYOffset = true
input double InpServerGMTOffsetHours = 0.0;   // used when InpBrokerFixedNYOffset = false (broker's fixed GMT offset)

input group "=== Killzones (NY time, decimal hours) ==="
input bool   InpEnableAsian  = true;
input double InpAsianStart   = 20.0;
input double InpAsianEnd     = 0.0;
input bool   InpEnableLondon = true;
input double InpLondonStart  = 2.0;
input double InpLondonEnd    = 5.0;
input bool   InpEnableNYAM   = true;
input double InpNYAMStart    = 7.0;
input double InpNYAMEnd      = 10.0;
input bool   InpEnableLClose = true;
input double InpLCloseStart  = 10.0;
input double InpLCloseEnd    = 12.0;
input bool   InpEnableNYPM   = false;
input double InpNYPMStart    = 13.5;
input double InpNYPMEnd      = 16.0;

input group "=== Structure & Liquidity ==="
input int    InpPivLen   = 8;     // swing confirmation bars each side (M5)
input double InpEqTolATR = 0.25;  // equal high/low tolerance x ATR (wider for Gold)
input int    InpH4PivLen = 3;     // H4 swing confirmation bars (bias timeframe)

input group "=== Displacement / OB / FVG ==="
input double InpDispATR      = 1.5;
input double InpDispBody     = 0.6;
input double InpFVGMinATR    = 0.2;
input bool   InpOBRequireFVG = true;
input bool   InpOBUseWick    = false;

input group "=== ICT Score thresholds ==="
input double InpScoreBuyThreshold  = 60;
input double InpScoreSellThreshold = 40;

input group "=== Setups ==="
input bool   InpEnableSetupA           = true;
input bool   InpEnableSetupB           = true;
input bool   InpEnableSetupC           = true;
input bool   InpEnableSetupD           = true;
input int    InpSetupA_MaxBarsSinceSweep = 16;
input int    InpSetupB_MaxBarsLookback   = 30;
input double InpSetupB_CutoffHour        = 11.0; // force-close if TP2 not hit by this NY hour
input int    InpSetupC_MaxBars           = 10;
input int    InpSetupD_MaxBars           = 6;

input group "=== Risk Management ==="
input double InpRiskPercent         = 0.75; // 0.5-1% per ICT playbook
input double InpMinRR_TP1           = 1.5;
input double InpMinRR_TP2           = 2.0;
input int    InpMaxTradesPerKZ      = 2;
input double InpMaxDailyLossPercent = 3.0;
input int    InpMaxConsecLosses     = 3;
input int    InpPauseMinutes        = 60;
input double InpSweepSLBufferATR    = 0.25;
input double InpZoneSLBufferATR     = 0.2;

input group "=== News filter ==="
input double InpNewsHourNY            = 8.5; // 08:30 NY (CPI/NFP-style slot)
input double InpNewsBlackoutMinBefore = 15;

input group "=== Trade ==="
input int InpMagicNumber = 20260912;
input int InpSlippage    = 30;
input int InpATRPeriod   = 14;

//====================================================================
// Globals
//====================================================================
int atrHandle = INVALID_HANDLE;

SwingPoint swingHighs[];
SwingPoint swingLows[];
SwingPoint h4SwingHighs[];
SwingPoint h4SwingLows[];
LiqLevel   liqLevels[];
Zone       zones[];
SweepEvt   sweepEvents[];
StructEvt  structEvents[];

datetime g_lastBarTime = 0, g_bar1Time = 0, g_lastD1Time = 0, g_lastW1Time = 0, g_lastH4Time = 0;
double   g_bar1Open = 0, g_bar1High = 0, g_bar1Low = 0, g_bar1Close = 0;
double   g_atr = 0;

ENUM_KZ  g_curKZ = KZ_NONE;
double   g_runAsianHigh = -1, g_runAsianLow = -1, g_runLondonHigh = -1, g_runLondonLow = -1;
bool     g_judasLondonDone = false, g_judasNYDone = false;
int      tradesThisKZ = 0;

int      g_structTrend = 0;      // M5 trend: 1 bull, -1 bear, 0 undefined
int      g_h4Bias = 0;
double   g_h4PD = 50;
double   g_pdPercent = 50, g_dealRangeHigh = 0, g_dealRangeLow = 0;
double   g_ictScore = 50;

double   g_dayStartBalance = 0;
datetime g_currentDay = 0;
int      g_consecLosses = 0;
datetime g_pausedUntil = 0;

ENUM_SETUP g_openSetup = SETUP_NONE;
double     g_tp1Price = 0;
bool       g_tp1Taken = false;

long g_cntBarsEvaluated=0, g_cntSweeps=0, g_cntZones=0, g_cntBOS=0, g_cntCHoCH=0;
long g_cntTradesA=0, g_cntTradesB=0, g_cntTradesC=0, g_cntTradesD=0;

//====================================================================
// Timezone helpers
//====================================================================
datetime NthSundayOfMonth(int year, int month, int n)
{
   MqlDateTime dt;
   dt.year=year; dt.mon=month; dt.day=1; dt.hour=0; dt.min=0; dt.sec=0;
   datetime firstOfMonth = StructToTime(dt);
   MqlDateTime f;
   TimeToStruct(firstOfMonth, f);
   int daysToSunday = (7 - f.day_of_week) % 7;
   datetime firstSunday = firstOfMonth + (long)daysToSunday*86400;
   return firstSunday + (long)(n-1)*7*86400;
}

bool IsUSDaylightSaving(datetime gmt)
{
   MqlDateTime dt;
   TimeToStruct(gmt, dt);
   datetime marchB = NthSundayOfMonth(dt.year, 3, 2);
   datetime novB   = NthSundayOfMonth(dt.year, 11, 1);
   return (gmt >= marchB && gmt < novB);
}

datetime GetNYTime()
{
   datetime srv = TimeCurrent();
   if(InpBrokerFixedNYOffset)
      return srv - (long)(InpServerToNY_Hours*3600);
   datetime gmt = srv - (long)(InpServerGMTOffsetHours*3600);
   int nyOff = IsUSDaylightSaving(gmt) ? 4 : 5;
   return gmt - (long)nyOff*3600;
}

double GetNYHourDecimal()
{
   MqlDateTime dt;
   TimeToStruct(GetNYTime(), dt);
   return dt.hour + dt.min/60.0;
}

bool InHours(double h, double start, double end)
{
   if(start == end) return true;
   if(start < end) return (h >= start && h < end);
   return (h >= start || h < end);
}

//====================================================================
// Liquidity level storage
//====================================================================
void AddLiqLevel(ENUM_LEVEL_TYPE type, double price, bool isBuySide, bool swept, datetime formed)
{
   bool singleton = (type==LVL_PDH||type==LVL_PDL||type==LVL_PWH||type==LVL_PWL||
                      type==LVL_ASIAN_H||type==LVL_ASIAN_L||type==LVL_LONDON_H||type==LVL_LONDON_L);
   if(singleton)
   {
      for(int i=0; i<ArraySize(liqLevels); i++)
      {
         if(liqLevels[i].type == type)
         {
            liqLevels[i].price=price; liqLevels[i].isBuySide=isBuySide;
            liqLevels[i].swept=swept; liqLevels[i].formed=formed;
            return;
         }
      }
   }
   int n = ArraySize(liqLevels);
   ArrayResize(liqLevels, n+1);
   liqLevels[n].type=type; liqLevels[n].price=price; liqLevels[n].isBuySide=isBuySide;
   liqLevels[n].swept=swept; liqLevels[n].formed=formed;
}

double GetNearestOppositeLiquidity(bool bullish)
{
   double best=0; bool found=false;
   for(int i=0; i<ArraySize(liqLevels); i++)
   {
      if(liqLevels[i].swept) continue;
      if(liqLevels[i].isBuySide != bullish) continue;
      double p = liqLevels[i].price;
      if(bullish && p<=g_bar1Close) continue;
      if(!bullish && p>=g_bar1Close) continue;
      if(!found || (bullish && p<best) || (!bullish && p>best)) { best=p; found=true; }
   }
   return found ? best : 0;
}

double GetTP2(bool bullish)
{
   double pdh=0, pdl=0, pwh=0, pwl=0;
   for(int i=0; i<ArraySize(liqLevels); i++)
   {
      if(liqLevels[i].type==LVL_PDH) pdh=liqLevels[i].price;
      if(liqLevels[i].type==LVL_PDL) pdl=liqLevels[i].price;
      if(liqLevels[i].type==LVL_PWH) pwh=liqLevels[i].price;
      if(liqLevels[i].type==LVL_PWL) pwl=liqLevels[i].price;
   }
   if(bullish)
   {
      if(pdh>g_bar1Close) return pdh;
      if(pwh>g_bar1Close) return pwh;
      return 0;
   }
   if(pdl>0 && pdl<g_bar1Close) return pdl;
   if(pwl>0 && pwl<g_bar1Close) return pwl;
   return 0;
}

double GetDealingRangeEQ()
{
   if(g_dealRangeHigh>g_dealRangeLow) return (g_dealRangeHigh+g_dealRangeLow)/2.0;
   return 0;
}

//====================================================================
// Swing / EQH-EQL
//====================================================================
void CheckEqualLevel(SwingPoint &arr[], int newIdx, bool isHigh)
{
   for(int j=newIdx-1; j>=0; j--)
   {
      if(arr[j].usedInEQ) continue;
      if(MathAbs(arr[newIdx].price - arr[j].price) <= InpEqTolATR*g_atr)
      {
         arr[newIdx].usedInEQ=true; arr[j].usedInEQ=true;
         AddLiqLevel(isHigh?LVL_EQH:LVL_EQL, arr[newIdx].price, isHigh, false, arr[newIdx].t);
         break;
      }
   }
}

void AppendSwing(SwingPoint &arr[], datetime t, double price, bool isHigh)
{
   int n = ArraySize(arr);
   ArrayResize(arr, n+1);
   arr[n].t=t; arr[n].price=price; arr[n].isHigh=isHigh; arr[n].broken=false; arr[n].usedInEQ=false;
   AddLiqLevel(isHigh?LVL_SWING_BSL:LVL_SWING_SSL, price, isHigh, false, t);
   CheckEqualLevel(arr, n, isHigh);
}

void UpdateSwings()
{
   int s = InpPivLen;
   double hi = iHigh(_Symbol, PERIOD_M5, s);
   double lo = iLow(_Symbol, PERIOD_M5, s);
   bool isHigh=true, isLow=true;
   for(int k=1; k<=s; k++)
   {
      if(iHigh(_Symbol,PERIOD_M5,s-k)>hi || iHigh(_Symbol,PERIOD_M5,s+k)>hi) isHigh=false;
      if(iLow(_Symbol,PERIOD_M5,s-k)<lo  || iLow(_Symbol,PERIOD_M5,s+k)<lo)  isLow=false;
   }
   datetime t = iTime(_Symbol, PERIOD_M5, s);
   if(isHigh) AppendSwing(swingHighs, t, hi, true);
   if(isLow)  AppendSwing(swingLows, t, lo, false);
}

void UpdateH4Swings()
{
   int s = InpH4PivLen;
   double hi = iHigh(_Symbol, PERIOD_H4, s);
   double lo = iLow(_Symbol, PERIOD_H4, s);
   bool isHigh=true, isLow=true;
   for(int k=1; k<=s; k++)
   {
      if(iHigh(_Symbol,PERIOD_H4,s-k)>hi || iHigh(_Symbol,PERIOD_H4,s+k)>hi) isHigh=false;
      if(iLow(_Symbol,PERIOD_H4,s-k)<lo  || iLow(_Symbol,PERIOD_H4,s+k)<lo)  isLow=false;
   }
   datetime t = iTime(_Symbol, PERIOD_H4, s);
   if(isHigh)
   {
      int n=ArraySize(h4SwingHighs); ArrayResize(h4SwingHighs,n+1);
      h4SwingHighs[n].t=t; h4SwingHighs[n].price=hi; h4SwingHighs[n].isHigh=true; h4SwingHighs[n].broken=false; h4SwingHighs[n].usedInEQ=false;
   }
   if(isLow)
   {
      int n=ArraySize(h4SwingLows); ArrayResize(h4SwingLows,n+1);
      h4SwingLows[n].t=t; h4SwingLows[n].price=lo; h4SwingLows[n].isHigh=false; h4SwingLows[n].broken=false; h4SwingLows[n].usedInEQ=false;
   }
}

//====================================================================
// Structure (BOS/CHoCH) - shared by M5 and H4
//====================================================================
int UpdateTrendFromSwings(SwingPoint &highs[], SwingPoint &lows[], double closePrice, int currentTrend,
                           datetime barTime, StructEvt &evtOut, bool &hasEvent)
{
   hasEvent=false;
   int hiIdx=-1, loIdx=-1;
   for(int i=ArraySize(highs)-1; i>=0; i--) if(!highs[i].broken) { hiIdx=i; break; }
   for(int i=ArraySize(lows)-1;  i>=0; i--) if(!lows[i].broken)  { loIdx=i; break; }

   int newTrend = currentTrend;
   if(hiIdx>=0 && closePrice > highs[hiIdx].price)
   {
      highs[hiIdx].broken=true;
      evtOut.isChoch = (currentTrend==-1);
      evtOut.bullish = true;
      evtOut.t = barTime;
      newTrend = 1;
      hasEvent = true;
   }
   else if(loIdx>=0 && closePrice < lows[loIdx].price)
   {
      lows[loIdx].broken=true;
      evtOut.isChoch = (currentTrend==1);
      evtOut.bullish = false;
      evtOut.t = barTime;
      newTrend = -1;
      hasEvent = true;
   }
   return newTrend;
}

void AppendStructEvent(StructEvt &e)
{
   int n=ArraySize(structEvents);
   ArrayResize(structEvents, n+1);
   structEvents[n]=e;
}

void CheckStructure()
{
   StructEvt evt; bool has;
   g_structTrend = UpdateTrendFromSwings(swingHighs, swingLows, g_bar1Close, g_structTrend, g_bar1Time, evt, has);
   if(has)
   {
      AppendStructEvent(evt);
      if(evt.isChoch) g_cntCHoCH++; else g_cntBOS++;
   }
}

void UpdateH4Bias()
{
   datetime h4t = iTime(_Symbol, PERIOD_H4, 0);
   if(h4t == g_lastH4Time) return;
   g_lastH4Time = h4t;

   UpdateH4Swings();

   double close1 = iClose(_Symbol, PERIOD_H4, 1);
   StructEvt evt; bool has;
   g_h4Bias = UpdateTrendFromSwings(h4SwingHighs, h4SwingLows, close1, g_h4Bias, h4t, evt, has);

   int nH=ArraySize(h4SwingHighs), nL=ArraySize(h4SwingLows);
   if(nH>0 && nL>0)
   {
      double rh=h4SwingHighs[nH-1].price, rl=h4SwingLows[nL-1].price;
      if(rh>rl) g_h4PD = (close1-rl)/(rh-rl)*100.0;
   }
}

//====================================================================
// Sweep & Judas detection
//====================================================================
void AppendSweep(SweepEvt &e)
{
   int n=ArraySize(sweepEvents);
   ArrayResize(sweepEvents, n+1);
   sweepEvents[n]=e;
   g_cntSweeps++;
}

void CheckSweepsAndJudas()
{
   for(int i=0; i<ArraySize(liqLevels); i++)
   {
      if(liqLevels[i].swept) continue;
      double lvl = liqLevels[i].price;
      if(liqLevels[i].isBuySide)
      {
         if(g_bar1High > lvl && g_bar1Close < lvl)
         {
            liqLevels[i].swept=true;
            SweepEvt e;
            e.srcType=liqLevels[i].type; e.bullishExpectation=false; e.levelPrice=lvl;
            e.extremePrice=g_bar1High; e.sweepBarOpposite=g_bar1Low; e.t=g_bar1Time;
            e.isJudas=false; e.usedForEntry=false;
            AppendSweep(e);
         }
         else if(g_bar1Close > lvl) liqLevels[i].swept=true; // break: consumed, no reversal signal
      }
      else
      {
         if(g_bar1Low < lvl && g_bar1Close > lvl)
         {
            liqLevels[i].swept=true;
            SweepEvt e;
            e.srcType=liqLevels[i].type; e.bullishExpectation=true; e.levelPrice=lvl;
            e.extremePrice=g_bar1Low; e.sweepBarOpposite=g_bar1High; e.t=g_bar1Time;
            e.isJudas=false; e.usedForEntry=false;
            AppendSweep(e);
         }
         else if(g_bar1Close < lvl) liqLevels[i].swept=true;
      }
   }

   if(g_curKZ==KZ_LONDON && !g_judasLondonDone)
   {
      for(int i=ArraySize(sweepEvents)-1; i>=0; i--)
      {
         if(sweepEvents[i].t != g_bar1Time) break;
         if(sweepEvents[i].srcType==LVL_ASIAN_H || sweepEvents[i].srcType==LVL_ASIAN_L)
         {
            sweepEvents[i].isJudas=true;
            g_judasLondonDone=true;
         }
      }
   }
   if(g_curKZ==KZ_NYAM && !g_judasNYDone)
   {
      for(int i=ArraySize(sweepEvents)-1; i>=0; i--)
      {
         if(sweepEvents[i].t != g_bar1Time) break;
         if(sweepEvents[i].srcType==LVL_LONDON_H || sweepEvents[i].srcType==LVL_LONDON_L)
         {
            sweepEvents[i].isJudas=true;
            g_judasNYDone=true;
         }
      }
   }
}

// Returns the array index (not a copy) so callers can persist usedForEntry back
// onto the real event - a struct returned by value would only mark a local copy.
int GetRecentSweepIdx(int maxBars, ENUM_LEVEL_TYPE t1, ENUM_LEVEL_TYPE t2, bool requireJudas)
{
   datetime cutoff = g_bar1Time - (long)maxBars*PeriodSeconds(PERIOD_M5);
   for(int i=ArraySize(sweepEvents)-1; i>=0; i--)
   {
      if(sweepEvents[i].t < cutoff) break;
      if(sweepEvents[i].usedForEntry) continue;
      if(requireJudas && !sweepEvents[i].isJudas) continue;
      if(sweepEvents[i].srcType!=t1 && sweepEvents[i].srcType!=t2) continue;
      return i;
   }
   return -1;
}

bool GetRecentStruct(int maxBars, bool requireChoch, bool bullish, StructEvt &out)
{
   datetime cutoff = g_bar1Time - (long)maxBars*PeriodSeconds(PERIOD_M5);
   for(int i=ArraySize(structEvents)-1; i>=0; i--)
   {
      if(structEvents[i].t < cutoff) break;
      if(requireChoch && !structEvents[i].isChoch) continue;
      if(structEvents[i].bullish != bullish) continue;
      out = structEvents[i];
      return true;
   }
   return false;
}

//====================================================================
// Displacement -> Order Block / FVG
//====================================================================
void AddZone(ENUM_ZONE_TYPE type, double top, double bottom, bool hasFVGPair, datetime formed)
{
   int n=ArraySize(zones);
   ArrayResize(zones, n+1);
   zones[n].type=type; zones[n].top=MathMax(top,bottom); zones[n].bottom=MathMin(top,bottom);
   zones[n].state=ZONE_FRESH; zones[n].hasFVGPair=hasFVGPair; zones[n].reactedThisBar=false; zones[n].formed=formed;
   g_cntZones++;
}

void CheckDisplacementAndZones()
{
   if(g_atr<=0) return;
   double range1 = g_bar1High-g_bar1Low;
   double body1  = MathAbs(g_bar1Close-g_bar1Open);
   if(range1 < InpDispATR*g_atr) return;
   if(body1 < InpDispBody*range1) return;

   bool bullDisp = g_bar1Close > g_bar1Open;

   int obShift=-1;
   for(int s=2; s<=6; s++)
   {
      double o=iOpen(_Symbol,PERIOD_M5,s), c=iClose(_Symbol,PERIOD_M5,s);
      bool bearish = (c<o);
      if(bullDisp && bearish) { obShift=s; break; }
      if(!bullDisp && !bearish) { obShift=s; break; }
   }

   bool hasFVG=false; double fvgTop=0, fvgBottom=0;
   double highShift3 = iHigh(_Symbol,PERIOD_M5,3);
   double lowShift3  = iLow(_Symbol,PERIOD_M5,3);
   if(bullDisp)
   {
      if(g_bar1Low > highShift3)
      {
         double gap = g_bar1Low - highShift3;
         if(gap >= InpFVGMinATR*g_atr) { hasFVG=true; fvgBottom=highShift3; fvgTop=g_bar1Low; }
      }
   }
   else
   {
      if(g_bar1High < lowShift3)
      {
         double gap = lowShift3 - g_bar1High;
         if(gap >= InpFVGMinATR*g_atr) { hasFVG=true; fvgBottom=g_bar1High; fvgTop=lowShift3; }
      }
   }

   if(obShift>=0)
   {
      double obOpen=iOpen(_Symbol,PERIOD_M5,obShift), obClose=iClose(_Symbol,PERIOD_M5,obShift);
      double obHigh=iHigh(_Symbol,PERIOD_M5,obShift), obLow=iLow(_Symbol,PERIOD_M5,obShift);
      double top, bottom;
      if(InpOBUseWick) { top=obHigh; bottom=obLow; }
      else { top=MathMax(obOpen,obClose); bottom=MathMin(obOpen,obClose); }

      if(!InpOBRequireFVG || hasFVG)
         AddZone(bullDisp?ZONE_OB_BULL:ZONE_OB_BEAR, top, bottom, hasFVG, g_bar1Time);
   }
   if(hasFVG)
      AddZone(bullDisp?ZONE_FVG_BULL:ZONE_FVG_BEAR, fvgTop, fvgBottom, true, g_bar1Time);
}

void UpdateZoneMitigation()
{
   for(int i=0; i<ArraySize(zones); i++)
   {
      zones[i].reactedThisBar=false;
      if(zones[i].state != ZONE_FRESH) continue;
      bool overlap = (g_bar1Low <= zones[i].top && g_bar1High >= zones[i].bottom);
      if(!overlap) continue;
      bool bullish = (zones[i].type==ZONE_OB_BULL || zones[i].type==ZONE_FVG_BULL);
      if(bullish)
      {
         if(g_bar1Close > zones[i].top)        { zones[i].state=ZONE_MITIGATED; zones[i].reactedThisBar=true; }
         else if(g_bar1Close < zones[i].bottom) zones[i].state=ZONE_VOID;
         else                                   zones[i].state=ZONE_MITIGATED;
      }
      else
      {
         if(g_bar1Close < zones[i].bottom)     { zones[i].state=ZONE_MITIGATED; zones[i].reactedThisBar=true; }
         else if(g_bar1Close > zones[i].top)    zones[i].state=ZONE_VOID;
         else                                   zones[i].state=ZONE_MITIGATED;
      }
   }
}

bool FindReactedZone(bool bullish, Zone &outZone)
{
   int bestIdx=-1;
   for(int i=ArraySize(zones)-1; i>=0; i--)
   {
      if(!zones[i].reactedThisBar) continue;
      bool zb = (zones[i].type==ZONE_OB_BULL || zones[i].type==ZONE_FVG_BULL);
      if(zb != bullish) continue;
      if(bestIdx==-1) bestIdx=i;
      else if(zones[i].hasFVGPair && !zones[bestIdx].hasFVGPair) bestIdx=i;
   }
   if(bestIdx==-1) return false;
   outZone = zones[bestIdx];
   return true;
}

bool HasFreshZone(bool bullish)
{
   for(int i=0; i<ArraySize(zones); i++)
   {
      if(zones[i].state != ZONE_FRESH) continue;
      bool zb = (zones[i].type==ZONE_OB_BULL || zones[i].type==ZONE_FVG_BULL);
      if(zb==bullish) return true;
   }
   return false;
}

//====================================================================
// Killzones & session ranges
//====================================================================
void UpdateNYAndKZ()
{
   double nyH = GetNYHourDecimal();
   ENUM_KZ kz = KZ_NONE;
   if(InpEnableAsian  && InHours(nyH, InpAsianStart,  InpAsianEnd))  kz=KZ_ASIAN;
   else if(InpEnableLondon && InHours(nyH, InpLondonStart, InpLondonEnd)) kz=KZ_LONDON;
   else if(InpEnableNYAM   && InHours(nyH, InpNYAMStart,   InpNYAMEnd))   kz=KZ_NYAM;
   else if(InpEnableLClose && InHours(nyH, InpLCloseStart, InpLCloseEnd)) kz=KZ_LCLOSE;
   else if(InpEnableNYPM   && InHours(nyH, InpNYPMStart,   InpNYPMEnd))   kz=KZ_NYPM;

   if(kz != g_curKZ)
   {
      if(g_curKZ==KZ_ASIAN && g_runAsianHigh>0)
      {
         AddLiqLevel(LVL_ASIAN_H, g_runAsianHigh, true,  false, g_bar1Time);
         AddLiqLevel(LVL_ASIAN_L, g_runAsianLow,  false, false, g_bar1Time);
      }
      if(g_curKZ==KZ_LONDON && g_runLondonHigh>0)
      {
         AddLiqLevel(LVL_LONDON_H, g_runLondonHigh, true,  false, g_bar1Time);
         AddLiqLevel(LVL_LONDON_L, g_runLondonLow,  false, false, g_bar1Time);
      }
      if(kz==KZ_ASIAN)  { g_runAsianHigh=-1;  g_runAsianLow=-1; }
      if(kz==KZ_LONDON) { g_runLondonHigh=-1; g_runLondonLow=-1; g_judasLondonDone=false; }
      if(kz==KZ_NYAM)   { g_judasNYDone=false; }
      tradesThisKZ=0;
      g_curKZ=kz;
   }
}

void UpdateSessionRanges()
{
   if(g_curKZ==KZ_ASIAN)
   {
      g_runAsianHigh = (g_runAsianHigh<0) ? g_bar1High : MathMax(g_runAsianHigh, g_bar1High);
      g_runAsianLow  = (g_runAsianLow<0)  ? g_bar1Low  : MathMin(g_runAsianLow,  g_bar1Low);
   }
   if(g_curKZ==KZ_LONDON)
   {
      g_runLondonHigh = (g_runLondonHigh<0) ? g_bar1High : MathMax(g_runLondonHigh, g_bar1High);
      g_runLondonLow  = (g_runLondonLow<0)  ? g_bar1Low  : MathMin(g_runLondonLow,  g_bar1Low);
   }
}

//====================================================================
// Daily / weekly liquidity
//====================================================================
void UpdateDailyWeeklyLevels()
{
   datetime d1t = iTime(_Symbol, PERIOD_D1, 0);
   if(d1t != g_lastD1Time)
   {
      g_lastD1Time = d1t;
      double pdh = iHigh(_Symbol, PERIOD_D1, 1), pdl = iLow(_Symbol, PERIOD_D1, 1);
      if(pdh>0) AddLiqLevel(LVL_PDH, pdh, true,  false, d1t);
      if(pdl>0) AddLiqLevel(LVL_PDL, pdl, false, false, d1t);
   }
   datetime w1t = iTime(_Symbol, PERIOD_W1, 0);
   if(w1t != g_lastW1Time)
   {
      g_lastW1Time = w1t;
      double pwh = iHigh(_Symbol, PERIOD_W1, 1), pwl = iLow(_Symbol, PERIOD_W1, 1);
      if(pwh>0) AddLiqLevel(LVL_PWH, pwh, true,  false, w1t);
      if(pwl>0) AddLiqLevel(LVL_PWL, pwl, false, false, w1t);
   }
}

//====================================================================
// Premium/Discount & ICT Score
//====================================================================
void UpdatePremiumDiscountAndScore()
{
   int nH=ArraySize(swingHighs), nL=ArraySize(swingLows);
   if(nH>0 && nL>0)
   {
      double rh=swingHighs[nH-1].price, rl=swingLows[nL-1].price;
      if(rh>rl)
      {
         g_pdPercent = (g_bar1Close-rl)/(rh-rl)*100.0;
         g_dealRangeHigh=rh; g_dealRangeLow=rl;
      }
   }
   double structComp = (g_structTrend==1) ? 20 : (g_structTrend==-1 ? -20 : 0);
   double pdComp = (50-g_pdPercent)*0.4;
   double zoneComp = 0;
   if(g_structTrend==1 && HasFreshZone(true))   zoneComp=20;
   if(g_structTrend==-1 && HasFreshZone(false)) zoneComp=-20;
   double kzComp = 0;
   if(g_curKZ != KZ_NONE) kzComp = (structComp>0) ? 10 : (structComp<0 ? -10 : 0);

   g_ictScore = 50 + structComp + pdComp + zoneComp + kzComp;
   if(g_ictScore<0)   g_ictScore=0;
   if(g_ictScore>100) g_ictScore=100;
}

//====================================================================
// Risk sizing
//====================================================================
double CalculateLotSize(double slDistancePrice)
{
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * InpRiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize<=0 || tickValue<=0 || slDistancePrice<=0) return 0;

   double lossPerLot = (slDistancePrice/tickSize)*tickValue;
   if(lossPerLot<=0) return 0;

   double lots = riskMoney/lossPerLot;
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep<=0) lotStep=0.01;

   lots = MathFloor(lots/lotStep)*lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));
   return NormalizeDouble(lots, 2);
}

//====================================================================
// Entry execution (shared by all 4 setups)
//====================================================================
bool HasOpenPosition()
{
   if(!PositionSelect(_Symbol)) return false;
   return PositionGetInteger(POSITION_MAGIC)==InpMagicNumber;
}

bool ExecuteEntry(ENUM_SETUP setup, bool bullish, double entry, double sl, double tp1, double tp2, string cmt)
{
   if(tp1<=0) tp1 = bullish ? entry+(entry-sl)*InpMinRR_TP1 : entry-(sl-entry)*InpMinRR_TP1;
   if(tp2<=0) tp2 = bullish ? entry+(entry-sl)*InpMinRR_TP2 : entry-(sl-entry)*InpMinRR_TP2;

   double risk = MathAbs(entry-sl);
   if(risk<=0) return false;
   double rr1 = MathAbs(tp1-entry)/risk;
   double rr2 = MathAbs(tp2-entry)/risk;
   if(rr1 < InpMinRR_TP1 || rr2 < InpMinRR_TP2) return false;

   double lots = CalculateLotSize(risk);
   if(lots<=0) return false;

   bool ok = bullish ? trade.Buy(lots, _Symbol, entry, sl, tp2, cmt)
                      : trade.Sell(lots, _Symbol, entry, sl, tp2, cmt);
   if(ok)
   {
      g_openSetup=setup; g_tp1Price=tp1; g_tp1Taken=false;
      tradesThisKZ++;
      switch(setup)
      {
         case SETUP_A: g_cntTradesA++; break;
         case SETUP_B: g_cntTradesB++; break;
         case SETUP_C: g_cntTradesC++; break;
         case SETUP_D: g_cntTradesD++; break;
         default: break;
      }
      PrintFormat("[ENTRY] %s dir=%s entry=%.2f sl=%.2f tp1=%.2f tp2=%.2f", cmt, bullish?"BUY":"SELL", entry, sl, tp1, tp2);
   }
   return ok;
}

//====================================================================
// Setup A: London Judas Reversal (buy after Asian Low sweep)
//====================================================================
void CheckSetupA()
{
   if(!InpEnableSetupA) return;
   if(g_curKZ != KZ_LONDON) return;
   if(!(g_h4Bias==1 || g_h4PD<50)) return;

   int swIdx = GetRecentSweepIdx(InpSetupA_MaxBarsSinceSweep, LVL_ASIAN_L, LVL_ASIAN_L, true);
   if(swIdx<0) return;
   SweepEvt sw = sweepEvents[swIdx];

   StructEvt st;
   if(!GetRecentStruct(InpSetupA_MaxBarsSinceSweep, true, true, st)) return;
   if(st.t <= sw.t) return;
   if(g_pdPercent >= 50) return;

   Zone z;
   if(!FindReactedZone(true, z)) return;

   double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl    = sw.extremePrice - InpSweepSLBufferATR*g_atr;
   double tp1   = GetNearestOppositeLiquidity(true);
   double tp2   = GetTP2(true);

   ExecuteEntry(SETUP_A, true, entry, sl, tp1, tp2, "SetupA-LondonJudas");
   sweepEvents[swIdx].usedForEntry=true;
}

//====================================================================
// Setup B: NY AM Continuation
//====================================================================
void CheckSetupB()
{
   if(!InpEnableSetupB) return;
   if(g_curKZ != KZ_NYAM) return;

   bool bull = (g_ictScore >= InpScoreBuyThreshold  && g_structTrend==1);
   bool bear = (g_ictScore <= InpScoreSellThreshold && g_structTrend==-1);
   if(!bull && !bear) return;

   StructEvt st;
   if(!GetRecentStruct(InpSetupB_MaxBarsLookback, false, bull, st)) return;

   Zone z;
   if(FindReactedZone(bull, z))
   {
      double entry = bull ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl    = bull ? z.bottom - InpZoneSLBufferATR*g_atr : z.top + InpZoneSLBufferATR*g_atr;
      double tp1   = GetNearestOppositeLiquidity(bull);
      double tp2   = GetTP2(bull);
      ExecuteEntry(SETUP_B, bull, entry, sl, tp1, tp2, "SetupB-Continuation");
      return;
   }

   ENUM_LEVEL_TYPE lt = bull ? LVL_LONDON_L : LVL_LONDON_H;
   int swIdx = GetRecentSweepIdx(3, lt, lt, true);
   if(swIdx<0) return;
   SweepEvt sw = sweepEvents[swIdx];
   bool reacted = bull ? (g_bar1Close > sw.levelPrice) : (g_bar1Close < sw.levelPrice);
   if(!reacted) return;

   double entry = bull ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl    = bull ? sw.extremePrice - InpSweepSLBufferATR*g_atr : sw.extremePrice + InpSweepSLBufferATR*g_atr;
   double tp1   = GetNearestOppositeLiquidity(bull);
   double tp2   = GetTP2(bull);
   ExecuteEntry(SETUP_B, bull, entry, sl, tp1, tp2, "SetupB-JudasNY");
   sweepEvents[swIdx].usedForEntry=true;
}

//====================================================================
// Setup C: PDH/PDL Sweep Reversal
//====================================================================
void CheckSetupC()
{
   if(!InpEnableSetupC) return;
   if(g_curKZ==KZ_NONE) return;

   StructEvt st; Zone z;

   int swIdxH = GetRecentSweepIdx(InpSetupC_MaxBars, LVL_PDH, LVL_PDH, false);
   if(swIdxH>=0 && g_pdPercent>=70)
   {
      SweepEvt sw = sweepEvents[swIdxH];
      if(GetRecentStruct(InpSetupC_MaxBars, true, false, st) && st.t>sw.t && g_ictScore<=40)
      {
         if(FindReactedZone(false, z))
         {
            double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
            double sl=sw.extremePrice + InpSweepSLBufferATR*g_atr;
            double tp1=GetNearestOppositeLiquidity(false);
            double tp2=GetDealingRangeEQ();
            if(tp2<=0) tp2=GetTP2(false);
            ExecuteEntry(SETUP_C, false, entry, sl, tp1, tp2, "SetupC-PDH-Reversal");
            sweepEvents[swIdxH].usedForEntry=true;
            return;
         }
      }
   }

   int swIdxL = GetRecentSweepIdx(InpSetupC_MaxBars, LVL_PDL, LVL_PDL, false);
   if(swIdxL>=0 && g_pdPercent<=30)
   {
      SweepEvt sw = sweepEvents[swIdxL];
      if(GetRecentStruct(InpSetupC_MaxBars, true, true, st) && st.t>sw.t && g_ictScore>=60)
      {
         if(FindReactedZone(true, z))
         {
            double entry=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
            double sl=sw.extremePrice - InpSweepSLBufferATR*g_atr;
            double tp1=GetNearestOppositeLiquidity(true);
            double tp2=GetDealingRangeEQ();
            if(tp2<=0) tp2=GetTP2(true);
            ExecuteEntry(SETUP_C, true, entry, sl, tp1, tp2, "SetupC-PDL-Reversal");
            sweepEvents[swIdxL].usedForEntry=true;
         }
      }
   }
}

//====================================================================
// Setup D: Turtle Soup (EQH/EQL trap)
//====================================================================
void CheckSetupD()
{
   if(!InpEnableSetupD) return;
   if(g_curKZ==KZ_NONE) return;

   int swIdxH = GetRecentSweepIdx(InpSetupD_MaxBars, LVL_EQH, LVL_EQH, false);
   if(swIdxH>=0)
   {
      SweepEvt sw = sweepEvents[swIdxH];
      if(g_bar1Close < sw.sweepBarOpposite)
      {
         double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         double sl=sw.extremePrice + InpSweepSLBufferATR*g_atr;
         double tp1=GetNearestOppositeLiquidity(false);
         double tp2=GetTP2(false);
         ExecuteEntry(SETUP_D, false, entry, sl, tp1, tp2, "SetupD-TurtleSoup-EQH");
         sweepEvents[swIdxH].usedForEntry=true;
         return;
      }
   }
   int swIdxL = GetRecentSweepIdx(InpSetupD_MaxBars, LVL_EQL, LVL_EQL, false);
   if(swIdxL>=0)
   {
      SweepEvt sw = sweepEvents[swIdxL];
      if(g_bar1Close > sw.sweepBarOpposite)
      {
         double entry=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         double sl=sw.extremePrice - InpSweepSLBufferATR*g_atr;
         double tp1=GetNearestOppositeLiquidity(true);
         double tp2=GetTP2(true);
         ExecuteEntry(SETUP_D, true, entry, sl, tp1, tp2, "SetupD-TurtleSoup-EQL");
         sweepEvents[swIdxL].usedForEntry=true;
      }
   }
}

//====================================================================
// Position management (partial TP1, breakeven, reversal exit, time cutoff)
//====================================================================
void ManageOpenPosition()
{
   if(!HasOpenPosition()) { g_openSetup=SETUP_NONE; return; }

   ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
   bool  isBuy  = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double vol   = PositionGetDouble(POSITION_VOLUME);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double curTP = PositionGetDouble(POSITION_TP);

   if(!g_tp1Taken && g_tp1Price>0)
   {
      bool hit = isBuy ? (g_bar1High >= g_tp1Price) : (g_bar1Low <= g_tp1Price);
      if(hit)
      {
         double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         if(lotStep<=0) lotStep=0.01;
         double closeVol = MathFloor((vol*0.5)/lotStep)*lotStep;
         if(closeVol>=minLot && closeVol<vol)
            trade.PositionClosePartial(ticket, closeVol);
         trade.PositionModify(ticket, openPrice, curTP);
         g_tp1Taken=true;
      }
   }

   StructEvt st;
   if(GetRecentStruct(1, true, !isBuy, st))
   {
      trade.PositionClose(ticket);
      return;
   }

   if(g_openSetup==SETUP_B && GetNYHourDecimal() >= InpSetupB_CutoffHour)
      trade.PositionClose(ticket);
}

//====================================================================
// Trading gates
//====================================================================
bool CanTradeNow()
{
   if(TimeCurrent() < g_pausedUntil) return false;
   double maxLossMoney = g_dayStartBalance*InpMaxDailyLossPercent/100.0;
   if(AccountInfoDouble(ACCOUNT_EQUITY) <= g_dayStartBalance-maxLossMoney) return false;
   if(tradesThisKZ >= InpMaxTradesPerKZ) return false;
   if(g_curKZ==KZ_NONE) return false;

   double nyH = GetNYHourDecimal();
   double newsStart = InpNewsHourNY - InpNewsBlackoutMinBefore/60.0;
   if(nyH>=newsStart && nyH<InpNewsHourNY) return false;
   return true;
}

//====================================================================
// Bar caching / ATR
//====================================================================
bool CacheBar1IfNew()
{
   datetime bt = iTime(_Symbol, PERIOD_M5, 0);
   if(bt == g_lastBarTime) return false;
   g_lastBarTime = bt;
   g_bar1Time  = iTime(_Symbol,  PERIOD_M5, 1);
   g_bar1Open  = iOpen(_Symbol,  PERIOD_M5, 1);
   g_bar1High  = iHigh(_Symbol,  PERIOD_M5, 1);
   g_bar1Low   = iLow(_Symbol,   PERIOD_M5, 1);
   g_bar1Close = iClose(_Symbol, PERIOD_M5, 1);
   return true;
}

bool UpdateATR()
{
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(atrHandle, 0, 1, 1, buf) < 1) return false;
   g_atr = buf[0];
   return g_atr>0;
}

//====================================================================
// Standard EA handlers
//====================================================================
int OnInit()
{
   atrHandle = iATR(_Symbol, PERIOD_M5, InpATRPeriod);
   if(atrHandle==INVALID_HANDLE)
   {
      Print("Failed to create ATR handle");
      return(INIT_FAILED);
   }
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);

   g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_currentDay = TimeCurrent() - (TimeCurrent()%86400);
   g_curKZ = KZ_NONE;

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   PrintFormat("[ICT-EA Summary] bars=%d sweeps=%d zones=%d BOS=%d CHoCH=%d tradesA=%d tradesB=%d tradesC=%d tradesD=%d",
               (int)g_cntBarsEvaluated, (int)g_cntSweeps, (int)g_cntZones, (int)g_cntBOS, (int)g_cntCHoCH,
               (int)g_cntTradesA, (int)g_cntTradesB, (int)g_cntTradesC, (int)g_cntTradesD);
   IndicatorRelease(atrHandle);
}

void OnTick()
{
   if(!CacheBar1IfNew()) return;
   if(!UpdateATR()) return;

   UpdateNYAndKZ();
   UpdateSessionRanges();
   UpdateDailyWeeklyLevels();
   UpdateSwings();
   CheckSweepsAndJudas();
   UpdateZoneMitigation();
   CheckDisplacementAndZones();
   CheckStructure();
   UpdateH4Bias();
   UpdatePremiumDiscountAndScore();

   ManageOpenPosition();

   datetime today = TimeCurrent() - (TimeCurrent()%86400);
   if(today != g_currentDay)
   {
      g_currentDay = today;
      g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }

   if(!HasOpenPosition() && CanTradeNow())
   {
      CheckSetupA();
      if(!HasOpenPosition()) CheckSetupB();
      if(!HasOpenPosition()) CheckSetupC();
      if(!HasOpenPosition()) CheckSetupD();
   }

   g_cntBarsEvaluated++;
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                         const MqlTradeRequest &request,
                         const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;

   long   magic  = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   long   entry  = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   string symbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
   if(magic != InpMagicNumber || symbol != _Symbol || entry != DEAL_ENTRY_OUT) return;

   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                 + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

   if(profit < 0) g_consecLosses++; else g_consecLosses=0;
   if(g_consecLosses >= InpMaxConsecLosses)
   {
      g_pausedUntil = TimeCurrent() + InpPauseMinutes*60;
      g_consecLosses = 0;
      Print("Max consecutive losses reached. Pausing until ", TimeToString(g_pausedUntil));
   }

   if(!HasOpenPosition())
   {
      g_openSetup = SETUP_NONE;
      g_tp1Price = 0;
      g_tp1Taken = false;
   }
}
//+------------------------------------------------------------------+
