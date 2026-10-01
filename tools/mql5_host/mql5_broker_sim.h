// mql5_broker_sim.h — broker GIẢ LẬP cho host harness (tài khoản hedging, market execution).
// Mô hình: XAUUSD-like, contract 100, tick 0.01, USD. Margin = lot*contract*giá/leverage;
// hedged margin theo SYMBOL_MARGIN_HEDGED (giống công thức ước tính của EA — dùng để test nhất quán).
// Có thể cấu hình: từ chối lệnh (retcode), chế độ xác nhận trễ (async), trượt giá, commission.
#ifndef MQL5_BROKER_SIM_H
#define MQL5_BROKER_SIM_H
#include <deque>
#include "mql5_terminal.h"

// ---------------------------------------------------------------- enums & retcodes
enum ENUM_TRADE_REQUEST_ACTIONS { TRADE_ACTION_DEAL = 1, TRADE_ACTION_PENDING = 5, TRADE_ACTION_SLTP = 6,
    TRADE_ACTION_MODIFY = 7, TRADE_ACTION_REMOVE = 8, TRADE_ACTION_CLOSE_BY = 10 };
enum ENUM_ORDER_TYPE { ORDER_TYPE_BUY, ORDER_TYPE_SELL, ORDER_TYPE_BUY_LIMIT, ORDER_TYPE_SELL_LIMIT,
    ORDER_TYPE_BUY_STOP, ORDER_TYPE_SELL_STOP };
enum ENUM_ORDER_TYPE_FILLING { ORDER_FILLING_FOK, ORDER_FILLING_IOC, ORDER_FILLING_RETURN, ORDER_FILLING_BOC };
enum ENUM_ORDER_TYPE_TIME { ORDER_TIME_GTC, ORDER_TIME_DAY, ORDER_TIME_SPECIFIED, ORDER_TIME_SPECIFIED_DAY };
enum ENUM_ORDER_STATE { ORDER_STATE_STARTED, ORDER_STATE_PLACED, ORDER_STATE_CANCELED, ORDER_STATE_PARTIAL,
    ORDER_STATE_FILLED, ORDER_STATE_REJECTED, ORDER_STATE_EXPIRED };
enum ENUM_POSITION_TYPE { POSITION_TYPE_BUY, POSITION_TYPE_SELL };
enum ENUM_POSITION_PROPERTY_INTEGER { POSITION_TICKET, POSITION_TIME, POSITION_TIME_MSC, POSITION_TYPE, POSITION_MAGIC,
    POSITION_IDENTIFIER, POSITION_REASON };
enum ENUM_POSITION_PROPERTY_DOUBLE { POSITION_VOLUME, POSITION_PRICE_OPEN, POSITION_SL, POSITION_TP, POSITION_PRICE_CURRENT,
    POSITION_SWAP, POSITION_PROFIT };
enum ENUM_POSITION_PROPERTY_STRING { POSITION_SYMBOL, POSITION_COMMENT, POSITION_EXTERNAL_ID };
enum ENUM_DEAL_TYPE { DEAL_TYPE_BUY, DEAL_TYPE_SELL, DEAL_TYPE_BALANCE, DEAL_TYPE_CREDIT, DEAL_TYPE_CHARGE, DEAL_TYPE_CORRECTION,
    DEAL_TYPE_BONUS, DEAL_TYPE_COMMISSION };
enum ENUM_DEAL_ENTRY { DEAL_ENTRY_IN, DEAL_ENTRY_OUT, DEAL_ENTRY_INOUT, DEAL_ENTRY_OUT_BY };
enum ENUM_DEAL_PROPERTY_INTEGER { DEAL_TICKET, DEAL_ORDER, DEAL_TIME, DEAL_TIME_MSC, DEAL_TYPE, DEAL_ENTRY, DEAL_MAGIC,
    DEAL_REASON, DEAL_POSITION_ID };
enum ENUM_DEAL_PROPERTY_DOUBLE { DEAL_VOLUME, DEAL_PRICE, DEAL_COMMISSION, DEAL_SWAP, DEAL_PROFIT, DEAL_FEE, DEAL_SL, DEAL_TP };
enum ENUM_DEAL_PROPERTY_STRING { DEAL_SYMBOL, DEAL_COMMENT, DEAL_EXTERNAL_ID };
enum ENUM_ORDER_PROPERTY_INTEGER { ORDER_TICKET, ORDER_TIME_SETUP, ORDER_TYPE, ORDER_STATE, ORDER_MAGIC, ORDER_POSITION_ID };
enum ENUM_TRADE_TRANSACTION_TYPE { TRADE_TRANSACTION_ORDER_ADD, TRADE_TRANSACTION_ORDER_UPDATE, TRADE_TRANSACTION_ORDER_DELETE,
    TRADE_TRANSACTION_HISTORY_ADD, TRADE_TRANSACTION_HISTORY_UPDATE, TRADE_TRANSACTION_HISTORY_DELETE,
    TRADE_TRANSACTION_DEAL_ADD, TRADE_TRANSACTION_DEAL_UPDATE, TRADE_TRANSACTION_DEAL_DELETE, TRADE_TRANSACTION_POSITION,
    TRADE_TRANSACTION_REQUEST };

#define TRADE_RETCODE_REQUOTE 10004
#define TRADE_RETCODE_REJECT 10006
#define TRADE_RETCODE_CANCEL 10007
#define TRADE_RETCODE_PLACED 10008
#define TRADE_RETCODE_DONE 10009
#define TRADE_RETCODE_DONE_PARTIAL 10010
#define TRADE_RETCODE_ERROR 10011
#define TRADE_RETCODE_TIMEOUT 10012
#define TRADE_RETCODE_INVALID 10013
#define TRADE_RETCODE_INVALID_VOLUME 10014
#define TRADE_RETCODE_INVALID_PRICE 10015
#define TRADE_RETCODE_INVALID_STOPS 10016
#define TRADE_RETCODE_TRADE_DISABLED 10017
#define TRADE_RETCODE_MARKET_CLOSED 10018
#define TRADE_RETCODE_NO_MONEY 10019
#define TRADE_RETCODE_PRICE_CHANGED 10020
#define TRADE_RETCODE_PRICE_OFF 10021
#define TRADE_RETCODE_INVALID_EXPIRATION 10022
#define TRADE_RETCODE_ORDER_CHANGED 10023
#define TRADE_RETCODE_TOO_MANY_REQUESTS 10024
#define TRADE_RETCODE_NO_CHANGES 10025
#define TRADE_RETCODE_SERVER_DISABLES_AT 10026
#define TRADE_RETCODE_CLIENT_DISABLES_AT 10027
#define TRADE_RETCODE_LOCKED 10028
#define TRADE_RETCODE_FROZEN 10029
#define TRADE_RETCODE_INVALID_FILL 10030
#define TRADE_RETCODE_CONNECTION 10031
#define TRADE_RETCODE_ONLY_REAL 10032
#define TRADE_RETCODE_LIMIT_ORDERS 10033
#define TRADE_RETCODE_LIMIT_VOLUME 10034
#define TRADE_RETCODE_INVALID_ORDER 10035
#define TRADE_RETCODE_POSITION_CLOSED 10036
#define TRADE_RETCODE_INVALID_CLOSE_VOLUME 10038
#define TRADE_RETCODE_CLOSE_ORDER_EXIST 10039
#define TRADE_RETCODE_LIMIT_POSITIONS 10040
#define TRADE_RETCODE_LONG_ONLY 10042
#define TRADE_RETCODE_SHORT_ONLY 10043
#define TRADE_RETCODE_CLOSE_ONLY 10044
#define TRADE_RETCODE_FIFO_CLOSE 10045
#define TRADE_RETCODE_HEDGE_PROHIBITED 10046

struct MqlTradeRequest {
    ENUM_TRADE_REQUEST_ACTIONS action; ulong magic; ulong order; string symbol; double volume; double price;
    double stoplimit; double sl; double tp; ulong deviation; ENUM_ORDER_TYPE type; ENUM_ORDER_TYPE_FILLING type_filling;
    ENUM_ORDER_TYPE_TIME type_time; datetime expiration; string comment; ulong position; ulong position_by;
};
struct MqlTradeResult {
    uint retcode; ulong deal; ulong order; double volume; double price; double bid; double ask; string comment;
    uint request_id; int retcode_external;
};
struct MqlTradeCheckResult {
    uint retcode; double balance; double equity; double profit; double margin; double margin_free; double margin_level;
    string comment;
};
struct MqlTradeTransaction {
    ulong deal; ulong order; string symbol; ENUM_TRADE_TRANSACTION_TYPE type; ENUM_ORDER_TYPE order_type;
    ENUM_ORDER_STATE order_state; ENUM_DEAL_TYPE deal_type; ENUM_ORDER_TYPE_TIME time_type; datetime time_expiration;
    double price; double price_trigger; double price_sl; double price_tp; double volume; ulong position; ulong position_by;
};

// ---------------------------------------------------------------- state
struct SimPos { ulong ticket; long magic; string symbol; int type; double volume, priceOpen, swap; string comment; datetime time; };
struct SimDeal { ulong ticket, order, positionId; long magic; string symbol; int type, entry; double volume, price, profit, swap, commission, fee;
    string comment; datetime time; };
struct SimOrderHist { ulong ticket; int state; long magic; ulong positionId; };
struct SimAsync { MqlTradeRequest req; ulong order; };

struct SimBrokerState {
    ulong nextTicket = 1000;
    std::vector<SimPos> positions;
    std::vector<SimDeal> deals;
    std::vector<SimOrderHist> orders;
    std::deque<uint> rejectQueue;      // retcode ép cho các lần OrderSend tiếp theo (0 = bình thường)
    bool asyncMode = false;            // OrderSend trả DONE nhưng deal đến sau (SimFlushAsync)
    std::vector<SimAsync> asyncPending;
    double slippage = 0.0;             // cộng vào giá khớp (bất lợi cho người mua)
    double commissionPerLotSide = -3.5;// commission mỗi lot mỗi chiều (âm = phí, đúng dấu MT5)
    int sendCount = 0;
    int closeSendCount = 0;
    std::vector<MqlTradeTransaction> txQueue;
    // lựa chọn lịch sử
    std::vector<size_t> histSel;       // chỉ số deal trong HistorySelect hiện tại
    int selPos = -1;                   // position đang được chọn
};
extern SimBrokerState g_sim;

inline double SimPosProfit(const SimPos &p) {
    double close = p.type == POSITION_TYPE_BUY ? g_simSym.bid : g_simSym.ask;
    double diff = p.type == POSITION_TYPE_BUY ? close - p.priceOpen : p.priceOpen - close;
    return diff * p.volume * g_simSym.contractSize;
}
inline double SimFloatingProfit() { double s = 0; for (auto &p : g_sim.positions) s += SimPosProfit(p); return s; }
inline double SimFloatingSwap() { double s = 0; for (auto &p : g_sim.positions) s += p.swap; return s; }
inline double SimMarginPerLot(double price) { return g_simSym.contractSize * price / (double)g_simAcc.leverage; }
inline double SimUsedMargin() {
    double b = 0, s = 0;
    for (auto &p : g_sim.positions) (p.type == POSITION_TYPE_BUY ? b : s) += p.volume;
    double mid = (g_simSym.bid + g_simSym.ask) / 2;
    double per = SimMarginPerLot(mid);
    if (g_simSym.hedgedUseLeg) return std::max(b, s) * per;
    double h = std::min(b, s);
    double ratio = g_simSym.marginHedged / g_simSym.contractSize;
    return (b - h) * per + (s - h) * per + 2.0 * h * per * ratio;
}
inline int SimPositionsCount() { return (int)g_sim.positions.size(); }

inline void SimSetPrice(double bid, double ask) { g_simSym.bid = bid; g_simSym.ask = ask; g_simSym.lastTickTime = g_simTerm.now; }
inline void SimSetMid(double mid, double spread = 0.20) { SimSetPrice(mid - spread / 2, mid + spread / 2); }

// ---------------------------------------------------------------- positions API
inline int PositionsTotal() { return (int)g_sim.positions.size(); }
inline ulong PositionGetTicket(int i) {
    if (i < 0 || i >= (int)g_sim.positions.size()) { g_simTerm.lastError = 4003; return 0; }
    g_sim.selPos = i;
    return g_sim.positions[(size_t)i].ticket;
}
inline bool PositionSelectByTicket(ulong t) {
    for (size_t i = 0; i < g_sim.positions.size(); ++i)
        if (g_sim.positions[i].ticket == t) { g_sim.selPos = (int)i; return true; }
    g_sim.selPos = -1;
    g_simTerm.lastError = 4753;
    return false;
}
inline const SimPos *SimSel() {
    if (g_sim.selPos < 0 || g_sim.selPos >= (int)g_sim.positions.size()) return nullptr;
    return &g_sim.positions[(size_t)g_sim.selPos];
}
inline long PositionGetInteger(ENUM_POSITION_PROPERTY_INTEGER p) {
    const SimPos *s = SimSel();
    if (!s) return 0;
    switch (p) {
        case POSITION_TICKET: case POSITION_IDENTIFIER: return (long)s->ticket;
        case POSITION_TIME: return s->time;
        case POSITION_TIME_MSC: return s->time * 1000;
        case POSITION_TYPE: return s->type;
        case POSITION_MAGIC: return s->magic;
        default: return 0;
    }
}
inline double PositionGetDouble(ENUM_POSITION_PROPERTY_DOUBLE p) {
    const SimPos *s = SimSel();
    if (!s) return 0;
    switch (p) {
        case POSITION_VOLUME: return s->volume;
        case POSITION_PRICE_OPEN: return s->priceOpen;
        case POSITION_PRICE_CURRENT: return s->type == POSITION_TYPE_BUY ? g_simSym.bid : g_simSym.ask;
        case POSITION_SWAP: return s->swap;
        case POSITION_PROFIT: return SimPosProfit(*s);
        default: return 0;
    }
}
inline string PositionGetString(ENUM_POSITION_PROPERTY_STRING p) {
    const SimPos *s = SimSel();
    if (!s) return "";
    switch (p) {
        case POSITION_SYMBOL: return s->symbol;
        case POSITION_COMMENT: return s->comment;
        default: return "";
    }
}

// ---------------------------------------------------------------- history API
inline bool HistorySelect(datetime from, datetime to) {
    g_sim.histSel.clear();
    for (size_t i = 0; i < g_sim.deals.size(); ++i)
        if (g_sim.deals[i].time >= from && g_sim.deals[i].time <= to) g_sim.histSel.push_back(i);
    return true;
}
inline bool HistorySelectByPosition(ulong posId) {
    g_sim.histSel.clear();
    for (size_t i = 0; i < g_sim.deals.size(); ++i)
        if (g_sim.deals[i].positionId == posId) g_sim.histSel.push_back(i);
    return true;
}
inline int HistoryDealsTotal() { return (int)g_sim.histSel.size(); }
inline ulong HistoryDealGetTicket(int i) {
    if (i < 0 || i >= (int)g_sim.histSel.size()) return 0;
    return g_sim.deals[g_sim.histSel[(size_t)i]].ticket;
}
inline const SimDeal *SimDealByTicket(ulong t) {
    for (auto &d : g_sim.deals) if (d.ticket == t) return &d;
    return nullptr;
}
inline bool HistoryDealSelect(ulong t) {
    if (!SimDealByTicket(t)) return false;
    // MT5: HistoryDealSelect thêm deal vào danh sách lựa chọn
    for (size_t i = 0; i < g_sim.deals.size(); ++i)
        if (g_sim.deals[i].ticket == t) {
            if (std::find(g_sim.histSel.begin(), g_sim.histSel.end(), i) == g_sim.histSel.end()) g_sim.histSel.push_back(i);
        }
    return true;
}
inline long HistoryDealGetInteger(ulong t, ENUM_DEAL_PROPERTY_INTEGER p) {
    const SimDeal *d = SimDealByTicket(t);
    if (!d) return 0;
    switch (p) {
        case DEAL_TICKET: return (long)d->ticket;
        case DEAL_ORDER: return (long)d->order;
        case DEAL_TIME: return d->time;
        case DEAL_TIME_MSC: return d->time * 1000;
        case DEAL_TYPE: return d->type;
        case DEAL_ENTRY: return d->entry;
        case DEAL_MAGIC: return d->magic;
        case DEAL_POSITION_ID: return (long)d->positionId;
        default: return 0;
    }
}
inline double HistoryDealGetDouble(ulong t, ENUM_DEAL_PROPERTY_DOUBLE p) {
    const SimDeal *d = SimDealByTicket(t);
    if (!d) return 0;
    switch (p) {
        case DEAL_VOLUME: return d->volume;
        case DEAL_PRICE: return d->price;
        case DEAL_COMMISSION: return d->commission;
        case DEAL_SWAP: return d->swap;
        case DEAL_PROFIT: return d->profit;
        case DEAL_FEE: return d->fee;
        default: return 0;
    }
}
inline string HistoryDealGetString(ulong t, ENUM_DEAL_PROPERTY_STRING p) {
    const SimDeal *d = SimDealByTicket(t);
    if (!d) return "";
    switch (p) {
        case DEAL_SYMBOL: return d->symbol;
        case DEAL_COMMENT: return d->comment;
        default: return "";
    }
}
inline bool HistoryOrderSelect(ulong t) {
    for (auto &o : g_sim.orders) if (o.ticket == t) return true;
    return false;
}
inline long HistoryOrderGetInteger(ulong t, ENUM_ORDER_PROPERTY_INTEGER p) {
    for (auto &o : g_sim.orders)
        if (o.ticket == t) {
            switch (p) {
                case ORDER_TICKET: return (long)o.ticket;
                case ORDER_STATE: return o.state;
                case ORDER_MAGIC: return o.magic;
                case ORDER_POSITION_ID: return (long)o.positionId;
                default: return 0;
            }
        }
    return 0;
}

// ---------------------------------------------------------------- margin / profit calc
inline bool OrderCalcMargin(ENUM_ORDER_TYPE, const string &sym, double vol, double price, double &margin) {
    if (!SimKnownSymbol(sym) || vol <= 0 || price <= 0) { g_simTerm.lastError = 4758; return false; }
    margin = vol * SimMarginPerLot(price);
    return true;
}
inline bool OrderCalcProfit(ENUM_ORDER_TYPE t, const string &sym, double vol, double open, double close, double &profit) {
    if (!SimKnownSymbol(sym)) return false;
    double diff = (t == ORDER_TYPE_BUY) ? close - open : open - close;
    profit = diff * vol * g_simSym.contractSize;
    return true;
}

// ---------------------------------------------------------------- execution
inline void SimPushTx(const SimDeal &d, int posType) {
    MqlTradeTransaction t = MqlTradeTransaction();
    t.type = TRADE_TRANSACTION_DEAL_ADD;
    t.deal = d.ticket;
    t.order = d.order;
    t.symbol = d.symbol;
    t.deal_type = (ENUM_DEAL_TYPE)d.type;
    t.price = d.price;
    t.volume = d.volume;
    t.position = d.positionId;
    (void)posType;
    g_sim.txQueue.push_back(t);
}

// Thực hiện một yêu cầu market đã được chấp nhận. Trả về ticket deal.
inline ulong SimExecute(const MqlTradeRequest &r, ulong order, double &fillPrice) {
    bool isBuy = r.type == ORDER_TYPE_BUY;
    fillPrice = (isBuy ? g_simSym.ask + g_sim.slippage : g_simSym.bid - g_sim.slippage);
    SimDeal d{};
    d.ticket = g_sim.nextTicket++;
    d.order = order;
    d.magic = (long)r.magic;
    d.symbol = r.symbol;
    d.type = isBuy ? DEAL_TYPE_BUY : DEAL_TYPE_SELL;
    d.volume = r.volume;
    d.price = fillPrice;
    d.comment = r.comment;
    d.time = g_simTerm.now;
    d.commission = g_sim.commissionPerLotSide * r.volume;
    if (r.position == 0) {
        SimPos p{};
        p.ticket = order;  // MT5 hedging: position ticket = order ticket mở
        p.magic = (long)r.magic;
        p.symbol = r.symbol;
        p.type = isBuy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
        p.volume = r.volume;
        p.priceOpen = fillPrice;
        p.comment = r.comment;
        p.time = g_simTerm.now;
        g_sim.positions.push_back(p);
        d.entry = DEAL_ENTRY_IN;
        d.positionId = order;
    } else {
        for (size_t i = 0; i < g_sim.positions.size(); ++i) {
            SimPos &p = g_sim.positions[i];
            if (p.ticket != r.position) continue;
            double diff = p.type == POSITION_TYPE_BUY ? fillPrice - p.priceOpen : p.priceOpen - fillPrice;
            d.profit = diff * p.volume * g_simSym.contractSize;
            d.swap = p.swap;
            d.entry = DEAL_ENTRY_OUT;
            d.positionId = p.ticket;
            d.magic = p.magic;
            g_sim.positions.erase(g_sim.positions.begin() + (long)i);
            break;
        }
    }
    g_simAcc.balance += d.profit + d.swap + d.commission + d.fee;
    g_sim.deals.push_back(d);
    g_sim.orders.push_back({order, ORDER_STATE_FILLED, (long)r.magic, d.positionId});
    SimPushTx(d, 0);
    return d.ticket;
}

inline bool OrderCheck(const MqlTradeRequest &r, MqlTradeCheckResult &res) {
    res = MqlTradeCheckResult();
    if (r.action != TRADE_ACTION_DEAL || !SimKnownSymbol(r.symbol) || r.volume <= 0) { res.retcode = TRADE_RETCODE_INVALID; return false; }
    if (r.position == 0) {
        double m = 0;
        OrderCalcMargin(r.type, r.symbol, r.volume, r.price, m);
        double fm = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
        res.margin = m;
        res.margin_free = fm - m;
        if (m > fm) { res.retcode = TRADE_RETCODE_NO_MONEY; return false; }
    }
    res.retcode = 0;
    return true;
}

inline bool OrderSend(const MqlTradeRequest &r, MqlTradeResult &res) {
    res = MqlTradeResult();
    g_sim.sendCount++;
    if (r.position != 0) g_sim.closeSendCount++;
    res.bid = g_simSym.bid;
    res.ask = g_simSym.ask;
    if (!g_sim.rejectQueue.empty()) {
        uint rc = g_sim.rejectQueue.front();
        g_sim.rejectQueue.pop_front();
        if (rc != 0) {
            res.retcode = rc;
            ulong ord = g_sim.nextTicket++;
            g_sim.orders.push_back({ord, ORDER_STATE_REJECTED, (long)r.magic, 0});
            return false;
        }
    }
    // kiểm tra cơ bản
    if (r.action != TRADE_ACTION_DEAL || !SimKnownSymbol(r.symbol)) { res.retcode = TRADE_RETCODE_INVALID; return false; }
    double steps = r.volume / g_simSym.volStep;
    if (r.volume < g_simSym.volMin - 1e-9 || r.volume > g_simSym.volMax + 1e-9 || std::fabs(steps - std::round(steps)) > 1e-6) {
        res.retcode = TRADE_RETCODE_INVALID_VOLUME;
        return false;
    }
    if (!g_simAcc.tradeAllowed || !g_simTerm.terminalTradeAllowed) { res.retcode = TRADE_RETCODE_CLIENT_DISABLES_AT; return false; }
    if (r.position != 0) {
        bool found = false;
        for (auto &p : g_sim.positions) if (p.ticket == r.position) { found = true; if (std::fabs(p.volume - r.volume) > 1e-9) { res.retcode = TRADE_RETCODE_INVALID_CLOSE_VOLUME; return false; } }
        if (!found) { res.retcode = TRADE_RETCODE_POSITION_CLOSED; return false; }
    } else {
        MqlTradeCheckResult cr;
        if (!OrderCheck(r, cr)) { res.retcode = cr.retcode; return false; }
    }
    double market = r.type == ORDER_TYPE_BUY ? g_simSym.ask : g_simSym.bid;
    if (std::fabs(market - r.price) > (double)r.deviation * g_simSym.point + 1e-9) { res.retcode = TRADE_RETCODE_REQUOTE; return false; }
    ulong order = g_sim.nextTicket++;
    res.order = order;
    res.retcode = TRADE_RETCODE_DONE;
    res.volume = r.volume;
    if (g_sim.asyncMode) {
        g_sim.asyncPending.push_back({r, order});
        res.deal = 0;
        return true;
    }
    double px = 0;
    res.deal = SimExecute(r, order, px);
    res.price = px;
    return true;
}

// Thực hiện các lệnh async đang chờ (mô phỏng xác nhận broker đến muộn)
inline void SimFlushAsync() {
    auto pend = g_sim.asyncPending;
    g_sim.asyncPending.clear();
    for (auto &a : pend) { double px; SimExecute(a.req, a.order, px); }
}
// Huỷ các lệnh async đang chờ (broker từ chối sau khi đã nhận)
inline void SimRejectAsync() {
    for (auto &a : g_sim.asyncPending) g_sim.orders.push_back({a.order, ORDER_STATE_REJECTED, (long)a.req.magic, 0});
    g_sim.asyncPending.clear();
}

// Đóng position từ bên ngoài EA (stop-out / người dùng)
inline void SimExternalClose(ulong ticket) {
    for (auto &p : g_sim.positions)
        if (p.ticket == ticket) {
            MqlTradeRequest r = MqlTradeRequest();
            r.action = TRADE_ACTION_DEAL; r.symbol = p.symbol; r.volume = p.volume; r.position = ticket;
            r.type = p.type == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY; r.magic = (ulong)p.magic;
            r.comment = "external";
            double px;
            SimExecute(r, g_sim.nextTicket++, px);
            return;
        }
}

// Mở position "lệnh tay" / EA khác (để test EA không đụng vào)
inline ulong SimOpenForeign(int type, double vol, long magic, const string &comment, const string &symbol = "") {
    MqlTradeRequest r = MqlTradeRequest();
    r.action = TRADE_ACTION_DEAL; r.symbol = symbol.empty() ? g_simSym.name : symbol; r.volume = vol;
    r.type = type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL; r.magic = (ulong)magic; r.comment = comment;
    ulong order = g_sim.nextTicket++;
    double px;
    SimExecute(r, order, px);
    g_sim.txQueue.clear();
    return order;
}

inline void SimReset() {
    g_sim = SimBrokerState();
    g_simSym = SimSymbolState();
    g_simAcc = SimAccountState();
    g_simTerm.lastError = 0;
}

#endif
