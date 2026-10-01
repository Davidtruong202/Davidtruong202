// host_tests_phase3.h — integration test Order Manager trên broker giả lập.
#ifndef HOST_TESTS_PHASE3_H
#define HOST_TESTS_PHASE3_H
#include <new>

// ---------------------------------------------------------------- tiện ích dùng chung cho test host
inline void HostAdvance(int sec) { g_simTerm.now += sec; }

inline void HostPump() {
    while (!g_sim.txQueue.empty()) {
        MqlTradeTransaction t = g_sim.txQueue.front();
        g_sim.txQueue.erase(g_sim.txQueue.begin());
        MqlTradeRequest rq = MqlTradeRequest();
        MqlTradeResult rs = MqlTradeResult();
        OnTradeTransaction(t, rq, rs);
    }
}

inline void HostDefaultCfg(SIdhgConfig &c) {
    c.SetDefaults();
    c.grid.minDistance = 0;
    c.grid.maxDistance = 0;
    c.general.dashboardEnabled = false;
}

// Khởi động lại EA (giữ broker + GlobalVariables), giống restart terminal/chart
inline int HostRestart(const SIdhgConfig &c) {
    g_engine.~CIdhgEngine();
    new (&g_engine) CIdhgEngine();
    string err;
    g_engine.SetQuiet(true);
    int rc = g_engine.Init(_Symbol, c, err);
    g_engine.SetQuiet(true);
    return rc;
}

// Môi trường mới hoàn toàn
inline int HostFresh(const SIdhgConfig &c, double mid = 5000.10, double spread = 0.20) {
    SimReset();
    g_simTerm.gvars.clear();
    g_simTerm.now = 1798761600;
    SimSetMid(mid, spread);
    return HostRestart(c);
}

inline void HostTick(double mid, double spread = 0.20) {
    HostAdvance(1);
    SimSetMid(mid, spread);
    g_engine.OnTick();
    HostPump();
}

inline int HostCountEaPositions(int type = -1) {
    int n = 0;
    for (auto &p : g_sim.positions)
        if (p.magic == g_engine.m_config.Magic() && p.symbol == g_simSym.name && (type < 0 || p.type == type)) n++;
    return n;
}

inline const SimPos *HostFindPos(const string &comment_prefix) {
    for (auto &p : g_sim.positions)
        if (p.comment.compare(0, comment_prefix.size(), comment_prefix) == 0) return &p;
    return nullptr;
}

inline ENUM_IDHG_LEVEL_STATUS HostLevelStatus(ENUM_IDHG_SIDE s, int id) {
    SIdhgLevel lv;
    if (!g_engine.m_grid.GetLevel(s, id, lv)) return IDHG_LVL_NONE;
    return lv.status;
}
inline SIdhgLevel HostLevel(ENUM_IDHG_SIDE s, int id) {
    SIdhgLevel lv;
    lv.Reset();
    g_engine.m_grid.GetLevel(s, id, lv);
    return lv;
}

// Snapshot position của EA (Phase 3: dựng thủ công từ broker giả lập)
inline void HostSnapshot(MqlArray<SIdhgPosition> &out) {
    ArrayResize(out, 0);
    for (auto &p : g_sim.positions) {
        if (p.magic != g_engine.m_config.Magic() || p.symbol != g_simSym.name) continue;
        SIdhgPosition s;
        s.Reset();
        s.ticket = p.ticket;
        s.side = p.type == POSITION_TYPE_BUY ? IDHG_BUY : IDHG_SELL;
        s.volume = p.volume;
        s.profit = SimPosProfit(p);
        s.net = s.profit + p.swap;
        out.v.push_back(s);
    }
}

// ---------------------------------------------------------------- tests
inline void HostTestPhase3_Start() {
    T_Begin("P3.HOST.START (initial BUY+SELL)");
    SIdhgConfig c;
    HostDefaultCfg(c);
    T_EqInt(HostFresh(c, 5000.10, 0.20), INIT_SUCCEEDED, "Init");
    string msg;
    T_Check(g_engine.Command(IDHG_CMD_START, msg), "START", msg);
    HostPump();
    T_EqInt(HostCountEaPositions(POSITION_TYPE_BUY), 1, "1 BUY mở");
    T_EqInt(HostCountEaPositions(POSITION_TYPE_SELL), 1, "1 SELL mở");
    T_Near(g_engine.m_cycle.RefPrice(), 5000.10, 1e-9, "Reference = Mid 5000.10");
    const SimPos *b = HostFindPos("DHG|C001|BUY|L000");
    const SimPos *s = HostFindPos("DHG|C001|SELL|L000");
    T_Check(b && std::fabs(b->priceOpen - 5000.20) < 1e-9, "BUY khớp theo ASK 5000.20");
    T_Check(s && std::fabs(s->priceOpen - 5000.00) < 1e-9, "SELL khớp theo BID 5000.00");
    SIdhgLevel lb = HostLevel(IDHG_BUY, 0);
    T_Check(lb.status == IDHG_LVL_OPEN && std::fabs(lb.actualEntryPrice - 5000.20) < 1e-9 && std::fabs(lb.logicalPrice - 5000.10) < 1e-9,
            "Level0 BUY OPEN: actual 5000.20 ≠ logical 5000.10");
    T_EqInt(g_engine.m_grid.Opened(IDHG_BUY) + g_engine.m_grid.Opened(IDHG_SELL), 2, "ĐÃ RẢI = 2");
    T_Check(g_engine.m_cycle.InitialStatus(IDHG_BUY) == IDHG_INIT_CONFIRMED && g_engine.m_cycle.InitialStatus(IDHG_SELL) == IDHG_INIT_CONFIRMED,
            "ConfirmInitial cả hai phía");
    int sends = g_sim.sendCount;
    T_Check(!g_engine.Command(IDHG_CMD_START, msg), "START lần 2 bị từ chối", msg);
    for (int i = 0; i < 5; i++) HostTick(5000.10);
    T_EqInt(g_sim.sendCount, sends, "OnTick nhiều lần không gửi trùng initial");
    HostTick(5010.10);
    T_Check(HostFindPos("DHG|C001|BUY|L001|5010.10") != nullptr, "Giá lên 5010.10 → BUY L001");
    T_EqInt(HostCountEaPositions(POSITION_TYPE_SELL), 1, "SELL không thêm khi giá lên");
    HostTick(4990.10);
    T_Check(HostFindPos("DHG|C001|SELL|L001|4990.10") != nullptr, "Giá xuống 4990.10 → SELL L001");
}

inline void HostTestPhase3_Gap() {
    T_Begin("P3.HOST.GAP execution");
    SIdhgConfig c;
    HostDefaultCfg(c);
    HostFresh(c, 5000.00, 0.20);
    string msg;
    g_engine.Command(IDHG_CMD_START, msg);
    HostTick(5045.00);
    bool all = true;
    for (int i = 1; i <= 4; i++) {
        string tag = "DHG|C001|BUY|L00" + std::to_string(i) + "|" + DoubleToString(5000.0 + 10.0 * i, 2);
        all = all && HostFindPos(tag) != nullptr;
    }
    T_Check(all, "OPEN_ALL_CROSSED: mở 5010,5020,5030,5040");
    T_EqInt(HostCountEaPositions(POSITION_TYPE_BUY), 5, "5 BUY (L0..L4)");
    // thứ tự gần → xa: ticket tăng dần theo level
    T_Check(HostFindPos("DHG|C001|BUY|L001")->ticket < HostFindPos("DHG|C001|BUY|L004")->ticket, "Thứ tự gửi gần → xa");
    HostTick(4955.00);
    T_EqInt(HostCountEaPositions(POSITION_TYPE_SELL), 5, "SELL gap 4955: L1..L4 + L0");
}

inline void HostTestPhase3_Blocks() {
    T_Begin("P3.HOST.SPREAD/MARGIN/REJECT (TEST 15)");
    SIdhgConfig c;
    HostDefaultCfg(c);
    c.risk.maxSpread = 1.0;
    HostFresh(c, 5000.00, 0.20);
    string msg;
    g_engine.Command(IDHG_CMD_START, msg);
    int sends = g_sim.sendCount;
    HostTick(5010.00, 2.0);
    T_EqInt(g_sim.sendCount, sends, "Spread 2.0 > 1.0: không gửi lệnh");
    T_Check(HostLevelStatus(IDHG_BUY, 1) == IDHG_LVL_SKIPPED && HostLevel(IDHG_BUY, 1).reason == IDHG_R_SKIPPED_SPREAD,
            "Level SKIPPED_SPREAD");
    HostTick(5020.00, 0.2);
    T_Check(HostLevelStatus(IDHG_BUY, 2) == IDHG_LVL_OPEN, "Spread bình thường: level tương lai mở bình thường");
    // TEST 15: broker reject (không tạm thời)
    int opened = g_engine.m_grid.Opened(IDHG_BUY);
    g_sim.rejectQueue.push_back(TRADE_RETCODE_REJECT);
    HostTick(5030.00);
    SIdhgLevel l3 = HostLevel(IDHG_BUY, 3);
    T_Check(l3.status == IDHG_LVL_SKIPPED && l3.reason == IDHG_R_SKIPPED_BROKER_ERROR && l3.retcode == TRADE_RETCODE_REJECT,
            "TEST 15: reject → SKIPPED_BROKER_ERROR + retcode");
    T_EqInt(g_engine.m_grid.Opened(IDHG_BUY), opened, "TEST 15: reject KHÔNG tính ĐÃ RẢI");
    T_Check(HostFindPos("DHG|C001|BUY|L003") == nullptr, "Không có position cho level bị reject");
    sends = g_sim.sendCount;
    HostTick(5031.00);
    HostTick(5032.00);
    T_EqInt(g_sim.sendCount, sends, "Không retry level bị reject");
    // Margin
    g_simAcc.balance = 50.0;
    HostTick(5040.00);
    T_Check(HostLevel(IDHG_BUY, 4).reason == IDHG_R_SKIPPED_MARGIN, "Free margin không đủ → SKIPPED_MARGIN",
            IdhgReasonCode(HostLevel(IDHG_BUY, 4).reason));
}

inline void HostTestPhase3_Transient() {
    T_Begin("P3.HOST.TRANSIENT RETRY");
    SIdhgConfig c;
    HostDefaultCfg(c);
    c.general.maxSendAttempts = 3;
    HostFresh(c, 5000.00, 0.20);
    string msg;
    g_engine.Command(IDHG_CMD_START, msg);
    g_sim.rejectQueue.push_back(TRADE_RETCODE_REQUOTE);
    g_sim.rejectQueue.push_back(TRADE_RETCODE_PRICE_CHANGED);
    HostTick(5010.00);
    T_Check(HostLevelStatus(IDHG_BUY, 1) == IDHG_LVL_FAILED, "Lần 1 REQUOTE → FAILED (chờ thử lại)");
    T_EqInt(g_engine.m_grid.Opened(IDHG_BUY), 1, "Chưa tính ĐÃ RẢI");
    HostTick(5010.50);
    HostTick(5010.60);
    T_Check(HostLevelStatus(IDHG_BUY, 1) == IDHG_LVL_OPEN && g_engine.m_grid.Attempts(IDHG_BUY, 1) == 3, "Lần 3 thành công → OPEN");
    g_sim.rejectQueue.push_back(TRADE_RETCODE_REQUOTE);
    g_sim.rejectQueue.push_back(TRADE_RETCODE_REQUOTE);
    g_sim.rejectQueue.push_back(TRADE_RETCODE_REQUOTE);
    HostTick(5020.00);
    HostTick(5020.10);
    HostTick(5020.20);
    int sends = g_sim.sendCount;
    HostTick(5020.30);
    HostTick(5020.40);
    T_Check(HostLevelStatus(IDHG_BUY, 2) == IDHG_LVL_SKIPPED && HostLevel(IDHG_BUY, 2).reason == IDHG_R_SKIPPED_BROKER_ERROR,
            "Hết số lần thử → SKIPPED_BROKER_ERROR");
    T_EqInt(g_sim.sendCount, sends, "Không retry vô hạn");
}

inline void HostTestPhase3_Async() {
    T_Begin("P3.HOST.ASYNC CONFIRM / DUPLICATE");
    SIdhgConfig c;
    HostDefaultCfg(c);
    HostFresh(c, 5000.00, 0.20);
    g_sim.asyncMode = true;
    string msg;
    g_engine.Command(IDHG_CMD_START, msg);
    T_EqInt(g_sim.sendCount, 2, "Gửi 2 initial");
    T_Check(HostLevelStatus(IDHG_BUY, 0) == IDHG_LVL_SENDING && g_engine.m_cycle.IsInitialPending(IDHG_BUY), "Chờ xác nhận: SENDING");
    T_EqInt(g_engine.m_grid.Opened(IDHG_BUY), 0, "SENDING không tính ĐÃ RẢI");
    for (int i = 0; i < 5; i++) HostTick(5000.00);
    T_EqInt(g_sim.sendCount, 2, "OnTick nhiều lần khi đang chờ: KHÔNG gửi trùng");
    T_Check(!g_engine.Command(IDHG_CMD_START, msg), "START khi request đang chờ bị từ chối");
    SimFlushAsync();
    HostPump();
    T_Check(HostLevelStatus(IDHG_BUY, 0) == IDHG_LVL_OPEN && HostLevelStatus(IDHG_SELL, 0) == IDHG_LVL_OPEN,
            "OnTradeTransaction xác nhận → OPEN");
    T_EqInt(g_engine.m_grid.Opened(IDHG_BUY) + g_engine.m_grid.Opened(IDHG_SELL), 2, "ĐÃ RẢI = 2 sau xác nhận");
    T_EqInt(g_engine.m_order.PendingOpenCount(), 0, "Không còn request chờ");
    // broker huỷ sau khi nhận
    HostTick(5010.00);
    T_Check(HostLevelStatus(IDHG_BUY, 1) == IDHG_LVL_SENDING, "L1 SENDING");
    SimRejectAsync();
    HostAdvance(c.general.confirmTimeoutSec + 1);
    g_engine.OnTimer();
    T_Check(HostLevelStatus(IDHG_BUY, 1) == IDHG_LVL_SKIPPED && HostLevel(IDHG_BUY, 1).reason == IDHG_R_SKIPPED_BROKER_ERROR,
            "Order bị huỷ → SKIPPED_BROKER_ERROR (đối soát)");
    T_EqInt(g_engine.m_grid.Opened(IDHG_BUY), 1, "Không tính ĐÃ RẢI");
    // deal tới nhưng transaction bị mất → đối soát lịch sử
    HostTick(5020.00);
    SimFlushAsync();
    g_sim.txQueue.clear();
    T_Check(HostLevelStatus(IDHG_BUY, 2) == IDHG_LVL_SENDING, "Mất transaction: vẫn SENDING");
    HostAdvance(c.general.confirmTimeoutSec + 1);
    g_engine.OnTimer();
    T_Check(HostLevelStatus(IDHG_BUY, 2) == IDHG_LVL_OPEN, "Đối soát lịch sử deal → OPEN");
    g_sim.asyncMode = false;
}

inline void HostTestPhase3_Close() {
    T_Begin("P3.HOST.CLOSE (duplicate close / confirmation / foreign)");
    SIdhgConfig c;
    HostDefaultCfg(c);
    HostFresh(c, 5000.00, 0.20);
    ulong manual = SimOpenForeign(POSITION_TYPE_BUY, 0.05, 0, "manual");
    ulong otherEa = SimOpenForeign(POSITION_TYPE_SELL, 0.02, 999, "other EA");
    ulong otherSym = SimOpenForeign(POSITION_TYPE_BUY, 0.01, c.general.magic, "DHG|C001|BUY|L000", "EURUSD");
    string msg;
    T_Check(g_engine.Command(IDHG_CMD_START, msg), "START khi có lệnh tay / EA khác / symbol khác", msg);
    HostPump();
    g_sim.asyncMode = true;
    ulong buy0 = HostLevel(IDHG_BUY, 0).ticket;
    SIdhgExecEvent ev;
    SIdhgMarket mk = g_engine.m_mk;
    T_Check(g_engine.m_order.ClosePosition(buy0, IDHG_CR_MANUAL_SIDE, mk, TimeCurrent(), ev) && ev.type == IDHG_EV_CLOSE_SENT, "Gửi đóng BUY L0");
    T_Check(!g_engine.m_order.ClosePosition(buy0, IDHG_CR_MANUAL_SIDE, mk, TimeCurrent(), ev) && ev.type == IDHG_EV_CLOSE_SKIPPED,
            "Gửi đóng lần 2 bị chặn (chống trùng)");
    T_EqInt(g_sim.closeSendCount, 1, "Chỉ 1 request đóng");
    T_Check(HostLevelStatus(IDHG_BUY, 0) == IDHG_LVL_OPEN, "OrderSend DONE nhưng chưa có deal OUT → vẫn OPEN");
    SimFlushAsync();
    HostPump();
    T_Check(HostLevelStatus(IDHG_BUY, 0) == IDHG_LVL_CLOSED, "Deal OUT xác nhận → CLOSED");
    T_EqInt(g_engine.m_grid.Closed(IDHG_BUY), 1, "ĐÃ CHỐT = 1");
    g_sim.asyncMode = false;
    T_Check(!g_engine.m_order.ClosePosition(manual, IDHG_CR_MANUAL_ALL, mk, TimeCurrent(), ev), "Không đóng lệnh tay");
    T_Check(!g_engine.m_order.ClosePosition(otherEa, IDHG_CR_MANUAL_ALL, mk, TimeCurrent(), ev), "Không đóng lệnh EA khác");
    T_Check(!g_engine.m_order.ClosePosition(otherSym, IDHG_CR_MANUAL_ALL, mk, TimeCurrent(), ev), "Không đóng lệnh symbol khác");
    MqlArray<SIdhgPosition> snap;
    HostSnapshot(snap);
    MqlArray<SIdhgExecEvent> evs;
    g_engine.m_order.CloseAll(snap, IDHG_CR_MANUAL_ALL, mk, TimeCurrent(), evs);
    HostPump();
    T_EqInt(HostCountEaPositions(), 0, "CloseAll đóng hết lệnh EA");
    T_EqInt((long)g_sim.positions.size(), 3, "Lệnh tay / EA khác / symbol khác vẫn còn");
}

inline void HostTestPhase3_SideOff() {
    T_Begin("P3.HOST.SIDE OFF");
    SIdhgConfig c;
    HostDefaultCfg(c);
    c.general.sideEnabled[IDHG_BUY] = false;
    HostFresh(c, 5000.00, 0.20);
    string msg;
    g_engine.Command(IDHG_CMD_START, msg);
    T_EqInt(HostCountEaPositions(POSITION_TYPE_BUY), 0, "BUY OFF: không mở initial BUY");
    T_EqInt(HostCountEaPositions(POSITION_TYPE_SELL), 1, "SELL vẫn mở");
    HostTick(5010.00);
    T_EqInt(HostCountEaPositions(POSITION_TYPE_BUY), 0, "BUY OFF: không mở level BUY");
    T_Check(HostLevel(IDHG_BUY, 1).reason == IDHG_R_SKIPPED_SIDE_OFF, "Level BUY vượt khi OFF → SKIPPED_SIDE_OFF");
}

inline void HostTestPhase3() {
    HostTestPhase3_Start();
    HostTestPhase3_Gap();
    HostTestPhase3_Blocks();
    HostTestPhase3_Transient();
    HostTestPhase3_Async();
    HostTestPhase3_Close();
    HostTestPhase3_SideOff();
}
#endif
