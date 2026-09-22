//+------------------------------------------------------------------+
//|                                            DTC_v137_EA.mq5       |
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
#property version   "1.37"

#include <Trade\Trade.mqh>
CTrade trade;

//====================================================================
// Inputs
//====================================================================
input group "=== Cài Đặt EMA (khớp độ dài của indicator) ==="
input int    InpLen1 = 30;
input int    InpLen2 = 35;
input int    InpLen3 = 40;
input int    InpLen4 = 45;
input int    InpLen5 = 50;
input int    InpLen6 = 60;

input group "=== Quản Lý Rủi Ro ==="
input double InpStopLossPercent = 0.25;  // % Dừng lỗ theo giá vào lệnh
input double InpTP1Multiplier   = 1.0;
input double InpTP2Multiplier   = 2.0;
input double InpRiskPercent     = 0.75;  // % rủi ro tài khoản trên khoảng cách SL mỗi lệnh, chia đều cho TP1+TP2

input group "=== Bộ Lọc Giảm Nhiễu (bỏ tín hiệu khi ribbon EMA còn quá hẹp/đi ngang) ==="
input double InpMinRibbonWidthATR = 0.3; // độ rộng tối thiểu giữa EMA1-EMA6, tính theo x lần ATR(14); 0 = tắt bộ lọc

input group "=== Quản Lý Vị Thế ==="
input bool   InpBreakevenAfterTP1 = true; // dời SL của lệnh TP2 về giá vào lệnh khi giá chạm TP1
input ulong  InpMagicNumber       = 20260921;

input group "=== Thực Thi Lệnh (buffer vào lệnh) ==="
input int    InpSlippagePoints   = 20; // độ trượt giá tối đa cho phép khi khớp lệnh thị trường
input int    InpMaxSpreadPoints  = 0;  // bỏ qua vào lệnh nếu spread hiện tại vượt quá số điểm này (0 = không giới hạn)

input group "=== Cảnh Báo Telegram (tuỳ chọn, gọi thẳng Bot API) ==="
input bool   InpTelegramEnabled          = false;
input string InpTelegramBotToken         = ""; // lấy từ @BotFather
input string InpTelegramChatId           = ""; // 1 hoặc nhiều Chat ID cách nhau bởi dấu phẩy, vd: 111111,-100222222,-100333333 (gửi cùng lúc vào nhiều nhóm/kênh)
input int    InpTelegramThreadId         = 0;  // message_thread_id nếu muốn gửi vào 1 Topic cụ thể của nhóm đang bật Forum/Topics (0 = gửi vào nhóm chính, không chỉ định Topic)
input bool   InpTelegramDayMonthSummary  = true; // cũng gửi tổng kết lời/lỗ khi ngày/tháng kết thúc
input bool   InpTestTelegramOnStart      = false; // gửi ngay 1 tin MUA + 1 tin BÁN giả khi gắn EA, để thử kênh Telegram

input group "=== Bảng Lợi Nhuận (chỉ lệnh của EA này, theo magic number) ==="
input bool   InpShowPnLTable = true;
input ENUM_BASE_CORNER InpPnLCorner = CORNER_LEFT_LOWER;
input int    InpPnLFontSize  = 9;

input group "=== Bảng Lịch Sử Vào/Ra Lệnh (lệnh thật, theo magic number) ==="
input bool   InpShowTradeLog = true;
input int    InpTradeLogRows = 8;   // số dòng gần nhất hiển thị (tối đa 15)
input ENUM_BASE_CORNER InpTradeLogCorner = CORNER_RIGHT_LOWER;
input int    InpTradeLogFontSize = 9;

//====================================================================
// Globals
//====================================================================
int handleEma1, handleEma2, handleEma3, handleEma4, handleEma5, handleEma6, handleAtr;
datetime g_lastBarTime = 0;

// The currently open pair of orders (TP1 leg + TP2 leg), or 0 when flat.
ulong  g_ticket1 = 0, g_ticket2 = 0;
double g_entry = 0, g_sl = 0, g_tp1 = 0, g_tp2 = 0;
bool   g_bullish = false;
bool   g_beApplied = false;

datetime g_curDayStart = 0, g_curMonthStart = 0;

#define OBJ_PREFIX "DTCEA137_"

//====================================================================
// P&L reporting (this EA's own trades only, filtered by InpMagicNumber)
//====================================================================
void TelegramSend(string msg)
{
   if(!InpTelegramEnabled || InpTelegramBotToken=="" || InpTelegramChatId=="") return;

   // InpTelegramChatId có thể chứa nhiều Chat ID cách nhau bởi dấu phẩy -> gửi vào từng nhóm/kênh
   string ids[];
   int idCount = StringSplit(InpTelegramChatId, ',', ids);
   for(int k=0; k<idCount; k++)
   {
      string id = ids[k];
      StringTrimLeft(id); StringTrimRight(id);
      if(id=="") continue;

      string url = "https://api.telegram.org/bot" + InpTelegramBotToken + "/sendMessage";
      string json = "{\"chat_id\":\"" + id + "\",\"text\":\"" + msg + "\"" +
         (InpTelegramThreadId>0 ? ",\"message_thread_id\":"+IntegerToString(InpTelegramThreadId) : "") + "}";

      char post[], result[];
      string headers = "Content-Type: application/json\r\n";
      StringToCharArray(json, post, 0, StringLen(json));
      string resultHeaders;
      int res = WebRequest("POST", url, headers, 5000, post, result, resultHeaders);
      if(res==-1)
         PrintFormat("[DTC-EA] Gửi Telegram tới Chat ID %s thất bại, lỗi=%d. Thêm %s vào Tools>Options>Expert Advisors>Allow WebRequest.", id, GetLastError(), url);
   }
}

datetime StartOfDay(datetime t)
{
   MqlDateTime dt; TimeToStruct(t, dt);
   dt.hour=0; dt.min=0; dt.sec=0;
   return StructToTime(dt);
}

datetime StartOfMonth(datetime t)
{
   MqlDateTime dt; TimeToStruct(t, dt);
   dt.day=1; dt.hour=0; dt.min=0; dt.sec=0;
   return StructToTime(dt);
}

double ComputeProfitBetween(datetime fromTime, datetime toTime)
{
   double sum = 0;
   if(!HistorySelect(fromTime, toTime)) return 0;
   int total = HistoryDealsTotal();
   for(int i=0; i<total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket==0) continue;
      if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;
      sum += HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
   }
   return sum;
}

string FormatMoney(double v)
{
   return (v>=0 ? "+" : "") + DoubleToString(v, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY);
}

void UpdatePnLDashboard()
{
   if(!InpShowPnLTable) { ObjectsDeleteAll(0, OBJ_PREFIX+"pnl_"); return; }

   double todayPnL = ComputeProfitBetween(g_curDayStart, TimeCurrent());
   double monthPnL = ComputeProfitBetween(g_curMonthStart, TimeCurrent());

   string rows[3];
   rows[0] = "DTC Lợi Nhuận";
   rows[1] = "Hôm nay   " + FormatMoney(todayPnL);
   rows[2] = "Tháng này " + FormatMoney(monthPnL);
   color clrs[3];
   clrs[0] = clrWhite;
   clrs[1] = todayPnL>=0 ? clrLime : clrRed;
   clrs[2] = monthPnL>=0 ? clrLime : clrRed;

   for(int r=0; r<3; r++)
   {
      string name = OBJ_PREFIX+"pnl_row"+IntegerToString(r);
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, InpPnLCorner);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 10 + r*(InpPnLFontSize+6));
         ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpPnLFontSize);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      }
      ObjectSetString(0, name, OBJPROP_TEXT, rows[r]);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrs[r]);
   }
}

#define TRADE_LOG_MAX_ROWS 15

struct TradeLogRow
{
   datetime t;
   bool     bullish;
   string   result;
   double   profit;
};

void DrawTableRect(string name, ENUM_BASE_CORNER corner, int x, int y, int w, int h, color bg, color border)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
}

void DrawTableText(string name, ENUM_BASE_CORNER corner, int x, int y, string text, color clr, int fontSize)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

// Bảng lịch sử N lệnh gần nhất đã đóng của đúng EA này (lọc theo InpMagicNumber, lấy từ
// deal history thật của tài khoản - không phải mô phỏng). Mỗi tín hiệu tạo 2 dòng (lệnh TP1
// + lệnh TP2) vì đó là 2 lệnh riêng biệt. Kết quả (TP1/TP2/SL/Đóng tay) đọc từ comment của
// lệnh khi có, hoặc suy ra từ DEAL_REASON do broker trả về khi đóng.
void UpdateTradeLogTable()
{
   if(!InpShowTradeLog) { ObjectsDeleteAll(0, OBJ_PREFIX+"log_"); return; }

   int wantRows = (int)MathMin(InpTradeLogRows, TRADE_LOG_MAX_ROWS);
   TradeLogRow rows[];

   if(HistorySelect(TimeCurrent()-30*86400, TimeCurrent()))
   {
      int total = HistoryDealsTotal();
      for(int i=total-1; i>=0 && ArraySize(rows)<wantRows; i--)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket==0) continue;
         if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;
         if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

         int idx = ArraySize(rows);
         ArrayResize(rows, idx+1);
         rows[idx].t = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         rows[idx].bullish = ((ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE) == DEAL_TYPE_SELL); // đóng bằng lệnh SELL nghĩa là vị thế gốc là MUA
         rows[idx].profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);

         string cmt = HistoryDealGetString(ticket, DEAL_COMMENT);
         if(StringFind(cmt,"TP1")>=0) rows[idx].result = "TP1";
         else if(StringFind(cmt,"TP2")>=0) rows[idx].result = "TP2";
         else
         {
            ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(ticket, DEAL_REASON);
            if(reason==DEAL_REASON_SL) rows[idx].result = "SL";
            else if(reason==DEAL_REASON_TP) rows[idx].result = "TP";
            else rows[idx].result = "Đóng tay";
         }
      }
   }

   int fontSize = InpTradeLogFontSize;
   int rowH = fontSize+7;
   int colGio=52, colLoai=42, colKq=58, colPL=82;
   int tableW = colGio+colLoai+colKq+colPL;
   int baseX=10, baseY=10;

   DrawTableRect(OBJ_PREFIX+"log_hdr_bg", InpTradeLogCorner, baseX, baseY, tableW, rowH, C'40,40,40', clrSilver);
   DrawTableText(OBJ_PREFIX+"log_hdr_0", InpTradeLogCorner, baseX+4, baseY+3, "Giờ", clrWhite, fontSize);
   DrawTableText(OBJ_PREFIX+"log_hdr_1", InpTradeLogCorner, baseX+colGio+2, baseY+3, "Loại", clrWhite, fontSize);
   DrawTableText(OBJ_PREFIX+"log_hdr_2", InpTradeLogCorner, baseX+colGio+colLoai+2, baseY+3, "Kết quả", clrWhite, fontSize);
   DrawTableText(OBJ_PREFIX+"log_hdr_3", InpTradeLogCorner, baseX+colGio+colLoai+colKq+2, baseY+3, "Lãi/Lỗ", clrWhite, fontSize);

   int n = ArraySize(rows);
   for(int r=0; r<TRADE_LOG_MAX_ROWS; r++)
   {
      string rectName = OBJ_PREFIX+"log_row_bg"+IntegerToString(r);
      string c0 = OBJ_PREFIX+"log_row"+IntegerToString(r)+"_c0";
      string c1 = OBJ_PREFIX+"log_row"+IntegerToString(r)+"_c1";
      string c2 = OBJ_PREFIX+"log_row"+IntegerToString(r)+"_c2";
      string c3 = OBJ_PREFIX+"log_row"+IntegerToString(r)+"_c3";

      if(r>=wantRows || r>=n)
      {
         ObjectDelete(0, rectName);
         ObjectDelete(0, c0); ObjectDelete(0, c1); ObjectDelete(0, c2); ObjectDelete(0, c3);
         continue;
      }

      int y = baseY + (r+1)*rowH;
      color rowBg = (r%2==0) ? C'25,25,25' : C'15,15,15';
      DrawTableRect(rectName, InpTradeLogCorner, baseX, y, tableW, rowH, rowBg, clrSilver);

      color typeClr = rows[r].bullish ? clrLime : clrRed;
      color resClr  = (rows[r].result=="SL") ? clrRed : ((rows[r].result=="Đóng tay") ? clrSilver : clrLime);
      color plClr   = rows[r].profit>=0 ? clrLime : clrRed;

      DrawTableText(c0, InpTradeLogCorner, baseX+4, y+3, TimeToString(rows[r].t, TIME_MINUTES), clrWhite, fontSize);
      DrawTableText(c1, InpTradeLogCorner, baseX+colGio+2, y+3, rows[r].bullish?"MUA":"BÁN", typeClr, fontSize);
      DrawTableText(c2, InpTradeLogCorner, baseX+colGio+colLoai+2, y+3, rows[r].result, resClr, fontSize);
      DrawTableText(c3, InpTradeLogCorner, baseX+colGio+colLoai+colKq+2, y+3, FormatMoney(rows[r].profit), plClr, fontSize);
   }
}

// Fires once right after a day/month actually ends, summarizing that day/month's P&L via Telegram.
void CheckDayMonthRollover()
{
   datetime nowDayStart = StartOfDay(TimeCurrent());
   if(nowDayStart != g_curDayStart)
   {
      double pnl = ComputeProfitBetween(g_curDayStart, nowDayStart);
      if(InpTelegramDayMonthSummary)
         TelegramSend("DTC Lợi Nhuận Ngày - " + _Symbol + "\n" + TimeToString(g_curDayStart, TIME_DATE) + ": " + FormatMoney(pnl));
      g_curDayStart = nowDayStart;
   }

   datetime nowMonthStart = StartOfMonth(TimeCurrent());
   if(nowMonthStart != g_curMonthStart)
   {
      double pnl = ComputeProfitBetween(g_curMonthStart, nowMonthStart);
      if(InpTelegramDayMonthSummary)
         TelegramSend("DTC Lợi Nhuận Tháng - " + _Symbol + "\n" + TimeToString(g_curMonthStart, TIME_DATE) + ": " + FormatMoney(pnl));
      g_curMonthStart = nowMonthStart;
   }
}

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
   handleAtr  = iATR(_Symbol, PERIOD_CURRENT, 14);

   if(handleEma1==INVALID_HANDLE || handleEma2==INVALID_HANDLE || handleEma3==INVALID_HANDLE ||
      handleEma4==INVALID_HANDLE || handleEma5==INVALID_HANDLE || handleEma6==INVALID_HANDLE ||
      handleAtr==INVALID_HANDLE)
   {
      Print("[DTC-EA] Không thể tạo handle EMA/ATR");
      return INIT_FAILED;
   }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);

   ObjectsDeleteAll(0, "DTCEA135_"); // dọn object của các bản cũ nếu có
   ObjectsDeleteAll(0, "DTCEA136_");

   g_curDayStart   = StartOfDay(TimeCurrent());
   g_curMonthStart = StartOfMonth(TimeCurrent());
   EventSetTimer(20); // periodic P&L table refresh + day/month rollover check
   UpdatePnLDashboard();
   UpdateTradeLogTable();

   if(InpTestTelegramOnStart)
   {
      double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(px<=0) px = 1.0;
      SendTelegramAlert("MUA [THỬ]", px, px*0.998, px*1.002, px*1.004);
      SendTelegramAlert("BÁN [THỬ]", px, px*1.002, px*0.998, px*0.996);
      Print("[DTC-EA] Đã gửi 2 tin nhắn thử (MUA + BÁN) tới Telegram để kiểm tra kênh báo.");
   }

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   IndicatorRelease(handleEma1); IndicatorRelease(handleEma2); IndicatorRelease(handleEma3);
   IndicatorRelease(handleEma4); IndicatorRelease(handleEma5); IndicatorRelease(handleEma6);
   IndicatorRelease(handleAtr);
   ObjectsDeleteAll(0, OBJ_PREFIX);
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

// Bỏ tín hiệu khi ribbon EMA1-EMA6 còn quá hẹp so với ATR (giá đang đi ngang/nhiễu).
bool RibbonWideEnough(int shift)
{
   if(InpMinRibbonWidthATR<=0) return true;
   double e1, e6, atr;
   if(!GetEmaShift(handleEma1, shift, e1) || !GetEmaShift(handleEma6, shift, e6) || !GetEmaShift(handleAtr, shift, atr))
      return false;
   if(atr<=0) return true;
   return MathAbs(e1-e6) >= InpMinRibbonWidthATR*atr;
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
   string msg = "Tín hiệu " + signalType + " - " + _Symbol + " (" + EnumToString((ENUM_TIMEFRAMES)Period()) + ")" +
      "\nVào lệnh: " + DoubleToString(entry, _Digits) +
      "\nSL: " + DoubleToString(sl, _Digits) +
      "\nTP1: " + DoubleToString(t1, _Digits) +
      "\nTP2: " + DoubleToString(t2, _Digits);
   TelegramSend(msg);
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
      PrintFormat("[DTC-EA] Spread quá rộng (%.1f điểm > %d), bỏ qua vào lệnh", spreadPoints, InpMaxSpreadPoints);
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
      Print("[DTC-EA] Khối lượng lệnh tính ra bằng 0, bỏ qua vào lệnh");
      return false;
   }

   double lot1, lot2;
   SplitVolume(totalLots, lot1, lot2);
   if(lot1<=0 || lot2<=0)
   {
      Print("[DTC-EA] Tài khoản/khối lượng quá nhỏ để chia đều TP1+TP2, bỏ qua vào lệnh");
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
      PrintFormat("[DTC-EA] Cả 2 lệnh vào đều thất bại, retcode=%d", trade.ResultRetcode());
      return false;
   }

   g_ticket1=t1; g_ticket2=t2; g_entry=entry; g_sl=sl; g_tp1=tp1; g_tp2=tp2;
   g_bullish=bullish; g_beApplied=false;

   PrintFormat("[DTC-EA] %s entry=%.5f sl=%.5f tp1=%.5f tp2=%.5f lot1=%.2f lot2=%.2f",
      bullish?"MUA":"BÁN", entry, sl, tp1, tp2, lot1, lot2);
   SendTelegramAlert(bullish?"MUA":"BÁN", entry, sl, tp1, tp2);
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

void OnTimer()
{
   CheckDayMonthRollover();
   UpdatePnLDashboard();
   UpdateTradeLogTable();
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
   if(!RibbonWideEnough(1)) return; // ribbon còn quá hẹp: bỏ qua tín hiệu này, coi như đang đi ngang/nhiễu

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
