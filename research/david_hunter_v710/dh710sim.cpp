// dh710sim – bộ giả lập David Hunter EA V710 (CHINH_CHU/David_Hunter_EA_V710.mq5, version 710.09)
// Chép lại đúng thứ tự gọi hàm trong OnTick/ManageTrailHedge của EA, chạy nhiều bộ SET song song.
// Đây là mô phỏng, KHÔNG phải backtest MT5. Sai khác đã biết: xem README.md.
//
// Biên dịch: g++ -O2 -std=c++17 -pthread dh710sim.cpp -o dh710sim
// Chạy:      ./dh710sim --ticks du_lieu/ticks_syn.bin --bars du_lieu/bars_m1.bin --sets sets.csv --out kq.csv
//            [--from 2026-01-01] [--to 2026-09-28] [--threads 4] [--extra_spread 0] [--chart_tf 1|5]
//            [--bars5 du_lieu/bars_m5.bin] [--balance 20000] [--live 0|1] [--log_prefix prefix] (ghi lệnh+ngày cho từng set)
#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <map>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

using std::string;
using std::vector;

// ------------------------------------------------------------------ dữ liệu
struct Tick { int64_t t; double bid, ask; };
struct Bar { int64_t t; double o, h, l, c, spread, atr1, atr15, neu; };

static vector<Tick> g_ticks;
static vector<Bar> g_m1;      // nến M1 (dùng cho spike, ATR, trend, và trailing khi chart M1)
static vector<Bar> g_m5;      // nến M5 (trailing khi chart M5)

static const double POINT = 0.001;
static const int DIGITS = 3;
static const double CONTRACT = 100.0;   // 1 lot, 1.0 giá = 100 đơn vị tiền tài khoản (USD Pro / USC Cent đều vậy)
static const double VMIN = 0.01, VMAX = 200.0, VSTEP = 0.01, TICKSIZE = 0.001;

// ------------------------------------------------------------------ tham số (tên đúng như input MQL5)
struct Params {
  long   InpMagic = 71020001;
  int    Hand_FirstDist = 70, Hand_MinDist1 = 100, Hand_AddGap1 = 110, Hand_MinDist2 = 140, Hand_AddGap2 = 160;
  int    Hand_OrderThresh = 6, Hand_MoveStep = 50;
  bool   InpGridAutoScale = true;
  double Hand_InitLot = 0.01, Hand_AddLotMult = 1.15, Hand_SideTP = 250, Hand_SideSL = 1000, Hand_AllStopLoss = 150;
  double Hand_PauseLoss = 1500, NetClosePL = 250;
  string EA_StartTime = "03:00", EA_StopTime = "15:00";
  double InpBasketMaxLoss = 1500, InpHardSLATR = 2.5;
  int    InpHardSLPts = 0;
  bool   InpFlattenOnClose = true;
  int    InpMaxLayers = 7;
  double InpMaxTotalLots = 0.12, InpDailyLossLimit = 1500, InpPeakRetracePct = 20;
  bool   InpPreOpenLevels = true;
  bool   InpSpikeEnable = true;
  double InpSpikeUSD = 3.0;
  int    InpSpikePauseMin = 30;
  bool   InpSpikeRemovePend = true;
  bool   EnableCloseButtons = true;
  double MaxLot = 0.05, DailyProfitTarget = 300;
  string name;
};

static bool parse_bool(const string &v) { return v == "true" || v == "1" || v == "True" || v == "TRUE"; }

static bool set_param(Params &p, const string &k, const string &v) {
#define PI(x) if (k == #x) { p.x = atoi(v.c_str()); return true; }
#define PL(x) if (k == #x) { p.x = atol(v.c_str()); return true; }
#define PD(x) if (k == #x) { p.x = atof(v.c_str()); return true; }
#define PB(x) if (k == #x) { p.x = parse_bool(v); return true; }
#define PS(x) if (k == #x) { p.x = v; return true; }
  PL(InpMagic) PI(Hand_FirstDist) PI(Hand_MinDist1) PI(Hand_AddGap1) PI(Hand_MinDist2) PI(Hand_AddGap2)
  PI(Hand_OrderThresh) PI(Hand_MoveStep) PB(InpGridAutoScale) PD(Hand_InitLot) PD(Hand_AddLotMult) PD(Hand_SideTP)
  PD(Hand_SideSL) PD(Hand_AllStopLoss) PD(Hand_PauseLoss) PD(NetClosePL) PS(EA_StartTime) PS(EA_StopTime)
  PD(InpBasketMaxLoss) PD(InpHardSLATR) PI(InpHardSLPts) PB(InpFlattenOnClose) PI(InpMaxLayers) PD(InpMaxTotalLots)
  PD(InpDailyLossLimit) PD(InpPeakRetracePct) PB(InpPreOpenLevels) PB(InpSpikeEnable) PD(InpSpikeUSD)
  PI(InpSpikePauseMin) PB(InpSpikeRemovePend) PB(EnableCloseButtons) PD(MaxLot) PD(DailyProfitTarget) PS(name)
  return false;
}

// ------------------------------------------------------------------ hàm làm tròn giống EA
static double LiftNormalize(double value, int digits) {
  long long truncv = (long long)value;
  double p10 = 1.0;
  for (int i = 0; i < digits; i++) p10 *= 10.0;
  double t = (double)truncv;
  double frac = value - t;
  double add = (value > 0.0) ? 0.5000001 : -0.5000001;
  long long r = (long long)(frac * p10 + add);
  return (double)r / p10 + t;
}
static double LN(double v) { return LiftNormalize(v, DIGITS); }
static double LiftNormalizeTick(double v) { return LN(TICKSIZE * std::round(v / TICKSIZE)); }
static double Norm11c60(double v, bool up) {
  double q = v / TICKSIZE;
  q = up ? std::ceil(q) : std::floor(q);
  return LN(q * TICKSIZE);
}

static int parse_hms(const string &s) {
  size_t p1 = s.find(':');
  if (p1 == string::npos) return 0;
  int h = atoi(s.substr(0, p1).c_str());
  string rest = s.substr(p1 + 1);
  size_t p2 = rest.find(':');
  int m = 0, sec = 0;
  if (p2 == string::npos) m = atoi(rest.c_str());
  else { m = atoi(rest.substr(0, p2).c_str()); sec = atoi(rest.substr(p2 + 1).c_str()); }
  return h * 3600 + m * 60 + sec;
}

// ------------------------------------------------------------------ mô phỏng 1 bộ SET
struct Pos { int type; double lots, open, sl, tp; int64_t open_t; int64_t ticket; };
struct Pend { bool on = false; int type = 0; double lots = 0, price = 0; int64_t ticket = 0; int n = 0; };
struct Deal { int64_t t_open, t_close; int type; double lots, open, close, profit; int reason; int layer; };

enum Reason { R_NET = 0, R_SIDETP, R_ALLTP, R_SIDESL, R_BASKET, R_SL, R_TP, R_FLAT, R_DAYHALT, R_TIMESL, R_NREASON };
static const char *REASON_NAME[] = {"chot_lai_rong", "chot_loi_1_huong", "chot_tong", "cat_lo_1_huong", "cat_lo_ro",
                                    "cham_SL", "cham_TP", "dong_ngoai_gio", "dung_ngay", "cat_lo_thoi_gian"};

struct Snap {   // CollectedPos g_pos (RefreshCollect)
  int buy_n = 0, sell_n = 0;
  double buy_lots = 0, sell_lots = 0, buy_profit = 0, sell_profit = 0;
  double buy_min_px = 0, buy_max_px = 0, sell_min_px = 0, sell_max_px = 0, buy_vwap = 0, sell_vwap = 0;
  int pend_buy_stop = 0, pend_sell_stop = 0;
  int64_t pend_buy_tk = 0, pend_sell_tk = 0;
  double pend_buy_px = 0, pend_sell_px = 0;
};

struct Result {
  string name;
  double net = 0, gp = 0, gl = 0, maxdd = 0, maxdd_pct = 0, min_eq = 0, max_lots = 0, worst_day = 0, best_day = 0;
  double max_float_loss = 0;
  int trades = 0, wins = 0, max_layers = 0, days = 0, win_days = 0, blown = 0, max_consec_loss_days = 0;
  int reasons[R_NREASON] = {0};
  std::map<string, double> month;
};

struct Sim {
  Params P;
  double balance0, balance, extra_spread;
  bool live;
  int chart_tf;
  // state
  vector<Pos> pos;
  Pend pb, ps;   // buy stop / sell stop (EA giữ tối đa 1 lệnh chờ mỗi hướng)
  int64_t next_ticket = 1;
  Snap S;
  int scale = 10;
  double g_9340 = 0; int64_t g_t02170 = 0;
  double g_peak_net = 0;
  int64_t g_trade_block_until = 0, g_spike_m1bar = -1;
  int64_t g_day_stamp = -1, g_hist_bar = -1;
  double g_day_closed = 0, realized_today = 0;
  bool g_day_halt = false;
  int dyn_latch_buy = -1, dyn_latch_sell = -1; double dyn_store_buy = 0, dyn_store_sell = 0;
  // context của tick hiện tại
  int64_t now = 0; double bid = 0, ask = 0; size_t i1 = 0, i5 = 0;  // chỉ số nến M1/M5 hiện tại
  // kết quả
  Result R;
  double peak_eq = 0;
  std::map<int64_t, double> day_pl;
  vector<Deal> *deals = nullptr;
  bool stop = false;

  int ScalePts(int pts) const { return P.InpGridAutoScale ? pts * scale : pts; }
  int GridMinDistPts(int n) const { return n > P.Hand_OrderThresh ? ScalePts(P.Hand_MinDist2) : ScalePts(P.Hand_MinDist1); }
  int GridAddGapPts(int n) const { return n > P.Hand_OrderThresh ? ScalePts(P.Hand_AddGap2) : ScalePts(P.Hand_AddGap1); }
  double GetGridLot(int n) const {
    double lot = P.Hand_InitLot;
    if (n != 0) lot = std::pow(P.Hand_AddLotMult, (double)n) * P.Hand_InitLot;
    lot = std::min(P.MaxLot, lot);
    lot = std::max(VMIN, lot);
    lot = std::min(VMAX, lot);
    lot = std::floor(lot / VSTEP) * VSTEP;
    return lot;
  }
  double PosProfit(const Pos &p) const {
    return p.type == 0 ? (bid - p.open) * p.lots * CONTRACT : (p.open - ask) * p.lots * CONTRACT;
  }
  int PendingStopsHelper() const {
    int lvl = 0;
    if (live) {
      if (ask > bid) { int spr = (int)std::ceil((ask - bid) / POINT) + 5; if (spr > lvl) lvl = spr; }
    }
    return lvl + 31;   // digits 3 -> +31
  }
  bool InHms(int a, int b) const {
    if (a == b) return false;
    int s = (int)(now % 86400);
    if (a < b) return s >= a && s < b;
    return s >= a || s < b;
  }
  int win_a = 0, win_b = 0;
  void InitWindow() {
    win_a = parse_hms(P.EA_StartTime); win_b = parse_hms(P.EA_StopTime);
    if (P.EA_StopTime.rfind("24:00", 0) == 0) win_b = 86400;
  }
  bool InTradingWindow() const {
    int a = win_a, b = win_b;
    if (a == b) return true;
    if (a == 0 && b == 86400) return true;
    return InHms(a, b) || (a == 0 && b >= 86400);
  }
  bool IsSpikeBlocked() const {
    if (!P.InpSpikeEnable) return false;
    if (g_trade_block_until <= 0) return false;
    return now < g_trade_block_until;
  }

  // ---------------------------------------------------------------- lệnh
  void ClosePos(size_t k, int reason) {
    Pos &p = pos[k];
    double px = p.type == 0 ? bid : ask;
    double pr = PosProfit(p);
    balance += pr;
    realized_today += pr;
    R.trades++;
    if (pr > 0) { R.gp += pr; R.wins++; } else R.gl += -pr;
    R.reasons[reason]++;
    day_pl[now / 86400] += pr;
    char mk[24]; time_t tt = now; struct tm g; gmtime_r(&tt, &g); snprintf(mk, sizeof mk, "%04d-%02d", g.tm_year + 1900, g.tm_mon + 1);
    R.month[mk] += pr;
    if (deals) deals->push_back({p.open_t, now, p.type, p.lots, p.open, px, pr, reason, 0});
    pos.erase(pos.begin() + k);
  }
  void CloseSide(int side, int reason) {
    for (int k = (int)pos.size() - 1; k >= 0; k--) {
      if (side == 1 && pos[k].type != 0) continue;
      if (side == -1 && pos[k].type != 1) continue;
      ClosePos(k, reason);
    }
    if (side >= 0) pb.on = false;
    if (side <= 0) ps.on = false;
  }
  void RemovePendings() { pb.on = false; ps.on = false; }

  void RefreshCollect() {
    S = Snap();
    double bn = 0, sn = 0;
    for (auto &p : pos) {
      double px = LN(p.open), pr = PosProfit(p);
      if (p.type == 1) {
        S.sell_n++; S.sell_lots += p.lots; S.sell_profit += pr; sn += p.lots * px;
        if (S.sell_min_px == 0 || px < S.sell_min_px) S.sell_min_px = px;
        if (S.sell_max_px == 0 || px > S.sell_max_px) S.sell_max_px = px;
      } else {
        S.buy_n++; S.buy_lots += p.lots; S.buy_profit += pr; bn += p.lots * px;
        if (S.buy_min_px == 0 || px < S.buy_min_px) S.buy_min_px = px;
        if (S.buy_max_px == 0 || px > S.buy_max_px) S.buy_max_px = px;
      }
    }
    if (S.buy_lots > 0) S.buy_vwap = LN(bn / S.buy_lots);
    if (S.sell_lots > 0) S.sell_vwap = LN(sn / S.sell_lots);
    if (pb.on) {
      double px = LN(pb.price);
      S.pend_buy_stop++; S.pend_buy_tk = pb.ticket; S.pend_buy_px = px;
      if (S.buy_max_px == 0 || px > S.buy_max_px) S.buy_max_px = px;
    }
    if (ps.on) {
      double px = LN(ps.price);
      S.pend_sell_stop++; S.pend_sell_tk = ps.ticket; S.pend_sell_px = px;
      if (S.sell_min_px == 0 || S.sell_min_px > px) S.sell_min_px = px;
    }
  }

  // ---------------------------------------------------------------- phía sàn: SL/TP và lệnh chờ khớp
  void BrokerFills() {
    for (int k = (int)pos.size() - 1; k >= 0; k--) {
      Pos &p = pos[k];
      if (p.type == 0) {
        if (p.sl > 0 && bid <= p.sl) { ClosePos(k, R_SL); continue; }
        if (p.tp > 0 && bid >= p.tp) { ClosePos(k, R_TP); continue; }
      } else {
        if (p.sl > 0 && ask >= p.sl) { ClosePos(k, R_SL); continue; }
        if (p.tp > 0 && ask <= p.tp) { ClosePos(k, R_TP); continue; }
      }
    }
    if (pb.on && ask >= pb.price) {
      pos.push_back({0, pb.lots, ask, 0, 0, now, next_ticket++});
      pb.on = false;
    }
    if (ps.on && bid <= ps.price) {
      pos.push_back({1, ps.lots, bid, 0, 0, now, next_ticket++});
      ps.on = false;
    }
  }

  // ---------------------------------------------------------------- EA
  void CheckSpikePause() {
    if (!P.InpSpikeEnable || P.InpSpikeUSD <= 0 || P.InpSpikePauseMin <= 0) return;
    int64_t cur = g_m1[i1].t;
    if (cur == g_spike_m1bar) return;
    g_spike_m1bar = cur;
    if (i1 == 0) return;
    const Bar &b = g_m1[i1 - 1];
    if (now - b.t > 180) return;
    double diff = std::fabs(b.c - b.o);
    if (diff < P.InpSpikeUSD) return;
    int64_t until = now + (int64_t)P.InpSpikePauseMin * 60;
    if (until > g_trade_block_until) g_trade_block_until = until;
  }

  void RefreshDailyStats() {
    int64_t day0 = now / 86400;
    if (g_day_stamp != day0) { g_day_stamp = day0; g_day_closed = 0; g_hist_bar = -1; g_day_halt = false; realized_today = 0; }
    int64_t bar = chart_tf == 5 ? g_m5[i5].t : g_m1[i1].t;
    if (bar != g_hist_bar) { g_hist_bar = bar; g_day_closed = realized_today; }
  }

  void ManageDailyGuard() {
    RefreshDailyStats();
    if (g_day_halt) return;
    if (P.InpDailyLossLimit > 0 && g_day_closed <= -P.InpDailyLossLimit) {
      g_day_halt = true; CloseSide(0, R_DAYHALT); RemovePendings();
    } else if (P.DailyProfitTarget > 0 && g_day_closed >= P.DailyProfitTarget) {
      g_day_halt = true; CloseSide(0, R_DAYHALT); RemovePendings();
    }
  }

  double ScaleXmm6() const {
    double a = std::fabs(g_9340), x = 0;
    if (a > 20.0) { double t = (a - 20.0) / 80.0; if (t > 1.0) t = 1.0; if (t < 0) t = 0; x = t; }
    return x * 0.6 + 1.0;
  }

  void UpdateTrend(bool force) {
    if (!force && g_t02170 > 0 && (now - g_t02170) < 5) return;
    g_t02170 = now;
    double neu = g_m1[i1].neu;
    if (force) { g_9340 = neu; return; }
    double oldv = g_9340, alpha = 0.22;
    if (neu * oldv < 0) alpha = 0.8;
    else if (std::fabs(neu) > std::fabs(oldv)) alpha = 0.55;
    g_9340 = oldv + (neu - oldv) * alpha;
  }

  void ManageHedge() {
    // Tỉa đầu/cuối: cổng k_flag_9021 = 1000 lệnh -> không bao giờ kích hoạt, bỏ qua.
    double xmm6 = ScaleXmm6();
    double net = S.buy_profit + S.sell_profit;
    if (P.NetClosePL > 0) {
      if (net > g_peak_net) g_peak_net = net;
      double thresh = xmm6 * P.NetClosePL;
      if (net >= thresh) {
        double retr = (P.InpPeakRetracePct > 0 ? P.InpPeakRetracePct : 20.0) * 0.01;
        bool fire = net >= 1.5 * thresh;
        if (!fire && (g_peak_net - net) >= retr * thresh) fire = true;
        if (fire) { CloseSide(0, R_NET); g_peak_net = 0; }
      }
    }
  }

  bool ModifyOk(const Pos &p, double sl, double tp) const {
    if (p.type == 0) { if (sl > 0 && sl >= bid) return false; if (tp > 0 && tp <= bid) return false; }
    else { if (sl > 0 && sl <= ask) return false; if (tp > 0 && tp >= ask) return false; }
    return true;
  }

  void EnsureHardSL() {
    if (P.InpHardSLATR <= 0 && P.InpHardSLPts <= 0) return;
    double dist = 0;
    double a15 = g_m1[i1].atr15;
    if (P.InpHardSLATR > 0 && a15 > 0) dist = P.InpHardSLATR * a15;
    if (dist <= 0 && P.InpHardSLPts > 0) dist = ScalePts(P.InpHardSLPts) * POINT;
    if (dist <= 0) return;
    for (auto &p : pos) {
      if (p.sl != 0) continue;
      double want;
      if (p.type == 0) { want = LN(p.open - dist); if (bid > 0 && bid - want < 0) want = LN(bid); }
      else { want = LN(p.open + dist); if (ask > 0 && want - ask < 0) want = LN(ask); }
      if (ModifyOk(p, want, p.tp)) p.sl = want;
    }
  }

  double TrailPrice(int dir, double price) const {
    const vector<Bar> &B = chart_tf == 5 ? g_m5 : g_m1;
    size_t cur = chart_tf == 5 ? i5 : i1;
    for (size_t k = 1; k < 500 && k <= cur; k++) {
      const Bar &b = B[cur - k];
      if (dir == 1) { double v = LN(b.l); if (v <= 0) continue; if (price <= v) continue; return v; }
      else { double v = LN(b.h); if (v <= 0) continue; if (v <= price) continue; return v; }
    }
    return 0;
  }

  void ManageTrail() {
    double act = 6.0 * scale * POINT, improve = 8.0 * scale * POINT;
    double atr = g_m1[i1].atr1;
    double x7 = 2 * atr, x9 = 1.5 * atr;
    for (auto &p : pos) {
      double open_px = LN(p.open), sl = LN(p.sl), tp = LN(p.tp);
      if (p.type == 0) {
        if (S.buy_vwap <= 0) continue;
        double h = TrailPrice(1, bid);
        if (h < S.buy_vwap + act) continue;
        if (h <= sl + improve) continue;
        if ((bid - h) / POINT <= 0) continue;
        h = LN(h);
        double x14 = 0;
        if (atr > 0 && bid - open_px > x7) x14 = LN(bid + x9);
        double ntp = x14 > 0 ? x14 : tp;
        if (ModifyOk(p, h, ntp)) { p.sl = h; p.tp = ntp; }
      } else {
        if (S.sell_vwap <= 0) continue;
        double h = TrailPrice(-1, ask);
        if (S.sell_vwap - act < h) continue;
        if (sl != 0 && sl - improve <= h) continue;
        if ((h - ask) / POINT <= 0) continue;
        h = LN(h);
        double x14 = 0;
        if (atr > 0 && open_px - ask > x7) x14 = LN(ask - x9);
        double ntp = x14 > 0 ? x14 : tp;
        if (ModifyOk(p, h, ntp)) { p.sl = h; p.tp = ntp; }
      }
    }
  }

  void DynApply(int side, double tp) {
    if (tp <= 0) return;
    for (auto &p : pos) if (p.type == side && ModifyOk(p, p.sl, tp)) p.tp = tp;
  }
  bool DynRange(int side, double &mn, double &mx) const {
    bool any = false; mn = mx = 0;
    for (auto &p : pos) {
      if (p.type != side) continue;
      if (!any) { mn = mx = p.open; any = true; } else { mn = std::min(mn, p.open); mx = std::max(mx, p.open); }
    }
    return any;
  }
  void ManageDynTP() {
    const int need = 5; const double pct = 60.0;
    int buys = S.buy_n, sells = S.sell_n;
    if (buys + sells <= 0) { dyn_store_buy = dyn_store_sell = 0; dyn_latch_buy = dyn_latch_sell = -1; return; }
    if (buys < need) { if (dyn_latch_buy != -1) { dyn_latch_buy = -1; dyn_store_buy = 0; } }
    else if (buys != dyn_latch_buy || dyn_store_buy == 0) {
      double mn, mx;
      if (DynRange(0, mn, mx) && mn > 0 && mx > mn) {
        double tp = LiftNormalizeTick(mn + (mx - mn) * (pct / 100.0));
        if (mn >= tp) tp = LiftNormalizeTick(mn + POINT);
        DynApply(0, tp); dyn_store_buy = tp; dyn_latch_buy = buys;
      }
    }
    if (sells < need) { if (dyn_latch_sell != -1) { dyn_latch_sell = -1; dyn_store_sell = 0; } }
    else if (sells != dyn_latch_sell || dyn_store_sell == 0) {
      double mn, mx;
      if (DynRange(1, mn, mx) && mn > 0 && mx > mn) {
        double tp = LiftNormalizeTick(mx + (mx - mn) * (pct / -100.0));
        if (tp >= mx) tp = LiftNormalizeTick(mx - POINT);
        DynApply(1, tp); dyn_store_sell = tp; dyn_latch_sell = sells;
      }
    }
  }

  void ManageTimeSL() {
    const int64_t span = 0x20788;
    int64_t ob = now, os = now; bool hb = false, hs = false; double bp = 0, sp = 0;
    for (auto &p : pos) {
      double pr = PosProfit(p);
      if (p.type == 0) { hb = true; bp += pr; ob = std::min(ob, p.open_t); }
      else { hs = true; sp += pr; os = std::min(os, p.open_t); }
    }
    if (hb && now - ob > span && bp < 0) for (int k = (int)pos.size() - 1; k >= 0; k--) if (pos[k].type == 0) ClosePos(k, R_TIMESL);
    if (hs && now - os > span && sp < 0) for (int k = (int)pos.size() - 1; k >= 0; k--) if (pos[k].type == 1) ClosePos(k, R_TIMESL);
  }

  void PlaceGridBuy() {
    if (IsSpikeBlocked()) return;
    if (S.pend_buy_stop > 0) return;
    if (-P.Hand_PauseLoss >= S.buy_profit) return;
    int n = S.buy_n;
    if (P.InpMaxLayers > 0 && n >= P.InpMaxLayers) return;
    int min_pts = GridMinDistPts(n), add_pts = GridAddGapPts(n);
    double want;
    if (n == 0) want = LN(ask + ScalePts(P.Hand_FirstDist) * POINT);
    else {
      want = LN(ask + min_pts * POINT);
      if (S.buy_min_px != 0) { double t = LN(S.buy_min_px - add_pts * POINT); if (t > want) want = LN(ask + add_pts * POINT); }
    }
    if (S.buy_min_px != 0) { double t = LN(S.buy_min_px - add_pts * POINT); if (t < want && n != 0) return; }
    else if (n != 0) return;
    double lot = GetGridLot(n);
    if (lot <= 0) return;
    if (P.InpMaxTotalLots > 0 && S.buy_lots + S.sell_lots + lot > P.InpMaxTotalLots) return;
    if (!InTradingWindow()) return;
    double floorp = ask + PendingStopsHelper() * POINT;
    double price = want;
    if (floorp > price) price = floorp;
    price = Norm11c60(price, true);
    if (floorp > price) price = Norm11c60(floorp, true);
    if (price <= ask || price < floorp) return;
    pb.on = true; pb.type = 0; pb.lots = lot; pb.price = price; pb.ticket = next_ticket++; pb.n = n;
  }
  void PlaceGridSell() {
    if (IsSpikeBlocked()) return;
    if (S.pend_sell_stop > 0) return;
    if (-P.Hand_PauseLoss >= S.sell_profit) return;
    int n = S.sell_n;
    if (P.InpMaxLayers > 0 && n >= P.InpMaxLayers) return;
    int min_pts = GridMinDistPts(n), add_pts = GridAddGapPts(n);
    double want;
    if (n == 0) want = LN(bid - ScalePts(P.Hand_FirstDist) * POINT);
    else {
      want = LN(bid - min_pts * POINT);
      if (S.sell_max_px != 0) { double t = LN(S.sell_max_px + add_pts * POINT); if (t > want) want = LN(bid - add_pts * POINT); }
    }
    if (S.sell_max_px != 0) { double t = LN(S.sell_max_px + add_pts * POINT); if (want < t && n != 0) return; }
    else if (n != 0) return;
    double lot = GetGridLot(n);
    if (lot <= 0) return;
    if (P.InpMaxTotalLots > 0 && S.buy_lots + S.sell_lots + lot > P.InpMaxTotalLots) return;
    if (!InTradingWindow()) return;
    double ceilp = bid - PendingStopsHelper() * POINT;
    double price = want;
    if (ceilp < price) price = ceilp;
    price = Norm11c60(price, false);
    if (price > ceilp) price = Norm11c60(ceilp, false);
    if (bid <= price || ceilp < price) return;
    ps.on = true; ps.type = 1; ps.lots = lot; ps.price = price; ps.ticket = next_ticket++; ps.n = n;
  }

  void PendingModifyBuy(double price) {
    if (price <= ask) { pb.on = false; S.pend_buy_stop = 0; S.pend_buy_tk = 0; PlaceGridBuy(); return; }
    pb.price = price;
  }
  void PendingModifySell(double price) {
    if (price >= bid) { ps.on = false; S.pend_sell_stop = 0; S.pend_sell_tk = 0; PlaceGridSell(); return; }
    ps.price = price;
  }

  void ManagePendingStops() {
    if (S.pend_buy_tk != 0) {
      int buys = S.buy_n, add = GridAddGapPts(buys), mn = GridMinDistPts(buys);
      double want = buys == 0 ? LN(ask + ScalePts(P.Hand_FirstDist) * POINT) : LN(ask + mn * POINT);
      double half = std::max((double)ScalePts(P.Hand_MoveStep), (double)PendingStopsHelper()) * POINT * 0.5;
      double op_half = LN(S.pend_buy_px - half);
      double cap = LN(S.buy_min_px - add * POINT);
      bool sil = (want <= cap) || (S.buy_min_px == 0);
      bool mod;
      if (buys == 0) mod = (op_half > want) && sil;
      else {
        double cap_max = LN(S.buy_max_px + add * POINT);
        if (want >= cap_max) mod = (op_half > want) && sil;
        else mod = (want < op_half) && (want <= cap) && sil;
      }
      if (mod) PendingModifyBuy(want);
    }
    if (S.pend_sell_tk != 0) {
      int sells = S.sell_n, add = GridAddGapPts(sells), mn = GridMinDistPts(sells);
      double want = sells == 0 ? LN(bid - ScalePts(P.Hand_FirstDist) * POINT) : LN(bid - mn * POINT);
      double half = std::max((double)ScalePts(P.Hand_MoveStep), (double)PendingStopsHelper()) * POINT * 0.5;
      double op_half = LN(S.pend_sell_px + half);
      double cap = LN(S.sell_max_px + add * POINT);
      bool sil = (cap <= want) || (S.sell_max_px == 0);
      bool mod;
      if (sells == 0) mod = (want > op_half) && sil;
      else {
        double cap_min = LN(S.sell_min_px - add * POINT);
        if (cap_min >= want) mod = (want > op_half) && sil;
        else mod = (op_half < want) && (cap <= want) && sil;
      }
      if (mod) PendingModifySell(want);
    }
  }

  void ManageTrailHedge() {
    ManageHedge();
    EnsureHardSL();
    double buy_p = S.buy_profit, sell_p = S.sell_profit, net = buy_p + sell_p;
    if (P.InpBasketMaxLoss > 0 && net <= -P.InpBasketMaxLoss) { CloseSide(0, R_BASKET); return; }
    double all_tp = P.Hand_AllStopLoss, side = P.Hand_SideTP, side_sl = P.Hand_SideSL;
    const int need = 5;
    int buys = S.buy_n, sells = S.sell_n;
    if (buy_p > -all_tp && sell_p > -all_tp) {
      if (buys < need && buy_p >= side) { CloseSide(1, R_SIDETP); return; }
      if (sells < need && sell_p >= side) { CloseSide(-1, R_SIDETP); return; }
    } else if (net >= all_tp) { CloseSide(0, R_ALLTP); return; }
    if (buy_p <= -side_sl) { CloseSide(1, R_SIDESL); return; }
    if (sell_p <= -side_sl) { CloseSide(-1, R_SIDESL); return; }
    ManageTrail();
    ManageDynTP();
    ManageTimeSL();
    PlaceGridBuy();
    PlaceGridSell();
    RefreshCollect();
    ManagePendingStops();
    UpdateTrend(false);
  }

  void OnTick() {
    CheckSpikePause();
    if (P.InpSpikeEnable && P.InpSpikeRemovePend && IsSpikeBlocked()) RemovePendings();
    ManageDailyGuard();
    if (g_day_halt) { if (!pos.empty()) CloseSide(0, R_DAYHALT); RemovePendings(); return; }
    bool win_ok = InTradingWindow();
    if (!win_ok) {
      if (pb.on || ps.on) RemovePendings();
      if (P.InpFlattenOnClose && !pos.empty()) CloseSide(0, R_FLAT);
    }
    RefreshCollect();
    ManageTrailHedge();
  }

  void Run(size_t t_begin, size_t t_end) {
    InitWindow();
    balance = balance0; peak_eq = balance0; R.min_eq = balance0;
    bool init = false;
    double floating_min = 0;
    for (size_t k = t_begin; k < t_end && !stop; k++) {
      const Tick &tk = g_ticks[k];
      now = tk.t / 1000; bid = tk.bid; ask = tk.ask + extra_spread;
      while (i1 + 1 < g_m1.size() && g_m1[i1 + 1].t <= now) i1++;
      if (chart_tf == 5) while (i5 + 1 < g_m5.size() && g_m5[i5 + 1].t <= now) i5++;
      if (!init) { UpdateTrend(true); init = true; }
      // phía sàn trước, rồi EA
      if (!pos.empty() || pb.on || ps.on) BrokerFills();
      OnTick();
      // số liệu
      double fl = 0, lots = 0;
      for (auto &p : pos) { fl += PosProfit(p); lots += p.lots; }
      double eq = balance + fl;
      if (fl < floating_min) floating_min = fl;
      if (eq > peak_eq) peak_eq = eq;
      double dd = peak_eq - eq;
      if (dd > R.maxdd) { R.maxdd = dd; R.maxdd_pct = 100.0 * dd / peak_eq; }
      if (eq < R.min_eq) R.min_eq = eq;
      if (lots > R.max_lots) R.max_lots = lots;
      int nb = 0, ns = 0; for (auto &p : pos) (p.type == 0 ? nb : ns)++;
      R.max_layers = std::max(R.max_layers, std::max(nb, ns));
      if (eq <= 0) { R.blown = 1; stop = true; }
    }
    // đóng phần còn lại ở tick cuối
    if (!pos.empty()) CloseSide(0, R_FLAT);
    R.net = balance - balance0;
    R.max_float_loss = -floating_min;
    int consec = 0;
    for (auto &d : day_pl) {
      R.days++;
      if (d.second > 0) { R.win_days++; consec = 0; } else { consec++; R.max_consec_loss_days = std::max(R.max_consec_loss_days, consec); }
      R.worst_day = std::min(R.worst_day, d.second);
      R.best_day = std::max(R.best_day, d.second);
    }
  }
};

// ------------------------------------------------------------------ IO
template <class T> static vector<T> read_bin(const string &path) {
  std::ifstream f(path, std::ios::binary | std::ios::ate);
  if (!f) { fprintf(stderr, "không mở được %s\n", path.c_str()); exit(1); }
  size_t sz = f.tellg(); f.seekg(0);
  vector<T> v(sz / sizeof(T));
  f.read((char *)v.data(), v.size() * sizeof(T));
  return v;
}

static vector<Bar> read_bars(const string &path, int ncol) {
  auto raw = read_bin<double>(path);
  vector<Bar> out(raw.size() / ncol);
  for (size_t i = 0; i < out.size(); i++) {
    const double *r = &raw[i * ncol];
    Bar b{}; b.t = (int64_t)r[0]; b.o = r[1]; b.h = r[2]; b.l = r[3]; b.c = r[4];
    if (ncol >= 9) { b.spread = r[5]; b.atr1 = r[6]; b.atr15 = r[7]; b.neu = r[8]; }
    out[i] = b;
  }
  return out;
}

static vector<string> split(const string &s, char d) {
  vector<string> out; string cur; std::stringstream ss(s);
  while (std::getline(ss, cur, d)) { if (!cur.empty() && cur.back() == '\r') cur.pop_back(); out.push_back(cur); }
  return out;
}

static int64_t parse_date(const string &s) {   // YYYY-MM-DD -> epoch giây (UTC)
  struct tm g{}; sscanf(s.c_str(), "%d-%d-%d", &g.tm_year, &g.tm_mon, &g.tm_mday);
  g.tm_year -= 1900; g.tm_mon -= 1;
  return (int64_t)timegm(&g);
}

int main(int argc, char **argv) {
  std::map<string, string> a;
  for (int i = 1; i + 1 < argc; i += 2) a[argv[i]] = argv[i + 1];
  auto get = [&](const char *k, const char *d) { return a.count(k) ? a[k] : string(d); };
  g_ticks = read_bin<Tick>(get("--ticks", "du_lieu/ticks_syn.bin"));
  g_m1 = read_bars(get("--bars", "du_lieu/bars_m1.bin"), 9);
  int chart_tf = atoi(get("--chart_tf", "1").c_str());
  if (chart_tf == 5) g_m5 = read_bars(get("--bars5", "du_lieu/bars_m5.bin"), 5);
  int64_t from = parse_date(get("--from", "2000-01-01")) * 1000, to = parse_date(get("--to", "2100-01-01")) * 1000;
  size_t tb = std::lower_bound(g_ticks.begin(), g_ticks.end(), from, [](const Tick &x, int64_t v) { return x.t < v; }) - g_ticks.begin();
  size_t te = std::lower_bound(g_ticks.begin(), g_ticks.end(), to, [](const Tick &x, int64_t v) { return x.t < v; }) - g_ticks.begin();
  double balance = atof(get("--balance", "20000").c_str());
  double extra = atof(get("--extra_spread", "0").c_str()) * POINT;
  bool live = atoi(get("--live", "0").c_str()) != 0;
  int threads = atoi(get("--threads", "4").c_str());
  string log_prefix = get("--log_prefix", "");

  // đọc danh sách SET: CSV, dòng đầu là tên input
  vector<Params> sets;
  {
    std::ifstream f(get("--sets", "sets.csv"));
    string line; std::getline(f, line);
    auto hdr = split(line, ',');
    while (std::getline(f, line)) {
      if (line.empty()) continue;
      auto v = split(line, ',');
      Params p;
      for (size_t i = 0; i < hdr.size() && i < v.size(); i++)
        if (!set_param(p, hdr[i], v[i])) { fprintf(stderr, "input không có trong V710: %s\n", hdr[i].c_str()); return 1; }
      if (p.name.empty()) p.name = "set" + std::to_string(sets.size());
      sets.push_back(p);
    }
  }
  fprintf(stderr, "%zu tick (%zu..%zu), %zu nến M1, %zu set, %d luồng\n", te - tb, tb, te, g_m1.size(), sets.size(), threads);

  vector<Result> res(sets.size());
  std::atomic<size_t> next{0};
  std::mutex mu;
  auto worker = [&]() {
    for (;;) {
      size_t i = next++;
      if (i >= sets.size()) return;
      Sim s; s.P = sets[i]; s.balance0 = balance; s.extra_spread = extra; s.live = live; s.chart_tf = chart_tf;
      vector<Deal> deals;
      if (!log_prefix.empty()) s.deals = &deals;
      s.R.name = sets[i].name;
      s.Run(tb, te);
      res[i] = s.R;
      if (!log_prefix.empty()) {
        string fn = log_prefix + sets[i].name + "_lenh.csv";
        FILE *f = fopen(fn.c_str(), "w");
        fprintf(f, "mo,dong,loai,lot,gia_mo,gia_dong,lai_lo,ly_do\n");
        for (auto &d : deals)
          fprintf(f, "%lld,%lld,%s,%.2f,%.3f,%.3f,%.2f,%s\n", (long long)d.t_open, (long long)d.t_close, d.type == 0 ? "BUY" : "SELL",
                  d.lots, d.open, d.close, d.profit, REASON_NAME[d.reason]);
        fclose(f);
        fn = log_prefix + sets[i].name + "_ngay.csv";
        f = fopen(fn.c_str(), "w");
        fprintf(f, "ngay,lai_lo\n");
        for (auto &d : s.day_pl) fprintf(f, "%lld,%.2f\n", (long long)(d.first * 86400), d.second);
        fclose(f);
      }
      std::lock_guard<std::mutex> lk(mu);
      fprintf(stderr, "\r%zu/%zu xong", i + 1, sets.size());
    }
  };
  vector<std::thread> th;
  for (int i = 0; i < threads; i++) th.emplace_back(worker);
  for (auto &t : th) t.join();
  fprintf(stderr, "\n");

  // các tháng xuất hiện
  std::map<string, int> months;
  for (auto &r : res) for (auto &m : r.month) months[m.first] = 1;
  FILE *f = fopen(get("--out", "kq.csv").c_str(), "w");
  fprintf(f, "name,net,pf,trades,win_pct,maxdd,maxdd_pct,min_eq,max_float_loss,max_lots,max_layers,days,win_days_pct,"
             "worst_day,best_day,max_consec_loss_days,blown");
  for (int r = 0; r < R_NREASON; r++) fprintf(f, ",n_%s", REASON_NAME[r]);
  for (auto &m : months) fprintf(f, ",m_%s", m.first.c_str());
  fprintf(f, "\n");
  for (auto &r : res) {
    double pf = r.gl > 0 ? r.gp / r.gl : (r.gp > 0 ? 99 : 0);
    fprintf(f, "%s,%.2f,%.3f,%d,%.1f,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%d,%.1f,%.2f,%.2f,%d,%d", r.name.c_str(), r.net, pf, r.trades,
            r.trades ? 100.0 * r.wins / r.trades : 0, r.maxdd, r.maxdd_pct, r.min_eq, r.max_float_loss, r.max_lots, r.max_layers,
            r.days, r.days ? 100.0 * r.win_days / r.days : 0, r.worst_day, r.best_day, r.max_consec_loss_days, r.blown);
    for (int k = 0; k < R_NREASON; k++) fprintf(f, ",%d", r.reasons[k]);
    for (auto &m : months) fprintf(f, ",%.2f", r.month.count(m.first) ? r.month.at(m.first) : 0.0);
    fprintf(f, "\n");
  }
  fclose(f);
  return 0;
}
