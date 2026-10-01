// mql5_broker_sim.h — broker giả lập (PHASE 1: chưa có giao dịch; chỉ trạng thái rỗng).
#ifndef MQL5_BROKER_SIM_H
#define MQL5_BROKER_SIM_H
#include "mql5_terminal.h"
inline double SimFloatingProfit() { return 0.0; }
inline double SimFloatingSwap() { return 0.0; }
inline double SimUsedMargin() { return 0.0; }
inline int SimPositionsCount() { return 0; }
#endif
