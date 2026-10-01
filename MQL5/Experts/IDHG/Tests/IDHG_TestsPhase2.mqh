//+------------------------------------------------------------------+
//| IDHG_TestsPhase2.mqh — Self-test PHASE 2 (Grid Engine)            |
//| Grid KHÔNG gửi lệnh: test chỉ kiểm tra candidate + trạng thái.    |
//+------------------------------------------------------------------+
#ifndef IDHG_TESTS_PHASE2_MQH
#define IDHG_TESTS_PHASE2_MQH

#include "IDHG_TestsPhase1.mqh"
#include "..\IDHG_Grid.mqh"

//--- Mảng điều khiển cho Evaluate (dùng mảng động để tương thích tham số &arr[])
void T2_Allow(bool &allow[], ENUM_IDHG_REASON &reason[], const bool buy, const bool sell, const ENUM_IDHG_REASON r)
  {
   ArrayResize(allow, IDHG_SIDE_COUNT);
   ArrayResize(reason, IDHG_SIDE_COUNT);
   allow[IDHG_BUY] = buy;
   allow[IDHG_SELL] = sell;
   reason[IDHG_BUY] = r;
   reason[IDHG_SELL] = r;
  }

//--- Engine với Reference 5000, distance cố định 10, min/max tắt
void T2_MakeEngine(CGridEngine &ge, SIdhgGridConfig &g, const ENUM_IDHG_GAP_MODE gap)
  {
   SIdhgSymbolSpec spec;
   IdhgTestSpec(spec);
   g.SetDefaults();
   g.distanceMode = IDHG_DIST_FIXED;
   g.baseDistance = 10.0;
   g.minDistance = 0;
   g.maxDistance = 0;
   g.gapMode = gap;
   ge.SetSymbol(spec);
   ge.ApplyConfig(g);
   ge.StartCycle(1, 5000.0);
  }

int T2_Eval(CGridEngine &ge, const double mid, SIdhgCandidate &out[])
  {
   bool allow[];
   ENUM_IDHG_REASON reason[];
   T2_Allow(allow, reason, true, true, IDHG_R_NONE);
   ArrayResize(out, 0);
   return ge.Evaluate(mid, allow, reason, out);
  }

double T2_LevelPrice(CGridEngine &ge, const ENUM_IDHG_SIDE s, const int id)
  {
   SIdhgLevel lv;
   if(!ge.GetLevel(s, id, lv))
      return -1;
   return lv.logicalPrice;
  }

ENUM_IDHG_LEVEL_STATUS T2_LevelStatus(CGridEngine &ge, const ENUM_IDHG_SIDE s, const int id)
  {
   SIdhgLevel lv;
   if(!ge.GetLevel(s, id, lv))
      return IDHG_LVL_NONE;
   return lv.status;
  }

ENUM_IDHG_REASON T2_LevelReason(CGridEngine &ge, const ENUM_IDHG_SIDE s, const int id)
  {
   SIdhgLevel lv;
   if(!ge.GetLevel(s, id, lv))
      return IDHG_R_NONE;
   return lv.reason;
  }

void IdhgTestPhase2_Distance(void)
  {
   T_Begin("P2.DISTANCE (TEST 3)");
   SIdhgGridConfig g;
   g.SetDefaults();
   g.minDistance = 0; g.maxDistance = 0;
   g.distanceMode = IDHG_DIST_FIXED; g.baseDistance = 10;
   T_Check(IdhgEQ(IdhgGridDistance(g, 1), 10) && IdhgEQ(IdhgGridDistance(g, 2), 10) && IdhgEQ(IdhgGridDistance(g, 5), 10), "FIXED: 10,10,10");
   g.distanceMode = IDHG_DIST_MULTIPLIER; g.distMultiplier = 1.2;
   T_Near(IdhgGridDistance(g, 1), 10.0, 1e-9, "MULTIPLIER L1 = 10");
   T_Near(IdhgGridDistance(g, 2), 12.0, 1e-9, "MULTIPLIER L2 = 12");
   T_Near(IdhgGridDistance(g, 3), 14.4, 1e-9, "MULTIPLIER L3 = 14.4");
   T_Near(IdhgGridDistance(g, 4), 17.28, 1e-9, "MULTIPLIER L4 = 17.28");
   g.distanceMode = IDHG_DIST_ADDITIVE; g.additiveStep = 2;
   T_Check(IdhgEQ(IdhgGridDistance(g, 1), 10) && IdhgEQ(IdhgGridDistance(g, 2), 12) &&
           IdhgEQ(IdhgGridDistance(g, 3), 14) && IdhgEQ(IdhgGridDistance(g, 4), 16), "ADDITIVE: 10,12,14,16");
   g.distanceMode = IDHG_DIST_MULTIPLIER; g.distMultiplier = 2.0; g.maxDistance = 30;
   T_Check(IdhgEQ(IdhgGridDistance(g, 3), 30) && IdhgEQ(IdhgGridDistance(g, 4), 30), "Vượt MaxDistance → kẹp về Max");
   g.maxDistance = 0; g.distanceMode = IDHG_DIST_ADDITIVE; g.additiveStep = -3; g.minDistance = 2;
   T_Check(IdhgEQ(IdhgGridDistance(g, 4), 2) && IdhgEQ(IdhgGridDistance(g, 3), 4), "Nhỏ hơn MinDistance → kẹp về Min");
  }

void IdhgTestPhase2_Test1(void)
  {
   T_Begin("P2.TEST1 BUY/SELL levels");
   CGridEngine ge;
   SIdhgGridConfig g;
   T2_MakeEngine(ge, g, IDHG_GAP_OPEN_ALL_CROSSED);
   bool en[];
   ArrayResize(en, IDHG_SIDE_COUNT);
   en[IDHG_BUY] = true;
   en[IDHG_SELL] = true;
   SIdhgCandidate init[];
   T_EqInt(ge.InitialCandidates(en, init), 2, "Initial BUY + SELL");
   T_Check(init[0].side == IDHG_BUY && init[0].isInitial && IdhgEQ(init[0].logicalPrice, 5000), "Initial BUY tại 5000");
   T_Check(init[1].side == IDHG_SELL && init[1].isInitial && IdhgEQ(init[1].logicalPrice, 5000), "Initial SELL tại 5000");
   SIdhgCandidate c[];
   double up[] = {5010.0, 5020.0, 5030.0};
   for(int i = 0; i < 3; i++)
     {
      int n = T2_Eval(ge, up[i], c);
      T_Check(n == 1 && c[0].side == IDHG_BUY && c[0].levelId == i + 1 && IdhgEQ(c[0].logicalPrice, up[i]),
              "BUY candidate L" + IntegerToString(i + 1) + " = " + DoubleToString(up[i], 2));
     }
   T_EqInt(T2_Eval(ge, 5000.0, c), 0, "Giá quay về 5000: không có candidate");
   double dn[] = {4990.0, 4980.0, 4970.0};
   for(int i = 0; i < 3; i++)
     {
      int n = T2_Eval(ge, dn[i], c);
      T_Check(n == 1 && c[0].side == IDHG_SELL && c[0].levelId == i + 1 && IdhgEQ(c[0].logicalPrice, dn[i]),
              "SELL candidate L" + IntegerToString(i + 1) + " = " + DoubleToString(dn[i], 2));
     }
   T_Check(IdhgEQ(T2_LevelPrice(ge, IDHG_BUY, 0), 5000) && IdhgEQ(T2_LevelPrice(ge, IDHG_BUY, 1), 5010) &&
           IdhgEQ(T2_LevelPrice(ge, IDHG_BUY, 2), 5020) && IdhgEQ(T2_LevelPrice(ge, IDHG_BUY, 3), 5030), "BUY: 5000,5010,5020,5030");
   T_Check(IdhgEQ(T2_LevelPrice(ge, IDHG_SELL, 0), 5000) && IdhgEQ(T2_LevelPrice(ge, IDHG_SELL, 1), 4990) &&
           IdhgEQ(T2_LevelPrice(ge, IDHG_SELL, 2), 4980) && IdhgEQ(T2_LevelPrice(ge, IDHG_SELL, 3), 4970), "SELL: 5000,4990,4980,4970");
   double px, d, lot;
   T_Check(ge.PeekNext(IDHG_BUY, px, d, lot) && IdhgEQ(px, 5040), "Next BUY = 5040");
   T_Check(ge.PeekNext(IDHG_SELL, px, d, lot) && IdhgEQ(px, 4960), "Next SELL = 4960");
   T_EqInt(T2_Eval(ge, 5035.0, c), 0, "BUY chỉ mở level phía BUY: giá lên 5035 < 5040 → không có");
  }

void IdhgTestPhase2_Gap(void)
  {
   T_Begin("P2.TEST2 GAP 5000→5045");
   CGridEngine ge;
   SIdhgGridConfig g;
   SIdhgCandidate c[];
   T2_MakeEngine(ge, g, IDHG_GAP_OPEN_ALL_CROSSED);
   int n = T2_Eval(ge, 5045.0, c);
   T_EqInt(n, 4, "OPEN_ALL_CROSSED nhận 4 level");
   bool order = (n == 4);
   for(int i = 0; i < n && order; i++)
      order = (c[i].side == IDHG_BUY && IdhgEQ(c[i].logicalPrice, 5010.0 + 10.0 * i) && c[i].levelId == i + 1);
   T_Check(order, "Thứ tự gần → xa: 5010,5020,5030,5040");
   T_Check(n == 4 && c[0].status == IDHG_LVL_CROSSED && c[0].direction == 1 && c[0].cycleId == 1 &&
           IdhgEQ(c[0].distance, 10) && IdhgEQ(c[0].lot, 0.01) && c[0].reason == IDHG_R_NONE, "Candidate đủ trường");
   T_EqInt(T2_Eval(ge, 5045.0, c), 0, "Đánh giá lại cùng giá: không lặp candidate");

   T2_MakeEngine(ge, g, IDHG_GAP_OPEN_ALL_CROSSED);
   n = T2_Eval(ge, 4955.0, c);
   order = (n == 4);
   for(int i = 0; i < n && order; i++)
      order = (c[i].side == IDHG_SELL && IdhgEQ(c[i].logicalPrice, 4990.0 - 10.0 * i) && c[i].direction == -1);
   T_Check(order, "SELL gap 5000→4955: 4990,4980,4970,4960 (gần → xa)");

   T2_MakeEngine(ge, g, IDHG_GAP_OPEN_LATEST_ONLY);
   n = T2_Eval(ge, 5045.0, c);
   T_Check(n == 1 && c[0].levelId == 4 && IdhgEQ(c[0].logicalPrice, 5040), "OPEN_LATEST_ONLY: chỉ 5040");
   T_Check(T2_LevelStatus(ge, IDHG_BUY, 1) == IDHG_LVL_SKIPPED && T2_LevelReason(ge, IDHG_BUY, 1) == IDHG_R_SKIPPED_GAP_MODE &&
           T2_LevelStatus(ge, IDHG_BUY, 3) == IDHG_LVL_SKIPPED, "LATEST_ONLY: L1..L3 SKIPPED_GAP_MODE");

   T2_MakeEngine(ge, g, IDHG_GAP_SKIP_CROSSED);
   n = T2_Eval(ge, 5045.0, c);
   T_EqInt(n, 0, "SKIP_CROSSED: không mở level bị vượt");
   T_Check(T2_LevelStatus(ge, IDHG_BUY, 4) == IDHG_LVL_SKIPPED && T2_LevelReason(ge, IDHG_BUY, 4) == IDHG_R_SKIPPED_GAP_MODE,
           "SKIP_CROSSED: 5040 SKIPPED_GAP_MODE");
   T_EqInt(ge.Skipped(IDHG_BUY), 4, "SKIP_CROSSED: 4 level skipped (có lý do)");
   n = T2_Eval(ge, 5050.0, c);
   T_Check(n == 1 && c[0].levelId == 5 && IdhgEQ(c[0].logicalPrice, 5050), "Sau gap: bước bình thường mở 5050");
   T_EqInt(T2_Eval(ge, 5045.0, c), 0, "Không backfill level đã SKIPPED");
  }

void IdhgTestPhase2_Block(void)
  {
   T_Begin("P2.BLOCK / TEST7 grid-level");
   CGridEngine ge;
   SIdhgGridConfig g;
   SIdhgCandidate c[];
   bool allow[];
   ENUM_IDHG_REASON reason[];
   T2_MakeEngine(ge, g, IDHG_GAP_OPEN_ALL_CROSSED);
   T2_Allow(allow, reason, false, true, IDHG_R_SKIPPED_PAUSED);
   ArrayResize(c, 0);
   int n = ge.Evaluate(5025.0, allow, reason, c);
   T_EqInt(n, 0, "BUY bị chặn: không có candidate");
   T_Check(T2_LevelStatus(ge, IDHG_BUY, 1) == IDHG_LVL_SKIPPED && T2_LevelReason(ge, IDHG_BUY, 2) == IDHG_R_SKIPPED_PAUSED,
           "Level vượt khi bị chặn → SKIPPED_PAUSED");
   T_EqInt(T2_Eval(ge, 5025.0, c), 0, "Bỏ chặn: KHÔNG backfill");
   n = T2_Eval(ge, 5030.0, c);
   T_Check(n == 1 && c[0].levelId == 3, "Bỏ chặn: chỉ level tương lai (5030)");

   //--- TEST 7 ở mức grid: gap + MaxOrders đầy → SKIPPED_MAX_ORDERS, không retry vô hạn
   T2_MakeEngine(ge, g, IDHG_GAP_OPEN_ALL_CROSSED);
   n = T2_Eval(ge, 5045.0, c);
   int allowedSlots = 2;   // giả lập gate: chỉ còn 2 chỗ
   for(int i = 0; i < n; i++)
     {
      if(i < allowedSlots)
        {
         ge.MarkSending(c[i].side, c[i].levelId, 900 + i);
         ge.MarkOpen(c[i].side, c[i].levelId, 900 + i, c[i].logicalPrice + 0.1, 1);
        }
      else
         ge.MarkSkipped(c[i].side, c[i].levelId, IDHG_R_SKIPPED_MAX_ORDERS, 0);
     }
   T_Check(T2_LevelReason(ge, IDHG_BUY, 3) == IDHG_R_SKIPPED_MAX_ORDERS && T2_LevelReason(ge, IDHG_BUY, 4) == IDHG_R_SKIPPED_MAX_ORDERS,
           "L3, L4 SKIPPED_MAX_ORDERS");
   int total = 0;
   for(int k = 0; k < 5; k++)
      total += T2_Eval(ge, 5045.0, c);
   T_EqInt(total, 0, "Không retry level SKIPPED (5 lần đánh giá)");
   T_EqInt(ge.SkippedByReason(IDHG_BUY, IDHG_R_SKIPPED_MAX_ORDERS), 2, "Đếm skipped theo lý do");
   n = T2_Eval(ge, 5050.0, c);
   T_Check(n == 1 && c[0].levelId == 5, "Tăng limit: chỉ mở level tương lai, không quay lại L3/L4");
  }

void IdhgTestPhase2_Lot(void)
  {
   T_Begin("P2.LOT");
   SIdhgGridConfig g;
   g.SetDefaults();
   T_Check(IdhgEQ(IdhgGridLotRaw(g, IDHG_BUY, 0), 0.01) && IdhgEQ(IdhgGridLotRaw(g, IDHG_BUY, 7), 0.01),
           "LotMultiplier 1.0: lot không đổi (không martingale)");
   g.lotMultiplier = 1.2;
   T_Near(IdhgGridLotRaw(g, IDHG_BUY, 1), 0.012, 1e-12, "Lot raw L1 = 0.012");
   T_Near(IdhgGridLotRaw(g, IDHG_BUY, 2), 0.0144, 1e-12, "Lot raw L2 = 0.0144");
   CGridEngine ge;
   SIdhgSymbolSpec spec;
   IdhgTestSpec(spec);
   g.minDistance = 0; g.maxDistance = 0; g.baseDistance = 10;
   ge.SetSymbol(spec);
   ge.ApplyConfig(g);
   ge.StartCycle(1, 5000);
   SIdhgCandidate c[];
   T2_Eval(ge, 5040, c);
   T_Check(ArraySize(c) == 4 && IdhgEQ(c[0].lot, 0.01) && IdhgEQ(c[1].lot, 0.01) && IdhgEQ(c[3].lot, 0.02),
           "Lot normalize theo step: 0.012→0.01, 0.0144→0.01, 0.020736→0.02");
   g.buyLot = 0.05; g.lotMultiplier = 2.0; g.maxLot = 0.15;
   ge.ApplyConfig(g);
   ge.StartCycle(2, 5000);
   T2_Eval(ge, 5030, c);
   T_Check(ArraySize(c) == 3 && IdhgEQ(c[0].lot, 0.10) && IdhgEQ(c[1].lot, 0.15) && IdhgEQ(c[2].lot, 0.15),
           "MaxLot kẹp lot: 0.10, 0.15, 0.15");
   g.sellLot = 0.03; g.lotMultiplier = 1.0; g.maxLot = 1.0;
   ge.ApplyConfig(g);
   ge.StartCycle(3, 5000);
   T2_Eval(ge, 4990, c);
   T_Check(ArraySize(c) == 1 && c[0].side == IDHG_SELL && IdhgEQ(c[0].lot, 0.03), "SELL dùng SellLot riêng");
  }

void IdhgTestPhase2_Apply(void)
  {
   T_Begin("P2.TEST16 APPLY GRID CHANGES");
   CGridEngine ge;
   SIdhgGridConfig g;
   SIdhgCandidate c[];
   T2_MakeEngine(ge, g, IDHG_GAP_OPEN_ALL_CROSSED);
   T2_Eval(ge, 5010, c);
   T2_Eval(ge, 5020, c);
   T2_Eval(ge, 5030, c);
   CConfig cm;
   SIdhgConfig full;
   full.SetDefaults();
   full.grid = g;
   cm.Load(full);
   SIdhgGridConfig ng = g;
   ng.baseDistance = 20;
   cm.SetPending(ng);
   double px, d, lot;
   ge.PeekNext(IDHG_BUY, px, d, lot);
   T_Check(IdhgEQ(px, 5040) && IdhgEQ(d, 10), "Trước APPLY: next = 5040 (pending chưa hiệu lực)");
   cm.ApplyPending();
   SIdhgGridConfig act;
   cm.GetGrid(act);
   ge.ApplyConfig(act);
   T_Check(IdhgEQ(T2_LevelPrice(ge, IDHG_BUY, 1), 5010) && IdhgEQ(T2_LevelPrice(ge, IDHG_BUY, 2), 5020) &&
           IdhgEQ(T2_LevelPrice(ge, IDHG_BUY, 3), 5030), "Level cũ không đổi sau APPLY");
   SIdhgLevel lv;
   ge.GetLevel(IDHG_BUY, 2, lv);
   T_Near(lv.distance, 10.0, 1e-9, "Distance level cũ giữ nguyên");
   ge.PeekNext(IDHG_BUY, px, d, lot);
   T_Check(IdhgEQ(px, 5050) && IdhgEQ(d, 20), "Level tương lai dùng distance mới: 5050");
   ge.PeekNext(IDHG_SELL, px, d, lot);
   T_Check(IdhgEQ(px, 4980), "SELL tương lai cũng dùng config mới: 4980");
   T_EqInt(T2_Eval(ge, 5045, c), 0, "5045 chưa tới level mới");
   T_Check(T2_Eval(ge, 5050, c) == 1 && IdhgEQ(c[0].logicalPrice, 5050), "Mở level mới 5050");
  }

void IdhgTestPhase2_LevelState(void)
  {
   T_Begin("P2.LEVEL_STATE");
   CGridEngine ge;
   SIdhgGridConfig g;
   SIdhgCandidate c[];
   T2_MakeEngine(ge, g, IDHG_GAP_OPEN_ALL_CROSSED);
   T2_Eval(ge, 5010, c);
   T_Check(T2_LevelStatus(ge, IDHG_BUY, 1) == IDHG_LVL_CROSSED, "Sau Evaluate: CROSSED");
   T_Check(ge.MarkSending(IDHG_BUY, 1, 555), "MarkSending");
   T_Check(!ge.MarkSending(IDHG_BUY, 1, 556), "MarkSending lần 2 bị chặn (chống trùng)");
   T_EqInt(ge.Opened(IDHG_BUY), 0, "SENDING chưa tính là ĐÃ RẢI");
   T_Check(ge.MarkOpen(IDHG_BUY, 1, 555, 5010.25, 100), "MarkOpen (broker xác nhận)");
   T_Check(!ge.MarkOpen(IDHG_BUY, 1, 555, 5010.25, 100), "MarkOpen lặp lại → bỏ qua (idempotent)");
   SIdhgLevel lv;
   ge.GetLevel(IDHG_BUY, 1, lv);
   T_Check(IdhgEQ(lv.actualEntryPrice, 5010.25) && IdhgEQ(lv.logicalPrice, 5010.0), "ActualEntryPrice ≠ LogicalPrice (lưu riêng)");
   T_EqInt(ge.Opened(IDHG_BUY), 1, "ĐÃ RẢI = 1");
   T_EqInt(ge.OpenNow(IDHG_BUY), 1, "ĐANG MỞ = 1");
   T_Check(!ge.MarkSkipped(IDHG_BUY, 1, IDHG_R_SKIPPED_RISK, 0), "Không SKIP level đang OPEN");
   T_Check(ge.MarkClosed(IDHG_BUY, 1, 200), "MarkClosed");
   T_EqInt(ge.Closed(IDHG_BUY), 1, "ĐÃ CHỐT = 1");
   T_EqInt(ge.OpenNow(IDHG_BUY), 0, "ĐANG MỞ = 0");
   //--- broker reject tạm thời → retry có giới hạn, sau đó SKIPPED_BROKER_ERROR
   T2_Eval(ge, 5020, c);
   ge.MarkSending(IDHG_BUY, 2, 0);
   ge.MarkFailed(IDHG_BUY, 2, IDHG_R_FAILED_TRANSIENT, 10004);
   T_EqInt(ge.Opened(IDHG_BUY), 1, "Lệnh bị reject KHÔNG tính ĐÃ RẢI");
   int n = T2_Eval(ge, 5021, c);
   T_Check(n == 1 && c[0].levelId == 2, "Level FAILED tạm thời được đưa lại làm candidate");
   ge.MarkSkipped(IDHG_BUY, 2, IDHG_R_SKIPPED_BROKER_ERROR, 10006);
   T_EqInt(T2_Eval(ge, 5021, c), 0, "Sau SKIPPED_BROKER_ERROR: không retry");
   ge.GetLevel(IDHG_BUY, 2, lv);
   T_Check(lv.reason == IDHG_R_SKIPPED_BROKER_ERROR && lv.retcode == 10006, "Lưu reason + retcode");
   //--- RevertSending
   T2_Eval(ge, 5030, c);
   ge.MarkSending(IDHG_BUY, 3, 0);
   T_Check(ge.RevertSending(IDHG_BUY, 3) && T2_LevelStatus(ge, IDHG_BUY, 3) == IDHG_LVL_FAILED, "RevertSending → FAILED (thử lại)");
   T_EqInt(ge.Attempts(IDHG_BUY, 3), 1, "Đếm số lần gửi");
  }

void IdhgTestPhase2_Reopen(void)
  {
   T_Begin("P2.REOPEN");
   CGridEngine ge;
   SIdhgGridConfig g;
   SIdhgCandidate c[];
   T2_MakeEngine(ge, g, IDHG_GAP_OPEN_ALL_CROSSED);
   T2_Eval(ge, 5010, c);
   ge.MarkSending(IDHG_BUY, 1, 1);
   ge.MarkOpen(IDHG_BUY, 1, 1, 5010.2, 1);
   ge.MarkClosed(IDHG_BUY, 1, 2);
   T2_Eval(ge, 5005, c);
   T_EqInt(T2_Eval(ge, 5012, c), 0, "Mặc định: level CLOSED KHÔNG mở lại");
   g.reopenClosedLevel = true;
   ge.ApplyConfig(g);
   T_EqInt(T2_Eval(ge, 5012, c), 0, "Reopen bật: chưa tái kích hoạt khi giá chưa quay về");
   T2_Eval(ge, 5005, c);
   int n = T2_Eval(ge, 5012, c);
   T_Check(n == 1 && c[0].levelId == 1 && c[0].isReopen, "Reopen bật: giá quay về rồi vượt lại → mở lại L1");
   T2_MakeEngine(ge, g, IDHG_GAP_SKIP_CROSSED);
   T2_Eval(ge, 5025, c);   // L1, L2 SKIPPED (gap)
   T2_Eval(ge, 5000, c);
   T_EqInt(T2_Eval(ge, 5025, c), 0, "Level SKIPPED không bao giờ backfill (kể cả khi bật reopen)");
  }

void IdhgTestPhase2_Independence(void)
  {
   T_Begin("P2.INDEPENDENCE");
   CGridEngine ge;
   SIdhgGridConfig g;
   SIdhgCandidate c[];
   bool allow[];
   ENUM_IDHG_REASON reason[];
   T2_MakeEngine(ge, g, IDHG_GAP_OPEN_ALL_CROSSED);
   T2_Allow(allow, reason, false, true, IDHG_R_SKIPPED_SIDE_OFF);
   ArrayResize(c, 0);
   ge.Evaluate(5010, allow, reason, c);
   ArrayResize(c, 0);
   int n = ge.Evaluate(4990, allow, reason, c);
   T_Check(n == 1 && c[0].side == IDHG_SELL, "BUY tắt không ảnh hưởng SELL");
   T_Check(T2_LevelReason(ge, IDHG_BUY, 1) == IDHG_R_SKIPPED_SIDE_OFF, "BUY tắt: level vượt → SKIPPED_SIDE_OFF");
   double px, d, lot;
   ge.PeekNext(IDHG_SELL, px, d, lot);
   T_Check(IdhgEQ(px, 4980), "SELL anchor theo Reference, không theo giá khớp BUY");
   //--- vòng lặp an toàn: khoảng cách rất nhỏ
   g.distanceMode = IDHG_DIST_MULTIPLIER; g.distMultiplier = 0.01; g.minDistance = 0; g.maxDistance = 0;
   ge.ApplyConfig(g);
   ge.StartCycle(9, 5000);
   n = T2_Eval(ge, 5100, c);
   T_Check(n <= IDHG_MAX_CROSS_PER_EVAL, "Khoảng cách tiến về 0 → kẹp tick size, giới hạn vòng lặp", IntegerToString(n));
  }

void IdhgRunPhase2Tests(void)
  {
   IdhgTestPhase2_Distance();
   IdhgTestPhase2_Test1();
   IdhgTestPhase2_Gap();
   IdhgTestPhase2_Block();
   IdhgTestPhase2_Lot();
   IdhgTestPhase2_Apply();
   IdhgTestPhase2_LevelState();
   IdhgTestPhase2_Reopen();
   IdhgTestPhase2_Independence();
  }

#endif
