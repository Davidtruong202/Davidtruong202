//+------------------------------------------------------------------+
//| IDHG_Cycle.mqh                                                   |
//| CCycleManager: CycleID, ReferencePrice (Mid), initial BUY/SELL   |
//| chống trùng (MarkInitialSending / ConfirmInitial / FailInitial). |
//+------------------------------------------------------------------+
#ifndef IDHG_CYCLE_MQH
#define IDHG_CYCLE_MQH

#include "IDHG_Utils.mqh"

enum ENUM_IDHG_INITIAL_STATUS
  {
   IDHG_INIT_NONE      = 0,
   IDHG_INIT_SENDING   = 1,
   IDHG_INIT_CONFIRMED = 2,
   IDHG_INIT_FAILED    = 3
  };

class CCycleManager
  {
private:
   int               m_cycleId;          // 0 = không có chu kỳ
   int               m_lastCycleId;      // CycleID lớn nhất đã thấy (broker history + cache)
   double            m_refPrice;
   double            m_refAsk;
   double            m_refBid;
   datetime          m_startTime;
   datetime          m_endTime;
   ENUM_IDHG_INITIAL_STATUS m_initStatus[IDHG_SIDE_COUNT];
   ulong             m_initTicket[IDHG_SIDE_COUNT];
   double            m_initPrice[IDHG_SIDE_COUNT];
   ENUM_IDHG_REASON  m_initReason[IDHG_SIDE_COUNT];
   string            m_lastError;

   bool              Fail(const string e) { m_lastError = e; return false; }
   void              ResetInitials(void)
     {
      for(int i = 0; i < IDHG_SIDE_COUNT; i++)
        {
         m_initStatus[i] = IDHG_INIT_NONE;
         m_initTicket[i] = 0;
         m_initPrice[i] = 0.0;
         m_initReason[i] = IDHG_R_NONE;
        }
     }

public:
                     CCycleManager(void) : m_cycleId(0), m_lastCycleId(0), m_refPrice(0), m_refAsk(0), m_refBid(0),
                     m_startTime(0), m_endTime(0), m_lastError("") { ResetInitials(); }

   int               CycleId(void) const { return m_cycleId; }
   int               LastCycleId(void) const { return m_lastCycleId; }
   double            RefPrice(void) const { return m_refPrice; }
   double            RefAsk(void) const { return m_refAsk; }
   double            RefBid(void) const { return m_refBid; }
   datetime          StartTime(void) const { return m_startTime; }
   datetime          EndTime(void) const { return m_endTime; }
   string            LastError(void) const { return m_lastError; }
   string            Tag(void) const { return m_cycleId > 0 ? IdhgCycleTag(m_cycleId) : "-"; }

   //--- Ghi nhận CycleID đã tồn tại (từ lịch sử broker) để không tái sử dụng ID
   void              NoteSeenCycleId(const int id) { if(id > m_lastCycleId) m_lastCycleId = id; }

   //--- Kiểm tra điều kiện START / NEW CYCLE
   bool              CanStart(const ENUM_IDHG_STATE state, const int eaPositions, const int pendingRequests)
     {
      if(state != IDHG_STATE_IDLE && state != IDHG_STATE_CYCLE_ENDED)
         return Fail("Đang có chu kỳ hoạt động (" + IdhgCycleTag(m_cycleId) + ")");
      if(eaPositions > 0)
         return Fail("Còn " + IntegerToString(eaPositions) + " position cũ của EA — không thể mở chu kỳ mới");
      if(pendingRequests > 0)
         return Fail("Còn yêu cầu gửi lệnh đang chờ xác nhận");
      return true;
     }

   //--- Tạo chu kỳ mới. ReferencePrice = (Ask+Bid)/2 normalize theo tick size.
   int               Begin(const double ask, const double bid, const double tickSize, const int digits, const datetime now)
     {
      m_lastCycleId++;
      m_cycleId = m_lastCycleId;
      m_refAsk = ask;
      m_refBid = bid;
      m_refPrice = PriceNormalize((ask + bid) * 0.5, tickSize, digits);
      m_startTime = now;
      m_endTime = 0;
      ResetInitials();
      return m_cycleId;
     }

   //--- Khôi phục chu kỳ (recovery)
   void              Restore(const int id, const double refPrice, const double refAsk, const double refBid, const datetime start)
     {
      m_cycleId = id;
      NoteSeenCycleId(id);
      m_refPrice = refPrice;
      m_refAsk = refAsk;
      m_refBid = refBid;
      m_startTime = start;
      m_endTime = 0;
     }

   void              End(const datetime now) { m_endTime = now; }

   //--- RESET LOGIC: từ chối nếu còn position (tránh chồng chu kỳ)
   bool              CanResetLogic(const int eaPositions, const int pendingRequests)
     {
      if(eaPositions > 0)
         return Fail("RESET LOGIC bị từ chối: còn " + IntegerToString(eaPositions) + " position");
      if(pendingRequests > 0)
         return Fail("RESET LOGIC bị từ chối: còn yêu cầu đang chờ");
      return true;
     }

   void              ResetLogic(void)
     {
      m_cycleId = 0;              // m_lastCycleId giữ nguyên: ID không bao giờ quay lại
      m_refPrice = 0;
      m_refAsk = 0;
      m_refBid = 0;
      m_startTime = 0;
      m_endTime = 0;
      ResetInitials();
     }

   //--- Chống trùng initial BUY/SELL
   bool              MarkInitialSending(const ENUM_IDHG_SIDE side)
     {
      if(m_cycleId <= 0)
         return Fail("Chưa có chu kỳ");
      if(m_initStatus[side] == IDHG_INIT_SENDING)
         return Fail("Initial " + IdhgSideName(side) + " đang chờ xác nhận — không gửi lại");
      if(m_initStatus[side] == IDHG_INIT_CONFIRMED)
         return Fail("Initial " + IdhgSideName(side) + " đã mở — không gửi lại");
      m_initStatus[side] = IDHG_INIT_SENDING;
      return true;
     }

   void              ConfirmInitial(const ENUM_IDHG_SIDE side, const ulong ticket, const double price)
     {
      m_initStatus[side] = IDHG_INIT_CONFIRMED;
      m_initTicket[side] = ticket;
      m_initPrice[side] = price;
      m_initReason[side] = IDHG_R_NONE;
     }

   void              FailInitial(const ENUM_IDHG_SIDE side, const ENUM_IDHG_REASON reason)
     {
      m_initStatus[side] = IDHG_INIT_FAILED;
      m_initReason[side] = reason;
     }

   ENUM_IDHG_INITIAL_STATUS InitialStatus(const ENUM_IDHG_SIDE side) const { return m_initStatus[side]; }
   bool              IsInitialPending(const ENUM_IDHG_SIDE side) const { return m_initStatus[side] == IDHG_INIT_SENDING; }
   ulong             InitialTicket(const ENUM_IDHG_SIDE side) const { return m_initTicket[side]; }
   double            InitialPrice(const ENUM_IDHG_SIDE side) const { return m_initPrice[side]; }
   ENUM_IDHG_REASON  InitialReason(const ENUM_IDHG_SIDE side) const { return m_initReason[side]; }
  };

#endif
