//+------------------------------------------------------------------+
//|                                               Larry FX.mq5       |
//|            Complete & Executable Reconstruction of Larry FX EA   |
//|            Martingale Grid Trading Expert Advisor                |
//|            Includes: Trading Engine + Full Statistics Panel      |
//|                      + Boundary Buttons + 5-day P&L table        |
//|            MQL5 port of "Larry FX Full.mq4"                      |
//+------------------------------------------------------------------+
#property copyright "Simple Forex Tools"
#property link      "https://t.me/simpleforextools"
#property version   "1.00"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUTS                                                           |
//+------------------------------------------------------------------+
input bool   InpEnableBuy       = true;      // Enable Buy (BUYSTOP) grid
input bool   InpEnableSell      = true;      // Enable Sell (SELLSTOP) grid
input bool   InpFirstOrder      = true;      // Allow first order
input bool   InpOpenTrend       = false;     // Trend-following placement
input int    InpFirstStep       = 50;        // First order distance (points)
input int    InpMinDistance     = 80;        // Min distance between grid levels
input int    InpStep            = 80;        // Grid step distance
input int    InpMinDistance1    = 30;        // Min distance altitude levels
input int    InpStep1           = 80;        // Grid step altitude levels
input int    InpMaxOrderCount   = 999999;    // Max orders before using alt params (KHÔNG phải giới hạn số lệnh, chỉ đổi khoảng cách - xem InpMaxGridLevels)
input int    InpMaxGridLevels   = 6;         // [MỚI - $3000] Số tầng grid tối đa mỗi hướng - chặn cứng martingale, bản gốc không có giới hạn này
input int    InpStepTrailOrders = 5;         // Pending order trailing step
input double InpMaxLoss         = 150.0;     // [$3000] Ngừng đặt thêm lệnh grid mới khi 1 hướng lỗ quá mức này ($)
input double InpMaxLossCloseAll = 40.0;      // [$3000] Ngưỡng chuyển sang chế độ "chờ grid tự hồi phục" (KHÔNG chỉ là hiển thị - xem giải thích trong CheckExitConditions)
input double InpBaseLot         = 0.01;      // Base lot size
input double InpPlusLot         = 0.0;       // Extra lot per level
input double InpLotMultiplier   = 1.15;      // [$3000] Giảm từ 1.3 -> 1.15 để lot tăng chậm hơn qua các tầng
input int    InpLotDigits       = 2;         // Lot rounding digits
input double InpCloseAll        = 100.0;     // [$3000] Chốt toàn bộ khi tổng lợi nhuận đạt mức này ($, ~3% tài khoản)
input double InpStopProfit      = 30.0;      // Take profit per direction ($)
input double InpStopLoss        = 300.0;     // [$3000] SL THẬT mỗi hướng ($, ~10% tài khoản) - bản gốc để 10,000,000 = tắt SL
input int    InpMagic           = 666888;    // Magic number
input int    InpFontSize        = 10;        // Font size
input color  InpTextColor       = clrLime;   // Text color

//--- Trailing stop settings
input string InpTrailingMode    = "0-off  1-Candle  2-Fractals  >2-pips"; // Trailing mode
input int    InpTrailingStop    = 1;         // Trailing stop mode
input int    InpTrailingStep    = 0;         // Trailing step
input int    InpMinProfit       = 10;        // Minimum profit to trail
input int    InpDelta           = 0;         // Delta offset
input int    InpTrailTF         = 0;         // Trailing timeframe
input int    InpKey             = 0;         // Key (unused)

//--- Time filter
input string InpTimeMode        = "time";    // Time mode
input bool   InpUseTimeFilter   = false;     // Enable time filter
input int    InpStartHour       = 1;         // Start hour
input int    InpEndHour         = 20;        // End hour

//--- Display
input bool   InpShowStatistics  = true;      // Show meeting statistics panel
input bool   InpShowButtons     = true;      // Show boundary buttons

//+------------------------------------------------------------------+
//| GLOBALS                                                          |
//+------------------------------------------------------------------+
CTrade trade;

int    g_StopLevel = 0;
int    g_Slippage  = 3;
int    g_CurMinDist = 30;
int    g_CurStep    = 30;
int    g_Cur1MinDist = 30;
int    g_Cur1Step   = 30;
ENUM_TIMEFRAMES g_TrailTF = PERIOD_CURRENT;
int    g_Step       = 0;
int    g_FirstStep  = 0;
int    g_FractalHandle = INVALID_HANDLE;

//--- Panel positions
int    g_PanelX     = 10;
int    g_PanelY     = 10;
int    g_PanelW     = 360;
int    g_PanelH     = 400;

//--- Order statistics
int    g_BuyCount  = 0;
int    g_SellCount = 0;
int    g_BuyStopCount  = 0;
int    g_SellStopCount = 0;
double g_BuyLots   = 0.0;
double g_SellLots  = 0.0;
double g_BuyProfit = 0.0;
double g_SellProfit= 0.0;
double g_BuyAvgPrice  = 0.0;
double g_SellAvgPrice = 0.0;
double g_BuyMaxOpen   = 0.0;
double g_BuyMinOpen   = 0.0;
double g_SellMaxOpen  = 0.0;
double g_SellMinOpen  = 0.0;
ulong  g_BuyStopTicket = 0;
ulong  g_SellStopTicket = 0;
double g_BuyStopPrice  = 0.0;
double g_SellStopPrice = 0.0;

//--- 5-day P&L statistics (index 0 = today, 1 = yesterday, 2, 3, 4)
double g_DayProfit[5];
double g_DayLots[5];
double g_DayOrderCount[5];
datetime g_DayStart[5];
datetime g_DayEnd[5];

//--- Combined position P&L
double g_TotalPositionPF = 0.0;
double g_MinTotalPF      = 0.0;

//--- Boundary button names (bottom-right corner)
string g_btnCloseAll    = "LFX_CloseAll";
string g_btnCloseCur    = "LFX_CloseCur";
string g_btnCloseLongs  = "LFX_CloseLongs";
string g_btnCloseShorts = "LFX_CloseShorts";
string g_btnCloseProfit = "LFX_CloseProfit";
string g_btnCloseLoss   = "LFX_CloseLoss";

//+------------------------------------------------------------------+
//| Market data helpers                                              |
//+------------------------------------------------------------------+
double CurrentBid() { return SymbolInfoDouble(_Symbol, SYMBOL_BID); }
double CurrentAsk() { return SymbolInfoDouble(_Symbol, SYMBOL_ASK); }

//+------------------------------------------------------------------+
//| Date/time helpers (MQL4 equivalents)                             |
//+------------------------------------------------------------------+
int DayOfWeekOf(datetime t)
{
   MqlDateTime st;
   TimeToStruct(t, st);
   return st.day_of_week;
}

int MonthOf(datetime t)
{
   MqlDateTime st;
   TimeToStruct(t, st);
   return st.mon;
}

int DayOf(datetime t)
{
   MqlDateTime st;
   TimeToStruct(t, st);
   return st.day;
}

int YearOf(datetime t)
{
   MqlDateTime st;
   TimeToStruct(t, st);
   return st.year;
}

int CurrentHour()
{
   MqlDateTime st;
   TimeToStruct(TimeCurrent(), st);
   return st.hour;
}

//+------------------------------------------------------------------+
//| Timeframe conversion helper (minutes -> nearest standard TF)     |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES NormalizeTimeframe(int tf)
{
   if (tf == 0)     return PERIOD_CURRENT;
   if (tf > 43200)  return PERIOD_CURRENT;
   if (tf > 10080)  return PERIOD_MN1;
   if (tf > 1440)   return PERIOD_W1;
   if (tf > 240)    return PERIOD_D1;
   if (tf > 60)     return PERIOD_H4;
   if (tf > 30)     return PERIOD_H1;
   if (tf > 15)     return PERIOD_M30;
   if (tf > 5)      return PERIOD_M15;
   if (tf > 1)      return PERIOD_M5;
   if (tf == 1)     return PERIOD_M1;
   return PERIOD_CURRENT;
}

//+------------------------------------------------------------------+
//| Get the start of a given trading day (0=today, 1=yesterday,      |
//| 2=2 days ago, 3=3 days ago, 4=4 days ago), skipping weekends.   |
//+------------------------------------------------------------------+
datetime TradingDayStart(int daysAgo)
{
   datetime day = TimeCurrent();
   string dstr = TimeToString(day, TIME_DATE);
   day = StringToTime(dstr);

   // Back up to the closest weekday (Monday-Friday)
   while (DayOfWeekOf(day) < 1 || DayOfWeekOf(day) > 5)
      day -= 86400;

   for (int i = 0; i < daysAgo; i++)
   {
      day -= 86400;
      while (DayOfWeekOf(day) < 1 || DayOfWeekOf(day) > 5)
         day -= 86400;
   }
   return day;
}

//+------------------------------------------------------------------+
//| Get the start of the current week (Monday)                       |
//+------------------------------------------------------------------+
datetime CurrentWeekStart()
{
   datetime day = TimeCurrent();
   string dstr = TimeToString(day, TIME_DATE);
   day = StringToTime(dstr);
   while (DayOfWeekOf(day) != 1)
      day -= 86400;
   return day;
}

//+------------------------------------------------------------------+
//| Compute closed P&L and lots from deal history for a period.      |
//| In MQL5 closed trades are represented by exit deals              |
//| (DEAL_ENTRY_OUT / OUT_BY / INOUT).                               |
//+------------------------------------------------------------------+
double CalcRangeProfit(datetime from, datetime to, double &lots)
{
   double profit = 0.0;
   lots = 0.0;

   if (!HistorySelect(from, to))
      return 0.0;

   for (int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if (ticket == 0) continue;
      if (HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic) continue;

      long dtype = HistoryDealGetInteger(ticket, DEAL_TYPE);
      if (dtype != DEAL_TYPE_BUY && dtype != DEAL_TYPE_SELL) continue;

      long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if (entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY && entry != DEAL_ENTRY_INOUT)
         continue;

      datetime ctime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if (ctime >= from && ctime < to)
      {
         profit += HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                   HistoryDealGetDouble(ticket, DEAL_SWAP) +
                   HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         lots += HistoryDealGetDouble(ticket, DEAL_VOLUME);
      }
   }
   return profit;
}

//+------------------------------------------------------------------+
//| Initialize                                                        |
//+------------------------------------------------------------------+
int OnInit()
{
   g_TrailTF   = NormalizeTimeframe(InpTrailTF);
   g_Step      = InpStep;
   g_FirstStep = InpFirstStep;

   if (_Digits == 5 || _Digits == 3)
      g_Slippage = 30;

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(g_Slippage);

   // This grid EA needs independent buy/sell positions (hedging mode)
   if (AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      Alert("Warning: account is not in hedging mode. This grid EA requires a hedging account.");

   Comment("");

   // Determine stop level
   g_StopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);

   if (g_Step < g_StopLevel)
   {
      Alert("Step < STOPLEVEL ", g_StopLevel);
      g_Step = g_StopLevel;
   }
   if (g_FirstStep < g_StopLevel)
   {
      Alert("FirstStep < STOPLEVEL ", g_StopLevel);
      g_FirstStep = g_StopLevel;
   }

   // Fractals indicator handle for trailing mode 2
   g_FractalHandle = iFractals(_Symbol, g_TrailTF);
   if (g_FractalHandle == INVALID_HANDLE)
      Print("Failed to create Fractals handle. Err ", GetLastError());

   // Create display labels
   if (InpShowStatistics)
   {
      CreateLabel("Balance", 5, 15);
      CreateLabel("Equity", 5, 15 + 2*InpFontSize);
      CreateLabel("FreeMargin", 5, 15 + 4*InpFontSize);
      CreateLabel("ProfitB", 5, 15 + 6*InpFontSize);
      CreateLabel("ProfitS", 5, 15 + 8*InpFontSize);
      CreateLabel("Profit", 5, 15 + 10*InpFontSize);

      CreatePanel();
      if (InpShowButtons)
         CreateBoundaryButtons();
   }

   EventSetMillisecondTimer(300);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Create a simple label object                                     |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y)
{
   if (ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   }
}

//+------------------------------------------------------------------+
//| Deinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   if (g_FractalHandle != INVALID_HANDLE)
      IndicatorRelease(g_FractalHandle);
   ObjectsDeleteAll(0, -1);
}

//+------------------------------------------------------------------+
//| Timer - update display labels                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   if (InpShowStatistics)
      UpdateDisplay();
}

//+------------------------------------------------------------------+
//| Main tick handler                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- 1. Collect order statistics
   CollectOrderStats();

   //--- 2. Determine active grid parameters based on order count
   if (g_BuyCount <= InpMaxOrderCount)
   {
      g_CurMinDist = InpMinDistance;
      g_CurStep    = g_Step;
   }
   else
   {
      g_CurMinDist = InpMinDistance1;
      g_CurStep    = InpStep1;
   }

   if (g_SellCount <= InpMaxOrderCount)
   {
      g_Cur1MinDist = InpMinDistance;
      g_Cur1Step    = g_Step;
   }
   else
   {
      g_Cur1MinDist = InpMinDistance1;
      g_Cur1Step    = InpStep1;
   }

   //--- 3. Draw average price markers
   DrawAverageMarkers();

   //--- 4. Trailing stop for open positions
   if (InpTrailingStop)
      TrailingStop();

   //--- 5. Check profit/loss exit conditions
   CheckExitConditions();

   //--- 6. Place buy grid
   if (g_BuyStopCount == 0 && InpEnableBuy)
      PlaceBuyGrid();

   //--- 7. Place sell grid
   if (g_SellStopCount == 0 && InpEnableSell)
      PlaceSellGrid();

   //--- 8. Trail pending orders
   TrailPendingOrders();

   //--- 9. Update display
   if (InpShowStatistics)
      UpdateDisplay();
}

//+------------------------------------------------------------------+
//| Collect statistics for all our positions and pending orders      |
//+------------------------------------------------------------------+
void CollectOrderStats()
{
   g_BuyCount = 0;
   g_SellCount = 0;
   g_BuyStopCount = 0;
   g_SellStopCount = 0;
   g_BuyLots = 0.0;
   g_SellLots = 0.0;
   g_BuyProfit = 0.0;
   g_SellProfit = 0.0;
   g_BuyAvgPrice = 0.0;
   g_SellAvgPrice = 0.0;
   g_BuyMaxOpen = 0.0;
   g_BuyMinOpen = 0.0;
   g_SellMaxOpen = 0.0;
   g_SellMinOpen = 0.0;
   g_BuyStopTicket = 0;
   g_SellStopTicket = 0;
   g_BuyStopPrice = 0.0;
   g_SellStopPrice = 0.0;
   double buyCost = 0.0;
   double sellCost = 0.0;

   // Open positions (market orders in MQL4 terms)
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      long type = PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double lots = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

      if (type == POSITION_TYPE_BUY)
      {
         g_BuyCount++;
         g_BuyLots += lots;
         buyCost += open * lots;
         g_BuyProfit += profit;
         if (g_BuyMaxOpen == 0 || open > g_BuyMaxOpen) g_BuyMaxOpen = open;
         if (g_BuyMinOpen == 0 || open < g_BuyMinOpen) g_BuyMinOpen = open;
      }
      else if (type == POSITION_TYPE_SELL)
      {
         g_SellCount++;
         g_SellLots += lots;
         sellCost += open * lots;
         g_SellProfit += profit;
         if (g_SellMaxOpen == 0 || open > g_SellMaxOpen) g_SellMaxOpen = open;
         if (g_SellMinOpen == 0 || open < g_SellMinOpen) g_SellMinOpen = open;
      }
   }

   // Pending orders
   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if (ticket == 0) continue;
      if (OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if (OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;

      long type = OrderGetInteger(ORDER_TYPE);
      double open = OrderGetDouble(ORDER_PRICE_OPEN);

      if (type == ORDER_TYPE_BUY_STOP)
      {
         g_BuyStopCount++;
         if (g_BuyStopPrice == 0 || open < g_BuyStopPrice)
            g_BuyStopPrice = open;
         g_BuyStopTicket = ticket;
      }
      else if (type == ORDER_TYPE_SELL_STOP)
      {
         g_SellStopCount++;
         if (g_SellStopPrice == 0 || open > g_SellStopPrice)
            g_SellStopPrice = open;
         g_SellStopTicket = ticket;
      }
   }

   if (g_BuyLots > 0) g_BuyAvgPrice = buyCost / g_BuyLots;
   if (g_SellLots > 0) g_SellAvgPrice = sellCost / g_SellLots;

   // Total position P&L
   g_TotalPositionPF = g_BuyProfit + g_SellProfit;
   if (g_TotalPositionPF < g_MinTotalPF)
      g_MinTotalPF = g_TotalPositionPF;
}

//+------------------------------------------------------------------+
//| Draw average price markers on chart                              |
//+------------------------------------------------------------------+
void DrawAverageMarkers()
{
   ObjectDelete(0, "SLb");
   ObjectDelete(0, "SLs");

   datetime t0 = iTime(_Symbol, PERIOD_CURRENT, 0);

   if (g_BuyCount > 0)
   {
      ObjectCreate(0, "SLb", OBJ_ARROW, 0, t0, g_BuyAvgPrice);
      ObjectSetInteger(0, "SLb", OBJPROP_ARROWCODE, 6);
      ObjectSetInteger(0, "SLb", OBJPROP_COLOR, clrRed);
   }
   if (g_SellCount > 0)
   {
      ObjectCreate(0, "SLs", OBJ_ARROW, 0, t0, g_SellAvgPrice);
      ObjectSetInteger(0, "SLs", OBJPROP_ARROWCODE, 6);
      ObjectSetInteger(0, "SLs", OBJPROP_COLOR, clrBlue);
   }
}

//+------------------------------------------------------------------+
//| Trailing stop using selected mode                                |
//+------------------------------------------------------------------+
void TrailingStop()
{
   double bid = CurrentBid();
   double ask = CurrentAsk();

   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      long type = PositionGetInteger(POSITION_TYPE);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double newSL = sl;

      if (type == POSITION_TYPE_BUY)
      {
         double trail = GetTrailingLevel(1, bid, InpTrailingStop);
         double basis = g_BuyAvgPrice;
         if (basis <= 0) basis = open;

         if (trail >= basis + InpMinProfit * _Point)
         {
            if (trail > sl + InpTrailingStep * _Point)
            {
               if ((bid - trail) / _Point > g_StopLevel)
                  newSL = trail;
            }
         }
         if (newSL > sl && newSL > 0)
         {
            if (!trade.PositionModify(ticket, NormalizeDouble(newSL, _Digits), tp))
               Print("TrailingStop Modify Buy SL ", sl, "->", newSL, " Err ", trade.ResultRetcode());
         }
      }
      else if (type == POSITION_TYPE_SELL)
      {
         double trail = GetTrailingLevel(-1, ask, InpTrailingStop);
         double basis = g_SellAvgPrice;
         if (basis <= 0) basis = open;

         if (trail <= basis - InpMinProfit * _Point)
         {
            if (trail < sl - InpTrailingStep * _Point || sl == 0)
            {
               if ((trail - ask) / _Point > g_StopLevel)
                  newSL = trail;
            }
         }
         if (newSL < sl || (sl == 0 && newSL != 0))
         {
            if (!trade.PositionModify(ticket, NormalizeDouble(newSL, _Digits), tp))
               Print("TrailingStop Modify Sell SL ", sl, "->", newSL, " Err ", trade.ResultRetcode());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get fractal value at a shift (0 when there is no fractal there)  |
//+------------------------------------------------------------------+
double FractalAt(int buffer, int shift)
{
   double buf[1];
   if (g_FractalHandle == INVALID_HANDLE) return 0.0;
   if (CopyBuffer(g_FractalHandle, buffer, shift, 1, buf) != 1) return 0.0;
   if (buf[0] == EMPTY_VALUE) return 0.0;
   return buf[0];
}

//+------------------------------------------------------------------+
//| Compute trailing level based on mode                             |
//+------------------------------------------------------------------+
double GetTrailingLevel(int dir, double price, int mode)
{
   double result = 0.0;

   if (mode <= 2)
   {
      if (mode == 2) // Fractals
      {
         if (dir == 1)
         {
            for (int s = 1; s < 100; s++)
            {
               double fr = FractalAt(UPPER_LINE, s);
               if (fr != 0)
               {
                  result = fr - InpDelta * _Point;
                  if (price - g_StopLevel * _Point > result)
                     break;
                  result = 0;
               }
            }
         }
         else
         {
            for (int s = 1; s < 100; s++)
            {
               double fr = FractalAt(LOWER_LINE, s);
               if (fr != 0)
               {
                  result = fr + InpDelta * _Point;
                  if (g_StopLevel * _Point + price < result)
                     break;
                  result = 0;
               }
            }
         }
      }
      else if (mode == 1) // Candle
      {
         if (dir == 1)
         {
            for (int s = 1; s < 500; s++)
            {
               double loRaw = iLow(_Symbol, g_TrailTF, s) - InpDelta * _Point;
               double lo = NormalizeDouble(loRaw, _Digits);
               result = lo;              // set before break (matches original)
               if (loRaw != 0)
               {
                  if (price - g_StopLevel * _Point > loRaw)
                     break;
                  result = 0;
               }
            }
         }
         else
         {
            for (int s = 1; s < 500; s++)
            {
               double hiRaw = iHigh(_Symbol, g_TrailTF, s) + InpDelta * _Point;
               double hi = NormalizeDouble(hiRaw, _Digits);
               result = hi;              // set before break (matches original)
               if (hiRaw != 0)
               {
                  if (g_StopLevel * _Point + price < hiRaw)
                     break;
                  result = 0;
               }
            }
         }
      }
   }
   else // Pip based
   {
      result = (dir == 1) ? price - mode * _Point : mode * _Point + price;
   }

   return result;
}

//+------------------------------------------------------------------+
//| Check profit/loss exit conditions                                |
//+------------------------------------------------------------------+
void CheckExitConditions()
{
   double totalProfit = g_BuyProfit + g_SellProfit;

   // [ĐÍNH CHÍNH] Dù tên input là "Warning icon threshold (display only)",
   // giá trị này KHÔNG chỉ để hiển thị - nó quyết định EA có đang ở chế độ
   // "chốt lời nhanh từng hướng" (lossIcon=false, đóng khi 1 hướng đạt
   // +InpStopProfit) hay chuyển sang "chờ grid tự hồi phục" (lossIcon=true,
   // chỉ đóng hết khi TỔNG lời đạt InpCloseAll). Với giá trị gốc 5.0, chỉ
   // cần 1 hướng lỗ nổi quá $5 là chuyển hẳn sang chế độ chờ hồi phục và
   // gần như không bao giờ chốt lời từng phần nữa - đây là một nguyên nhân
   // khiến EA "cháy nhanh". Đã nâng lên 40.0 (InpMaxLossCloseAll) để chế độ
   // chốt lời nhanh còn hoạt động qua các đợt lỗ nổi nhỏ bình thường.
   bool lossIcon = (g_BuyProfit <= -InpMaxLossCloseAll ||
                    g_SellProfit <= -InpMaxLossCloseAll);

   if (lossIcon)
   {
      // Loss warning icon shown (both directions combined). Close all only
      // when the total profit reaches the large CloseAll target.
      if (totalProfit >= InpCloseAll)
      {
         Print("CloseAll ", DoubleToString(totalProfit, 2));
         CloseAllOrders(0);
         return;
      }
   }
   else
   {
      // Profit icon shown. Close each direction when it reaches StopProfit.
      if (g_BuyProfit >= InpStopProfit)
      {
         Print("Buy Profit ", DoubleToString(g_BuyProfit, 2));
         CloseAllOrders(1);
         return;
      }
      if (g_SellProfit >= InpStopProfit)
      {
         Print("Sell Profit ", DoubleToString(g_SellProfit, 2));
         CloseAllOrders(-1);
         return;
      }
   }

   // Directional stop loss (defaults are so large they are effectively never hit)
   if (g_BuyProfit <= -InpStopLoss)
   {
      Print("Buy Loss ", DoubleToString(g_BuyProfit, 2));
      CloseAllOrders(1);
      return;
   }
   if (g_SellProfit <= -InpStopLoss)
   {
      Print("Sell Loss ", DoubleToString(g_SellProfit, 2));
      CloseAllOrders(-1);
      return;
   }
}

//+------------------------------------------------------------------+
//| Margin required for 1 lot (MQL4 MODE_MARGINREQUIRED equivalent)  |
//+------------------------------------------------------------------+
double MarginRequiredPerLot(ENUM_ORDER_TYPE type, double price)
{
   double margin = 0.0;
   if (!OrderCalcMargin(type, _Symbol, 1.0, price, margin))
      return 0.0;
   return margin;
}

//+------------------------------------------------------------------+
//| Place buy (BUYSTOP) grid                                         |
//+------------------------------------------------------------------+
void PlaceBuyGrid()
{
   if (!InpEnableBuy) return;
   // [MỚI - $3000] Chặn cứng số tầng grid mỗi hướng, EA gốc không có giới hạn
   // này (InpMaxOrderCount chỉ đổi khoảng cách, không chặn số lệnh).
   if (g_BuyCount >= InpMaxGridLevels) return;
   // Original negates InpMaxLoss to -100000 and blocks only when the loss
   // exceeds that threshold (v90 > -100000). So placement is allowed unless
   // buy profit is a large loss (<= -InpMaxLoss).
   if (g_BuyProfit <= -InpMaxLoss) return;

   double ask = CurrentAsk();
   double price;
   if (g_BuyCount > 0)
   {
      price = ask + g_CurMinDist * _Point;
      double ref = g_BuyMinOpen - g_CurStep * _Point;
      if (price < ref)
         price = ask + g_CurStep * _Point;
   }
   else
   {
      price = ask + g_FirstStep * _Point;
   }

   // Grid placement conditions
   bool allow = false;
   if (g_BuyCount == 0)
      allow = true;
   else if (g_BuyMaxOpen != 0 && price >= g_BuyMaxOpen + g_CurStep * _Point && InpOpenTrend)
      allow = true;
   else if (g_BuyMinOpen != 0 && price <= g_BuyMinOpen - g_CurStep * _Point)
      allow = true;

   if (!allow) return;

   // Determine lot size
   double lots;
   if (g_BuyCount > 0)
      lots = NormalizeDouble(InpBaseLot * MathPow(InpLotMultiplier, g_BuyCount) + g_BuyCount * InpPlusLot, InpLotDigits);
   else
      lots = InpBaseLot;

   // Check margin
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginReq = MarginRequiredPerLot(ORDER_TYPE_BUY, ask);
   if (marginReq <= 0) return;
   double maxLots = freeMargin / marginReq;

   // [SỬA LỖI] Bản gốc dùng "(lots < maxLots && g_BuyCount > 0) || InpFirstOrder".
   // Vì InpFirstOrder mặc định = true, điều kiện này LUÔN đúng bất kể margin,
   // tức kiểm tra margin bị vô hiệu hoá hoàn toàn cho MỌI lệnh, không chỉ
   // lệnh đầu tiên. Sửa lại: chỉ bỏ qua kiểm tra margin cho đúng lệnh đầu
   // tiên (g_BuyCount == 0), các lệnh martingale sau vẫn phải qua kiểm tra.
   if ((g_BuyCount == 0) || (lots < maxLots))
   {
      // Time filter: only place when inside allowed window (if enabled)
      if (TimeFilterAllowed())
      {
         if (!trade.BuyStop(lots, NormalizeDouble(price, _Digits), _Symbol, 0, 0,
                            ORDER_TIME_GTC, 0, "LarryFX BUY"))
            Print("OrderSend BUYSTOP Error ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
//| Place sell (SELLSTOP) grid                                       |
//+------------------------------------------------------------------+
void PlaceSellGrid()
{
   if (!InpEnableSell) return;
   // [MỚI - $3000] Chặn cứng số tầng grid mỗi hướng, EA gốc không có giới hạn
   // này (InpMaxOrderCount chỉ đổi khoảng cách, không chặn số lệnh).
   if (g_SellCount >= InpMaxGridLevels) return;
   // Original negates InpMaxLoss to -100000 and blocks only when the loss
   // exceeds that threshold (v91 > -100000). So placement is allowed unless
   // sell profit is a large loss (<= -InpMaxLoss).
   if (g_SellProfit <= -InpMaxLoss) return;

   double bid = CurrentBid();
   double price;
   if (g_SellCount > 0)
   {
      price = bid - g_Cur1MinDist * _Point;
      double ref = g_SellMaxOpen + g_Cur1Step * _Point;
      if (price < ref)
         price = bid - g_Cur1Step * _Point;
   }
   else
   {
      price = bid - g_FirstStep * _Point;
   }

   // Grid placement conditions
   bool allow = false;
   if (g_SellCount == 0)
      allow = true;
   else if (g_SellMinOpen != 0 && price <= g_SellMinOpen - g_Cur1Step * _Point && InpOpenTrend)
      allow = true;
   else if (g_SellMaxOpen != 0 && price >= g_SellMaxOpen + g_Cur1Step * _Point)
      allow = true;

   if (!allow) return;

   // Determine lot size
   double lots;
   if (g_SellCount > 0)
      lots = NormalizeDouble(InpBaseLot * MathPow(InpLotMultiplier, g_SellCount) + g_SellCount * InpPlusLot, InpLotDigits);
   else
      lots = InpBaseLot;

   // Check margin
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginReq = MarginRequiredPerLot(ORDER_TYPE_SELL, bid);
   if (marginReq <= 0) return;
   double maxLots = freeMargin / marginReq;

   // [SỬA LỖI] Giống PlaceBuyGrid: chỉ bỏ qua kiểm tra margin cho lệnh đầu
   // tiên (g_SellCount == 0), không để InpFirstOrder vô hiệu hoá margin
   // check cho toàn bộ chuỗi martingale.
   if ((g_SellCount == 0) || (lots < maxLots))
   {
      // Time filter: only place when inside allowed window (if enabled)
      if (TimeFilterAllowed())
      {
         if (!trade.SellStop(lots, NormalizeDouble(price, _Digits), _Symbol, 0, 0,
                             ORDER_TIME_GTC, 0, "LarryFX SELL"))
            Print("OrderSend SELLSTOP Error ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
//| Time filter check                                                |
//+------------------------------------------------------------------+
bool TimeFilterAllowed()
{
   if (!InpUseTimeFilter) return true;
   int hour = CurrentHour();
   if (InpStartHour < InpEndHour)
      return (hour >= InpStartHour && hour < InpEndHour);
   else
      return (hour >= InpStartHour || hour < InpEndHour); // overnight window
}

//+------------------------------------------------------------------+
//| Trail pending orders (move open price)                           |
//+------------------------------------------------------------------+
void TrailPendingOrders()
{
   // Buy stop trailing
   if (g_BuyStopPrice != 0 && InpEnableBuy)
   {
      double price = (g_BuyCount > 0) ? g_CurMinDist * _Point : g_FirstStep * _Point;
      price = price + CurrentAsk();
      double ref = g_BuyStopPrice - InpStepTrailOrders * _Point;

      if (ref > price)
      {
         // Original: outer limit based on buys MIN open (v78 - step)
         double limit = g_BuyMinOpen - g_CurStep * _Point;
         if (price <= limit || g_BuyMinOpen == 0 || InpOpenTrend)
         {
            if (g_BuyCount == 0 ||
                price >= g_BuyMaxOpen + g_CurStep * _Point ||
                price <= g_BuyMinOpen - g_CurStep * _Point)
            {
               if (trade.OrderModify(g_BuyStopTicket, NormalizeDouble(price, _Digits), 0, 0, ORDER_TIME_GTC, 0))
                  Print("Order Buy Modify OOP ", g_BuyStopPrice, "->", price);
               else
                  Print("Error Order Modify Buy OOP ", g_BuyStopPrice, "->", price, " Err ", trade.ResultRetcode());
            }
         }
      }
   }

   // Sell stop trailing
   if (g_SellStopPrice != 0 && InpEnableSell)
   {
      double price = (g_SellCount > 0) ? g_Cur1MinDist * _Point : g_FirstStep * _Point;
      price = CurrentBid() - price;
      double ref = g_SellStopPrice + InpStepTrailOrders * _Point;

      if (ref < price)
      {
         // Original: outer limit based on sells MAX open (v77 + step)
         double limit = g_SellMaxOpen + g_Cur1Step * _Point;
         if (price >= limit || g_SellMaxOpen == 0 || InpOpenTrend)
         {
            if (g_SellCount == 0 ||
                price <= g_SellMinOpen - g_Cur1Step * _Point ||
                price >= g_SellMaxOpen + g_Cur1Step * _Point)
            {
               if (trade.OrderModify(g_SellStopTicket, NormalizeDouble(price, _Digits), 0, 0, ORDER_TIME_GTC, 0))
                  Print("Order Sell Modify OOP ", g_SellStopPrice, "->", price);
               else
                  Print("Error Order Modify Sell OOP ", g_SellStopPrice, "->", price, " Err ", trade.ResultRetcode());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close orders. dir: 1=buy, -1=sell, 0=all                        |
//+------------------------------------------------------------------+
void CloseAllOrders(int dir)
{
   for (int retry = 0; retry < 10; retry++)
   {
      // Close open positions
      for (int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if (ticket == 0) continue;
         if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if (PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

         long type = PositionGetInteger(POSITION_TYPE);
         bool doClose = false;
         if (type == POSITION_TYPE_BUY && (dir == 1 || dir == 0)) doClose = true;
         if (type == POSITION_TYPE_SELL && (dir == -1 || dir == 0)) doClose = true;
         if (!doClose) continue;

         if (!trade.PositionClose(ticket, g_Slippage))
            Print("PositionClose Error ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
      }

      // Delete pending orders
      for (int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if (ticket == 0) continue;
         if (OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
         if (OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;

         long type = OrderGetInteger(ORDER_TYPE);
         bool doClose = false;
         if (type == ORDER_TYPE_BUY_STOP && (dir == 1 || dir == 0)) doClose = true;
         if (type == ORDER_TYPE_SELL_STOP && (dir == -1 || dir == 0)) doClose = true;
         if (!doClose) continue;

         if (!trade.OrderDelete(ticket))
            Print("OrderDelete Error ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
      }

      // Check remaining orders
      int remaining = 0;
      for (int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if (ticket == 0) continue;
         if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if (PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
         long type = PositionGetInteger(POSITION_TYPE);
         if (type == POSITION_TYPE_BUY && (dir == 1 || dir == 0)) remaining++;
         if (type == POSITION_TYPE_SELL && (dir == -1 || dir == 0)) remaining++;
      }
      for (int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if (ticket == 0) continue;
         if (OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
         if (OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
         long type = OrderGetInteger(ORDER_TYPE);
         if (type == ORDER_TYPE_BUY_STOP && (dir == 1 || dir == 0)) remaining++;
         if (type == ORDER_TYPE_SELL_STOP && (dir == -1 || dir == 0)) remaining++;
      }

      if (remaining == 0) break;
      Sleep(1000);
   }
}

//+==================================================================+
//|  PANEL & STATISTICS LAYER                                        |
//+==================================================================+

//+------------------------------------------------------------------+
//| Create the main statistics panel (rectangle + labels)            |
//+------------------------------------------------------------------+
void CreatePanel()
{
   // Main panel rectangle (dark background, top-left corner)
   if (ObjectFind(0, "LFX_Panel") < 0)
   {
      ObjectCreate(0, "LFX_Panel", OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "LFX_Panel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "LFX_Panel", OBJPROP_XDISTANCE, g_PanelX);
      ObjectSetInteger(0, "LFX_Panel", OBJPROP_YDISTANCE, g_PanelY);
      ObjectSetInteger(0, "LFX_Panel", OBJPROP_XSIZE, g_PanelW);
      ObjectSetInteger(0, "LFX_Panel", OBJPROP_YSIZE, g_PanelH);
      ObjectSetInteger(0, "LFX_Panel", OBJPROP_BGCOLOR, C'25,25,25');
      ObjectSetInteger(0, "LFX_Panel", OBJPROP_COLOR, clrDimGray);
      ObjectSetInteger(0, "LFX_Panel", OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, "LFX_Panel", OBJPROP_BACK, false);
      ObjectSetInteger(0, "LFX_Panel", OBJPROP_SELECTABLE, false);
   }

   // Panel title
   PanelLabel("LFX_Title", "LARRY FX English version", g_PanelX + 10, g_PanelY + 6, 11, clrYellow);

   // Separator line between the account section and the P&L table
   if (ObjectFind(0, "LFX_Sep") < 0)
   {
      ObjectCreate(0, "LFX_Sep", OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "LFX_Sep", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "LFX_Sep", OBJPROP_XDISTANCE, g_PanelX + 10);
      ObjectSetInteger(0, "LFX_Sep", OBJPROP_YDISTANCE, g_PanelY + 138);
      ObjectSetInteger(0, "LFX_Sep", OBJPROP_XSIZE, g_PanelW - 20);
      ObjectSetInteger(0, "LFX_Sep", OBJPROP_YSIZE, 1);
      ObjectSetInteger(0, "LFX_Sep", OBJPROP_BGCOLOR, clrSilver);
      ObjectSetInteger(0, "LFX_Sep", OBJPROP_COLOR, clrSilver);
      ObjectSetInteger(0, "LFX_Sep", OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, "LFX_Sep", OBJPROP_BACK, false);
      ObjectSetInteger(0, "LFX_Sep", OBJPROP_SELECTABLE, false);
   }

   // Table header
   PanelLabel("LFX_HdrTime", "Time",       g_PanelX + 10,  g_PanelY + 146, 10, clrLimeGreen);
   PanelLabel("LFX_HdrLots", "Lots",       g_PanelX + 100, g_PanelY + 146, 10, clrLimeGreen);
   PanelLabel("LFX_HdrMon",  "Money",      g_PanelX + 180, g_PanelY + 146, 10, clrLimeGreen);
   PanelLabel("LFX_HdrPct",  "Percentage", g_PanelX + 265, g_PanelY + 146, 10, clrLimeGreen);
}

//+------------------------------------------------------------------+
//| Draw one row of the P&L table (name / lots / money / percentage) |
//+------------------------------------------------------------------+
void PanelRow(int idx, string name, double lots, double money, double balance)
{
   int y = g_PanelY + 168 + 19 * idx;
   color c = (money < 0) ? clrRed : clrLimeGreen;
   double pct = (balance != 0) ? money / balance * 100.0 : 0.0;
   string sidx = IntegerToString(idx);

   PanelLabel("LFX_TN" + sidx, name,                          g_PanelX + 10,  y, 9, clrWhite);
   PanelLabel("LFX_TL" + sidx, DoubleToString(lots, 2),       g_PanelX + 100, y, 9, c);
   PanelLabel("LFX_TM" + sidx, DoubleToString(money, 2),      g_PanelX + 180, y, 9, c);
   PanelLabel("LFX_TP" + sidx, DoubleToString(pct, 2) + "%",  g_PanelX + 265, y, 9, c);
}

//+------------------------------------------------------------------+
//| Helper to create a panel label                                   |
//+------------------------------------------------------------------+
void PanelLabel(string name, string text, int x, int y, int size, color clr)
{
   if (ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| Update panel text values                                         |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   // --- Account info section -------------------------------------
   PanelLabel("LFX_Spread",
              "Spread:" + DoubleToString((CurrentAsk() - CurrentBid()) / _Point, 0) +
              "   Lever:1:" + IntegerToString(AccountInfoInteger(ACCOUNT_LEVERAGE)),
              g_PanelX + 10, g_PanelY + 32, 9, clrWhite);
   PanelLabel("LFX_Account", "Accountnumber:" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)),
              g_PanelX + 10, g_PanelY + 54, 9, clrWhite);

   // --- Long / Short summary --------------------------------------
   color cB = (g_BuyProfit  < 0) ? clrRed : clrLimeGreen;
   color cS = (g_SellProfit < 0) ? clrRed : clrLimeGreen;
   PanelLabel("LFX_LongCnt",  "Long Count: "   + IntegerToString(g_BuyCount),    g_PanelX + 10,  g_PanelY + 76, 9, clrSilver);
   PanelLabel("LFX_LongVol",  "Long Volume: "  + DoubleToString(g_BuyLots, 2),   g_PanelX + 125, g_PanelY + 76, 9, clrSilver);
   PanelLabel("LFX_LongPL",   "Long P/L: "     + DoubleToString(g_BuyProfit, 2), g_PanelX + 245, g_PanelY + 76, 9, cB);
   PanelLabel("LFX_ShortCnt", "Short Count: "  + IntegerToString(g_SellCount),   g_PanelX + 10,  g_PanelY + 96, 9, clrSilver);
   PanelLabel("LFX_ShortVol", "Short Volume: " + DoubleToString(g_SellLots, 2),  g_PanelX + 125, g_PanelY + 96, 9, clrSilver);
   PanelLabel("LFX_ShortPL",  "Short P/L: "    + DoubleToString(g_SellProfit, 2),g_PanelX + 245, g_PanelY + 96, 9, cS);

   // --- Current floating P/L and max floating loss ----------------
   color cCur = (g_TotalPositionPF < 0) ? clrRed : clrLimeGreen;
   PanelLabel("LFX_CurPL", "Current P/L: " + DoubleToString(g_TotalPositionPF, 2),
              g_PanelX + 10, g_PanelY + 116, 9, cCur);
   PanelLabel("LFX_MaxFL", "Max Floating Loss: " + DoubleToString(g_MinTotalPF, 2),
              g_PanelX + 165, g_PanelY + 116, 9, (g_MinTotalPF < 0) ? clrRed : clrSilver);

   // --- P&L table --------------------------------------------------
   // History-based statistics are recomputed only when the deal history
   // changes or at most every 5 seconds (the panel itself is refreshed
   // every 300 ms by the timer).
   static double wLots = 0, mLots = 0, qLots = 0, yLots = 0, aLots = 0;
   static double wPF = 0, mPF = 0, qPF = 0, yPF = 0, aPF = 0;
   static int      lastHistTotal = -1;
   static datetime lastHistCalc  = 0;

   datetime now = TimeCurrent();
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   int histTotal = -1;
   if (HistorySelect(0, now + 86400))
      histTotal = HistoryDealsTotal();

   if (histTotal != lastHistTotal || now - lastHistCalc >= 5)
   {
      lastHistTotal = histTotal;
      lastHistCalc  = now;

      ComputeDayStats();
      wPF = CalcRangeProfit(CurrentWeekStart(),    now + 86400, wLots);
      mPF = CalcRangeProfit(CurrentMonthStart(),   now + 86400, mLots);
      qPF = CalcRangeProfit(CurrentQuarterStart(), now + 86400, qLots);
      yPF = CalcRangeProfit(CurrentYearStart(),    now + 86400, yLots);
      aPF = CalcRangeProfit(0,                     now + 86400, aLots);
   }

   // Row 0: floating P/L of open positions, Row 1: today's closed P/L
   PanelRow(0, "Current Profit", g_BuyLots + g_SellLots, g_TotalPositionPF, balance);
   PanelRow(1, "Day Profit",     g_DayLots[0],           g_DayProfit[0],    balance);

   // Rows 2-5: previous 4 trading days, labelled like "8.3"
   for (int i = 1; i < 5; i++)
   {
      string dname = IntegerToString(MonthOf(g_DayStart[i])) + "." +
                     IntegerToString(DayOf(g_DayStart[i]));
      PanelRow(1 + i, dname, g_DayLots[i], g_DayProfit[i], balance);
   }

   // Rows 6-10: aggregated periods
   PanelRow(6,  "Week Profit",    wLots, wPF, balance);
   PanelRow(7,  "Month Profit",   mLots, mPF, balance);
   PanelRow(8,  "Quarter Profit", qLots, qPF, balance);
   PanelRow(9,  "Year Profit",    yLots, yPF, balance);
   PanelRow(10, "Whole Profit",   aLots, aPF, balance);
}

//+------------------------------------------------------------------+
//| Start of the current month / quarter / year                      |
//+------------------------------------------------------------------+
datetime CurrentMonthStart()
{
   datetime now = TimeCurrent();
   return StringToTime(IntegerToString(YearOf(now)) + "." +
                       IntegerToString(MonthOf(now)) + ".01");
}

datetime CurrentQuarterStart()
{
   datetime now = TimeCurrent();
   int qm = ((MonthOf(now) - 1) / 3) * 3 + 1;
   return StringToTime(IntegerToString(YearOf(now)) + "." +
                       IntegerToString(qm) + ".01");
}

datetime CurrentYearStart()
{
   return StringToTime(IntegerToString(YearOf(TimeCurrent())) + ".01.01");
}

//+------------------------------------------------------------------+
//| Compute per-day P&L, lots and order counts (from deal history)   |
//+------------------------------------------------------------------+
void ComputeDayStats()
{
   // Trading day boundaries (skip weekends)
   datetime now = TimeCurrent();
   for (int i = 0; i < 5; i++)
   {
      g_DayStart[i] = TradingDayStart(i);
      g_DayEnd[i]   = (i == 0) ? now + 86400 : g_DayStart[i-1];
   }

   // Reset
   for (int i = 0; i < 5; i++)
   {
      g_DayProfit[i] = 0.0;
      g_DayLots[i]   = 0.0;
      g_DayOrderCount[i] = 0;
   }

   // Scan closed deal history
   if (!HistorySelect(g_DayStart[4], now + 86400))
      return;

   for (int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if (ticket == 0) continue;
      if (HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic) continue;

      long dtype = HistoryDealGetInteger(ticket, DEAL_TYPE);
      if (dtype != DEAL_TYPE_BUY && dtype != DEAL_TYPE_SELL) continue;

      long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if (entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY && entry != DEAL_ENTRY_INOUT)
         continue;

      datetime ctime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      for (int d = 0; d < 5; d++)
      {
         if (ctime >= g_DayStart[d] && ctime < g_DayEnd[d])
         {
            g_DayProfit[d] += HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                              HistoryDealGetDouble(ticket, DEAL_SWAP) +
                              HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            g_DayLots[d]   += HistoryDealGetDouble(ticket, DEAL_VOLUME);
            g_DayOrderCount[d]++;
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Create the 6 boundary buttons, anchored to the BOTTOM-RIGHT      |
//| corner of the chart (corner 3). Each button shows its own text   |
//| label INSIDE the button (no separate external labels). The       |
//| positions are kept well within the chart bounds so that no       |
//| button goes off-screen.                                          |
//+------------------------------------------------------------------+
void CreateBoundaryButtons()
{
   int bx = 5;    // X distance from the right edge (corner 3)
   int by = 5;    // Y distance from the bottom edge (corner 3)
   int bw = 160;
   int bh = 26;
   int gap = 30;   // vertical spacing between buttons

   CreateButton(g_btnCloseAll,    "Close All",     bx+bw, by + 6*gap, bw, bh, clrRed);
   CreateButton(g_btnCloseCur,    "Close current", bx+bw, by + 5*gap, bw, bh, clrDarkGray);
   CreateButton(g_btnCloseLongs,  "Close Longs",   bx+bw, by + 4*gap, bw, bh, clrGreen);
   CreateButton(g_btnCloseShorts, "Close Shorts",  bx+bw, by + 3*gap, bw, bh, clrBlue);
   CreateButton(g_btnCloseProfit, "Close Profits", bx+bw, by + 2*gap, bw, bh, clrGreen);
   CreateButton(g_btnCloseLoss,   "Close Losses",  bx+bw, by + 1*gap, bw, bh, clrRed);
}

//+------------------------------------------------------------------+
//| Helper to create a button object (bottom-right corner)           |
//+------------------------------------------------------------------+
void CreateButton(string name, string text, int x, int y, int w, int h, color clr)
{
   if (ObjectFind(0, name) < 0)
   {
      if (ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
      {
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
         ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
         ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);     // text color
         ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);        // background color
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
         ObjectSetInteger(0, name, OBJPROP_STATE, false);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);

         ObjectSetString(0, name, OBJPROP_TEXT, text);      // <-- actually shows the caption
         ObjectSetString(0, name, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      }
   }
}

//+------------------------------------------------------------------+
//| Set the text displayed inside a button (used for "Executing")    |
//+------------------------------------------------------------------+
void SetButtonText(string name, string text)
{
   if (ObjectFind(0, name) >= 0)
      ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| Handle chart events (button clicks)                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if (id != CHARTEVENT_OBJECT_CLICK) return;

   if (sparam == g_btnCloseAll)
      RunButtonAction(g_btnCloseAll, "CloseAll", "Close All");
   else if (sparam == g_btnCloseCur)
      RunButtonAction(g_btnCloseCur, "CloseCurrent", "Close current");
   else if (sparam == g_btnCloseLongs)
      RunButtonAction(g_btnCloseLongs, "CloseLongs", "Close Longs");
   else if (sparam == g_btnCloseShorts)
      RunButtonAction(g_btnCloseShorts, "CloseShorts", "Close Shorts");
   else if (sparam == g_btnCloseProfit)
      RunButtonAction(g_btnCloseProfit, "CloseProfits", "Close Profits");
   else if (sparam == g_btnCloseLoss)
      RunButtonAction(g_btnCloseLoss, "CloseLosses", "Close Losses");
}

//+------------------------------------------------------------------+
//| Show "Executing" in the button, perform the action, then reset.  |
//+------------------------------------------------------------------+
void RunButtonAction(string btnName, string action, string originalText)
{
   SetButtonText(btnName, "Executing...");
   ChartRedraw();

   if (action == "CloseAll")
      CloseAllOrders(0);
   else if (action == "CloseCurrent")
      CloseAllOrders(0);
   else if (action == "CloseLongs")
      CloseAllOrders(1);
   else if (action == "CloseShorts")
      CloseAllOrders(-1);
   else if (action == "CloseProfits")
      CloseDirections(true);
   else if (action == "CloseLosses")
      CloseDirections(false);

   SetButtonText(btnName, originalText);   // restore, don't blank
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Close all profitable (or loosing) positions                      |
//+------------------------------------------------------------------+
void CloseDirections(bool profitable)
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      double pf = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      bool isProf = (pf >= 0);
      if (isProf != profitable) continue;

      if (!trade.PositionClose(ticket, g_Slippage))
         Print("CloseDirections Error ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Close all profitable positions in a given direction              |
//+------------------------------------------------------------------+
void CloseProfitDirection(int dir)
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket == 0) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if (PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      long type = PositionGetInteger(POSITION_TYPE);
      if ((type == POSITION_TYPE_BUY && dir != 1) || (type == POSITION_TYPE_SELL && dir != -1)) continue;

      double pf = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if (pf < 0) continue;

      if (!trade.PositionClose(ticket, g_Slippage))
         Print("CloseProfitDirection Error ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Update on-screen display labels                                  |
//+------------------------------------------------------------------+
void UpdateDisplay()
{
   SetLabelText("Balance", "Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
   SetLabelText("Equity", "Equity: " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2));
   SetLabelText("FreeMargin", "FreeMargin: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2));

   if (g_BuyLots > 0)
      SetLabelText("ProfitB", "Buy: " + IntegerToString(g_BuyCount) + "  " + DoubleToString(g_BuyProfit, 2) + "  " + DoubleToString(g_BuyLots, 2), clrGreen);
   else
      SetLabelText("ProfitB", "Buy: ---", clrGray);

   if (g_SellLots > 0)
      SetLabelText("ProfitS", "Sell: " + IntegerToString(g_SellCount) + "  " + DoubleToString(g_SellProfit, 2) + "  " + DoubleToString(g_SellLots, 2), clrRed);
   else
      SetLabelText("ProfitS", "Sell: ---", clrGray);

   double total = g_BuyProfit + g_SellProfit;
   if (g_BuyLots + g_SellLots > 0)
      SetLabelText("Profit", "Total: " + DoubleToString(total, 2), total >= 0 ? clrGreen : clrRed);
   else
      SetLabelText("Profit", "Total: ---", clrGray);

   // Update the panel
   UpdatePanel();
}

//+------------------------------------------------------------------+
//| Set label text with color                                        |
//+------------------------------------------------------------------+
void SetLabelText(string name, string text, color clr = clrLime)
{
   if (ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}
//+------------------------------------------------------------------+
