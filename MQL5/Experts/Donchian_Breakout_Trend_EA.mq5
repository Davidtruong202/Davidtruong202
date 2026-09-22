//+------------------------------------------------------------------+
//|                                Donchian_Breakout_Trend_EA.mq5     |
//|  He thong trend-following breakout (tu thiet ke): loc xu huong   |
//|  bang EMA + dot pha kenh Donchian + xac nhan bien dong mo rong    |
//|  (ATR) de vao lenh; trailing stop Chandelier (ATR) + chot loi mot |
//|  phan + cong lenh (pyramiding) de quan ly lenh. Ve San Entry/SL/  |
//|  TP va bang thong ke ngay tren chart. Xem README.md de biet ly do |
//|  thiet ke va cac don gian hoa.                                   |
//+------------------------------------------------------------------+
#property copyright "Custom EA"
#property version   "1.10"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// Input - Khung thời gian
//====================================================================
input group "=== Khung thời gian ==="
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_CURRENT; // Chạy theo khung của chart đang gắn EA (để nguyên = khung hiện tại)

//====================================================================
// Input - Bộ lọc xu hướng (EMA)
//====================================================================
input group "=== Bộ lọc xu hướng (EMA) ==="
input int InpEMAFast = 50;  // Chu kỳ đường EMA nhanh
input int InpEMASlow = 200; // Chu kỳ đường EMA chậm

//====================================================================
// Input - Đột phá / Kênh Donchian
//====================================================================
input group "=== Đột phá / Kênh Donchian ==="
input int InpDonchianPeriod = 20; // Số nến nhìn lại để tính kênh (không tính nến tín hiệu, kiểu Turtle Trading)

//====================================================================
// Input - Bộ lọc biến động mở rộng
//====================================================================
input group "=== Bộ lọc biến động mở rộng (ATR) ==="
input int    InpATRPeriod          = 14; // Số nến tính ATR
input int    InpATRAvgPeriod       = 50; // Số nến tính ATR trung bình (đường nền so sánh)
input double InpATRExpansionFactor = 1.1; // Chỉ vào lệnh khi ATR hiện tại > ATR trung bình × hệ số này

//====================================================================
// Input - Điểm dừng / Thoát lệnh
//====================================================================
input group "=== Điểm dừng / Thoát lệnh ==="
input double InpInitialSLATR    = 2.0; // Khoảng cách SL ban đầu = số ATR tính từ giá vào lệnh
input double InpChandelierATR   = 3.0; // Khoảng cách trailing stop (Chandelier Exit) = số ATR từ giá cao/thấp nhất kể từ lúc vào
input double InpPartialTPR      = 2.0; // Chốt lời một phần khi lãi đạt X lần rủi ro ban đầu (R)
input double InpPartialClosePct = 30;  // % khối lượng đóng khi chốt lời một phần

//====================================================================
// Input - Cộng thêm lệnh khi đang thắng (Pyramiding)
//====================================================================
input group "=== Cộng thêm lệnh khi đang thắng (Pyramiding) ==="
input bool   InpEnablePyramid    = true; // Cho phép cộng thêm lệnh khi giá đi đúng hướng
input double InpPyramidStepATR   = 1.0;  // Cộng thêm 1 đơn vị mỗi X lần ATR giá đi đúng hướng kể từ lệnh đầu
input int    InpMaxPyramidUnits  = 2;    // Số đơn vị cộng thêm tối đa (ngoài lệnh đầu tiên)

//====================================================================
// Input - Quản lý rủi ro
//====================================================================
input group "=== Quản lý rủi ro ==="
input double InpRiskPercent         = 1.5; // Rủi ro mỗi đơn vị lệnh (% số dư tài khoản)
input double InpMaxDailyLossPercent = 4.0; // Giới hạn lỗ tối đa trong ngày (%), chạm mức này sẽ dừng vào lệnh
input int    InpMaxConsecLosses     = 4;   // Số lệnh thua liên tiếp tối đa trước khi tạm dừng
input int    InpPauseMinutes        = 120; // Số phút tạm dừng sau khi chạm giới hạn thua liên tiếp

//====================================================================
// Input - Bộ lọc tin tức (tuỳ chọn, mặc định tắt)
//====================================================================
input group "=== Bộ lọc tin tức (tuỳ chọn, mặc định tắt) ==="
input bool   InpEnableNewsFilter     = false; // Bật/tắt lọc tin tức (breakout thường ăn theo biến động do tin, nên mặc định tắt)
input bool   InpBrokerFixedNYOffset  = true;  // true: server luôn lệch múi giờ NY một số giờ cố định (InpServerToNY_Hours)
input double InpServerToNY_Hours     = 7.0;   // Số giờ server đi trước giờ New York (dùng khi InpBrokerFixedNYOffset = true)
input double InpServerGMTOffsetHours = 0.0;   // Múi giờ GMT cố định của broker (dùng khi InpBrokerFixedNYOffset = false)
input double InpNewsHour             = 8.5;   // Giờ NY (thập phân) của mốc tin tức cần tránh, ví dụ 8.5 = 08:30
input double InpNewsBlackoutBefore   = 15;    // Số phút chặn lệnh TRƯỚC mốc tin
input double InpNewsBlackoutAfter    = 15;    // Số phút chặn lệnh SAU mốc tin

//====================================================================
// Input - Giao dịch
//====================================================================
input group "=== Giao dịch ==="
input int InpMagicNumber = 20260923; // Mã Magic để EA nhận diện đúng lệnh của mình
input int InpSlippage    = 30;       // Trượt giá tối đa cho phép (points)

//====================================================================
// Input - Hiển thị trên chart
//====================================================================
input group "=== Hiển thị trên chart ==="
input bool InpShowChartLevels = true; // Vẽ đường Entry (vàng) / SL (đỏ) / TP (xanh) của lệnh đang mở lên chart
input bool InpShowStatsPanel  = true; // Hiện bảng thống kê (số lệnh, tỉ lệ thắng, drawdown...) ở góc trên chart

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
int      g_consecLosses = 0; // dùng để khoá tạm dừng, đồng thời hiển thị "thua liên tiếp"
int      g_consecWins   = 0; // chỉ dùng để hiển thị "thắng liên tiếp"
datetime g_pausedUntil = 0;

// Theo dõi lệnh đang mở (mốc lệnh đầu tiên quyết định R-multiple & bước pyramid)
double   g_entryPriceFirst=0, g_priceRiskPerUnit=0;
double   g_highestSinceEntry=0, g_lowestSinceEntry=0;
int      g_pyramidUnitsAdded=0;
bool     g_partialTPDone=false;

long g_cntBarsEvaluated=0, g_cntTrades=0, g_cntPyramidAdds=0;

// Thống kê hiệu suất cho bảng hiển thị trên chart
long   g_cntWins=0, g_cntLosses=0;
double g_grossProfit=0, g_grossLoss=0;
double g_peakEquity=0, g_maxDDPercent=0, g_curDDPercent=0;

//====================================================================
// Múi giờ / bộ lọc tin tức (tuỳ chọn, mặc định tắt)
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
// Trung bình ATR trượt (bộ lọc biến động mở rộng)
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
// Kênh Donchian (không tính nến tín hiệu vừa đóng cửa)
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
// Tính khối lượng lệnh theo rủi ro
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
// Điều kiện chung để giao dịch
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
   if(!g_atrAvgReady) return false; // chưa đủ dữ liệu để đánh giá biến động mở rộng

   if(InpEnableNewsFilter)
   {
      double nyH = GetNYHourDecimal();
      if(InBlackout(nyH, InpNewsHour, InpNewsBlackoutBefore, InpNewsBlackoutAfter)) return false;
   }
   return true;
}

//====================================================================
// Vẽ / xoá đường Entry - SL - TP trên chart
//====================================================================
#define LVL_ENTRY_NAME "DonchianEA_Entry"
#define LVL_SL_NAME    "DonchianEA_SL"
#define LVL_TP_NAME    "DonchianEA_TP"

void DrawOrUpdateLine(string name, double price, color col, string text)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectMove(0, name, 0, 0, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void DeleteLine(string name)
{
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
}

void DeleteTradeLevels()
{
   DeleteLine(LVL_ENTRY_NAME);
   DeleteLine(LVL_SL_NAME);
   DeleteLine(LVL_TP_NAME);
}

// Vẽ lại 3 đường theo trạng thái lệnh hiện tại - gọi sau khi vào lệnh và
// mỗi khi ManageOpenPosition cập nhật SL/trạng thái chốt lời một phần.
void UpdateTradeLevelsOnChart()
{
   if(!InpShowChartLevels) { DeleteTradeLevels(); return; }
   if(!HasOpenPosition())  { DeleteTradeLevels(); return; }

   bool   isBuy = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double sl    = PositionGetDouble(POSITION_SL);
   int    dig   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   DrawOrUpdateLine(LVL_ENTRY_NAME, g_entryPriceFirst, clrYellow,
                     "Vào lệnh " + DoubleToString(g_entryPriceFirst, dig));

   if(sl > 0)
      DrawOrUpdateLine(LVL_SL_NAME, sl, clrRed, "Cắt lỗ " + DoubleToString(sl, dig));
   else
      DeleteLine(LVL_SL_NAME);

   if(!g_partialTPDone && g_priceRiskPerUnit > 0)
   {
      double tp = isBuy ? g_entryPriceFirst + g_priceRiskPerUnit*InpPartialTPR
                         : g_entryPriceFirst - g_priceRiskPerUnit*InpPartialTPR;
      DrawOrUpdateLine(LVL_TP_NAME, tp, clrLime, "Chốt lời " + DoubleToString(tp, dig));
   }
   else
      DeleteLine(LVL_TP_NAME); // đã chốt lời một phần, không còn mốc TP cố định - phần còn lại chạy theo trailing
}

//====================================================================
// Bảng thống kê hiển thị góc trên chart (Comment)
//====================================================================
void UpdateStatsPanel()
{
   if(!InpShowStatsPanel) { Comment(""); return; }

   int    totalTrades = (int)(g_cntWins + g_cntLosses);
   double winRate      = totalTrades>0 ? (double)g_cntWins/totalTrades*100.0 : 0;
   double netProfit    = g_grossProfit + g_grossLoss;
   double profitFactor = (g_grossLoss<0) ? g_grossProfit/MathAbs(g_grossLoss) : 0;

   string posLine;
   if(HasOpenPosition())
   {
      bool   isBuy = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      double sl    = PositionGetDouble(POSITION_SL);
      string tpText = "đã chốt";
      if(!g_partialTPDone && g_priceRiskPerUnit>0)
      {
         double tp = isBuy ? g_entryPriceFirst + g_priceRiskPerUnit*InpPartialTPR
                            : g_entryPriceFirst - g_priceRiskPerUnit*InpPartialTPR;
         tpText = DoubleToString(tp, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      }
      posLine = StringFormat("Vị thế: %s | Vào: %s | SL: %s | TP: %s | Đã cộng thêm: %d/%d",
                              isBuy ? "MUA" : "BÁN",
                              DoubleToString(g_entryPriceFirst, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
                              DoubleToString(sl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
                              tpText, g_pyramidUnitsAdded, InpMaxPyramidUnits);
   }
   else
      posLine = "Vị thế: không có lệnh mở";

   string panel = StringFormat(
      "=== THỐNG KÊ EA DONCHIAN BREAKOUT ===\n" +
      "Tổng lệnh: %d | Thắng: %d (%.1f%%) | Thua: %d\n" +
      "Lãi gộp: %.2f | Lỗ gộp: %.2f | Lãi ròng: %.2f\n" +
      "Profit Factor: %.2f\n" +
      "Drawdown hiện tại: %.1f%% | Drawdown tối đa: %.1f%%\n" +
      "Thắng liên tiếp: %d | Thua liên tiếp: %d\n" +
      "%s",
      totalTrades, (int)g_cntWins, winRate, (int)g_cntLosses,
      g_grossProfit, g_grossLoss, netProfit,
      profitFactor,
      g_curDDPercent, g_maxDDPercent,
      g_consecWins, g_consecLosses,
      posLine);

   Comment(panel);
}

void UpdateDrawdownStats()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_peakEquity) g_peakEquity = eq;
   if(g_peakEquity > 0) g_curDDPercent = (g_peakEquity-eq)/g_peakEquity*100.0;
   if(g_curDDPercent > g_maxDDPercent) g_maxDDPercent = g_curDDPercent;
}

//====================================================================
// Đặt lại trạng thái theo dõi lệnh (gọi khi không còn lệnh mở)
//====================================================================
void ResetTradeTracking()
{
   g_entryPriceFirst=0; g_priceRiskPerUnit=0;
   g_highestSinceEntry=0; g_lowestSinceEntry=0;
   g_pyramidUnitsAdded=0; g_partialTPDone=false;
   DeleteTradeLevels();
}

//====================================================================
// Vào lệnh đầu tiên
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
      PrintFormat("[VÀO LỆNH] hướng=%s giá=%.5f SL=%.5f rủi ro=%.5f", bullish?"MUA":"BÁN", entry, sl, risk);
      UpdateTradeLevelsOnChart();
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
// Quản lý lệnh đang mở: thoát khi đổi chiều EMA, trailing Chandelier,
// chốt lời một phần, cộng thêm lệnh (pyramiding).
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

   // Đổi chiều cấu trúc: xu hướng biện minh cho lệnh này không còn đúng nữa.
   bool trendBull = g_emaFast1 > g_emaSlow1;
   bool trendBear = g_emaFast1 < g_emaSlow1;
   if((isBuy && trendBear) || (!isBuy && trendBull))
   {
      trade.PositionClose(ticket);
      ResetTradeTracking();
      return;
   }

   // Trailing stop Chandelier - chỉ siết chặt lại, không bao giờ nới ra.
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

   // Chốt lời một phần tại X lần (InpPartialTPR) rủi ro của đơn vị đầu tiên.
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

   // Cộng thêm lệnh: thêm 1 đơn vị mỗi InpPyramidStepATR giá đi đúng hướng.
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
            // Bảo vệ đơn vị cộng thêm bằng SL trailing hiện tại, để tài khoản
            // hedging (mỗi đơn vị 1 ticket riêng) không bị hở bảo hiểm.
            bool ok = isBuy ? trade.Buy(addLots, _Symbol, addEntry, curSL, 0, "DonchianPyramid")
                             : trade.Sell(addLots, _Symbol, addEntry, curSL, 0, "DonchianPyramid");
            if(ok)
            {
               g_pyramidUnitsAdded++;
               g_cntPyramidAdds++;
               PrintFormat("[CỘNG LỆNH] đơn vị=%d hướng=%s giá=%.5f", g_pyramidUnitsAdded, isBuy?"MUA":"BÁN", addEntry);
            }
         }
      }
   }

   UpdateTradeLevelsOnChart();
}

//====================================================================
// Lưu nến / cập nhật chỉ báo
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
// Các hàm chuẩn của EA
//====================================================================
int OnInit()
{
   emaFastHandle = iMA(_Symbol, InpTimeframe, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, InpTimeframe, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle     = iATR(_Symbol, InpTimeframe, InpATRPeriod);
   if(emaFastHandle==INVALID_HANDLE || emaSlowHandle==INVALID_HANDLE || atrHandle==INVALID_HANDLE)
   {
      Print("Không tạo được handle EMA/ATR");
      return(INIT_FAILED);
   }

   ArrayResize(g_atrHist, InpATRAvgPeriod);
   g_atrHistIdx=0; g_atrHistCount=0; g_atrHistSum=0; g_atrAvgReady=false;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);

   g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_currentDay = TimeCurrent() - (TimeCurrent()%86400);
   g_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);

   ResetTradeTracking();

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   PrintFormat("[Tổng kết EA Donchian] số nến=%d số lệnh=%d số lần cộng lệnh=%d",
               (int)g_cntBarsEvaluated, (int)g_cntTrades, (int)g_cntPyramidAdds);
   IndicatorRelease(emaFastHandle);
   IndicatorRelease(emaSlowHandle);
   IndicatorRelease(atrHandle);
   Comment("");
   DeleteTradeLevels();
}

void OnTick()
{
   UpdateDrawdownStats();
   UpdateStatsPanel();

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

   if(profit < 0)
   {
      g_consecLosses++; g_consecWins=0;
      g_cntLosses++; g_grossLoss += profit;
   }
   else
   {
      g_consecLosses=0; g_consecWins++;
      g_cntWins++; g_grossProfit += profit;
   }

   if(g_consecLosses >= InpMaxConsecLosses)
   {
      g_pausedUntil = TimeCurrent() + InpPauseMinutes*60;
      g_consecLosses = 0;
      Print("Đã chạm số lệnh thua liên tiếp tối đa. Tạm dừng đến ", TimeToString(g_pausedUntil));
   }

   if(!HasOpenPosition())
      ResetTradeTracking();
}
//+------------------------------------------------------------------+
