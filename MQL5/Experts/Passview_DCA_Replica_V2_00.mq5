//+------------------------------------------------------------------+
//|                                  Passview_DCA_Replica_V2_00.mq5  |
//| Tai dung bot Passview (KVB, XAUUSD.e, magic 1234) tu log         |
//| TradeLogger ngay 25/09 va 28/09/2026.                            |
//| Bang chung: docs/passview_dca/01_bao_cao_tai_dung_V2.md          |
//|                                                                  |
//| CO CHE DA QUAN SAT (lap lai tren ca 2 phien, >= 96% mau):        |
//|  - Moi chu ky dat 10 BUY STOP phia tren va 10 SELL STOP phia     |
//|    duoi gia (BUY truoc, SELL sau), bac cach nhau 0.21,           |
//|    lot 0.05, SL 0.50 gan san tren lenh cho, khong TP.            |
//|  - Dat ca luoi lien tiep (1-2 s cho 20 lenh), giu nguyen ~5 giay, |
//|    roi huy lenh chua khop va dat lai NGAY (khong cho).            |
//|    72.9% lan khop xay ra > 2 s sau khi dat -> khong lam moi < 1 s.|
//|  - SL gan san tren lenh cho: co hieu luc ngay khi khop.           |
//|  - Chi thoat bang SL: SL giu nguyen cho toi khi lai du lon, sau  |
//|    do nhay len >= hoa von va trailing theo TUNG TICK.            |
//| SUY LUAN CO CAN CU: bac dau cach gia ~1 buoc; khoang trailing    |
//|    0.50 kich hoat khi lai >= 0.50.                               |
//| CHUA XAC DINH: khung gio chay (chi 2 phien), gioi han vi the.    |
//| BO SUNG AN TOAN (khong co trong log Passview): gioi han vi the,  |
//|    spread, lo ngay, sut giam, het han lenh cho, tam dung khi loi.|
//+------------------------------------------------------------------+
#property copyright "Passview DCA Replica"
#property version   "2.00"
#property description "Tái dựng bot Passview: lưới BUY/SELL STOP làm mới mỗi 5 giây + trailing SL."
#property description "Chỉ hỗ trợ tài khoản hedging. Mặc định chỉ chạy demo/tester."

#include <Trade\Trade.mqh>

#define EA_VERSION "V2.00"

//====================================================================
// Input
//====================================================================
input group "1. Hệ thống và an toàn"
input long   InpMagic            = 55082602;  // Magic number riêng của EA
input bool   InpAllowRealAccount = false;     // Cho phép chạy tài khoản THẬT
input string InpOrderComment     = "PVR2";    // Comment lệnh
input int    InpSlippagePoints   = 30;        // Trượt giá tối đa khi đóng lệnh (point)
input int    InpMaxConsecErrors  = 5;         // Lỗi liên tiếp tối đa trước khi tạm dừng
input int    InpErrorPauseSec    = 30;        // Thời gian tạm dừng sau lỗi (giây)

input group "2. Lưới lệnh chờ (đo từ log Passview)"
input int    InpLevels           = 10;        // Số bậc mỗi phía
input double InpStepPrice        = 0.21;      // Khoảng cách giữa các bậc (giá)
input double InpFirstOffset      = 0.21;      // Bậc đầu cách Ask/Bid (giá, suy luận)
input double InpLot              = 0.05;      // Lot mỗi lệnh
input double InpSLPrice          = 0.50;      // SL ban đầu cách giá vào (giá)
input int    InpRefreshMs        = 5000;      // Thời gian sống của lưới trước khi hủy và đặt lại (ms)
input int    InpPendingExpirySec = 60;        // Lệnh chờ tự hết hạn sau N giây (0 = không)

input group "3. Trailing stop (suy luận từ log)"
input double InpTrailStart       = 0.50;      // Bắt đầu trailing khi lãi ≥ (giá)
input double InpTrailDist        = 0.50;      // Khoảng cách trailing (giá)
input double InpTrailStep        = 0.01;      // Chỉ sửa SL khi cải thiện ≥ (giá)

input group "4. Khung giờ chạy (giờ server; chỉ quan sát 2 phiên)"
input bool   InpUseSession        = true;     // Chỉ đặt lưới trong khung giờ
input string InpSessionStart      = "15:23";  // Giờ bắt đầu (HH:MM)
input string InpSessionEnd        = "18:32";  // Giờ kết thúc (HH:MM)
input bool   InpCloseAtSessionEnd = false;    // Đóng mọi vị thế khi hết giờ

input group "5. Giới hạn rủi ro (bổ sung, Passview không thể hiện)"
input int    InpMaxPositionsPerSide = 40;     // Số vị thế tối đa mỗi chiều (0 = không giới hạn)
input double InpMaxSpreadPrice      = 0.50;   // Spread tối đa để đặt lưới (giá, 0 = tắt)
input double InpDailyLossPct        = 0.0;    // Lỗ trong ngày ≥ % balance đầu ngày → dừng tới hôm sau (0 = tắt)
input double InpMaxDrawdownPct      = 0.0;    // Sụt giảm equity ≥ % balance → đóng hết, dừng tới hôm sau (0 = tắt)

input group "6. Nhật ký"
input bool   InpWriteLog        = true;       // Ghi log CSV
input bool   InpLogCommonFolder = true;       // Ghi vào thư mục Common\Files
input bool   InpLogGrid         = true;       // Ghi mỗi lần đặt/hủy lưới
input bool   InpLogTrail        = false;      // Ghi mỗi lần dời SL (file lớn)

//====================================================================
// Trang thai
//====================================================================
CTrade   g_trade;
bool     g_tester        = false;
int      g_sessStart     = 0, g_sessEnd = 0;
bool     g_gridActive    = false;  // co luoi dang cho het han
long     g_placedMs      = 0;      // thoi diem dat xong luoi
long     g_pauseUntilMs  = 0;      // tam dung sau loi
int      g_cycle         = 0;
bool     g_useExpiry     = false;
int      g_consecErrors  = 0;
string   g_block         = "";     // ly do dang ngung dat luoi
bool     g_sessionClosed = false;  // da xu ly het gio
datetime g_dayStart      = 0;
double   g_dayStartBal   = 0;
bool     g_dayStopped    = false;
string   g_dayStopWhy    = "";
int      g_logH          = INVALID_HANDLE;
string   g_logName       = "";

int      g_stCycles = 0, g_stPlaced = 0, g_stRejected = 0, g_stFills = 0, g_stCloses = 0, g_stErrors = 0, g_stMaxOpen = 0;
double   g_stMaxDD  = 0;

//====================================================================
// Tien ich
//====================================================================
long NowMs()
  {
   if(g_tester)
     {
      MqlTick t;
      long ms = (long)TimeCurrent() * 1000;
      if(SymbolInfoTick(_Symbol, t) && t.time_msc > ms)
         ms = t.time_msc;
      return ms;
     }
   return (long)GetTickCount64();
  }

int ParseHM(const string s)
  {
   string parts[];
   if(StringSplit(s, ':', parts) != 2)
      return -1;
   int h = (int)StringToInteger(parts[0]), m = (int)StringToInteger(parts[1]);
   if(h < 0 || h > 23 || m < 0 || m > 59)
      return -1;
   return h * 60 + m;
  }

bool InSession()
  {
   if(!InpUseSession || g_sessStart == g_sessEnd)
      return true;
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   int now = t.hour * 60 + t.min;
   if(g_sessStart < g_sessEnd)
      return now >= g_sessStart && now < g_sessEnd;
   return now >= g_sessStart || now < g_sessEnd;
  }

bool IsOurPosition()
  {
   return PositionGetInteger(POSITION_MAGIC) == InpMagic && PositionGetString(POSITION_SYMBOL) == _Symbol;
  }

bool IsOurPending()
  {
   long type = OrderGetInteger(ORDER_TYPE);
   return OrderGetInteger(ORDER_MAGIC) == InpMagic && OrderGetString(ORDER_SYMBOL) == _Symbol &&
          (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP);
  }

void CountPositions(int &nb, int &ns)
  {
   nb = 0;
   ns = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetTicket(i) == 0 || !IsOurPosition())
         continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         nb++;
      else
         ns++;
     }
  }

int CountPending()
  {
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
      if(OrderGetTicket(i) != 0 && IsOurPending())
         n++;
   return n;
  }

double Spread()
  {
   return SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
  }

double DrawdownPct()
  {
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   return bal > 0 ? MathMax(0.0, (bal - AccountInfoDouble(ACCOUNT_EQUITY)) / bal * 100.0) : 0.0;
  }

string Clean(string s)
  {
   StringReplace(s, ",", ";");
   StringReplace(s, "\r", " ");
   StringReplace(s, "\n", " ");
   return s;
  }

//====================================================================
// Nhat ky (ASCII, 1 file / thang)
//====================================================================
void LogOpen()
  {
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   string name = StringFormat("PassviewV2_%s_%I64d_%04d_%02d.csv", _Symbol, InpMagic, t.year, t.mon);
   if(name == g_logName && g_logH != INVALID_HANDLE)
      return;
   if(g_logH != INVALID_HANDLE)
      FileClose(g_logH);
   int flags = FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ;
   if(InpLogCommonFolder)
      flags |= FILE_COMMON;
   g_logH = FileOpen(name, flags);
   g_logName = name;
   if(g_logH == INVALID_HANDLE)
     {
      PrintFormat("[PVR2] Không mở được file log %s, lỗi %d", name, GetLastError());
      return;
     }
   if(FileSize(g_logH) == 0)
      FileWriteString(g_logH, "time,time_msc,event,side,ticket,position,price,ref_price,diff,lot,bid,ask,spread,"
                              "open_buy,open_sell,pending,balance,equity,cycle,retcode,version,detail\r\n");
   FileSeek(g_logH, 0, SEEK_END);
  }

void LogRow(const string ev, const string side, const ulong ticket, const ulong position, const double price,
            const double ref, const double diff, const double lot, const string detail, const uint retcode = 0)
  {
   if(!InpWriteLog)
      return;
   LogOpen();
   if(g_logH == INVALID_HANDLE)
      return;
   MqlTick tk;
   bool hasTick = SymbolInfoTick(_Symbol, tk);
   long msc = hasTick ? tk.time_msc : (long)TimeCurrent() * 1000;
   int nb, ns;
   CountPositions(nb, ns);
   int dg = _Digits;
   string line = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + "," + IntegerToString(msc) + "," + ev + "," + side + "," +
                 IntegerToString((long)ticket) + "," + IntegerToString((long)position) + "," +
                 DoubleToString(price, dg) + "," + DoubleToString(ref, dg) + "," + DoubleToString(diff, 2) + "," +
                 DoubleToString(lot, 2) + "," + DoubleToString(hasTick ? tk.bid : 0, dg) + "," +
                 DoubleToString(hasTick ? tk.ask : 0, dg) + "," + DoubleToString(hasTick ? tk.ask - tk.bid : 0, dg) + "," +
                 IntegerToString(nb) + "," + IntegerToString(ns) + "," + IntegerToString(CountPending()) + "," +
                 DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "," + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "," +
                 IntegerToString(g_cycle) + "," + IntegerToString(retcode) + "," + EA_VERSION + "," + Clean(detail);
   FileWriteString(g_logH, line + "\r\n");
   if(g_tester == false && (ev != "TRAIL" && ev != "GRID"))
      FileFlush(g_logH);
  }

//====================================================================
// Xu ly loi
//====================================================================
bool IsPauseCode(const uint rc)
  {
   return rc == TRADE_RETCODE_MARKET_CLOSED || rc == TRADE_RETCODE_TRADE_DISABLED || rc == TRADE_RETCODE_NO_MONEY ||
          rc == TRADE_RETCODE_LIMIT_ORDERS || rc == TRADE_RETCODE_LIMIT_POSITIONS || rc == TRADE_RETCODE_LIMIT_VOLUME ||
          rc == TRADE_RETCODE_TOO_MANY_REQUESTS || rc == TRADE_RETCODE_CONNECTION || rc == TRADE_RETCODE_SERVER_DISABLES_AT ||
          rc == TRADE_RETCODE_CLIENT_DISABLES_AT || rc == TRADE_RETCODE_INVALID_VOLUME;
  }

void HandleError(const uint rc, const string where, const ulong ticket = 0)
  {
   g_stErrors++;
   g_consecErrors++;
   LogRow("ERROR", "", ticket, 0, 0, 0, 0, 0, where + " " + g_trade.ResultRetcodeDescription(), rc);
   if(IsPauseCode(rc) || g_consecErrors >= InpMaxConsecErrors)
     {
      g_pauseUntilMs = NowMs() + (long)MathMax(1, InpErrorPauseSec) * 1000;
      g_consecErrors = 0;
      LogRow("PAUSE", "", 0, 0, 0, 0, 0, 0, StringFormat("errors -> pause %ds (last %s)", InpErrorPauseSec, where), rc);
      PrintFormat("[PVR2] Tạm dừng đặt lưới %d giây sau lỗi %u (%s)", InpErrorPauseSec, rc, where);
     }
  }

//====================================================================
// Luoi lenh cho
//====================================================================
int CancelAllPending()
  {
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong tk = OrderGetTicket(i);
      if(tk == 0 || !IsOurPending())
         continue;
      if(g_trade.OrderDelete(tk) && g_trade.ResultRetcode() == TRADE_RETCODE_DONE)
        {
         n++;
         continue;
        }
      if(!OrderSelect(tk))
         continue;           // vua khop hoac da het han: binh thuong
      HandleError(g_trade.ResultRetcode(), "DELETE", tk);
     }
   return n;
  }

// dat mot phia cua luoi; tra ve so lenh dat duoc
int PlaceSide(const bool buy, int &rejected, double &anchorOut)
  {
   rejected = 0;
   anchorOut = 0;
   int nb, ns;
   CountPositions(nb, ns);
   int open = buy ? nb : ns;
   int levels = InpLevels;
   if(InpMaxPositionsPerSide > 0)
      levels = MathMin(levels, InpMaxPositionsPerSide - open);
   if(levels <= 0)
     {
      LogRow("SKIP_SIDE", buy ? "BUY" : "SELL", 0, 0, 0, 0, 0, 0, StringFormat("MAX_POSITIONS open=%d", open));
      return 0;
     }
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t))
      return 0;
   const double anchor = buy ? t.ask : t.bid;
   anchorOut = anchor;
   const double minDist = (double)MathMax(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
                                          SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL)) * _Point;
   int placed = 0;
   for(int k = 0; k < levels; k++)
     {
      double price = NormalizeDouble(buy ? anchor + InpFirstOffset + k * InpStepPrice
                                         : anchor - InpFirstOffset - k * InpStepPrice, _Digits);
      double sl = NormalizeDouble(buy ? price - InpSLPrice : price + InpSLPrice, _Digits);
      MqlTick now;
      if(!SymbolInfoTick(_Symbol, now))
         break;
      // gia da chay qua bac nay trong luc dat -> bo bac (log Passview cung thieu bac trong cung o 19% chu ky)
      double room = buy ? price - now.ask : now.bid - price;
      if(room <= minDist)
        {
         rejected++;
         continue;
        }
      ENUM_ORDER_TYPE_TIME tt = g_useExpiry ? ORDER_TIME_SPECIFIED : ORDER_TIME_GTC;
      datetime exp = g_useExpiry ? TimeCurrent() + InpPendingExpirySec : 0;
      bool ok = buy ? g_trade.BuyStop(InpLot, price, _Symbol, sl, 0.0, tt, exp, InpOrderComment)
                    : g_trade.SellStop(InpLot, price, _Symbol, sl, 0.0, tt, exp, InpOrderComment);
      uint rc = g_trade.ResultRetcode();
      if(ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED))
        {
         placed++;
         g_consecErrors = 0;
         continue;
        }
      if(rc == TRADE_RETCODE_INVALID_EXPIRATION && g_useExpiry)
        {
         g_useExpiry = false;   // san khong nhan het han -> dung GTC, dat lai bac nay
         LogRow("INFO", "", 0, 0, 0, 0, 0, 0, "expiration rejected by broker -> GTC", rc);
         k--;
         continue;
        }
      rejected++;
      if(rc == TRADE_RETCODE_INVALID_PRICE || rc == TRADE_RETCODE_INVALID_STOPS || rc == TRADE_RETCODE_PRICE_OFF ||
         rc == TRADE_RETCODE_PRICE_CHANGED || rc == TRADE_RETCODE_REQUOTE)
         continue;              // gia chay nhanh: binh thuong, khong tinh la loi
      HandleError(rc, buy ? "PLACE_BUY_STOP" : "PLACE_SELL_STOP");
      if(NowMs() < g_pauseUntilMs)
         break;
     }
   return placed;
  }

void PlaceGrid(const int canceled)
  {
   g_cycle++;
   g_stCycles++;
   int rejB, rejS;
   double ancB, ancS;
   int pB = PlaceSide(true, rejB, ancB);     // Passview: BUY STOP truoc
   int pS = 0;
   rejS = 0;
   ancS = 0;
   if(NowMs() >= g_pauseUntilMs)
      pS = PlaceSide(false, rejS, ancS);     // roi SELL STOP
   g_stPlaced += pB + pS;
   g_stRejected += rejB + rejS;
   if(InpLogGrid)
      LogRow("GRID", "", 0, 0, ancB, ancS, ancB - ancS, InpLot,
             StringFormat("canceled=%d buy_placed=%d buy_skipped=%d sell_placed=%d sell_skipped=%d", canceled, pB, rejB, pS, rejS));
  }

//====================================================================
// Dong lenh
//====================================================================
void CloseAllPositions(const string why)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !IsOurPosition())
         continue;
      if(!g_trade.PositionClose(tk, InpSlippagePoints) ||
         (g_trade.ResultRetcode() != TRADE_RETCODE_DONE && g_trade.ResultRetcode() != TRADE_RETCODE_DONE_PARTIAL))
         HandleError(g_trade.ResultRetcode(), "CLOSE " + why, tk);
     }
  }

//====================================================================
// Trailing stop: giu SL goc cho toi khi lai >= InpTrailStart,
// sau do SL = gia - InpTrailDist (BUY theo Bid, SELL theo Ask)
//====================================================================
void Trail()
  {
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t))
      return;
   const double stopLvl = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   const double frz     = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !IsOurPosition())
         continue;
      bool buy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      double px   = buy ? t.bid : t.ask;
      double gain = buy ? px - open : open - px;
      if(gain < InpTrailStart - 1e-9)
         continue;
      double nsl = NormalizeDouble(buy ? px - InpTrailDist : px + InpTrailDist, _Digits);
      bool better = (sl <= 0) || (buy ? nsl >= sl + InpTrailStep - 1e-9 : nsl <= sl - InpTrailStep + 1e-9);
      if(!better)
         continue;
      double dist = buy ? px - nsl : nsl - px;
      if(dist <= stopLvl || (frz > 0 && sl > 0 && MathAbs(px - sl) <= frz))
         continue;
      if(g_trade.PositionModify(tk, nsl, tp) && g_trade.ResultRetcode() == TRADE_RETCODE_DONE)
        {
         if(InpLogTrail)
            LogRow("TRAIL", buy ? "BUY" : "SELL", tk, tk, nsl, sl, buy ? nsl - open : open - nsl, PositionGetDouble(POSITION_VOLUME), "");
        }
      else
        {
         uint rc = g_trade.ResultRetcode();
         if(rc != TRADE_RETCODE_INVALID_STOPS && rc != TRADE_RETCODE_PRICE_CHANGED && rc != TRADE_RETCODE_FROZEN)
            HandleError(rc, "TRAIL", tk);
        }
     }
  }

//====================================================================
// Gioi han ngay / sut giam
//====================================================================
double RealizedSince(const datetime from)
  {
   double pnl = 0;
   if(!HistorySelect(from, TimeCurrent() + 60))
      return 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
     {
      ulong d = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(d, DEAL_MAGIC) != InpMagic || HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol)
         continue;
      pnl += HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_COMMISSION) +
             HistoryDealGetDouble(d, DEAL_SWAP) + HistoryDealGetDouble(d, DEAL_FEE);
     }
   return pnl;
  }

double FloatingPnL()
  {
   double f = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetTicket(i) != 0 && IsOurPosition())
         f += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   return f;
  }

void UpdateDay()
  {
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   t.hour = 0;
   t.min = 0;
   t.sec = 0;
   datetime d0 = StructToTime(t);
   if(d0 == g_dayStart)
      return;
   g_dayStart = d0;
   g_dayStartBal = AccountInfoDouble(ACCOUNT_BALANCE) - RealizedSince(d0);
   g_dayStopped = false;
   g_dayStopWhy = "";
   g_sessionClosed = false;
  }

void CheckRiskLimits()
  {
   double dd = DrawdownPct();
   g_stMaxDD = MathMax(g_stMaxDD, dd);
   if(g_dayStopped)
      return;
   if(InpMaxDrawdownPct > 0 && dd >= InpMaxDrawdownPct)
     {
      g_dayStopped = true;
      g_dayStopWhy = StringFormat("MAX_DRAWDOWN %.2f%%", dd);
      LogRow("RISK_STOP", "", 0, 0, 0, 0, dd, 0, g_dayStopWhy + " -> cancel grid, close all");
      CancelAllPending();
      CloseAllPositions("MAX_DRAWDOWN");
      g_gridActive = false;
      return;
     }
   static long lastDayCheck = 0;
   long now = NowMs();
   if(InpDailyLossPct > 0 && g_dayStartBal > 0 && now - lastDayCheck >= 1000)
     {
      lastDayCheck = now;
      double day = RealizedSince(g_dayStart) + FloatingPnL();
      if(day <= -InpDailyLossPct / 100.0 * g_dayStartBal)
        {
         g_dayStopped = true;
         g_dayStopWhy = StringFormat("DAILY_LOSS %.2f", day);
         LogRow("RISK_STOP", "", 0, 0, 0, 0, day, 0, g_dayStopWhy + " -> cancel grid, keep SL/trailing");
         CancelAllPending();
         g_gridActive = false;
        }
     }
  }

//====================================================================
// Chu ky luoi
//====================================================================
string BlockReason()
  {
   if(g_dayStopped)
      return "DAY_STOPPED " + g_dayStopWhy;
   if(!InSession())
      return "OUT_OF_SESSION";
   if(!g_tester && (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED)))
      return "ALGO_TRADING_OFF";
   if(InpMaxSpreadPrice > 0 && Spread() > InpMaxSpreadPrice)
      return "SPREAD_HIGH";
   return "";
  }

void CycleStep()
  {
   UpdateDay();
   CheckRiskLimits();
   string why = BlockReason();
   if(why != "")
     {
      if(g_gridActive || CountPending() > 0)
        {
         int n = CancelAllPending();
         g_gridActive = false;
         if(InpLogGrid)
            LogRow("GRID_CANCEL", "", 0, 0, 0, 0, 0, 0, StringFormat("canceled=%d reason=%s", n, why));
        }
      if(why != g_block)
        {
         g_block = why;
         LogRow("PAUSE", "", 0, 0, 0, 0, Spread(), 0, why);
        }
      if(why == "OUT_OF_SESSION" && InpCloseAtSessionEnd && !g_sessionClosed)
        {
         g_sessionClosed = true;
         int nb, ns;
         CountPositions(nb, ns);
         if(nb + ns > 0)
           {
            LogRow("SESSION_CLOSE", "", 0, 0, 0, 0, 0, 0, StringFormat("close %d positions", nb + ns));
            CloseAllPositions("SESSION_END");
           }
        }
      return;
     }
   if(g_block != "")
     {
      LogRow("RESUME", "", 0, 0, 0, 0, Spread(), 0, "after " + g_block);
      g_block = "";
     }
   g_sessionClosed = false;
   long now = NowMs();
   if(now < g_pauseUntilMs)
     {
      // dang tam dung sau loi: van huy luoi cu dung han, khong de lenh cho treo
      if(g_gridActive && now - g_placedMs >= (long)InpRefreshMs)
        {
         CancelAllPending();
         g_gridActive = false;
        }
      return;
     }
   if(g_gridActive && now - g_placedMs < (long)InpRefreshMs)
      return;
   int canceled = CancelAllPending();
   PlaceGrid(canceled);
   g_placedMs = NowMs();
   g_gridActive = true;
  }

//====================================================================
// Su kien chuan
//====================================================================
int OnInit()
  {
   g_tester = (bool)MQLInfoInteger(MQL_TESTER);
   long mode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(mode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      Alert("Passview Replica ", EA_VERSION, ": tài khoản ",
            mode == ACCOUNT_MARGIN_MODE_RETAIL_NETTING ? "NETTING" : "EXCHANGE",
            " KHÔNG được hỗ trợ. Bot cần giữ đồng thời nhiều vị thế BUY và SELL (hedging).");
      return INIT_FAILED;
     }
   bool demo = AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO;
   if(!g_tester && !demo && !InpAllowRealAccount)
     {
      Alert("Passview Replica: đây là tài khoản THẬT. Bật 'Cho phép chạy tài khoản THẬT' nếu chắc chắn.");
      return INIT_FAILED;
     }
   g_sessStart = ParseHM(InpSessionStart);
   g_sessEnd   = ParseHM(InpSessionEnd);
   if(InpLevels < 1 || InpStepPrice <= 0 || InpFirstOffset < 0 || InpLot <= 0 || InpSLPrice <= 0 ||
      InpRefreshMs < 100 || InpTrailDist <= 0 || InpTrailStart < 0 || InpTrailStep < 0 ||
      (InpUseSession && (g_sessStart < 0 || g_sessEnd < 0)))
     {
      Print("[PVR2] Tham số không hợp lệ (bậc, bước, lot, SL, trailing hoặc giờ HH:MM).");
      return INIT_PARAMETERS_INCORRECT;
     }
   long om = SymbolInfoInteger(_Symbol, SYMBOL_ORDER_MODE);
   if((om & SYMBOL_ORDER_STOP) == 0 || (om & SYMBOL_ORDER_SL) == 0)
     {
      Alert("Passview Replica: symbol ", _Symbol, " không cho phép lệnh Stop kèm SL.");
      return INIT_FAILED;
     }
   long maxOrders = AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
   if(maxOrders > 0 && maxOrders < 2 * InpLevels)
      PrintFormat("[PVR2] Cảnh báo: sàn chỉ cho %I64d lệnh chờ, lưới cần %d.", maxOrders, 2 * InpLevels);
   long em = SymbolInfoInteger(_Symbol, SYMBOL_EXPIRATION_MODE);
   g_useExpiry = InpPendingExpirySec > 0 && (em & SYMBOL_EXPIRATION_SPECIFIED) != 0;

   g_trade.SetExpertMagicNumber((ulong)InpMagic);
   g_trade.SetDeviationInPoints(InpSlippagePoints);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.SetAsyncMode(false);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   g_gridActive = false;       // lenh cho cu (neu co) se bi huy o chu ky dau tien
   g_pauseUntilMs = 0;
   g_consecErrors = 0;
   g_block = "";
   g_dayStart = 0;
   UpdateDay();

   int nb, ns;
   CountPositions(nb, ns);
   int np = CountPending();
   LogRow("START", "", 0, 0, 0, 0, 0, InpLot,
          StringFormat("%s levels=%d step=%.2f offset=%.2f sl=%.2f refresh=%dms trail=%.2f/%.2f session=%s-%s expiry=%s",
                       g_tester ? "TESTER" : (demo ? "DEMO" : "REAL"), InpLevels, InpStepPrice, InpFirstOffset, InpSLPrice,
                       InpRefreshMs, InpTrailStart, InpTrailDist, InpSessionStart, InpSessionEnd, g_useExpiry ? "yes" : "no"));
   if(nb + ns + np > 0)
     {
      LogRow("RECOVER", "", 0, 0, 0, 0, 0, 0,
             StringFormat("found open_buy=%d open_sell=%d pending=%d -> trailing continues, old pending replaced", nb, ns, np));
      PrintFormat("[PVR2] Khôi phục: %d BUY, %d SELL đang mở, %d lệnh chờ cũ sẽ được thay.", nb, ns, np);
     }
   EventSetMillisecondTimer(200);
   PrintFormat("[PVR2] %s khởi động %s | %d bậc x %.2f | lot %.2f | SL %.2f | làm mới %d ms | trailing %.2f/%.2f",
               EA_VERSION, _Symbol, InpLevels, InpStepPrice, InpLot, InpSLPrice, InpRefreshMs, InpTrailStart, InpTrailDist);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   // lenh cho khong duoc quan ly khi EA tat: huy tru khi chi doi timeframe/tham so (se dat lai ngay)
   if(reason != REASON_CHARTCHANGE && reason != REASON_PARAMETERS && reason != REASON_RECOMPILE)
     {
      int n = CancelAllPending();
      if(n > 0)
         LogRow("GRID_CANCEL", "", 0, 0, 0, 0, 0, 0, StringFormat("canceled=%d reason=deinit_%d", n, reason));
     }
   PrintFormat("[PVR2 Summary] chu kỳ %d | lệnh chờ đặt %d, bỏ %d | khớp %d | đóng %d | lỗi %d | vị thế mở lớn nhất %d | DD lớn nhất %.2f%%",
               g_stCycles, g_stPlaced, g_stRejected, g_stFills, g_stCloses, g_stErrors, g_stMaxOpen, g_stMaxDD);
   LogRow("STOP", "", 0, 0, 0, 0, 0, 0, StringFormat("reason=%d cycles=%d fills=%d closes=%d errors=%d", reason, g_stCycles, g_stFills,
          g_stCloses, g_stErrors));
   if(g_logH != INVALID_HANDLE)
     {
      FileClose(g_logH);
      g_logH = INVALID_HANDLE;
     }
   Comment("");
  }

void OnTick()
  {
   Trail();
   CycleStep();
   int nb, ns;
   CountPositions(nb, ns);
   g_stMaxOpen = MathMax(g_stMaxOpen, MathMax(nb, ns));
   if(!g_tester || MQLInfoInteger(MQL_VISUAL_MODE))
      Comment(StringFormat("Passview Replica %s | %s | Magic %I64d\nChu kỳ %d | BUY %d | SELL %d | lệnh chờ %d\n"
                           "Spread %.2f | DD %.2f%% | lỗi %d\n%s",
                           EA_VERSION, _Symbol, InpMagic, g_cycle, nb, ns, CountPending(), Spread(), DrawdownPct(),
                           g_stErrors, g_block == "" ? "Đang chạy" : "Ngưng đặt lưới: " + g_block));
  }

void OnTimer()
  {
   CycleStep();   // van lam moi luoi khi khong co tick
   if(g_logH != INVALID_HANDLE && !g_tester)
      FileFlush(g_logH);
  }

// ghi moi lan khop / dong de so sanh voi Passview
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.symbol != _Symbol)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;
   long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   ulong posId = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   if(magic != InpMagic)
     {
      // dong tay (magic 0): chi nhan neu vi the goc la cua EA
      if(entry == DEAL_ENTRY_IN || !HistorySelectByPosition(posId) || HistoryDealsTotal() == 0 ||
         HistoryDealGetInteger(HistoryDealGetTicket(0), DEAL_MAGIC) != InpMagic)
         return;
      HistoryDealSelect(trans.deal);
     }
   long   dtype = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   double price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   double vol   = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
   if(entry == DEAL_ENTRY_IN)
     {
      g_stFills++;
      bool buy = dtype == DEAL_TYPE_BUY;
      double req = HistoryOrderSelect(trans.order) ? HistoryOrderGetDouble(trans.order, ORDER_PRICE_OPEN) : 0;
      double slip = req > 0 ? (buy ? price - req : req - price) : 0;   // + = khop xau hon gia stop
      LogRow("FILL", buy ? "BUY" : "SELL", trans.deal, posId, price, req, slip, vol,
             StringFormat("commission=%.2f", HistoryDealGetDouble(trans.deal, DEAL_COMMISSION)));
     }
   else
     {
      g_stCloses++;
      bool posBuy = dtype == DEAL_TYPE_SELL;   // dong BUY bang deal SELL
      double net = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION) +
                   HistoryDealGetDouble(trans.deal, DEAL_SWAP) + HistoryDealGetDouble(trans.deal, DEAL_FEE);
      string rs = EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON));
      LogRow("CLOSE", posBuy ? "BUY" : "SELL", trans.deal, posId, price, 0, net, vol,
             StringFormat("reason=%s profit=%.2f comment=%s", rs, HistoryDealGetDouble(trans.deal, DEAL_PROFIT),
                          HistoryDealGetString(trans.deal, DEAL_COMMENT)));
     }
  }

double OnTester()
  {
   PrintFormat("[PVR2 Tester] chu kỳ %d | khớp %d | đóng %d | bỏ bậc %d | lỗi %d | vị thế mở lớn nhất %d | DD equity lớn nhất %.2f%%",
               g_stCycles, g_stFills, g_stCloses, g_stRejected, g_stErrors, g_stMaxOpen, g_stMaxDD);
   return TesterStatistics(STAT_PROFIT);
  }
//+------------------------------------------------------------------+
