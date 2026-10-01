//+------------------------------------------------------------------+
//| IDHG_Order.mqh                                                   |
//| ORDER MANAGER — module DUY NHẤT gửi lệnh.                         |
//| - Mở BUY/SELL market (initial + level), đóng position.            |
//| - Kiểm tra broker: quyền giao dịch, volume, spread, margin,       |
//|   OrderCheck; deviation; filling mode.                           |
//| - Theo dõi request: SENDING → OPEN (broker xác nhận) / FAILED.    |
//| - Không bao giờ coi OrderSend thành công = position đã mở/đóng    |
//|   nếu chưa có deal/position xác nhận.                             |
//+------------------------------------------------------------------+
#ifndef IDHG_ORDER_MQH
#define IDHG_ORDER_MQH

#include "IDHG_Config.mqh"

enum ENUM_IDHG_EXEC_EVENT
  {
   IDHG_EV_NONE = 0,
   IDHG_EV_OPEN_CONFIRMED,     // broker xác nhận deal IN → position tồn tại
   IDHG_EV_OPEN_PENDING,       // broker nhận lệnh, chưa có deal → giữ SENDING
   IDHG_EV_OPEN_FAILED,        // broker từ chối (retcode)
   IDHG_EV_OPEN_BLOCKED,       // không gửi vì kiểm tra trước thất bại (reason)
   IDHG_EV_CLOSE_SENT,         // đã gửi lệnh đóng, chờ xác nhận
   IDHG_EV_CLOSE_CONFIRMED,    // deal OUT xác nhận position đã đóng
   IDHG_EV_CLOSE_FAILED,       // lệnh đóng bị từ chối
   IDHG_EV_CLOSE_SKIPPED       // đang có lệnh đóng chờ cho ticket này (chống trùng)
  };

struct SIdhgExecEvent
  {
   ENUM_IDHG_EXEC_EVENT type;
   ENUM_IDHG_SIDE    side;
   int               cycleId;
   int               levelId;
   bool              isInitial;
   ulong             position;
   ulong             order;
   ulong             deal;
   double            price;
   double            volume;
   double            logicalPrice;
   datetime          time;
   uint              retcode;
   ENUM_IDHG_REASON  reason;
   bool              transient;
   ENUM_IDHG_CLOSE_REASON closeReason;
   double            profit;          // deal OUT: profit+swap+commission+fee
   string            note;

   void              Reset(void)
     {
      type = IDHG_EV_NONE; side = IDHG_BUY; cycleId = 0; levelId = IDHG_NO_LEVEL; isInitial = false;
      position = 0; order = 0; deal = 0; price = 0; volume = 0; logicalPrice = 0; time = 0; retcode = 0;
      reason = IDHG_R_NONE; transient = false; closeReason = IDHG_CR_NONE; profit = 0; note = "";
     }
  };

//--- Một request mở đang chờ xác nhận
struct SIdhgOpenRequest
  {
   ENUM_IDHG_SIDE    side;
   int               cycleId;
   int               levelId;
   bool              isInitial;
   double            lot;
   double            logicalPrice;
   double            requestPrice;
   ulong             order;
   datetime          sentTime;
   uint              retcode;

   void              Reset(void)
     {
      side = IDHG_BUY; cycleId = 0; levelId = IDHG_NO_LEVEL; isInitial = false; lot = 0; logicalPrice = 0;
      requestPrice = 0; order = 0; sentTime = 0; retcode = 0;
     }
  };

//==================================================================//
// Hàm thuần logic (test được trong MT5 script và host)             //
//==================================================================//

bool IdhgIsSuccessRetcode(const uint rc)
  {
   return rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED;
  }

//--- Lỗi tạm thời: có thể gửi lại (có giới hạn số lần)
bool IdhgIsTransientRetcode(const uint rc)
  {
   return rc == TRADE_RETCODE_REQUOTE || rc == TRADE_RETCODE_PRICE_CHANGED || rc == TRADE_RETCODE_PRICE_OFF ||
          rc == TRADE_RETCODE_TIMEOUT || rc == TRADE_RETCODE_CONNECTION || rc == TRADE_RETCODE_TOO_MANY_REQUESTS ||
          rc == TRADE_RETCODE_LOCKED || rc == TRADE_RETCODE_ERROR;
  }

ENUM_IDHG_REASON IdhgReasonFromRetcode(const uint rc)
  {
   if(rc == TRADE_RETCODE_NO_MONEY)
      return IDHG_R_SKIPPED_MARGIN;
   if(rc == TRADE_RETCODE_INVALID_VOLUME || rc == TRADE_RETCODE_LIMIT_VOLUME)
      return IDHG_R_SKIPPED_VOLUME;
   if(rc == TRADE_RETCODE_TRADE_DISABLED || rc == TRADE_RETCODE_CLIENT_DISABLES_AT || rc == TRADE_RETCODE_SERVER_DISABLES_AT ||
      rc == TRADE_RETCODE_LONG_ONLY || rc == TRADE_RETCODE_SHORT_ONLY || rc == TRADE_RETCODE_CLOSE_ONLY ||
      rc == TRADE_RETCODE_HEDGE_PROHIBITED)
      return IDHG_R_SKIPPED_TRADE_DISABLED;
   if(rc == TRADE_RETCODE_LIMIT_POSITIONS || rc == TRADE_RETCODE_LIMIT_ORDERS)
      return IDHG_R_SKIPPED_MAX_ORDERS;
   if(IdhgIsTransientRetcode(rc))
      return IDHG_R_FAILED_TRANSIENT;
   return IDHG_R_SKIPPED_BROKER_ERROR;
  }

//--- Chọn kiểu filling theo SYMBOL_FILLING_MODE (bitmask)
ENUM_ORDER_TYPE_FILLING IdhgSelectFilling(const long fillingMode)
  {
   if((fillingMode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;
   if((fillingMode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
  }

//--- Kiểm tra trước khi gửi (không gọi broker). marginRequired < 0 = không tính được.
ENUM_IDHG_REASON IdhgPreTradeCheck(const SIdhgCandidate &c, const SIdhgMarket &mk, const SIdhgSymbolSpec &spec,
                                   const SIdhgAccountSnap &acc, const double marginRequired, const double maxSpread,
                                   const double sideOpenVolume)
  {
   if(c.reason != IDHG_R_NONE)
      return c.reason;
   if(!mk.valid || mk.bid <= 0.0 || mk.ask <= 0.0)
      return IDHG_R_SKIPPED_BROKER_ERROR;
   if(maxSpread > 0.0 && mk.spread > maxSpread + IDHG_EPS)
      return IDHG_R_SKIPPED_SPREAD;
   double lot = LotNormalize(c.lot, spec.volMin, spec.volMax, spec.volStep, 0.0, 0.0);
   if(lot <= 0.0 || !IdhgEQ(lot, c.lot))
      return IDHG_R_SKIPPED_VOLUME;
   if(spec.volLimit > 0.0 && sideOpenVolume + lot > spec.volLimit + IDHG_EPS)
      return IDHG_R_SKIPPED_VOLUME;
   if(marginRequired >= 0.0 && acc.valid && marginRequired > acc.freeMargin)
      return IDHG_R_SKIPPED_MARGIN;
   return IDHG_R_NONE;
  }

//--- Dựng request mở market. BUY theo Ask, SELL theo Bid.
void IdhgBuildOpenRequest(const SIdhgCandidate &c, const SIdhgMarket &mk, const SIdhgSymbolSpec &spec, const long magic,
                          const string prefix, const int deviation, MqlTradeRequest &req)
  {
   ZeroMemory(req);
   req.action = TRADE_ACTION_DEAL;
   req.symbol = spec.name;
   req.magic = (ulong)magic;
   req.volume = c.lot;
   req.type = (c.side == IDHG_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price = PriceNormalize((c.side == IDHG_BUY) ? mk.ask : mk.bid, spec.tickSize, spec.digits);
   req.deviation = (ulong)deviation;
   req.type_filling = IdhgSelectFilling(spec.fillingMode);
   req.type_time = ORDER_TIME_GTC;
   req.sl = 0.0;   // mặc định KHÔNG SL/TP phía broker
   req.tp = 0.0;
   req.comment = IdhgBuildComment(prefix, c.cycleId, c.side, c.levelId, c.logicalPrice, spec.digits);
  }

//--- Dựng request đóng position (lệnh ngược chiều, cùng volume)
void IdhgBuildCloseRequest(const ulong ticket, const ENUM_IDHG_SIDE side, const double volume, const SIdhgMarket &mk,
                           const SIdhgSymbolSpec &spec, const long magic, const int deviation, const string comment,
                           MqlTradeRequest &req)
  {
   ZeroMemory(req);
   req.action = TRADE_ACTION_DEAL;
   req.symbol = spec.name;
   req.magic = (ulong)magic;
   req.position = ticket;
   req.volume = volume;
   req.type = (side == IDHG_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   req.price = PriceNormalize((side == IDHG_BUY) ? mk.bid : mk.ask, spec.tickSize, spec.digits);
   req.deviation = (ulong)deviation;
   req.type_filling = IdhgSelectFilling(spec.fillingMode);
   req.type_time = ORDER_TIME_GTC;
   req.comment = comment;
  }

string IdhgCloseTag(const ENUM_IDHG_CLOSE_REASON r)
  {
   switch(r)
     {
      case IDHG_CR_INDIVIDUAL_TP: return "ITP";
      case IDHG_CR_BASKET_TP:     return "BTP";
      case IDHG_CR_SIDE_TOTAL_TP: return "STP";
      case IDHG_CR_EMERGENCY:     return "EMG";
      case IDHG_CR_MANUAL_PROFIT: return "MPF";
      case IDHG_CR_MANUAL_SIDE:   return "MSD";
      case IDHG_CR_MANUAL_ALL:    return "MAL";
      default:                    return "CLS";
     }
  }

//+------------------------------------------------------------------+
//| COrderManager                                                    |
//+------------------------------------------------------------------+
class COrderManager
  {
private:
   long              m_magic;
   string            m_prefix;
   int               m_deviation;
   double            m_maxSpread;
   int               m_confirmTimeout;
   int               m_closeTimeout;
   SIdhgSymbolSpec   m_spec;
   SIdhgOpenRequest  m_req[];
   ulong             m_closingTicket[];
   datetime          m_closingTime[];
   ENUM_IDHG_CLOSE_REASON m_closingReason[];
   CIdhgLog          m_log;
   int               m_sendCount;
   int               m_rejectCount;
   int               m_closeSendCount;

   int               FindRequestByOrder(const ulong order) const
     {
      if(order == 0)
         return -1;
      for(int i = 0; i < ArraySize(m_req); i++)
         if(m_req[i].order == order)
            return i;
      return -1;
     }

   void              RemoveRequest(const int i)
     {
      int n = ArraySize(m_req);
      if(i < 0 || i >= n)
         return;
      for(int k = i; k < n - 1; k++)
         m_req[k] = m_req[k + 1];
      ArrayResize(m_req, n - 1);
     }

   int               FindClosing(const ulong ticket) const
     {
      for(int i = 0; i < ArraySize(m_closingTicket); i++)
         if(m_closingTicket[i] == ticket)
            return i;
      return -1;
     }

   void              RemoveClosing(const int i)
     {
      int n = ArraySize(m_closingTicket);
      if(i < 0 || i >= n)
         return;
      for(int k = i; k < n - 1; k++)
        {
         m_closingTicket[k] = m_closingTicket[k + 1];
         m_closingTime[k] = m_closingTime[k + 1];
         m_closingReason[k] = m_closingReason[k + 1];
        }
      ArrayResize(m_closingTicket, n - 1);
      ArrayResize(m_closingTime, n - 1);
      ArrayResize(m_closingReason, n - 1);
     }

   void              FillFromRequest(const SIdhgOpenRequest &r, SIdhgExecEvent &ev) const
     {
      ev.side = r.side;
      ev.cycleId = r.cycleId;
      ev.levelId = r.levelId;
      ev.isInitial = r.isInitial;
      ev.order = r.order;
      ev.logicalPrice = r.logicalPrice;
      ev.volume = r.lot;
     }

   //--- Xác nhận bằng deal IN trong lịch sử. true nếu deal hợp lệ thuộc EA.
   bool              ReadInDeal(const ulong deal, ulong &posId, double &price, double &volume, ulong &order, datetime &t) const
     {
      if(deal == 0 || !HistoryDealSelect(deal))
         return false;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != m_spec.name)
         return false;
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != m_magic)
         return false;
      if(HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_IN)
         return false;
      posId = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      price = HistoryDealGetDouble(deal, DEAL_PRICE);
      volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
      order = (ulong)HistoryDealGetInteger(deal, DEAL_ORDER);
      t = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      return posId != 0;
     }

   void              LogExec(const string action, const SIdhgExecEvent &ev) const
     {
      m_log.Info(action + " " + IdhgCycleTag(ev.cycleId) + "|" + IdhgSideName(ev.side) + "|" + IdhgLevelTag(ev.levelId) +
                 " logic=" + DoubleToString(ev.logicalPrice, m_spec.digits) + " thực=" + DoubleToString(ev.price, m_spec.digits) +
                 " lot=" + DoubleToString(ev.volume, 2) + " pos=" + IntegerToString((long)ev.position) +
                 " rc=" + IntegerToString((long)ev.retcode) + (ev.reason != IDHG_R_NONE ? " lý do=" + IdhgReasonCode(ev.reason) : "") +
                 (ev.note != "" ? " " + ev.note : ""));
     }

public:
                     COrderManager(void) : m_magic(0), m_prefix(""), m_deviation(0), m_maxSpread(0), m_confirmTimeout(10),
                     m_closeTimeout(15), m_sendCount(0), m_rejectCount(0), m_closeSendCount(0) { m_spec.Reset(); }

   void              Configure(const SIdhgConfig &cfg, const SIdhgSymbolSpec &spec)
     {
      m_magic = cfg.general.magic;
      m_prefix = cfg.general.commentPrefix;
      m_deviation = cfg.general.deviationPoints;
      m_maxSpread = cfg.risk.maxSpread;
      m_confirmTimeout = cfg.general.confirmTimeoutSec;
      m_closeTimeout = cfg.general.closeTimeoutSec;
      m_spec = spec;
      m_log.SetThrottle(cfg.general.logThrottleSec);
     }

   void              SetQuiet(const bool q) { m_log.SetQuiet(q); }
   int               PendingOpenCount(void) const { return ArraySize(m_req); }
   int               ClosingCount(void) const { return ArraySize(m_closingTicket); }
   int               SendCount(void) const { return m_sendCount; }
   int               RejectCount(void) const { return m_rejectCount; }
   int               CloseSendCount(void) const { return m_closeSendCount; }

   bool              HasPendingOpen(const ENUM_IDHG_SIDE side, const int cycleId, const int levelId) const
     {
      for(int i = 0; i < ArraySize(m_req); i++)
         if(m_req[i].side == side && m_req[i].cycleId == cycleId && m_req[i].levelId == levelId)
            return true;
      return false;
     }

   //--- Tìm position của EA đang mở cho (cycle, side, level) — chống trùng sau restart / timeout
   bool              FindPositionForLevel(const int cycleId, const ENUM_IDHG_SIDE side, const int levelId, ulong &ticket) const
     {
      ticket = 0;
      int total = PositionsTotal();
      for(int i = 0; i < total; i++)
        {
         ulong t = PositionGetTicket(i);
         if(t == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != m_spec.name || PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;
         SIdhgCommentInfo info;
         if(!IdhgParseComment(PositionGetString(POSITION_COMMENT), m_prefix, m_spec.digits, info))
            continue;
         if(info.cycleId == cycleId && info.side == side && info.levelId == levelId)
           {
            ticket = t;
            return true;
           }
        }
      return false;
     }

   //--- Gửi lệnh mở cho một candidate. Kết quả trả qua 'ev'.
   void              SendOpen(const SIdhgCandidate &c, const SIdhgMarket &mk, const SIdhgAccountSnap &acc,
                              const double sideOpenVolume, const datetime now, SIdhgExecEvent &ev)
     {
      ev.Reset();
      ev.side = c.side;
      ev.cycleId = c.cycleId;
      ev.levelId = c.levelId;
      ev.isInitial = c.isInitial;
      ev.logicalPrice = c.logicalPrice;
      ev.volume = c.lot;
      ev.time = now;
      //--- 1) chống trùng: đã có request chờ hoặc position đang mở cho level này
      if(HasPendingOpen(c.side, c.cycleId, c.levelId))
        {
         ev.type = IDHG_EV_OPEN_BLOCKED;
         ev.reason = IDHG_R_SKIPPED_DUPLICATE;
         ev.note = "request đang chờ";
         return;
        }
      ulong existing = 0;
      if(FindPositionForLevel(c.cycleId, c.side, c.levelId, existing))
        {
         ev.type = IDHG_EV_OPEN_BLOCKED;
         ev.reason = IDHG_R_SKIPPED_DUPLICATE;
         ev.position = existing;
         ev.note = "position đã tồn tại";
         LogExec("CHẶN TRÙNG", ev);
         return;
        }
      //--- 2) quyền giao dịch
      string why;
      if(!IdhgTradePermitted(m_spec, c.side, why))
        {
         ev.type = IDHG_EV_OPEN_BLOCKED;
         ev.reason = IDHG_R_SKIPPED_TRADE_DISABLED;
         ev.note = why;
         LogExec("KHÔNG GỬI", ev);
         return;
        }
      //--- 3) spread / volume / margin
      double margin = -1.0;
      double m = 0.0;
      ENUM_ORDER_TYPE type = (c.side == IDHG_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      double px = (c.side == IDHG_BUY) ? mk.ask : mk.bid;
      if(OrderCalcMargin(type, m_spec.name, c.lot, px, m))
         margin = m;
      ENUM_IDHG_REASON r = IdhgPreTradeCheck(c, mk, m_spec, acc, margin, m_maxSpread, sideOpenVolume);
      if(r != IDHG_R_NONE)
        {
         ev.type = IDHG_EV_OPEN_BLOCKED;
         ev.reason = r;
         ev.note = (r == IDHG_R_SKIPPED_SPREAD) ? "spread=" + DoubleToString(mk.spread, m_spec.digits) :
                   (r == IDHG_R_SKIPPED_MARGIN) ? "margin cần=" + DoubleToString(margin, 2) + " free=" + DoubleToString(acc.freeMargin, 2) : "";
         LogExec("KHÔNG GỬI", ev);
         return;
        }
      //--- 4) dựng request + OrderCheck phía terminal
      MqlTradeRequest req;
      MqlTradeResult res;
      MqlTradeCheckResult chk;
      IdhgBuildOpenRequest(c, mk, m_spec, m_magic, m_prefix, m_deviation, req);
      ZeroMemory(chk);
      if(!OrderCheck(req, chk))
        {
         ev.type = IDHG_EV_OPEN_FAILED;
         ev.retcode = chk.retcode;
         ev.reason = IdhgReasonFromRetcode(chk.retcode);
         ev.transient = IdhgIsTransientRetcode(chk.retcode);
         ev.note = "OrderCheck";
         m_rejectCount++;
         LogExec("OrderCheck TỪ CHỐI", ev);
         return;
        }
      //--- 5) gửi
      SIdhgOpenRequest rq;
      rq.Reset();
      rq.side = c.side;
      rq.cycleId = c.cycleId;
      rq.levelId = c.levelId;
      rq.isInitial = c.isInitial;
      rq.lot = c.lot;
      rq.logicalPrice = c.logicalPrice;
      rq.requestPrice = req.price;
      rq.sentTime = now;
      ZeroMemory(res);
      ResetLastError();
      bool sent = OrderSend(req, res);
      m_sendCount++;
      ev.retcode = res.retcode;
      ev.order = res.order;
      if(!sent || !IdhgIsSuccessRetcode(res.retcode))
        {
         ev.type = IDHG_EV_OPEN_FAILED;
         if(res.retcode == 0)
            ev.note = "OrderSend lỗi " + IntegerToString(GetLastError());
         ev.reason = IdhgReasonFromRetcode(res.retcode);
         ev.transient = IdhgIsTransientRetcode(res.retcode);
         m_rejectCount++;
         LogExec("BROKER TỪ CHỐI", ev);
         return;
        }
      //--- 6) xác nhận: chỉ khi có deal IN thật trong lịch sử
      ulong posId = 0, ord = 0;
      double dpx = 0, dvol = 0;
      datetime dt = 0;
      if(res.deal > 0 && ReadInDeal(res.deal, posId, dpx, dvol, ord, dt))
        {
         ev.type = IDHG_EV_OPEN_CONFIRMED;
         ev.position = posId;
         ev.deal = res.deal;
         ev.price = dpx;
         ev.volume = dvol;
         ev.time = dt;
         LogExec("MỞ", ev);
         return;
        }
      //--- chưa có xác nhận: lưu request để chờ OnTradeTransaction / đối soát
      rq.order = res.order;
      rq.retcode = res.retcode;
      int n = ArraySize(m_req);
      ArrayResize(m_req, n + 1);
      m_req[n] = rq;
      ev.type = IDHG_EV_OPEN_PENDING;
      LogExec("CHỜ XÁC NHẬN", ev);
     }

   //--- OnTradeTransaction: xác nhận mở / đóng. Trả về số event thêm vào.
   int               OnTransaction(const MqlTradeTransaction &t, SIdhgExecEvent &out[])
     {
      if(t.type != TRADE_TRANSACTION_DEAL_ADD || t.deal == 0)
         return 0;
      if(!HistoryDealSelect(t.deal))
         return 0;
      if(HistoryDealGetString(t.deal, DEAL_SYMBOL) != m_spec.name || HistoryDealGetInteger(t.deal, DEAL_MAGIC) != m_magic)
         return 0;
      long entry = HistoryDealGetInteger(t.deal, DEAL_ENTRY);
      SIdhgExecEvent ev;
      ev.Reset();
      if(entry == DEAL_ENTRY_IN)
        {
         ulong order = (ulong)HistoryDealGetInteger(t.deal, DEAL_ORDER);
         int i = FindRequestByOrder(order);
         if(i < 0)
            return 0;   // đã xác nhận đồng bộ trước đó (idempotent)
         FillFromRequest(m_req[i], ev);
         ev.type = IDHG_EV_OPEN_CONFIRMED;
         ev.deal = t.deal;
         ev.position = (ulong)HistoryDealGetInteger(t.deal, DEAL_POSITION_ID);
         ev.price = HistoryDealGetDouble(t.deal, DEAL_PRICE);
         ev.volume = HistoryDealGetDouble(t.deal, DEAL_VOLUME);
         ev.time = (datetime)HistoryDealGetInteger(t.deal, DEAL_TIME);
         RemoveRequest(i);
         LogExec("MỞ (xác nhận trễ)", ev);
        }
      else
         if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
           {
            ev.type = IDHG_EV_CLOSE_CONFIRMED;
            ev.deal = t.deal;
            ev.position = (ulong)HistoryDealGetInteger(t.deal, DEAL_POSITION_ID);
            ev.price = HistoryDealGetDouble(t.deal, DEAL_PRICE);
            ev.volume = HistoryDealGetDouble(t.deal, DEAL_VOLUME);
            ev.time = (datetime)HistoryDealGetInteger(t.deal, DEAL_TIME);
            ev.profit = GetNetPL(HistoryDealGetDouble(t.deal, DEAL_PROFIT), HistoryDealGetDouble(t.deal, DEAL_SWAP),
                                 HistoryDealGetDouble(t.deal, DEAL_COMMISSION), HistoryDealGetDouble(t.deal, DEAL_FEE));
            int ci = FindClosing(ev.position);
            ev.closeReason = (ci >= 0) ? m_closingReason[ci] : IDHG_CR_EXTERNAL;
            if(ci >= 0)
               RemoveClosing(ci);
           }
         else
            return 0;
      int n = ArraySize(out);
      ArrayResize(out, n + 1);
      out[n] = ev;
      return 1;
     }

   //--- Đối soát request chờ quá hạn + lệnh đóng quá hạn (gọi từ OnTimer)
   int               CheckPending(const datetime now, SIdhgExecEvent &out[])
     {
      int added = 0;
      for(int i = ArraySize(m_req) - 1; i >= 0; i--)
        {
         if(now - m_req[i].sentTime < m_confirmTimeout)
            continue;
         SIdhgExecEvent ev;
         ev.Reset();
         FillFromRequest(m_req[i], ev);
         ev.time = now;
         bool decided = false;
         //--- tìm deal IN của order trong lịch sử
         if(HistorySelect(m_req[i].sentTime - 60, now + 60))
           {
            int total = HistoryDealsTotal();
            for(int k = 0; k < total && !decided; k++)
              {
               ulong d = HistoryDealGetTicket(k);
               if((ulong)HistoryDealGetInteger(d, DEAL_ORDER) != m_req[i].order || m_req[i].order == 0)
                  continue;
               ulong posId = 0, ord = 0;
               double px = 0, vol = 0;
               datetime dt = 0;
               if(ReadInDeal(d, posId, px, vol, ord, dt))
                 {
                  ev.type = IDHG_EV_OPEN_CONFIRMED;
                  ev.deal = d;
                  ev.position = posId;
                  ev.price = px;
                  ev.volume = vol;
                  ev.time = dt;
                  decided = true;
                  LogExec("MỞ (đối soát)", ev);
                 }
              }
           }
         //--- order bị huỷ/từ chối sau khi nhận
         if(!decided && m_req[i].order != 0 && HistoryOrderSelect(m_req[i].order))
           {
            long st = HistoryOrderGetInteger(m_req[i].order, ORDER_STATE);
            if(st == ORDER_STATE_REJECTED || st == ORDER_STATE_CANCELED || st == ORDER_STATE_EXPIRED)
              {
               ev.type = IDHG_EV_OPEN_FAILED;
               ev.reason = IDHG_R_SKIPPED_BROKER_ERROR;
               ev.note = "order state " + IntegerToString(st);
               decided = true;
               LogExec("BROKER HUỶ", ev);
              }
           }
         //--- quá hạn dài: chỉ báo thất bại sau khi chắc chắn không có position cho level
         if(!decided && now - m_req[i].sentTime >= 3 * m_confirmTimeout)
           {
            ulong existing = 0;
            if(FindPositionForLevel(m_req[i].cycleId, m_req[i].side, m_req[i].levelId, existing) &&
               PositionSelectByTicket(existing))
              {
               ev.type = IDHG_EV_OPEN_CONFIRMED;
               ev.position = existing;
               ev.price = PositionGetDouble(POSITION_PRICE_OPEN);
               ev.volume = PositionGetDouble(POSITION_VOLUME);
               ev.time = (datetime)PositionGetInteger(POSITION_TIME);
               LogExec("MỞ (tìm thấy position)", ev);
              }
            else
              {
               ev.type = IDHG_EV_OPEN_FAILED;
               ev.reason = IDHG_R_FAILED_TRANSIENT;
               ev.transient = true;
               ev.note = "quá hạn xác nhận";
               LogExec("QUÁ HẠN", ev);
              }
            decided = true;
           }
         if(!decided)
            continue;
         RemoveRequest(i);
         int n = ArraySize(out);
         ArrayResize(out, n + 1);
         out[n] = ev;
         added++;
        }
      //--- lệnh đóng quá hạn: nếu position còn → cho phép gửi lại; nếu đã mất → xoá
      for(int j = ArraySize(m_closingTicket) - 1; j >= 0; j--)
        {
         if(now - m_closingTime[j] < m_closeTimeout)
            continue;
         if(PositionSelectByTicket(m_closingTicket[j]))
            m_log.Warn("Lệnh đóng ticket " + IntegerToString((long)m_closingTicket[j]) + " chưa được xác nhận sau " +
                       IntegerToString(m_closeTimeout) + "s — cho phép gửi lại");
         RemoveClosing(j);
        }
      return added;
     }

   bool              IsClosing(const ulong ticket) const { return FindClosing(ticket) >= 0; }

   //--- Position đã biến mất (refresh) → bỏ khỏi danh sách đang đóng
   void              OnPositionGone(const ulong ticket)
     {
      int i = FindClosing(ticket);
      if(i >= 0)
         RemoveClosing(i);
     }

   //--- Đóng 1 position. Chống trùng: mỗi ticket chỉ 1 lệnh đóng chờ xác nhận.
   bool              ClosePosition(const ulong ticket, const ENUM_IDHG_CLOSE_REASON reason, const SIdhgMarket &mk,
                                   const datetime now, SIdhgExecEvent &ev)
     {
      ev.Reset();
      ev.position = ticket;
      ev.closeReason = reason;
      ev.time = now;
      if(IsClosing(ticket))
        {
         ev.type = IDHG_EV_CLOSE_SKIPPED;
         return false;
        }
      if(!PositionSelectByTicket(ticket))
        {
         ev.type = IDHG_EV_CLOSE_SKIPPED;
         ev.note = "position không còn";
         return false;
        }
      if(PositionGetString(POSITION_SYMBOL) != m_spec.name || PositionGetInteger(POSITION_MAGIC) != m_magic)
        {
         ev.type = IDHG_EV_CLOSE_SKIPPED;
         ev.note = "không thuộc EA — không đụng vào";
         return false;
        }
      ENUM_IDHG_SIDE side = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? IDHG_BUY : IDHG_SELL;
      double vol = PositionGetDouble(POSITION_VOLUME);
      ev.side = side;
      ev.volume = vol;
      SIdhgCommentInfo info;
      if(IdhgParseComment(PositionGetString(POSITION_COMMENT), m_prefix, m_spec.digits, info))
        {
         ev.cycleId = info.cycleId;
         ev.levelId = info.levelId;
        }
      MqlTradeRequest req;
      MqlTradeResult res;
      IdhgBuildCloseRequest(ticket, side, vol, mk, m_spec, m_magic, m_deviation, m_prefix + "|X|" + IdhgCloseTag(reason), req);
      ZeroMemory(res);
      ResetLastError();
      bool sent = OrderSend(req, res);
      m_closeSendCount++;
      ev.retcode = res.retcode;
      ev.order = res.order;
      ev.price = res.price;
      if(!sent || !IdhgIsSuccessRetcode(res.retcode))
        {
         ev.type = IDHG_EV_CLOSE_FAILED;
         ev.transient = IdhgIsTransientRetcode(res.retcode);
         m_log.Warn("ĐÓNG thất bại ticket=" + IntegerToString((long)ticket) + " rc=" + IntegerToString((long)res.retcode) +
                    " lý do=" + IdhgCloseReasonName(reason));
         return false;
        }
      //--- KHÔNG coi là đã đóng: chờ deal OUT / position biến mất
      int n = ArraySize(m_closingTicket);
      ArrayResize(m_closingTicket, n + 1);
      ArrayResize(m_closingTime, n + 1);
      ArrayResize(m_closingReason, n + 1);
      m_closingTicket[n] = ticket;
      m_closingTime[n] = now;
      m_closingReason[n] = reason;
      ev.type = IDHG_EV_CLOSE_SENT;
      m_log.Info("ĐÓNG gửi " + IdhgCycleTag(ev.cycleId) + "|" + IdhgSideName(side) + "|" + IdhgLevelTag(ev.levelId) +
                 " ticket=" + IntegerToString((long)ticket) + " lot=" + DoubleToString(vol, 2) + " lý do=" + IdhgCloseReasonName(reason));
      return true;
     }

   //--- Đóng theo danh sách snapshot (side < 0 = cả hai phía; onlyProfitable = chỉ Net > 0)
   int               CloseFiltered(const SIdhgPosition &pos[], const int sideFilter, const bool onlyProfitable,
                                   const ENUM_IDHG_CLOSE_REASON reason, const SIdhgMarket &mk, const datetime now,
                                   SIdhgExecEvent &out[])
     {
      int sent = 0;
      for(int i = 0; i < ArraySize(pos); i++)
        {
         if(sideFilter >= 0 && (int)pos[i].side != sideFilter)
            continue;
         if(onlyProfitable && pos[i].net <= 0.0)
            continue;
         SIdhgExecEvent ev;
         if(ClosePosition(pos[i].ticket, reason, mk, now, ev))
            sent++;
         int n = ArraySize(out);
         ArrayResize(out, n + 1);
         out[n] = ev;
        }
      return sent;
     }

   int               CloseProfitable(const SIdhgPosition &pos[], const ENUM_IDHG_SIDE side, const ENUM_IDHG_CLOSE_REASON reason,
                                     const SIdhgMarket &mk, const datetime now, SIdhgExecEvent &out[])
     { return CloseFiltered(pos, (int)side, true, reason, mk, now, out); }

   int               CloseSide(const SIdhgPosition &pos[], const ENUM_IDHG_SIDE side, const ENUM_IDHG_CLOSE_REASON reason,
                               const SIdhgMarket &mk, const datetime now, SIdhgExecEvent &out[])
     { return CloseFiltered(pos, (int)side, false, reason, mk, now, out); }

   int               CloseAll(const SIdhgPosition &pos[], const ENUM_IDHG_CLOSE_REASON reason, const SIdhgMarket &mk,
                              const datetime now, SIdhgExecEvent &out[])
     { return CloseFiltered(pos, -1, false, reason, mk, now, out); }

   void              ClearAll(void)
     {
      ArrayFree(m_req);
      ArrayFree(m_closingTicket);
      ArrayFree(m_closingTime);
      ArrayFree(m_closingReason);
     }
  };

#endif
