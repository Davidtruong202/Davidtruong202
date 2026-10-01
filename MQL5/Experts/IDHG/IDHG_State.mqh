//+------------------------------------------------------------------+
//| IDHG_State.mqh                                                   |
//| Máy trạng thái: IDLE / RUNNING / PAUSED / STOP_GRID / CYCLE_ENDED |
//| Cờ: AllowNewEntries / AllowProfitLogic / AllowRiskLogic          |
//+------------------------------------------------------------------+
#ifndef IDHG_STATE_MQH
#define IDHG_STATE_MQH

#include "IDHG_Types.mqh"

string IdhgStateName(const ENUM_IDHG_STATE s)
  {
   switch(s)
     {
      case IDHG_STATE_IDLE:        return "IDLE";
      case IDHG_STATE_RUNNING:     return "RUNNING";
      case IDHG_STATE_PAUSED:      return "PAUSED";
      case IDHG_STATE_STOP_GRID:   return "STOP_GRID";
      case IDHG_STATE_CYCLE_ENDED: return "CYCLE_ENDED";
      default:                     return "?";
     }
  }

string IdhgStateNameVN(const ENUM_IDHG_STATE s)
  {
   switch(s)
     {
      case IDHG_STATE_IDLE:        return "CHỜ (IDLE)";
      case IDHG_STATE_RUNNING:     return "ĐANG CHẠY";
      case IDHG_STATE_PAUSED:      return "TẠM DỪNG";
      case IDHG_STATE_STOP_GRID:   return "DỪNG GRID";
      case IDHG_STATE_CYCLE_ENDED: return "KẾT THÚC CHU KỲ";
      default:                     return "?";
     }
  }

//--- Bảng cờ theo trạng thái (theo đặc tả mục XXVIII)
bool IdhgStateAllowsNewEntries(const ENUM_IDHG_STATE s) { return s == IDHG_STATE_RUNNING; }
bool IdhgStateAllowsProfitLogic(const ENUM_IDHG_STATE s) { return s != IDHG_STATE_PAUSED; }
bool IdhgStateAllowsRiskLogic(const ENUM_IDHG_STATE s)   { return true; }

class CState
  {
private:
   ENUM_IDHG_STATE   m_state;
   ENUM_IDHG_STATE   m_beforePause;    // trạng thái để RESUME quay lại
   string            m_lastError;

   bool              Fail(const string e) { m_lastError = e; return false; }

public:
                     CState(void) : m_state(IDHG_STATE_IDLE), m_beforePause(IDHG_STATE_RUNNING), m_lastError("") {}

   ENUM_IDHG_STATE   State(void) const { return m_state; }
   ENUM_IDHG_STATE   ResumeTarget(void) const { return m_beforePause; }
   string            LastError(void) const { return m_lastError; }
   bool              AllowNewEntries(void) const { return IdhgStateAllowsNewEntries(m_state); }
   bool              AllowProfitLogic(void) const { return IdhgStateAllowsProfitLogic(m_state); }
   bool              AllowRiskLogic(void) const { return IdhgStateAllowsRiskLogic(m_state); }
   bool              IsCycleActive(void) const
     {
      return m_state == IDHG_STATE_RUNNING || m_state == IDHG_STATE_PAUSED || m_state == IDHG_STATE_STOP_GRID;
     }

   //--- START / NEW CYCLE: chỉ từ IDLE hoặc CYCLE_ENDED
   bool              Start(void)
     {
      if(m_state != IDHG_STATE_IDLE && m_state != IDHG_STATE_CYCLE_ENDED)
         return Fail("START bị từ chối: trạng thái " + IdhgStateName(m_state));
      m_state = IDHG_STATE_RUNNING;
      m_beforePause = IDHG_STATE_RUNNING;
      return true;
     }

   bool              Pause(void)
     {
      if(m_state != IDHG_STATE_RUNNING && m_state != IDHG_STATE_STOP_GRID)
         return Fail("PAUSE bị từ chối: trạng thái " + IdhgStateName(m_state));
      m_beforePause = m_state;
      m_state = IDHG_STATE_PAUSED;
      return true;
     }

   bool              Resume(void)
     {
      if(m_state != IDHG_STATE_PAUSED)
         return Fail("RESUME bị từ chối: không ở PAUSED");
      m_state = m_beforePause;
      return true;
     }

   bool              StopGrid(void)
     {
      if(m_state != IDHG_STATE_RUNNING && m_state != IDHG_STATE_PAUSED)
         return Fail("STOP GRID bị từ chối: trạng thái " + IdhgStateName(m_state));
      m_state = IDHG_STATE_STOP_GRID;
      m_beforePause = IDHG_STATE_STOP_GRID;
      return true;
     }

   bool              ResumeGrid(void)
     {
      if(m_state != IDHG_STATE_STOP_GRID)
         return Fail("RESUME GRID bị từ chối: không ở STOP_GRID");
      m_state = IDHG_STATE_RUNNING;
      m_beforePause = IDHG_STATE_RUNNING;
      return true;
     }

   //--- Chu kỳ kết thúc khi mọi position của chu kỳ đã CLOSED (kiểm tra ở CycleManager)
   bool              EndCycle(void)
     {
      if(!IsCycleActive())
         return Fail("END CYCLE bị từ chối: không có chu kỳ đang chạy");
      m_state = IDHG_STATE_CYCLE_ENDED;
      return true;
     }

   //--- RESET LOGIC: chỉ khi không có chu kỳ đang chạy (điều kiện position kiểm tra ở CycleManager)
   bool              ResetLogic(void)
     {
      if(IsCycleActive())
         return Fail("RESET LOGIC bị từ chối: chu kỳ đang chạy");
      m_state = IDHG_STATE_IDLE;
      m_beforePause = IDHG_STATE_RUNNING;
      return true;
     }

   //--- Khôi phục sau restart (recovery)
   void              Restore(const ENUM_IDHG_STATE s, const ENUM_IDHG_STATE beforePause)
     {
      m_state = s;
      m_beforePause = (beforePause == IDHG_STATE_STOP_GRID) ? IDHG_STATE_STOP_GRID : IDHG_STATE_RUNNING;
     }
  };

#endif
