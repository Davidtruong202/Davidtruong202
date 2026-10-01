//+------------------------------------------------------------------+
//| IDHG_Engine.mqh                                                  |
//| Bộ điều phối: nối các module theo sự kiện OnTick / OnTimer /     |
//| OnTradeTransaction. KHÔNG chứa logic nghiệp vụ chi tiết — mỗi    |
//| quyết định nằm trong module tương ứng.                           |
//+------------------------------------------------------------------+
#ifndef IDHG_ENGINE_MQH
#define IDHG_ENGINE_MQH

#include "IDHG_State.mqh"
#include "IDHG_Cycle.mqh"
#include "IDHG_Grid.mqh"
#include "IDHG_Order.mqh"

class CIdhgEngine
  {
public:
   //--- Module (public để dashboard / self-test đọc trạng thái)
   CConfig           m_config;
   CState            m_state;
   CCycleManager     m_cycle;
   CGridEngine       m_grid;
   COrderManager     m_order;
   CIdhgLog          m_log;
   SIdhgSymbolSpec   m_spec;
   SIdhgMarket       m_mk;
   SIdhgAccountSnap  m_acc;
   string            m_symbol;
   bool              m_ready;
   string            m_lastMsg;

private:
   SIdhgConfig       m_cfg;            // bản sao cấu hình hiện hành (đọc nhanh)

   void              SyncConfig(void) { m_config.Get(m_cfg); }

   //--- Đếm position của EA (symbol + magic) và volume theo phía
   int               ScanEaPositions(double &buyVol, double &sellVol) const
     {
      buyVol = 0;
      sellVol = 0;
      int n = 0;
      int total = PositionsTotal();
      for(int i = 0; i < total; i++)
        {
         ulong t = PositionGetTicket(i);
         if(t == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol || PositionGetInteger(POSITION_MAGIC) != m_cfg.general.magic)
            continue;
         n++;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            buyVol += PositionGetDouble(POSITION_VOLUME);
         else
            sellVol += PositionGetDouble(POSITION_VOLUME);
        }
      return n;
     }

public:
                     CIdhgEngine(void) : m_symbol(""), m_ready(false), m_lastMsg("")
     {
      m_spec.Reset();
      m_mk.Reset();
      m_acc.Reset();
      m_cfg.SetDefaults();
     }

   //--- Khởi tạo: HEDGING, symbol, cấu hình. Trả mã INIT_*.
   int               Init(const string symbol, const SIdhgConfig &cfg, string &err)
     {
      err = "";
      m_ready = false;
      m_symbol = symbol;
      if(!IdhgIsHedgingMode(AccountInfoInteger(ACCOUNT_MARGIN_MODE)))
        {
         err = "Tài khoản KHÔNG phải HEDGING — EA từ chối khởi động";
         return INIT_FAILED;
        }
      if(!IdhgReadSymbolSpec(symbol, m_spec))
        {
         string e;
         IdhgCheckSymbolSpec(m_spec, e);
         err = "Thông số symbol không hợp lệ: " + e;
         return INIT_FAILED;
        }
      if(!m_config.Load(cfg))
        {
         err = "Input không hợp lệ: " + m_config.LastError();
         return INIT_PARAMETERS_INCORRECT;
        }
      SyncConfig();
      m_log.SetThrottle(m_cfg.general.logThrottleSec);
      m_grid.SetSymbol(m_spec);
      m_grid.ApplyConfig(m_cfg.grid);
      m_order.Configure(m_cfg, m_spec);
      RefreshMarket();
      RefreshAccount();
      m_ready = true;
      return INIT_SUCCEEDED;
     }

   void              SetQuiet(const bool q) { m_log.SetQuiet(q); m_order.SetQuiet(q); }

   bool              RefreshMarket(void) { return IdhgReadMarket(m_symbol, m_spec, m_mk); }
   void              RefreshAccount(void) { IdhgReadAccount(m_acc); }

   int               EaPositionCount(void) const
     {
      double b, s;
      return ScanEaPositions(b, s);
     }

   //--- Áp dụng kết quả thực thi vào Grid + Cycle
   void              ApplyEvent(const SIdhgExecEvent &e)
     {
      switch(e.type)
        {
         case IDHG_EV_OPEN_CONFIRMED:
            if(e.cycleId == m_grid.CycleId())
               m_grid.MarkOpen(e.side, e.levelId, e.position, e.price, e.time);
            if(e.isInitial && e.cycleId == m_cycle.CycleId())
               m_cycle.ConfirmInitial(e.side, e.position, e.price);
            break;
         case IDHG_EV_OPEN_FAILED:
           {
            bool retry = e.transient && m_grid.Attempts(e.side, e.levelId) < m_cfg.general.maxSendAttempts;
            if(retry)
               m_grid.MarkFailed(e.side, e.levelId, IDHG_R_FAILED_TRANSIENT, (int)e.retcode);
            else
               m_grid.MarkSkipped(e.side, e.levelId, e.transient ? IDHG_R_SKIPPED_BROKER_ERROR : e.reason, (int)e.retcode);
            if(e.isInitial)
               m_cycle.FailInitial(e.side, retry ? IDHG_R_FAILED_TRANSIENT : e.reason);
            break;
           }
         case IDHG_EV_OPEN_BLOCKED:
            if(e.reason == IDHG_R_SKIPPED_DUPLICATE)
              {
               // position đã tồn tại cho level → đồng bộ trạng thái thay vì gửi lại
               if(e.position != 0 && PositionSelectByTicket(e.position))
                 {
                  m_grid.MarkOpen(e.side, e.levelId, e.position, PositionGetDouble(POSITION_PRICE_OPEN),
                                  (datetime)PositionGetInteger(POSITION_TIME));
                  if(e.isInitial)
                     m_cycle.ConfirmInitial(e.side, e.position, PositionGetDouble(POSITION_PRICE_OPEN));
                 }
               break;
              }
            m_grid.MarkSkipped(e.side, e.levelId, e.reason, 0);
            if(e.isInitial)
               m_cycle.FailInitial(e.side, e.reason);
            break;
         case IDHG_EV_CLOSE_CONFIRMED:
           {
            for(int s = 0; s < IDHG_SIDE_COUNT; s++)
              {
               ENUM_IDHG_SIDE sd = IdhgSideFromIndex(s);
               int id = m_grid.FindByTicket(sd, e.position);
               if(id != IDHG_NO_LEVEL)
                  m_grid.MarkClosed(sd, id, e.time);
              }
            m_order.OnPositionGone(e.position);
            break;
           }
         default:
            break;
        }
     }

   void              ApplyEvents(const SIdhgExecEvent &ev[])
     {
      for(int i = 0; i < ArraySize(ev); i++)
         ApplyEvent(ev[i]);
     }

   //--- Thực thi danh sách candidate qua OrderManager (Grid không gửi lệnh)
   void              ExecuteCandidates(const SIdhgCandidate &cands[])
     {
      for(int i = 0; i < ArraySize(cands); i++)
        {
         SIdhgCandidate c = cands[i];
         if(c.isInitial && !m_cycle.MarkInitialSending(c.side))
            continue;
         if(!m_grid.MarkSending(c.side, c.levelId, 0))
            continue;
         double buyVol, sellVol;
         ScanEaPositions(buyVol, sellVol);
         RefreshAccount();
         SIdhgExecEvent ev;
         m_order.SendOpen(c, m_mk, m_acc, c.side == IDHG_BUY ? buyVol : sellVol, TimeCurrent(), ev);
         ApplyEvent(ev);
         RefreshMarket();
        }
     }

   //--- Lý do chặn vào lệnh theo trạng thái / phía
   void              EntryPermissions(bool &allow[], ENUM_IDHG_REASON &reason[])
     {
      ArrayResize(allow, IDHG_SIDE_COUNT);
      ArrayResize(reason, IDHG_SIDE_COUNT);
      ENUM_IDHG_STATE st = m_state.State();
      ENUM_IDHG_REASON stateReason = IDHG_R_SKIPPED_STATE;
      if(st == IDHG_STATE_PAUSED)
         stateReason = IDHG_R_SKIPPED_PAUSED;
      else
         if(st == IDHG_STATE_STOP_GRID)
            stateReason = IDHG_R_SKIPPED_STOP_GRID;
      for(int s = 0; s < IDHG_SIDE_COUNT; s++)
        {
         allow[s] = m_state.AllowNewEntries();
         reason[s] = stateReason;
         if(allow[s] && !m_config.SideEnabled(IdhgSideFromIndex(s)))
           {
            allow[s] = false;
            reason[s] = IDHG_R_SKIPPED_SIDE_OFF;
           }
        }
     }

   //--- Grid đánh giá giá mới → candidate → OrderManager
   void              RunEntries(void)
     {
      if(!m_state.IsCycleActive() || !m_mk.valid)
         return;
      bool allow[];
      ENUM_IDHG_REASON reason[];
      EntryPermissions(allow, reason);
      SIdhgCandidate cands[];
      m_grid.Evaluate(m_mk.mid, allow, reason, cands);
      if(ArraySize(cands) > 0)
         ExecuteCandidates(cands);
     }

   //--- START / NEW CYCLE
   bool              StartCycle(string &msg)
     {
      if(!m_ready)
        {
         msg = "EA chưa sẵn sàng";
         return false;
        }
      if(!RefreshMarket())
        {
         msg = "Không đọc được giá";
         return false;
        }
      int eaPos = EaPositionCount();
      if(!m_cycle.CanStart(m_state.State(), eaPos, m_order.PendingOpenCount()))
        {
         msg = m_cycle.LastError();
         return false;
        }
      if(!m_state.Start())
        {
         msg = m_state.LastError();
         return false;
        }
      int id = m_cycle.Begin(m_mk.ask, m_mk.bid, m_spec.tickSize, m_spec.digits, TimeCurrent());
      m_grid.StartCycle(id, m_cycle.RefPrice());
      m_log.Info("START " + m_cycle.Tag() + " Ref=" + DoubleToString(m_cycle.RefPrice(), m_spec.digits) +
                 " Ask=" + DoubleToString(m_cycle.RefAsk(), m_spec.digits) + " Bid=" + DoubleToString(m_cycle.RefBid(), m_spec.digits));
      bool enabled[];
      ArrayResize(enabled, IDHG_SIDE_COUNT);
      for(int s = 0; s < IDHG_SIDE_COUNT; s++)
         enabled[s] = m_config.SideEnabled(IdhgSideFromIndex(s));
      SIdhgCandidate init[];
      m_grid.InitialCandidates(enabled, init);
      ExecuteCandidates(init);
      msg = "Đã mở chu kỳ " + m_cycle.Tag();
      return true;
     }

   //--- Sự kiện
   void              OnTick(void)
     {
      if(!m_ready)
         return;
      if(!RefreshMarket())
         return;
      RefreshAccount();
      //--- Tuỳ chọn cho Strategy Tester: tự START chu kỳ ĐẦU TIÊN (không bao giờ tự mở chu kỳ sau)
      if(m_cfg.general.autoStartFirstCycle && m_state.State() == IDHG_STATE_IDLE && m_cycle.LastCycleId() == 0 &&
         EaPositionCount() == 0)
        {
         string msg;
         StartCycle(msg);
         return;
        }
      RunEntries();
     }

   void              OnTimer(void)
     {
      if(!m_ready)
         return;
      SIdhgExecEvent ev[];
      if(m_order.CheckPending(TimeCurrent(), ev) > 0)
         ApplyEvents(ev);
     }

   void              OnTradeTransaction(const MqlTradeTransaction &t)
     {
      if(!m_ready)
         return;
      SIdhgExecEvent ev[];
      if(m_order.OnTransaction(t, ev) > 0)
         ApplyEvents(ev);
     }

   //--- Lệnh điều khiển
   bool              Command(const ENUM_IDHG_COMMAND cmd, string &msg)
     {
      msg = "";
      bool ok = false;
      switch(cmd)
        {
         case IDHG_CMD_START:
            ok = StartCycle(msg);
            break;
         default:
            msg = "Lệnh chưa hỗ trợ ở phase này";
            break;
        }
      m_lastMsg = msg;
      if(msg != "")
         m_log.Info(msg);
      return ok;
     }
  };

#endif
