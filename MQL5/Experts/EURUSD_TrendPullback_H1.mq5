//+------------------------------------------------------------------+
//|                                    EURUSD_TrendPullback_H1.mq5   |
//|  EA giao dịch EURUSD theo xu hướng + hồi giá (trend pullback).   |
//|  - Xu hướng lớn: EMA nhanh/chậm trên khung H4 (mặc định).        |
//|  - Vào lệnh: nến H1 đóng cửa hồi về chạm EMA20 rồi đóng lại      |
//|    theo hướng xu hướng, lọc thêm RSI và ADX.                     |
//|  - SL theo swing + ATR, TP theo R:R, hoà vốn và trailing ATR.    |
//|  - Quản lý vốn: rủi ro % mỗi lệnh, giới hạn lỗ ngày, số lệnh/ngày |
//|    lọc spread, lọc phiên London/New York, đóng lệnh tối thứ Sáu.  |
//|  Tín hiệu chỉ tính trên nến đã đóng (không repaint).             |
//+------------------------------------------------------------------+
#property copyright "Custom EA"
#property version   "1.00"
#property description "EURUSD trend pullback EA (H1 entry, H4 trend filter)"

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// Inputs
//====================================================================
input group "=== Chung ==="
input long            InpMagic              = 20260930;  // Magic number
input ENUM_TIMEFRAMES InpEntryTF            = PERIOD_H1; // Khung vào lệnh
input ENUM_TIMEFRAMES InpTrendTF            = PERIOD_H4; // Khung xác định xu hướng
input bool            InpOnlyEURUSD         = true;      // Chỉ cho chạy trên symbol EURUSD*

input group "=== Xu hướng (khung lớn) ==="
input int             InpTrendFastEMA       = 50;        // EMA nhanh khung lớn
input int             InpTrendSlowEMA       = 200;       // EMA chậm khung lớn

input group "=== Tín hiệu vào lệnh (khung nhỏ) ==="
input int             InpPullbackEMA        = 20;        // EMA hồi giá
input int             InpEntrySlowEMA       = 50;        // EMA chậm khung vào lệnh (lọc cấu trúc)
input double          InpTouchATR           = 0.25;      // Biên chạm EMA (x ATR)
input int             InpRSIPeriod          = 14;        // Chu kỳ RSI
input double          InpRSIBuyMin          = 50.0;      // RSI tối thiểu để Buy
input double          InpRSISellMax         = 50.0;      // RSI tối đa để Sell
input int             InpADXPeriod          = 14;        // Chu kỳ ADX
input double          InpADXMin             = 20.0;      // ADX tối thiểu (0 = tắt)
input int             InpATRPeriod          = 14;        // Chu kỳ ATR

input group "=== SL / TP ==="
input int             InpSwingLookback      = 5;         // Số nến tìm swing cho SL
input double          InpSLBufferATR        = 0.5;       // Đệm SL ngoài swing (x ATR)
input double          InpMinSLPips          = 10.0;      // SL tối thiểu (pip)
input double          InpMaxSLPips          = 40.0;      // SL tối đa (pip) - vượt thì bỏ lệnh
input double          InpRewardRisk         = 2.0;       // TP = R x SL

input group "=== Quản lý lệnh ==="
input bool            InpUseBreakeven       = true;      // Dời SL về hoà vốn
input double          InpBETriggerR         = 1.0;       // Kích hoạt hoà vốn khi lãi đạt (R)
input double          InpBELockPips         = 1.0;       // Khoá thêm (pip) khi hoà vốn
input bool            InpUseTrailing        = true;      // Trailing stop theo ATR
input double          InpTrailStartR        = 1.5;       // Bắt đầu trailing khi lãi đạt (R)
input double          InpTrailATR           = 1.5;       // Khoảng trailing (x ATR)
input bool            InpExitOnTrendFlip    = true;      // Đóng lệnh khi xu hướng khung lớn đảo

input group "=== Quản lý vốn ==="
input double          InpRiskPercent        = 1.0;       // Rủi ro mỗi lệnh (% balance)
input double          InpFixedLot           = 0.0;       // Lot cố định (>0 thì bỏ qua % rủi ro)
input double          InpMaxDailyLossPct    = 3.0;       // Lỗ tối đa trong ngày (% balance đầu ngày, 0 = tắt)
input int             InpMaxTradesPerDay    = 2;         // Số lệnh mới tối đa mỗi ngày
input int             InpMaxOpenPositions   = 1;         // Số vị thế tối đa cùng lúc

input group "=== Bộ lọc ==="
input double          InpMaxSpreadPips      = 1.5;       // Spread tối đa (pip)
input int             InpServerGMTOffset    = 2;         // Giờ server = GMT + ? (vd 2 hoặc 3)
input int             InpSessionStartGMT    = 7;         // Giờ bắt đầu giao dịch (GMT)
input int             InpSessionEndGMT      = 17;        // Giờ kết thúc nhận lệnh mới (GMT)
input bool            InpCloseFriday        = true;      // Đóng hết lệnh tối thứ Sáu
input int             InpFridayCloseGMT     = 20;        // Giờ đóng lệnh thứ Sáu (GMT)
input bool            InpNoMondayEarly      = true;      // Không vào lệnh trước InpSessionStartGMT thứ Hai (tránh gap)

input group "=== Hiển thị ==="
input bool            InpShowPanel          = true;      // Hiện thông tin trên chart

//====================================================================
// Globals
//====================================================================
int      hTrendFast = INVALID_HANDLE, hTrendSlow = INVALID_HANDLE;
int      hPullEMA   = INVALID_HANDLE, hEntrySlow = INVALID_HANDLE;
int      hRSI       = INVALID_HANDLE, hADX       = INVALID_HANDLE, hATR = INVALID_HANDLE;
double   gPip       = 0.0;
datetime gLastBarTime = 0;
int      gDayOfYear   = -1;
double   gDayStartBalance = 0.0;
bool     gDailyLocked = false;

// thống kê
int      gSignalsBuy = 0, gSignalsSell = 0, gSkippedSpread = 0, gSkippedSL = 0, gOrdersSent = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpOnlyEURUSD && StringFind(_Symbol, "EURUSD") < 0)
   {
      Print("EA chỉ dành cho EURUSD. Symbol hiện tại: ", _Symbol,
            " (tắt InpOnlyEURUSD nếu muốn chạy symbol khác)");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpTrendFastEMA >= InpTrendSlowEMA || InpPullbackEMA >= InpEntrySlowEMA ||
      InpRewardRisk <= 0 || InpRiskPercent < 0 || InpMinSLPips > InpMaxSLPips)
   {
      Print("Tham số không hợp lệ");
      return INIT_PARAMETERS_INCORRECT;
   }

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   gPip = (digits == 3 || digits == 5) ? _Point * 10.0 : _Point;

   hTrendFast = iMA(_Symbol, InpTrendTF, InpTrendFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hTrendSlow = iMA(_Symbol, InpTrendTF, InpTrendSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hPullEMA   = iMA(_Symbol, InpEntryTF, InpPullbackEMA, 0, MODE_EMA, PRICE_CLOSE);
   hEntrySlow = iMA(_Symbol, InpEntryTF, InpEntrySlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hRSI       = iRSI(_Symbol, InpEntryTF, InpRSIPeriod, PRICE_CLOSE);
   hADX       = iADX(_Symbol, InpEntryTF, InpADXPeriod);
   hATR       = iATR(_Symbol, InpEntryTF, InpATRPeriod);

   if(hTrendFast == INVALID_HANDLE || hTrendSlow == INVALID_HANDLE ||
      hPullEMA == INVALID_HANDLE || hEntrySlow == INVALID_HANDLE ||
      hRSI == INVALID_HANDLE || hADX == INVALID_HANDLE || hATR == INVALID_HANDLE)
   {
      Print("Không tạo được indicator handle, lỗi ", GetLastError());
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFillingBySymbol(_Symbol);

   ResetDailyIfNeeded();
   PrintFormat("EURUSD EA khởi động: %s, pip=%.5f, entryTF=%s, trendTF=%s",
               _Symbol, gPip, EnumToString(InpEntryTF), EnumToString(InpTrendTF));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(hTrendFast); IndicatorRelease(hTrendSlow);
   IndicatorRelease(hPullEMA);   IndicatorRelease(hEntrySlow);
   IndicatorRelease(hRSI);       IndicatorRelease(hADX); IndicatorRelease(hATR);
   Comment("");
   PrintFormat("[EURUSD-EA Summary] buySignals=%d sellSignals=%d orders=%d skipSpread=%d skipSL=%d",
               gSignalsBuy, gSignalsSell, gOrdersSent, gSkippedSpread, gSkippedSL);
}

//+------------------------------------------------------------------+
void OnTick()
{
   ResetDailyIfNeeded();
   CheckDailyLoss();

   // Quản lý lệnh đang mở trên mỗi tick (hoà vốn / trailing / đóng thứ Sáu)
   ManagePositions();

   // Panel gọi HistorySelect nên bỏ qua khi backtest không visual để chạy nhanh
   if(InpShowPanel && (!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE))) ShowPanel();

   // Tín hiệu chỉ xét khi có nến mới trên khung vào lệnh
   datetime barTime = iTime(_Symbol, InpEntryTF, 0);
   if(barTime == 0 || barTime == gLastBarTime) return;
   gLastBarTime = barTime;

   if(InpExitOnTrendFlip) CheckTrendFlipExit();

   if(gDailyLocked) return;
   if(!IsTradingTime()) return;
   if(CountMyPositions() >= InpMaxOpenPositions) return;
   if(CountTradesToday() >= InpMaxTradesPerDay) return;

   int signal = GetSignal();
   if(signal == 0) return;

   if(CurrentSpreadPips() > InpMaxSpreadPips)
   {
      gSkippedSpread++;
      PrintFormat("Bỏ tín hiệu: spread %.1f pip > %.1f", CurrentSpreadPips(), InpMaxSpreadPips);
      return;
   }
   OpenTrade(signal);
}

//====================================================================
// Signal
//====================================================================
bool GetBuf(int handle, int buffer, int shift, double &val)
{
   double b[];
   if(CopyBuffer(handle, buffer, shift, 1, b) != 1) return false;
   val = b[0];
   return true;
}

// +1 = tăng, -1 = giảm, 0 = không rõ. Dùng nến khung lớn đã đóng.
int TrendDirection()
{
   double fast, slow;
   if(!GetBuf(hTrendFast, 0, 1, fast) || !GetBuf(hTrendSlow, 0, 1, slow)) return 0;
   double close = iClose(_Symbol, InpTrendTF, 1);
   if(close <= 0) return 0;
   if(fast > slow && close > slow) return  1;
   if(fast < slow && close < slow) return -1;
   return 0;
}

// +1 = Buy, -1 = Sell, 0 = không có tín hiệu. Chỉ dùng nến đã đóng (shift 1).
int GetSignal()
{
   int trend = TrendDirection();
   if(trend == 0) return 0;

   double ema, emaSlow, rsi, adx, atr;
   if(!GetBuf(hPullEMA, 0, 1, ema) || !GetBuf(hEntrySlow, 0, 1, emaSlow) ||
      !GetBuf(hRSI, 0, 1, rsi) || !GetBuf(hADX, 0, 1, adx) || !GetBuf(hATR, 0, 1, atr))
      return 0;
   if(atr <= 0) return 0;

   double o = iOpen (_Symbol, InpEntryTF, 1);
   double h = iHigh (_Symbol, InpEntryTF, 1);
   double l = iLow  (_Symbol, InpEntryTF, 1);
   double c = iClose(_Symbol, InpEntryTF, 1);
   if(c <= 0) return 0;

   double touch = InpTouchATR * atr;
   bool adxOK = (InpADXMin <= 0 || adx >= InpADXMin);

   if(trend == 1)
   {
      bool structure = ema > emaSlow;                 // EMA20 trên EMA50
      bool pullback  = l <= ema + touch;              // râu nến hồi về EMA20
      bool rejection = c > ema && c > o;              // đóng lại trên EMA, nến tăng
      bool notTooDeep= l > emaSlow - touch;           // không phá sâu EMA50
      if(structure && pullback && rejection && notTooDeep && rsi >= InpRSIBuyMin && adxOK)
      {
         gSignalsBuy++;
         return 1;
      }
   }
   else
   {
      bool structure = ema < emaSlow;
      bool pullback  = h >= ema - touch;
      bool rejection = c < ema && c < o;
      bool notTooDeep= h < emaSlow + touch;
      if(structure && pullback && rejection && notTooDeep && rsi <= InpRSISellMax && adxOK)
      {
         gSignalsSell++;
         return -1;
      }
   }
   return 0;
}

//====================================================================
// Trade execution
//====================================================================
void OpenTrade(int dir)
{
   double atr;
   if(!GetBuf(hATR, 0, 1, atr)) return;

   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;

   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double entry  = (dir == 1) ? tk.ask : tk.bid;

   // SL: ngoài swing của N nến gần nhất + đệm ATR
   double sl;
   if(dir == 1)
   {
      int idx = iLowest(_Symbol, InpEntryTF, MODE_LOW, InpSwingLookback, 1);
      if(idx < 0) return;
      sl = iLow(_Symbol, InpEntryTF, idx) - InpSLBufferATR * atr;
   }
   else
   {
      int idx = iHighest(_Symbol, InpEntryTF, MODE_HIGH, InpSwingLookback, 1);
      if(idx < 0) return;
      sl = iHigh(_Symbol, InpEntryTF, idx) + InpSLBufferATR * atr;
   }

   double slDist = MathAbs(entry - sl);
   double minDist = InpMinSLPips * gPip;
   if(slDist < minDist)
   {
      slDist = minDist;
      sl = (dir == 1) ? entry - slDist : entry + slDist;
   }
   if(slDist > InpMaxSLPips * gPip)
   {
      gSkippedSL++;
      PrintFormat("Bỏ tín hiệu: SL %.1f pip > tối đa %.1f", slDist / gPip, InpMaxSLPips);
      return;
   }

   // Tôn trọng stop level của broker
   double stopLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(slDist <= stopLevel) return;

   double tpDist = slDist * InpRewardRisk;
   double tp = (dir == 1) ? entry + tpDist : entry - tpDist;
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   double lots = CalcLots(dir, entry, sl);
   if(lots <= 0)
   {
      Print("Khối lượng tính ra = 0, bỏ lệnh");
      return;
   }

   string cmt = "EURUSD-TP";
   bool ok = (dir == 1) ? trade.Buy (lots, _Symbol, 0, sl, tp, cmt)
                        : trade.Sell(lots, _Symbol, 0, sl, tp, cmt);
   if(ok && (trade.ResultRetcode() == TRADE_RETCODE_DONE || trade.ResultRetcode() == TRADE_RETCODE_PLACED))
   {
      gOrdersSent++;
      PrintFormat("%s %.2f lot @%.5f SL=%.5f (%.1f pip) TP=%.5f (%.1f pip)",
                  dir == 1 ? "BUY" : "SELL", lots, entry, sl, slDist / gPip, tp, tpDist / gPip);
   }
   else
      PrintFormat("Lỗi gửi lệnh: retcode=%u %s", trade.ResultRetcode(), trade.ResultRetcodeDescription());
}

double CalcLots(int dir, double entry, double sl)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(stepLot <= 0) stepLot = 0.01;

   double lots;
   if(InpFixedLot > 0)
      lots = InpFixedLot;
   else
   {
      double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
      // Tính lỗ cho 1 lot nếu chạm SL (chính xác theo tiền tệ tài khoản)
      double lossPerLot = 0.0;
      ENUM_ORDER_TYPE type = (dir == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(!OrderCalcProfit(type, _Symbol, 1.0, entry, sl, lossPerLot) || lossPerLot == 0.0)
      {
         double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         if(tickValue <= 0 || tickSize <= 0) return 0.0;
         lossPerLot = MathAbs(entry - sl) / tickSize * tickValue;
      }
      lossPerLot = MathAbs(lossPerLot);
      if(lossPerLot <= 0) return 0.0;
      lots = riskMoney / lossPerLot;
   }

   lots = MathFloor(lots / stepLot) * stepLot;
   if(lots < minLot)
   {
      PrintFormat("Lot %.3f < min %.2f (vốn quá nhỏ cho mức rủi ro này)", lots, minLot);
      return 0.0;
   }
   lots = MathMin(lots, maxLot);

   // Kiểm tra ký quỹ
   double margin;
   ENUM_ORDER_TYPE t = (dir == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(OrderCalcMargin(t, _Symbol, lots, entry, margin) &&
      margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
   {
      Print("Không đủ ký quỹ cho ", DoubleToString(lots, 2), " lot");
      return 0.0;
   }
   int lotDigits = (int)MathMax(0, MathCeil(-MathLog10(stepLot) - 1e-9));
   return NormalizeDouble(lots, lotDigits);
}

//====================================================================
// Position management
//====================================================================
void ManagePositions()
{
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk)) return;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double stopLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   bool fridayClose = false;
   if(InpCloseFriday)
   {
      MqlDateTime g; TimeToStruct(GMTNow(), g);
      fridayClose = (g.day_of_week == 5 && g.hour >= InpFridayCloseGMT);
   }

   double atr = 0;
   GetBuf(hATR, 0, 1, atr);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !IsMine()) continue;

      if(fridayClose)
      {
         trade.PositionClose(ticket);
         continue;
      }

      long   type  = PositionGetInteger(POSITION_TYPE);
      double open  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);
      double initR = InitialRisk(ticket, open, sl, tp);
      if(initR <= 0) continue;

      bool   isBuy = (type == POSITION_TYPE_BUY);
      double price = isBuy ? tk.bid : tk.ask;
      double profitDist = isBuy ? price - open : open - price;
      double newSL = sl;

      // Hoà vốn
      if(InpUseBreakeven && profitDist >= InpBETriggerR * initR)
      {
         double be = isBuy ? open + InpBELockPips * gPip : open - InpBELockPips * gPip;
         if(isBuy ? (be > newSL) : (newSL == 0 || be < newSL)) newSL = be;
      }
      // Trailing ATR
      if(InpUseTrailing && atr > 0 && profitDist >= InpTrailStartR * initR)
      {
         double tr = isBuy ? price - InpTrailATR * atr : price + InpTrailATR * atr;
         if(isBuy ? (tr > newSL) : (newSL == 0 || tr < newSL)) newSL = tr;
      }

      newSL = NormalizeDouble(newSL, digits);
      if(newSL != NormalizeDouble(sl, digits))
      {
         // SL phải cách giá hiện tại tối thiểu stop level
         if(isBuy ? (price - newSL > stopLevel) : (newSL - price > stopLevel))
         {
            // chỉ sửa khi thay đổi đáng kể (>= 0.2 pip) để tránh spam lệnh sửa
            if(MathAbs(newSL - sl) >= 0.2 * gPip)
               trade.PositionModify(ticket, newSL, tp);
         }
      }
   }
}

// Rủi ro ban đầu (khoảng cách giá) của vị thế: suy ra từ TP / RR để vẫn đúng
// sau khi SL đã được dời về hoà vốn hoặc trailing.
double InitialRisk(ulong ticket, double open, double sl, double tp)
{
   if(tp > 0 && InpRewardRisk > 0)
      return MathAbs(tp - open) / InpRewardRisk;
   if(sl > 0) return MathAbs(open - sl);
   return 0.0;
}

void CheckTrendFlipExit()
{
   int trend = TrendDirection();
   if(trend == 0) return;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !IsMine()) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if((type == POSITION_TYPE_BUY && trend == -1) || (type == POSITION_TYPE_SELL && trend == 1))
      {
         Print("Xu hướng khung lớn đảo chiều -> đóng vị thế #", ticket);
         trade.PositionClose(ticket);
      }
   }
}

//====================================================================
// Helpers
//====================================================================
bool IsMine()
{
   return PositionGetString(POSITION_SYMBOL) == _Symbol &&
          PositionGetInteger(POSITION_MAGIC) == InpMagic;
}

int CountMyPositions()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetTicket(i) > 0 && IsMine()) n++;
   return n;
}

datetime DayStartServer()
{
   MqlDateTime s; TimeToStruct(TimeCurrent(), s);
   s.hour = 0; s.min = 0; s.sec = 0;
   return StructToTime(s);
}

int CountTradesToday()
{
   int n = 0;
   if(!HistorySelect(DayStartServer(), TimeCurrent() + 60)) return 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0) continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(d, DEAL_MAGIC) != InpMagic) continue;
      if(HistoryDealGetInteger(d, DEAL_ENTRY) == DEAL_ENTRY_IN) n++;
   }
   return n;
}

void ResetDailyIfNeeded()
{
   MqlDateTime s; TimeToStruct(TimeCurrent(), s);
   if(s.day_of_year != gDayOfYear)
   {
      gDayOfYear = s.day_of_year;
      gDayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      gDailyLocked = false;
   }
}

void CheckDailyLoss()
{
   if(InpMaxDailyLossPct <= 0 || gDailyLocked || gDayStartBalance <= 0) return;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double lossPct = (gDayStartBalance - equity) / gDayStartBalance * 100.0;
   if(lossPct >= InpMaxDailyLossPct)
   {
      gDailyLocked = true;
      PrintFormat("Chạm giới hạn lỗ ngày %.2f%% -> đóng lệnh và dừng tới ngày mai", lossPct);
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && IsMine()) trade.PositionClose(ticket);
      }
   }
}

datetime GMTNow()
{
   return TimeCurrent() - InpServerGMTOffset * 3600;
}

bool IsTradingTime()
{
   MqlDateTime g; TimeToStruct(GMTNow(), g);
   if(g.day_of_week == 0 || g.day_of_week == 6) return false;
   if(InpCloseFriday && g.day_of_week == 5 && g.hour >= InpFridayCloseGMT - 1) return false;
   if(InpNoMondayEarly && g.day_of_week == 1 && g.hour < InpSessionStartGMT) return false;
   if(InpSessionStartGMT <= InpSessionEndGMT)
      return g.hour >= InpSessionStartGMT && g.hour < InpSessionEndGMT;
   return g.hour >= InpSessionStartGMT || g.hour < InpSessionEndGMT; // phiên qua đêm
}

double CurrentSpreadPips()
{
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk) || gPip <= 0) return 999.0;
   return (tk.ask - tk.bid) / gPip;
}

void ShowPanel()
{
   int trend = TrendDirection();
   string t = (trend == 1) ? "TĂNG" : (trend == -1 ? "GIẢM" : "KHÔNG RÕ");
   Comment(StringFormat(
      "EURUSD Trend Pullback EA\n"
      "Xu hướng %s: %s\n"
      "Spread: %.1f pip | Giờ giao dịch: %s\n"
      "Lệnh hôm nay: %d/%d | Vị thế mở: %d\n"
      "Khoá lỗ ngày: %s\n"
      "Tín hiệu Buy/Sell: %d/%d | Đã vào: %d",
      EnumToString(InpTrendTF), t,
      CurrentSpreadPips(), IsTradingTime() ? "CÓ" : "KHÔNG",
      CountTradesToday(), InpMaxTradesPerDay, CountMyPositions(),
      gDailyLocked ? "CÓ" : "KHÔNG",
      gSignalsBuy, gSignalsSell, gOrdersSent));
}
//+------------------------------------------------------------------+
