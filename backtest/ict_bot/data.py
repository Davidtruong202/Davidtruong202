"""Load price data exported from the broker (MT5) and turn it into M5 bars.

Supported inputs (auto-detected):
  * MT5 "Bars" export   : <DATE> <TIME> <OPEN> <HIGH> <LOW> <CLOSE> <TICKVOL> <VOL> <SPREAD>
  * MT5 "Ticks" export  : <DATE> <TIME> <BID> <ASK> <LAST> <VOLUME> <FLAGS>
  * Generic CSV         : header with time/datetime (or date+time), open, high, low, close[, spread]
  * download_mt5.py CSV : time,open,high,low,close,tick_volume,spread

Bars of any timeframe <= M5 (M1, M5, ticks) are aggregated to M5. All times are
kept as broker *server* time in epoch seconds (naive, treated as UTC) - exactly
what the MT5 Strategy Tester sees.
"""

import csv
import os
import sys
from datetime import datetime, timezone

M5 = 300


class Bars:
    """Column-oriented M5 bar storage. Prices are BID prices; spread is in price units."""

    __slots__ = ("t", "o", "h", "l", "c", "spread")

    def __init__(self):
        self.t, self.o, self.h, self.l, self.c, self.spread = [], [], [], [], [], []

    def __len__(self):
        return len(self.t)

    def append(self, t, o, h, l, c, spread):
        self.t.append(t); self.o.append(o); self.h.append(h)
        self.l.append(l); self.c.append(c); self.spread.append(spread)

    def slice_time(self, t_from=None, t_to=None):
        out = Bars()
        for i in range(len(self.t)):
            if t_from is not None and self.t[i] < t_from:
                continue
            if t_to is not None and self.t[i] >= t_to:
                continue
            out.append(self.t[i], self.o[i], self.h[i], self.l[i], self.c[i], self.spread[i])
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
def load_bars(path, point=0.01, default_spread_points=25, verbose=True):
    """Read any supported file and return M5 Bars (bid prices, spread in price)."""
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

    bars = Bars()
    default_spread = default_spread_points * point
    cur_key = None
    bo = bh = bl = bc = 0.0
    spr_sum, spr_n = 0.0, 0
    n_rows = 0

    def flush():
        if cur_key is not None:
            bars.append(cur_key, bo, bh, bl, bc, (spr_sum / spr_n) if spr_n else default_spread)

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
            key = t - t % M5
            if key != cur_key:
                flush()
                cur_key, bo, bh, bl, bc, spr_sum, spr_n = key, bid, bid, bid, bid, 0.0, 0
            else:
                bh = max(bh, bid); bl = min(bl, bid); bc = bid
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
            key = t - t % M5
            if key != cur_key:
                flush()
                cur_key, bo, bh, bl, bc, spr_sum, spr_n = key, o, h, l, c, 0.0, 0
            else:
                bh = max(bh, h); bl = min(bl, l); bc = c
            if sp is not None:
                spr_sum += sp; spr_n += 1
        flush()
    fh.close()

    if len(bars) < 2:
        raise ValueError("Qua it du lieu (%d nen M5)." % len(bars))
    step = sorted(bars.t[k + 1] - bars.t[k] for k in range(min(len(bars) - 1, 2000)))[0]
    if step > M5:
        raise ValueError("Du lieu co khung lon hon M5 (buoc %ds). Hay xuat nen M1/M5 hoac tick." % step)
    if verbose:
        kind = "tick" if is_ticks else "nen"
        print("Doc %s dong %s -> %d nen M5 (%s -> %s)" % (
            format(n_rows, ","), kind, len(bars), fmt_time(bars.t[0]), fmt_time(bars.t[-1])), file=sys.stderr)
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
