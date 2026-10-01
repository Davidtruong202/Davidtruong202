#!/usr/bin/env python3
"""Quét MỌI khung thời gian × MỌI chỉ báo × nhiều chu kỳ từ nến M1, để tìm điều kiện vào lệnh của một EA
không có file .set. Chỉ dùng thư viện chuẩn.

Đầu vào:
  - <prefix>_m1_<symbol>.csv  : nến M1 do TradeLogger (3.20+) xuất, InpExportM1 = true
  - <prefix>_deals.csv        : deals của TradeLogger (cột k_idx, k_side, time_msc)

    python3 quet_khung.py --m1 tradelog_m1_XAUUSD.csv --deals tradelog_deals.csv --magic 202601

Cách làm:
  1. Gộp nến M1 thành 19 khung: M1 M2 M3 M4 M5 M6 M10 M12 M15 M20 M30 H1 H2 H3 H4 H6 H8 H12 D1.
  2. Trên mỗi khung tính (công thức như MT5): EMA 5…200 (16 chu kỳ), SMA 20/50/200, hiệu mọi cặp EMA,
     RSI 2…21, CCI 14/20, ADX14 (+DI − −DI), BB20 %b, MACD 12/26/9, Stoch 5/3/3 và 14/3/3, ATR14, thân nến.
     Khoảng 160 đặc trưng mỗi khung, hơn 3000 đặc trưng tổng cộng.
  3. Lấy giá trị ở nến ĐÃ ĐÓNG ngay trước mỗi lệnh đầu của rổ và tại 2000 thời điểm ngẫu nhiên (nền chung),
     tách riêng BUY và SELL.
  4. Dò quy tắc từng bước: mỗi bước chọn điều kiện 1 phía (≤ / ≥ ngưỡng) bao ≥ 97% lệnh mà để lại ít nến
     nền nhất; bước sau tính trên phần nền còn lại, nên chỉ báo "họ hàng" (cùng đo một thứ) tự bị loại.
  5. Làm y hệt với "lệnh giả" ngẫu nhiên để biết mức nhiễu; kèm bảng KS từng đặc trưng.

Giá trị tính bằng Python có thể lệch rất nhỏ so với MT5 ở vài trăm nến đầu (khác cách khởi tạo EMA);
phần sau trùng khớp. Không ảnh hưởng việc dò.
"""
import argparse
import bisect
import calendar
import csv
import math
import os
import random
import sys
import time as _time
from array import array
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from phan_tich_chung import f, ks, load_deals, q, suggest  # noqa: E402

TFS = [("M1", 60), ("M2", 120), ("M3", 180), ("M4", 240), ("M5", 300), ("M6", 360), ("M10", 600),
       ("M12", 720), ("M15", 900), ("M20", 1200), ("M30", 1800), ("H1", 3600), ("H2", 7200),
       ("H3", 10800), ("H4", 14400), ("H6", 21600), ("H8", 28800), ("H12", 43200), ("D1", 86400)]
EMA_P = [5, 8, 9, 10, 13, 14, 20, 21, 26, 34, 50, 55, 89, 100, 144, 200]
SMA_P = [20, 50, 200]
RSI_P = [2, 3, 5, 7, 9, 14, 21]
CCI_P = [14, 20]
STOCH_P = [(5, 3, 3), (14, 3, 3)]
WARMUP = 250          # bỏ các nến đầu của mỗi khung (chỉ báo chưa ổn định)
POP_SAMPLE = 2000     # số nến lấy làm nền chung mỗi khung


# ---------------------------------------------------------------------------
# Dữ liệu
# ---------------------------------------------------------------------------
def parse_time(s):
    s = s.strip()
    for fmt in ("%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M", "%Y-%m-%d %H:%M:%S"):
        try:
            return calendar.timegm(_time.strptime(s, fmt))
        except ValueError:
            pass
    raise ValueError(f"không đọc được thời gian '{s}'")


def load_m1(path):
    rows = {}
    with open(path, encoding="utf-8-sig", newline="") as fh:
        for r in csv.DictReader(fh):
            t = parse_time(r["time"])
            rows[t] = (float(r["open"]), float(r["high"]), float(r["low"]), float(r["close"]))
    ts = sorted(rows)
    return ts, [rows[t][0] for t in ts], [rows[t][1] for t in ts], [rows[t][2] for t in ts], [rows[t][3] for t in ts]


def resample(ts, o, h, l, c, per):
    """Gộp M1 thành khung per giây. Giờ MT5 tính từ epoch theo giờ server, nên nến khung ≤ D1 bắt đầu
    đúng tại bội số của per."""
    bt, bo, bh, bl, bc = [], [], [], [], []
    cur = None
    for i in range(len(ts)):
        b = ts[i] - ts[i] % per
        if b != cur:
            cur = b
            bt.append(b); bo.append(o[i]); bh.append(h[i]); bl.append(l[i]); bc.append(c[i])
        else:
            if h[i] > bh[-1]:
                bh[-1] = h[i]
            if l[i] < bl[-1]:
                bl[-1] = l[i]
            bc[-1] = c[i]
    return bt, bo, bh, bl, bc


# ---------------------------------------------------------------------------
# Chỉ báo — công thức theo MT5
# ---------------------------------------------------------------------------
def ema(x, p):
    k = 2.0 / (p + 1)
    out = [0.0] * len(x)
    if not x:
        return out
    v = x[0]
    for i, xi in enumerate(x):
        v = xi * k + v * (1 - k) if i else xi
        out[i] = v
    return out


def sma(x, p):
    out = [None] * len(x)
    s = 0.0
    for i, xi in enumerate(x):
        s += xi
        if i >= p:
            s -= x[i - p]
        if i >= p - 1:
            out[i] = s / p
    return out


def rsi(c, p):
    n = len(c)
    out = [None] * n
    if n <= p:
        return out
    g = l = 0.0
    for i in range(1, p + 1):
        d = c[i] - c[i - 1]
        g += max(d, 0.0)
        l += max(-d, 0.0)
    g /= p
    l /= p
    out[p] = 100.0 if l == 0 else 100 - 100 / (1 + g / l)
    for i in range(p + 1, n):
        d = c[i] - c[i - 1]
        g = (g * (p - 1) + max(d, 0.0)) / p
        l = (l * (p - 1) + max(-d, 0.0)) / p
        out[i] = 100.0 if l == 0 else 100 - 100 / (1 + g / l)
    return out


def true_range(h, l, c):
    tr = [h[0] - l[0]]
    for i in range(1, len(c)):
        tr.append(max(h[i], c[i - 1]) - min(l[i], c[i - 1]))
    return tr


def adx(h, l, c, p):
    """MT5 iADX: +DI/−DI = EMA của 100·DM/TR, ADX = EMA của DX."""
    n = len(c)
    pdm = [0.0] * n
    mdm = [0.0] * n
    for i in range(1, n):
        tr = max(h[i] - l[i], abs(h[i] - c[i - 1]), abs(l[i] - c[i - 1]))
        up = max(h[i] - h[i - 1], 0.0)
        dn = max(l[i - 1] - l[i], 0.0)
        if up > dn:
            dn = 0.0
        elif dn > up:
            up = 0.0
        else:
            up = dn = 0.0
        if tr > 0:
            pdm[i] = 100 * up / tr
            mdm[i] = 100 * dn / tr
    pdi, mdi = ema(pdm, p), ema(mdm, p)
    dx = [0.0 if pdi[i] + mdi[i] == 0 else 100 * abs(pdi[i] - mdi[i]) / (pdi[i] + mdi[i]) for i in range(n)]
    return ema(dx, p), pdi, mdi


def cci(h, l, c, p):
    tp = [(h[i] + l[i] + c[i]) / 3 for i in range(len(c))]
    m = sma(tp, p)
    out = [None] * len(c)
    for i in range(p - 1, len(c)):
        md = sum(abs(tp[j] - m[i]) for j in range(i - p + 1, i + 1)) / p
        out[i] = 0.0 if md == 0 else (tp[i] - m[i]) / (0.015 * md)
    return out


def bb_pctb(c, p, k):
    out = [None] * len(c)
    m = sma(c, p)
    for i in range(p - 1, len(c)):
        var = sum((c[j] - m[i]) ** 2 for j in range(i - p + 1, i + 1)) / p
        sd = math.sqrt(var)
        out[i] = 0.5 if sd == 0 else (c[i] - (m[i] - k * sd)) / (2 * k * sd)
    return out


def stoch(h, l, c, kp, dp, slow):
    """MT5 iStochastic (MODE_SMA, STO_LOWHIGH)."""
    n = len(c)
    num = [None] * n
    den = [None] * n
    for i in range(kp - 1, n):
        ll = min(l[i - kp + 1:i + 1])
        hh = max(h[i - kp + 1:i + 1])
        num[i] = c[i] - ll
        den[i] = hh - ll
    main = [None] * n
    for i in range(kp + slow - 2, n):
        sn = sum(num[i - slow + 1:i + 1])
        sd = sum(den[i - slow + 1:i + 1])
        main[i] = 100.0 if sd == 0 else 100 * sn / sd
    sig = [None] * n
    for i in range(kp + slow + dp - 3, n):
        sig[i] = sum(main[i - dp + 1:i + 1]) / dp
    return main, sig


# ---------------------------------------------------------------------------
# Đặc trưng
# ---------------------------------------------------------------------------
class TF:
    """Một khung: mảng chỉ báo đầy đủ; đặc trưng chỉ được lấy ra ở các chỉ số cần."""

    def __init__(self, name, per, m1):
        self.name, self.per = name, per
        self.t, self.o, self.h, self.l, self.c = resample(*m1, per)
        c, h, l = self.c, self.h, self.l
        self.ema = {p: ema(c, p) for p in EMA_P}
        self.sma = {p: sma(c, p) for p in SMA_P}
        self.rsi = {p: rsi(c, p) for p in RSI_P}
        self.cci = {p: cci(h, l, c, p) for p in CCI_P}
        self.adx, self.pdi, self.mdi = adx(h, l, c, 14)
        self.atr = sma(true_range(h, l, c), 14)
        self.bb = bb_pctb(c, 20, 2.0)
        m = [a - b for a, b in zip(ema(c, 12), ema(c, 26))]
        self.macd, self.macd_sig = m, sma(m, 9)
        self.st = {k: stoch(h, l, c, *k) for k in STOCH_P}

    def closed_index(self, t_sec):
        """Nến đã đóng gần nhất tại thời điểm t: nến bắt đầu lúc s đóng lúc s + per ≤ t."""
        return bisect.bisect_right(self.t, t_sec - self.per) - 1

    def features(self, i):
        c = self.c[i]
        out = {}
        tf = self.name
        for p in EMA_P:
            out[f"{tf} EMA{p} giá−EMA %"] = (c - self.ema[p][i]) / c * 100
        for p in SMA_P:
            v = self.sma[p][i]
            out[f"{tf} SMA{p} giá−SMA %"] = None if v is None else (c - v) / c * 100
        for x in range(len(EMA_P)):
            for y in range(x + 1, len(EMA_P)):
                a, b = EMA_P[x], EMA_P[y]
                out[f"{tf} EMA{a}−EMA{b} %"] = (self.ema[a][i] - self.ema[b][i]) / c * 100
        for p in RSI_P:
            out[f"{tf} RSI{p}"] = self.rsi[p][i]
        for p in CCI_P:
            out[f"{tf} CCI{p}"] = self.cci[p][i]
        out[f"{tf} ADX14"] = self.adx[i]
        out[f"{tf} +DI−−DI 14"] = self.pdi[i] - self.mdi[i]
        out[f"{tf} BB20 %b"] = self.bb[i]
        out[f"{tf} MACD %"] = self.macd[i] / c * 100
        s = self.macd_sig[i]
        out[f"{tf} MACD−signal %"] = None if s is None else (self.macd[i] - s) / c * 100
        for k in STOCH_P:
            mn, sg = self.st[k][0][i], self.st[k][1][i]
            tag = "/".join(map(str, k))
            out[f"{tf} Stoch{tag}"] = mn
            out[f"{tf} Stoch{tag} main−signal"] = None if mn is None or sg is None else mn - sg
        a = self.atr[i]
        out[f"{tf} ATR14 %"] = None if a is None else a / c * 100
        out[f"{tf} thân nến %"] = (c - self.o[i]) / c * 100
        return out


NAN = float("nan")


def matrix(tfs, times):
    """Giá trị mọi đặc trưng tại các thời điểm `times` (nến đã đóng gần nhất của từng khung).
    Trả về {tên đặc trưng: array('d')} thẳng hàng theo `times`; thiếu dữ liệu = NaN."""
    cols = {}
    n = len(times)
    for tfo in tfs:
        names = list(tfo.features(WARMUP).keys())
        tcols = {k: array("d", [NAN]) * n for k in names}
        for j, t in enumerate(times):
            i = tfo.closed_index(t)
            if i < WARMUP:
                continue
            for k, v in tfo.features(i).items():
                if v is not None:
                    tcols[k][j] = v
        cols.update(tcols)
    return cols


def vals(col, idx=None):
    it = col if idx is None else (col[i] for i in idx)
    return [v for v in it if v == v]


def rank(ent_cols, pop_cols, min_n):
    res = []
    for k, col in ent_cols.items():
        a = vals(col)
        b = vals(pop_cols[k])
        if len(a) < min_n or len(b) < 50:
            continue
        res.append((ks(a, b), k, a, b))
    res.sort(key=lambda x: -x[0])
    return res


def best_condition(a, b, cov):
    """Điều kiện 1 phía bao `cov` phần lệnh (a) mà ít nến nền (b) thỏa nhất: (tỉ lệ nền thỏa, chuỗi, hàm kiểm)."""
    hi_t = q(a, cov)
    lo_t = q(a, 1 - cov)
    fr_hi = sum(1 for x in b if x <= hi_t) / len(b)
    fr_lo = sum(1 for x in b if x >= lo_t) / len(b)
    if fr_hi <= fr_lo:
        return fr_hi, f"≤ {hi_t:.4g}", (lambda x, t=hi_t: x == x and x <= t)
    return fr_lo, f"≥ {lo_t:.4g}", (lambda x, t=lo_t: x == x and x >= t)


def greedy_rule(ent_cols, pop_cols, n_ent, n_pop, cov=1.0, steps=4, min_gain=0.9, cand=None):
    """Chọn dần điều kiện: mỗi bước lấy điều kiện còn để lại ít nến nền nhất, giữ ≥ cov lệnh mỗi bước."""
    E = list(range(n_ent))
    P = list(range(n_pop))
    keys = cand or list(ent_cols.keys())
    rule = []
    for _ in range(steps):
        best = None
        for k in keys:
            if any(k == r[0] for r in rule):
                continue
            a = vals(ent_cols[k], E)
            b = vals(pop_cols[k], P)
            if len(a) < max(10, 0.8 * len(E)) or len(b) < 30:
                continue
            fr, txt, fn = best_condition(a, b, cov)
            if best is None or fr < best[0]:
                best = (fr, k, txt, fn)
        if best is None or best[0] > min_gain:
            break
        fr, k, txt, fn = best
        E2 = [i for i in E if fn(ent_cols[k][i])]
        P2 = [i for i in P if fn(pop_cols[k][i])]
        rule.append((k, txt, fr, len(E2) / n_ent, len(P2) / n_pop))
        if len(P2) == len(P):
            rule.pop()
            break
        E, P = E2, P2
        if not P:
            break
    return rule


def tf_scores(ranked):
    by_tf = defaultdict(list)
    for d, k, _, _ in ranked:
        by_tf[k.split(" ")[0]].append(d)
    out = []
    for tf, ds in by_tf.items():
        ds.sort(reverse=True)
        out.append((sum(ds[:5]) / min(5, len(ds)), ds[0], tf))
    out.sort(reverse=True)
    return out


# ---------------------------------------------------------------------------
# Báo cáo
# ---------------------------------------------------------------------------
def write_rule(w, rule, n_pop):
    w("| Bước | Điều kiện | Lệnh còn thỏa (cộng dồn) | Nến nền còn thỏa (cộng dồn) |")
    w("|---|---|---|---|")
    for i, (k, txt, fr, e_left, p_left) in enumerate(rule, 1):
        w(f"| {i} | **{k} {txt}** | {e_left:.0%} | {p_left:.1%} ({round(p_left * n_pop)} / {n_pop}) |")
    w("")


def busy_intervals(rows, side):
    """Khoảng thời gian EA đang có rổ mở ở chiều `side` (không thể vào lệnh đầu mới)."""
    spans = defaultdict(lambda: [None, None])
    for r in rows:
        if r["k_side"] != side:
            continue
        t = int(r["time_msc"]) // 1000
        sp = spans[r["k_basket"]]
        sp[0] = t if sp[0] is None else min(sp[0], t)
        sp[1] = t if sp[1] is None else max(sp[1], t)
    return sorted(tuple(v) for v in spans.values())


def free_times(rng, t0, t1, busy, entries, n, gap_before):
    """Thời điểm ngẫu nhiên khi EA RẢNH (không có rổ cùng chiều) và không sát ngay trước một lệnh.
    Lúc rảnh mà điều kiện thật thỏa thì EA đã vào lệnh, nên điều kiện thật hiếm khi thỏa ở các thời điểm này."""
    starts = [a for a, _ in busy]
    ent = sorted(entries)
    out = []
    tries = 0
    while len(out) < n and tries < n * 50:
        tries += 1
        t = rng.randint(t0, t1)
        k = bisect.bisect_right(starts, t) - 1
        if k >= 0 and busy[k][0] <= t <= busy[k][1]:
            continue
        j = bisect.bisect_left(ent, t)
        if j < len(ent) and ent[j] - t < gap_before:
            continue
        out.append(t)
    return out


def section_scan(rows, m1_path, w, top=15, min_n=15, seed=1, n_pop=2000, cov=1.0, gap_before=1800):
    w("## 8. Quét mọi khung × mọi chỉ báo từ nến M1\n")
    t_start = _time.time()
    m1 = load_m1(m1_path)
    if len(m1[0]) < 1000:
        w(f"File `{os.path.basename(m1_path)}` chỉ có {len(m1[0])} nến M1, quá ít.\n")
        return
    span_days = (m1[0][-1] - m1[0][0]) / 86400
    tfs = [x for x in (TF(n, p, m1) for n, p in TFS) if len(x.t) > WARMUP + 50]
    skipped = [n for n, _ in TFS if n not in {x.name for x in tfs}]

    first = [r for r in rows if r["entry"] == "IN" and r["k_idx"] == "1"]
    rng = random.Random(seed)
    all_t = [int(r["time_msc"]) // 1000 for r in first]
    t0, t1 = min(all_t), max(all_t)
    any_pop = matrix(tfs, [rng.randint(t0, t1) for _ in range(200)])

    w(f"Nến M1: {len(m1[0])} ({span_days:.0f} ngày, file `{os.path.basename(m1_path)}`). "
      f"Khung đủ dữ liệu: {', '.join(x.name for x in tfs)}"
      + (f"; bỏ qua (chưa đủ {WARMUP + 50} nến): {', '.join(skipped)}" if skipped else "") + ". "
      f"Nền chung mỗi chiều: {n_pop} thời điểm ngẫu nhiên lúc EA **rảnh** (không có rổ cùng chiều, không sát "
      f"trước lệnh {gap_before // 60} phút). Số đặc trưng: {len(any_pop)}.\n")

    for side in ("BUY", "SELL"):
        st = [int(r["time_msc"]) // 1000 for r in first if r["k_side"] == side]
        if len(st) < min_n:
            w(f"### {side}: chỉ có {len(st)} lệnh đầu, cần ≥ {min_n}.\n")
            continue
        ent = matrix(tfs, st)
        busy = busy_intervals([r for r in rows if r.get("k_basket")], side)
        pop_t = free_times(rng, t0, t1, busy, st, n_pop, gap_before)
        if len(pop_t) < 200:
            w(f"### {side}: EA gần như lúc nào cũng có lệnh, chỉ lấy được {len(pop_t)} thời điểm rảnh.\n")
            continue
        pop = matrix(tfs, pop_t)
        n_pop_side = len(pop_t)
        # lệnh giả: thời điểm rảnh ngẫu nhiên, cùng số lượng
        fake_t = free_times(rng, t0, t1, busy, st, len(st), gap_before)
        fake = matrix(tfs, fake_t)
        ranked = rank(ent, pop, min_n)
        noise = rank(fake, pop, min_n)
        n_max = noise[0][0] if noise else 0
        cand = [k for _, k, _, _ in ranked[:400]]
        rule = greedy_rule(ent, pop, len(st), n_pop_side, cov=cov, cand=cand)
        fcand = [k for _, k, _, _ in noise[:400]]
        frule = greedy_rule(fake, pop, len(fake_t), n_pop_side, cov=cov, cand=fcand)

        w(f"### {side} ({len(st)} lệnh đầu)\n")
        w(f"**Quy tắc dò được** (mỗi bước giữ ≥ {cov:.0%} lệnh, chọn điều kiện để lại ít thời điểm rảnh nhất):\n")
        write_rule(w, rule, n_pop_side)
        f_left = frule[-1][4] if frule else 1.0
        r_left = rule[-1][4] if rule else 1.0
        w(f"So với nhiễu: cùng thuật toán trên lệnh giả ngẫu nhiên còn {f_left:.1%} nến nền thỏa; "
          f"quy tắc thật còn {r_left:.1%}. "
          + ("→ **khác biệt rõ, quy tắc đáng tin**." if r_left < f_left / 3 else
             "→ **không khác nhiễu bao nhiêu**: EA có thể không lọc theo chỉ báo phổ biến.") + "\n")
        w(f"Mức nhiễu KS (lệnh giả): {n_max:.2f}. Khung nổi bật (TB 5 KS cao nhất): "
          + ", ".join(f"{tf} {avg:.2f}" for avg, _, tf in tf_scores(ranked)[:5]) + "\n")
        w(f"Top {top} đặc trưng riêng lẻ (KS):\n")
        w("| # | Đặc trưng | KS | Lúc vào: p5 / trung vị / p95 | Mọi lúc: p5 / trung vị / p95 | Gợi ý |")
        w("|---|---|---|---|---|---|")
        for i, (d, k, a, b) in enumerate(ranked[:top], 1):
            flag = "" if d > n_max else " (≈ nhiễu)"
            w(f"| {i} | {k} | {d:.2f}{flag} | {f(q(a, .05), 2)} / {f(q(a, .5), 2)} / {f(q(a, .95), 2)} | "
              f"{f(q(b, .05), 2)} / {f(q(b, .5), 2)} / {f(q(b, .95), 2)} | {suggest(a, b)} |")
        w("")
    w(f"Thời gian tính: {_time.time() - t_start:.0f}s.\n")
    w("Cách đọc:")
    w("- **Quy tắc dò được** là kết quả chính. Bước 1 thường là điều kiện \"kích hoạt\" (RSI/CCI/BB quá mua/bán…), "
      "các bước sau là bộ lọc (xu hướng EMA, ADX…). Chỉ báo \"họ hàng\" (cùng đo một thứ) tự bị loại ở bước sau "
      "vì không lọc thêm được.")
    w("- Ngưỡng là giá trị bao hết các lệnh, nên thường **lệch nhẹ ra ngoài** ngưỡng thật (vd thấy ≤ 24.99 khi thật là < 25).")
    w("- \"Nền còn thỏa\" gần 0% nghĩa là: lúc EA rảnh, hầu như không bao giờ quy tắc đúng mà EA lại không vào → quy tắc "
      "giải thích gần trọn hành vi vào lệnh.")
    w("- Bảng KS riêng lẻ cho biết vùng/khung nổi bật; một chỉ báo thật kéo theo cả \"họ\" gần nó.")
    w("- Kết quả là **giả thuyết**: kiểm lại bằng cách viết EA theo quy tắc, chạy backtest và so lệnh với EA gốc.")
    w("")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--m1", required=True, help="file <prefix>_m1_<symbol>.csv")
    ap.add_argument("--deals", required=True, help="file <prefix>_deals.csv")
    ap.add_argument("--magic", type=int)
    ap.add_argument("--symbol")
    ap.add_argument("--top", type=int, default=15)
    ap.add_argument("--out")
    a = ap.parse_args()
    rows = load_deals(a.deals, a.magic, a.symbol)
    lines = []
    if not rows:
        lines.append("Không có deal nào khớp bộ lọc.")
    else:
        section_scan(rows, a.m1, lines.append, top=a.top)
    text = "\n".join(lines)
    print(text)
    if a.out:
        with open(a.out, "w", encoding="utf-8") as fh:
            fh.write(text + "\n")


if __name__ == "__main__":
    main()
