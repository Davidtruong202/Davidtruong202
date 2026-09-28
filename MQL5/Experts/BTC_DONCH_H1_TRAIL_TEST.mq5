//+------------------------------------------------------------------+
//|                                    BTC_DONCH_H1_TRAIL_TEST.mq5   |
//|  STRATEGY TESTER VERSION: same logic, defaults reproduce the     |
//|  research run (1% risk, spread filter and protections disabled). |
//|  DO NOT use on a live/demo chart.                                |
//|  BTCUSD H1 trend-following EA - second leg of the BTC portfolio  |
//|  (research/btc/run_portfolio.py, docs/btcusd_research/04_...md). |
//|                                                                  |
//|  Signal (on the H1 bar that just CLOSED):                        |
//|   BUY : close > highest high of the 55 bars before it and        |
//|         EMA50 > EMA200 (H1).   SELL: mirror image.               |
//|  Exit : initial SL = InpSlATR x ATR14(H1) from fill, no TP,      |
//|         trailing stop InpTrailATR x ATR14(H1) (distance fixed at |
//|         entry), moved after each closed M1 bar to                |
//|         (M1 high - trail) for BUY / (M1 low + spread + trail)    |
//|         for SELL, never loosened. Forced close after             |
//|         InpMaxHoldMin minutes. One position at a time.           |
//|  No grid, no DCA, no martingale.                                 |
//|  Indicators computed with the research formulas (see MOM EA).    |
//+------------------------------------------------------------------+
#property copyright "BTC research EA"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

input group "=== Signal (locked research values) ==="
input int    InpBreakBars   = 55;    // Close must break the extreme of N prior H1 bars
input bool   InpTrendFilter = true;  // Require EMA50/EMA200 (H1) in trade direction

input group "=== Exits (locked research values) ==="
input double InpSlATR       = 2.0;   // Initial SL, x ATR14 (H1)
input double InpTrailATR    = 2.0;   // Trailing distance, x ATR14 (H1) at entry
input int    InpMaxHoldMin  = 11520; // Force close after N minutes (192 H1 bars)

input group "=== Risk & protection ==="
input double InpRiskPct         = 1.0;   // Risk per trade, % of balance
input double InpMaxRiskOverMult = 1.5;   // Skip if min lot would risk more than this x target
input double InpMaxSpreadUSD    = 100000;  // Skip entry if spread (price units) is above this
input double InpMaxSpreadSLPct  = 100;   // Skip entry if spread > this % of SL distance
input double InpDailyLossPct    = 100;   // Stop new entries for the day after this loss
input int    InpMaxConsecLosses = 100000;     // Pause after N consecutive losing trades
input int    InpPauseHours      = 24;    // Pause length
input double InpKillDDPct       = 100;  // Stop trading permanently if equity DD from peak exceeds this

input group "=== Misc ==="
input long   InpMagic       = 20260929;
input int    InpSlippagePts = 300;   // Max deviation in points
input int    InpCalcBars    = 1500;  // Bars used to compute indicators (warm-up)
input bool   InpWriteCsvLog = true;  // Write trade log CSV to MQL5/Files

//--- state
datetime g_lastH1 = 0, g_lastM1 = 0;
datetime g_dayStart = 0;
double   g_dayStartBalance = 0;
int      g_consecLosses = 0;
datetime g_pausedUntil = 0;
string   g_gvPeak, g_gvKill;
string   g_logName;
double   g_lastRisk = 0;
int      g_lastDir = 0;
datetime g_lastSig = 0;

string TrailKey(ulong ticket) { return StringFormat("DONCHH1_%I64d_trail_%I64u", InpMagic, ticket); }

//+------------------------------------------------------------------+
//| Helpers shared with BTC_MOM_M15_H1.mq5 (identical code)           |
//+------------------------------------------------------------------+
bool GetRates(ENUM_TIMEFRAMES tf, int count, MqlRates &r[])
{
   ArraySetAsSeries(r, false);
   int got = CopyRates(_Symbol, tf, 1, count, r);   // shift 1 = closed bars only
   return got == count;
}

// EMA seeded with the first value, alpha = 2/(n+1)  (pandas ewm(span=n, adjust=False))
double EmaLast(const MqlRates &r[], int n)
{
   double a = 2.0 / (n + 1.0);
   double e = r[0].close;
   for(int i = 1; i < ArraySize(r); i++)
      e = a * r[i].close + (1.0 - a) * e;
   return e;
}

// Wilder ATR, alpha = 1/n, seeded with first true range
double AtrLast(const MqlRates &r[], int n)
{
   double a = 1.0 / n;
   double v = r[0].high - r[0].low;
   for(int i = 1; i < ArraySize(r); i++)
   {
      double pc = r[i - 1].close;
      double tr = MathMax(r[i].high - r[i].low, MathMax(MathAbs(r[i].high - pc), MathAbs(r[i].low - pc)));
      v = a * tr + (1.0 - a) * v;
   }
   return v;
}

// Wilder ADX (same construction as research/btc/indicators.py)
double AdxLast(const MqlRates &r[], int n)
{
   double a = 1.0 / n;
   int sz = ArraySize(r);
   double atr = r[0].high - r[0].low, spdm = 0, sndm = 0, adx = 0;
   bool adxInit = false;
   for(int i = 1; i < sz; i++)
   {
      double up = r[i].high - r[i - 1].high;
      double dn = r[i - 1].low - r[i].low;
      double pdm = (up > dn && up > 0) ? up : 0.0;
      double ndm = (dn > up && dn > 0) ? dn : 0.0;
      double pc = r[i - 1].close;
      double tr = MathMax(r[i].high - r[i].low, MathMax(MathAbs(r[i].high - pc), MathAbs(r[i].low - pc)));
      atr  = a * tr + (1.0 - a) * atr;
      spdm = a * pdm + (1.0 - a) * spdm;
      sndm = a * ndm + (1.0 - a) * sndm;
      if(atr <= 0) continue;
      double pdi = 100.0 * spdm / atr, ndi = 100.0 * sndm / atr;
      if(pdi + ndi <= 0) continue;
      double dx = 100.0 * MathAbs(pdi - ndi) / (pdi + ndi);
      if(!adxInit) { adx = dx; adxInit = true; }
      else adx = a * dx + (1.0 - a) * adx;
   }
   return adx;
}

//+------------------------------------------------------------------+
//| Position helpers                                                  |
//+------------------------------------------------------------------+
bool FindPosition(ulong &ticket)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagic)
      {
         ticket = t;
         return true;
      }
   }
   return false;
}

double LotsForRisk(double slDist, double &actualRiskMoney)
{
   actualRiskMoney = 0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickValue <= 0) tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double minLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step      = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(tickValue <= 0 || tickSize <= 0 || slDist <= 0 || step <= 0) return 0;

   double lossPerLot = slDist / tickSize * tickValue;
   double target = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPct / 100.0;
   double lots = MathFloor(target / lossPerLot / step) * step;
   if(lots < minLot)
   {
      // Account too small for the target risk: only trade min lot if it is not far above target
      if(minLot * lossPerLot > target * InpMaxRiskOverMult)
      {
         PrintFormat("[SKIP] min lot %.2f risks %.2f > %.1fx target %.2f - account too small for this SL",
                     minLot, minLot * lossPerLot, InpMaxRiskOverMult, target);
         return 0;
      }
      lots = minLot;
   }
   lots = MathMin(lots, maxLot);
   actualRiskMoney = lots * lossPerLot;
   int digits = (int)MathMax(0, MathCeil(-MathLog10(step)));
   return NormalizeDouble(lots, digits);
}

//+------------------------------------------------------------------+
//| Protection                                                        |
//+------------------------------------------------------------------+
void UpdateDay()
{
   datetime now = TimeCurrent();
   datetime d = now - (now % 86400);
   if(d != g_dayStart)
   {
      g_dayStart = d;
      g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }
}

bool KillSwitchActive()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double peak = GlobalVariableCheck(g_gvPeak) ? GlobalVariableGet(g_gvPeak) : eq;
   if(eq > peak) { peak = eq; GlobalVariableSet(g_gvPeak, peak); }
   if(GlobalVariableCheck(g_gvKill) && GlobalVariableGet(g_gvKill) > 0) return true;
   if(peak > 0 && (peak - eq) / peak * 100.0 >= InpKillDDPct)
   {
      GlobalVariableSet(g_gvKill, 1);
      PrintFormat("[KILL] Equity drawdown %.1f%% >= %.1f%%. Trading stopped. Delete global variable %s to re-enable.",
                  (peak - eq) / peak * 100.0, InpKillDDPct, g_gvKill);
      return true;
   }
   return false;
}

bool CanOpen(string &why)
{
   if(KillSwitchActive()) { why = "kill-switch"; return false; }
   if(TimeCurrent() < g_pausedUntil) { why = "paused after losing streak"; return false; }
   double dayLoss = g_dayStartBalance - AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_dayStartBalance > 0 && dayLoss >= g_dayStartBalance * InpDailyLossPct / 100.0)
   { why = "daily loss limit"; return false; }
   return true;
}

//+------------------------------------------------------------------+
//| CSV log                                                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| CSV log                                                           |
//+------------------------------------------------------------------+
void LogLine(string line)
{
   if(!InpWriteCsvLog) return;
   int h = FileOpen(g_logName, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
   if(h == INVALID_HANDLE) return;
   if(FileSize(h) == 0)
      FileWriteString(h, "time,event,ticket,dir,signal_time,price,sl,trail,lots,atr_h1,ema50_h1,ema200_h1,"
                         "spread,risk_money,profit,r_multiple,reason\r\n");
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, line + "\r\n");
   FileClose(h);
}

//+------------------------------------------------------------------+
//| Signal evaluation on a newly closed H1 bar                        |
//+------------------------------------------------------------------+
void EvaluateSignal()
{
   MqlRates h1[];
   if(!GetRates(PERIOD_H1, InpCalcBars, h1)) { Print("[WARN] not enough H1 history"); return; }
   int last = ArraySize(h1) - 1;
   MqlRates b = h1[last];

   double atr = AtrLast(h1, 14);
   if(atr <= 0) return;
   double hh = -DBL_MAX, ll = DBL_MAX;
   for(int i = last - InpBreakBars; i < last; i++)
   {
      hh = MathMax(hh, h1[i].high);
      ll = MathMin(ll, h1[i].low);
   }
   int dir = 0;
   if(b.close > hh) dir = 1;
   if(b.close < ll) dir = -1;
   if(dir == 0) return;
   double e50 = EmaLast(h1, 50), e200 = EmaLast(h1, 200);
   if(InpTrendFilter && ((dir == 1 && e50 <= e200) || (dir == -1 && e50 >= e200))) return;

   string why;
   if(!CanOpen(why)) { PrintFormat("[SKIP] signal %s blocked: %s", dir > 0 ? "BUY" : "SELL", why); return; }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK), bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = ask - bid;
   double slDist = InpSlATR * atr;
   double trail  = InpTrailATR * atr;
   if(spread > InpMaxSpreadUSD || spread > slDist * InpMaxSpreadSLPct / 100.0)
   {
      PrintFormat("[SKIP] spread %.2f too wide (SL dist %.2f)", spread, slDist);
      return;
   }
   double riskMoney;
   double lots = LotsForRisk(slDist, riskMoney);
   if(lots <= 0) return;

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double px = dir > 0 ? ask : bid;
   double sl = NormalizeDouble(dir > 0 ? px - slDist : px + slDist, digits);
   bool ok = dir > 0 ? trade.Buy(lots, _Symbol, 0, sl, 0, "DONCHH1") : trade.Sell(lots, _Symbol, 0, sl, 0, "DONCHH1");
   if(!ok)
   {
      PrintFormat("[ERROR] order failed: %d %s", trade.ResultRetcode(), trade.ResultRetcodeDescription());
      return;
   }
   ulong ticket;
   if(FindPosition(ticket))
   {
      double fill = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl2 = NormalizeDouble(dir > 0 ? fill - slDist : fill + slDist, digits);
      if(MathAbs(sl2 - sl) > SymbolInfoDouble(_Symbol, SYMBOL_POINT))
         trade.PositionModify(ticket, sl2, 0);
      px = fill; sl = sl2;
      GlobalVariableSet(TrailKey(ticket), trail);   // survives EA / terminal restarts
   }
   g_lastRisk = riskMoney; g_lastDir = dir; g_lastSig = b.time;
   PrintFormat("[ENTRY] %s lots=%.2f px=%.2f sl=%.2f trail=%.2f atr=%.2f spread=%.2f risk=%.2f",
               dir > 0 ? "BUY" : "SELL", lots, px, sl, trail, atr, spread, riskMoney);
   LogLine(StringFormat("%s,ENTRY,%I64u,%d,%s,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,,,",
                        TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), trade.ResultOrder(), dir,
                        TimeToString(b.time, TIME_DATE | TIME_MINUTES), px, sl, trail, lots, atr, e50, e200,
                        spread, riskMoney));
}

//+------------------------------------------------------------------+
//| Trailing stop (after each closed M1 bar) and time exit            |
//+------------------------------------------------------------------+
void ManagePosition(bool newM1)
{
   ulong ticket;
   if(!FindPosition(ticket)) return;
   datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
   if(TimeCurrent() - opened >= InpMaxHoldMin * 60)
   {
      if(trade.PositionClose(ticket)) PrintFormat("[EXIT] time limit reached (%d min)", InpMaxHoldMin);
      return;
   }
   if(!newM1) return;
   if(!GlobalVariableCheck(TrailKey(ticket))) return;
   double trail = GlobalVariableGet(TrailKey(ticket));
   if(trail <= 0) return;

   // only M1 bars that closed after the position was opened count
   datetime barT = iTime(_Symbol, PERIOD_M1, 1);
   if(barT + 60 <= opened) return;
   bool isBuy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
   double curSL = PositionGetDouble(POSITION_SL);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double newSL;
   if(isBuy)
   {
      newSL = NormalizeDouble(iHigh(_Symbol, PERIOD_M1, 1) - trail, digits);
      if(newSL <= curSL) return;
      if(newSL >= SymbolInfoDouble(_Symbol, SYMBOL_BID)) return;   // price already below: SL would be invalid
   }
   else
   {
      newSL = NormalizeDouble(iLow(_Symbol, PERIOD_M1, 1) + spread + trail, digits);
      if(curSL > 0 && newSL >= curSL) return;
      if(newSL <= SymbolInfoDouble(_Symbol, SYMBOL_ASK)) return;
   }
   trade.PositionModify(ticket, newSL, 0);
}

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber((ulong)InpMagic);
   trade.SetDeviationInPoints(InpSlippagePts);
   trade.SetTypeFillingBySymbol(_Symbol);
   g_gvPeak = StringFormat("DONCHH1_%I64d_%s_peak", InpMagic, _Symbol);
   g_gvKill = StringFormat("DONCHH1_%I64d_%s_kill", InpMagic, _Symbol);
   g_logName = StringFormat("DONCHH1_%s_%I64d.csv", _Symbol, InpMagic);
   if(MQLInfoInteger(MQL_TESTER))
   {
      GlobalVariableDel(g_gvPeak);
      GlobalVariableDel(g_gvKill);
   }
   UpdateDay();
   g_lastH1 = iTime(_Symbol, PERIOD_H1, 0);
   g_lastM1 = iTime(_Symbol, PERIOD_M1, 0);
   PrintFormat("[INIT] %s magic=%I64d risk=%.2f%% SL=%.1fATR trail=%.1fATR hold=%dmin",
               _Symbol, InpMagic, InpRiskPct, InpSlATR, InpTrailATR, InpMaxHoldMin);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {}

void OnTick()
{
   UpdateDay();
   datetime m1t = iTime(_Symbol, PERIOD_M1, 0);
   bool newM1 = (m1t != 0 && m1t != g_lastM1);
   if(newM1) g_lastM1 = m1t;
   ManagePosition(newM1);

   datetime t = iTime(_Symbol, PERIOD_H1, 0);
   if(t == 0 || t == g_lastH1) return;
   g_lastH1 = t;
   ulong ticket;
   if(FindPosition(ticket)) return;   // one position at a time, as in research
   EvaluateSignal();
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &req, const MqlTradeResult &res)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || !HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagic) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;

   long posId = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   GlobalVariableDel(TrailKey((ulong)posId));
   double p = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
            + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   long reason = HistoryDealGetInteger(trans.deal, DEAL_REASON);
   string rs = reason == DEAL_REASON_SL ? "SL/TRAIL" : "CLOSE";
   double r = g_lastRisk > 0 ? p / g_lastRisk : 0;
   if(p < 0) g_consecLosses++; else g_consecLosses = 0;
   if(g_consecLosses >= InpMaxConsecLosses)
   {
      g_pausedUntil = TimeCurrent() + InpPauseHours * 3600;
      g_consecLosses = 0;
      PrintFormat("[PAUSE] %d consecutive losses - paused until %s", InpMaxConsecLosses, TimeToString(g_pausedUntil));
   }
   PrintFormat("[CLOSE] %s profit=%.2f R=%.2f", rs, p, r);
   LogLine(StringFormat("%s,CLOSE,%I64d,%d,%s,%.2f,,,%.2f,,,,,%.2f,%.2f,%.2f,%s",
                        TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), posId, g_lastDir,
                        TimeToString(g_lastSig, TIME_DATE | TIME_MINUTES),
                        HistoryDealGetDouble(trans.deal, DEAL_PRICE), HistoryDealGetDouble(trans.deal, DEAL_VOLUME),
                        g_lastRisk, p, r, rs));
}
//+------------------------------------------------------------------+
