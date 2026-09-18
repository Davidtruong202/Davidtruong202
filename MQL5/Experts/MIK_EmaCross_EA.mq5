//+------------------------------------------------------------------+
//|                                          MIK_EmaCross_EA.mq5     |
//|  EA tu dong hoa dung logic cua indicator MIK EmaCross Signal:    |
//|  BUY  khi EMA9 > EMA20 (gia)  VA  EMA9(RSI14) > WMA45(RSI14)     |
//|  SELL khi EMA9 < EMA20 (gia)  VA  EMA9(RSI14) < WMA45(RSI14)     |
//|  EXIT khi 1 trong 2 ve phia tren gay - dong lenh dang mo          |
//|  Danh gia tren nen VUA DONG CUA (shift=1), khong theo tick dang   |
//|  hinh thanh nhu indicator hien thi - tranh whipsaw/repaint khi    |
//|  vao lenh that. Chay theo dung khung gio cua chart gan EA (giong  |
//|  indicator dung PERIOD_CURRENT).                                  |
//+------------------------------------------------------------------+
#property copyright "Custom EA"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// Inputs
//====================================================================
input group "=== EMA tren gia (chart) ==="
input int    InpEma9Period    = 9;
input int    InpEma20Period   = 20;

input group "=== RSI cross ==="
input int    InpRsiPeriod     = 14;
input int    InpRsiEmaPeriod  = 9;
input int    InpRsiWmaPeriod  = 45;

input group "=== ATR / SL-TP (boi so ATR tu gia vao lenh) ==="
input int    InpAtrPeriod     = 14;
input double InpSlAtr         = 1.5;   // SL = InpSlAtr x ATR
input double InpTpAtr         = 3.0;   // TP = InpTpAtr x ATR

input group "=== Quan ly lenh ==="
input double InpLotSize             = 0.01;
input ulong  InpMagicNumber          = 20260918;
input bool   InpCloseOnExitSignal    = true;   // dong lenh ngay khi co tin hieu Exit (1 ve gay)
input bool   InpReverseOnOpposite    = false;  // true: dong lenh cu + mo lenh nguoc ngay khi tin hieu dao chieu han; false: chi dong, cho nen sau

input group "=== Loc khung gio (server time) ==="
input bool   InpUseTimeFilter = false;
input int    InpStartHour     = 7;
input int    InpEndHour       = 22;

input group "=== [MOI] Loc xu huong ADX (chan whipsaw khi di ngang) ==="
input bool   InpUseAdxFilter    = true;   // Chi vao lenh moi khi ADX >= nguong - day la EA thuan xu huong, can trend that
input int    InpAdxPeriod       = 14;
input double InpAdxMinThreshold = 25.0;   // ADX < nguong nay = thi truong di ngang -> khong vao lenh

input group "=== [MOI] Chong whipsaw ==="
input int    InpMinBarsBetween  = 5;      // So nen toi thieu phai cho sau lenh truoc (dong hoac dao chieu) truoc khi mo lenh moi

input group "=== [MOI] Loc xu huong khung lon (HTF) ==="
input bool             InpUseHtfFilter = true;      // Chi vao lenh cung chieu voi trend khung lon
input ENUM_TIMEFRAMES  InpHtfTimeframe = PERIOD_H1;
input int              InpHtfEmaPeriod = 50;

input group "=== [MOI] Tam dung sau chuoi thua (circuit breaker) ==="
input bool   InpUsePauseAfterLosses = true;
input int    InpMaxConsecLosses     = 4;    // So lenh thua lien tiep de kich hoat tam dung
input int    InpPauseBars           = 20;   // So nen tam dung sau khi cham nguong

//====================================================================
// Globals
//====================================================================
int emaFastHandle = INVALID_HANDLE;
int emaSlowHandle = INVALID_HANDLE;
int rsiHandle     = INVALID_HANDLE;
int atrHandle     = INVALID_HANDLE;
int adxHandle     = INVALID_HANDLE;
int htfEmaHandle  = INVALID_HANDLE;

datetime lastBarTime = 0;
int      g_barsSinceLastTrade = 999999; // dem so nen da troi qua ke tu lan mo/dong lenh gan nhat
int      g_consecLosses  = 0;
int      g_pauseBarsLeft = 0;

#define DASH_PREFIX "MIK_Dash_"

//====================================================================
// Helpers
//====================================================================
bool GetBufferSeries(int handle, int bufferIndex, int count, double &arr[])
{
   if (handle == INVALID_HANDLE) return false;
   ArraySetAsSeries(arr, true);
   int copied = CopyBuffer(handle, bufferIndex, 0, count, arr);
   return copied >= count;
}

bool IsNewBar()
{
   datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
   if (t == 0) return false;
   if (t != lastBarTime)
   {
      lastBarTime = t;
      return true;
   }
   return false;
}

bool PositionExists()
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) continue;
      return true;
   }
   return false;
}

// Tra ve 1 (buy), -1 (sell), 0 (khong co lenh cua EA nay)
int GetPositionDirection()
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      return (type == POSITION_TYPE_BUY) ? 1 : -1;
   }
   return 0;
}

void ClosePosition()
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) continue;
      trade.PositionClose(ticket);
   }
   g_barsSinceLastTrade = 0;
}

// [MOI] ADX < nguong = thi truong dang di ngang, chan vao lenh de giam whipsaw
bool IsAdxTooWeak()
{
   if (!InpUseAdxFilter) return false;
   double adxVal[];
   if (!GetBufferSeries(adxHandle, 0, 2, adxVal)) return true; // thieu du lieu -> an toan, coi nhu chan
   return adxVal[1] < InpAdxMinThreshold;
}

// [MOI] Chi cho vao lenh cung chieu voi trend khung lon (gia vs EMA tren HTF)
bool IsAgainstHtfTrend(int direction)
{
   if (!InpUseHtfFilter) return false;
   double htfEma[];
   if (!GetBufferSeries(htfEmaHandle, 0, 2, htfEma)) return true; // thieu du lieu -> an toan, coi nhu chan
   double refPrice = iClose(_Symbol, PERIOD_CURRENT, 1);
   if (direction == 1  && refPrice < htfEma[1]) return true; // BUY nguoc downtrend lon
   if (direction == -1 && refPrice > htfEma[1]) return true; // SELL nguoc uptrend lon
   return false;
}

bool IsTradingHourBlocked()
{
   if (!InpUseTimeFilter) return false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;
   if (InpStartHour == InpEndHour) return false;
   if (InpStartHour < InpEndHour)
      return !(h >= InpStartHour && h < InpEndHour);
   return !(h >= InpStartHour || h < InpEndHour);
}

string DirStr(int d) { return d == 1 ? "BUY" : (d == -1 ? "SELL" : "FLAT/EXIT"); }

//+------------------------------------------------------------------+
//| Tinh EMA(RSI) va WMA(RSI) thu cong (khong co ham dung san trong  |
//| MQL5 de ap MA len buffer cua indicator khac) - chi can tinh lai  |
//| moi khi co nen moi, khong can persist giua cac tick.             |
//+------------------------------------------------------------------+
bool ComputeRsiCross(double &rsiEma1, double &rsiWma1, double &rsiEma2, double &rsiWma2)
{
   int need = InpRsiWmaPeriod + InpRsiEmaPeriod + 60;
   double rsiRaw[];
   if (!GetBufferSeries(rsiHandle, 0, need, rsiRaw)) return false;

   // Dao lai thanh thu tu thoi gian tang dan (index 0 = cu nhat) de tinh EMA/WMA de quy
   ArraySetAsSeries(rsiRaw, false);

   double rsiEma[];
   ArrayResize(rsiEma, need);
   double kEma = 2.0 / (InpRsiEmaPeriod + 1.0);
   for (int i = 0; i < need; i++)
   {
      if (i == 0) rsiEma[i] = rsiRaw[i];
      else        rsiEma[i] = rsiRaw[i] * kEma + rsiEma[i-1] * (1.0 - kEma);
   }

   double rsiWma[];
   ArrayResize(rsiWma, need);
   int wn = InpRsiWmaPeriod;
   for (int i = 0; i < need; i++)
   {
      if (i + 1 < wn) { rsiWma[i] = rsiRaw[i]; continue; }
      double sumW = 0, sumWX = 0;
      for (int k = 0; k < wn; k++)
      {
         double w = (wn - k);
         sumWX += w * rsiRaw[i - k];
         sumW  += w;
      }
      rsiWma[i] = sumWX / sumW;
   }

   // index need-1 = nen dang hinh thanh (shift0), need-2 = shift1 (vua dong), need-3 = shift2
   rsiEma1 = rsiEma[need - 2];
   rsiWma1 = rsiWma[need - 2];
   rsiEma2 = rsiEma[need - 3];
   rsiWma2 = rsiWma[need - 3];
   return true;
}

int BarState(double e9, double e20, double re, double rw)
{
   if (e9 > e20 && re > rw) return 1;
   if (e9 < e20 && re < rw) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Mo lenh theo huong direction (1=buy, -1=sell), SL/TP theo ATR    |
//+------------------------------------------------------------------+
void OpenTrade(int direction)
{
   if (PositionExists()) return;
   if (IsTradingHourBlocked()) return;
   if (IsAdxTooWeak()) return;                              // [MOI] chan khi thi truong di ngang
   if (g_barsSinceLastTrade < InpMinBarsBetween) return;     // [MOI] chan whipsaw ngay sau lenh truoc
   if (IsAgainstHtfTrend(direction)) return;                // [MOI] chan lenh nguoc xu huong khung lon
   if (InpUsePauseAfterLosses && g_pauseBarsLeft > 0) return; // [MOI] dang tam dung sau chuoi thua

   double atrVal[];
   if (!GetBufferSeries(atrHandle, 0, 2, atrVal)) return;
   double atr = atrVal[1];
   if (atr <= 0) return;

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if (direction == 1)
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = (InpSlAtr > 0) ? NormalizeDouble(price - atr * InpSlAtr, digits) : 0;
      double tp = (InpTpAtr > 0) ? NormalizeDouble(price + atr * InpTpAtr, digits) : 0;
      trade.Buy(InpLotSize, _Symbol, price, sl, tp, "MIK EmaCross Buy");
   }
   else
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = (InpSlAtr > 0) ? NormalizeDouble(price + atr * InpSlAtr, digits) : 0;
      double tp = (InpTpAtr > 0) ? NormalizeDouble(price - atr * InpTpAtr, digits) : 0;
      trade.Sell(InpLotSize, _Symbol, price, sl, tp, "MIK EmaCross Sell");
   }
   g_barsSinceLastTrade = 0;
}

//+------------------------------------------------------------------+
//| Xu ly tin hieu khi co nen moi dong cua                           |
//+------------------------------------------------------------------+
void ProcessSignal()
{
   double ema9[], ema20[];
   if (!GetBufferSeries(emaFastHandle, 0, 3, ema9)) return;
   if (!GetBufferSeries(emaSlowHandle, 0, 3, ema20)) return;

   double rsiEma1, rsiWma1, rsiEma2, rsiWma2;
   if (!ComputeRsiCross(rsiEma1, rsiWma1, rsiEma2, rsiWma2)) return;

   int st1 = BarState(ema9[1], ema20[1], rsiEma1, rsiWma1); // nen vua dong (shift1)
   int st2 = BarState(ema9[2], ema20[2], rsiEma2, rsiWma2); // nen truoc do (shift2)

   if (st1 == st2) return; // trang thai khong doi, khong lam gi (giong "chong spam" cua indicator)

   bool hasPos = PositionExists();
   int  posDir = hasPos ? GetPositionDirection() : 0;

   if (st1 == 0) // Exit
   {
      if (hasPos && InpCloseOnExitSignal)
      {
         ClosePosition();
         Print("[MIK EmaCross EA] Exit signal - da dong lenh ", DirStr(posDir));
      }
      return;
   }

   // st1 == 1 (Buy) hoac -1 (Sell)
   if (hasPos)
   {
      if (posDir != st1)
      {
         ClosePosition();
         Print("[MIK EmaCross EA] Tin hieu dao chieu - da dong lenh ", DirStr(posDir));
         if (InpReverseOnOpposite)
            OpenTrade(st1);
      }
      // posDir == st1: dang dung huong, khong lam gi them
   }
   else
   {
      if (!IsTradingHourBlocked())
      {
         OpenTrade(st1);
         Print("[MIK EmaCross EA] Mo lenh moi ", DirStr(st1));
      }
   }
}

//+------------------------------------------------------------------+
//| [MOI] Theo doi chuoi lenh thua lien tiep de kich hoat tam dung   |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                          const MqlTradeRequest &request,
                          const MqlTradeResult &result)
{
   if (!InpUsePauseAfterLosses) return;
   if (trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

   ulong dealTicket = trans.deal;
   if (!HistoryDealSelect(dealTicket)) return;
   if (HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != (long)InpMagicNumber) return;
   if (HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) return;

   long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if (entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) return; // chi quan tam luc DONG lenh

   double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) +
                    HistoryDealGetDouble(dealTicket, DEAL_SWAP) +
                    HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

   if (profit < 0)
   {
      g_consecLosses++;
      if (g_consecLosses >= InpMaxConsecLosses)
      {
         g_pauseBarsLeft = InpPauseBars;
         g_consecLosses  = 0;
         PrintFormat("[MIK EmaCross EA] Cham %d lenh thua lien tiep - tam dung %d nen", InpMaxConsecLosses, InpPauseBars);
      }
   }
   else
   {
      g_consecLosses = 0;
   }
}

//====================================================================
// Dashboard
//====================================================================
void SetLabel(string name, string text, color clr)
{
   if (ObjectFind(0, name) < 0) return;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void CreateDashboard()
{
   string keys[] = {"Title", "Ema", "Rsi", "Adx", "Htf", "Hour", "Pause", "Position", "Status"};
   int x = 10, y = 18, dy = 16;
   for (int i = 0; i < ArraySize(keys); i++)
   {
      string name = DASH_PREFIX + keys[i];
      if (ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + i * dy);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrSilver);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, name, OBJPROP_TEXT, "...");
   }
}

void DeleteDashboard()
{
   ObjectsDeleteAll(0, DASH_PREFIX);
}

void UpdateDashboard()
{
   color clrOk = clrLimeGreen, clrBad = clrTomato, clrNeutral = clrSilver;

   SetLabel(DASH_PREFIX + "Title", "=== MIK EmaCross EA ===", clrWhite);

   double ema9[], ema20[];
   if (GetBufferSeries(emaFastHandle, 0, 2, ema9) && GetBufferSeries(emaSlowHandle, 0, 2, ema20))
   {
      bool priceBuy = ema9[1] > ema20[1];
      SetLabel(DASH_PREFIX + "Ema", StringFormat("EMA9/20: %.2f / %.2f [%s]", ema9[1], ema20[1], priceBuy ? "Tren" : "Duoi"),
                priceBuy ? clrOk : clrBad);
   }

   double rsiEma1, rsiWma1, rsiEma2, rsiWma2;
   if (ComputeRsiCross(rsiEma1, rsiWma1, rsiEma2, rsiWma2))
   {
      bool rsiBuy = rsiEma1 > rsiWma1;
      SetLabel(DASH_PREFIX + "Rsi", StringFormat("EMA9(RSI)/WMA45(RSI): %.1f / %.1f [%s]", rsiEma1, rsiWma1, rsiBuy ? "Tren" : "Duoi"),
                rsiBuy ? clrOk : clrBad);
   }

   double adxVal[];
   if (GetBufferSeries(adxHandle, 0, 2, adxVal))
   {
      bool weak = InpUseAdxFilter && adxVal[1] < InpAdxMinThreshold;
      SetLabel(DASH_PREFIX + "Adx", StringFormat("ADX(%d): %.1f [%s]", InpAdxPeriod, adxVal[1],
                !InpUseAdxFilter ? "TAT loc" : (weak ? "DI NGANG - chan" : "OK - co trend")),
                !InpUseAdxFilter ? clrNeutral : (weak ? clrBad : clrOk));
   }

   double htfEma[];
   if (GetBufferSeries(htfEmaHandle, 0, 2, htfEma))
   {
      double refPrice = iClose(_Symbol, PERIOD_CURRENT, 1);
      bool htfUp = refPrice >= htfEma[1];
      SetLabel(DASH_PREFIX + "Htf", StringFormat("HTF(%s) EMA%d: %s", EnumToString(InpHtfTimeframe), InpHtfEmaPeriod,
                !InpUseHtfFilter ? "TAT loc" : (htfUp ? "Gia tren - uptrend" : "Gia duoi - downtrend")),
                !InpUseHtfFilter ? clrNeutral : (htfUp ? clrOk : clrBad));
   }

   bool hourBlocked = IsTradingHourBlocked();
   SetLabel(DASH_PREFIX + "Hour", StringFormat("Gio giao dich: %s", hourBlocked ? "CHAN" : "OK"), hourBlocked ? clrBad : clrOk);

   SetLabel(DASH_PREFIX + "Pause",
             InpUsePauseAfterLosses ? StringFormat("Circuit breaker: %s", g_pauseBarsLeft > 0 ? StringFormat("TAM DUNG (%d nen)", g_pauseBarsLeft) : StringFormat("OK (thua lien tiep %d/%d)", g_consecLosses, InpMaxConsecLosses))
                                      : "Circuit breaker: TAT",
             g_pauseBarsLeft > 0 ? clrBad : clrOk);

   bool hasPos = PositionExists();
   int  posDir = hasPos ? GetPositionDirection() : 0;
   SetLabel(DASH_PREFIX + "Position", StringFormat("Lenh dang mo: %s", hasPos ? DirStr(posDir) : "KHONG"), hasPos ? clrOk : clrNeutral);

   int waitBars = InpMinBarsBetween - g_barsSinceLastTrade;
   if (waitBars < 0) waitBars = 0;
   SetLabel(DASH_PREFIX + "Status", StringFormat("TF: %s | Cho whipsaw: %d nen", EnumToString((ENUM_TIMEFRAMES)Period()), waitBars), clrWhite);
}

//====================================================================
// Expert lifecycle
//====================================================================
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);

   emaFastHandle = iMA(_Symbol, PERIOD_CURRENT, InpEma9Period,  0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, PERIOD_CURRENT, InpEma20Period, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle     = iRSI(_Symbol, PERIOD_CURRENT, InpRsiPeriod, PRICE_CLOSE);
   atrHandle     = iATR(_Symbol, PERIOD_CURRENT, InpAtrPeriod);
   adxHandle     = iADX(_Symbol, PERIOD_CURRENT, InpAdxPeriod);
   htfEmaHandle  = iMA(_Symbol, InpHtfTimeframe, InpHtfEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);

   if (emaFastHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE ||
       rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE ||
       adxHandle == INVALID_HANDLE || htfEmaHandle == INVALID_HANDLE)
   {
      Print("[MIK EmaCross EA] Khong tao duoc indicator handle");
      return INIT_FAILED;
   }

   CreateDashboard();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if (emaFastHandle != INVALID_HANDLE) IndicatorRelease(emaFastHandle);
   if (emaSlowHandle != INVALID_HANDLE) IndicatorRelease(emaSlowHandle);
   if (rsiHandle     != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if (atrHandle      != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if (adxHandle      != INVALID_HANDLE) IndicatorRelease(adxHandle);
   if (htfEmaHandle   != INVALID_HANDLE) IndicatorRelease(htfEmaHandle);
   DeleteDashboard();
}

void OnTick()
{
   if (IsNewBar())
   {
      if (g_barsSinceLastTrade < 999999) g_barsSinceLastTrade++;
      if (g_pauseBarsLeft > 0) g_pauseBarsLeft--;
      ProcessSignal();
   }

   UpdateDashboard();
}
