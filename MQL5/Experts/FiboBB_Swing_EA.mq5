//+------------------------------------------------------------------+
//|                                          FiboBB_Swing_EA.mq5      |
//|  Automates the "Fibonacci + Bollinger Bands" pullback strategy:  |
//|  trend via swing structure, Fibonacci retracement zone (50%-     |
//|  61.8%) of the latest swing leg, Bollinger Band touch, and a     |
//|  bullish/bearish reversal candle (Pin Bar, Engulfing, Morning/   |
//|  Evening Star) as confirmation. TP1/TP2/TP3 use the nearest      |
//|  swing extreme plus 127.2% / 161.8% Fibonacci extensions.        |
//|  Works on any symbol/timeframe attached to the chart. See        |
//|  README.md for design notes and simplifications.                 |
//+------------------------------------------------------------------+
#property copyright "Custom EA"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// Inputs
//====================================================================
input group "=== Timeframe ==="
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M15; // working timeframe for structure/entries

input group "=== Structure / Swings ==="
input int    InpPivLen       = 5;    // swing confirmation bars each side
input double InpMinLegATR    = 3.0;  // minimum leg range (high-low) in ATR multiples to be tradeable

input group "=== Fibonacci zone ==="
input double InpFiboZoneNear = 0.5;   // near edge of the pullback entry zone
input double InpFiboZoneFar  = 0.618; // far edge of the pullback entry zone
input double InpFiboExt1     = 1.272; // TP2 extension
input double InpFiboExt2     = 1.618; // TP3 extension

input group "=== Bollinger Bands ==="
input int    InpBBPeriod       = 20;
input double InpBBDeviation    = 2.0;
input double InpMinBandWidthPct= 0.5; // min (upper-lower)/middle*100, filters sideways/squeeze markets

input group "=== Candle confirmation ==="
input bool   InpAllowPinBar     = true;
input bool   InpAllowEngulfing  = true;
input bool   InpAllowStar       = true; // Morning Star / Evening Star

input group "=== Risk Management ==="
input double InpRiskPercent         = 1.0;  // 1-2% tai khoan moi lenh (khuyen nghi)
input double InpSLBufferATR         = 0.75; // dem ngoai day/dinh gan nhat hoac Band, khuyen nghi 0.5-1 ATR
input double InpMaxDailyLossPercent = 3.0;
input int    InpMaxConsecLosses     = 3;
input int    InpPauseMinutes        = 60;
input double InpTP1ClosePct         = 50; // % of original volume closed at TP1
input double InpTP2ClosePct         = 30; // % of original volume closed at TP2 (remaining 20% rides to TP3)

input group "=== Timezone (NY) ==="
input bool   InpBrokerFixedNYOffset  = true;
input double InpServerToNY_Hours     = 7.0;
input double InpServerGMTOffsetHours = 0.0;

input group "=== News filter (NY time, decimal hours) ==="
input bool   InpEnableNewsFilter1   = true;
input double InpNewsHour1           = 8.5;  // 08:30 NY - NFP/CPI slot
input double InpNewsBlackoutBefore1 = 15;
input double InpNewsBlackoutAfter1  = 15;
input bool   InpEnableNewsFilter2   = true;
input double InpNewsHour2           = 14.0; // 14:00 NY - FOMC slot
input double InpNewsBlackoutBefore2 = 15;
input double InpNewsBlackoutAfter2  = 30;

input group "=== Trade ==="
input int InpMagicNumber = 20260922;
input int InpSlippage    = 30;
input int InpATRPeriod   = 14;

//====================================================================
// Structs / globals
//====================================================================
struct SwingPoint
{
   datetime t;
   double   price;
   bool     isHigh;
   bool     broken;
};

SwingPoint swingHighs[];
SwingPoint swingLows[];

int atrHandle = INVALID_HANDLE;
int bbHandle  = INVALID_HANDLE;

datetime g_lastBarTime = 0, g_bar1Time = 0;
double   g_bar1Open=0, g_bar1High=0, g_bar1Low=0, g_bar1Close=0;
double   g_atr = 0;
double   g_bbUpper=0, g_bbMiddle=0, g_bbLower=0;

int      g_structTrend = 0; // 1 bull, -1 bear, 0 undefined

double   g_legHigh = 0, g_legLow = 0;
datetime g_legHighTime = 0, g_legLowTime = 0;
bool     g_legValid = false;

double   g_dayStartBalance = 0;
datetime g_currentDay = 0;
int      g_consecLosses = 0;
datetime g_pausedUntil = 0;

bool     g_isBuy = false;
double   g_tp1=0, g_tp2=0, g_tp3=0;
bool     g_tp1Done=false, g_tp2Done=false;
double   g_initialVolume=0;

long g_cntBarsEvaluated=0, g_cntTrades=0;

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

bool InBlackout(double h, double center, double before, double after)
{
   double start = center - before/60.0;
   double end   = center + after/60.0;
   if(start <= end) return (h >= start && h < end);
   return (h >= start || h < end); // wraps midnight
}

//====================================================================
// Bar helpers (all on InpTimeframe)
//====================================================================
double GetO(int shift) { return iOpen(_Symbol, InpTimeframe, shift); }
double GetH(int shift) { return iHigh(_Symbol, InpTimeframe, shift); }
double GetL(int shift) { return iLow(_Symbol, InpTimeframe, shift); }
double GetC(int shift) { return iClose(_Symbol, InpTimeframe, shift); }

//====================================================================
// Swing detection & structure trend
//====================================================================
void AppendSwing(SwingPoint &arr[], datetime t, double price, bool isHigh)
{
   int n = ArraySize(arr);
   ArrayResize(arr, n+1);
   arr[n].t=t; arr[n].price=price; arr[n].isHigh=isHigh; arr[n].broken=false;
}

void UpdateSwings()
{
   int s = InpPivLen;
   double hi = iHigh(_Symbol, InpTimeframe, s);
   double lo = iLow(_Symbol, InpTimeframe, s);
   bool isHigh=true, isLow=true;
   for(int k=1; k<=s; k++)
   {
      if(iHigh(_Symbol,InpTimeframe,s-k)>hi || iHigh(_Symbol,InpTimeframe,s+k)>hi) isHigh=false;
      if(iLow(_Symbol,InpTimeframe,s-k)<lo  || iLow(_Symbol,InpTimeframe,s+k)<lo)  isLow=false;
   }
   datetime t = iTime(_Symbol, InpTimeframe, s);
   if(isHigh) AppendSwing(swingHighs, t, hi, true);
   if(isLow)  AppendSwing(swingLows, t, lo, false);
}

// Break-of-structure trend, same idea as classic BOS/CHoCH tracking.
void CheckStructure()
{
   int hiIdx=-1, loIdx=-1;
   for(int i=ArraySize(swingHighs)-1; i>=0; i--) if(!swingHighs[i].broken) { hiIdx=i; break; }
   for(int i=ArraySize(swingLows)-1;  i>=0; i--) if(!swingLows[i].broken)  { loIdx=i; break; }

   if(hiIdx>=0 && g_bar1Close > swingHighs[hiIdx].price)
   {
      swingHighs[hiIdx].broken=true;
      g_structTrend = 1;
   }
   else if(loIdx>=0 && g_bar1Close < swingLows[loIdx].price)
   {
      swingLows[loIdx].broken=true;
      g_structTrend = -1;
   }
}

// Latest completed swing leg in the direction of the current trend:
// bull -> [most recent swing low, most recent swing high after it]
// bear -> [most recent swing high, most recent swing low after it]
void UpdateLeg()
{
   g_legValid = false;
   int nH=ArraySize(swingHighs), nL=ArraySize(swingLows);
   if(nH==0 || nL==0) return;

   if(g_structTrend==1)
   {
      double hi = swingHighs[nH-1].price; datetime hiT = swingHighs[nH-1].t;
      // most recent low that precedes this high
      double lo=0; datetime loT=0; bool found=false;
      for(int i=nL-1; i>=0; i--)
      {
         if(swingLows[i].t < hiT) { lo=swingLows[i].price; loT=swingLows[i].t; found=true; break; }
      }
      if(!found) return;
      if(hi<=lo) return;
      g_legHigh=hi; g_legLow=lo; g_legHighTime=hiT; g_legLowTime=loT; g_legValid=true;
   }
   else if(g_structTrend==-1)
   {
      double lo = swingLows[nL-1].price; datetime loT = swingLows[nL-1].t;
      double hi=0; datetime hiT=0; bool found=false;
      for(int i=nH-1; i>=0; i--)
      {
         if(swingHighs[i].t < loT) { hi=swingHighs[i].price; hiT=swingHighs[i].t; found=true; break; }
      }
      if(!found) return;
      if(hi<=lo) return;
      g_legHigh=hi; g_legLow=lo; g_legHighTime=hiT; g_legLowTime=loT; g_legValid=true;
   }
}

//====================================================================
// Candle confirmation patterns (evaluated on the last closed bar)
//====================================================================
bool IsBullishPinBar(int shift)
{
   double o=GetO(shift), h=GetH(shift), l=GetL(shift), c=GetC(shift);
   double range=h-l; if(range<=0) return false;
   double body=MathAbs(c-o);
   double lowerWick = MathMin(o,c)-l;
   double upperWick = h-MathMax(o,c);
   if(body > range*0.35) return false;
   if(lowerWick < body*2.0) return false;
   if(lowerWick < range*0.5) return false;
   if(upperWick > range*0.25) return false;
   return true;
}

bool IsBearishPinBar(int shift)
{
   double o=GetO(shift), h=GetH(shift), l=GetL(shift), c=GetC(shift);
   double range=h-l; if(range<=0) return false;
   double body=MathAbs(c-o);
   double lowerWick = MathMin(o,c)-l;
   double upperWick = h-MathMax(o,c);
   if(body > range*0.35) return false;
   if(upperWick < body*2.0) return false;
   if(upperWick < range*0.5) return false;
   if(lowerWick > range*0.25) return false;
   return true;
}

bool IsBullishEngulfing(int shift)
{
   double o1=GetO(shift+1), c1=GetC(shift+1);
   double o2=GetO(shift),   c2=GetC(shift);
   if(!(c1<o1)) return false; // prior bearish
   if(!(c2>o2)) return false; // this bullish
   return (o2<=c1 && c2>=o1);
}

bool IsBearishEngulfing(int shift)
{
   double o1=GetO(shift+1), c1=GetC(shift+1);
   double o2=GetO(shift),   c2=GetC(shift);
   if(!(c1>o1)) return false; // prior bullish
   if(!(c2<o2)) return false; // this bearish
   return (o2>=c1 && c2<=o1);
}

bool IsMorningStar(int shift)
{
   double o3=GetO(shift+2), c3=GetC(shift+2);
   double o2=GetO(shift+1), c2=GetC(shift+1);
   double o1=GetO(shift),   c1=GetC(shift);
   bool bearish3 = c3<o3;
   double body3 = MathAbs(c3-o3);
   double body2 = MathAbs(c2-o2);
   bool smallStar = body2 < body3*0.5;
   bool bullish1 = c1>o1;
   double mid3 = (o3+c3)/2.0;
   return bearish3 && smallStar && bullish1 && (c1>mid3);
}

bool IsEveningStar(int shift)
{
   double o3=GetO(shift+2), c3=GetC(shift+2);
   double o2=GetO(shift+1), c2=GetC(shift+1);
   double o1=GetO(shift),   c1=GetC(shift);
   bool bullish3 = c3>o3;
   double body3 = MathAbs(c3-o3);
   double body2 = MathAbs(c2-o2);
   bool smallStar = body2 < body3*0.5;
   bool bearish1 = c1<o1;
   double mid3 = (o3+c3)/2.0;
   return bullish3 && smallStar && bearish1 && (c1<mid3);
}

bool HasBullishConfirmation(int shift)
{
   if(InpAllowPinBar    && IsBullishPinBar(shift))    return true;
   if(InpAllowEngulfing && IsBullishEngulfing(shift)) return true;
   if(InpAllowStar       && IsMorningStar(shift))      return true;
   return false;
}

bool HasBearishConfirmation(int shift)
{
   if(InpAllowPinBar    && IsBearishPinBar(shift))    return true;
   if(InpAllowEngulfing && IsBearishEngulfing(shift)) return true;
   if(InpAllowStar       && IsEveningStar(shift))      return true;
   return false;
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
// Trading gates
//====================================================================
bool HasOpenPosition()
{
   if(!PositionSelect(_Symbol)) return false;
   return PositionGetInteger(POSITION_MAGIC)==InpMagicNumber;
}

bool CanTradeNow()
{
   if(TimeCurrent() < g_pausedUntil) return false;
   double maxLossMoney = g_dayStartBalance*InpMaxDailyLossPercent/100.0;
   if(AccountInfoDouble(ACCOUNT_EQUITY) <= g_dayStartBalance-maxLossMoney) return false;

   double nyH = GetNYHourDecimal();
   if(InpEnableNewsFilter1 && InBlackout(nyH, InpNewsHour1, InpNewsBlackoutBefore1, InpNewsBlackoutAfter1)) return false;
   if(InpEnableNewsFilter2 && InBlackout(nyH, InpNewsHour2, InpNewsBlackoutBefore2, InpNewsBlackoutAfter2)) return false;
   return true;
}

bool IsMarketSideways()
{
   if(g_bbMiddle<=0) return true;
   double widthPct = (g_bbUpper-g_bbLower)/g_bbMiddle*100.0;
   if(widthPct < InpMinBandWidthPct) return true;
   if(!g_legValid) return true;
   if((g_legHigh-g_legLow) < InpMinLegATR*g_atr) return true;
   return false;
}

//====================================================================
// Entry execution
//====================================================================
bool ExecuteEntry(bool bullish, double entry, double sl, double tp1, double tp2, double tp3, string cmt)
{
   double risk = MathAbs(entry-sl);
   if(risk<=0) return false;

   double lots = CalculateLotSize(risk);
   if(lots<=0) return false;

   bool ok = bullish ? trade.Buy(lots, _Symbol, entry, sl, tp3, cmt)
                      : trade.Sell(lots, _Symbol, entry, sl, tp3, cmt);
   if(ok)
   {
      g_isBuy=bullish; g_tp1=tp1; g_tp2=tp2; g_tp3=tp3;
      g_tp1Done=false; g_tp2Done=false; g_initialVolume=lots;
      g_cntTrades++;
      PrintFormat("[ENTRY] %s dir=%s entry=%.5f sl=%.5f tp1=%.5f tp2=%.5f tp3=%.5f",
                  cmt, bullish?"BUY":"SELL", entry, sl, tp1, tp2, tp3);
   }
   return ok;
}

//====================================================================
// Setup check (BUY / SELL mirrors of the Fibonacci + BB pullback)
//====================================================================
void CheckSetup()
{
   if(!g_legValid) return;
   double range = g_legHigh - g_legLow;
   if(range<=0) return;

   double zoneFar  = g_legHigh - range*InpFiboZoneFar;  // deeper retracement (smaller price in bull leg)
   double zoneNear = g_legHigh - range*InpFiboZoneNear; // shallower retracement

   if(g_structTrend==1)
   {
      // pullback candle must dip into [zoneFar, zoneNear], touch the lower band,
      // then close back at/above the zone with a bullish confirmation pattern.
      bool dippedIntoZone = (g_bar1Low <= zoneNear && g_bar1Low >= g_legLow);
      bool touchedLowerBand = (g_bar1Low <= g_bbLower);
      bool closeOk = (g_bar1Close >= zoneFar);
      bool bullishCandle = (g_bar1Close > g_bar1Open);
      if(dippedIntoZone && touchedLowerBand && closeOk && bullishCandle && HasBullishConfirmation(1))
      {
         double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl    = MathMin(g_legLow, g_bbLower) - InpSLBufferATR*g_atr;
         double tp1   = g_legHigh;
         double tp2   = g_legLow + range*InpFiboExt1;
         double tp3   = g_legLow + range*InpFiboExt2;
         ExecuteEntry(true, entry, sl, tp1, tp2, tp3, "FiboBB-Buy");
      }
   }
   else if(g_structTrend==-1)
   {
      bool dippedIntoZone = (g_bar1High >= zoneFar && g_bar1High <= g_legHigh);
      bool touchedUpperBand = (g_bar1High >= g_bbUpper);
      bool closeOk = (g_bar1Close <= zoneNear);
      bool bearishCandle = (g_bar1Close < g_bar1Open);
      if(dippedIntoZone && touchedUpperBand && closeOk && bearishCandle && HasBearishConfirmation(1))
      {
         double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl    = MathMax(g_legHigh, g_bbUpper) + InpSLBufferATR*g_atr;
         double tp1   = g_legLow;
         double tp2   = g_legHigh - range*InpFiboExt1;
         double tp3   = g_legHigh - range*InpFiboExt2;
         ExecuteEntry(false, entry, sl, tp1, tp2, tp3, "FiboBB-Sell");
      }
   }
}

//====================================================================
// Position management: partial exits at TP1/TP2, breakeven step-up,
// early exit on an opposing confirmation candle before TP1 is banked.
//====================================================================
void ManageOpenPosition()
{
   if(!HasOpenPosition()) return;

   ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
   bool  isBuy  = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double vol   = PositionGetDouble(POSITION_VOLUME);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double curTP = PositionGetDouble(POSITION_TP);
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep<=0) lotStep=0.01;

   if(!g_tp1Done && g_tp1>0)
   {
      bool hit = isBuy ? (g_bar1High >= g_tp1) : (g_bar1Low <= g_tp1);
      if(hit)
      {
         double closeVol = MathFloor((g_initialVolume*InpTP1ClosePct/100.0)/lotStep)*lotStep;
         if(closeVol>=minLot && closeVol<vol)
            trade.PositionClosePartial(ticket, closeVol);
         trade.PositionModify(ticket, openPrice, curTP); // breakeven
         g_tp1Done=true;
         return;
      }
   }

   if(g_tp1Done && !g_tp2Done && g_tp2>0)
   {
      bool hit = isBuy ? (g_bar1High >= g_tp2) : (g_bar1Low <= g_tp2);
      if(hit)
      {
         vol = PositionGetDouble(POSITION_VOLUME);
         double closeVol = MathFloor((g_initialVolume*InpTP2ClosePct/100.0)/lotStep)*lotStep;
         if(closeVol>=minLot && closeVol<vol)
            trade.PositionClosePartial(ticket, closeVol);
         trade.PositionModify(ticket, g_tp1, curTP); // lock in gains to TP1
         g_tp2Done=true;
         return;
      }
   }

   // Only force-exit on an opposing confirmation candle before TP1 is banked;
   // once TP1 is taken the resting SL/TP already protect the trade.
   if(!g_tp1Done)
   {
      bool oppositeSignal = isBuy ? HasBearishConfirmation(1) : HasBullishConfirmation(1);
      if(oppositeSignal)
         trade.PositionClose(ticket);
   }
}

//====================================================================
// Bar caching / indicator refresh
//====================================================================
bool CacheBar1IfNew()
{
   datetime bt = iTime(_Symbol, InpTimeframe, 0);
   if(bt == g_lastBarTime) return false;
   g_lastBarTime = bt;
   g_bar1Time  = iTime(_Symbol,  InpTimeframe, 1);
   g_bar1Open  = iOpen(_Symbol,  InpTimeframe, 1);
   g_bar1High  = iHigh(_Symbol,  InpTimeframe, 1);
   g_bar1Low   = iLow(_Symbol,   InpTimeframe, 1);
   g_bar1Close = iClose(_Symbol, InpTimeframe, 1);
   return true;
}

bool UpdateIndicators()
{
   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   if(CopyBuffer(atrHandle, 0, 1, 1, atrBuf) < 1) return false;
   g_atr = atrBuf[0];

   double up[], mid[], lo[];
   ArraySetAsSeries(up, true); ArraySetAsSeries(mid, true); ArraySetAsSeries(lo, true);
   if(CopyBuffer(bbHandle, 1, 1, 1, up) < 1) return false;  // upper band
   if(CopyBuffer(bbHandle, 0, 1, 1, mid) < 1) return false; // middle band
   if(CopyBuffer(bbHandle, 2, 1, 1, lo) < 1) return false;  // lower band
   g_bbUpper=up[0]; g_bbMiddle=mid[0]; g_bbLower=lo[0];

   return g_atr>0 && g_bbMiddle>0;
}

//====================================================================
// Standard EA handlers
//====================================================================
int OnInit()
{
   atrHandle = iATR(_Symbol, InpTimeframe, InpATRPeriod);
   bbHandle  = iBands(_Symbol, InpTimeframe, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   if(atrHandle==INVALID_HANDLE || bbHandle==INVALID_HANDLE)
   {
      Print("Failed to create ATR/Bollinger Bands handle");
      return(INIT_FAILED);
   }
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);

   g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_currentDay = TimeCurrent() - (TimeCurrent()%86400);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   PrintFormat("[FiboBB-EA Summary] bars=%d trades=%d", (int)g_cntBarsEvaluated, (int)g_cntTrades);
   IndicatorRelease(atrHandle);
   IndicatorRelease(bbHandle);
}

void OnTick()
{
   if(!CacheBar1IfNew()) return;
   if(!UpdateIndicators()) return;

   UpdateSwings();
   CheckStructure();
   UpdateLeg();

   ManageOpenPosition();

   datetime today = TimeCurrent() - (TimeCurrent()%86400);
   if(today != g_currentDay)
   {
      g_currentDay = today;
      g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }

   if(!HasOpenPosition() && CanTradeNow() && !IsMarketSideways())
      CheckSetup();

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
      g_tp1=0; g_tp2=0; g_tp3=0; g_tp1Done=false; g_tp2Done=false; g_initialVolume=0;
   }
}
//+------------------------------------------------------------------+
