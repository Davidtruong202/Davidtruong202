"""Load price data exported from the broker (MT5) and turn it into M1/M5 bars.

Supported inputs (auto-detected):
  * MT5 "Bars" export   : <DATE> <TIME> <OPEN> <HIGH> <LOW> <CLOSE> <TICKVOL> <VOL> <SPREAD>
  * MT5 "Ticks" export  : <DATE> <TIME> <BID> <ASK> <LAST> <VOLUME> <FLAGS>
  * Generic CSV         : header with time/datetime (or date+time), open, high, low, close[, spread]
  * download_mt5.py CSV : time,open,high,low,close,tick_volume,spread

Ticks and bars are aggregated to the requested timeframe (M1 or M5). All times are
kept as broker *server* time in epoch seconds (naive, treated as UTC) - exactly
what the MT5 Strategy Tester sees.
"""

import csv
import os
import sys
from datetime import datetime, timezone

M5 = 300


class Bars:
    """Column-oriented bar storage (timeframe in seconds = .tf). Prices are BID prices; spread is in price units.

    hf = which extreme printed first inside the bar: 1 high first, -1 low first,
    0 unknown. Known from tick data (and mostly from M1 bars); the backtest uses it
    to decide whether SL or TP filled first when a bar touches both.
    """

    __slots__ = ("t", "o", "h", "l", "c", "spread", "hf", "tf")
    COLS = ("t", "o", "h", "l", "c", "spread", "hf")

    def __init__(self, tf=M5):
        self.t, self.o, self.h, self.l, self.c, self.spread, self.hf = [], [], [], [], [], [], []
        self.tf = tf

    def __len__(self):
        return len(self.t)

    def append(self, t, o, h, l, c, spread, hf=0):
        self.t.append(t); self.o.append(o); self.h.append(h)
        self.l.append(l); self.c.append(c); self.spread.append(spread); self.hf.append(hf)

    def slice_time(self, t_from=None, t_to=None):
        out = Bars(self.tf)
        for i in range(len(self.t)):
            if t_from is not None and self.t[i] < t_from:
                continue
            if t_to is not None and self.t[i] >= t_to:
                continue
            out.append(self.t[i], self.o[i], self.h[i], self.l[i], self.c[i], self.spread[i], self.hf[i])
        return out

    def tail(self, n):
        out = Bars(self.tf)
        for name in self.COLS:
            setattr(out, name, getattr(self, name)[-n:])
        return out


# ---------------------------------------------------------------------------
# Parsing helpers
# ---------------------------------------------------------------------------
def _open_text(path):
    """MT5 exports ticks as UTF-16 LE with BOM; bars usually UTF-8/ANSI."""
    with open(path, "rb") as f:
        head = f.read(4)
    if head[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return open(path, "r", encoding="utf-16", newline="")
    if head[:3] == b"\xef\xbb\xbf":
        return open(path, "r", encoding="utf-8-sig", newline="")
    return open(path, "r", encoding="utf-8", errors="replace", newline="")


_TIME_FORMATS = (
    "%Y.%m.%d %H:%M:%S.%f", "%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M",
    "%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M",
    "%Y-%m-%dT%H:%M:%S", "%Y/%m/%d %H:%M:%S", "%Y/%m/%d %H:%M",
    "%d.%m.%Y %H:%M:%S", "%d.%m.%Y %H:%M", "%Y.%m.%d", "%Y-%m-%d",
)


class _TimeParser:
    """Remembers the last format that worked - parsing millions of ticks stays fast."""

    def __init__(self):
        self.fmt = None

    def __call__(self, s):
        s = s.strip()
        if s.isdigit() or (s.replace(".", "", 1).isdigit() and len(s) >= 9):
            v = float(s)
            return int(v / 1000) if v > 1e11 else int(v)  # ms or s epoch
        if self.fmt:
            try:
                return _to_epoch(datetime.strptime(s, self.fmt))
            except ValueError:
                pass
        for fmt in _TIME_FORMATS:
            try:
                dt = datetime.strptime(s, fmt)
            except ValueError:
                continue
            self.fmt = fmt
            return _to_epoch(dt)
        raise ValueError("Khong doc duoc thoi gian: %r" % s)


def _to_epoch(dt):
    return int(dt.replace(tzinfo=timezone.utc).timestamp())


def _norm(name):
    return name.strip().strip("<>").strip().lower().replace(" ", "_")


def _f(x):
    x = x.strip()
    return float(x) if x else None


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
def load_bars(path, point=0.01, default_spread_points=25, verbose=True, tf=M5):
    """Read any supported file and return Bars of `tf` seconds (bid prices, spread in price)."""
    if not os.path.exists(path):
        raise FileNotFoundError(path)

    fh = _open_text(path)
    sample = fh.read(8192)
    fh.seek(0)
    delim = "\t" if sample.count("\t") > sample.count(",") else ("," if sample.count(",") >= sample.count(";") else ";")
    reader = csv.reader(fh, delimiter=delim)
    header = [_norm(h) for h in next(reader)]

    def col(*names):
        for n in names:
            if n in header:
                return header.index(n)
        return -1

    i_date, i_time = col("date"), col("time")
    i_dt = col("datetime", "timestamp", "time_msc", "date_time", "time_utc", "gmt_time", "local_time")
    if i_dt < 0 and i_date < 0:
        i_dt = i_time  # a single "time" column holding date+time
        i_time = -1
    i_bid, i_ask = col("bid"), col("ask")
    i_o, i_h, i_l, i_c = col("open"), col("high"), col("low"), col("close")
    i_spr = col("spread")

    is_ticks = i_bid >= 0 and i_o < 0
    if not is_ticks and min(i_o, i_h, i_l, i_c) < 0:
        raise ValueError("File khong co cot OPEN/HIGH/LOW/CLOSE hoac BID/ASK. Header: %s" % header)

    parse_t = _TimeParser()

    def row_time(r):
        if i_dt >= 0:
            return parse_t(r[i_dt])
        if i_time >= 0 and i_time < len(r) and r[i_time].strip():
            return parse_t(r[i_date].strip() + " " + r[i_time].strip())
        return parse_t(r[i_date])

    bars = Bars(tf)
    default_spread = default_spread_points * point
    cur_key = None
    bo = bh = bl = bc = 0.0
    spr_sum, spr_n = 0.0, 0
    n_rows = 0
    hi_at = lo_at = 0  # sequence number where the current high / low printed
    seq = 0

    def flush():
        if cur_key is not None:
            hf = 1 if hi_at < lo_at else (-1 if lo_at < hi_at else 0)
            bars.append(cur_key, bo, bh, bl, bc, (spr_sum / spr_n) if spr_n else default_spread, hf)

    if is_ticks:
        bid = ask = None
        for r in reader:
            if not r or len(r) <= i_bid:
                continue
            n_rows += 1
            b = _f(r[i_bid])
            a = _f(r[i_ask]) if 0 <= i_ask < len(r) else None
            if b is not None:
                bid = b
            if a is not None:
                ask = a
            if bid is None or b is None:
                continue  # only bid changes move the (bid-based) chart
            t = row_time(r)
            key = t - t % tf
            seq += 1
            if key != cur_key:
                flush()
                cur_key, bo, bh, bl, bc, spr_sum, spr_n = key, bid, bid, bid, bid, 0.0, 0
                hi_at = lo_at = seq
            else:
                if bid > bh:
                    bh, hi_at = bid, seq
                if bid < bl:
                    bl, lo_at = bid, seq
                bc = bid
            if ask is not None and ask >= bid:
                spr_sum += ask - bid; spr_n += 1
            if verbose and n_rows % 2_000_000 == 0:
                print("  ... da doc %d tick" % n_rows, file=sys.stderr)
        flush()
    else:
        for r in reader:
            if not r or len(r) <= i_c or not r[i_c].strip():
                continue
            n_rows += 1
            t = row_time(r)
            o, h, l, c = float(r[i_o]), float(r[i_h]), float(r[i_l]), float(r[i_c])
            sp = None
            if i_spr >= 0 and i_spr < len(r) and r[i_spr].strip():
                sp = float(r[i_spr]) * point  # MT5 stores spread in points
                if sp <= 0:
                    sp = None
            key = t - t % tf
            seq += 1
            if key != cur_key:
                flush()
                cur_key, bo, bh, bl, bc, spr_sum, spr_n = key, o, h, l, c, 0.0, 0
                hi_at = lo_at = seq  # unknown inside a single source bar
            else:
                if h > bh:
                    bh, hi_at = h, seq
                if l < bl:
                    bl, lo_at = l, seq
                bc = c
            if sp is not None:
                spr_sum += sp; spr_n += 1
        flush()
    fh.close()

    if len(bars) < 2:
        raise ValueError("Qua it du lieu (%d nen)." % len(bars))
    step = sorted(bars.t[k + 1] - bars.t[k] for k in range(min(len(bars) - 1, 2000)))[0]
    if step > tf:
        raise ValueError("Du lieu co khung lon hon M%d (buoc %ds). Hay xuat nen M1 hoac tick." % (tf // 60, step))
    if verbose:
        kind = "tick" if is_ticks else "nen"
        print("Doc %s dong %s -> %d nen M%d (%s -> %s)" % (
            format(n_rows, ","), kind, len(bars), tf // 60, fmt_time(bars.t[0]), fmt_time(bars.t[-1])), file=sys.stderr)
    return bars


def resample(bars, tf):
    """Aggregate finer bars (e.g. M1) into `tf` seconds, keeping which extreme came first."""
    out = Bars(tf)
    cur = None
    o = h = l = c = 0.0
    sp, hi_at, lo_at, hf0 = [], 0, 0, 0
    for i in range(len(bars)):
        t = bars.t[i]
        k = t - t % tf
        if k != cur:
            if cur is not None:
                out.append(cur, o, h, l, c, sum(sp) / len(sp), 1 if hi_at < lo_at else (-1 if lo_at < hi_at else hf0))
            cur, o, h, l, c, sp = k, bars.o[i], bars.h[i], bars.l[i], bars.c[i], [bars.spread[i]]
            hi_at = lo_at = i
            hf0 = bars.hf[i]
        else:
            if bars.h[i] > h:
                h, hi_at = bars.h[i], i
            if bars.l[i] < l:
                l, lo_at = bars.l[i], i
            c = bars.c[i]
            sp.append(bars.spread[i])
    if cur is not None:
        out.append(cur, o, h, l, c, sum(sp) / len(sp), 1 if hi_at < lo_at else (-1 if lo_at < hi_at else hf0))
    return out


def bars_from_rates(rates, point, default_spread_points=25, tf=M5):
    """MT5 copy_rates_* result (numpy structured array or list of dicts) -> Bars."""
    bars = Bars(tf)
    for r in rates:
        sp = float(r["spread"]) * point if r["spread"] else default_spread_points * point
        bars.append(int(r["time"]), float(r["open"]), float(r["high"]), float(r["low"]), float(r["close"]), sp, 0)
    return bars


def fmt_time(t):
    return datetime.fromtimestamp(t, tz=timezone.utc).strftime("%Y-%m-%d %H:%M")


def save_bars_csv(bars, path, point=0.01):
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["time", "open", "high", "low", "close", "spread"])
        for i in range(len(bars)):
            w.writerow([fmt_time(bars.t[i]), bars.o[i], bars.h[i], bars.l[i], bars.c[i],
                        int(round(bars.spread[i] / point))])
