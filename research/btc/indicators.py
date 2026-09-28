"""Indicators computed only from data available at each bar's close."""
import numpy as np
import pandas as pd


def ema(s, n):
    return s.ewm(span=n, adjust=False).mean()


def rma(s, n):
    return s.ewm(alpha=1.0 / n, adjust=False).mean()


def atr(df, n=14):
    pc = df.close.shift(1)
    tr = pd.concat([df.high - df.low, (df.high - pc).abs(), (df.low - pc).abs()], axis=1).max(axis=1)
    return rma(tr, n)


def rsi(s, n=14):
    d = s.diff()
    up = rma(d.clip(lower=0), n)
    dn = rma((-d).clip(lower=0), n)
    return 100 - 100 / (1 + up / dn.replace(0, np.nan))


def stoch_k(df, n=14, smooth=3):
    ll = df.low.rolling(n).min()
    hh = df.high.rolling(n).max()
    k = 100 * (df.close - ll) / (hh - ll).replace(0, np.nan)
    return k.rolling(smooth).mean()


def bollinger(s, n=20, k=2.0):
    m = s.rolling(n).mean()
    sd = s.rolling(n).std(ddof=0)
    return m, m + k * sd, m - k * sd


def adx(df, n=14):
    up = df.high.diff()
    dn = -df.low.diff()
    pdm = np.where((up > dn) & (up > 0), up, 0.0)
    ndm = np.where((dn > up) & (dn > 0), dn, 0.0)
    a = atr(df, n)
    pdi = 100 * rma(pd.Series(pdm, index=df.index), n) / a
    ndi = 100 * rma(pd.Series(ndm, index=df.index), n) / a
    dx = 100 * (pdi - ndi).abs() / (pdi + ndi).replace(0, np.nan)
    return rma(dx, n)


def rolling_pct_rank(s, n):
    """Percentile of the current value inside the trailing n values (inclusive)."""
    return s.rolling(n).rank(pct=True)


def add_features(df):
    f = df.copy()
    f["atr"] = atr(f, 14)
    f["rsi"] = rsi(f.close, 14)
    f["stoch"] = stoch_k(f, 14, 3)
    f["ema20"] = ema(f.close, 20)
    f["ema50"] = ema(f.close, 50)
    f["ema200"] = ema(f.close, 200)
    f["bb_mid"], f["bb_up"], f["bb_lo"] = bollinger(f.close, 20, 2.0)
    f["bb_w"] = (f.bb_up - f.bb_lo) / f.atr
    f["adx"] = adx(f, 14)
    f["hh20"] = f.high.shift(1).rolling(20).max()
    f["ll20"] = f.low.shift(1).rolling(20).min()
    f["hh55"] = f.high.shift(1).rolling(55).max()
    f["ll55"] = f.low.shift(1).rolling(55).min()
    f["body"] = f.close - f.open
    f["rng"] = f.high - f.low
    f["atr_pct"] = rolling_pct_rank(f.atr, 500)
    f["bbw_pct"] = rolling_pct_rank(f.bb_w, 200)
    # Efficiency ratio over 20 bars: |net move| / path length (trendiness, 0..1)
    net = (f.close - f.close.shift(20)).abs()
    path = f.close.diff().abs().rolling(20).sum()
    f["er20"] = net / path.replace(0, np.nan)
    # Position inside the current UTC day range so far (0 = day low, 1 = day high)
    day = f.index.normalize()
    dh = f.high.groupby(day).cummax()
    dl = f.low.groupby(day).cummin()
    f["pos_day"] = (f.close - dl) / (dh - dl).replace(0, np.nan)
    # Consecutive same-colour candles (signed)
    col = np.sign(f.body).fillna(0).astype(int)
    grp = (col != col.shift()).cumsum()
    f["streak"] = col.groupby(grp).cumcount().add(1) * col
    return f
