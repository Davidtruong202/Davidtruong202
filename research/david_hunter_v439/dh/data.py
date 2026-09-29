"""Tick loading and MT5-style bar building.

Input: MT5 "Export ticks" CSV (tab separated: <DATE> <TIME> <BID> <ASK> <LAST> <VOLUME> <FLAGS>),
zipped and optionally split into GitHub-sized parts (``*.zip.part001``, ``*.zip.part002`` ...).
An incomplete part set is still usable: the deflate stream is decoded as far as the parts go
and the last partial line is dropped, so the loader reports exactly which period is covered.

Bars are built from BID prices like MT5 charts; a bar is labelled by its open time and only
exists when at least one tick falls inside it. Times are broker server time (Exness = GMT+0).
"""
import glob
import io
import os
import struct
import zlib

import numpy as np
import pandas as pd

CACHE = os.environ.get("DH_CACHE", os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".cache"))

# MT5 timeframe codes (ENUM_TIMEFRAMES) -> seconds; names as used in V4.39 grids.
TF_SECONDS = {
    "M1": 60, "M2": 120, "M3": 180, "M4": 240, "M5": 300, "M6": 360, "M10": 600, "M12": 720,
    "M15": 900, "M20": 1200, "M30": 1800, "H1": 3600, "H2": 7200, "H3": 10800, "H4": 14400,
}


class Ticks:
    """Arrays of ticks: time in ms and s (int64), bid/ask (float64)."""

    def __init__(self, t_ms, bid, ask, source=""):
        self.t_ms = np.ascontiguousarray(t_ms, dtype=np.int64)
        self.t = self.t_ms // 1000
        self.bid = np.ascontiguousarray(bid, dtype=np.float64)
        self.ask = np.ascontiguousarray(ask, dtype=np.float64)
        self.source = source

    def __len__(self):
        return len(self.t_ms)

    def slice(self, start_s=None, end_s=None):
        lo = 0 if start_s is None else int(np.searchsorted(self.t, start_s, "left"))
        hi = len(self.t) if end_s is None else int(np.searchsorted(self.t, end_s, "left"))
        return Ticks(self.t_ms[lo:hi], self.bid[lo:hi], self.ask[lo:hi], self.source)


class Bars:
    """Bars of one timeframe built from ticks.

    first/last: tick index range of the bar; open time ``time`` in seconds.
    """

    def __init__(self, tf, time, o, h, l, c, first, last):
        self.tf = tf
        self.sec = TF_SECONDS[tf]
        self.time = time
        self.open, self.high, self.low, self.close = o, h, l, c
        self.first, self.last = first, last

    def __len__(self):
        return len(self.time)


def _raw_zip_member_stream(parts):
    """Concatenate split parts and return (member_name, compressed_bytes, method, usize)."""
    blob = b"".join(open(p, "rb").read() for p in parts)
    sig, _ver, _flag, method, _t, _d, _crc, csize, usize, nlen, xlen = struct.unpack("<IHHHHHIIIHH", blob[:30])
    if sig != 0x04034B50:
        raise ValueError("not a zip local header: %s" % parts[0])
    name = blob[30:30 + nlen].decode("utf-8", "replace")
    start = 30 + nlen + xlen
    return name, blob[start:start + csize] if csize else blob[start:], method, usize, csize


def read_tick_zip(path_pattern):
    """Decode an (optionally split / incomplete) zipped MT5 tick export into a DataFrame."""
    parts = sorted(glob.glob(path_pattern))
    if not parts:
        raise FileNotFoundError(path_pattern)
    name, comp, method, usize, csize = _raw_zip_member_stream(parts)
    if method == 8:
        d = zlib.decompressobj(-15)
        raw = d.decompress(comp)
        complete = d.eof
    elif method == 0:
        raw, complete = comp, len(comp) >= csize
    else:
        raise ValueError("unsupported zip method %d" % method)
    raw = raw[: raw.rfind(b"\n") + 1]
    df = pd.read_csv(io.BytesIO(raw), sep="\t", usecols=[0, 1, 2, 3], names=["date", "time", "bid", "ask"], header=0,
                     dtype={"date": str, "time": str})
    info = {"member": name, "parts": [os.path.basename(p) for p in parts], "complete": bool(complete),
            "uncompressed_expected": int(usize), "uncompressed_read": len(raw)}
    return df, info


def ticks_from_frame(df):
    ts = pd.to_datetime(df["date"] + " " + df["time"], format="%Y.%m.%d %H:%M:%S.%f")
    t_ms = ts.values.astype("datetime64[ms]").astype(np.int64)
    bid = df["bid"].ffill().to_numpy(np.float64)
    ask = df["ask"].ffill().to_numpy(np.float64)
    ok = np.isfinite(bid) & np.isfinite(ask) & (bid > 0) & (ask >= bid)
    order = np.argsort(t_ms[ok], kind="stable")
    return t_ms[ok][order], bid[ok][order], ask[ok][order]


def load_ticks(path_pattern, cache_name, refresh=False):
    """Load ticks (cached as .npz). Returns (Ticks, info dict)."""
    os.makedirs(CACHE, exist_ok=True)
    cache = os.path.join(CACHE, cache_name + ".npz")
    if os.path.exists(cache) and not refresh:
        z = np.load(cache, allow_pickle=True)
        return Ticks(z["t_ms"], z["bid"], z["ask"], cache_name), z["info"].item()
    df, info = read_tick_zip(path_pattern)
    t_ms, bid, ask = ticks_from_frame(df)
    info.update({"ticks": int(len(t_ms)), "first": str(pd.to_datetime(t_ms[0], unit="ms")),
                 "last": str(pd.to_datetime(t_ms[-1], unit="ms"))})
    np.savez(cache, t_ms=t_ms, bid=bid, ask=ask, info=np.array(info, dtype=object))
    return Ticks(t_ms, bid, ask, cache_name), info


def build_bars(ticks, tf):
    sec = TF_SECONDS[tf]
    key = ticks.t // sec
    starts = np.flatnonzero(np.r_[True, key[1:] != key[:-1]])
    ends = np.r_[starts[1:], len(key)] - 1
    b = ticks.bid
    o = b[starts]
    c = b[ends]
    h = np.maximum.reduceat(b, starts)
    l = np.minimum.reduceat(b, starts)
    return Bars(tf, key[starts] * sec, o, h, l, c, starts.astype(np.int64), ends.astype(np.int64))


class Market:
    """Ticks plus lazily built bars for any timeframe."""

    def __init__(self, ticks, symbol="XAUUSD", tick_size=0.001, point=0.001, contract=100.0, stops_level=0, digits=3):
        self.ticks = ticks
        self.symbol = symbol
        self.tick_size = tick_size
        self.point = point
        self.contract = contract
        self.stops_level = stops_level
        self.digits = digits
        self._bars = {}
        self._tick_bar = {}

    def bars(self, tf):
        if tf not in self._bars:
            self._bars[tf] = build_bars(self.ticks, tf)
        return self._bars[tf]

    def tick_bar(self, tf):
        """Index (into bars(tf)) of the bar each tick belongs to."""
        if tf not in self._tick_bar:
            bars = self.bars(tf)
            self._tick_bar[tf] = np.repeat(np.arange(len(bars), dtype=np.int64), bars.last - bars.first + 1)
        return self._tick_bar[tf]
