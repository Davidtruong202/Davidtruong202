// script_main.cpp — biên dịch + chạy một script self-test MQL5 (OnStart) trên host.
#include "mql5_shim.h"
#include "mql5_terminal.h"
#include "mql5_broker_sim.h"
#include "sim_globals.h"
#include SCRIPT_PATH
int main() {
    OnStart();
    return g_tFail == 0 ? 0 : 1;
}
