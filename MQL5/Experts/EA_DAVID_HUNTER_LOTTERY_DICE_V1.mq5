//+------------------------------------------------------------------+
//|                         EA_DAVID_HUNTER_LOTTERY_DICE_V1.mq5      |
//|  EA thí nghiệm xác suất "XỔ SỐ / TUNG XÚC XẮC".                   |
//|  Mỗi nến mới (khi được phép vào lệnh) tung 1 xúc xắc 6 mặt:      |
//|     1, 2, 3 -> BUY      4, 5, 6 -> SELL                           |
//|  KHÔNG có bất kỳ phân tích kỹ thuật / bộ lọc / martingale / DCA / |
//|  grid / hedge / averaging nào. Hướng lệnh chỉ phụ thuộc xúc xắc.  |
//|                                                                  |
//|  SL / TP tính theo KHOẢNG CÁCH GIÁ thực tế (vd 10.0 = 10 giá      |
//|  XAUUSD), không phải point.                                       |
//|                                                                  |
//|  Random Seed:                                                    |
//|     = 0 : seed động (thời gian/tick) -> mỗi lần chạy khác nhau.  |
//|     > 0 : seed cố định -> backtest tái lập cùng chuỗi xúc xắc.   |
//|  Bộ sinh số ngẫu nhiên là PCG32 tự cài đặt (không dùng MathRand) |
//|  nên chuỗi xúc xắc chỉ phụ thuộc seed và số lần tung.            |
//+------------------------------------------------------------------+
#property copyright "David Hunter"
#property version   "1.00"
#property description "EA_DAVID_HUNTER_LOTTERY_DICE_V1 - thí nghiệm xác suất tung xúc xắc"
#property description "Xúc xắc 1-3 = BUY, 4-6 = SELL. Không chiến lược, không lọc."

#include <Trade\Trade.mqh>

//====================================================================
// INPUT (tên hiển thị tiếng Việt lấy từ comment cuối dòng)
//====================================================================
input group "=== CÀI ĐẶT CHUNG ==="
input bool            InpEnabled       = true;        // Bật EA
input double          InpLot           = 0.01;        // Khối lượng giao dịch (lot)
input double          InpSLDistance    = 10.0;        // Khoảng cách Stop Loss (theo giá)
input double          InpTPDistance    = 10.0;        // Khoảng cách Take Profit (theo giá)
input ENUM_TIMEFRAMES InpDiceTimeframe = PERIOD_M1;   // Khung thời gian tung xúc xắc
input int             InpMaxPositions  = 1;           // Số lệnh tối đa
input long            InpMagic         = 20261001;    // Magic Number
input uint            InpRandomSeed    = 0;           // Hạt giống ngẫu nhiên (0 = ngẫu nhiên động)

input group "=== HƯỚNG LỆNH ==="
input bool            InpAllowBuy      = true;        // Cho phép BUY
input bool            InpAllowSell     = true;        // Cho phép SELL

input group "=== HIỂN THỊ ==="
input bool            InpShowPanel     = true;        // Hiển thị bảng thông tin
input int             InpSlippage      = 30;          // Độ trượt giá tối đa (point)

//====================================================================
// HẰNG SỐ
//====================================================================
#define EA_NAME      "EA_DAVID_HUNTER_LOTTERY_DICE_V1"
#define PANEL_PREFIX "DHLD_PANEL_"
#define LOG_TAG      "[DICE] "

//====================================================================
// BIẾN TOÀN CỤC
//====================================================================
CTrade          g_trade;
ENUM_TIMEFRAMES g_tf             = PERIOD_M1;
datetime        g_lastBarTime    = 0;      // nến đã được xử lý gần nhất (khóa 1 lần / nến)
bool            g_isNetting      = false;
int             g_maxPositions   = 1;
double          g_lot            = 0.01;

// --- RNG (PCG32) ---
ulong           g_rngState       = 0;
ulong           g_rngInc         = 1442695040888963407;
uint            g_effectiveSeed  = 0;

// --- Thống kê xúc xắc (trong phiên chạy) ---
int             g_lastDice       = 0;
string          g_lastSignal     = "-";
long            g_totalRolls     = 0;
long            g_totalBuyRolls  = 0;
long            g_totalSellRolls = 0;

// --- Lệnh gần nhất ---
double          g_lastEntry      = 0.0;
double          g_lastSL         = 0.0;
double          g_lastTP         = 0.0;
double          g_lastLot        = 0.0;

// --- Thống kê lệnh đã đóng ---
long            g_closedTrades   = 0;
long            g_wins           = 0;
long            g_losses         = 0;
double          g_totalProfit    = 0.0;

// --- Drawdown ---
double          g_peakEquity     = 0.0;

// --- Trạng thái / log ---
string          g_status         = "-";
string          g_lastBlockReason= "";
uint            g_lastPanelMs    = 0;
bool            g_panelEnabled   = false;

//====================================================================
// RNG: PCG32 (O'Neill) - xác định hoàn toàn theo seed
//====================================================================
uint Rng_Next32()
{
   ulong oldState = g_rngState;
   g_rngState = oldState * 6364136223846793005 + g_rngInc;
   uint xorshifted = (uint)(((oldState >> 18) ^ oldState) >> 27);
   uint rot        = (uint)(oldState >> 59);
   return (xorshifted >> rot) | (xorshifted << ((32 - rot) & 31));
}

void Rng_Seed(const uint seed)
{
   g_rngState = 0;
   g_rngInc   = 1442695040888963407;      // số lẻ cố định
   Rng_Next32();
   g_rngState += (ulong)seed;
   Rng_Next32();
}

// Seed động khi người dùng nhập 0
uint BuildDynamicSeed()
{
   ulong s = GetMicrosecondCount();
   s ^= ((ulong)TimeLocal()) << 21;
   s ^= ((ulong)GetTickCount()) << 7;
   s ^= (ulong)ChartID();
   MqlTick t;
   if(SymbolInfoTick(_Symbol, t))
      s ^= (ulong)t.time_msc;
   uint seed = (uint)(s ^ (s >> 32));
   if(seed == 0)
      seed = 1;
   return seed;
}

// Tung xúc xắc 6 mặt, không lệch (rejection sampling)
int RollDice()
{
   const uint limit = 0xFFFFFFFC;   // 4294967292 = 6 * 715827882
   uint r;
   do
     {
      r = Rng_Next32();
     }
   while(r >= limit);
   return (int)(r % 6) + 1;
}

//====================================================================
// TIỆN ÍCH
//====================================================================
string TfToString(const ENUM_TIMEFRAMES tf)
{
   string s = EnumToString(tf);          // "PERIOD_M1"
   if(StringFind(s, "PERIOD_") == 0)
      s = StringSubstr(s, 7);
   return s;
}

double NormalizePrice(const double price)
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   int    digits   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double p = price;
   if(tickSize > 0.0)
      p = MathRound(p / tickSize) * tickSize;
   return NormalizeDouble(p, digits);
}

int VolumeDigits(const double step)
{
   int d = 0;
   double s = step;
   while(d < 8 && MathAbs(s - MathRound(s)) > 1e-9)
     {
      s *= 10.0;
      d++;
     }
   return d;
}

// Chuẩn hóa lot theo min/max/step của broker
double NormalizeLot(const double lot)
{
   double vMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vMax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(vStep <= 0.0)
      vStep = 0.01;
   double v = MathFloor(lot / vStep + 1e-7) * vStep;
   if(v < vMin)
      v = vMin;
   if(vMax > 0.0 && v > vMax)
      v = vMax;
   return NormalizeDouble(v, VolumeDigits(vStep));
}

// Kiểm tra quyền giao dịch chung (terminal, EA, tài khoản, symbol)
bool IsTradingAllowed(string &reason)
{
   if(!TerminalInfoInteger(TERMINAL_CONNECTED) && !MQLInfoInteger(MQL_TESTER))
     { reason = "Terminal chưa kết nối server"; return false; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     { reason = "AutoTrading (Algo Trading) trên terminal đang TẮT"; return false; }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
     { reason = "EA không được cấp quyền 'Allow Algo Trading'"; return false; }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
     { reason = "Tài khoản không cho phép giao dịch"; return false; }
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
     { reason = "Tài khoản không cho phép EA giao dịch"; return false; }
   long mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(mode == SYMBOL_TRADE_MODE_DISABLED)
     { reason = "Symbol " + _Symbol + " bị khóa giao dịch"; return false; }
   if(mode == SYMBOL_TRADE_MODE_CLOSEONLY)
     { reason = "Symbol " + _Symbol + " chỉ cho phép đóng lệnh"; return false; }
   reason = "";
   return true;
}

// Hướng lệnh có được symbol cho phép không (LONGONLY / SHORTONLY)
bool SymbolAllowsDirection(const bool isBuy)
{
   long mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(isBuy && mode == SYMBOL_TRADE_MODE_SHORTONLY)
      return false;
   if(!isBuy && mode == SYMBOL_TRADE_MODE_LONGONLY)
      return false;
   return true;
}

// Đếm vị thế của chính EA (đúng Symbol + Magic)
int CountMyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      count++;
     }
   return count;
}

// Đếm lệnh chờ / lệnh đang xử lý của EA (chống duplicate)
int CountMyOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagic)
         continue;
      count++;
     }
   return count;
}

// Netting: nếu Symbol đang có vị thế của người khác/EA khác thì không vào
// (vào lệnh sẽ cộng/trừ vào vị thế của họ).
bool HasForeignNettingPosition()
{
   if(!g_isNetting)
      return false;
   if(!PositionSelect(_Symbol))
      return false;
   return (PositionGetInteger(POSITION_MAGIC) != InpMagic);
}

double CurrentFloatingProfit()
{
   double p = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      p += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return p;
}

double DealNet(const ulong deal)
{
   return HistoryDealGetDouble(deal, DEAL_PROFIT)
        + HistoryDealGetDouble(deal, DEAL_SWAP)
        + HistoryDealGetDouble(deal, DEAL_COMMISSION)
        + HistoryDealGetDouble(deal, DEAL_FEE);
}

bool IsCloseEntry(const ENUM_DEAL_ENTRY entry)
{
   return (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY || entry == DEAL_ENTRY_INOUT);
}

string DealReasonText(const ENUM_DEAL_REASON r)
{
   switch(r)
     {
      case DEAL_REASON_TP:     return "TP";
      case DEAL_REASON_SL:     return "SL";
      case DEAL_REASON_SO:     return "STOP OUT";
      case DEAL_REASON_EXPERT: return "EXPERT";
      case DEAL_REASON_CLIENT:
      case DEAL_REASON_MOBILE:
      case DEAL_REASON_WEB:    return "MANUAL";
      default:                 return "OTHER";
     }
}

// Đọc lại thống kê lệnh đã đóng từ lịch sử (khi EA khởi động lại)
void LoadHistoryStats()
{
   g_closedTrades = 0;
   g_wins         = 0;
   g_losses       = 0;
   g_totalProfit  = 0.0;

   if(!HistorySelect(0, TimeCurrent() + 86400))
      return;

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagic)
         continue;
      ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
      if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL)
         continue;

      double net = DealNet(deal);
      g_totalProfit += net;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(IsCloseEntry(entry))
        {
         g_closedTrades++;
         if(net > 0.0)
            g_wins++;
         else
            g_losses++;
        }
     }
}

// Nạp thông tin vị thế đang mở (nếu EA được gắn lại khi đã có lệnh)
void LoadOpenPositionInfo()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      g_lastEntry  = PositionGetDouble(POSITION_PRICE_OPEN);
      g_lastSL     = PositionGetDouble(POSITION_SL);
      g_lastTP     = PositionGetDouble(POSITION_TP);
      g_lastLot    = PositionGetDouble(POSITION_VOLUME);
      g_lastSignal = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      break;
     }
}

//====================================================================
// VÀO LỆNH
//====================================================================
bool IsRetryableRetcode(const uint rc)
{
   return (rc == TRADE_RETCODE_REQUOTE ||
           rc == TRADE_RETCODE_PRICE_CHANGED ||
           rc == TRADE_RETCODE_PRICE_OFF);
}

bool OpenDiceTrade(const bool isBuy, const int dice)
{
   string dir = isBuy ? "BUY" : "SELL";
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // --- Margin ---
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick) || tick.ask <= 0.0 || tick.bid <= 0.0)
     {
      Print(LOG_TAG, "Không lấy được giá ", _Symbol, " -> bỏ qua ", dir);
      return false;
     }
   double margin = 0.0;
   ENUM_ORDER_TYPE otype = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(OrderCalcMargin(otype, _Symbol, g_lot, isBuy ? tick.ask : tick.bid, margin))
     {
      if(margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
        {
         Print(LOG_TAG, "Không đủ margin cho ", dir, " ", DoubleToString(g_lot, 2),
               " lot (cần ", DoubleToString(margin, 2), ") -> bỏ qua");
         return false;
        }
     }

   for(int attempt = 1; attempt <= 3; attempt++)
     {
      if(attempt > 1 && !SymbolInfoTick(_Symbol, tick))
         break;

      double price = isBuy ? tick.ask : tick.bid;
      double sl    = isBuy ? price - InpSLDistance : price + InpSLDistance;
      double tp    = isBuy ? price + InpTPDistance : price - InpTPDistance;
      price = NormalizePrice(price);
      sl    = NormalizePrice(sl);
      tp    = NormalizePrice(tp);

      // --- StopsLevel / FreezeLevel ---
      long   stopsLvl  = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      long   freezeLvl = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      double minDist   = (double)MathMax(stopsLvl, freezeLvl) * point;
      // SL/TP của BUY được kích hoạt theo Bid, của SELL theo Ask
      double slGap = isBuy ? (tick.bid - sl) : (sl - tick.ask);
      double tpGap = isBuy ? (tp - tick.bid) : (tick.ask - tp);
      if(slGap <= 0.0 || tpGap <= 0.0 || slGap < minDist || tpGap < minDist)
        {
         Print(LOG_TAG, "SL/TP vi phạm StopsLevel của broker (min = ",
               DoubleToString(minDist, digits), ", SL gap = ", DoubleToString(slGap, digits),
               ", TP gap = ", DoubleToString(tpGap, digits), ") -> bỏ qua ", dir);
         return false;
        }

      string comment = StringFormat("DICE %d %s", dice, dir);
      bool sent = isBuy ? g_trade.Buy(g_lot, _Symbol, price, sl, tp, comment)
                        : g_trade.Sell(g_lot, _Symbol, price, sl, tp, comment);
      uint rc = g_trade.ResultRetcode();

      if(sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED))
        {
         double fill = g_trade.ResultPrice();
         if(fill <= 0.0)
            fill = price;
         g_lastEntry = fill;
         g_lastSL    = sl;
         g_lastTP    = tp;
         g_lastLot   = g_lot;
         Print(LOG_TAG, "Entry ", dir, " ", _Symbol, " @ ", DoubleToString(fill, digits),
               " | Lot = ", DoubleToString(g_lot, 2));
         Print(LOG_TAG, "SL = ", DoubleToString(sl, digits), " | TP = ", DoubleToString(tp, digits));
         return true;
        }

      Print(LOG_TAG, "Gửi lệnh ", dir, " thất bại (lần ", attempt, "): retcode = ", rc,
            " - ", g_trade.ResultRetcodeDescription());
      if(!IsRetryableRetcode(rc))
         break;
     }
   return false;
}

//====================================================================
// XỬ LÝ NẾN MỚI (gọi đúng 1 lần cho mỗi nến)
//====================================================================
void ProcessNewBar()
{
   if(!InpEnabled)
     {
      g_status = "DISABLED";
      return;
     }

   string reason;
   if(!IsTradingAllowed(reason))
     {
      g_status = "TRADE NOT ALLOWED";
      if(reason != g_lastBlockReason)
        {
         Print(LOG_TAG, "Không thể giao dịch: ", reason);
         g_lastBlockReason = reason;
        }
      return;
     }
   g_lastBlockReason = "";

   // Đã đủ số vị thế -> không tung xúc xắc, chờ nến mới tiếp theo
   int openCount = CountMyPositions() + CountMyOrders();
   if(openCount >= g_maxPositions)
     {
      g_status = "IN POSITION";
      return;
     }

   if(HasForeignNettingPosition())
     {
      g_status = "BLOCKED (NETTING)";
      Print(LOG_TAG, "Tài khoản Netting: ", _Symbol,
            " đang có vị thế không thuộc EA (magic khác) -> không vào lệnh");
      return;
     }

   // ---------------- TUNG XÚC XẮC ----------------
   int  dice  = RollDice();
   bool isBuy = (dice <= 3);           // 1-3 BUY, 4-6 SELL
   string dir = isBuy ? "BUY" : "SELL";

   g_totalRolls++;
   if(isBuy)
      g_totalBuyRolls++;
   else
      g_totalSellRolls++;
   g_lastDice   = dice;
   g_lastSignal = dir;

   Print(LOG_TAG, "Roll = ", dice, " → ", dir);

   // Người dùng tắt chiều này -> bỏ lượt (KHÔNG tung lại, KHÔNG đảo chiều)
   if((isBuy && !InpAllowBuy) || (!isBuy && !InpAllowSell))
     {
      g_status = "SKIP (" + dir + " OFF)";
      Print(LOG_TAG, dir, " đang bị tắt trong Input -> bỏ lượt này, chờ nến mới");
      return;
     }
   if(!SymbolAllowsDirection(isBuy))
     {
      g_status = "SKIP (SYMBOL " + dir + " ONLY-MODE)";
      Print(LOG_TAG, "Symbol không cho phép ", dir, " -> bỏ lượt này, chờ nến mới");
      return;
     }

   if(OpenDiceTrade(isBuy, dice))
      g_status = "IN POSITION";
   else
      g_status = "ENTRY FAILED - WAIT NEW BAR";
}

//====================================================================
// BẢNG THÔNG TIN
//====================================================================
#define PANEL_LINES 24

void Panel_Create()
{
   string bg = PANEL_PREFIX + "BG";
   if(ObjectFind(0, bg) < 0)
      ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, 8);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, 22);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE, 300);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE, PANEL_LINES * 16 + 12);
   ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'20,24,32');
   ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bg, OBJPROP_COLOR, C'90,90,110');
   ObjectSetInteger(0, bg, OBJPROP_BACK, false);
   ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);

   for(int i = 0; i < PANEL_LINES; i++)
     {
      string name = PANEL_PREFIX + IntegerToString(i);
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 16);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 28 + i * 16);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhiteSmoke);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, name, OBJPROP_TEXT, " ");
     }
}

void Panel_SetLine(const int idx, const string text, const color clr = clrWhiteSmoke)
{
   string name = PANEL_PREFIX + IntegerToString(idx);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void Panel_Delete()
{
   ObjectsDeleteAll(0, PANEL_PREFIX);
}

string Row(const string label, const string value)
{
   return StringFormat("%-14s: %s", label, value);
}

void Panel_Update()
{
   if(!g_panelEnabled)
      return;

   int    digits   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double floating = CurrentFloatingProfit();
   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double ddMoney  = (g_peakEquity > equity) ? (g_peakEquity - equity) : 0.0;
   double ddPct    = (g_peakEquity > 0.0) ? ddMoney / g_peakEquity * 100.0 : 0.0;
   double buyPct   = (g_totalRolls > 0) ? 100.0 * g_totalBuyRolls  / g_totalRolls : 0.0;
   double sellPct  = (g_totalRolls > 0) ? 100.0 * g_totalSellRolls / g_totalRolls : 0.0;
   double winRate  = (g_closedTrades > 0) ? 100.0 * g_wins / g_closedTrades : 0.0;

   color sigClr = (g_lastSignal == "BUY") ? clrDodgerBlue : (g_lastSignal == "SELL") ? clrTomato : clrWhiteSmoke;
   color stClr  = (!InpEnabled) ? clrGray : clrLimeGreen;

   int i = 0;
   Panel_SetLine(i++, "DAVID HUNTER – LOTTERY DICE", clrGold);
   Panel_SetLine(i++, Row("Symbol", _Symbol));
   Panel_SetLine(i++, Row("Timeframe", TfToString(g_tf)));
   Panel_SetLine(i++, Row("Status", g_status), stClr);
   Panel_SetLine(i++, Row("Seed", IntegerToString(g_effectiveSeed) + (InpRandomSeed == 0 ? " (dynamic)" : " (fixed)")));
   Panel_SetLine(i++, Row("DICE", g_lastDice > 0 ? IntegerToString(g_lastDice) : "-"), clrGold);
   Panel_SetLine(i++, Row("SIGNAL", g_lastSignal), sigClr);
   Panel_SetLine(i++, Row("Entry", g_lastEntry > 0 ? DoubleToString(g_lastEntry, digits) : "-"));
   Panel_SetLine(i++, Row("SL", g_lastSL > 0 ? DoubleToString(g_lastSL, digits) : "-"));
   Panel_SetLine(i++, Row("TP", g_lastTP > 0 ? DoubleToString(g_lastTP, digits) : "-"));
   Panel_SetLine(i++, Row("Lot", DoubleToString(g_lot, 2)));
   Panel_SetLine(i++, Row("Total rolls", IntegerToString(g_totalRolls)));
   Panel_SetLine(i++, Row("Total BUY", IntegerToString(g_totalBuyRolls)), clrDodgerBlue);
   Panel_SetLine(i++, Row("Total SELL", IntegerToString(g_totalSellRolls)), clrTomato);
   Panel_SetLine(i++, Row("BUY %", DoubleToString(buyPct, 2) + "%"));
   Panel_SetLine(i++, Row("SELL %", DoubleToString(sellPct, 2) + "%"));
   Panel_SetLine(i++, Row("Closed trades", IntegerToString(g_closedTrades)));
   Panel_SetLine(i++, Row("Win", IntegerToString(g_wins)), clrLimeGreen);
   Panel_SetLine(i++, Row("Loss", IntegerToString(g_losses)), clrTomato);
   Panel_SetLine(i++, Row("Win Rate", DoubleToString(winRate, 2) + "%"));
   Panel_SetLine(i++, Row("Profit now", DoubleToString(floating, 2)), floating >= 0 ? clrLimeGreen : clrTomato);
   Panel_SetLine(i++, Row("Profit total", DoubleToString(g_totalProfit, 2)), g_totalProfit >= 0 ? clrLimeGreen : clrTomato);
   Panel_SetLine(i++, Row("Drawdown", DoubleToString(ddMoney, 2) + " (" + DoubleToString(ddPct, 2) + "%)"));
   Panel_SetLine(i++, Row("Account", g_isNetting ? "NETTING" : "HEDGING"), clrSilver);

   ChartRedraw(0);
}

//====================================================================
// SỰ KIỆN EA
//====================================================================
int OnInit()
{
   // --- Kiểm tra Input ---
   if(InpSLDistance <= 0.0 || InpTPDistance <= 0.0)
     {
      Print(LOG_TAG, "Khoảng cách SL/TP phải > 0");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpLot <= 0.0)
     {
      Print(LOG_TAG, "Khối lượng giao dịch phải > 0");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpMaxPositions < 1)
     {
      Print(LOG_TAG, "Số lệnh tối đa phải >= 1");
      return INIT_PARAMETERS_INCORRECT;
     }

   g_tf = (InpDiceTimeframe == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : InpDiceTimeframe;

   // --- Loại tài khoản ---
   ENUM_ACCOUNT_MARGIN_MODE mm = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   g_isNetting    = (mm != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   g_maxPositions = InpMaxPositions;
   if(g_isNetting && g_maxPositions > 1)
     {
      Print(LOG_TAG, "Tài khoản Netting chỉ có 1 vị thế / symbol -> Số lệnh tối đa = 1");
      g_maxPositions = 1;
     }

   // --- Lot ---
   g_lot = NormalizeLot(InpLot);
   if(MathAbs(g_lot - InpLot) > 1e-8)
      Print(LOG_TAG, "Lot ", DoubleToString(InpLot, 4), " được chuẩn hóa theo broker thành ",
            DoubleToString(g_lot, 4), " (min=", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN),
            ", max=", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX),
            ", step=", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP), ")");

   // --- CTrade ---
   g_trade.SetExpertMagicNumber((ulong)InpMagic);
   g_trade.SetDeviationInPoints((ulong)MathMax(InpSlippage, 0));
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetMarginMode();
   g_trade.SetAsyncMode(false);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   // --- Random seed ---
   g_effectiveSeed = (InpRandomSeed > 0) ? InpRandomSeed : BuildDynamicSeed();
   Rng_Seed(g_effectiveSeed);

   // --- Trạng thái ban đầu ---
   LoadHistoryStats();
   LoadOpenPositionInfo();
   g_peakEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
   // Không tung ngay khi gắn EA: chờ nến MỚI đầu tiên xuất hiện
   g_lastBarTime = iTime(_Symbol, g_tf, 0);
   g_status      = InpEnabled ? "WAITING NEW BAR" : "DISABLED";

   bool tester = (bool)MQLInfoInteger(MQL_TESTER);
   bool visual = (bool)MQLInfoInteger(MQL_VISUAL_MODE);
   g_panelEnabled = InpShowPanel && (!tester || visual);
   if(g_panelEnabled)
     {
      Panel_Create();
      Panel_Update();
     }

   Print(LOG_TAG, EA_NAME, " khởi động | ", _Symbol, " | TF xúc xắc = ", TfToString(g_tf),
         " | Lot = ", DoubleToString(g_lot, 2),
         " | SL = ", DoubleToString(InpSLDistance, 2), " | TP = ", DoubleToString(InpTPDistance, 2),
         " | Magic = ", InpMagic, " | ", (g_isNetting ? "NETTING" : "HEDGING"));
   Print(LOG_TAG, "Random seed = ", g_effectiveSeed,
         (InpRandomSeed == 0 ? " (động - nhập số này vào Input để tái lập chuỗi xúc xắc)" : " (cố định)"));

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Panel_Delete();
   Print(LOG_TAG, EA_NAME, " dừng | Tổng tung = ", g_totalRolls,
         " | BUY = ", g_totalBuyRolls, " | SELL = ", g_totalSellRolls,
         " | Lệnh đóng = ", g_closedTrades, " | Win = ", g_wins, " | Loss = ", g_losses,
         " | Profit tổng = ", DoubleToString(g_totalProfit, 2));
}

void OnTick()
{
   // --- Drawdown: đỉnh equity từ khi EA chạy ---
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity > g_peakEquity)
      g_peakEquity = equity;

   // --- Phát hiện nến mới trên khung xúc xắc ---
   datetime barTime = iTime(_Symbol, g_tf, 0);
   if(barTime > 0)
     {
      if(g_lastBarTime == 0)
        {
         // Dữ liệu chưa sẵn sàng lúc OnInit: ghi nhận nến hiện tại, chờ nến kế tiếp
         g_lastBarTime = barTime;
        }
      else if(barTime != g_lastBarTime)
        {
         // KHÓA nến trước khi xử lý -> mỗi nến chỉ xét/tung đúng 1 lần,
         // kể cả khi gửi lệnh thất bại hoặc lệnh đóng ngay trong nến này.
         g_lastBarTime = barTime;
         ProcessNewBar();
         g_lastPanelMs = 0;   // cập nhật bảng ngay
        }
     }

   if(g_status == "IN POSITION" && CountMyPositions() + CountMyOrders() == 0)
      g_status = "WAITING NEW BAR";

   // --- Bảng thông tin (giới hạn ~2 lần/giây) ---
   if(g_panelEnabled)
     {
      uint now = GetTickCount();
      if(g_lastPanelMs == 0 || now - g_lastPanelMs >= 500)
        {
         g_lastPanelMs = now;
         Panel_Update();
        }
     }
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   if(trans.deal == 0 || !HistoryDealSelect(trans.deal))
      return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol)
      return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagic)
      return;

   ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL)
      return;

   double net = DealNet(trans.deal);
   g_totalProfit += net;     // gồm cả commission/fee của deal vào lệnh

   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(!IsCloseEntry(entry))
      return;

   g_closedTrades++;
   if(net > 0.0)
      g_wins++;
   else
      g_losses++;

   // Deal đóng có chiều ngược với vị thế: deal SELL đóng vị thế BUY
   string posDir = (type == DEAL_TYPE_SELL) ? "BUY" : "SELL";
   ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON);
   Print(LOG_TAG, posDir, " closed by ", DealReasonText(reason),
         " | Profit = ", DoubleToString(net, 2),
         " | Profit tổng = ", DoubleToString(g_totalProfit, 2));

   if(CountMyPositions() + CountMyOrders() == 0)
      g_status = InpEnabled ? "WAITING NEW BAR" : "DISABLED";
   g_lastPanelMs = 0;
}
//+------------------------------------------------------------------+
