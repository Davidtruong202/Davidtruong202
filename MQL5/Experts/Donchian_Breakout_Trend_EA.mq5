//+------------------------------------------------------------------+
//|                                Donchian_Breakout_Trend_EA.mq5     |
//|  Trend-following breakout system (own design, not from a         |
//|  supplied document): EMA trend filter + Donchian channel         |
//|  breakout + ATR volatility-expansion confirmation for entries;   |
//|  ATR chandelier trailing stop + partial take-profit + pyramiding |
//|  for exits/scaling. Built for aggressive risk (2-3%/trade,       |
//|  accepts deeper drawdown for growth) on any symbol/timeframe.    |
//|  See README.md for design rationale and simplifications.         |
//+------------------------------------------------------------------+
#property copyright "Custom EA"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// Inputs
//====================================================================
input group "=== Timeframe ==="
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // works on whatever chart/timeframe the EA is attached to

input group "=== Trend filter (EMA) ==="
input int InpEMAFast = 50;
input int InpEMASlow = 200;

input group "=== Breakout / Donchian channel ==="
input int InpDonchianPeriod = 20; // channel lookback, excludes the signal bar itself (classic Turtle-style breakout)

input group "=== Volatility expansion filter ==="
input int    InpATRPeriod          = 14;
input int    InpATRAvgPeriod       = 50;  // rolling average window for ATR
input double InpATRExpansionFactor = 1.1; // require current ATR > average ATR * this factor

input group "=== Stops / Exits ==="
input double InpInitialSLATR    = 2.0; // initial protective stop, in ATR, from entry
input double InpChandelierATR   = 3.0; // trailing stop distance in ATR from the highest/lowest price since entry
input double InpPartialTPR      = 2.0; // take partial profit at this multiple of initial risk (R)
input double InpPartialClosePct = 30;  // % of current volume closed at the partial TP

input group "=== Pyramiding (adds to winners) ==="
input bool   InpEnablePyramid    = true;
input double InpPyramidStepATR   = 1.0; // add one more unit every N ATR of favorable movement from first entry
input int    InpMaxPyramidUnits  = 2;   // max add-on units beyond the first entry (was 3 - cut to reduce drawdown)

input group "=== Risk Management ==="
input double InpRiskPercent         = 1.5; // tuned down from 2.5% to bring backtest equity DD toward ~30%
input double InpMaxDailyLossPercent = 4.0; // scaled down with InpRiskPercent
input int    InpMaxConsecLosses     = 4;
input int    InpPauseMinutes        = 120;

input group "=== Optional news filter (off by default) ==="
input bool   InpEnableNewsFilter = false; // breakout systems often want to ride news-driven moves, so default off
input bool   InpBrokerFixedNYOffset  = true;
input double InpServerToNY_Hours     = 7.0;
input double InpServerGMTOffsetHours = 0.0;
input double InpNewsHour             = 8.5;
input double InpNewsBlackoutBefore   = 15;
input double InpNewsBlackoutAfter    = 15;

input group "=== Trade ==="
input int InpMagicNumber = 20260923;
input int InpSlippage    = 30;

//====================================================================
// Globals
//====================================================================
int emaFastHandle = INVALID_HANDLE;
int emaSlowHandle = INVALID_HANDLE;
int atrHandle     = INVALID_HANDLE;

datetime g_lastBarTime = 0;
double   g_bar1Open=0, g_bar1High=0, g_bar1Low=0, g_bar1Close=0;
double   g_emaFast1=0, g_emaSlow1=0, g_atr1=0;

double   g_donchianHighExcl=0, g_donchianLowExcl=0;

double   g_atrHist[];
int      g_atrHistIdx=0, g_atrHistCount=0;
double   g_atrHistSum=0, g_atrAvg=0;
bool     g_atrAvgReady=false;

double   g_dayStartBalance = 0;
datetime g_currentDay = 0;
int      g_consecLosses = 0;
datetime g_pausedUntil = 0;

// Open-trade tracking (first-entry anchor drives R-multiples & pyramid steps)
double   g_entryPriceFirst=0, g_priceRiskPerUnit=0;
double   g_highestSinceEntry=0, g_lowestSinceEntry=0;
int      g_pyramidUnitsAdded=0;
bool     g_partialTPDone=false;

long g_cntBarsEvaluated=0, g_cntTrades=0, g_cntPyramidAdds=0;

//====================================================================
// Timezone / news filter helpers (optional, off by default)
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
   return (h >= start || h < end);
}

//====================================================================
// Rolling ATR average (volatility-expansion filter)
//====================================================================
void PushATRHistory(double v)
{
   int n = ArraySize(g_atrHist);
   if(n<=0) return;
   if(g_atrHistCount<n)
   {
      g_atrHist[g_atrHistIdx]=v;
      g_atrHistSum+=v;
      g_atrHistCount++;
   }
   else
   {
      g_atrHistSum -= g_atrHist[g_atrHistIdx];
      g_atrHist[g_atrHistIdx]=v;
      g_atrHistSum += v;
   }
   g_atrHistIdx=(g_atrHistIdx+1)%n;
   g_atrAvgReady = (g_atrHistCount>=n);
   if(g_atrAvgReady) g_atrAvg = g_atrHistSum/n;
}

//====================================================================
// Donchian channel (excludes the just-closed signal bar itself)
//====================================================================
void UpdateDonchian()
{
   double hh=-DBL_MAX, ll=DBL_MAX;
   for(int i=2; i<=InpDonchianPeriod+1; i++)
   {
      double h=iHigh(_Symbol, InpTimeframe, i);
      double l=iLow(_Symbol, InpTimeframe, i);
      if(h>hh) hh=h;
      if(l<ll) ll=l;
   }
   g_donchianHighExcl=hh;
   g_donchianLowExcl=ll;
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
   if(!g_atrAvgReady) return false; // not enough history yet to judge volatility expansion

   if(InpEnableNewsFilter)
   {
      double nyH = GetNYHourDecimal();
      if(InBlackout(nyH, InpNewsHour, InpNewsBlackoutBefore, InpNewsBlackoutAfter)) return false;
   }
   return true;
}

//====================================================================
// Reset per-trade tracking (called when the position is fully flat)
//====================================================================
void ResetTradeTracking()
{
   g_entryPriceFirst=0; g_priceRiskPerUnit=0;
   g_highestSinceEntry=0; g_lowestSinceEntry=0;
   g_pyramidUnitsAdded=0; g_partialTPDone=false;
}

//====================================================================
// First entry
//====================================================================
void OpenNewTrade(bool bullish)
{
   double entry = bullish ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl    = bullish ? entry - InpInitialSLATR*g_atr1 : entry + InpInitialSLATR*g_atr1;
   double risk  = MathAbs(entry-sl);
   if(risk<=0) return;

   double lots = CalculateLotSize(risk);
   if(lots<=0) return;

   bool ok = bullish ? trade.Buy(lots, _Symbol, entry, sl, 0, "DonchianBreakout")
                      : trade.Sell(lots, _Symbol, entry, sl, 0, "DonchianBreakout");
   if(ok)
   {
      g_entryPriceFirst=entry; g_priceRiskPerUnit=risk;
      g_highestSinceEntry=entry; g_lowestSinceEntry=entry;
      g_pyramidUnitsAdded=0; g_partialTPDone=false;
      g_cntTrades++;
      PrintFormat("[ENTRY] dir=%s entry=%.5f sl=%.5f risk=%.5f", bullish?"BUY":"SELL", entry, sl, risk);
   }
}

void CheckEntry()
{
   bool trendBull = g_emaFast1 > g_emaSlow1;
   bool trendBear = g_emaFast1 < g_emaSlow1;
   bool volExpansion = g_atrAvgReady && (g_atr1 > g_atrAvg*InpATRExpansionFactor);
   if(!volExpansion) return;

   if(trendBull && g_bar1Close > g_donchianHighExcl)
      OpenNewTrade(true);
   else if(trendBear && g_bar1Close < g_donchianLowExcl)
      OpenNewTrade(false);
}

//====================================================================
// Position management: EMA-flip exit, chandelier trail, partial TP,
// pyramiding adds.
//====================================================================
void ManageOpenPosition()
{
   if(!HasOpenPosition()) { ResetTradeTracking(); return; }

   ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
   bool  isBuy  = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double curSL = PositionGetDouble(POSITION_SL);
   double curTP = PositionGetDouble(POSITION_TP);

   if(isBuy) g_highestSinceEntry = MathMax(g_highestSinceEntry, g_bar1High);
   else      g_lowestSinceEntry  = MathMin(g_lowestSinceEntry,  g_bar1Low);

   // Regime flip: the trend that justified this trade no longer holds.
   bool trendBull = g_emaFast1 > g_emaSlow1;
   bool trendBear = g_emaFast1 < g_emaSlow1;
   if((isBuy && trendBear) || (!isBuy && trendBull))
   {
      trade.PositionClose(ticket);
      ResetTradeTracking();
      return;
   }

   // Chandelier trailing stop - only ever tightens toward price.
   if(isBuy)
   {
      double candidate = g_highestSinceEntry - InpChandelierATR*g_atr1;
      if(candidate > curSL)
      {
         trade.PositionModify(ticket, candidate, curTP);
         curSL = candidate;
      }
   }
   else
   {
      double candidate = g_lowestSinceEntry + InpChandelierATR*g_atr1;
      if(curSL<=0 || candidate < curSL)
      {
         trade.PositionModify(ticket, candidate, curTP);
         curSL = candidate;
      }
   }

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep<=0) lotStep=0.01;

   // Partial take-profit at InpPartialTPR multiples of the first unit's risk.
   if(!g_partialTPDone && g_priceRiskPerUnit>0)
   {
      double tp1 = isBuy ? g_entryPriceFirst + g_priceRiskPerUnit*InpPartialTPR
                         : g_entryPriceFirst - g_priceRiskPerUnit*InpPartialTPR;
      bool hit = isBuy ? (g_bar1High >= tp1) : (g_bar1Low <= tp1);
      if(hit)
      {
         double vol = PositionGetDouble(POSITION_VOLUME);
         double closeVol = MathFloor((vol*InpPartialClosePct/100.0)/lotStep)*lotStep;
         if(closeVol>=minLot && closeVol<vol)
            trade.PositionClosePartial(ticket, closeVol);
         g_partialTPDone=true;
      }
   }

   // Pyramiding: add a unit every InpPyramidStepATR of favorable movement.
   if(InpEnablePyramid && g_pyramidUnitsAdded<InpMaxPyramidUnits && g_priceRiskPerUnit>0)
   {
      double threshold = isBuy ? g_entryPriceFirst + (g_pyramidUnitsAdded+1)*InpPyramidStepATR*g_atr1
                                : g_entryPriceFirst - (g_pyramidUnitsAdded+1)*InpPyramidStepATR*g_atr1;
      bool reached = isBuy ? (g_bar1Close >= threshold) : (g_bar1Close <= threshold);
      if(reached)
      {
         double addEntry = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double addSL     = isBuy ? addEntry - InpInitialSLATR*g_atr1 : addEntry + InpInitialSLATR*g_atr1;
         double addLots    = CalculateLotSize(MathAbs(addEntry-addSL));
         if(addLots>0)
         {
            // Protect the add-on leg with the current trailed stop too, so a
            // hedging account's separate ticket is never left unprotected.
            bool ok = isBuy ? trade.Buy(addLots, _Symbol, addEntry, curSL, 0, "DonchianPyramid")
                             : trade.Sell(addLots, _Symbol, addEntry, curSL, 0, "DonchianPyramid");
            if(ok)
            {
               g_pyramidUnitsAdded++;
               g_cntPyramidAdds++;
               PrintFormat("[PYRAMID] unit=%d dir=%s entry=%.5f", g_pyramidUnitsAdded, isBuy?"BUY":"SELL", addEntry);
            }
         }
      }
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
   g_bar1Open  = iOpen(_Symbol,  InpTimeframe, 1);
   g_bar1High  = iHigh(_Symbol,  InpTimeframe, 1);
   g_bar1Low   = iLow(_Symbol,   InpTimeframe, 1);
   g_bar1Close = iClose(_Symbol, InpTimeframe, 1);
   return true;
}

bool UpdateIndicators()
{
   double emaF[], emaS[], atrBuf[];
   ArraySetAsSeries(emaF, true); ArraySetAsSeries(emaS, true); ArraySetAsSeries(atrBuf, true);
   if(CopyBuffer(emaFastHandle, 0, 1, 1, emaF) < 1) return false;
   if(CopyBuffer(emaSlowHandle, 0, 1, 1, emaS) < 1) return false;
   if(CopyBuffer(atrHandle, 0, 1, 1, atrBuf) < 1) return false;

   g_emaFast1=emaF[0]; g_emaSlow1=emaS[0]; g_atr1=atrBuf[0];
   if(g_atr1<=0) return false;

   PushATRHistory(g_atr1);
   return true;
}

//====================================================================
// Standard EA handlers
//====================================================================
int OnInit()
{
   emaFastHandle = iMA(_Symbol, InpTimeframe, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, InpTimeframe, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle     = iATR(_Symbol, InpTimeframe, InpATRPeriod);
   if(emaFastHandle==INVALID_HANDLE || emaSlowHandle==INVALID_HANDLE || atrHandle==INVALID_HANDLE)
   {
      Print("Failed to create EMA/ATR handle");
      return(INIT_FAILED);
   }

   ArrayResize(g_atrHist, InpATRAvgPeriod);
   g_atrHistIdx=0; g_atrHistCount=0; g_atrHistSum=0; g_atrAvgReady=false;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);

   g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_currentDay = TimeCurrent() - (TimeCurrent()%86400);

   ResetTradeTracking();

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   PrintFormat("[Donchian-EA Summary] bars=%d trades=%d pyramidAdds=%d",
               (int)g_cntBarsEvaluated, (int)g_cntTrades, (int)g_cntPyramidAdds);
   IndicatorRelease(emaFastHandle);
   IndicatorRelease(emaSlowHandle);
   IndicatorRelease(atrHandle);
}

void OnTick()
{
   if(!CacheBar1IfNew()) return;
   if(!UpdateIndicators()) return;

   UpdateDonchian();
   ManageOpenPosition();

   datetime today = TimeCurrent() - (TimeCurrent()%86400);
   if(today != g_currentDay)
   {
      g_currentDay = today;
      g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }

   if(!HasOpenPosition() && CanTradeNow())
      CheckEntry();

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
      ResetTradeTracking();
}
//+------------------------------------------------------------------+
