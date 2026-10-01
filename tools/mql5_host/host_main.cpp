// host_main.cpp — chạy toàn bộ self-test IDHG trên host (EA + test dùng chung + test host).
#include "mql5_shim.h"
#include "mql5_terminal.h"
#include "mql5_broker_sim.h"
#include "sim_globals.h"
#include "Experts/IDHG/IndependentDynamicHedgeGridEA.mq5"
#include "Experts/IDHG/Tests/IDHG_TestsAll.mqh"
#include "host_tests_all.h"

int main() {
    IdhgRunAllSharedTests();
    HostRunAllTests();
    return T_Report() == 0 ? 0 : 1;
}
