//+------------------------------------------------------------------+
//|                                 XAUUSD_MeanReversion_M5.mq5      |
//|  Counter-trend / mean-reversion EA for XAUUSD, base timeframe    |
//|  M5. Entry = Stochastic(100,3,3) extreme + MACD(12,26,9) cross,  |
//|  gated by ADX(14) (blocks when > threshold, since this is a      |
//|  reversal strategy, not trend-following), an optional M15/M30    |
//|  EMA big-trend filter, an ATR(14) volatility band, a trading     |
//|  hour block, and the built-in MQL5 Economic Calendar (blocks on  |
//|  High-impact news). Once the M5 trigger fires it arms a pending  |
//|  signal that must be confirmed by a Pin Bar or Engulfing pattern |
//|  on M1 within a configurable window, otherwise it is cancelled.  |
//|  Trade management: fixed SL/TP (price units), break-even after   |
//|  a price-unit profit trigger, and an early-close when MACD on a  |
//|  higher timeframe (default M15) crosses against the open side.   |
//|  See README.md for design notes.                                 |
//+------------------------------------------------------------------+
#property copyright "Custom EA"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// Inputs
//====================================================================
input group "=== Stochastic (M5) ==="
input int    InpStoch_K          = 100;    // %K period
input int    InpStoch_D          = 3;      // %D period
input int    InpStoch_Slowing    = 3;      // Slowing
input double InpStoch_SellLevel  = 85.0;   // Stoch >= level => overbought (Sell side)
input double InpStoch_BuyLevel   = 15.0;   // Stoch <= level => oversold (Buy side)

input group "=== MACD (M5) ==="
input int    InpMACD_Fast   = 12;
input int    InpMACD_Slow   = 26;
input int    InpMACD_Signal = 9;

input group "=== ADX (M5) ==="
input int    InpADX_Period       = 14;
input double InpADX_MaxThreshold = 30.0;   // ADX > threshold => BLOCK (trend too strong for a reversal trade)

input group "=== EMA big-trend filter ==="
input bool             InpUseEMAFilter  = true;
input int              InpEMA_Period    = 50;
input ENUM_TIMEFRAMES  InpEMA_Timeframe = PERIOD_M15;  // M15 or M30

input group "=== ATR volatility band (M5) ==="
input int    InpATR_Period    = 14;
input double InpATR_MinPoints = 1.5;   // in price units (e.g. $1.50 for Gold)
input double InpATR_MaxPoints = 15.0;  // in price units (e.g. $15.00 for Gold)

input group "=== M1 pattern confirmation ==="
input int  InpM1_ConfirmMaxMinutes = 15;    // cancel the pending signal if no M1 pattern within this window
input bool InpUsePinBar             = true;
input bool InpUseEngulfing          = true;

input group "=== Trade management ==="
input double InpSL_Price          = 5.0;   // stop loss, price units ($5 = 50 "pip" per spec)
input double InpTP_Price          = 10.0;  // take profit, price units ($10 = 100 "pip" per spec)
input double InpSLBE_TriggerPrice = 5.0;   // move SL to break-even once profit reaches this many price units
input double InpLotSize            = 0.01;
input ulong  InpMagicNumber        = 20260916;

input group "=== Early close on trend reversal ==="
input bool             InpUseEarlyClose       = true;
input ENUM_TIMEFRAMES  InpEarlyClose_Timeframe = PERIOD_M15;

input group "=== Trading hour filter (server time) ==="
input int InpBlockStartHour   = 0;   // block from this hour (inclusive)
input int InpBlockEndHour     = 2;   // block until this hour (exclusive)
input int InpServer_GMT_Offset = 3;  // informational only (shown on dashboard); logic uses server time directly

input group "=== News filter (built-in Economic Calendar) ==="
input bool InpUseNewsFilter     = true;
input int  InpNewsMinutesBefore = 30;  // block this many minutes before a High-impact event
input int  InpNewsMinutesAfter  = 30;  // block this many minutes after a High-impact event

//====================================================================
// Globals
//====================================================================
int stochHandle           = INVALID_HANDLE;
int macdHandle            = INVALID_HANDLE;
int adxHandle             = INVALID_HANDLE;
int emaHandle             = INVALID_HANDLE;
int atrHandle             = INVALID_HANDLE;
int earlyCloseMacdHandle  = INVALID_HANDLE;

datetime lastBarTimeM5         = 0;
datetime lastBarTimeM1         = 0;
datetime lastBarTimeEarlyClose = 0;

struct PendingSignal
{
   bool     active;
   int      direction;   // 1 = BUY, -1 = SELL
   datetime armedTime;
   datetime deadline;
};
PendingSignal pending;

#define DASH_PREFIX "MR_Dash_"

//====================================================================
// Small helpers
//====================================================================
string DirStr(int d) { return d==1 ? "BUY" : (d==-1 ? "SELL" : "NONE"); }

bool GetBufferSeries(int handle, int bufferIndex, int count, double &arr[])
{
   if(handle == INVALID_HANDLE) return false;
   ArraySetAsSeries(arr, true);
   int copied = CopyBuffer(handle, bufferIndex, 0, count, arr);
   return copied >= count;
}

bool IsNewBar(ENUM_TIMEFRAMES tf, datetime &lastTime)
{
   datetime t = iTime(_Symbol, tf, 0);
   if(t == 0) return false;
   if(t != lastTime)
   {
      lastTime = t;
      return true;
   }
   return false;
}

bool PositionExists()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) continue;
      return true;
   }
   return false;
}

bool IsTradingHourBlocked()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;
   if(InpBlockStartHour == InpBlockEndHour) return false;
   if(InpBlockStartHour < InpBlockEndHour)
      return (h >= InpBlockStartHour && h < InpBlockEndHour);
   // wrap-around midnight (defensive, spec default 0..2 does not need this branch)
   return (h >= InpBlockStartHour || h < InpBlockEndHour);
}

bool IsNewsBlocked()
{
   datetime from = TimeCurrent() - InpNewsMinutesAfter * 60;
   datetime to   = TimeCurrent() + InpNewsMinutesBefore * 60;
   MqlCalendarValue values[];
   int n = CalendarValueHistory(values, from, to, NULL, "USD");
   if(n <= 0) return false; // no events, or calendar data unavailable -> fail open
   for(int i = 0; i < n; i++)
   {
      MqlCalendarEvent evt;
      if(!CalendarEventById(values[i].event_id, evt)) continue;
      if(evt.importance == CALENDAR_IMPORTANCE_HIGH) return true;
   }
   return false;
}

//====================================================================
// Gate conditions shared by both the M5 arm-check and the M1 confirm
// (ADX, EMA big-trend filter, ATR band, trading hour, news, no open
// position). Direction: 1 = BUY, -1 = SELL.
//====================================================================
bool CheckGateConditions(int direction, string &reason)
{
   if(PositionExists()) { reason = "Đã có lệnh mở"; return false; }

   double adxMain[];
   if(!GetBufferSeries(adxHandle, 0, 2, adxMain)) { reason = "Thiếu dữ liệu ADX"; return false; }
   if(adxMain[1] > InpADX_MaxThreshold) { reason = "ADX quá cao (trend M5 quá mạnh)"; return false; }

   double atrVal[];
   if(!GetBufferSeries(atrHandle, 0, 2, atrVal)) { reason = "Thiếu dữ liệu ATR"; return false; }
   if(atrVal[1] < InpATR_MinPoints || atrVal[1] > InpATR_MaxPoints) { reason = "ATR ngoài ngưỡng"; return false; }

   if(InpUseEMAFilter)
   {
      double emaVal[];
      if(!GetBufferSeries(emaHandle, 0, 2, emaVal)) { reason = "Thiếu dữ liệu EMA"; return false; }
      double refPrice = iClose(_Symbol, PERIOD_M5, 1);
      if(direction == 1 && refPrice < emaVal[1]) { reason = "EMA filter chặn BUY (ngược trend lớn)"; return false; }
      if(direction == -1 && refPrice > emaVal[1]) { reason = "EMA filter chặn SELL (ngược trend lớn)"; return false; }
   }

   if(IsTradingHourBlocked()) { reason = "Trong khung giờ chặn"; return false; }

   if(InpUseNewsFilter && IsNewsBlocked()) { reason = "Có tin tức High impact"; return false; }

   return true;
}

//====================================================================
// M1 candle pattern detection (Pin Bar / Engulfing)
//====================================================================
bool IsBullishPinBar(int shift)
{
   double o = iOpen(_Symbol, PERIOD_M1, shift);
   double h = iHigh(_Symbol, PERIOD_M1, shift);
   double l = iLow(_Symbol, PERIOD_M1, shift);
   double c = iClose(_Symbol, PERIOD_M1, shift);
   double range = h - l;
   if(range <= 0) return false;
   double body      = MathAbs(c - o);
   double lowerWick = MathMin(o, c) - l;
   double upperWick = h - MathMax(o, c);
   return (lowerWick >= 2.0 * body && lowerWick >= 0.6 * range && upperWick <= 0.25 * range);
}

bool IsBearishPinBar(int shift)
{
   double o = iOpen(_Symbol, PERIOD_M1, shift);
   double h = iHigh(_Symbol, PERIOD_M1, shift);
   double l = iLow(_Symbol, PERIOD_M1, shift);
   double c = iClose(_Symbol, PERIOD_M1, shift);
   double range = h - l;
   if(range <= 0) return false;
   double body      = MathAbs(c - o);
   double lowerWick = MathMin(o, c) - l;
   double upperWick = h - MathMax(o, c);
   return (upperWick >= 2.0 * body && upperWick >= 0.6 * range && lowerWick <= 0.25 * range);
}

bool IsBullishEngulfing(int shift)
{
   double o1 = iOpen(_Symbol, PERIOD_M1, shift + 1), c1 = iClose(_Symbol, PERIOD_M1, shift + 1);
   double o0 = iOpen(_Symbol, PERIOD_M1, shift),     c0 = iClose(_Symbol, PERIOD_M1, shift);
   bool prevBearish = c1 < o1;
   bool curBullish  = c0 > o0;
   return prevBearish && curBullish && o0 <= c1 && c0 >= o1;
}

bool IsBearishEngulfing(int shift)
{
   double o1 = iOpen(_Symbol, PERIOD_M1, shift + 1), c1 = iClose(_Symbol, PERIOD_M1, shift + 1);
   double o0 = iOpen(_Symbol, PERIOD_M1, shift),     c0 = iClose(_Symbol, PERIOD_M1, shift);
   bool prevBullish = c1 > o1;
   bool curBearish  = c0 < o0;
   return prevBullish && curBearish && o0 >= c1 && c0 <= o1;
}

//====================================================================
// Trade execution
//====================================================================
void OpenTrade(int direction)
{
   if(PositionExists()) return;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(direction == 1)
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = NormalizeDouble(price - InpSL_Price, digits);
      double tp = NormalizeDouble(price + InpTP_Price, digits);
      trade.Buy(InpLotSize, _Symbol, price, sl, tp, "MeanRev Buy");
   }
   else
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = NormalizeDouble(price + InpSL_Price, digits);
      double tp = NormalizeDouble(price - InpTP_Price, digits);
      trade.Sell(InpLotSize, _Symbol, price, sl, tp, "MeanRev Sell");
   }
   PrintFormat("[MeanRev] Opened %s @ %s", DirStr(direction), TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
}

void ManageBreakeven()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) continue;

      long   type      = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL      = PositionGetDouble(POSITION_SL);
      double curTP      = PositionGetDouble(POSITION_TP);

      if(type == POSITION_TYPE_BUY)
      {
         double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double profit = bid - openPrice;
         if(profit >= InpSLBE_TriggerPrice && curSL < openPrice - _Point)
         {
            double newSL = NormalizeDouble(openPrice, digits);
            trade.PositionModify(ticket, newSL, curTP);
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double profit = openPrice - ask;
         if(profit >= InpSLBE_TriggerPrice && (curSL > openPrice + _Point || curSL == 0))
         {
            double newSL = NormalizeDouble(openPrice, digits);
            trade.PositionModify(ticket, newSL, curTP);
         }
      }
   }
}

void CheckEarlyClose()
{
   if(!InpUseEarlyClose) return;
   if(!IsNewBar(InpEarlyClose_Timeframe, lastBarTimeEarlyClose)) return;

   double macdMain[], macdSignal[];
   if(!GetBufferSeries(earlyCloseMacdHandle, 0, 3, macdMain)) return;
   if(!GetBufferSeries(earlyCloseMacdHandle, 1, 3, macdSignal)) return;

   bool crossUp   = macdMain[2] < macdSignal[2] && macdMain[1] > macdSignal[1];
   bool crossDown = macdMain[2] > macdSignal[2] && macdMain[1] < macdSignal[1];
   if(!crossUp && !crossDown) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) continue;

      long type = PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_SELL && crossUp)
      {
         trade.PositionClose(ticket);
         Print("[MeanRev] Early close SELL: MACD ", EnumToString(InpEarlyClose_Timeframe), " crossed up");
      }
      else if(type == POSITION_TYPE_BUY && crossDown)
      {
         trade.PositionClose(ticket);
         Print("[MeanRev] Early close BUY: MACD ", EnumToString(InpEarlyClose_Timeframe), " crossed down");
      }
   }
}

//====================================================================
// M5 trigger (Stoch extreme + MACD cross) -> arm pending signal
//====================================================================
void ArmPendingSignal(int direction)
{
   pending.active    = true;
   pending.direction = direction;
   pending.armedTime = TimeCurrent();
   pending.deadline  = TimeCurrent() + InpM1_ConfirmMaxMinutes * 60;
   PrintFormat("[MeanRev] Armed %s signal, waiting M1 confirm until %s",
               DirStr(direction), TimeToString(pending.deadline, TIME_DATE|TIME_SECONDS));
}

void DetectM5Trigger()
{
   if(pending.active) return;      // already waiting for M1 confirm
   if(PositionExists()) return;

   double stochMain[];
   if(!GetBufferSeries(stochHandle, 0, 3, stochMain)) return;

   double macdMain[], macdSignal[];
   if(!GetBufferSeries(macdHandle, 0, 3, macdMain)) return;
   if(!GetBufferSeries(macdHandle, 1, 3, macdSignal)) return;

   bool macdCrossDown = macdMain[2] > macdSignal[2] && macdMain[1] < macdSignal[1];
   bool macdCrossUp   = macdMain[2] < macdSignal[2] && macdMain[1] > macdSignal[1];

   bool stochSellZone = stochMain[1] >= InpStoch_SellLevel;
   bool stochBuyZone  = stochMain[1] <= InpStoch_BuyLevel;

   string reason = "";
   if(stochSellZone && macdCrossDown)
   {
      if(CheckGateConditions(-1, reason)) ArmPendingSignal(-1);
      else PrintFormat("[MeanRev] SELL trigger on M5 but blocked: %s", reason);
   }
   else if(stochBuyZone && macdCrossUp)
   {
      if(CheckGateConditions(1, reason)) ArmPendingSignal(1);
      else PrintFormat("[MeanRev] BUY trigger on M5 but blocked: %s", reason);
   }
}

//====================================================================
// M1 confirmation of the pending signal (Pin Bar / Engulfing)
//====================================================================
void EvaluateM1Confirmation()
{
   if(!pending.active) return;

   bool confirmed = false;
   if(pending.direction == 1)
   {
      if(InpUsePinBar && IsBullishPinBar(1)) confirmed = true;
      if(!confirmed && InpUseEngulfing && IsBullishEngulfing(1)) confirmed = true;
   }
   else
   {
      if(InpUsePinBar && IsBearishPinBar(1)) confirmed = true;
      if(!confirmed && InpUseEngulfing && IsBearishEngulfing(1)) confirmed = true;
   }

   if(!confirmed) return;

   string reason = "";
   if(CheckGateConditions(pending.direction, reason))
   {
      OpenTrade(pending.direction);
   }
   else
   {
      PrintFormat("[MeanRev] M1 pattern confirmed %s but gate blocked: %s", DirStr(pending.direction), reason);
   }
   pending.active = false; // pattern is a one-bar event either way, don't carry it forward
}

//====================================================================
// Dashboard
//====================================================================
void SetLabel(string name, string text, color clr)
{
   if(ObjectFind(0, name) < 0) return;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void CreateDashboard()
{
   string keys[] = {"Title","Stoch","Macd","Adx","Ema","Atr","Hour","News","M1","Sep","Position","Status"};
   int x = 10, y = 18, dy = 16;
   for(int i = 0; i < ArraySize(keys); i++)
   {
      string name = DASH_PREFIX + keys[i];
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + i * dy);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrSilver);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetString(0, name, OBJPROP_TEXT, "...");
   }
}

void DeleteDashboard()
{
   ObjectsDeleteAll(0, DASH_PREFIX);
}

void UpdateDashboard()
{
   color clrOk = clrLimeGreen, clrBad = clrTomato, clrNeutral = clrSilver, clrWait = clrKhaki;

   SetLabel(DASH_PREFIX + "Title", "=== EA STATUS: XAUUSD Mean Reversion ===", clrWhite);

   double stochMain[];
   if(GetBufferSeries(stochHandle, 0, 2, stochMain))
   {
      string state; color c;
      if(stochMain[1] >= InpStoch_SellLevel)      { state = StringFormat("Sell: ĐẠT (>=%.0f)", InpStoch_SellLevel); c = clrOk; }
      else if(stochMain[1] <= InpStoch_BuyLevel)  { state = StringFormat("Buy: ĐẠT (<=%.0f)", InpStoch_BuyLevel); c = clrOk; }
      else                                          { state = StringFormat("chưa đạt | cần >=%.0f hoặc <=%.0f", InpStoch_SellLevel, InpStoch_BuyLevel); c = clrNeutral; }
      SetLabel(DASH_PREFIX + "Stoch", StringFormat("Stoch(%d): %6.2f   [%s]", InpStoch_K, stochMain[1], state), c);
   }

   double macdMain[], macdSignal[];
   if(GetBufferSeries(macdHandle, 0, 3, macdMain) && GetBufferSeries(macdHandle, 1, 3, macdSignal))
   {
      bool crossDown = macdMain[2] > macdSignal[2] && macdMain[1] < macdSignal[1];
      bool crossUp   = macdMain[2] < macdSignal[2] && macdMain[1] > macdSignal[1];
      string txt; color c;
      if(crossDown)      { txt = "MACD Cross:     cắt XUỐNG [Sell trigger]"; c = clrOk; }
      else if(crossUp)   { txt = "MACD Cross:     cắt LÊN [Buy trigger]"; c = clrOk; }
      else                 { txt = "MACD Cross:     chờ [chưa cắt]"; c = clrNeutral; }
      SetLabel(DASH_PREFIX + "Macd", txt, c);
   }

   double adxMain[];
   if(GetBufferSeries(adxHandle, 0, 2, adxMain))
   {
      bool ok = adxMain[1] <= InpADX_MaxThreshold;
      SetLabel(DASH_PREFIX + "Adx", StringFormat("ADX(%d):         %6.2f   [%s]", InpADX_Period, adxMain[1], ok ? "OK - cho phép" : "CHẶN - trend quá mạnh"), ok ? clrOk : clrBad);
   }

   if(InpUseEMAFilter)
   {
      double emaVal[];
      if(GetBufferSeries(emaHandle, 0, 2, emaVal))
      {
         double refPrice = iClose(_Symbol, PERIOD_M5, 1);
         string trend = refPrice >= emaVal[1] ? "Tăng" : "Giảm";
         SetLabel(DASH_PREFIX + "Ema", StringFormat("EMA Filter %s:  %s (EMA=%.2f)", EnumToString(InpEMA_Timeframe), trend, emaVal[1]), clrNeutral);
      }
   }
   else
      SetLabel(DASH_PREFIX + "Ema", "EMA Filter:     TẮT (không dùng)", clrNeutral);

   double atrVal[];
   if(GetBufferSeries(atrHandle, 0, 2, atrVal))
   {
      bool ok = atrVal[1] >= InpATR_MinPoints && atrVal[1] <= InpATR_MaxPoints;
      SetLabel(DASH_PREFIX + "Atr", StringFormat("ATR(%d):         %6.2f   [%s]", InpATR_Period, atrVal[1], ok ? "OK - trong ngưỡng" : "NGOÀI ngưỡng"), ok ? clrOk : clrBad);
   }

   bool hourBlocked = IsTradingHourBlocked();
   SetLabel(DASH_PREFIX + "Hour", StringFormat("Giờ giao dịch:  %s", hourBlocked ? "CHẶN (00:00-02:00 server)" : "OK"), hourBlocked ? clrBad : clrOk);

   bool newsBlocked = InpUseNewsFilter && IsNewsBlocked();
   SetLabel(DASH_PREFIX + "News", StringFormat("Tin tức:        %s", !InpUseNewsFilter ? "TẮT bộ lọc" : (newsBlocked ? "CHẶN - có tin High" : "OK - không có tin High")), newsBlocked ? clrBad : clrOk);

   if(pending.active)
   {
      long remainSec = (long)(pending.deadline - TimeCurrent());
      if(remainSec < 0) remainSec = 0;
      SetLabel(DASH_PREFIX + "M1", StringFormat("M1 Confirm:     chờ %s... (còn %d phút)", DirStr(pending.direction), (int)(remainSec / 60)), clrWait);
   }
   else
      SetLabel(DASH_PREFIX + "M1", "M1 Confirm:     --", clrNeutral);

   SetLabel(DASH_PREFIX + "Sep", "─────────────────────", clrGray);

   bool hasPos = PositionExists();
   SetLabel(DASH_PREFIX + "Position", StringFormat("Lệnh đang mở:   %s", hasPos ? "CÓ" : "KHÔNG"), hasPos ? clrWait : clrNeutral);

   string status;
   if(hasPos)                status = "ĐANG QUẢN LÝ LỆNH MỞ";
   else if(pending.active)   status = "ĐANG CHỜ TÍN HIỆU M1";
   else                       status = "ĐANG CHỜ TÍN HIỆU M5";
   SetLabel(DASH_PREFIX + "Status", StringFormat("Trạng thái:     %s", status), clrWhite);
}

//====================================================================
// Expert lifecycle
//====================================================================
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);

   stochHandle = iStochastic(_Symbol, PERIOD_M5, InpStoch_K, InpStoch_D, InpStoch_Slowing, MODE_SMA, STO_LOWHIGH);
   macdHandle  = iMACD(_Symbol, PERIOD_M5, InpMACD_Fast, InpMACD_Slow, InpMACD_Signal, PRICE_CLOSE);
   adxHandle   = iADX(_Symbol, PERIOD_M5, InpADX_Period);
   atrHandle   = iATR(_Symbol, PERIOD_M5, InpATR_Period);

   if(stochHandle == INVALID_HANDLE || macdHandle == INVALID_HANDLE ||
      adxHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
   {
      Print("[MeanRev] Failed to create core indicator handles");
      return INIT_FAILED;
   }

   if(InpUseEMAFilter)
   {
      emaHandle = iMA(_Symbol, InpEMA_Timeframe, InpEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      if(emaHandle == INVALID_HANDLE)
      {
         Print("[MeanRev] Failed to create EMA handle");
         return INIT_FAILED;
      }
   }

   if(InpUseEarlyClose)
   {
      earlyCloseMacdHandle = iMACD(_Symbol, InpEarlyClose_Timeframe, InpMACD_Fast, InpMACD_Slow, InpMACD_Signal, PRICE_CLOSE);
      if(earlyCloseMacdHandle == INVALID_HANDLE)
      {
         Print("[MeanRev] Failed to create early-close MACD handle");
         return INIT_FAILED;
      }
   }

   pending.active    = false;
   pending.direction = 0;
   pending.armedTime = 0;
   pending.deadline   = 0;

   CreateDashboard();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(stochHandle != INVALID_HANDLE) IndicatorRelease(stochHandle);
   if(macdHandle != INVALID_HANDLE) IndicatorRelease(macdHandle);
   if(adxHandle != INVALID_HANDLE) IndicatorRelease(adxHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(emaHandle != INVALID_HANDLE) IndicatorRelease(emaHandle);
   if(earlyCloseMacdHandle != INVALID_HANDLE) IndicatorRelease(earlyCloseMacdHandle);
   DeleteDashboard();
}

void OnTick()
{
   ManageBreakeven();
   CheckEarlyClose();

   bool newM5 = IsNewBar(PERIOD_M5, lastBarTimeM5);
   bool newM1 = IsNewBar(PERIOD_M1, lastBarTimeM1);

   if(newM5)
      DetectM5Trigger();

   if(pending.active)
   {
      if(TimeCurrent() > pending.deadline)
      {
         PrintFormat("[MeanRev] Pending %s signal expired (no M1 confirm within %d min)", DirStr(pending.direction), InpM1_ConfirmMaxMinutes);
         pending.active = false;
      }
      else if(newM1)
         EvaluateM1Confirmation();
   }

   UpdateDashboard();
}
