"""A tiny in-memory stand-in for the MetaTrader5 package.

It replays bars (M1/M5) as 4 ticks each (open, first extreme, second extreme, close),
fills market orders at the current tick, and triggers SL/TP server-side - just
enough to drive ``goldbot.live.LiveTrader`` end to end without a terminal.
"""

from types import SimpleNamespace as NS


class FakeMT5:
    ACCOUNT_TRADE_MODE_DEMO, ACCOUNT_TRADE_MODE_REAL = 0, 2
    TIMEFRAME_M1, TIMEFRAME_M5 = 1, 5
    TRADE_ACTION_DEAL, TRADE_ACTION_SLTP = 1, 6
    ORDER_TYPE_BUY, ORDER_TYPE_SELL = 0, 1
    POSITION_TYPE_BUY, POSITION_TYPE_SELL = 0, 1
    DEAL_TYPE_BUY, DEAL_TYPE_SELL = 0, 1
    DEAL_ENTRY_IN, DEAL_ENTRY_OUT = 0, 1
    ORDER_FILLING_FOK, ORDER_FILLING_IOC, ORDER_FILLING_RETURN = 0, 1, 2
    ORDER_TIME_GTC = 0

    def __init__(self, bars, symbol="XAUUSD", balance=10000.0, demo=True, start=0, contract=100.0):
        self.b, self.sym, self.contract = bars, symbol, contract
        self.balance = balance
        self.demo = demo
        self.k, self.n = start, 0
        self.positions = {}
        self.deals = []
        self.next_ticket = 1000
        self.rates = [dict(time=bars.t[i], open=bars.o[i], high=bars.h[i], low=bars.l[i], close=bars.c[i],
                           tick_volume=0, spread=round(bars.spread[i] / 0.01), real_volume=0) for i in range(len(bars))]

    # -- market replay
    def _path(self, k):
        b = self.b
        o, h, l, c = b.o[k], b.h[k], b.l[k], b.c[k]
        return (o, h, l, c) if c < o else (o, l, h, c)

    def bid(self):
        return self._path(self.k)[self.n]

    def ask(self):
        return self.bid() + self.b.spread[self.k]

    def advance(self):
        self.n += 1
        if self.n > 3:
            self.n = 0
            self.k += 1
        if self.k < len(self.b):
            self._check_stops()
        return self.k < len(self.b)

    def _check_stops(self):
        for p in list(self.positions.values()):
            buy = p.type == 0
            px = self.bid() if buy else self.ask()
            if p.sl and ((buy and px <= p.sl) or (not buy and px >= p.sl)):
                self._close(p, p.volume, px, "sl")
            elif p.tp and ((buy and px >= p.tp) or (not buy and px <= p.tp)):
                self._close(p, p.volume, px, "tp")

    def _now(self):
        return self.b.t[self.k] + self.n * (self.b.tf // 4)

    def _close(self, p, vol, px, why):
        buy = p.type == 0
        pnl = (px - p.price_open) * (1 if buy else -1) * vol * self.contract
        self.balance += pnl
        self.deals.append(NS(ticket=len(self.deals) + 1, position_id=p.ticket, magic=p.magic, symbol=self.sym,
                             time=self._now(), entry=1, type=1 if buy else 0, volume=vol, price=px,
                             profit=pnl, swap=0.0, commission=0.0, fee=0.0, comment=why))
        p.volume = round(p.volume - vol, 2)
        if p.volume <= 1e-9:
            del self.positions[p.ticket]

    # -- MetaTrader5 API subset
    def initialize(self, **kw):
        return True

    def shutdown(self):
        pass

    def last_error(self):
        return (0, "ok")

    def terminal_info(self):
        return NS(connected=True)

    def account_info(self):
        return NS(login=123456, server="FakeHFM-Demo", balance=self.balance, currency="USD",
                  trade_mode=self.ACCOUNT_TRADE_MODE_DEMO if self.demo else self.ACCOUNT_TRADE_MODE_REAL)

    def symbol_select(self, s, on):
        return s == self.sym

    def symbol_info(self, s):
        return NS(point=0.01, digits=2, trade_contract_size=self.contract, volume_min=0.01, volume_max=100.0,
                  volume_step=0.01, trade_tick_size=0.01, trade_tick_value=0.01 * self.contract,
                  trade_stops_level=0, filling_mode=1)

    def symbol_info_tick(self, s):
        return NS(time=self._now(), bid=self.bid(), ask=self.ask())

    def copy_rates_from_pos(self, s, tf, start, count):
        k = self.k
        seen = self._path(k)[: self.n + 1]
        forming = dict(self.rates[k], high=max(seen), low=min(seen), close=seen[-1])
        return self.rates[max(0, k - count + 1):k] + [forming]

    def positions_get(self, symbol=None):
        return tuple(self.positions.values())

    def history_deals_get(self, a, b):
        return tuple(d for d in self.deals if a <= d.time <= b)

    def order_send(self, r):
        if r["action"] == self.TRADE_ACTION_SLTP:
            p = self.positions.get(r["position"])
            if not p:
                return NS(retcode=10013, comment="no position")
            p.sl, p.tp = r["sl"], r["tp"]
            return NS(retcode=10009, comment="done")
        if "position" in r:
            p = self.positions.get(r["position"])
            if not p:
                return NS(retcode=10013, comment="no position")
            px = self.bid() if p.type == 0 else self.ask()
            self._close(p, r["volume"], px, r.get("comment", ""))
            return NS(retcode=10009, comment="done")
        buy = r["type"] == self.ORDER_TYPE_BUY
        px = self.ask() if buy else self.bid()
        self.next_ticket += 1
        p = NS(ticket=self.next_ticket, type=0 if buy else 1, volume=r["volume"], price_open=px, sl=r.get("sl", 0),
               tp=r.get("tp", 0), magic=r["magic"], time=self._now(), symbol=self.sym)
        self.positions[p.ticket] = p
        self.deals.append(NS(ticket=len(self.deals) + 1, position_id=p.ticket, magic=p.magic, symbol=self.sym,
                             time=self._now(), entry=0, type=0 if buy else 1, volume=p.volume, price=px,
                             profit=0.0, swap=0.0, commission=0.0, fee=0.0, comment=r.get("comment", "")))
        return NS(retcode=10009, order=p.ticket, comment="done")
