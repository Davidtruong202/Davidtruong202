//+------------------------------------------------------------------+
//|                                            DTC_v135_EA.mq5       |
//|  Auto-trading port of the "DTC - v1.35" Pine Script indicator    |
//|  (6-EMA trend-alignment system). Entry/exit logic mirrors the    |
//|  indicator's bullish_trend/bearish_trend edge detection exactly; |
//|  SL/TP1/TP2 use the same percent-of-entry formulas. Each signal  |
//|  opens TWO market orders of equal volume (one targeting TP1, one |
//|  targeting TP2, same SL) instead of one position with manual     |
//|  partial closes - the broker closes each leg on its own TP, and  |
//|  the EA moves the TP2 leg's SL to breakeven the moment price     |
//|  reaches TP1. Opposite signals always close the open group and   |
//|  reverse. See README.md for details.                             |
//+------------------------------------------------------------------+
#property copyright "Custom EA"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// Inputs
//====================================================================
input group "=== EMA Settings (matches indicator lengths) ==="
input int    InpLen1 = 30;
input int    InpLen2 = 35;
input int    InpLen3 = 40;
input int    InpLen4 = 45;
input int    InpLen5 = 50;
input int    InpLen6 = 60;

input group "=== Risk Management ==="
input double InpStopLossPercent = 0.25;  // Stop Loss % of entry price
input double InpTP1Multiplier   = 1.0;
input double InpTP2Multiplier   = 2.0;
input double InpRiskPercent     = 0.75;  // account risk % spent on SL distance per trade, split across TP1+TP2

input group "=== Position Management ==="
input bool   InpBreakevenAfterTP1 = true; // move the TP2 leg's SL to entry once price reaches TP1
input ulong  InpMagicNumber       = 20260921;

input group "=== Execution (entry buffer) ==="
input int    InpSlippagePoints   = 20; // max price deviation tolerated when filling market orders
input int    InpMaxSpreadPoints  = 0;  // skip entry if current spread exceeds this many points (0 = no limit)

input group "=== Telegram Alert (optional, direct Bot API call) ==="
input bool   InpTelegramEnabled  = false;
input string InpTelegramBotToken = ""; // from @BotFather
input string InpTelegramChatId   = "";

//====================================================================
// Globals
//====================================================================
int handleEma1, handleEma2, handleEma3, handleEma4, handleEma5, handleEma6;
datetime g_lastBarTime = 0;

// The currently open pair of orders (TP1 leg + TP2 leg), or 0 when flat.
ulong  g_ticket1 = 0, g_ticket2 = 0;
double g_entry = 0, g_sl = 0, g_tp1 = 0, g_tp2 = 0;
bool   g_bullish = false;
bool   g_beApplied = false;

//====================================================================
// Init / Deinit
//====================================================================
int OnInit()
{
   handleEma1 = iMA(_Symbol, PERIOD_CURRENT, InpLen1, 0, MODE_EMA, PRICE_CLOSE);
   handleEma2 = iMA(_Symbol, PERIOD_CURRENT, InpLen2, 0, MODE_EMA, PRICE_CLOSE);
   handleEma3 = iMA(_Symbol, PERIOD_CURRENT, InpLen3, 0, MODE_EMA, PRICE_CLOSE);
   handleEma4 = iMA(_Symbol, PERIOD_CURRENT, InpLen4, 0, MODE_EMA, PRICE_CLOSE);
   handleEma5 = iMA(_Symbol, PERIOD_CURRENT, InpLen5, 0, MODE_EMA, PRICE_CLOSE);
   handleEma6 = iMA(_Symbol, PERIOD_CURRENT, InpLen6, 0, MODE_EMA, PRICE_CLOSE);

   if(handleEma1==INVALID_HANDLE || handleEma2==INVALID_HANDLE || handleEma3==INVALID_HANDLE ||
      handleEma4==INVALID_HANDLE || handleEma5==INVALID_HANDLE || handleEma6==INVALID_HANDLE)
   {
      Print("[DTC-EA] Failed to create EMA handles");
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(handleEma1); IndicatorRelease(handleEma2); IndicatorRelease(handleEma3);
   IndicatorRelease(handleEma4); IndicatorRelease(handleEma5); IndicatorRelease(handleEma6);
}

//====================================================================
// Helpers
//====================================================================
bool GetEmaShift(int handle, int shift, double &value)
{
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(handle, 0, shift, 1, buf) != 1) return false;
   value = buf[0];
   return true;
}

// Returns true if EMA1>EMA2>...>EMA6 (bullish) at the given shift, or the mirror for bearish.
bool TrendAligned(int shift, bool bullish)
{
   double e1,e2,e3,e4,e5,e6;
   if(!GetEmaShift(handleEma1, shift, e1) || !GetEmaShift(handleEma2, shift, e2) ||
      !GetEmaShift(handleEma3, shift, e3) || !GetEmaShift(handleEma4, shift, e4) ||
      !GetEmaShift(handleEma5, shift, e5) || !GetEmaShift(handleEma6, shift, e6))
      return false;

   if(bullish) return (e1>e2 && e2>e3 && e3>e4 && e4>e5 && e5>e6);
   return (e1<e2 && e2<e3 && e3<e4 && e4<e5 && e5<e6);
}

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

// Splits the total risk-sized volume into two equal legs (one per TP), respecting the
// broker's lot step/minimum. Returns lot1=lot2=0 if the account is too small to split.
void SplitVolume(double totalLots, double &lot1, double &lot2)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep<=0) lotStep=0.01;

   double half = MathFloor((totalLots/2.0)/lotStep)*lotStep;
   if(half < minLot) { lot1=0; lot2=0; return; }

   lot1 = half;
   lot2 = NormalizeDouble(totalLots - half, 2);
   if(lot2 < minLot) lot2 = half; // rounding left too little for leg 2: fall back to an equal split
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
   string headers = "Content-Type: application/json\r\n";
   StringToCharArray(json, post, 0, StringLen(json));
   string resultHeaders;
   int res = WebRequest("POST", url, headers, 5000, post, result, resultHeaders);
   if(res==-1)
      PrintFormat("[DTC-EA] Telegram WebRequest failed, error=%d. Add %s to Tools>Options>Expert Advisors>Allow WebRequest.", GetLastError(), url);
}

//====================================================================
// Position group management (TP1 leg + TP2 leg)
//====================================================================
bool GroupHasAnyOpen()
{
   return (g_ticket1!=0 && PositionSelectByTicket(g_ticket1)) || (g_ticket2!=0 && PositionSelectByTicket(g_ticket2));
}

bool GroupOpen(int &dir) // dir: 1 buy, -1 sell, 0 none
{
   dir = 0;
   if(g_ticket1==0 && g_ticket2==0) return false;
   if(!GroupHasAnyOpen()) return false;
   dir = g_bullish ? 1 : -1;
   return true;
}

void CloseGroup()
{
   if(g_ticket1!=0 && PositionSelectByTicket(g_ticket1)) trade.PositionClose(g_ticket1);
   if(g_ticket2!=0 && PositionSelectByTicket(g_ticket2)) trade.PositionClose(g_ticket2);
   g_ticket1=0; g_ticket2=0; g_beApplied=false;
}

bool OpenPositionGroup(bool bullish)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spreadPoints = (ask-bid) / _Point;
   if(InpMaxSpreadPoints>0 && spreadPoints>InpMaxSpreadPoints)
   {
      PrintFormat("[DTC-EA] Spread too wide (%.1f pts > %d), skipping entry", spreadPoints, InpMaxSpreadPoints);
      return false;
   }

   double entry = bullish ? ask : bid;
   double sl  = bullish ? entry*(1 - InpStopLossPercent/100.0) : entry*(1 + InpStopLossPercent/100.0);
   double tp1 = bullish ? entry*(1 + InpStopLossPercent*InpTP1Multiplier/100.0) : entry*(1 - InpStopLossPercent*InpTP1Multiplier/100.0);
   double tp2 = bullish ? entry*(1 + InpStopLossPercent*InpTP2Multiplier/100.0) : entry*(1 - InpStopLossPercent*InpTP2Multiplier/100.0);

   double slDistance = MathAbs(entry - sl);
   double totalLots = CalculateLotSize(slDistance);
   if(totalLots<=0)
   {
      Print("[DTC-EA] Lot size computed as 0, skipping entry");
      return false;
   }

   double lot1, lot2;
   SplitVolume(totalLots, lot1, lot2);
   if(lot1<=0 || lot2<=0)
   {
      Print("[DTC-EA] Account/volume too small to split across TP1+TP2, skipping entry");
      return false;
   }

   ulong t1=0, t2=0;
   bool ok1 = bullish ? trade.Buy(lot1, _Symbol, entry, sl, tp1, "DTC-TP1")
                       : trade.Sell(lot1, _Symbol, entry, sl, tp1, "DTC-TP1");
   if(ok1) t1 = trade.ResultOrder();

   bool ok2 = bullish ? trade.Buy(lot2, _Symbol, entry, sl, tp2, "DTC-TP2")
                       : trade.Sell(lot2, _Symbol, entry, sl, tp2, "DTC-TP2");
   if(ok2) t2 = trade.ResultOrder();

   if(!ok1 && !ok2)
   {
      PrintFormat("[DTC-EA] Both entry orders failed, retcode=%d", trade.ResultRetcode());
      return false;
   }

   g_ticket1=t1; g_ticket2=t2; g_entry=entry; g_sl=sl; g_tp1=tp1; g_tp2=tp2;
   g_bullish=bullish; g_beApplied=false;

   PrintFormat("[DTC-EA] %s entry=%.5f sl=%.5f tp1=%.5f tp2=%.5f lot1=%.2f lot2=%.2f",
      bullish?"BUY":"SELL", entry, sl, tp1, tp2, lot1, lot2);
   SendTelegramAlert(bullish?"BUY":"SELL", entry, sl, tp1, tp2);
   return true;
}

// Moves the TP2 leg's SL to breakeven (entry) the instant price reaches TP1 - regardless
// of whether the TP1 leg's own broker-side take-profit has filled yet on this same tick.
void ManageGroup()
{
   if(g_ticket1==0 && g_ticket2==0) return;
   if(!GroupHasAnyOpen()) { g_ticket1=0; g_ticket2=0; g_beApplied=false; return; }
   if(!InpBreakevenAfterTP1 || g_beApplied) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double curPrice = g_bullish ? bid : ask; // exit-side price
   bool hitTp1 = g_bullish ? (curPrice>=g_tp1) : (curPrice<=g_tp1);
   if(!hitTp1) return;

   if(g_ticket2!=0 && PositionSelectByTicket(g_ticket2))
   {
      double tp = PositionGetDouble(POSITION_TP);
      trade.PositionModify(g_ticket2, g_entry, tp);
   }
   g_beApplied = true;
}

//====================================================================
// Main tick handler
//====================================================================
void OnTick()
{
   ManageGroup();

   datetime curBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(curBarTime == g_lastBarTime) return; // only evaluate signals once per closed bar
   g_lastBarTime = curBarTime;
   if(Bars(_Symbol, PERIOD_CURRENT) < InpLen6+2) return;

   // shift 1 = last closed bar, shift 2 = the one before it (mirrors Pine's [1] on a confirmed bar)
   bool bullNow  = TrendAligned(1, true);
   bool bullPrev = TrendAligned(2, true);
   bool bearNow  = TrendAligned(1, false);
   bool bearPrev = TrendAligned(2, false);

   bool longSignal  = bullNow && !bullPrev;
   bool shortSignal = bearNow && !bearPrev;
   if(!longSignal && !shortSignal) return; // evaluated and acted on the same tick the bar closes - no artificial delay

   int dir;
   bool hasPos = GroupOpen(dir);

   if(longSignal)
   {
      if(hasPos && dir==1) return; // already long
      if(hasPos && dir==-1) CloseGroup(); // always reverse on an opposite signal
      OpenPositionGroup(true);
   }
   else if(shortSignal)
   {
      if(hasPos && dir==-1) return; // already short
      if(hasPos && dir==1) CloseGroup();
      OpenPositionGroup(false);
   }
}
