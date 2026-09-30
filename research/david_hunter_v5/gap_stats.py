import csv, datetime as dt, statistics as st
import os
P = os.environ.get("DH_M1", "../../../ea-pro/data/backtest_mt5/2026-09-29_V439_7PP_KiemChung_6PP/nen_M1.csv")  # nen M1 cua EA-PRO
rows = []
with open(P) as f:
    r = csv.reader(f, delimiter=';'); next(r)
    for t, o, h, l, c, v, s in r:
        rows.append((dt.datetime.strptime(t, "%Y.%m.%d %H:%M:%S"), float(o), float(h), float(l), float(c), int(s)))
print("bars", len(rows), rows[0][0], "->", rows[-1][0])

def pct(a, q):
    a = sorted(a); k = (len(a) - 1) * q; f = int(k); c = min(f + 1, len(a) - 1)
    return a[f] + (a[c] - a[f]) * (k - f)

weekend, daily, other = [], [], []
for (t0, o0, h0, l0, c0, s0), (t1, o1, h1, l1, c1, s1) in zip(rows, rows[1:]):
    d = (t1 - t0).total_seconds() / 60
    if d <= 1: continue
    g = abs(o1 - c0)
    rec = (t0, t1, d, g, o1 - c0)
    if d >= 24 * 60: weekend.append(rec)
    elif d >= 30: daily.append(rec)
    else: other.append(rec)

def summary(name, arr):
    g = [x[3] for x in arr]
    if not g: print(name, "none"); return
    print(f"\n{name}: n={len(g)}  median={st.median(g):.2f}$  p90={pct(g,.9):.2f}$  p95={pct(g,.95):.2f}$  max={max(g):.2f}$")
    for thr in (1, 2, 5, 10, 20):
        n = sum(1 for x in g if x >= thr)
        print(f"   gap >= {thr:>2}$ : {n:>3} lần ({100*n/len(g):.1f}%)  -> với SL 5$ = lỗ >= {1+thr/5:.1f}R nếu gap vượt qua SL")
    top = sorted(arr, key=lambda x: -x[3])[:5]
    for t0, t1, d, gg, sg in top:
        print(f"   {t0:%Y-%m-%d %H:%M} -> {t1:%Y-%m-%d %H:%M}  gap {sg:+.2f}$  (= {gg/5:.1f} x SL 5$, {gg/20:.1f} x SL 20$)")

summary("CUOI TUAN (nghi >= 24h)", weekend)
summary("NGHI HANG NGAY / NGHI DAI (30 phut - 24h)", daily)
summary("KHOANG TRONG NGAN (2-29 phut)", other)
print("\nGio bat dau nghi hang ngay (gio server):", sorted(set(x[0].strftime('%H:%M') for x in daily))[:12])

# Nhay gia trong 1 phut (proxy truot gia khi co tin)
rng = [h - l for (_, o, h, l, c, s) in rows]
print(f"\nBien do nen M1: median={st.median(rng):.2f}$ p99={pct(rng,.99):.2f}$ p99.9={pct(rng,.999):.2f}$ max={max(rng):.2f}$")
for thr in (5, 10, 20):
    print(f"   so nen M1 co bien do >= {thr}$ : {sum(1 for x in rng if x >= thr)}")

# ATR(14) M5 -> SL EMA = 2.5 x ATR, doi chieu dai SL 5..20
m5 = {}
for (t, o, h, l, c, s) in rows:
    k = t.replace(minute=t.minute - t.minute % 5, second=0)
    if k not in m5: m5[k] = [o, h, l, c]
    else:
        b = m5[k]; b[1] = max(b[1], h); b[2] = min(b[2], l); b[3] = c
keys = sorted(m5); atr = None; prev_c = None; sls = []
for k in keys:
    o, h, l, c = m5[k]
    tr = h - l if prev_c is None else max(h - l, abs(h - prev_c), abs(l - prev_c))
    atr = tr if atr is None else (atr * 13 + tr) / 14   # Wilder-style smoothing (MT5 iATR dung SMA; chi xap xi)
    prev_c = c; sls.append(2.5 * atr)
sls = sls[200:]
n = len(sls)
print(f"\nEMA SL = 2.5 x ATR14(M5) tren {n} nen M5: median={st.median(sls):.2f}$ p10={pct(sls,.1):.2f}$ p90={pct(sls,.9):.2f}$")
print(f"   < 5$ (bi noi len 5$): {100*sum(1 for x in sls if x < 5)/n:.1f}%   5-20$: {100*sum(1 for x in sls if 5 <= x <= 20)/n:.1f}%   > 20$ (bi loai): {100*sum(1 for x in sls if x > 20)/n:.1f}%")
sp = [s for (*_, s) in rows]
print(f"\nspread_points M1: median={st.median(sp)} p90={pct(sp,.9):.0f} max={max(sp)}  (0.50$ = 500 points voi 3 chu so)")
print(f"   ty le nen M1 co spread > 500 points: {100*sum(1 for x in sp if x > 500)/len(sp):.2f}%")
