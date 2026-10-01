//+------------------------------------------------------------------+
//| IDHG_TestsPhase1.mqh — Self-test PHASE 1 (Core Architecture)      |
//| HEDGING check, symbol check, utils, config validation,           |
//| state machine, cycle state, pending config.                      |
//+------------------------------------------------------------------+
#ifndef IDHG_TESTS_PHASE1_MQH
#define IDHG_TESTS_PHASE1_MQH

#include "IDHG_TestFramework.mqh"
#include "..\IDHG_Config.mqh"
#include "..\IDHG_State.mqh"
#include "..\IDHG_Cycle.mqh"

//--- Thông số XAUUSD giả định cho test thuần logic
void IdhgTestSpec(SIdhgSymbolSpec &s)
  {
   s.Reset();
   s.name = "XAUUSD"; s.digits = 2; s.point = 0.01; s.tickSize = 0.01; s.tickValue = 1.0; s.tickValueLoss = 1.0;
   s.contractSize = 100.0; s.volMin = 0.01; s.volMax = 100.0; s.volStep = 0.01; s.marginHedged = 50.0;
   s.tradeMode = SYMBOL_TRADE_MODE_FULL; s.valid = true;
  }

void IdhgTestPhase1_Hedging(void)
  {
   T_Begin("P1.HEDGING");
   T_Check(IdhgIsHedgingMode(ACCOUNT_MARGIN_MODE_RETAIL_HEDGING), "HEDGING được chấp nhận");
   T_Check(!IdhgIsHedgingMode(ACCOUNT_MARGIN_MODE_RETAIL_NETTING), "NETTING bị từ chối");
   T_Check(!IdhgIsHedgingMode(ACCOUNT_MARGIN_MODE_EXCHANGE), "EXCHANGE bị từ chối");
  }

void IdhgTestPhase1_Symbol(void)
  {
   T_Begin("P1.SYMBOL");
   SIdhgSymbolSpec s;
   IdhgTestSpec(s);
   string err;
   T_Check(IdhgCheckSymbolSpec(s, err), "spec XAUUSD hợp lệ", err);
   s.tickSize = 0;
   T_Check(!IdhgCheckSymbolSpec(s, err), "tick size = 0 bị từ chối");
   IdhgTestSpec(s);
   s.volStep = 0;
   T_Check(!IdhgCheckSymbolSpec(s, err), "volume step = 0 bị từ chối");
   IdhgTestSpec(s);
   s.tickValue = 0;
   T_Check(!IdhgCheckSymbolSpec(s, err), "tick value = 0 bị từ chối (không hard-code)");
  }

void IdhgTestPhase1_Utils(void)
  {
   T_Begin("P1.UTILS");
   T_Near(PriceNormalize(5000.004, 0.01, 2), 5000.00, 1e-9, "PriceNormalize 5000.004 → 5000.00");
   T_Near(PriceNormalize(5000.006, 0.01, 2), 5000.01, 1e-9, "PriceNormalize 5000.006 → 5000.01");
   T_Near(PriceNormalize(5000.03, 0.05, 2), 5000.05, 1e-9, "PriceNormalize tick 0.05");
   T_Near(TickSizeNormalize(12.34, 0.25), 12.25, 1e-9, "TickSizeNormalize 0.25");
   T_Near(LotNormalize(0.012, 0.01, 100, 0.01, 0.01, 0), 0.01, 1e-9, "LotNormalize 0.012 → 0.01");
   T_Near(LotNormalize(0.0144, 0.01, 100, 0.01, 0.01, 0), 0.01, 1e-9, "LotNormalize 0.0144 → 0.01");
   T_Near(LotNormalize(0.03, 0.01, 100, 0.01, 0.01, 0), 0.03, 1e-9, "LotNormalize 0.03 (sai số float)");
   T_Near(LotNormalize(0.029, 0.01, 100, 0.01, 0.01, 0), 0.02, 1e-9, "LotNormalize làm tròn xuống");
   T_Near(LotNormalize(0.005, 0.01, 100, 0.01, 0.0, 0), 0.01, 1e-9, "LotNormalize < volume min → min");
   T_Near(LotNormalize(150, 0.01, 100, 0.01, 0.01, 0), 100.0, 1e-9, "LotNormalize > volume max → max");
   T_Near(LotNormalize(5, 0.01, 100, 0.01, 0.01, 1.0), 1.0, 1e-9, "LotNormalize theo MaxLot người dùng");
   T_Near(LotNormalize(0.15, 0.1, 100, 0.1, 0.0, 0), 0.1, 1e-9, "LotNormalize step 0.1");
   T_Near(LotNormalize(0.01, 0.01, 100, 0.01, 0.5, 0.2), 0.0, 1e-9, "MinLot > MaxLot → 0 (không hợp lệ)");
   T_Near(GetNetPL(10.0, -1.0, -0.5), 8.5, 1e-9, "Net = Profit + Swap + Commission (commission âm = phí)");
   T_Near(GetNetPL(10.0, 0.0, 0.3), 10.3, 1e-9, "Commission dương = rebate được cộng");
   T_Near(GetSpread(5000.00, 5000.25), 0.25, 1e-9, "Spread theo giá");
  }

void IdhgTestPhase1_Comment(void)
  {
   T_Begin("P1.COMMENT");
   string c = IdhgBuildComment("DHG", 1, IDHG_BUY, 5, 5010.0, 2);
   T_EqStr(c, "DHG|C001|BUY|L005|5010.00", "Build comment");
   T_Check(StringLen(c) <= IDHG_MAX_COMMENT_LEN, "Comment ≤ 31 ký tự");
   SIdhgCommentInfo info;
   T_Check(IdhgParseComment(c, "DHG", 2, info), "Parse comment hợp lệ");
   T_Check(info.ok && info.cycleId == 1 && info.side == IDHG_BUY && info.levelId == 5, "Parse đúng Cycle/Side/Level");
   T_Check(info.hasPrice && IdhgEQ(info.logicalPrice, 5010.0), "Parse đúng giá logic");
   T_Check(!IdhgParseComment("DHG|C0x1|BUY|L005", "DHG", 2, info), "CycleID hỏng → từ chối (không đoán)");
   T_Check(!IdhgParseComment("DHG|C001|BU", "DHG", 2, info), "Comment bị cắt → từ chối");
   T_Check(!IdhgParseComment("XYZ|C001|BUY|L005", "DHG", 2, info), "Prefix khác → từ chối");
   T_Check(!IdhgParseComment("DHG|C001|SELL|Lx5", "DHG", 2, info), "LevelID hỏng → từ chối");
   T_Check(IdhgParseComment("DHG|C002|SELL|L010|4990.0", "DHG", 2, info) && info.ok && !info.hasPrice,
           "Giá bị cắt → giữ ID, KHÔNG dùng giá");
   T_Check(IdhgParseComment("DHG|C002|SELL|L010", "DHG", 2, info) && info.side == IDHG_SELL && info.levelId == 10,
           "Comment không có giá vẫn parse ID");
   string longc = IdhgBuildComment("DHGXYZ", 12345, IDHG_SELL, 1234, 123456.78, 2);
   T_Check(StringLen(longc) <= IDHG_MAX_COMMENT_LEN, "Comment dài → bỏ phần giá để không bị cắt", longc);
   T_EqStr(IdhgCycleTag(7), "C007", "CycleTag C007");
   T_EqStr(IdhgLevelTag(12), "L012", "LevelTag L012");
  }

void IdhgTestPhase1_Config(void)
  {
   T_Begin("P1.CONFIG");
   CConfig cm;
   SIdhgConfig c;
   c.SetDefaults();
   T_Check(cm.Load(c), "Cấu hình mặc định hợp lệ", cm.LastError());
   T_Check(IdhgEQ(c.grid.lotMultiplier, 1.0), "LotMultiplier mặc định 1.0 (không martingale)");
   T_Check(c.risk.emergencyAction == IDHG_EMERGENCY_STOP_NEW_ENTRIES, "EmergencyAction mặc định STOP_NEW_ENTRIES");
   T_Check(!c.grid.reopenClosedLevel, "ReopenClosedLevel mặc định false");
   T_Check(!c.capacity.creditFutureProfit, "Không credit lời tương lai mặc định");

   SIdhgConfig bad = c;
   bad.grid.baseDistance = 0;
   T_Check(!cm.Load(bad), "BaseDistance = 0 bị từ chối");
   bad = c;
   bad.grid.minDistance = 20; bad.grid.maxDistance = 10;
   T_Check(!cm.Load(bad), "MinDistance > MaxDistance bị từ chối");
   bad = c;
   bad.risk.maxOrders = -1;
   T_Check(!cm.Load(bad), "MaxOrders âm bị từ chối");
   bad = c;
   bad.risk.maxOrders = 0; bad.risk.maxTotalLots = 0; bad.risk.maxSpread = 0;
   T_Check(cm.Load(bad), "MaxOrders/MaxLots/MaxSpread = 0 hợp lệ (không giới hạn)");
   bad = c;
   bad.profit.basketEnabled[IDHG_SELL] = true; bad.profit.basketTarget[IDHG_SELL] = 0;
   T_Check(!cm.Load(bad), "Basket SELL bật với target 0 bị từ chối");
   bad = c;
   bad.capacity.plannerEnabled = false; bad.capacity.mode = IDHG_CAP_SURVIVE_TO_PRICE;
   T_Check(!cm.Load(bad), "Capacity tự động khi planner tắt bị từ chối");
   bad = c;
   bad.general.commentPrefix = "D|G";
   T_Check(!cm.Load(bad), "Prefix chứa '|' bị từ chối");
   bad = c;
   bad.grid.lotMultiplier = 0;
   T_Check(!cm.Load(bad), "LotMultiplier = 0 bị từ chối");
   T_Check(StringLen(cm.Summary()) > 0, "Summary có nội dung");
  }

void IdhgTestPhase1_Pending(void)
  {
   T_Begin("P1.PENDING_CONFIG");
   CConfig cm;
   SIdhgConfig c;
   c.SetDefaults();
   cm.Load(c);
   SIdhgGridConfig g;
   cm.GetGrid(g);
   SIdhgGridConfig ng = g;
   ng.baseDistance = 15.0;
   T_Check(cm.SetPending(ng), "SetPending hợp lệ");
   T_Check(cm.HasPending(), "Có pending");
   SIdhgGridConfig act;
   cm.GetGrid(act);
   T_Near(act.baseDistance, 10.0, 1e-9, "Active KHÔNG đổi trước APPLY");
   cm.DiscardPending();
   T_Check(!cm.HasPending(), "DiscardPending xoá pending");
   cm.GetGrid(act);
   T_Near(act.baseDistance, 10.0, 1e-9, "Active giữ nguyên sau Discard");
   cm.SetPending(ng);
   T_Check(cm.ApplyPending(), "ApplyPending thành công");
   cm.GetGrid(act);
   T_Near(act.baseDistance, 15.0, 1e-9, "Active = pending sau APPLY");
   T_Check(!cm.HasPending(), "Hết pending sau APPLY");
   T_Check(!cm.ApplyPending(), "Apply khi không có pending → false");
   SIdhgGridConfig badg = ng;
   badg.baseDistance = -1;
   T_Check(!cm.SetPending(badg), "SetPending không hợp lệ bị từ chối");
   T_Check(!cm.HasPending(), "Pending không hợp lệ không được lưu");
   T_Check(cm.SetPending(act) && !cm.HasPending(), "Pending giống active → không tạo pending");
   cm.SetIndivEnabled(IDHG_BUY, false);
   T_Check(!cm.IndivEnabled(IDHG_BUY) && cm.IndivEnabled(IDHG_SELL), "Toggle runtime BUY không ảnh hưởng SELL");
  }

void IdhgTestPhase1_State(void)
  {
   T_Begin("P1.STATE_MACHINE");
   CState st;
   T_Check(st.State() == IDHG_STATE_IDLE, "Khởi đầu IDLE");
   T_Check(!st.AllowNewEntries() && st.AllowRiskLogic(), "IDLE: không vào lệnh, risk chạy");
   T_Check(!st.Pause(), "PAUSE từ IDLE bị từ chối");
   T_Check(st.Start(), "START từ IDLE");
   T_Check(st.AllowNewEntries() && st.AllowProfitLogic() && st.AllowRiskLogic(), "RUNNING: T/T/T");
   T_Check(!st.Start(), "START khi đang RUNNING bị từ chối");
   T_Check(st.Pause(), "PAUSE");
   T_Check(!st.AllowNewEntries() && !st.AllowProfitLogic() && st.AllowRiskLogic(), "PAUSED: F/F/T");
   T_Check(st.Resume() && st.State() == IDHG_STATE_RUNNING, "RESUME → RUNNING");
   T_Check(st.StopGrid(), "STOP GRID");
   T_Check(!st.AllowNewEntries() && st.AllowProfitLogic() && st.AllowRiskLogic(), "STOP_GRID: F/T/T");
   T_Check(st.Pause() && st.Resume() && st.State() == IDHG_STATE_STOP_GRID, "PAUSE từ STOP_GRID rồi RESUME → STOP_GRID");
   T_Check(st.ResumeGrid() && st.State() == IDHG_STATE_RUNNING, "RESUME GRID → RUNNING");
   T_Check(!st.ResetLogic(), "RESET LOGIC khi đang chạy bị từ chối");
   T_Check(st.EndCycle() && st.State() == IDHG_STATE_CYCLE_ENDED, "END CYCLE → CYCLE_ENDED");
   T_Check(!st.AllowNewEntries(), "CYCLE_ENDED: không tự vào lệnh");
   T_Check(!st.EndCycle(), "END CYCLE lần 2 bị từ chối");
   T_Check(st.Start(), "NEW CYCLE từ CYCLE_ENDED");
   T_Check(st.EndCycle() && st.ResetLogic() && st.State() == IDHG_STATE_IDLE, "RESET LOGIC → IDLE");
  }

void IdhgTestPhase1_Cycle(void)
  {
   T_Begin("P1.CYCLE");
   CCycleManager cy;
   T_Check(!cy.CanStart(IDHG_STATE_IDLE, 2, 0), "START bị chặn khi còn position cũ");
   T_Check(!cy.CanStart(IDHG_STATE_RUNNING, 0, 0), "START bị chặn khi chu kỳ đang chạy");
   T_Check(!cy.CanStart(IDHG_STATE_IDLE, 0, 1), "START bị chặn khi còn request chờ");
   T_Check(cy.CanStart(IDHG_STATE_IDLE, 0, 0), "START hợp lệ");
   int id = cy.Begin(5000.30, 5000.00, 0.01, 2, 1000);
   T_EqInt(id, 1, "CycleID đầu tiên = 1");
   T_Near(cy.RefPrice(), 5000.15, 1e-9, "ReferencePrice = Mid");
   T_Near(cy.RefAsk(), 5000.30, 1e-9, "Lưu ReferenceAsk");
   T_Near(cy.RefBid(), 5000.00, 1e-9, "Lưu ReferenceBid");
   T_Check(cy.MarkInitialSending(IDHG_BUY), "MarkInitialSending BUY");
   T_Check(!cy.MarkInitialSending(IDHG_BUY), "Gửi lại BUY khi đang SENDING bị chặn (chống trùng)");
   cy.ConfirmInitial(IDHG_BUY, 111, 5000.30);
   T_Check(!cy.MarkInitialSending(IDHG_BUY), "Gửi lại BUY sau khi đã mở bị chặn");
   T_Check(cy.MarkInitialSending(IDHG_SELL), "MarkInitialSending SELL độc lập với BUY");
   cy.FailInitial(IDHG_SELL, IDHG_R_SKIPPED_BROKER_ERROR);
   T_Check(cy.InitialStatus(IDHG_SELL) == IDHG_INIT_FAILED && cy.InitialReason(IDHG_SELL) == IDHG_R_SKIPPED_BROKER_ERROR,
           "FailInitial ghi lý do");
   T_Check(cy.InitialTicket(IDHG_BUY) == 111 && IdhgEQ(cy.InitialPrice(IDHG_BUY), 5000.30), "ConfirmInitial lưu ticket + giá khớp");
   T_Check(!cy.CanResetLogic(1, 0), "RESET LOGIC bị từ chối khi còn position");
   T_Check(cy.CanResetLogic(0, 0), "RESET LOGIC hợp lệ khi không còn position");
   cy.ResetLogic();
   T_EqInt(cy.CycleId(), 0, "Sau RESET: CycleID = 0");
   T_EqInt(cy.LastCycleId(), 1, "Sau RESET: không tái sử dụng ID");
   T_EqInt(cy.Begin(5000.30, 5000.00, 0.01, 2, 2000), 2, "Chu kỳ tiếp theo = 2");
   cy.NoteSeenCycleId(7);
   cy.ResetLogic();
   T_EqInt(cy.Begin(5000.30, 5000.00, 0.01, 2, 3000), 8, "CycleID tiếp sau ID lớn nhất trong lịch sử");
  }

void IdhgRunPhase1Tests(void)
  {
   IdhgTestPhase1_Hedging();
   IdhgTestPhase1_Symbol();
   IdhgTestPhase1_Utils();
   IdhgTestPhase1_Comment();
   IdhgTestPhase1_Config();
   IdhgTestPhase1_Pending();
   IdhgTestPhase1_State();
   IdhgTestPhase1_Cycle();
  }

#endif
