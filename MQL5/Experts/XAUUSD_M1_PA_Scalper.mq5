//+------------------------------------------------------------------+
//|                                       XAUUSD_M1_PA_Scalper.mq5   |
//|  Price-action scalper: multi-timeframe EMA trend filter +        |
//|  candlestick reversal pattern entries at EMA pullback, fixed     |
//|  percent risk sizing. Designed for small ($1000-class) accounts. |
//+------------------------------------------------------------------+
#property copyright "Custom EA"
#property version   "1.00"

#include <Trade\Trade.mqh>

CTrade trade;

//=== Risk Management ===
input double InpRiskPercent         = 1.0;    // Risk % of balance per trade
input double InpMaxDailyLossPercent = 3.0;    // Stop trading for the day after this % loss
input int    InpMaxConsecLosses     = 3;      // Pause after this many losses in a row
input int    InpPauseMinutes        = 60;     // Pause duration (minutes)
input double InpRiskRewardRatio     = 1.5;    // TP distance = SL distance * ratio
input double InpMaxSpreadPoints     = 350;    // Reject entries if spread exceeds this (points)

//=== Strategy ===
input int    InpFastEMA             = 20;     // Fast EMA period (M1, pullback reference)
input int    InpSlowEMA             = 50;     // Slow EMA period (M1, not used for filtering, for chart context)
input ENUM_TIMEFRAMES InpTrendTF    = PERIOD_M15; // Higher timeframe for trend bias
input int    InpTrendEMA            = 200;    // Trend EMA period (higher timeframe)
input int    InpATRPeriod           = 14;     // ATR period (M1)
input double InpATR_SL_Multiplier   = 1.5;    // SL distance = ATR * multiplier (min bound)
input double InpPinBarRatio         = 2.0;    // Min wick/body ratio to count as pin bar
input double InpPullbackATRMult     = 1.0;    // Max distance from EMA (in ATR) to count as "pullback"

//=== Session Filter (server/broker time) ===
input bool   InpUseSessionFilter    = true;
input int    InpSessionStartHour    = 13;     // e.g. London/NY overlap start (broker time)
input int    InpSessionEndHour      = 21;     // e.g. London/NY overlap end (broker time)

//=== Trade Management ===
input int    InpMagicNumber         = 20240915;
input int    InpSlippage            = 20;     // Slippage in points
input bool   InpUseTrailing         = true;
input double InpTrailingStartR      = 1.0;    // Start trailing after this multiple of initial risk
input double InpTrailingStepATR     = 0.5;    // Trail distance behind price, in ATR multiples

//--- Indicator handles
int emaFastHandle, emaSlowHandle, atrHandle, trendEmaHandle;

//--- State
datetime lastBarTime        = 0;
double   dayStartBalance    = 0;
datetime currentDay         = 0;
int      consecLosses       = 0;
datetime pausedUntil        = 0;
double   g_initialRiskDist  = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   emaFastHandle  = iMA(_Symbol, PERIOD_M1, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle  = iMA(_Symbol, PERIOD_M1, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle      = iATR(_Symbol, PERIOD_M1, InpATRPeriod);
   trendEmaHandle = iMA(_Symbol, InpTrendTF, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);

   if(emaFastHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE ||
      atrHandle == INVALID_HANDLE || trendEmaHandle == INVALID_HANDLE)
   {
      Print("Failed to create one or more indicator handles");
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);

   dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   currentDay = TimeCurrent() - (TimeCurrent() % 86400);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(emaFastHandle);
   IndicatorRelease(emaSlowHandle);
   IndicatorRelease(atrHandle);
   IndicatorRelease(trendEmaHandle);
}

//+------------------------------------------------------------------+
//| Candlestick pattern helpers (M1)                                 |
//+------------------------------------------------------------------+
bool IsBullishPinBar(int shift)
{
   double o = iOpen(_Symbol, PERIOD_M1, shift);
   double c = iClose(_Symbol, PERIOD_M1, shift);
   double h = iHigh(_Symbol, PERIOD_M1, shift);
   double l = iLow(_Symbol, PERIOD_M1, shift);
   double body = MathAbs(c - o);
   if(body <= 0) return false;
   double lowerWick = MathMin(o, c) - l;
   double upperWick = h - MathMax(o, c);
   return (lowerWick >= body * InpPinBarRatio && upperWick <= body * 0.5);
}

bool IsBearishPinBar(int shift)
{
   double o = iOpen(_Symbol, PERIOD_M1, shift);
   double c = iClose(_Symbol, PERIOD_M1, shift);
   double h = iHigh(_Symbol, PERIOD_M1, shift);
   double l = iLow(_Symbol, PERIOD_M1, shift);
   double body = MathAbs(c - o);
   if(body <= 0) return false;
   double upperWick = h - MathMax(o, c);
   double lowerWick = MathMin(o, c) - l;
   return (upperWick >= body * InpPinBarRatio && lowerWick <= body * 0.5);
}

bool IsBullishEngulfing(int shift)
{
   double o1 = iOpen(_Symbol, PERIOD_M1, shift + 1), c1 = iClose(_Symbol, PERIOD_M1, shift + 1);
   double o0 = iOpen(_Symbol, PERIOD_M1, shift),     c0 = iClose(_Symbol, PERIOD_M1, shift);
   bool prevBearish = c1 < o1;
   bool currBullish = c0 > o0;
   return (prevBearish && currBullish && c0 >= o1 && o0 <= c1);
}

bool IsBearishEngulfing(int shift)
{
   double o1 = iOpen(_Symbol, PERIOD_M1, shift + 1), c1 = iClose(_Symbol, PERIOD_M1, shift + 1);
   double o0 = iOpen(_Symbol, PERIOD_M1, shift),     c0 = iClose(_Symbol, PERIOD_M1, shift);
   bool prevBullish = c1 > o1;
   bool currBearish = c0 < o0;
   return (prevBullish && currBearish && c0 <= o1 && o0 >= c1);
}

//+------------------------------------------------------------------+
int GetTrendBias()
{
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(trendEmaHandle, 0, 0, 1, buf) < 1) return 0;
   double price = iClose(_Symbol, InpTrendTF, 0);
   if(price > buf[0]) return 1;
   if(price < buf[0]) return -1;
   return 0;
}

bool IsWithinSession(int hour)
{
   if(InpSessionStartHour == InpSessionEndHour) return true;
   if(InpSessionStartHour < InpSessionEndHour)
      return (hour >= InpSessionStartHour && hour < InpSessionEndHour);
   return (hour >= InpSessionStartHour || hour < InpSessionEndHour);
}

//+------------------------------------------------------------------+
int PositionsTotalByMagic()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
double CalculateLotSize(double slDistancePrice)
{
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * InpRiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0 || tickValue <= 0 || slDistancePrice <= 0) return 0;

   double lossPerLot = (slDistancePrice / tickSize) * tickValue;
   if(lossPerLot <= 0) return 0;

   double lots = riskMoney / lossPerLot;

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0) lotStep = 0.01;

   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));
   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
void TryOpenLong(double atrValue)
{
   if(PositionsTotalByMagic() > 0) return;

   double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double patternLow = iLow(_Symbol, PERIOD_M1, 1);
   double stopLevel  = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

   double slDistance = MathMax(atrValue * InpATR_SL_Multiplier, (ask - patternLow) + 2 * point);
   if(slDistance < stopLevel) slDistance = stopLevel + 2 * point;

   double sl = ask - slDistance;
   double tp = ask + slDistance * InpRiskRewardRatio;
   double lots = CalculateLotSize(slDistance);
   if(lots <= 0) return;

   if(trade.Buy(lots, _Symbol, ask, sl, tp, "PA-Scalp-Long"))
      g_initialRiskDist = slDistance;
}

void TryOpenShort(double atrValue)
{
   if(PositionsTotalByMagic() > 0) return;

   double point       = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid         = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double patternHigh = iHigh(_Symbol, PERIOD_M1, 1);
   double stopLevel   = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;

   double slDistance = MathMax(atrValue * InpATR_SL_Multiplier, (patternHigh - bid) + 2 * point);
   if(slDistance < stopLevel) slDistance = stopLevel + 2 * point;

   double sl = bid + slDistance;
   double tp = bid - slDistance * InpRiskRewardRatio;
   double lots = CalculateLotSize(slDistance);
   if(lots <= 0) return;

   if(trade.Sell(lots, _Symbol, bid, sl, tp, "PA-Scalp-Short"))
      g_initialRiskDist = slDistance;
}

//+------------------------------------------------------------------+
void ManageTrailing(double atrValue)
{
   if(!InpUseTrailing || g_initialRiskDist <= 0) return;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long   type      = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL     = PositionGetDouble(POSITION_SL);
      double curTP     = PositionGetDouble(POSITION_TP);
      double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(type == POSITION_TYPE_BUY)
      {
         double profitDist = bid - openPrice;
         if(profitDist >= g_initialRiskDist * InpTrailingStartR)
         {
            double newSL = bid - atrValue * InpTrailingStepATR;
            if(newSL > curSL)
               trade.PositionModify(ticket, newSL, curTP);
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double profitDist = openPrice - ask;
         if(profitDist >= g_initialRiskDist * InpTrailingStartR)
         {
            double newSL = ask + atrValue * InpTrailingStepATR;
            if(newSL < curSL || curSL == 0)
               trade.PositionModify(ticket, newSL, curTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
void OnTick()
{
   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   if(CopyBuffer(atrHandle, 0, 0, 2, atrBuf) < 2) return;
   double atrValue = atrBuf[1];

   ManageTrailing(atrValue);

   // Daily loss-limit reset/check
   datetime today = TimeCurrent() - (TimeCurrent() % 86400);
   if(today != currentDay)
   {
      currentDay = today;
      dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }

   if(TimeCurrent() < pausedUntil) return;

   double maxLossMoney = dayStartBalance * InpMaxDailyLossPercent / 100.0;
   if(AccountInfoDouble(ACCOUNT_EQUITY) <= dayStartBalance - maxLossMoney) return;

   if(InpUseSessionFilter)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(!IsWithinSession(dt.hour)) return;
   }

   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / point;
   if(spread > InpMaxSpreadPoints) return;

   // Only evaluate signals once per closed M1 bar
   datetime barTime = iTime(_Symbol, PERIOD_M1, 0);
   if(barTime == lastBarTime) return;
   lastBarTime = barTime;

   if(PositionsTotalByMagic() > 0) return;

   int bias = GetTrendBias();
   if(bias == 0) return;

   double emaFastBuf[];
   ArraySetAsSeries(emaFastBuf, true);
   if(CopyBuffer(emaFastHandle, 0, 1, 1, emaFastBuf) < 1) return;
   double emaFast = emaFastBuf[0];

   double low1   = iLow(_Symbol, PERIOD_M1, 1);
   double high1  = iHigh(_Symbol, PERIOD_M1, 1);
   double close1 = iClose(_Symbol, PERIOD_M1, 1);
   double pullbackBand = atrValue * InpPullbackATRMult;

   if(bias == 1)
   {
      bool pattern = IsBullishPinBar(1) || IsBullishEngulfing(1);
      if(pattern && MathAbs(low1 - emaFast) <= pullbackBand && close1 > emaFast)
         TryOpenLong(atrValue);
   }
   else if(bias == -1)
   {
      bool pattern = IsBearishPinBar(1) || IsBearishEngulfing(1);
      if(pattern && MathAbs(high1 - emaFast) <= pullbackBand && close1 < emaFast)
         TryOpenShort(atrValue);
   }
}

//+------------------------------------------------------------------+
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

   if(profit < 0) consecLosses++;
   else consecLosses = 0;

   if(consecLosses >= InpMaxConsecLosses)
   {
      pausedUntil = TimeCurrent() + InpPauseMinutes * 60;
      consecLosses = 0;
      Print("Max consecutive losses reached. Pausing until ", TimeToString(pausedUntil));
   }

   g_initialRiskDist = 0;
}
//+------------------------------------------------------------------+
