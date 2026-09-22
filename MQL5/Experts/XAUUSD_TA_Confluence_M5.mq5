//+------------------------------------------------------------------+
//|                                XAUUSD_TA_Confluence_M5.mq5       |
//|  Multi-indicator confluence EA for XAUUSD, M5.                   |
//|  Signal = vote count across RSI(14), MACD(12,26,9), ADX(14)      |
//|  direction, Stochastic %K, CCI(20), ROC(9) - the same indicator  |
//|  set shown in the chart's "TECHNICALS" panel. The panel's own    |
//|  "AI Forecast" and "TCX Indicator Pro" are proprietary to that   |
//|  app (no published formula), so they are NOT reproduced here;    |
//|  this confluence score is a standard-indicator substitute for    |
//|  them, not a copy.                                               |
//|  TP1/TP2/TP3 = nearest 3 swing highs/lows beyond entry (support/ |
//|  resistance), SL = nearest opposing swing beyond entry, buffered |
//|  by ATR. See README.md for details and simplifications.          |
//+------------------------------------------------------------------+
#property copyright "Custom EA"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// Inputs
//====================================================================
input group "=== Indicators ==="
input int    InpRSIPeriod      = 14;
input int    InpMACDFast       = 12;
input int    InpMACDSlow       = 26;
input int    InpMACDSignal     = 9;
input int    InpADXPeriod      = 14;
input double InpADXMinTrend    = 20.0;  // skip entries when ADX below this (ranging market)
input int    InpStochK         = 14;
input int    InpStochD         = 3;
input int    InpStochSlowing   = 3;
input int    InpCCIPeriod      = 20;
input int    InpROCPeriod      = 9;

input group "=== Confluence ==="
input int    InpMinScore       = 5;     // min aligned indicators out of 6 to enter (5-6 recommended)
input bool   InpUseVolumeFilter= true;
input int    InpVolMAPeriod    = 20;
input double InpMinVolRatio    = 0.7;   // skip entries when tick volume < ratio * its MA (matches "Volume: Low")

input group "=== Swing structure (TP/SL) ==="
input int    InpPivLen         = 6;     // fractal confirmation bars each side
input int    InpMaxSwingsKept  = 150;   // trim oldest swings beyond this count
input int    InpATRPeriod      = 14;
input double InpSLBufferATR    = 0.3;   // extra buffer beyond the opposing swing
input double InpFallbackATRmult= 1.5;   // used only when no swing level is found
input double InpMinRR_TP1      = 1.0;   // reject trade if TP1 R:R below this

input group "=== Risk management ==="
input double InpRiskPercent         = 0.75;
input double InpMaxDailyLossPercent = 3.0;
input int    InpMaxConsecLosses     = 3;
input int    InpPauseMinutes        = 60;
input double InpMaxSpreadPoints     = 350; // skip entries when spread above this (points)

input group "=== Trade ==="
input int InpMagicNumber = 20260922;
input int InpSlippage    = 30;

//====================================================================
// Swing structure
//====================================================================
struct SwingLevel
{
   double   price;
   bool     isHigh;
   datetime formed;
};
SwingLevel swings[];

void TrimSwings()
{
   int n = ArraySize(swings);
   if(n <= InpMaxSwingsKept) return;
   int drop = n - InpMaxSwingsKept;
   for(int i=0; i<n-drop; i++) swings[i] = swings[i+drop];
   ArrayResize(swings, n-drop);
}

void AppendSwing(double price, bool isHigh, datetime t)
{
   int n = ArraySize(swings);
   ArrayResize(swings, n+1);
   swings[n].price = price;
   swings[n].isHigh = isHigh;
   swings[n].formed = t;
   TrimSwings();
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
   if(isHigh) AppendSwing(hi, true,  t);
   if(isLow)  AppendSwing(lo, false, t);
}

// Collect up to 3 nearest swing levels of the requested type beyond refPrice,
// sorted by distance, into out[]. Returns count found (0-3).
int NearestSwings(bool wantHigh, double refPrice, bool above, double &out[])
{
   double cand[]; int cn=0;
   ArrayResize(cand, ArraySize(swings));
   for(int i=0; i<ArraySize(swings); i++)
   {
      if(swings[i].isHigh != wantHigh) continue;
      double p = swings[i].price;
      if(above && p<=refPrice) continue;
      if(!above && p>=refPrice) continue;
      cand[cn++] = p;
   }
   ArrayResize(cand, cn);
   ArraySort(cand); // ascending
   ArrayResize(out, 0);
   if(above)
   {
      for(int i=0; i<cn && i<3; i++) { int n=ArraySize(out); ArrayResize(out,n+1); out[n]=cand[i]; }
   }
   else
   {
      for(int i=cn-1; i>=0 && ArraySize(out)<3; i--) { int n=ArraySize(out); ArrayResize(out,n+1); out[n]=cand[i]; }
   }
   return ArraySize(out);
}

double NearestOpposing(bool wantHigh, double refPrice, bool above)
{
   double out[];
   if(NearestSwings(wantHigh, refPrice, above, out) > 0) return out[0];
   return 0;
}

//====================================================================
// Indicator handles / globals
//====================================================================
int h_rsi=INVALID_HANDLE, h_macd=INVALID_HANDLE, h_adx=INVALID_HANDLE,
    h_stoch=INVALID_HANDLE, h_cci=INVALID_HANDLE, h_atr=INVALID_HANDLE, h_volma=INVALID_HANDLE;

double g_atr=0;
datetime g_lastBarTime=0;

double g_dayStartBalance=0;
datetime g_currentDay=0;
int g_consecLosses=0;
datetime g_pausedUntil=0;

double g_tp1=0, g_tp2=0, g_tp3=0;
bool   g_tp1Taken=false, g_tp2Taken=false;

//====================================================================
// Indicator reads (value at the last CLOSED bar, shift=1)
//====================================================================
bool GetShift1(int handle, int bufferIdx, double &val)
{
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(handle, bufferIdx, 1, 1, buf) < 1) return false;
   val = buf[0];
   return true;
}

double ComputeROC()
{
   double c1 = iClose(_Symbol, PERIOD_M5, 1);
   double c0 = iClose(_Symbol, PERIOD_M5, 1+InpROCPeriod);
   if(c0<=0) return 0;
   return (c1-c0)/c0*100.0;
}

//====================================================================
// Confluence score
//====================================================================
bool ComputeSignal(int &bullScore, int &bearScore, double &adxVal, bool &adxBull)
{
   bullScore=0; bearScore=0;
   double rsi, macdMain, macdSignal, adxMain, plusDI, minusDI, kMain, cci;
   if(!GetShift1(h_rsi, 0, rsi)) return false;
   if(!GetShift1(h_macd, 0, macdMain)) return false;
   if(!GetShift1(h_macd, 1, macdSignal)) return false;
   if(!GetShift1(h_adx, 0, adxMain)) return false;
   if(!GetShift1(h_adx, 1, plusDI)) return false;
   if(!GetShift1(h_adx, 2, minusDI)) return false;
   if(!GetShift1(h_stoch, 0, kMain)) return false;
   if(!GetShift1(h_cci, 0, cci)) return false;
   double roc = ComputeROC();

   adxVal = adxMain;
   adxBull = (plusDI > minusDI);

   if(rsi > 50) bullScore++; else bearScore++;
   if(macdMain > macdSignal) bullScore++; else bearScore++;
   if(adxBull) bullScore++; else bearScore++;
   if(kMain > 50) bullScore++; else bearScore++;
   if(cci > 0) bullScore++; else bearScore++;
   if(roc > 0) bullScore++; else bearScore++;

   return true;
}

bool VolumeOk()
{
   if(!InpUseVolumeFilter) return true;
   double vbuf[]; ArraySetAsSeries(vbuf, true);
   if(CopyBuffer(h_volma, 0, 1, 1, vbuf) < 1) return true;
   long curVol = iVolume(_Symbol, PERIOD_M5, 1);
   if(vbuf[0] <= 0) return true;
   return (curVol >= InpMinVolRatio * vbuf[0]);
}

//====================================================================
// Risk sizing (same technique as the ICT EA)
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
// Entry execution
//====================================================================
bool HasOpenPosition()
{
   if(!PositionSelect(_Symbol)) return false;
   return PositionGetInteger(POSITION_MAGIC)==InpMagicNumber;
}

bool SpreadOk()
{
   double spreadPoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return spreadPoints <= InpMaxSpreadPoints;
}

void TryEnter(bool bullish, double entry)
{
   double targets[];
   // TP: swing highs above entry for a buy, swing lows below entry for a sell (resistance/support ahead)
   NearestSwings(bullish, entry, bullish, targets);
   double atrSL = bullish ? entry - InpFallbackATRmult*g_atr : entry + InpFallbackATRmult*g_atr;
   // SL: nearest swing low below entry for a buy, swing high above entry for a sell (structure behind entry)
   double opposing = NearestOpposing(!bullish, entry, !bullish);
   double sl = (opposing>0) ? (bullish ? opposing - InpSLBufferATR*g_atr : opposing + InpSLBufferATR*g_atr) : atrSL;

   double tp1 = (ArraySize(targets)>=1) ? targets[0] : (bullish ? entry+1.0*(entry-sl) : entry-1.0*(sl-entry));
   double tp2 = (ArraySize(targets)>=2) ? targets[1] : (bullish ? entry+2.0*(entry-sl) : entry-2.0*(sl-entry));
   double tp3 = (ArraySize(targets)>=3) ? targets[2] : (bullish ? entry+3.0*(entry-sl) : entry-3.0*(sl-entry));

   double risk = MathAbs(entry-sl);
   if(risk<=0) return;
   double rr1 = MathAbs(tp1-entry)/risk;
   if(rr1 < InpMinRR_TP1) return;

   double lots = CalculateLotSize(risk);
   if(lots<=0) return;

   bool ok = bullish ? trade.Buy(lots, _Symbol, entry, sl, tp3, "TA-Confluence")
                      : trade.Sell(lots, _Symbol, entry, sl, tp3, "TA-Confluence");
   if(ok)
   {
      g_tp1=tp1; g_tp2=tp2; g_tp3=tp3; g_tp1Taken=false; g_tp2Taken=false;
      PrintFormat("[ENTRY] dir=%s entry=%.2f sl=%.2f tp1=%.2f tp2=%.2f tp3=%.2f",
                  bullish?"BUY":"SELL", entry, sl, tp1, tp2, tp3);
   }
}

//====================================================================
// Position management: partials at TP1/TP2, ride remainder to TP3
//====================================================================
void ManageOpenPosition()
{
   if(!HasOpenPosition()) { g_tp1Taken=false; g_tp2Taken=false; return; }

   ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
   bool  isBuy  = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double vol   = PositionGetDouble(POSITION_VOLUME);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double curTP = PositionGetDouble(POSITION_TP);
   double curSL = PositionGetDouble(POSITION_SL);

   double lastClose = iClose(_Symbol, PERIOD_M5, 1);
   double lastHigh   = iHigh(_Symbol, PERIOD_M5, 1);
   double lastLow    = iLow(_Symbol, PERIOD_M5, 1);
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep<=0) lotStep=0.01;

   if(!g_tp1Taken && g_tp1>0)
   {
      bool hit = isBuy ? (lastHigh >= g_tp1) : (lastLow <= g_tp1);
      if(hit)
      {
         double closeVol = MathFloor((vol/3.0)/lotStep)*lotStep;
         if(closeVol>=minLot && closeVol<vol)
            trade.PositionClosePartial(ticket, closeVol);
         trade.PositionModify(ticket, openPrice, curTP); // SL -> breakeven
         g_tp1Taken=true;
      }
   }
   else if(g_tp1Taken && !g_tp2Taken && g_tp2>0)
   {
      bool hit = isBuy ? (lastHigh >= g_tp2) : (lastLow <= g_tp2);
      if(hit)
      {
         double closeVol = MathFloor((vol*0.5)/lotStep)*lotStep;
         if(closeVol>=minLot && closeVol<vol)
            trade.PositionClosePartial(ticket, closeVol);
         trade.PositionModify(ticket, g_tp1, curTP); // SL -> TP1 (lock in)
         g_tp2Taken=true;
      }
   }

   // Reversal exit before TP1 is banked: strong opposing confluence flip
   if(!g_tp1Taken)
   {
      int bull, bear; double adxVal; bool adxBull;
      if(ComputeSignal(bull, bear, adxVal, adxBull))
      {
         bool opposingFlip = isBuy ? (bear >= InpMinScore) : (bull >= InpMinScore);
         if(opposingFlip)
            trade.PositionClose(ticket);
      }
   }
}

//====================================================================
// Trading gates
//====================================================================
bool CanTradeNow()
{
   if(TimeCurrent() < g_pausedUntil) return false;
   double maxLossMoney = g_dayStartBalance*InpMaxDailyLossPercent/100.0;
   if(AccountInfoDouble(ACCOUNT_EQUITY) <= g_dayStartBalance-maxLossMoney) return false;
   if(!SpreadOk()) return false;
   if(!VolumeOk()) return false;
   return true;
}

//====================================================================
// Bar caching / ATR
//====================================================================
bool CacheBarIfNew()
{
   datetime bt = iTime(_Symbol, PERIOD_M5, 0);
   if(bt == g_lastBarTime) return false;
   g_lastBarTime = bt;
   return true;
}

bool UpdateATR()
{
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(h_atr, 0, 1, 1, buf) < 1) return false;
   g_atr = buf[0];
   return g_atr>0;
}

//====================================================================
// Standard EA handlers
//====================================================================
int OnInit()
{
   h_rsi   = iRSI(_Symbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);
   h_macd  = iMACD(_Symbol, PERIOD_M5, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   h_adx   = iADX(_Symbol, PERIOD_M5, InpADXPeriod);
   h_stoch = iStochastic(_Symbol, PERIOD_M5, InpStochK, InpStochD, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
   h_cci   = iCCI(_Symbol, PERIOD_M5, InpCCIPeriod, PRICE_TYPICAL);
   h_atr   = iATR(_Symbol, PERIOD_M5, InpATRPeriod);
   h_volma = iMA(_Symbol, PERIOD_M5, InpVolMAPeriod, 0, MODE_SMA, VOLUME_TICK);

   if(h_rsi==INVALID_HANDLE || h_macd==INVALID_HANDLE || h_adx==INVALID_HANDLE ||
      h_stoch==INVALID_HANDLE || h_cci==INVALID_HANDLE || h_atr==INVALID_HANDLE || h_volma==INVALID_HANDLE)
   {
      Print("Failed to create one or more indicator handles");
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
   IndicatorRelease(h_rsi);
   IndicatorRelease(h_macd);
   IndicatorRelease(h_adx);
   IndicatorRelease(h_stoch);
   IndicatorRelease(h_cci);
   IndicatorRelease(h_atr);
   IndicatorRelease(h_volma);
}

void OnTick()
{
   if(!CacheBarIfNew()) return;
   if(!UpdateATR()) return;

   UpdateSwings();
   ManageOpenPosition();

   datetime today = TimeCurrent() - (TimeCurrent()%86400);
   if(today != g_currentDay)
   {
      g_currentDay = today;
      g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }

   if(!HasOpenPosition() && CanTradeNow())
   {
      int bull, bear; double adxVal; bool adxBull;
      if(!ComputeSignal(bull, bear, adxVal, adxBull)) return;
      if(adxVal < InpADXMinTrend) return;

      if(bull >= InpMinScore && adxBull)
         TryEnter(true, SymbolInfoDouble(_Symbol, SYMBOL_ASK));
      else if(bear >= InpMinScore && !adxBull)
         TryEnter(false, SymbolInfoDouble(_Symbol, SYMBOL_BID));
   }
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
      g_tp1=0; g_tp2=0; g_tp3=0; g_tp1Taken=false; g_tp2Taken=false;
   }
}
//+------------------------------------------------------------------+
