//+------------------------------------------------------------------+
//|                                            DTC_v135_EA.mq5       |
//|  Auto-trading port of the "DTC - v1.35" Pine Script indicator    |
//|  (6-EMA trend-alignment system). Entry/exit logic mirrors the    |
//|  indicator's bullish_trend/bearish_trend edge detection exactly; |
//|  SL/TP1-4 use the same percent-of-entry formulas. Partial closes |
//|  at TP1/TP2/TP3 (25% of original volume each) and a runner to    |
//|  TP4 are added since the source script only draws levels and     |
//|  does not manage a position itself. See README.md for details.   |
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
input double InpTP3Multiplier   = 3.0;
input double InpTP4Multiplier   = 4.0;
input double InpRiskPercent     = 0.75;  // account risk % spent on SL distance per trade

input group "=== Position Management ==="
input bool   InpReverseOnOpposite = true; // close current position and flip when the opposite signal fires
input bool   InpBreakevenAfterTP1 = true;
input ulong  InpMagicNumber       = 20260921;

input group "=== Telegram Alert (optional, direct Bot API call) ==="
input bool   InpTelegramEnabled  = false;
input string InpTelegramBotToken = ""; // from @BotFather
input string InpTelegramChatId   = "";

//====================================================================
// Globals
//====================================================================
int handleEma1, handleEma2, handleEma3, handleEma4, handleEma5, handleEma6;
datetime g_lastBarTime = 0;

double g_entry = 0, g_sl = 0, g_tp1 = 0, g_tp2 = 0, g_tp3 = 0, g_tp4 = 0;
double g_origVolume = 0;
bool   g_tp1Taken = false, g_tp2Taken = false, g_tp3Taken = false;
int    g_signalState = 0; // 1 = long, -1 = short, 0 = flat

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

bool HasOpenPosition(int &dir) // dir: 1 buy, -1 sell, 0 none
{
   dir = 0;
   if(!PositionSelect(_Symbol)) return false;
   if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) return false;
   dir = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) ? 1 : -1;
   return true;
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

void SendTelegramAlert(string signalType, double entry, double sl, double t1, double t2, double t3, double t4)
{
   if(!InpTelegramEnabled || InpTelegramBotToken=="" || InpTelegramChatId=="") return;

   string msg = signalType + " Signal - " + _Symbol + " (" + EnumToString((ENUM_TIMEFRAMES)Period()) + ")" +
      "\nEntry: " + DoubleToString(entry, _Digits) +
      "\nSL: " + DoubleToString(sl, _Digits) +
      "\nTP1: " + DoubleToString(t1, _Digits) +
      "\nTP2: " + DoubleToString(t2, _Digits) +
      "\nTP3: " + DoubleToString(t3, _Digits) +
      "\nTP4: " + DoubleToString(t4, _Digits);

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
// Entry / exit management
//====================================================================
void CloseCurrentPosition()
{
   if(PositionSelect(_Symbol) && (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber)
      trade.PositionClose(_Symbol);
   g_signalState = 0;
   g_tp1Taken = false; g_tp2Taken = false; g_tp3Taken = false;
}

void OpenPosition(bool bullish)
{
   double entry = bullish ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl  = bullish ? entry*(1 - InpStopLossPercent/100.0) : entry*(1 + InpStopLossPercent/100.0);
   double tp1 = bullish ? entry*(1 + InpStopLossPercent*InpTP1Multiplier/100.0) : entry*(1 - InpStopLossPercent*InpTP1Multiplier/100.0);
   double tp2 = bullish ? entry*(1 + InpStopLossPercent*InpTP2Multiplier/100.0) : entry*(1 - InpStopLossPercent*InpTP2Multiplier/100.0);
   double tp3 = bullish ? entry*(1 + InpStopLossPercent*InpTP3Multiplier/100.0) : entry*(1 - InpStopLossPercent*InpTP3Multiplier/100.0);
   double tp4 = bullish ? entry*(1 + InpStopLossPercent*InpTP4Multiplier/100.0) : entry*(1 - InpStopLossPercent*InpTP4Multiplier/100.0);

   double slDistance = MathAbs(entry - sl);
   double lots = CalculateLotSize(slDistance);
   if(lots<=0)
   {
      Print("[DTC-EA] Lot size computed as 0, skipping entry");
      return;
   }

   bool ok = bullish ? trade.Buy(lots, _Symbol, entry, sl, tp4, "DTC-v1.35")
                      : trade.Sell(lots, _Symbol, entry, sl, tp4, "DTC-v1.35");
   if(!ok)
   {
      PrintFormat("[DTC-EA] Order failed, retcode=%d", trade.ResultRetcode());
      return;
   }

   g_entry=entry; g_sl=sl; g_tp1=tp1; g_tp2=tp2; g_tp3=tp3; g_tp4=tp4;
   g_origVolume = lots;
   g_tp1Taken=false; g_tp2Taken=false; g_tp3Taken=false;
   g_signalState = bullish ? 1 : -1;

   PrintFormat("[DTC-EA] %s entry=%.5f sl=%.5f tp1=%.5f tp2=%.5f tp3=%.5f tp4=%.5f lots=%.2f",
      bullish?"BUY":"SELL", entry, sl, tp1, tp2, tp3, tp4, lots);

   SendTelegramAlert(bullish?"BUY":"SELL", entry, sl, tp1, tp2, tp3, tp4);
}

void ClosePartial(double fraction)
{
   if(!PositionSelect(_Symbol)) return;
   ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
   double vol = PositionGetDouble(POSITION_VOLUME);

   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(lotStep<=0) lotStep=0.01;

   double closeVol = MathFloor((g_origVolume*fraction)/lotStep)*lotStep;
   if(closeVol < minLot || closeVol >= vol) return;
   trade.PositionClosePartial(ticket, closeVol);
}

void ManageOpenPosition()
{
   int dir;
   if(!HasOpenPosition(dir)) { g_signalState=0; return; }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double curPrice = (dir==1) ? bid : ask; // exit-side price

   bool hitTp1 = (dir==1) ? (curPrice>=g_tp1) : (curPrice<=g_tp1);
   bool hitTp2 = (dir==1) ? (curPrice>=g_tp2) : (curPrice<=g_tp2);
   bool hitTp3 = (dir==1) ? (curPrice>=g_tp3) : (curPrice<=g_tp3);

   if(!g_tp1Taken && hitTp1)
   {
      ClosePartial(0.25);
      g_tp1Taken = true;
      if(InpBreakevenAfterTP1 && PositionSelect(_Symbol))
      {
         ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
         double tp = PositionGetDouble(POSITION_TP);
         trade.PositionModify(ticket, g_entry, tp);
      }
   }
   if(g_tp1Taken && !g_tp2Taken && hitTp2)
   {
      ClosePartial(0.25);
      g_tp2Taken = true;
   }
   if(g_tp2Taken && !g_tp3Taken && hitTp3)
   {
      ClosePartial(0.25);
      g_tp3Taken = true;
      // remaining ~25% rides to TP4, already set as the position's take-profit
   }
}

//====================================================================
// Main tick handler
//====================================================================
void OnTick()
{
   ManageOpenPosition();

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
   if(!longSignal && !shortSignal) return;

   int dir;
   bool hasPos = HasOpenPosition(dir);

   if(longSignal)
   {
      if(hasPos && dir==-1)
      {
         if(!InpReverseOnOpposite) return;
         CloseCurrentPosition();
      }
      else if(hasPos && dir==1) return; // already long
      OpenPosition(true);
   }
   else if(shortSignal)
   {
      if(hasPos && dir==1)
      {
         if(!InpReverseOnOpposite) return;
         CloseCurrentPosition();
      }
      else if(hasPos && dir==-1) return; // already short
      OpenPosition(false);
   }
}
