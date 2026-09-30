"""Thong ke vi cau truc tick XAUUSD (01-12/01/2026): hoat dong, spread, tu tuong quan loi suat theo khung."""
import sys, numpy as np, pandas as pd
z = np.load(sys.argv[1]); t = z["t_ms"]; bid = z["bid"]; ask = z["ask"]
mid = (bid + ask) / 2; spr = ask - bid
ts = pd.to_datetime(t, unit="ms")
df = pd.DataFrame({"mid": mid, "spr": spr}, index=ts)
hr = df.index.hour
print("=== Hoat dong va spread theo gio server (GMT+0) ===")
g = df.groupby(hr)
days = df.index.normalize().nunique()
tab = pd.DataFrame({"tick/giay": g.size() / (days * 3600), "spread_tv": g["spr"].median(), "spread_p95": g["spr"].quantile(.95)})
print(tab.round(3).to_string())
# Lay mau moi giay (gia cuoi cung trong giay) -> loi suat theo khung
sec = df["mid"].resample("1s").last().dropna()
sec_spr = df["spr"].resample("1s").median().dropna()
print("\nSo giay co tick:", len(sec))
print("\n=== Tu tuong quan loi suat (khung h) va xac suat tiep dien sau cu di manh ===")
for h in (1, 5, 15, 30, 60, 180, 300, 900):
    r = sec.diff(h)                         # chenh gia sau h giay (theo moc giay co tick)
    r_now = r.iloc[::h].dropna()            # khong chong lap
    ac = r_now.autocorr(1)
    # cu di manh: |r| > 2 do lech chuan -> huong h giay tiep theo
    s = r_now.std(); nxt = r_now.shift(-1)
    big = r_now.abs() > 2 * s
    cont = (np.sign(r_now[big]) == np.sign(nxt[big])).mean()
    mean_next = (np.sign(r_now[big]) * nxt[big]).mean()
    print(f"h={h:>4}s  n={len(r_now):>7}  std={s:6.3f}$  autocorr={ac:+.3f}  | sau cu >2std: tiep dien {cont*100:5.1f}%  loi TB theo huong {mean_next:+.3f}$  (spread tv {sec_spr.median():.3f}$)")
