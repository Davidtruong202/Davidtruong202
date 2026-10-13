"""Backtest DCA (nhoi lenh) dung tin hieu ban sao ATM SCALP AI lam lenh dau ro.

Cach chay:
  python3 bt_dca.py <thu muc scripts atm_scalp_ai> <thu muc phan_tich_ea> <ctxbars.csv> <spread gia>

Ro: mo lenh dau khi co tin hieu (dk 1-7) va dang khong co ro. Gia di nguoc STEP x ATR (ATR luc mo ro) thi
nhoi lop moi, lot x MULT, toi da LAYERS lop. Dong ca ro khi gia ve gia trung binh + TP x ATR.
CUT = so buoc ATR sau lop cuoi thi cat lo ca ro (0 = khong cat, gong toi khi ve).
Don vi tien: USD voi lot dau 0.01 (vang: 0.01 lot = 1 oz, gia chay 1 USD = 1 USD).
Trong 1 nen: xet TP truoc (voi gia TB cu), roi moi nhoi; khong chot TP trong cung nen vua nhoi -> than trong.
So sanh 3 cach chon chieu lenh dau: theo tin hieu / NGUOC tin hieu / ngau nhien (cung thoi diem).
"""
import sys, random
sys.path.insert(0, sys.argv[1]); sys.path.insert(0, sys.argv[2])
from load_m1 import load
import quet_khung as Q
from trigger_hunt_lib import adx_w

path, SPREAD = sys.argv[3], float(sys.argv[4])
d = load(path, "zzz_none")
o = list(d["open"]); h = list(d["high"]); l = list(d["low"]); c = list(d["close"]); t = d["bar_time"]
n = len(c)
E = {p: Q.ema(c, p) for p in (9, 14, 21, 55)}
adx, pdi, mdi, atr = adx_w(h, l, c)

cond = [0] * n
for i in range(600, n):
    for dr in (1, -1):
        if not ((E[21][i] - E[55][i]) * dr > 0 and adx[i] > 20 and (c[i] - E[9][i]) * dr > 0 and (E[9][i] - E[21][i]) * dr > 0
                and (c[i] - o[i]) * dr > 0 and ((c[i] > h[i - 1]) if dr > 0 else (c[i] < l[i - 1]))):
            continue
        if any(((l[j] <= E[14][j]) if dr > 0 else (h[j] >= E[14][j])) for j in range(i - 6, i + 1)):
            cond[i] = dr
            break


def run(STEP, MULT, LAYERS, TP, CUT, mode="sig", hours=None, seed=1):
    rnd = random.Random(seed)
    bal = 0.0; peak = 0.0; maxdd = 0.0
    B = None; res = []; maxlay = 0; cuts = 0; worst = 0.0; maxlot = 1.0
    for i in range(600, n):
        if B:
            dr = B["dr"]
            avg = B["pv"] / B["lot"]
            tgt = avg + dr * TP * B["atr"]
            if (h[i] >= tgt) if dr > 0 else (l[i] <= tgt):
                pnl = (tgt - avg) * dr * B["lot"] - B["cost"]
                bal += pnl; res.append(pnl); maxlay = max(maxlay, B["k"]); B = None
            else:
                while B["k"] < LAYERS:
                    nxt = B["last"] - dr * STEP * B["atr"]
                    if not ((l[i] <= nxt) if dr > 0 else (h[i] >= nxt)):
                        break
                    lot = B["lot0"] * MULT ** B["k"]
                    B["pv"] += nxt * lot; B["lot"] += lot; B["last"] = nxt; B["k"] += 1
                    B["cost"] += SPREAD * lot
                    maxlot = max(maxlot, B["lot"])
                if CUT > 0 and B["k"] >= LAYERS:
                    stop = B["last"] - dr * CUT * B["atr"]
                    if (l[i] <= stop) if dr > 0 else (h[i] >= stop):
                        pnl = (stop - B["pv"] / B["lot"]) * dr * B["lot"] - B["cost"]
                        bal += pnl; res.append(pnl); cuts += 1; maxlay = max(maxlay, B["k"]); B = None
            if B:  # so du tha noi xau nhat trong nen
                adv = l[i] if B["dr"] > 0 else h[i]
                fl = (adv - B["pv"] / B["lot"]) * B["dr"] * B["lot"] - B["cost"]
                worst = min(worst, fl)
                eq = bal + fl
                maxdd = max(maxdd, peak - eq)
        peak = max(peak, bal)
        maxdd = max(maxdd, peak - bal)
        if B is None and cond[i] != 0:
            if hours and not (hours[0] <= int(t[i][11:13]) < hours[1]):
                continue
            dr = cond[i] if mode == "sig" else (-cond[i] if mode == "rev" else rnd.choice((1, -1)))
            B = dict(dr=dr, atr=atr[i], lot0=1.0, lot=1.0, pv=c[i], last=c[i], k=1, cost=SPREAD)
    open_fl = 0.0
    if B:
        open_fl = (c[-1] - B["pv"] / B["lot"]) * B["dr"] * B["lot"] - B["cost"]
    return dict(n=len(res), net=bal, open=open_fl, maxdd=maxdd, worst=worst, cuts=cuts, maxlay=maxlay,
                maxlot=maxlot, win=sum(1 for x in res if x > 0))


def show(tag, r):
    wr = 100.0 * r["win"] / r["n"] if r["n"] else 0
    print(f"{tag:34s} ro {r['n']:5.0f} WR {wr:5.1f}% lai {r['net']:+9.0f}$ (ro dang mo {r['open']:+8.0f}$) "
          f"DD max {r['maxdd']:8.0f}$ am tha noi xau nhat {r['worst']:8.0f}$ cat {r['cuts']:3.0f} lop max {r['maxlay']:2.0f} "
          f"lot max {r['maxlot']*0.01:.2f}")


print(f"{path.split('/')[-1]}: {n} nen {t[0]} -> {t[-1]}, spread {SPREAD}, lot dau 0.01, don vi USD")
print("Lenh don (khong nhoi), SL 3xATR TP 1xATR de doi chieu:")
show("  1 lop, cat 3xATR, TP 1xATR", run(1, 1, 1, 1, 3))
for STEP, MULT, LAYERS, TP, CUT in [(1, 1.5, 6, 1, 0), (1, 1.5, 6, 1, 2), (2, 1.5, 6, 1, 0), (2, 1.5, 6, 1, 2),
                                    (2, 1.0, 6, 1, 2), (2, 2.0, 6, 1, 2), (3, 1.5, 5, 1, 0), (3, 1.5, 5, 1, 3),
                                    (2, 1.5, 10, 1, 0)]:
    cfg = f"buoc {STEP}xATR x{MULT} {LAYERS} lop TP {TP} cat {CUT or 'khong'}"
    print(cfg)
    show("  theo tin hieu", run(STEP, MULT, LAYERS, TP, CUT, "sig"))
    show("  NGUOC tin hieu", run(STEP, MULT, LAYERS, TP, CUT, "rev"))
    show("  ngau nhien (TB 5 lan)", {k: (sum(run(STEP, MULT, LAYERS, TP, CUT, "rnd", seed=s)[k] for s in range(5)) / 5)
                                     for k in ("n", "net", "open", "maxdd", "worst", "cuts", "maxlay", "maxlot", "win")})
    show("  theo tin hieu, gio 00-07", run(STEP, MULT, LAYERS, TP, CUT, "sig", hours=(0, 7)))
