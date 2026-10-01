// host_tests_phase1.h — test CHỈ chạy trên host (cần terminal giả lập).
#ifndef HOST_TESTS_PHASE1_H
#define HOST_TESTS_PHASE1_H

inline void HostTestPhase1(void) {
    T_Begin("P1.HOST.ONINIT (TEST 14)");
    g_simAcc.marginMode = ACCOUNT_MARGIN_MODE_RETAIL_NETTING;
    T_EqInt(OnInit(), INIT_FAILED, "TEST 14: tài khoản NETTING → INIT_FAILED");
    g_simAcc.marginMode = ACCOUNT_MARGIN_MODE_EXCHANGE;
    T_EqInt(OnInit(), INIT_FAILED, "Tài khoản EXCHANGE → INIT_FAILED");
    g_simAcc.marginMode = ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
    T_EqInt(OnInit(), INIT_SUCCEEDED, "Tài khoản HEDGING → INIT_SUCCEEDED");
    OnDeinit(REASON_REMOVE);
    double keep = InpBaseDistance;
    InpBaseDistance = 0.0;
    T_EqInt(OnInit(), INIT_PARAMETERS_INCORRECT, "Input sai (BaseDistance=0) → INIT_PARAMETERS_INCORRECT");
    InpBaseDistance = keep;
    double ts = g_simSym.tickSize;
    g_simSym.tickSize = 0.0;
    T_EqInt(OnInit(), INIT_FAILED, "Symbol thiếu tick size → INIT_FAILED");
    g_simSym.tickSize = ts;
    T_EqInt(OnInit(), INIT_SUCCEEDED, "Khôi phục → INIT_SUCCEEDED");
    OnDeinit(REASON_REMOVE);
}
#endif
