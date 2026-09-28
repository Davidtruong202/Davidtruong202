"""Load MT5-exported BTCUSDc data (zipped CSV in data/btcusd) into pandas.

Bars: <DATE> <TIME> <OPEN> <HIGH> <LOW> <CLOSE> <TICKVOL> <VOL> <SPREAD>, tab separated.
Ticks: <DATE> <TIME> <BID> <ASK> <LAST> <VOLUME> <FLAGS>.
All times are MT5 server time (Exness = GMT+0). Spread is in points.
Parsed frames are cached as parquet in the scratch dir (RESEARCH_CACHE env var).
"""
import glob
import os
import zipfile

import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA_DIR = os.path.join(ROOT, "data", "btcusd")
CACHE = os.environ.get("RESEARCH_CACHE", os.path.join(ROOT, ".cache"))
POINT = 0.01  # BTCUSDc price step (2 digits, confirmed by bid/ask in the data)


def _read_zip_csv(path):
    with zipfile.ZipFile(path) as z:
        name = [n for n in z.namelist() if n.lower().endswith(".csv")][0]
        with z.open(name) as f:
            return pd.read_csv(f, sep="\t")


def load_m1(refresh=False):
    os.makedirs(CACHE, exist_ok=True)
    cache = os.path.join(CACHE, "btc_m1.parquet")
    if os.path.exists(cache) and not refresh:
        return pd.read_parquet(cache)
    parts = []
    for p in sorted(glob.glob(os.path.join(DATA_DIR, "BTCUSDc_M1_*.zip"))):
        d = _read_zip_csv(p)
        d.columns = [c.strip("<>").lower() for c in d.columns]
        d.index = pd.to_datetime(d["date"] + " " + d["time"], format="%Y.%m.%d %H:%M:%S")
        parts.append(d[["open", "high", "low", "close", "tickvol", "spread"]])
    df = pd.concat(parts)
    df.index.name = "time"
    df.to_parquet(cache)
    return df


def load_ticks(refresh=False):
    os.makedirs(CACHE, exist_ok=True)
    cache = os.path.join(CACHE, "btc_ticks.parquet")
    if os.path.exists(cache) and not refresh:
        return pd.read_parquet(cache)
    parts = []
    for p in sorted(glob.glob(os.path.join(DATA_DIR, "BTCUSDc_2*.zip"))):
        d = _read_zip_csv(p)
        d.columns = [c.strip("<>").lower() for c in d.columns]
        d.index = pd.to_datetime(d["date"] + " " + d["time"], format="%Y.%m.%d %H:%M:%S.%f")
        parts.append(d[["bid", "ask", "flags"]])
    df = pd.concat(parts)
    df.index.name = "time"
    df.to_parquet(cache)
    return df


def resample(m1, rule):
    """Aggregate M1 to a higher timeframe. Bar is labelled by its open time."""
    o = m1.resample(rule, label="left", closed="left").agg(
        {"open": "first", "high": "max", "low": "min", "close": "last",
         "tickvol": "sum", "spread": "mean"})
    return o.dropna(subset=["open"])
