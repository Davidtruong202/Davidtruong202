// mt5sim: bo gia lap MT5 toi thieu de chay ma EA (da dich sang C++) tren tick that hoac tick sinh tu nen M1.
// Mo phong: tai khoan hedging USD, khop lenh thi truong tai Bid/Ask (+ truot gia bat loi tuy chon), SL/TP theo tick
// (khop tai gia tick, gom ca gap), ky quy CFD theo don bay, lich su deal, nen M1..D1 dung tu tick, file, GlobalVariable.
// Kiem toan doc lap voi EA: rui ro du kien moi lenh, lo ngay, vi the thieu SL/TP, giu lenh qua gio dong cuoi ngay/cuoi tuan.
#include "mql5.h"

#include <algorithm>
#include <cerrno>
#include <csignal>
#include <fenv.h>
#include <fstream>
#include <iostream>
#include <map>
#include <random>
#include <sstream>
#include <sys/stat.h>

string _Symbol = "XAUUSDm";
double _Point = 0.001;
int _Digits = 3;

namespace sim
{
struct Cfg
{
   std::string mode = "real";
   std::string tickFile, m1File, outDir = "sim_out/run";
   long start = 0, end = 0;
   double deposit = 10000, leverage = 200, commissionSide = 0, slipMax = 0, spreadMult = 1.0, spreadAdd = 0.0, stopOut = 20;
   long stopsLevel = 0, freezeLevel = 0;
   int tester = 1, tradeMode = 0, marginMode = 2;
   double contract = 100, volMin = 0.01, volMax = 200, volStep = 0.01, point = 0.001, tickSize = 0.001;
   int digits = 3;
   std::vector<long> restartAt;
   std::vector<std::pair<long, double>> cashAt;   // nap (+) / rut (-) tien giua chung
   unsigned seed = 12345;
   int maxTicksPerBar = 300;
   int eodMinute = 20 * 60 + 40;
   bool quiet = false;
};
Cfg C;

struct Pos
{
   ulong ticket; long ident; int type; double vol, open, sl, tp; long time, time_msc; long magic; std::string comment;
   double sl0, tp0, riskPlan, riskPct, base; bool flaggedEod;
};
struct Deal
{
   ulong ticket, order; long pos; long time, time_msc; int type, entry; double vol, price, profit, commission, swap, fee;
   long magic; int reason; std::string symbol, comment;
};
struct Series { ENUM_TIMEFRAMES tf; long sec; std::vector<MqlRates> b; };
struct TickRec { long t_ms; double bid, ask; };
struct FH { FILE *f; std::string path; };

MqlTick cur;
bool haveTick = false;
double balance = 0;
std::vector<Pos> pos;
std::vector<Deal> deals;
std::map<ulong, size_t> dealIdx;
ulong nextTicket = 100001, nextDeal = 500001;
ulong selTicket = 0;
std::vector<size_t> hsel;
std::map<std::string, double> gv;
std::vector<Series> ser;
std::vector<FH> files;
int lastErr = 0;
bool timerOn = false, removed = false;
std::mt19937 rng;
std::ofstream journal;
long nPrint = 0;

// Kiem toan
struct DayAudit { long key; double startBal; double minEq; int trades; double pl; };
std::vector<DayAudit> days;
double maxRiskPct = 0, peakEq = 0, maxDD = 0, maxDDPct = 0;
long noStopTicks = 0, eodViolations = 0, weekendViolations = 0, maxOpen = 0, tickCount = 0;
std::map<long, Pos> closedInfo;   // ident -> thong tin luc mo (de tinh R)

const char *TFNAME(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1: return "M1"; case PERIOD_M5: return "M5"; case PERIOD_M15: return "M15"; case PERIOD_M30: return "M30";
      case PERIOD_H1: return "H1"; case PERIOD_H4: return "H4"; case PERIOD_D1: return "D1"; default: return "?";
   }
}
long tfSec(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1: return 60; case PERIOD_M2: return 120; case PERIOD_M3: return 180; case PERIOD_M4: return 240; case PERIOD_M5: return 300;
      case PERIOD_M6: return 360; case PERIOD_M10: return 600; case PERIOD_M12: return 720; case PERIOD_M15: return 900; case PERIOD_M20: return 1200;
      case PERIOD_M30: return 1800; case PERIOD_H1: return 3600; case PERIOD_H2: return 7200; case PERIOD_H4: return 14400; case PERIOD_D1: return 86400;
      default: return 60;
   }
}
std::string ts(long t)
{
   return TimeToString((datetime)t, TIME_DATE | TIME_SECONDS);
}
void mkdirs(const std::string &p)
{
   std::string acc;
   for(size_t i = 0; i < p.size(); i++)
   {
      acc += p[i];
      if(p[i] == '/') mkdir(acc.c_str(), 0755);
   }
   mkdir(p.c_str(), 0755);
}
double equity();

void addTick(long t, double bid, int sprPts)
{
   for(auto &s : ser)
   {
      long bt = t - (t % s.sec);
      if(s.b.empty() || s.b.back().time != bt)
      {
         if(!s.b.empty() && bt < s.b.back().time) continue;
         MqlRates r;
         r.time = bt; r.open = r.high = r.low = r.close = bid; r.tick_volume = 1; r.spread = sprPts; r.real_volume = 0;
         s.b.push_back(r);
      }
      else
      {
         MqlRates &r = s.b.back();
         if(bid > r.high) r.high = bid;
         if(bid < r.low) r.low = bid;
         r.close = bid; r.tick_volume++; r.spread = sprPts;
      }
   }
}
void addBar(const MqlRates &m1)
{
   for(auto &s : ser)
   {
      long bt = m1.time - (m1.time % s.sec);
      if(s.b.empty() || s.b.back().time != bt)
      {
         MqlRates r = m1;
         r.time = bt;
         s.b.push_back(r);
      }
      else
      {
         MqlRates &r = s.b.back();
         r.high = std::max(r.high, m1.high); r.low = std::min(r.low, m1.low); r.close = m1.close; r.tick_volume += m1.tick_volume; r.spread = m1.spread;
      }
   }
}
Series *findSeries(ENUM_TIMEFRAMES tf)
{
   for(auto &s : ser) if(s.tf == tf) return &s;
   return nullptr;
}

double posProfit(const Pos &p, double bid, double ask)
{
   return (p.type == 0 ? bid - p.open : p.open - ask) * p.vol * C.contract;
}
double floating()
{
   double f = 0;
   for(auto &p : pos) f += posProfit(p, cur.bid, cur.ask);
   return f;
}
double equity() { return balance + floating(); }
double usedMargin()
{
   double m = 0;
   for(auto &p : pos) m += p.vol * C.contract * p.open / C.leverage;
   return m;
}
Deal &addDeal(ulong order, long posId, int type, int entry, double vol, double price, double profit, double comm, long magic, int reason,
              const std::string &cmt)
{
   Deal d;
   d.ticket = nextDeal++; d.order = order; d.pos = posId; d.time = cur.time; d.time_msc = cur.time_msc; d.type = type; d.entry = entry; d.vol = vol;
   d.price = price; d.profit = profit; d.commission = comm; d.swap = 0; d.fee = 0; d.magic = magic; d.reason = reason; d.symbol = _Symbol;
   d.comment = cmt;
   deals.push_back(d);
   dealIdx[d.ticket] = deals.size() - 1;
   return deals.back();
}
void closePos(size_t i, double price, int reason, const std::string &cmt, ulong order)
{
   Pos p = pos[i];
   double profit = (p.type == 0 ? price - p.open : p.open - price) * p.vol * C.contract;
   double comm = -C.commissionSide * p.vol;
   balance += profit + comm;
   addDeal(order ? order : nextTicket++, p.ident, p.type == 0 ? DEAL_TYPE_SELL : DEAL_TYPE_BUY, DEAL_ENTRY_OUT, p.vol, price, profit, comm, p.magic,
           reason, cmt);
   closedInfo[p.ident] = p;
   pos.erase(pos.begin() + (long)i);
}
void checkStops()
{
   for(size_t i = 0; i < pos.size();)
   {
      Pos &p = pos[i];
      bool hit = false; double px = 0; int rs = 0;
      if(p.type == 0)
      {
         if(p.sl > 0 && cur.bid <= p.sl) { hit = true; px = cur.bid; rs = DEAL_REASON_SL; }
         else if(p.tp > 0 && cur.bid >= p.tp) { hit = true; px = cur.bid; rs = DEAL_REASON_TP; }
      }
      else
      {
         if(p.sl > 0 && cur.ask >= p.sl) { hit = true; px = cur.ask; rs = DEAL_REASON_SL; }
         else if(p.tp > 0 && cur.ask <= p.tp) { hit = true; px = cur.ask; rs = DEAL_REASON_TP; }
      }
      if(hit) { closePos(i, px, rs, rs == DEAL_REASON_SL ? "[sl]" : "[tp]", 0); continue; }
      i++;
   }
   double m = usedMargin();
   while(!pos.empty() && m > 0 && equity() / m * 100.0 <= C.stopOut)
   {
      size_t worst = 0;
      for(size_t i = 1; i < pos.size(); i++)
         if(posProfit(pos[i], cur.bid, cur.ask) < posProfit(pos[worst], cur.bid, cur.ask)) worst = i;
      closePos(worst, pos[worst].type == 0 ? cur.bid : cur.ask, DEAL_REASON_SO, "[so]", 0);
      m = usedMargin();
   }
}
Pos *selPos()
{
   for(auto &p : pos) if(p.ticket == selTicket) return &p;
   return nullptr;
}
bool stopsOK(int type, double sl, double tp)
{
   double lv = (double)(C.stopsLevel) * C.point;
   if(type == 0)
   {
      if(sl > 0 && sl > cur.bid - lv) return false;
      if(tp > 0 && tp < cur.bid + lv) return false;
   }
   else
   {
      if(sl > 0 && sl < cur.ask + lv) return false;
      if(tp > 0 && tp > cur.ask - lv) return false;
   }
   return true;
}
double uni(double a, double b)
{
   std::uniform_real_distribution<double> d(a, b);
   return d(rng);
}
double roundPt(double v) { return std::round(v / C.point) * C.point; }
}  // namespace sim

using namespace sim;

// ---------------------------------------------------------------- API MQL5
void mql_fatal(const std::string &msg)
{
   fprintf(stderr, "\n*** LOI RUNTIME MQL5 (gia lap) tai %s: %s\n", ts(cur.time).c_str(), msg.c_str());
   if(journal.is_open()) journal << "LOI RUNTIME: " << msg << std::endl;
   std::exit(3);
}
void __unknown_input(const std::string &k) { fprintf(stderr, "CANH BAO: input khong ton tai trong EA: %s\n", k.c_str()); }
void __emit_print(const string &s)
{
   nPrint++;
   if(journal.is_open()) journal << ts(cur.time) << "  " << s << "\n";
   if(!C.quiet && nPrint <= 400) printf("[%s] %s\n", ts(cur.time).c_str(), s.c_str());
}
int PeriodSeconds(ENUM_TIMEFRAMES p) { return (int)tfSec(p == PERIOD_CURRENT ? PERIOD_M1 : p); }
datetime TimeCurrent() { return cur.time; }
ulong GetTickCount64() { return (ulong)cur.time_msc; }
int GetLastError() { return lastErr; }
void ResetLastError() { lastErr = 0; }
int MQLInfoInteger(ENUM_MQL_INFO_INTEGER p)
{
   if(p == MQL_TESTER) return C.tester;
   if(p == MQL_TRADE_ALLOWED) return 1;
   return 0;
}
int TerminalInfoInteger(ENUM_TERMINAL_INFO_INTEGER) { return 1; }
double AccountInfoDouble(ENUM_ACCOUNT_INFO_DOUBLE p)
{
   double eq = equity(), m = usedMargin();
   switch(p)
   {
      case ACCOUNT_BALANCE: return balance;
      case ACCOUNT_EQUITY: return eq;
      case ACCOUNT_MARGIN: return m;
      case ACCOUNT_MARGIN_FREE: return eq - m;
      case ACCOUNT_MARGIN_LEVEL: return m > 0 ? eq / m * 100.0 : 0.0;
      case ACCOUNT_PROFIT: return eq - balance;
   }
   return 0;
}
long AccountInfoInteger(ENUM_ACCOUNT_INFO_INTEGER p)
{
   switch(p)
   {
      case ACCOUNT_LOGIN: return 7654321;
      case ACCOUNT_TRADE_MODE: return C.tradeMode;
      case ACCOUNT_LEVERAGE: return (long)C.leverage;
      case ACCOUNT_MARGIN_MODE: return C.marginMode;
      default: return 1;
   }
}
string AccountInfoString(ENUM_ACCOUNT_INFO_STRING p) { return p == ACCOUNT_CURRENCY ? "USD" : "mt5sim"; }
bool SymbolInfoTick(const string &, MqlTick &t)
{
   if(!haveTick) return false;
   t = cur;
   return true;
}
double SymbolInfoDouble(const string &, ENUM_SYMBOL_INFO_DOUBLE p)
{
   switch(p)
   {
      case SYMBOL_BID: return cur.bid;
      case SYMBOL_ASK: return cur.ask;
      case SYMBOL_POINT: return C.point;
      case SYMBOL_TRADE_TICK_SIZE: return C.tickSize;
      case SYMBOL_TRADE_TICK_VALUE: return C.tickSize * C.contract;
      case SYMBOL_VOLUME_MIN: return C.volMin;
      case SYMBOL_VOLUME_MAX: return C.volMax;
      case SYMBOL_VOLUME_STEP: return C.volStep;
      case SYMBOL_TRADE_CONTRACT_SIZE: return C.contract;
   }
   return 0;
}
long SymbolInfoInteger(const string &, ENUM_SYMBOL_INFO_INTEGER p)
{
   switch(p)
   {
      case SYMBOL_DIGITS: return C.digits;
      case SYMBOL_SPREAD: return (long)std::lround((cur.ask - cur.bid) / C.point);
      case SYMBOL_TRADE_STOPS_LEVEL: return C.stopsLevel;
      case SYMBOL_TRADE_FREEZE_LEVEL: return C.freezeLevel;
      case SYMBOL_FILLING_MODE: return SYMBOL_FILLING_FOK | SYMBOL_FILLING_IOC;
      case SYMBOL_TRADE_CALC_MODE: return SYMBOL_CALC_MODE_CFDLEVERAGE;
      case SYMBOL_TRADE_MODE: return 4;
      case SYMBOL_TRADE_EXEMODE: return 2;
   }
   return 0;
}
bool OrderCalcProfit(ENUM_ORDER_TYPE t, const string &, double vol, double open, double close, double &profit)
{
   profit = (t == ORDER_TYPE_BUY ? close - open : open - close) * vol * C.contract;
   return true;
}
bool OrderCalcMargin(ENUM_ORDER_TYPE, const string &, double vol, double price, double &margin)
{
   margin = vol * C.contract * price / C.leverage;
   return true;
}
bool OrderSend(MqlTradeRequest &rq, MqlTradeResult &rs)
{
   rs = MqlTradeResult();
   rs.bid = cur.bid; rs.ask = cur.ask;
   if(rq.action == TRADE_ACTION_SLTP)
   {
      Pos *p = nullptr;
      for(auto &x : pos) if(x.ticket == rq.position) p = &x;
      if(!p) { rs.retcode = TRADE_RETCODE_POSITION_CLOSED; return false; }
      if(std::fabs(p->sl - rq.sl) < 1e-9 && std::fabs(p->tp - rq.tp) < 1e-9) { rs.retcode = TRADE_RETCODE_NO_CHANGES; return false; }
      double fz = (double)C.freezeLevel * C.point;
      if(!stopsOK(p->type, rq.sl, rq.tp)) { rs.retcode = TRADE_RETCODE_INVALID_STOPS; return false; }
      if(fz > 0 && p->sl > 0 && std::fabs((p->type == 0 ? cur.bid : cur.ask) - p->sl) <= fz) { rs.retcode = TRADE_RETCODE_INVALID_STOPS; return false; }
      p->sl = rq.sl; p->tp = rq.tp;
      rs.retcode = TRADE_RETCODE_DONE;
      return true;
   }
   if(rq.action != TRADE_ACTION_DEAL) { rs.retcode = TRADE_RETCODE_INVALID; return false; }
   if(rq.symbol != _Symbol) { rs.retcode = TRADE_RETCODE_INVALID; return false; }
   double slip = C.slipMax > 0 ? roundPt(uni(0, C.slipMax)) : 0.0;
   if(rq.position > 0)
   {
      for(size_t i = 0; i < pos.size(); i++)
         if(pos[i].ticket == rq.position)
         {
            if(std::fabs(rq.volume - pos[i].vol) > 1e-9) { rs.retcode = TRADE_RETCODE_INVALID_VOLUME; return false; }
            double px = pos[i].type == 0 ? cur.bid - slip : cur.ask + slip;
            ulong ord = nextTicket++;
            closePos(i, px, DEAL_REASON_EXPERT, rq.comment, ord);
            rs.retcode = TRADE_RETCODE_DONE; rs.order = ord; rs.deal = nextDeal - 1; rs.price = px; rs.volume = rq.volume;
            return true;
         }
      rs.retcode = TRADE_RETCODE_POSITION_CLOSED;
      return false;
   }
   double v = rq.volume;
   double steps = v / C.volStep;
   if(v < C.volMin - 1e-9 || v > C.volMax + 1e-9 || std::fabs(steps - std::round(steps)) > 1e-6) { rs.retcode = TRADE_RETCODE_INVALID_VOLUME; return false; }
   int type = rq.type == ORDER_TYPE_BUY ? 0 : 1;
   if(!stopsOK(type, rq.sl, rq.tp)) { rs.retcode = TRADE_RETCODE_INVALID_STOPS; return false; }
   double px = type == 0 ? cur.ask + slip : cur.bid - slip;
   double need = v * C.contract * px / C.leverage;
   double eqBefore = equity();
   if(eqBefore - usedMargin() < need) { rs.retcode = TRADE_RETCODE_NO_MONEY; return false; }
   double base = std::min(balance, eqBefore);
   Pos p;
   p.ticket = nextTicket++; p.ident = (long)p.ticket; p.type = type; p.vol = v; p.open = px; p.sl = rq.sl; p.tp = rq.tp; p.time = cur.time;
   p.time_msc = cur.time_msc; p.magic = (long)rq.magic; p.comment = rq.comment; p.sl0 = rq.sl; p.tp0 = rq.tp; p.flaggedEod = false;
   p.riskPlan = rq.sl > 0 ? std::fabs(px - rq.sl) * v * C.contract + 2 * C.commissionSide * v : 0.0;
   p.base = base;
   p.riskPct = base > 0 ? p.riskPlan / base * 100.0 : 0.0;
   if(p.riskPct > maxRiskPct) maxRiskPct = p.riskPct;
   double comm = -C.commissionSide * v;
   balance += comm;
   pos.push_back(p);
   addDeal(p.ticket, p.ident, type == 0 ? DEAL_TYPE_BUY : DEAL_TYPE_SELL, DEAL_ENTRY_IN, v, px, 0.0, comm, p.magic, DEAL_REASON_EXPERT, rq.comment);
   if(!days.empty()) days.back().trades++;
   rs.retcode = TRADE_RETCODE_DONE; rs.order = p.ticket; rs.deal = nextDeal - 1; rs.price = px; rs.volume = v;
   return true;
}
int PositionsTotal() { return (int)pos.size(); }
ulong PositionGetTicket(int i)
{
   if(i < 0 || i >= (int)pos.size()) { selTicket = 0; return 0; }
   selTicket = pos[(size_t)i].ticket;
   return selTicket;
}
bool PositionSelectByTicket(ulong t)
{
   for(auto &p : pos)
      if(p.ticket == t) { selTicket = t; return true; }
   return false;
}
long PositionGetInteger(ENUM_POSITION_PROPERTY_INTEGER pr)
{
   Pos *p = selPos();
   if(!p) return 0;
   switch(pr)
   {
      case POSITION_TICKET: return (long)p->ticket;
      case POSITION_TIME: return p->time;
      case POSITION_TIME_MSC: return p->time_msc;
      case POSITION_TYPE: return p->type;
      case POSITION_MAGIC: return p->magic;
      case POSITION_IDENTIFIER: return p->ident;
   }
   return 0;
}
double PositionGetDouble(ENUM_POSITION_PROPERTY_DOUBLE pr)
{
   Pos *p = selPos();
   if(!p) return 0;
   switch(pr)
   {
      case POSITION_VOLUME: return p->vol;
      case POSITION_PRICE_OPEN: return p->open;
      case POSITION_SL: return p->sl;
      case POSITION_TP: return p->tp;
      case POSITION_PRICE_CURRENT: return p->type == 0 ? cur.bid : cur.ask;
      case POSITION_SWAP: return 0;
      case POSITION_PROFIT: return posProfit(*p, cur.bid, cur.ask);
   }
   return 0;
}
string PositionGetString(ENUM_POSITION_PROPERTY_STRING pr)
{
   Pos *p = selPos();
   if(!p) return "";
   return pr == POSITION_SYMBOL ? _Symbol : p->comment;
}
bool HistorySelect(datetime from, datetime to)
{
   hsel.clear();
   for(size_t i = 0; i < deals.size(); i++)
      if(deals[i].time >= from && deals[i].time <= to) hsel.push_back(i);
   return true;
}
bool HistorySelectByPosition(long id)
{
   hsel.clear();
   for(size_t i = 0; i < deals.size(); i++)
      if(deals[i].pos == id) hsel.push_back(i);
   return true;
}
bool HistoryDealSelect(ulong t) { return dealIdx.count(t) > 0; }
int HistoryDealsTotal() { return (int)hsel.size(); }
ulong HistoryDealGetTicket(int i)
{
   if(i < 0 || i >= (int)hsel.size()) return 0;
   return deals[hsel[(size_t)i]].ticket;
}
static Deal *dealByTicket(ulong t)
{
   auto it = dealIdx.find(t);
   return it == dealIdx.end() ? nullptr : &deals[it->second];
}
long HistoryDealGetInteger(ulong t, ENUM_DEAL_PROPERTY_INTEGER p)
{
   Deal *d = dealByTicket(t);
   if(!d) return 0;
   switch(p)
   {
      case DEAL_TICKET: return (long)d->ticket;
      case DEAL_ORDER: return (long)d->order;
      case DEAL_TIME: return d->time;
      case DEAL_TIME_MSC: return d->time_msc;
      case DEAL_TYPE: return d->type;
      case DEAL_ENTRY: return d->entry;
      case DEAL_MAGIC: return d->magic;
      case DEAL_REASON: return d->reason;
      case DEAL_POSITION_ID: return d->pos;
   }
   return 0;
}
double HistoryDealGetDouble(ulong t, ENUM_DEAL_PROPERTY_DOUBLE p)
{
   Deal *d = dealByTicket(t);
   if(!d) return 0;
   switch(p)
   {
      case DEAL_VOLUME: return d->vol;
      case DEAL_PRICE: return d->price;
      case DEAL_COMMISSION: return d->commission;
      case DEAL_SWAP: return d->swap;
      case DEAL_PROFIT: return d->profit;
      case DEAL_FEE: return d->fee;
   }
   return 0;
}
string HistoryDealGetString(ulong t, ENUM_DEAL_PROPERTY_STRING p)
{
   Deal *d = dealByTicket(t);
   if(!d) return "";
   return p == DEAL_SYMBOL ? d->symbol : d->comment;
}
int CopyRates(const string &, ENUM_TIMEFRAMES tf, int start, int count, DynArr<MqlRates> &r)
{
   r.v.clear();
   Series *s = findSeries(tf);
   if(!s || count <= 0 || start < 0) return -1;
   long n = (long)s->b.size();
   long last = n - 1 - start;
   if(last < 0) return -1;
   long first = std::max(0L, last - count + 1);
   r.v.assign(s->b.begin() + first, s->b.begin() + last + 1);
   return (int)r.v.size();
}
int CopyRates(const string &, ENUM_TIMEFRAMES tf, datetime from, datetime to, DynArr<MqlRates> &r)
{
   r.v.clear();
   Series *s = findSeries(tf);
   if(!s) return -1;
   auto lo = std::lower_bound(s->b.begin(), s->b.end(), from, [](const MqlRates &a, long t) { return a.time < t; });
   for(auto it = lo; it != s->b.end() && it->time <= to; ++it) r.v.push_back(*it);
   return r.v.empty() ? -1 : (int)r.v.size();
}
datetime GlobalVariableSet(const string &n, double v)
{
   gv[n] = v;
   return cur.time;
}
double GlobalVariableGet(const string &n)
{
   auto it = gv.find(n);
   return it == gv.end() ? 0.0 : it->second;
}
bool GlobalVariableCheck(const string &n) { return gv.count(n) > 0; }
bool GlobalVariableDel(const string &n) { return gv.erase(n) > 0; }
void GlobalVariablesFlush() {}
static std::string mapPath(const string &name, int flags)
{
   std::string p = name;
   std::replace(p.begin(), p.end(), '\\', '/');
   std::string base = C.outDir + ((flags & FILE_COMMON) ? "/Common/Files/" : "/Files/");
   std::string full = base + p;
   size_t sl = full.rfind('/');
   if(sl != std::string::npos) mkdirs(full.substr(0, sl));
   return full;
}
int FileOpen(const string &name, int flags, int, uint)
{
   std::string path = mapPath(name, flags);
   bool r = flags & FILE_READ, w = flags & FILE_WRITE;
   struct stat st;
   bool exists = stat(path.c_str(), &st) == 0;
   const char *mode = r && w ? (exists ? "r+b" : "w+b") : (w ? "wb" : "rb");
   FILE *f = fopen(path.c_str(), mode);
   if(!f) { lastErr = 5004; return INVALID_HANDLE; }
   files.push_back({f, path});
   return (int)files.size() - 1;
}
static FILE *fh(int h)
{
   if(h < 0 || h >= (int)files.size() || !files[(size_t)h].f) mql_fatal("file handle khong hop le " + std::to_string(h));
   return files[(size_t)h].f;
}
void FileClose(int h)
{
   FILE *f = fh(h);
   fclose(f);
   files[(size_t)h].f = nullptr;
}
void FileFlush(int h) { fflush(fh(h)); }
ulong FileSize(int h)
{
   FILE *f = fh(h);
   long c = ftell(f);
   fseek(f, 0, SEEK_END);
   long s = ftell(f);
   fseek(f, c, SEEK_SET);
   return (ulong)s;
}
bool FileSeek(int h, long off, int origin) { return fseek(fh(h), off, origin) == 0; }
uint FileWriteString(int h, const string &s, int)
{
   return (uint)fwrite(s.data(), 1, s.size(), fh(h));
}
string FileReadString(int h, int)
{
   FILE *f = fh(h);
   std::string s;
   int c;
   while((c = fgetc(f)) != EOF)
   {
      if(c == '\n') break;
      if(c != '\r') s += (char)c;
   }
   return s;
}
bool FileIsEnding(int h)
{
   FILE *f = fh(h);
   int c = fgetc(f);
   if(c == EOF) return true;
   ungetc(c, f);
   return false;
}
bool FileIsExist(const string &name, int common)
{
   struct stat st;
   return stat(mapPath(name, common ? FILE_COMMON : 0).c_str(), &st) == 0;
}
bool FolderCreate(const string &name, int common)
{
   mkdirs(mapPath(name + "/x", common ? FILE_COMMON : 0).substr(0, mapPath(name + "/x", common ? FILE_COMMON : 0).size() - 2));
   return true;
}
void Comment(const string &) {}
bool EventSetTimer(int) { timerOn = true; return true; }
void EventKillTimer() { timerOn = false; }
void ExpertRemove() { removed = true; }

// ---------------------------------------------------------------- nap du lieu
static std::vector<MqlRates> loadM1(const std::string &file)
{
   std::vector<MqlRates> v;
   std::ifstream in(file);
   if(!in) { fprintf(stderr, "Khong mo duoc %s\n", file.c_str()); std::exit(2); }
   std::string line;
   std::getline(in, line);
   while(std::getline(in, line))
   {
      if(line.size() < 20) continue;
      struct tm g;
      memset(&g, 0, sizeof(g));
      int Y, M, D, h, m, s;
      if(sscanf(line.c_str(), "%d.%d.%d %d:%d:%d", &Y, &M, &D, &h, &m, &s) != 6) continue;
      g.tm_year = Y - 1900; g.tm_mon = M - 1; g.tm_mday = D; g.tm_hour = h; g.tm_min = m; g.tm_sec = s;
      MqlRates r;
      r.time = (long)timegm(&g);
      double o, hi, lo, c; long tv; int sp;
      const char *p = strchr(line.c_str(), ';');
      if(!p || sscanf(p + 1, "%lf;%lf;%lf;%lf;%ld;%d", &o, &hi, &lo, &c, &tv, &sp) != 6) continue;
      r.open = o; r.high = hi; r.low = lo; r.close = c; r.tick_volume = tv; r.spread = sp; r.real_volume = 0;
      v.push_back(r);
   }
   return v;
}
static long parseTime(const std::string &s)
{
   int Y, M, D, h = 0, m = 0, sec = 0;
   if(sscanf(s.c_str(), "%d.%d.%d %d:%d:%d", &Y, &M, &D, &h, &m, &sec) < 3) { fprintf(stderr, "Sai dinh dang thoi gian: %s\n", s.c_str()); std::exit(2); }
   struct tm g;
   memset(&g, 0, sizeof(g));
   g.tm_year = Y - 1900; g.tm_mon = M - 1; g.tm_mday = D; g.tm_hour = h; g.tm_min = m; g.tm_sec = sec;
   return (long)timegm(&g);
}

// Sinh tick trong mot nen M1: mo -> dinh/day -> day/dinh -> dong, cau Brown giua cac moc, so tick = tick_volume
static void genBar(const MqlRates &b, std::vector<TickRec> &out)
{
   out.clear();
   int n = (int)std::max(4L, std::min((long)C.maxTicksPerBar, b.tick_volume));
   bool bull = b.close >= b.open;
   double a1 = bull ? b.low : b.high, a2 = bull ? b.high : b.low;
   std::uniform_int_distribution<int> j(-n / 8, n / 8);
   int i1 = std::max(1, n / 3 + j(rng));
   int i2 = std::max(i1 + 1, 2 * n / 3 + j(rng));
   if(i2 > n - 2) i2 = n - 2;
   if(i1 >= i2) i1 = i2 - 1;
   if(i1 < 1) i1 = 1;
   std::vector<double> px((size_t)n);
   int anchorsI[4] = {0, i1, i2, n - 1};
   double anchorsP[4] = {b.open, a1, a2, b.close};
   double sigma = std::max(C.point, (b.high - b.low) / std::sqrt((double)n) * 0.6);
   std::normal_distribution<double> nd(0.0, 1.0);
   for(int seg = 0; seg < 3; seg++)
   {
      int s0 = anchorsI[seg], s1 = anchorsI[seg + 1];
      double p0 = anchorsP[seg], p1 = anchorsP[seg + 1];
      int m = s1 - s0;
      std::vector<double> w((size_t)m + 1, 0.0);
      for(int k = 1; k <= m; k++) w[(size_t)k] = w[(size_t)k - 1] + sigma * nd(rng);
      for(int k = 0; k <= m; k++)
      {
         double frac = m > 0 ? (double)k / m : 1.0;
         double v = p0 + (p1 - p0) * frac + (w[(size_t)k] - frac * w[(size_t)m]);
         v = std::min(b.high, std::max(b.low, v));
         px[(size_t)(s0 + k)] = roundPt(v);
      }
   }
   double sp = std::max(C.point, b.spread * C.point * C.spreadMult + C.spreadAdd);
   for(int k = 0; k < n; k++)
   {
      TickRec t;
      t.t_ms = b.time * 1000 + (long)((double)k * 59000.0 / n) + (long)uni(0, 900);
      t.bid = px[(size_t)k];
      t.ask = roundPt(t.bid + sp);
      out.push_back(t);
   }
   std::sort(out.begin(), out.end(), [](const TickRec &a, const TickRec &c) { return a.t_ms < c.t_ms; });
}

// ---------------------------------------------------------------- vong lap
static long lastDayKey = -1;
static void audit()
{
   tickCount++;
   double eq = equity();
   if(eq > peakEq) peakEq = eq;
   double dd = peakEq - eq;
   if(dd > maxDD) maxDD = dd;
   if(peakEq > 0 && dd / peakEq * 100.0 > maxDDPct) maxDDPct = dd / peakEq * 100.0;
   long dk = cur.time - cur.time % 86400;
   if(dk != lastDayKey)
   {
      days.push_back({dk, balance, eq, 0, 0});
      lastDayKey = dk;
   }
   DayAudit &d = days.back();
   if(eq < d.minEq) d.minEq = eq;
   if((long)pos.size() > maxOpen) maxOpen = (long)pos.size();
   MqlDateTime t;
   TimeToStruct(cur.time, t);
   int mod = t.hour * 60 + t.min;
   for(auto &p : pos)
   {
      if(p.sl <= 0 || p.tp <= 0) noStopTicks++;
      if(!p.flaggedEod && mod >= C.eodMinute + 2) { eodViolations++; p.flaggedEod = true; }
      if(t.day_of_week == 0 || t.day_of_week == 6) weekendViolations++;
   }
}

static void onTickFeed(const TickRec &tr, long &lastTimerSec)
{
   long t = tr.t_ms / 1000;
   double bid = roundPt(tr.bid);
   double ask = roundPt(tr.bid + (tr.ask - tr.bid) * C.spreadMult + C.spreadAdd);
   if(ask < bid) ask = bid;
   cur.time = t; cur.time_msc = tr.t_ms; cur.bid = bid; cur.ask = ask; cur.last = 0; cur.volume = 0; cur.flags = 6; cur.volume_real = 0;
   haveTick = true;
   addTick(t, bid, (int)std::lround((ask - bid) / C.point));
   for(auto &ca : C.cashAt)
      if(lastTimerSec >= 0 && lastTimerSec < ca.first && t >= ca.first)
      {
         balance += ca.second;
         addDeal(0, 0, DEAL_TYPE_BALANCE, DEAL_ENTRY_IN, 0, 0, ca.second, 0, 0, DEAL_REASON_CLIENT, ca.second > 0 ? "nap tien" : "rut tien");
         if(ca.second > 0) peakEq += ca.second; else peakEq = std::max(0.0, peakEq + ca.second);
         for(auto &d : days) if(d.key == t - t % 86400) { d.startBal += ca.second; d.minEq += ca.second; }
         printf("[%s] === GIA LAP %s %.2f ===\n", ts(t).c_str(), ca.second > 0 ? "NAP TIEN" : "RUT TIEN", ca.second);
      }
   checkStops();
   for(long r : C.restartAt)
      if(r > 0 && lastTimerSec >= 0 && lastTimerSec < r && t >= r)
      {
         printf("[%s] === GIA LAP KHOI DONG LAI EA (OnDeinit + OnInit) ===\n", ts(t).c_str());
         OnDeinit(REASON_CHARTCHANGE);
         int rc = OnInit();
         if(rc != INIT_SUCCEEDED) { fprintf(stderr, "OnInit sau khoi dong lai that bai: %d\n", rc); std::exit(4); }
      }
   OnTick();
   audit();
   if(timerOn && OnTimer && t != lastTimerSec) OnTimer();
   lastTimerSec = t;
}

static void report()
{
   std::string dir = C.outDir;
   mkdirs(dir);
   // Gop deal theo vi the
   struct Tr { long ident; long t0, t1; int type; double vol, open, close, sl0, tp0, net, risk, riskPct; int reason; std::string cmt; };
   std::map<long, Tr> tr;
   for(auto &d : deals)
   {
      if(d.type != DEAL_TYPE_BUY && d.type != DEAL_TYPE_SELL) continue;
      Tr &x = tr[d.pos];
      x.ident = d.pos;
      x.net += d.profit + d.commission + d.swap + d.fee;
      if(d.entry == DEAL_ENTRY_IN) { x.t0 = d.time; x.type = d.type == DEAL_TYPE_BUY ? 0 : 1; x.vol = d.vol; x.open = d.price; x.cmt = d.comment; }
      else { x.t1 = d.time; x.close = d.price; x.reason = d.reason; }
   }
   std::ofstream f(dir + "/lenh.csv");
   f << "ident;mo;dong;huong;lot;gia_mo;gia_dong;sl0;tp0;ket_qua;rui_ro_du_kien;rui_ro_pct;R;ly_do;comment\n";
   int n = 0, win = 0, streak = 0, maxStreak = 0, over = 0;
   double gp = 0, gl = 0, sumR = 0, worstR = 0, net = 0;
   std::map<std::string, std::vector<double>> byPP;
   std::map<int, double> byMonth;
   for(auto &kv : tr)
   {
      Tr &x = kv.second;
      if(x.t1 == 0) continue;
      auto it = closedInfo.find(x.ident);
      if(it != closedInfo.end()) { x.sl0 = it->second.sl0; x.tp0 = it->second.tp0; x.risk = it->second.riskPlan; x.riskPct = it->second.riskPct; }
      double R = x.risk > 0 ? x.net / x.risk : 0;
      n++; net += x.net; sumR += R;
      if(x.net > 0) { win++; gp += x.net; streak = 0; }
      else { gl -= x.net; streak++; maxStreak = std::max(maxStreak, streak); }
      if(n == 1 || R < worstR) worstR = R;
      if(R < -1.10) over++;
      std::string pp = x.cmt.size() >= 5 ? x.cmt.substr(0, 5) : x.cmt;
      byPP[pp].push_back(x.net);
      MqlDateTime t;
      TimeToStruct(x.t1, t);
      byMonth[t.year * 100 + t.mon] += x.net;
      const char *rs = x.reason == DEAL_REASON_SL ? "SL" : x.reason == DEAL_REASON_TP ? "TP" : x.reason == DEAL_REASON_SO ? "SO" : "EA";
      f << x.ident << ";" << ts(x.t0) << ";" << ts(x.t1) << ";" << (x.type == 0 ? "BUY" : "SELL") << ";" << x.vol << ";" << DoubleToString(x.open, 3)
        << ";" << DoubleToString(x.close, 3) << ";" << DoubleToString(x.sl0, 3) << ";" << DoubleToString(x.tp0, 3) << ";" << DoubleToString(x.net, 2)
        << ";" << DoubleToString(x.risk, 2) << ";" << DoubleToString(x.riskPct, 3) << ";" << DoubleToString(R, 3) << ";" << rs << ";" << x.cmt << "\n";
   }
   std::ofstream fd(dir + "/ngay.csv");
   fd << "ngay;balance_dau_ngay;equity_thap_nhat;lo_toi_da_trong_ngay_pct;so_lenh_mo\n";
   double worstDay = 0;
   for(auto &d : days)
   {
      double lp = d.startBal > 0 ? (d.startBal - d.minEq) / d.startBal * 100.0 : 0;
      if(lp > worstDay) worstDay = lp;
      fd << TimeToString((datetime)d.key, TIME_DATE) << ";" << DoubleToString(d.startBal, 2) << ";" << DoubleToString(d.minEq, 2) << ";"
         << DoubleToString(lp, 3) << ";" << d.trades << "\n";
   }
   std::ostringstream o;
   double pf = gl > 0 ? gp / gl : 0;
   o << "=== BAO CAO MT5SIM ===\n";
   o << "che do du lieu: " << C.mode << " | tu " << ts(C.start) << " den " << ts(cur.time) << " | tick da chay: " << tickCount << "\n";
   o << "von ban dau: " << C.deposit << " | balance cuoi: " << DoubleToString(balance, 2) << " | equity cuoi: " << DoubleToString(equity(), 2) << "\n";
   o << "spread x" << C.spreadMult << " +" << C.spreadAdd << " | truot gia toi da " << C.slipMax << " | phi/lot/chieu " << C.commissionSide << "\n";
   o << "so lenh: " << n << " | thang: " << win << " | win rate: " << DoubleToString(n ? 100.0 * win / n : 0, 2) << "%\n";
   o << "net: " << DoubleToString(net, 2) << " | loi gop: " << DoubleToString(gp, 2) << " | lo gop: " << DoubleToString(gl, 2) << " | PF: " << DoubleToString(pf, 3) << "\n";
   o << "ky vong/lenh: " << DoubleToString(n ? net / n : 0, 3) << " | ky vong R: " << DoubleToString(n ? sumR / n : 0, 4)
     << " | TB thang: " << DoubleToString(win ? gp / win : 0, 2) << " | TB thua: " << DoubleToString(n - win ? gl / (n - win) : 0, 2) << "\n";
   o << "chuoi thua dai nhat: " << maxStreak << " | R xau nhat: " << DoubleToString(worstR, 3) << " | so lenh lo vuot 1.1R: " << over << "\n";
   o << "max DD equity: " << DoubleToString(maxDD, 2) << " (" << DoubleToString(maxDDPct, 3) << "%) | recovery factor: "
     << DoubleToString(maxDD > 0 ? net / maxDD : 0, 3) << "\n";
   o << "--- KIEM TOAN RUI RO (doc lap voi EA) ---\n";
   o << "rui ro du kien lon nhat mot lenh: " << DoubleToString(maxRiskPct, 4) << "% cua min(balance, equity)" << (maxRiskPct <= 1.0 + 1e-6 ? "  [DAT <=1%]" : "  [VUOT 1%]") << "\n";
   o << "lo trong ngay lon nhat: " << DoubleToString(worstDay, 3) << "% balance dau ngay" << (worstDay <= 10.0 + 1e-6 ? "  [DAT <=10%]" : "  [VUOT 10%]") << "\n";
   o << "so tick co vi the thieu SL/TP sau OnTick: " << noStopTicks << " | vi the con mo sau gio dong cuoi ngay: " << eodViolations
     << " | tick cuoi tuan con vi the: " << weekendViolations << " | so vi the dong thoi lon nhat: " << maxOpen << "\n";
   o << "--- THEO COMMENT (PP) ---\n";
   for(auto &kv : byPP)
   {
      double s = 0, g = 0, l = 0; int w = 0;
      for(double x : kv.second) { s += x; if(x > 0) { w++; g += x; } else l -= x; }
      o << kv.first << ": " << kv.second.size() << " lenh | WR " << DoubleToString(100.0 * w / kv.second.size(), 1) << "% | PF "
        << DoubleToString(l > 0 ? g / l : 0, 2) << " | net " << DoubleToString(s, 2) << "\n";
   }
   o << "--- THEO THANG ---\n";
   for(auto &kv : byMonth) o << kv.first << ": " << DoubleToString(kv.second, 2) << "\n";
   std::ofstream fr(dir + "/bao_cao.txt");
   fr << o.str();
   printf("%s", o.str().c_str());
}

static void onSignal(int sig)
{
   fprintf(stderr, "\n*** LOI RUNTIME (tin hieu %d, co the la chia cho 0 / phep tinh khong hop le) tai %s\n", sig, ts(cur.time).c_str());
   std::_Exit(3);
}

int main(int argc, char **argv)
{
   if(argc < 2) { fprintf(stderr, "Cach dung: mt5sim <file cau hinh> [KEY=VALUE ...]\n"); return 1; }
   std::vector<std::pair<std::string, std::string>> inputs;
   auto apply = [&](const std::string &k, const std::string &v) {
      if(k == "mode") C.mode = v;
      else if(k == "ticks") C.tickFile = v;
      else if(k == "m1") C.m1File = v;
      else if(k == "out") C.outDir = v;
      else if(k == "start") C.start = parseTime(v);
      else if(k == "end") C.end = parseTime(v);
      else if(k == "deposit") C.deposit = std::stod(v);
      else if(k == "leverage") C.leverage = std::stod(v);
      else if(k == "commission_side") C.commissionSide = std::stod(v);
      else if(k == "slip_max") C.slipMax = std::stod(v);
      else if(k == "spread_mult") C.spreadMult = std::stod(v);
      else if(k == "spread_add") C.spreadAdd = std::stod(v);
      else if(k == "stops_level") C.stopsLevel = std::stol(v);
      else if(k == "freeze_level") C.freezeLevel = std::stol(v);
      else if(k == "tester") C.tester = std::stoi(v);
      else if(k == "trade_mode") C.tradeMode = std::stoi(v);
      else if(k == "margin_mode") C.marginMode = std::stoi(v);
      else if(k == "restart_at") C.restartAt.push_back(parseTime(v));
      else if(k == "cash_at")
      {
         size_t c = v.find(',');
         C.cashAt.push_back({parseTime(v.substr(0, c)), std::stod(v.substr(c + 1))});
      }
      else if(k == "seed") C.seed = (unsigned)std::stoul(v);
      else if(k == "max_ticks_per_bar") C.maxTicksPerBar = std::stoi(v);
      else if(k == "eod_minute") C.eodMinute = std::stoi(v);
      else if(k == "quiet") C.quiet = v == "1";
      else if(k == "symbol") _Symbol = v;
      else if(k.rfind("Inp", 0) == 0) inputs.push_back({k, v});
      else fprintf(stderr, "CANH BAO: khoa cau hinh la: %s\n", k.c_str());
   };
   {
      std::ifstream in(argv[1]);
      if(!in) { fprintf(stderr, "Khong mo duoc cau hinh %s\n", argv[1]); return 1; }
      std::string line;
      while(std::getline(in, line))
      {
         if(!line.empty() && line.back() == '\r') line.pop_back();
         if(line.empty() || line[0] == '#' || line[0] == ';') continue;
         size_t eq = line.find('=');
         if(eq == std::string::npos) continue;
         apply(line.substr(0, eq), line.substr(eq + 1));
      }
   }
   for(int i = 2; i < argc; i++)
   {
      std::string a = argv[i];
      size_t eq = a.find('=');
      if(eq != std::string::npos) apply(a.substr(0, eq), a.substr(eq + 1));
   }
   rng.seed(C.seed);
   _Point = C.point;
   _Digits = C.digits;
   mkdirs(C.outDir);
   journal.open(C.outDir + "/journal.txt");
   for(auto &kv : inputs) __apply_input(kv.first, kv.second);
   ENUM_TIMEFRAMES tfs[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1};
   for(auto tf : tfs) ser.push_back({tf, tfSec(tf), {}});
   std::vector<MqlRates> m1 = loadM1(C.m1File);
   if(C.end == 0) C.end = m1.back().time + 60;
   size_t k = 0;
   for(; k < m1.size() && m1[k].time < C.start; k++) addBar(m1[k]);
   printf("Nap lich su: %zu nen M1 truoc %s\n", k, ts(C.start).c_str());
   feenableexcept(FE_DIVBYZERO | FE_INVALID);
   signal(SIGFPE, onSignal);
   // Tick dau tien de EA doc gia khi OnInit
   balance = C.deposit;
   cur.time = C.start;
   cur.time_msc = C.start * 1000;
   addDeal(0, 0, DEAL_TYPE_BALANCE, DEAL_ENTRY_IN, 0, 0, C.deposit, 0, 0, DEAL_REASON_CLIENT, "nap tien");
   peakEq = C.deposit;
   long lastTimerSec = -1;
   bool inited = false;
   auto ensureInit = [&](const TickRec &first) {
      if(inited) return;
      cur.time = first.t_ms / 1000; cur.time_msc = first.t_ms; cur.bid = roundPt(first.bid);
      cur.ask = roundPt(first.bid + (first.ask - first.bid) * C.spreadMult + C.spreadAdd); haveTick = true;
      int rc = OnInit();
      if(rc != INIT_SUCCEEDED) { fprintf(stderr, "OnInit that bai: %d\n", rc); std::exit(4); }
      inited = true;
   };
   if(C.mode == "real")
   {
      FILE *f = fopen(C.tickFile.c_str(), "rb");
      if(!f) { fprintf(stderr, "Khong mo duoc tick %s\n", C.tickFile.c_str()); return 2; }
      TickRec buf[8192];
      size_t got;
      while(!removed && (got = fread(buf, sizeof(TickRec), 8192, f)) > 0)
      {
         for(size_t i = 0; i < got && !removed; i++)
         {
            long t = buf[i].t_ms / 1000;
            if(t < C.start) continue;
            if(t >= C.end) { removed = true; break; }
            ensureInit(buf[i]);
            onTickFeed(buf[i], lastTimerSec);
         }
      }
      fclose(f);
   }
   else
   {
      std::vector<TickRec> tk;
      for(; k < m1.size() && !removed; k++)
      {
         if(m1[k].time >= C.end) break;
         genBar(m1[k], tk);
         for(auto &t : tk)
         {
            ensureInit(t);
            onTickFeed(t, lastTimerSec);
            if(removed) break;
         }
      }
   }
   if(inited)
   {
      if(OnTester) OnTester();
      OnDeinit(REASON_REMOVE);
   }
   report();
   std::ofstream g(C.outDir + "/global_variables.txt");
   for(auto &kv : gv) g << kv.first << "=" << kv.second << "\n";
   return 0;
}
