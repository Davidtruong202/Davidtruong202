"""Live trading on MetaTrader 5 with the same strategy code the backtester runs.

Loop (every ``poll_seconds``):
  1. Watch the open position tick by tick: take the partial profit at TP1 and
     move the stop to breakeven (exactly what the backtester does inside a bar).
  2. When a new bar (strategy timeframe) starts, rebuild the last ``history_bars`` closed bars,
     ask the strategy what to do (``on_bar``) and execute its actions.

Safety
  * Refuses to trade a REAL account unless ``live.allow_real_account`` is true.
  * Only touches positions carrying its own magic number.
  * Daily loss limit / consecutive-loss stop / spread filter from ``risk``.
  * ``dry_run`` logs every decision without sending orders.
  * Every order and fill is written to logs/journal_<symbol>.csv.
"""

import csv
import json
import logging
import os
import time
from datetime import datetime, timezone

from .common import lot_size
from .data import bars_from_rates
from .engine import AccountView, Close, Enter, MoveSL, PositionView, RiskGate

log = logging.getLogger("goldbot")

RET_OK = (10008, 10009, 10010)  # PLACED, DONE, DONE_PARTIAL


def _ts(t):
    return datetime.fromtimestamp(t, tz=timezone.utc).strftime("%Y-%m-%d %H:%M:%S")


class LiveTrader:
    def __init__(self, cfg, mt5, sleep=time.sleep):
        self.cfg, self.mt5, self.sleep = cfg, mt5, sleep
        self.L = cfg.live
        self.symbol = cfg.symbol
        self.magic = int(self.L["magic"])
        self.strategy = cfg.make_strategy()
        self.gate = RiskGate(cfg.risk, self.strategy.clock)
        self.last_bar = None
        self.tf = getattr(self.strategy, "timeframe", 300)
        os.makedirs(self.L["log_dir"], exist_ok=True)
        self.state_path = os.path.join(self.L["log_dir"], "state_%s_%d.json" % (self.symbol, self.magic))
        self.journal_path = os.path.join(self.L["log_dir"], "journal_%s.csv" % self.symbol)
        self.state = self._load_state()

    # ------------------------------------------------------------ plumbing
    def _load_state(self):
        try:
            with open(self.state_path, encoding="utf-8") as f:
                return json.load(f)
        except (OSError, ValueError):
            return {"positions": {}}

    def _save_state(self):
        tmp = self.state_path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(self.state, f, indent=1)
        os.replace(tmp, self.state_path)

    def journal(self, event, **kw):
        new = not os.path.exists(self.journal_path)
        cols = ["time", "event", "ticket", "side", "lots", "price", "sl", "tp", "info"]
        with open(self.journal_path, "a", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=cols)
            if new:
                w.writeheader()
            row = {k: kw.get(k, "") for k in cols}
            row["time"], row["event"] = _ts(self.now()), event
            w.writerow(row)

    def now(self):
        tick = self.mt5.symbol_info_tick(self.symbol)
        return int(tick.time) if tick else int(time.time())

    # ------------------------------------------------------------ connect
    def connect(self):
        m, L = self.mt5, self.L
        kw = {}
        if L.get("mt5_path"):
            kw["path"] = L["mt5_path"]
        if L.get("login"):
            kw.update(login=int(L["login"]), password=L.get("password", ""), server=L.get("server", ""))
        if not m.initialize(**kw):
            raise RuntimeError("Khong ket noi duoc MT5: %s" % (m.last_error(),))
        acc = m.account_info()
        if acc is None:
            raise RuntimeError("MT5 chua dang nhap tai khoan: %s" % (m.last_error(),))
        demo = acc.trade_mode == m.ACCOUNT_TRADE_MODE_DEMO
        log.info("Tai khoan %s @ %s | %s | so du %.2f %s", acc.login, acc.server, "DEMO" if demo else "THAT",
                 acc.balance, acc.currency)
        if not demo and not L.get("allow_real_account"):
            raise RuntimeError("Day la tai khoan THAT. Bot chi chay demo tru khi dat live.allow_real_account = true.")
        if not m.symbol_select(self.symbol, True):
            raise RuntimeError("Khong tim thay symbol %s trong Market Watch." % self.symbol)
        si = m.symbol_info(self.symbol)
        self.si = si
        self.point = si.point
        log.info("Symbol %s: digits=%d point=%s contract=%s lot %s-%s step %s stops_level=%s",
                 self.symbol, si.digits, si.point, si.trade_contract_size, si.volume_min, si.volume_max,
                 si.volume_step, si.trade_stops_level)
        if not demo:
            log.warning("!!! DANG GIAO DICH TAI KHOAN THAT !!!")
        log.info("Chien luoc %s | rui ro %.2f%%/lenh | lo ngay toi da %.1f%% | %s",
                 self.strategy.name, self.cfg.risk.risk_percent, self.cfg.risk.max_daily_loss_percent,
                 "DRY-RUN (khong dat lenh)" if L.get("dry_run") else "dat lenh that tren tai khoan")
        self.journal("start", info="%s %s %s" % (acc.login, "demo" if demo else "REAL", self.strategy.name))

    # ------------------------------------------------------------ queries
    def my_position(self):
        ps = self.mt5.positions_get(symbol=self.symbol) or ()
        mine = [p for p in ps if p.magic == self.magic]
        if len(mine) > 1:
            log.warning("Co %d vi the cung magic - chi quan ly vi the dau tien", len(mine))
        return mine[0] if mine else None

    def _filling(self):
        fm = getattr(self.si, "filling_mode", 0)
        if fm & 1:
            return self.mt5.ORDER_FILLING_FOK
        if fm & 2:
            return self.mt5.ORDER_FILLING_IOC
        return self.mt5.ORDER_FILLING_RETURN

    def _send(self, req, what):
        if self.L.get("dry_run"):
            log.info("[DRY-RUN] %s %s", what, req)
            return None
        res = self.mt5.order_send(req)
        if res is None or res.retcode not in RET_OK:
            log.error("%s THAT BAI: %s %s", what, getattr(res, "retcode", None),
                      getattr(res, "comment", self.mt5.last_error()))
            self.journal("error", info="%s retcode=%s %s" % (what, getattr(res, "retcode", None),
                                                               getattr(res, "comment", "")))
            return None
        return res

    def day_stats(self, now):
        """Trades opened today per side, closed P/L today and trailing losing streak (this bot only)."""
        m = self.mt5
        today = self.gate.trading_day(now)
        deals = m.history_deals_get(now - 4 * 86400, now + 2 * 86400) or ()
        buys = sells = 0
        per_pos = {}
        open_ids = {p.ticket for p in (m.positions_get(symbol=self.symbol) or ()) if p.magic == self.magic}
        for d in deals:
            if d.magic != self.magic or d.symbol != self.symbol:
                continue
            if self.gate.trading_day(int(d.time)) != today:
                continue
            if d.entry == m.DEAL_ENTRY_IN:
                if d.type == m.DEAL_TYPE_BUY:
                    buys += 1
                else:
                    sells += 1
            else:
                pnl = d.profit + d.swap + d.commission + getattr(d, "fee", 0.0)
                pp = per_pos.setdefault(d.position_id, [0.0, 0])
                pp[0] += pnl
                pp[1] = max(pp[1], int(d.time))
        closed = sorted((v for k, v in per_pos.items() if k not in open_ids), key=lambda v: v[1])
        day_pnl = sum(v[0] for v in closed)
        consec = 0
        for v in reversed(closed):
            if v[0] < 0:
                consec += 1
            else:
                break
        return buys, sells, day_pnl, consec

    # ------------------------------------------------------------ intrabar
    def manage_ticks(self, pos):
        """TP1 partial + breakeven, as soon as price touches TP1."""
        st = self.state["positions"].get(str(pos.ticket))
        if not st or st.get("tp1_done") or not st.get("tp1"):
            return
        tick = self.mt5.symbol_info_tick(self.symbol)
        buy = pos.type == self.mt5.POSITION_TYPE_BUY
        px = tick.bid if buy else tick.ask
        if (buy and px < st["tp1"]) or (not buy and px > st["tp1"]):
            return
        si = self.si
        step = si.volume_step or 0.01
        vol = round(int(pos.volume * st.get("tp1_frac", 0.5) / step + 1e-9) * step, 2)
        if si.volume_min <= vol < pos.volume:
            req = dict(action=self.mt5.TRADE_ACTION_DEAL, symbol=self.symbol, volume=vol, position=pos.ticket,
                       type=self.mt5.ORDER_TYPE_SELL if buy else self.mt5.ORDER_TYPE_BUY, price=px,
                       deviation=int(self.L["deviation_points"]), magic=self.magic, comment="GB-TP1",
                       type_time=self.mt5.ORDER_TIME_GTC, type_filling=self._filling())
            if self._send(req, "Chot TP1") is not None:
                log.info("TP1: dong %.2f lot #%s tai %.2f", vol, pos.ticket, px)
                self.journal("tp1", ticket=pos.ticket, lots=vol, price=px)
        self._modify(pos, pos.price_open, "Doi SL ve hoa von")
        st["tp1_done"] = True
        self._save_state()

    def _modify(self, pos, sl, what):
        digits = self.si.digits
        req = dict(action=self.mt5.TRADE_ACTION_SLTP, symbol=self.symbol, position=pos.ticket,
                   sl=round(sl, digits), tp=pos.tp, magic=self.magic)
        if self._send(req, what) is not None:
            log.info("%s #%s: SL %.2f -> %.2f", what, pos.ticket, pos.sl, sl)
            self.journal("modify", ticket=pos.ticket, sl=sl, tp=pos.tp, info=what)
            return True
        return False

    # ------------------------------------------------------------ per bar
    def _pos_view(self, pos, bars):
        st = self.state["positions"].get(str(pos.ticket), {})
        pv = PositionView()
        pv.buy = pos.type == self.mt5.POSITION_TYPE_BUY
        pv.open_price, pv.sl, pv.tp, pv.lots = pos.price_open, pos.sl, pos.tp, pos.volume
        pv.init_sl = st.get("init_sl", pos.sl)
        pv.tp1 = st.get("tp1", 0.0)
        pv.tp1_done = st.get("tp1_done", True)
        pv.tag = st.get("tag", "")
        bar_t = st.get("open_bar", int(pos.time) - int(pos.time) % self.tf)
        pv.open_t = bar_t
        pv.open_i = next((k for k in range(len(bars) - 1, -1, -1) if bars.t[k] <= bar_t), 0)
        best = pos.price_open
        for k in range(len(bars)):
            if bars.t[k] >= bar_t:
                best = max(best, bars.c[k]) if pv.buy else min(best, bars.c[k])
        pv.best = best
        return pv

    def on_new_bar(self, rates):
        m = self.mt5
        bars = bars_from_rates(rates, self.point, tf=self.tf)
        s = self.strategy
        s.prepare(bars)
        i = len(bars) - 1
        now = self.now()
        pos = self.my_position()
        pv = self._pos_view(pos, bars) if pos else None
        acc = m.account_info()
        tick = m.symbol_info_tick(self.symbol)
        buys, sells, day_pnl, consec = self.day_stats(now)
        av = AccountView()
        av.balance = acc.balance
        av.trades_today_buy, av.trades_today_sell = buys, sells
        av.blocked = self.gate.blocked(day_pnl, acc.balance - day_pnl, consec)
        av.spread = tick.ask - tick.bid
        log.info("Nen %s dong %.2f | spread %.0f pt | %s | hom nay: %d mua %d ban, P/L %.2f%s",
                 _ts(bars.t[i]), bars.c[i], av.spread / self.point,
                 ("vi the #%s %s SL %.2f TP %.2f" % (pos.ticket, "MUA" if pv.buy else "BAN", pos.sl, pos.tp)) if pos else "khong co vi the",
                 buys, sells, day_pnl, (" | KHOA: " + av.blocked) if av.blocked else "")
        for act in s.on_bar(i, pv, av):
            if isinstance(act, Enter):
                self.enter(act, pos, av, bars.t[i] + self.tf)
            elif isinstance(act, Close) and pos:
                self.close(pos, act.reason)
            elif isinstance(act, MoveSL) and pos:
                better = act.sl > pos.sl if pv.buy else (pos.sl == 0 or act.sl < pos.sl)
                px = tick.bid if pv.buy else tick.ask
                gap = self.si.trade_stops_level * self.point
                valid = (act.sl < px - gap) if pv.buy else (act.sl > px + gap)
                if better and valid:
                    self._modify(pos, act.sl, "Trailing SL")

    def enter(self, act, pos, av, bar_t):
        m, r, si = self.mt5, self.cfg.risk, self.si
        side = "MUA" if act.buy else "BAN"
        if pos is not None:
            return
        if av.blocked:
            log.info("Bo tin hieu %s: bi khoa (%s)", side, av.blocked)
            self.journal("skip", side=side, info="blocked " + av.blocked)
            return
        if av.spread > r.max_spread_points * self.point:
            log.info("Bo tin hieu %s: spread %.0f pt > %s", side, av.spread / self.point, r.max_spread_points)
            self.journal("skip", side=side, info="spread")
            return
        tick = m.symbol_info_tick(self.symbol)
        fill = tick.ask if act.buy else tick.bid
        dist = (fill - act.sl) if act.buy else (act.sl - fill)
        if dist <= max(si.trade_stops_level, 1) * self.point:
            log.info("Bo tin hieu %s: SL qua gan (%.2f)", side, dist)
            return
        lots = lot_size(av.balance, r.risk_percent, dist, si.trade_tick_size, si.trade_tick_value,
                        si.volume_min, si.volume_max, si.volume_step)
        if lots <= 0:
            return
        sgn = 1 if act.buy else -1
        tp = fill + sgn * act.tp_r * dist
        req = dict(action=m.TRADE_ACTION_DEAL, symbol=self.symbol, volume=lots,
                   type=m.ORDER_TYPE_BUY if act.buy else m.ORDER_TYPE_SELL, price=fill,
                   sl=round(act.sl, si.digits), tp=round(tp, si.digits), deviation=int(self.L["deviation_points"]),
                   magic=self.magic, comment="GB-" + act.tag, type_time=m.ORDER_TIME_GTC, type_filling=self._filling())
        log.info("TIN HIEU %s %.2f lot @ %.2f SL %.2f TP %.2f (%s)", side, lots, fill, act.sl, tp, act.tag)
        res = self._send(req, "Vao lenh " + side)
        if res is None:
            return
        new = self.my_position()
        if new is None:
            log.warning("Da gui lenh nhung khong thay vi the (retcode %s)", res.retcode)
            return
        # targets are measured from the real fill, as in the backtest
        real = new.price_open
        dist = (real - act.sl) if act.buy else (act.sl - real)
        tp1 = real + sgn * act.tp1_r * dist if act.tp1_r > 0 else 0.0
        self.state["positions"][str(new.ticket)] = dict(
            tp1=tp1, tp1_frac=act.tp1_frac, tp1_done=act.tp1_r <= 0, init_sl=act.sl, tag=act.tag,
            open_bar=bar_t, open_price=real)
        self._save_state()
        self.journal("open", ticket=new.ticket, side=side, lots=new.volume, price=real, sl=new.sl, tp=new.tp,
                     info=act.tag)
        want_tp = round(real + sgn * act.tp_r * dist, si.digits)
        if abs(want_tp - new.tp) >= si.point * 5:
            req = dict(action=m.TRADE_ACTION_SLTP, symbol=self.symbol, position=new.ticket, sl=new.sl, tp=want_tp,
                       magic=self.magic)
            self._send(req, "Chinh TP theo gia khop")

    def close(self, pos, reason):
        m = self.mt5
        buy = pos.type == m.POSITION_TYPE_BUY
        tick = m.symbol_info_tick(self.symbol)
        req = dict(action=m.TRADE_ACTION_DEAL, symbol=self.symbol, volume=pos.volume, position=pos.ticket,
                   type=m.ORDER_TYPE_SELL if buy else m.ORDER_TYPE_BUY, price=tick.bid if buy else tick.ask,
                   deviation=int(self.L["deviation_points"]), magic=self.magic, comment="GB-close",
                   type_time=m.ORDER_TIME_GTC, type_filling=self._filling())
        if self._send(req, "Dong lenh (%s)" % reason) is not None:
            log.info("Dong #%s: %s", pos.ticket, reason)
            self.journal("close", ticket=pos.ticket, lots=pos.volume, price=req["price"], info=reason)

    # ------------------------------------------------------------ loop
    def _forget_closed(self, pos):
        tickets = set(self.state["positions"])
        live = {str(pos.ticket)} if pos else set()
        gone = tickets - live
        for t in gone:
            log.info("Vi the #%s da dong (SL/TP hoac dong tay)", t)
            self.journal("closed", ticket=t)
            del self.state["positions"][t]
        if gone:
            self._save_state()

    def step(self):
        """One polling iteration. Returns True when a new bar was processed."""
        pos = self.my_position()
        self._forget_closed(pos)
        if pos is not None:
            self.manage_ticks(pos)
        n = int(self.L["history_bars"])
        mt_tf = self.mt5.TIMEFRAME_M1 if self.tf == 60 else self.mt5.TIMEFRAME_M5
        rates = self.mt5.copy_rates_from_pos(self.symbol, mt_tf, 0, n + 1)
        if rates is None or len(rates) < 50:
            log.warning("Chua lay duoc du lieu nen: %s", self.mt5.last_error())
            return False
        forming = int(rates[-1]["time"])
        if self.last_bar is None:
            self.last_bar = forming  # wait for the next fresh bar before acting
            log.info("Da nap %d nen lich su, doi nen M%d moi...", len(rates) - 1, self.tf // 60)
            return False
        if forming == self.last_bar:
            return False
        self.last_bar = forming
        self.on_new_bar(rates[:-1])
        return True

    def run_forever(self):
        self.connect()
        poll = float(self.L["poll_seconds"])
        try:
            while True:
                try:
                    self.step()
                except Exception:  # keep the bot alive; log and retry next poll
                    log.exception("Loi trong vong lap - thu lai")
                    if self.mt5.terminal_info() is None:
                        log.warning("Mat ket noi MT5, dang ket noi lai...")
                        self.sleep(5)
                        self.mt5.initialize()
                self.sleep(poll)
        except KeyboardInterrupt:
            log.info("Dung bot (Ctrl+C). Vi the dang mo (neu co) van giu nguyen SL/TP tren san.")
        finally:
            self.journal("stop")
            self.mt5.shutdown()
