// Định nghĩa biến toàn cục của terminal giả lập (đúng 1 lần mỗi chương trình).
#ifndef SIM_GLOBALS_H
#define SIM_GLOBALS_H
SimSymbolState g_simSym;
SimAccountState g_simAcc;
SimTerminalState g_simTerm;
SimBrokerState g_sim;
bool g_shim_quiet = false;
std::vector<string> g_shim_log;
#endif
