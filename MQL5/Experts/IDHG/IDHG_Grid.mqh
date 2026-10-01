//+------------------------------------------------------------------+
//| IDHG_Grid.mqh                                                    |
//| GRID ENGINE: BUY và SELL hoàn toàn độc lập.                       |
//| - Chỉ QUYẾT ĐỊNH level nào cần mở → trả về danh sách candidate.   |
//| - KHÔNG gửi lệnh (OrderManager mới gửi).                          |
//| - Level đã tạo (materialized) không bao giờ bị đổi giá/khoảng.    |
//|   Thông số grid mới chỉ áp dụng cho level TƯƠNG LAI.              |
//+------------------------------------------------------------------+
#ifndef IDHG_GRID_MQH
#define IDHG_GRID_MQH

#include "IDHG_Config.mqh"

#define IDHG_MAX_CROSS_PER_EVAL  500   // chặn vòng lặp vô hạn khi khoảng cách quá nhỏ

//--- Khoảng cách của level i (i >= 1) = khoảng từ level i-1 tới level i
double IdhgGridDistance(const SIdhgGridConfig &g, const int levelIdx)
  {
   if(levelIdx <= 0)
      return 0.0;
   double d = g.baseDistance;
   if(g.distanceMode == IDHG_DIST_MULTIPLIER)
      d = g.baseDistance * MathPow(g.distMultiplier, levelIdx - 1);
   else
      if(g.distanceMode == IDHG_DIST_ADDITIVE)
         d = g.baseDistance + g.additiveStep * (levelIdx - 1);
   if(g.minDistance > 0.0 && d < g.minDistance)
      d = g.minDistance;
   if(g.maxDistance > 0.0 && d > g.maxDistance)
      d = g.maxDistance;
   return d;
  }

//--- Lot lý thuyết của level i: BaseLot * LotMultiplier^i (multiplier = 1.0 → không đổi)
double IdhgGridLotRaw(const SIdhgGridConfig &g, const ENUM_IDHG_SIDE side, const int levelIdx)
  {
   double base = (side == IDHG_BUY) ? g.buyLot : g.sellLot;
   if(levelIdx <= 0 || IdhgEQ(g.lotMultiplier, 1.0))
      return base;
   return base * MathPow(g.lotMultiplier, levelIdx);
  }

//--- Giá đã vượt level chưa (dùng giá Mid — cùng hệ quy chiếu với ReferencePrice)
bool IdhgLevelCrossed(const ENUM_IDHG_SIDE side, const double mid, const double levelPrice)
  {
   if(side == IDHG_BUY)
      return IdhgGE(mid, levelPrice);
   return IdhgLE(mid, levelPrice);
  }

//+------------------------------------------------------------------+
//| CGridSide — engine cho MỘT phía                                   |
//+------------------------------------------------------------------+
class CGridSide
  {
private:
   ENUM_IDHG_SIDE    m_side;
   int               m_cycleId;
   double            m_refPrice;
   SIdhgLevel        m_levels[];       // chỉ số mảng = LevelID
   int               m_nextLevel;      // level tương lai kế tiếp cần theo dõi (>= 1)
   bool              m_active;

   void              EnsureSize(const int levelId)
     {
      int n = ArraySize(m_levels);
      if(levelId < n)
         return;
      ArrayResize(m_levels, levelId + 1);
      for(int i = n; i <= levelId; i++)
        {
         m_levels[i].Reset();
         m_levels[i].cycleId = m_cycleId;
         m_levels[i].side = m_side;
         m_levels[i].levelId = i;
        }
     }

   //--- Tính (KHÔNG lưu) level tương lai i dựa trên level i-1 đã tồn tại + cấu hình hiện hành
   void              Peek(const SIdhgGridConfig &g, const SIdhgSymbolSpec &spec, const int levelId,
                          double &price, double &dist, double &lotRaw, double &lot) const
     {
      double prev = m_levels[levelId - 1].logicalPrice;
      dist = IdhgGridDistance(g, levelId);
      if(dist < spec.tickSize)
         dist = spec.tickSize;
      price = PriceNormalize(prev + IdhgSideDir(m_side) * dist, spec.tickSize, spec.digits);
      lotRaw = IdhgGridLotRaw(g, m_side, levelId);
      lot = LotNormalize(lotRaw, spec.volMin, spec.volMax, spec.volStep, g.minLot, g.maxLot);
     }

   void              Materialize(const SIdhgGridConfig &g, const SIdhgSymbolSpec &spec, const int levelId)
     {
      double price, dist, lotRaw, lot;
      Peek(g, spec, levelId, price, dist, lotRaw, lot);
      EnsureSize(levelId);
      m_levels[levelId].logicalPrice = price;
      m_levels[levelId].distance = dist;
      m_levels[levelId].lotRaw = lotRaw;
      m_levels[levelId].lot = lot;
      m_levels[levelId].status = IDHG_LVL_CROSSED;
      m_levels[levelId].reason = IDHG_R_NONE;
     }

   void              FillCandidate(const int levelId, const bool isReopen, SIdhgCandidate &c) const
     {
      c.Reset();
      c.side = m_side;
      c.cycleId = m_cycleId;
      c.levelId = levelId;
      c.logicalPrice = m_levels[levelId].logicalPrice;
      c.distance = m_levels[levelId].distance;
      c.lot = m_levels[levelId].lot;
      c.direction = IdhgSideDir(m_side);
      c.status = IDHG_LVL_CROSSED;
      c.reason = IDHG_R_NONE;
      c.isInitial = (levelId == 0);
      c.isReopen = isReopen;
      if(c.lot <= 0.0)
         c.reason = IDHG_R_SKIPPED_VOLUME;
     }

   void              Append(SIdhgCandidate &out[], const SIdhgCandidate &c) const
     {
      int n = ArraySize(out);
      ArrayResize(out, n + 1);
      out[n] = c;
     }

public:
                     CGridSide(void) : m_side(IDHG_BUY), m_cycleId(0), m_refPrice(0), m_nextLevel(1), m_active(false) {}

   //--- Khởi tạo phía cho chu kỳ mới: tạo level 0 tại ReferencePrice
   void              Init(const ENUM_IDHG_SIDE side, const int cycleId, const double refPrice,
                          const SIdhgGridConfig &g, const SIdhgSymbolSpec &spec)
     {
      m_side = side;
      m_cycleId = cycleId;
      m_refPrice = refPrice;
      ArrayFree(m_levels);
      EnsureSize(0);
      m_levels[0].logicalPrice = refPrice;
      m_levels[0].distance = 0.0;
      m_levels[0].lotRaw = IdhgGridLotRaw(g, side, 0);
      m_levels[0].lot = LotNormalize(m_levels[0].lotRaw, spec.volMin, spec.volMax, spec.volStep, g.minLot, g.maxLot);
      m_levels[0].status = IDHG_LVL_NONE;
      m_nextLevel = 1;
      m_active = true;
     }

   void              Clear(void)
     {
      ArrayFree(m_levels);
      m_nextLevel = 1;
      m_active = false;
      m_cycleId = 0;
      m_refPrice = 0;
     }

   bool              Active(void) const { return m_active; }
   int               CycleId(void) const { return m_cycleId; }
   double            RefPrice(void) const { return m_refPrice; }
   int               NextLevelId(void) const { return m_nextLevel; }
   int               LevelCount(void) const { return ArraySize(m_levels); }
   bool              HasLevel(const int id) const { return id >= 0 && id < ArraySize(m_levels); }

   bool              GetLevel(const int id, SIdhgLevel &out) const
     {
      if(!HasLevel(id))
         return false;
      out = m_levels[id];
      return true;
     }

   //--- Giá / khoảng / lot của level tương lai kế tiếp (hiển thị)
   bool              PeekNext(const SIdhgGridConfig &g, const SIdhgSymbolSpec &spec, double &price, double &dist, double &lot) const
     {
      if(!m_active || m_nextLevel < 1 || m_nextLevel - 1 >= ArraySize(m_levels))
         return false;
      double lotRaw;
      Peek(g, spec, m_nextLevel, price, dist, lotRaw, lot);
      return true;
     }

   //--- Candidate level 0 (initial)
   bool              InitialCandidate(SIdhgCandidate &c) const
     {
      if(!m_active || ArraySize(m_levels) == 0)
         return false;
      if(m_levels[0].status != IDHG_LVL_NONE && m_levels[0].status != IDHG_LVL_FAILED)
         return false;
      FillCandidate(0, false, c);
      return true;
     }

   //--- Đánh giá giá mới. Trả về số candidate thêm vào 'out'.
   //    allow=false → mọi level bị vượt được ghi SKIPPED với blockReason (không backfill sau này).
   int               Evaluate(const SIdhgGridConfig &g, const SIdhgSymbolSpec &spec, const double mid,
                              const bool allow, const ENUM_IDHG_REASON blockReason, SIdhgCandidate &out[])
     {
      if(!m_active || ArraySize(m_levels) == 0)
         return 0;
      int added = 0;
      SIdhgCandidate c;
      //--- 1) Thử lại level FAILED do lỗi tạm thời (số lần thử do OrderManager giới hạn)
      for(int i = 0; i < ArraySize(m_levels); i++)
        {
         if(m_levels[i].status != IDHG_LVL_FAILED)
            continue;
         if(!allow)
           {
            MarkSkipped(i, blockReason, m_levels[i].retcode);
            continue;
           }
         FillCandidate(i, m_levels[i].timesOpened > 0, c);
         Append(out, c);
         added++;
        }
      //--- 2) Phát hiện các level tương lai bị vượt (gần → xa)
      int crossed[];
      int nCross = 0;
      while(nCross < IDHG_MAX_CROSS_PER_EVAL)
        {
         double price, dist, lotRaw, lot;
         Peek(g, spec, m_nextLevel, price, dist, lotRaw, lot);
         if(!IdhgLevelCrossed(m_side, mid, price))
            break;
         Materialize(g, spec, m_nextLevel);
         ArrayResize(crossed, nCross + 1);
         crossed[nCross] = m_nextLevel;
         nCross++;
         m_nextLevel++;
        }
      //--- 3) Áp dụng GapMode / chặn vào lệnh
      for(int k = 0; k < nCross; k++)
        {
         int id = crossed[k];
         if(!allow)
           {
            MarkSkipped(id, blockReason, 0);
            continue;
           }
         bool isLatest = (k == nCross - 1);
         bool open = true;
         if(nCross > 1)
           {
            if(g.gapMode == IDHG_GAP_SKIP_CROSSED)
               open = false;
            else
               if(g.gapMode == IDHG_GAP_OPEN_LATEST_ONLY)
                  open = isLatest;
           }
         if(!open)
           {
            MarkSkipped(id, IDHG_R_SKIPPED_GAP_MODE, 0);
            continue;
           }
         FillCandidate(id, false, c);
         Append(out, c);
         added++;
        }
      //--- 4) ReopenClosedLevel (mặc định tắt): chỉ level CLOSED, KHÔNG bao giờ backfill level SKIPPED
      if(g.reopenClosedLevel)
        {
         for(int i = 0; i < m_nextLevel && i < ArraySize(m_levels); i++)
           {
            if(m_levels[i].status != IDHG_LVL_CLOSED)
               continue;
            bool crossedNow = IdhgLevelCrossed(m_side, mid, m_levels[i].logicalPrice) &&
                              !IdhgEQ(mid, m_levels[i].logicalPrice);
            if(!m_levels[i].rearmed)
              {
               // tái kích hoạt khi giá quay về phía bên kia của level
               if(!IdhgLevelCrossed(m_side, mid, m_levels[i].logicalPrice))
                  m_levels[i].rearmed = true;
               continue;
              }
            if(!crossedNow)
               continue;
            m_levels[i].rearmed = false;
            if(!allow)
               continue;
            m_levels[i].status = IDHG_LVL_CROSSED;
            m_levels[i].attempts = 0;
            FillCandidate(i, true, c);
            Append(out, c);
            added++;
           }
        }
      return added;
     }

   //--- Cập nhật trạng thái level (gọi từ OrderManager / PositionManager)
   bool              MarkSending(const int id, const ulong orderTicket)
     {
      if(!HasLevel(id))
         return false;
      ENUM_IDHG_LEVEL_STATUS s = m_levels[id].status;
      if(s == IDHG_LVL_SENDING || s == IDHG_LVL_OPEN)
         return false;   // chống trùng
      m_levels[id].status = IDHG_LVL_SENDING;
      m_levels[id].orderTicket = orderTicket;
      m_levels[id].attempts++;
      return true;
     }

   bool              MarkOpen(const int id, const ulong ticket, const double actualPrice, const datetime t)
     {
      if(!HasLevel(id))
         return false;
      if(m_levels[id].status == IDHG_LVL_OPEN && m_levels[id].ticket == ticket)
         return false;   // đã xác nhận rồi (idempotent)
      m_levels[id].status = IDHG_LVL_OPEN;
      m_levels[id].reason = IDHG_R_NONE;
      m_levels[id].ticket = ticket;
      m_levels[id].actualEntryPrice = actualPrice;
      m_levels[id].openTime = t;
      m_levels[id].closeTime = 0;
      m_levels[id].timesOpened++;
      return true;
     }

   bool              MarkClosed(const int id, const datetime t)
     {
      if(!HasLevel(id) || m_levels[id].status != IDHG_LVL_OPEN)
         return false;
      m_levels[id].status = IDHG_LVL_CLOSED;
      m_levels[id].closeTime = t;
      m_levels[id].rearmed = false;
      return true;
     }

   bool              MarkSkipped(const int id, const ENUM_IDHG_REASON reason, const int retcode)
     {
      if(!HasLevel(id))
         return false;
      if(m_levels[id].status == IDHG_LVL_OPEN || m_levels[id].status == IDHG_LVL_CLOSED)
         return false;
      m_levels[id].status = IDHG_LVL_SKIPPED;
      m_levels[id].reason = reason;
      m_levels[id].retcode = retcode;
      return true;
     }

   //--- Lỗi tạm thời: level chờ thử lại ở lần Evaluate sau
   bool              MarkFailed(const int id, const ENUM_IDHG_REASON reason, const int retcode)
     {
      if(!HasLevel(id) || m_levels[id].status == IDHG_LVL_OPEN)
         return false;
      m_levels[id].status = IDHG_LVL_FAILED;
      m_levels[id].reason = reason;
      m_levels[id].retcode = retcode;
      return true;
     }

   //--- Lần gửi đã đi tới broker nhưng chưa có xác nhận → về lại trạng thái chờ đánh giá
   bool              RevertSending(const int id)
     {
      if(!HasLevel(id) || m_levels[id].status != IDHG_LVL_SENDING)
         return false;
      m_levels[id].status = IDHG_LVL_FAILED;
      m_levels[id].reason = IDHG_R_FAILED_TRANSIENT;
      return true;
     }

   int               Attempts(const int id) const { return HasLevel(id) ? m_levels[id].attempts : 0; }

   //--- Recovery: ghi đè một level (đến từ lịch sử broker / cache)
   void              RestoreLevel(const SIdhgLevel &lv)
     {
      if(lv.levelId < 0)
         return;
      EnsureSize(lv.levelId);
      m_levels[lv.levelId] = lv;
      m_levels[lv.levelId].side = m_side;
      m_levels[lv.levelId].cycleId = m_cycleId;
      if(lv.levelId >= m_nextLevel)
         m_nextLevel = lv.levelId + 1;
     }

   void              RestoreNextLevel(const int next) { if(next > m_nextLevel) m_nextLevel = next; }

   //--- Khởi tạo phía khi recovery (không tạo lại level 0)
   void              InitForRestore(const ENUM_IDHG_SIDE side, const int cycleId, const double refPrice)
     {
      m_side = side;
      m_cycleId = cycleId;
      m_refPrice = refPrice;
      ArrayFree(m_levels);
      EnsureSize(0);
      m_levels[0].logicalPrice = refPrice;
      m_nextLevel = 1;
      m_active = true;
     }

   //--- Bộ đếm
   int               CountStatus(const ENUM_IDHG_LEVEL_STATUS s) const
     {
      int n = 0;
      for(int i = 0; i < ArraySize(m_levels); i++)
         if(m_levels[i].status == s)
            n++;
      return n;
     }
   int               CountOpenedEvents(void) const   // "ĐÃ RẢI": chỉ lệnh broker xác nhận
     {
      int n = 0;
      for(int i = 0; i < ArraySize(m_levels); i++)
         n += m_levels[i].timesOpened;
      return n;
     }
   int               CountClosedEvents(void) const   // "ĐÃ CHỐT"
     {
      int n = 0;
      for(int i = 0; i < ArraySize(m_levels); i++)
         n += m_levels[i].timesOpened - (m_levels[i].status == IDHG_LVL_OPEN ? 1 : 0);
      return n;
     }
   int               TheoreticalLevels(void) const { return m_active ? m_nextLevel : 0; }   // level 0..next-1 giá đã chạm
   int               CountReason(const ENUM_IDHG_REASON r) const
     {
      int n = 0;
      for(int i = 0; i < ArraySize(m_levels); i++)
         if(m_levels[i].status == IDHG_LVL_SKIPPED && m_levels[i].reason == r)
            n++;
      return n;
     }
   int               FindByTicket(const ulong ticket) const
     {
      for(int i = 0; i < ArraySize(m_levels); i++)
         if(m_levels[i].ticket == ticket && ticket != 0)
            return i;
      return IDHG_NO_LEVEL;
     }
  };

//+------------------------------------------------------------------+
//| CGridEngine — 2 phía độc lập + cấu hình grid đang hiệu lực        |
//+------------------------------------------------------------------+
class CGridEngine
  {
private:
   CGridSide         m_sides[IDHG_SIDE_COUNT];
   SIdhgGridConfig   m_cfg;          // ACTIVE (đổi qua ApplyConfig = APPLY GRID CHANGES)
   SIdhgSymbolSpec   m_spec;
   int               m_cycleId;

public:
                     CGridEngine(void) : m_cycleId(0) { m_cfg.SetDefaults(); m_spec.Reset(); }

   void              SetSymbol(const SIdhgSymbolSpec &spec) { m_spec = spec; }
   void              ApplyConfig(const SIdhgGridConfig &g) { m_cfg = g; }   // chỉ ảnh hưởng level tương lai
   void              GetConfig(SIdhgGridConfig &out) const { out = m_cfg; }
   int               CycleId(void) const { return m_cycleId; }

   void              StartCycle(const int cycleId, const double refPrice)
     {
      m_cycleId = cycleId;
      for(int s = 0; s < IDHG_SIDE_COUNT; s++)
         m_sides[s].Init(IdhgSideFromIndex(s), cycleId, refPrice, m_cfg, m_spec);
     }

   void              Clear(void)
     {
      m_cycleId = 0;
      for(int s = 0; s < IDHG_SIDE_COUNT; s++)
         m_sides[s].Clear();
     }

   //--- Candidate initial BUY + SELL (level 0)
   int               InitialCandidates(const bool &enabled[], SIdhgCandidate &out[])
     {
      int added = 0;
      for(int s = 0; s < IDHG_SIDE_COUNT; s++)
        {
         if(!enabled[s])
            continue;
         SIdhgCandidate c;
         if(!m_sides[s].InitialCandidate(c))
            continue;
         int n = ArraySize(out);
         ArrayResize(out, n + 1);
         out[n] = c;
         added++;
        }
      return added;
     }

   //--- Đánh giá cả hai phía ĐỘC LẬP
   int               Evaluate(const double mid, const bool &allow[], const ENUM_IDHG_REASON &blockReason[], SIdhgCandidate &out[])
     {
      int added = 0;
      for(int s = 0; s < IDHG_SIDE_COUNT; s++)
         added += m_sides[s].Evaluate(m_cfg, m_spec, mid, allow[s], blockReason[s], out);
      return added;
     }

   //--- Truy cập / cập nhật theo phía
   bool              Active(const ENUM_IDHG_SIDE s) const { return m_sides[s].Active(); }
   bool              GetLevel(const ENUM_IDHG_SIDE s, const int id, SIdhgLevel &out) const { return m_sides[s].GetLevel(id, out); }
   int               LevelCount(const ENUM_IDHG_SIDE s) const { return m_sides[s].LevelCount(); }
   int               NextLevelId(const ENUM_IDHG_SIDE s) const { return m_sides[s].NextLevelId(); }
   bool              PeekNext(const ENUM_IDHG_SIDE s, double &price, double &dist, double &lot) const { return m_sides[s].PeekNext(m_cfg, m_spec, price, dist, lot); }
   bool              MarkSending(const ENUM_IDHG_SIDE s, const int id, const ulong ord) { return m_sides[s].MarkSending(id, ord); }
   bool              MarkOpen(const ENUM_IDHG_SIDE s, const int id, const ulong ticket, const double px, const datetime t) { return m_sides[s].MarkOpen(id, ticket, px, t); }
   bool              MarkClosed(const ENUM_IDHG_SIDE s, const int id, const datetime t) { return m_sides[s].MarkClosed(id, t); }
   bool              MarkSkipped(const ENUM_IDHG_SIDE s, const int id, const ENUM_IDHG_REASON r, const int rc) { return m_sides[s].MarkSkipped(id, r, rc); }
   bool              MarkFailed(const ENUM_IDHG_SIDE s, const int id, const ENUM_IDHG_REASON r, const int rc) { return m_sides[s].MarkFailed(id, r, rc); }
   bool              RevertSending(const ENUM_IDHG_SIDE s, const int id) { return m_sides[s].RevertSending(id); }
   int               Attempts(const ENUM_IDHG_SIDE s, const int id) const { return m_sides[s].Attempts(id); }
   int               FindByTicket(const ENUM_IDHG_SIDE s, const ulong ticket) const { return m_sides[s].FindByTicket(ticket); }

   void              InitSideForRestore(const ENUM_IDHG_SIDE s, const int cycleId, const double refPrice)
     {
      m_cycleId = cycleId;
      m_sides[s].InitForRestore(s, cycleId, refPrice);
     }
   void              RestoreLevel(const ENUM_IDHG_SIDE s, const SIdhgLevel &lv) { m_sides[s].RestoreLevel(lv); }
   void              RestoreNextLevel(const ENUM_IDHG_SIDE s, const int next) { m_sides[s].RestoreNextLevel(next); }

   //--- Bộ đếm theo phía
   int               Opened(const ENUM_IDHG_SIDE s) const { return m_sides[s].CountOpenedEvents(); }
   int               Closed(const ENUM_IDHG_SIDE s) const { return m_sides[s].CountClosedEvents(); }
   int               OpenNow(const ENUM_IDHG_SIDE s) const { return m_sides[s].CountStatus(IDHG_LVL_OPEN); }
   int               Skipped(const ENUM_IDHG_SIDE s) const { return m_sides[s].CountStatus(IDHG_LVL_SKIPPED); }
   int               Sending(const ENUM_IDHG_SIDE s) const { return m_sides[s].CountStatus(IDHG_LVL_SENDING); }
   int               Theoretical(const ENUM_IDHG_SIDE s) const { return m_sides[s].TheoreticalLevels(); }
   int               SkippedByReason(const ENUM_IDHG_SIDE s, const ENUM_IDHG_REASON r) const { return m_sides[s].CountReason(r); }
  };

#endif
