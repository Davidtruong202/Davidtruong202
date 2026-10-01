// mql5_terminal.h — terminal/broker GIẢ LẬP cho host harness IDHG.
// Tên hằng & hàm theo đúng tài liệu MQL5; giá trị số là tuỳ ý (trừ khi ghi chú).
// Phần giao dịch (OrderSend, deal, history) nằm ở mql5_broker_sim.h.
#ifndef MQL5_TERMINAL_H
#define MQL5_TERMINAL_H
#include "mql5_shim.h"

// ---------------------------------------------------------------- init / deinit
#define INIT_SUCCEEDED 0
#define INIT_FAILED 1
#define INIT_PARAMETERS_INCORRECT 2
#define INIT_AGENT_NOT_SUITABLE 3
#define REASON_PROGRAM 0
#define REASON_REMOVE 1
#define REASON_RECOMPILE 2
#define REASON_CHARTCHANGE 3
#define REASON_CHARTCLOSE 4
#define REASON_PARAMETERS 5
#define REASON_ACCOUNT 6
#define REASON_TEMPLATE 7
#define REASON_INITFAILED 8
#define REASON_CLOSE 9

// ---------------------------------------------------------------- account
enum ENUM_ACCOUNT_INFO_INTEGER { ACCOUNT_LOGIN, ACCOUNT_TRADE_MODE, ACCOUNT_LEVERAGE, ACCOUNT_LIMIT_ORDERS,
    ACCOUNT_MARGIN_SO_MODE, ACCOUNT_TRADE_ALLOWED, ACCOUNT_TRADE_EXPERT, ACCOUNT_MARGIN_MODE, ACCOUNT_CURRENCY_DIGITS,
    ACCOUNT_FIFO_CLOSE, ACCOUNT_HEDGE_ALLOWED };
enum ENUM_ACCOUNT_INFO_DOUBLE { ACCOUNT_BALANCE, ACCOUNT_CREDIT, ACCOUNT_PROFIT, ACCOUNT_EQUITY, ACCOUNT_MARGIN,
    ACCOUNT_MARGIN_FREE, ACCOUNT_MARGIN_LEVEL, ACCOUNT_MARGIN_SO_CALL, ACCOUNT_MARGIN_SO_SO, ACCOUNT_MARGIN_INITIAL,
    ACCOUNT_MARGIN_MAINTENANCE, ACCOUNT_ASSETS, ACCOUNT_LIABILITIES, ACCOUNT_COMMISSION_BLOCKED };
enum ENUM_ACCOUNT_INFO_STRING { ACCOUNT_NAME, ACCOUNT_SERVER, ACCOUNT_CURRENCY, ACCOUNT_COMPANY };
enum ENUM_ACCOUNT_MARGIN_MODE { ACCOUNT_MARGIN_MODE_RETAIL_NETTING, ACCOUNT_MARGIN_MODE_EXCHANGE, ACCOUNT_MARGIN_MODE_RETAIL_HEDGING };
enum ENUM_ACCOUNT_STOPOUT_MODE { ACCOUNT_STOPOUT_MODE_PERCENT, ACCOUNT_STOPOUT_MODE_MONEY };
enum ENUM_ACCOUNT_TRADE_MODE { ACCOUNT_TRADE_MODE_DEMO, ACCOUNT_TRADE_MODE_CONTEST, ACCOUNT_TRADE_MODE_REAL };

// ---------------------------------------------------------------- symbol
enum ENUM_SYMBOL_INFO_INTEGER { SYMBOL_SELECT, SYMBOL_DIGITS, SYMBOL_SPREAD, SYMBOL_SPREAD_FLOAT, SYMBOL_TRADE_MODE,
    SYMBOL_TRADE_EXEMODE, SYMBOL_TRADE_STOPS_LEVEL, SYMBOL_TRADE_FREEZE_LEVEL, SYMBOL_FILLING_MODE, SYMBOL_EXPIRATION_MODE,
    SYMBOL_ORDER_MODE, SYMBOL_MARGIN_HEDGED_USE_LEG, SYMBOL_TIME, SYMBOL_VISIBLE };
enum ENUM_SYMBOL_INFO_DOUBLE { SYMBOL_BID, SYMBOL_ASK, SYMBOL_POINT, SYMBOL_TRADE_TICK_VALUE, SYMBOL_TRADE_TICK_VALUE_PROFIT,
    SYMBOL_TRADE_TICK_VALUE_LOSS, SYMBOL_TRADE_TICK_SIZE, SYMBOL_TRADE_CONTRACT_SIZE, SYMBOL_VOLUME_MIN, SYMBOL_VOLUME_MAX,
    SYMBOL_VOLUME_STEP, SYMBOL_VOLUME_LIMIT, SYMBOL_MARGIN_INITIAL, SYMBOL_MARGIN_MAINTENANCE, SYMBOL_MARGIN_HEDGED,
    SYMBOL_SWAP_LONG, SYMBOL_SWAP_SHORT };
enum ENUM_SYMBOL_INFO_STRING { SYMBOL_DESCRIPTION, SYMBOL_CURRENCY_BASE, SYMBOL_CURRENCY_PROFIT, SYMBOL_CURRENCY_MARGIN, SYMBOL_PATH };
enum ENUM_SYMBOL_TRADE_MODE { SYMBOL_TRADE_MODE_DISABLED, SYMBOL_TRADE_MODE_LONGONLY, SYMBOL_TRADE_MODE_SHORTONLY,
    SYMBOL_TRADE_MODE_CLOSEONLY, SYMBOL_TRADE_MODE_FULL };
// Giá trị bit theo đúng MQL5
#define SYMBOL_FILLING_FOK 1
#define SYMBOL_FILLING_IOC 2

// ---------------------------------------------------------------- terminal / mql
enum ENUM_TERMINAL_INFO_INTEGER { TERMINAL_CONNECTED, TERMINAL_TRADE_ALLOWED, TERMINAL_DLLS_ALLOWED };
enum ENUM_MQL_INFO_INTEGER { MQL_TRADE_ALLOWED, MQL_TESTER, MQL_OPTIMIZATION, MQL_VISUAL_MODE, MQL_DEBUG };

struct MqlTick { datetime time; double bid; double ask; double last; ulong volume; long time_msc; uint flags; double volume_real; };

struct SimSymbolState {
    string name = "XAUUSD";
    int digits = 2;
    double point = 0.01, tickSize = 0.01, contractSize = 100.0;
    double volMin = 0.01, volMax = 100.0, volStep = 0.01, volLimit = 0.0;
    double marginHedged = 50.0;  // = contract/2 → hedged margin 50%
    bool hedgedUseLeg = false;
    long tradeMode = SYMBOL_TRADE_MODE_FULL;
    long fillingMode = SYMBOL_FILLING_FOK | SYMBOL_FILLING_IOC;
    long stopsLevel = 0, freezeLevel = 0;
    double bid = 5000.00, ask = 5000.20;
    datetime lastTickTime = 0;
};
struct SimAccountState {
    long login = 123456;
    long marginMode = ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
    long tradeMode = ACCOUNT_TRADE_MODE_DEMO;
    long leverage = 100;
    double balance = 10000.0;
    double credit = 0.0;
    double soCall = 100.0, soSo = 50.0;
    long soMode = ACCOUNT_STOPOUT_MODE_PERCENT;
    bool tradeAllowed = true, tradeExpert = true;
    string currency = "USD";
};
struct SimTerminalState {
    bool connected = true, terminalTradeAllowed = true, mqlTradeAllowed = true, tester = false;
    datetime now = 1798761600;  // 2027-01-01 00:00:00 UTC
    int lastError = 0;
    int uninitReason = 0;
    std::map<string, double> gvars;
};

extern SimSymbolState g_simSym;
extern SimAccountState g_simAcc;
extern SimTerminalState g_simTerm;

// Hàm do broker sim cung cấp (định nghĩa trong mql5_broker_sim.h)
double SimFloatingProfit();
double SimFloatingSwap();
double SimUsedMargin();
int SimPositionsCount();

#define _Symbol (g_simSym.name)
#define _Digits (g_simSym.digits)
#define _Point (g_simSym.point)
inline string Symbol() { return g_simSym.name; }
#define _LastError (g_simTerm.lastError)
inline int GetLastError() { return g_simTerm.lastError; }
inline void ResetLastError() { g_simTerm.lastError = 0; }
inline void SetUserError(ushort e) { g_simTerm.lastError = 65536 + e; }
inline int UninitializeReason() { return g_simTerm.uninitReason; }
inline datetime TimeCurrent() { return g_simTerm.now; }
inline datetime TimeTradeServer() { return g_simTerm.now; }
inline datetime TimeLocal() { return g_simTerm.now; }
inline uint GetTickCount() { return (uint)(g_simTerm.now * 1000); }
inline bool IsStopped() { return false; }
inline long ChartID() { return 1; }
inline bool EventSetTimer(int) { return true; }
inline void EventKillTimer() {}
inline void Comment(const string &) {}
template <typename... A> void Alert(A... a) { Print(a...); }

inline long AccountInfoInteger(ENUM_ACCOUNT_INFO_INTEGER p) {
    switch (p) {
        case ACCOUNT_LOGIN: return g_simAcc.login;
        case ACCOUNT_TRADE_MODE: return g_simAcc.tradeMode;
        case ACCOUNT_LEVERAGE: return g_simAcc.leverage;
        case ACCOUNT_MARGIN_SO_MODE: return g_simAcc.soMode;
        case ACCOUNT_TRADE_ALLOWED: return g_simAcc.tradeAllowed;
        case ACCOUNT_TRADE_EXPERT: return g_simAcc.tradeExpert;
        case ACCOUNT_MARGIN_MODE: return g_simAcc.marginMode;
        case ACCOUNT_CURRENCY_DIGITS: return 2;
        case ACCOUNT_HEDGE_ALLOWED: return g_simAcc.marginMode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
        default: return 0;
    }
}
inline double AccountInfoDouble(ENUM_ACCOUNT_INFO_DOUBLE p) {
    double eq = g_simAcc.balance + g_simAcc.credit + SimFloatingProfit() + SimFloatingSwap();
    double mg = SimUsedMargin();
    switch (p) {
        case ACCOUNT_BALANCE: return g_simAcc.balance;
        case ACCOUNT_CREDIT: return g_simAcc.credit;
        case ACCOUNT_PROFIT: return SimFloatingProfit() + SimFloatingSwap();
        case ACCOUNT_EQUITY: return eq;
        case ACCOUNT_MARGIN: return mg;
        case ACCOUNT_MARGIN_FREE: return eq - mg;
        case ACCOUNT_MARGIN_LEVEL: return mg > 0 ? eq / mg * 100.0 : 0.0;
        case ACCOUNT_MARGIN_SO_CALL: return g_simAcc.soCall;
        case ACCOUNT_MARGIN_SO_SO: return g_simAcc.soSo;
        default: return 0.0;
    }
}
inline string AccountInfoString(ENUM_ACCOUNT_INFO_STRING p) {
    switch (p) {
        case ACCOUNT_CURRENCY: return g_simAcc.currency;
        case ACCOUNT_SERVER: return "SimServer";
        case ACCOUNT_COMPANY: return "SimBroker";
        default: return "Sim";
    }
}

inline bool SimKnownSymbol(const string &s) { return s == g_simSym.name; }
inline long SymbolInfoInteger(const string &s, ENUM_SYMBOL_INFO_INTEGER p) {
    if (!SimKnownSymbol(s)) { g_simTerm.lastError = 4301; return 0; }
    switch (p) {
        case SYMBOL_SELECT: case SYMBOL_VISIBLE: return 1;
        case SYMBOL_DIGITS: return g_simSym.digits;
        case SYMBOL_SPREAD: return (long)std::llround((g_simSym.ask - g_simSym.bid) / g_simSym.point);
        case SYMBOL_SPREAD_FLOAT: return 1;
        case SYMBOL_TRADE_MODE: return g_simSym.tradeMode;
        case SYMBOL_TRADE_EXEMODE: return 2;  // market
        case SYMBOL_TRADE_STOPS_LEVEL: return g_simSym.stopsLevel;
        case SYMBOL_TRADE_FREEZE_LEVEL: return g_simSym.freezeLevel;
        case SYMBOL_FILLING_MODE: return g_simSym.fillingMode;
        case SYMBOL_MARGIN_HEDGED_USE_LEG: return g_simSym.hedgedUseLeg ? 1 : 0;
        case SYMBOL_TIME: return g_simSym.lastTickTime;
        default: return 0;
    }
}
inline double SymbolInfoDouble(const string &s, ENUM_SYMBOL_INFO_DOUBLE p) {
    if (!SimKnownSymbol(s)) { g_simTerm.lastError = 4301; return 0; }
    switch (p) {
        case SYMBOL_BID: return g_simSym.bid;
        case SYMBOL_ASK: return g_simSym.ask;
        case SYMBOL_POINT: return g_simSym.point;
        case SYMBOL_TRADE_TICK_SIZE: return g_simSym.tickSize;
        case SYMBOL_TRADE_TICK_VALUE: case SYMBOL_TRADE_TICK_VALUE_PROFIT: case SYMBOL_TRADE_TICK_VALUE_LOSS:
            return g_simSym.tickSize * g_simSym.contractSize;
        case SYMBOL_TRADE_CONTRACT_SIZE: return g_simSym.contractSize;
        case SYMBOL_VOLUME_MIN: return g_simSym.volMin;
        case SYMBOL_VOLUME_MAX: return g_simSym.volMax;
        case SYMBOL_VOLUME_STEP: return g_simSym.volStep;
        case SYMBOL_VOLUME_LIMIT: return g_simSym.volLimit;
        case SYMBOL_MARGIN_HEDGED: return g_simSym.marginHedged;
        default: return 0.0;
    }
}
inline bool SymbolInfoDouble(const string &s, ENUM_SYMBOL_INFO_DOUBLE p, double &v) {
    if (!SimKnownSymbol(s)) { g_simTerm.lastError = 4301; return false; }
    v = SymbolInfoDouble(s, p);
    return true;
}
inline bool SymbolInfoInteger(const string &s, ENUM_SYMBOL_INFO_INTEGER p, long &v) {
    if (!SimKnownSymbol(s)) { g_simTerm.lastError = 4301; return false; }
    v = SymbolInfoInteger(s, p);
    return true;
}
inline string SymbolInfoString(const string &s, ENUM_SYMBOL_INFO_STRING p) {
    (void)s;
    switch (p) {
        case SYMBOL_CURRENCY_PROFIT: case SYMBOL_CURRENCY_MARGIN: return "USD";
        case SYMBOL_CURRENCY_BASE: return "XAU";
        default: return "Gold";
    }
}
inline bool SymbolInfoTick(const string &s, MqlTick &t) {
    if (!SimKnownSymbol(s)) { g_simTerm.lastError = 4301; return false; }
    t = MqlTick();
    t.time = g_simSym.lastTickTime ? g_simSym.lastTickTime : g_simTerm.now;
    t.time_msc = t.time * 1000;
    t.bid = g_simSym.bid;
    t.ask = g_simSym.ask;
    return true;
}
inline bool SymbolSelect(const string &s, bool) { return SimKnownSymbol(s); }

inline long TerminalInfoInteger(ENUM_TERMINAL_INFO_INTEGER p) {
    switch (p) {
        case TERMINAL_CONNECTED: return g_simTerm.connected;
        case TERMINAL_TRADE_ALLOWED: return g_simTerm.terminalTradeAllowed;
        default: return 0;
    }
}
inline long MQLInfoInteger(ENUM_MQL_INFO_INTEGER p) {
    switch (p) {
        case MQL_TRADE_ALLOWED: return g_simTerm.mqlTradeAllowed;
        case MQL_TESTER: return g_simTerm.tester;
        default: return 0;
    }
}

// ---------------------------------------------------------------- global variables
inline datetime GlobalVariableSet(const string &n, double v) {
    if (n.size() > 63) { g_simTerm.lastError = 4501; fprintf(stderr, "CRITICAL: GV name > 63: %s\n", n.c_str()); abort(); }
    g_simTerm.gvars[n] = v;
    return g_simTerm.now;
}
inline double GlobalVariableGet(const string &n) {
    auto it = g_simTerm.gvars.find(n);
    if (it == g_simTerm.gvars.end()) { g_simTerm.lastError = 4501; return 0.0; }
    return it->second;
}
inline bool GlobalVariableGet(const string &n, double &v) {
    auto it = g_simTerm.gvars.find(n);
    if (it == g_simTerm.gvars.end()) { g_simTerm.lastError = 4501; return false; }
    v = it->second;
    return true;
}
inline bool GlobalVariableCheck(const string &n) { return g_simTerm.gvars.count(n) > 0; }
inline bool GlobalVariableDel(const string &n) { return g_simTerm.gvars.erase(n) > 0; }
inline int GlobalVariablesDeleteAll(const string &prefix = "", datetime = 0) {
    int n = 0;
    for (auto it = g_simTerm.gvars.begin(); it != g_simTerm.gvars.end();) {
        if (it->first.compare(0, prefix.size(), prefix) == 0) { it = g_simTerm.gvars.erase(it); ++n; }
        else ++it;
    }
    return n;
}
inline int GlobalVariablesTotal() { return (int)g_simTerm.gvars.size(); }
inline string GlobalVariableName(int i) {
    int k = 0;
    for (auto &kv : g_simTerm.gvars) if (k++ == i) return kv.first;
    return "";
}
inline void GlobalVariablesFlush() {}

#endif
