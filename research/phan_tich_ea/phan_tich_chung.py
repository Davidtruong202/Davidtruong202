#!/usr/bin/env python3
"""Phân tích log của TradeLogger_Universal / TradeLogger_TripTrap 3.00 để suy ngược logic một EA bất kỳ.

Chỉ dùng thư viện chuẩn (không cần pandas).

    python3 phan_tich_chung.py triptrap_deals.csv --events triptrap_events_v3.csv --magic 202601 --out bao_cao.md
    python3 phan_tich_chung.py x_deals.csv --events x_events_v3.csv --ctxbars x_ctxbars_XAUUSD_H1.csv --out bao_cao.md

EA không có file .set (logger để InpIndicators = AUTO): chỉ cần tiền tố file, script tự tìm deals / events_v3 /
ctxbars / auto và phân tích lần lượt từng magic:

    python3 phan_tich_chung.py --prefix "C:/.../MQL5/Files/tradelog" --out bao_cao.md

Các mục của báo cáo:
  0. Tổng quan: số rổ, chiều, độ sâu rổ.
  1. Lệnh đầu: giờ/thứ, giây trong nến (vào lúc mở nến hay giữa nến), chỉ báo lúc vào (cột i_*), spread.
  2. Lưới/DCA: khoảng cách & hệ số lot theo số lệnh đang có; so bước lưới với ATR nếu có cột ATR.
  3. Đóng rổ: giá đóng so với giá trung bình, biên độ có lời tối đa sau lệnh cuối (trailing ảo), lý do đóng.
  4. Đóng khi rổ vẫn còn lệnh (tỉa / đóng một phần).
  5. Lệnh chờ (cần --events): khoảng cách lúc đặt, ngưỡng dời lệnh (refresh), khớp hay huỷ.
  6. Dò khung thời gian EA: thời điểm vào lệnh / đặt lệnh chờ có rơi đúng lúc mở nến M1…D1 không.
  7. Dò chỉ báo EA dùng (cần --ctxbars): so phân bố từng chỉ báo lúc vào lệnh với toàn bộ nến,
     xếp hạng cột tách biệt nhất (KS) và gợi ý ngưỡng. Dùng khi KHÔNG có file .set (tài khoản Passview).
Mọi khoảng cách theo đơn vị logger đã chọn (cột k_unit / unit: point hoặc pip).
"""
import argparse
import csv
import glob
import os
import sys
from collections import Counter, defaultdict


def num(v):
    try:
        return float(v) if v not in ("", None) else None
    except ValueError:
        return None


def clean(vals):
    return sorted(v for v in vals if v is not None)


def q(vals, p):
    vals = clean(vals)
    if not vals:
        return None
    k = (len(vals) - 1) * p
    a = int(k)
    b = min(a + 1, len(vals) - 1)
    return vals[a] + (vals[b] - vals[a]) * (k - a)


def lo(vals):
    vals = clean(vals)
    return vals[0] if vals else None


def hi(vals):
    vals = clean(vals)
    return vals[-1] if vals else None


def f(v, d=1):
    return "—" if v is None else f"{v:.{d}f}"


def dist_row(vals, d=1):
    return f"{f(lo(vals), d)} / {f(q(vals, .25), d)} / {f(q(vals, .5), d)} / {f(q(vals, .75), d)} / {f(hi(vals), d)}"


def read_csv(path):
    with open(path, encoding="utf-8-sig", newline="") as fh:
        return list(csv.DictReader(fh))


def load_deals(path, magic, symbol):
    rows = read_csv(path)
    if rows and "k_dist_last" not in rows[0]:
        sys.exit("File deals không có cột k_dist_last: cần log của TradeLogger_Universal/TripTrap 3.00.")
    out = [r for r in rows
           if (magic is None or r.get("magic") == str(magic))
           and (not symbol or r.get("symbol") == symbol)
           and r.get("k_basket") not in ("", "-1", None)]
    out.sort(key=lambda r: int(r["time_msc"]))
    return out


def unit_name(rows):
    u = Counter(r.get("k_unit") for r in rows).most_common(1)
    return f"đơn vị = {u[0][0]} giá" if u else ""


def section_overview(rows, w):
    baskets = defaultdict(list)
    for r in rows:
        baskets[r["k_basket"]].append(r)
    depth = Counter(max(int(r["k_idx"]) for r in b) for b in baskets.values())
    sides = Counter(b[0]["k_side"] for b in baskets.values())
    w("## 0. Tổng quan\n")
    w(f"- Số deal: {len(rows)}; số rổ: {len(baskets)} ({', '.join(f'{k} {v}' for k, v in sorted(sides.items()))}); {unit_name(rows)}")
    w("- Số rổ theo độ sâu (số lệnh tối đa): " + ", ".join(f"{k}: {v}" for k, v in sorted(depth.items())))
    # rổ BUY và SELL có chạy cùng lúc không (EA 2 chiều / hedge)?
    spans = defaultdict(list)
    for b in baskets.values():
        spans[b[0]["k_side"]].append((int(b[0]["time_msc"]), int(b[-1]["time_msc"])))
    overlap = 0
    for s1, e1 in spans.get("BUY", []):
        if any(s2 < e1 and s1 < e2 for s2, e2 in spans.get("SELL", [])):
            overlap += 1
    w(f"- Rổ BUY có lúc chạy song song với rổ SELL: {overlap}/{len(spans.get('BUY', []))} "
      "(nhiều → EA đánh 2 chiều cùng lúc)")
    w("")
    return baskets


def ind_columns(rows):
    if not rows:
        return []
    return [c for c in rows[0].keys() if c.startswith("i_")]


def section_first(rows, w):
    ins = [r for r in rows if r["entry"] == "IN" and r["k_idx"] == "1"]
    w("## 1. Lệnh đầu của rổ\n")
    if not ins:
        w("Không có.\n")
        return
    n = len(ins)
    sec = [num(r.get("c_sec_in_bar")) for r in ins]
    w(f"Số lệnh đầu: {n}. Cột phân vị: min / p25 / trung vị / p75 / max.\n")
    w("| Đại lượng | Phân vị | Ghi chú |")
    w("|---|---|---|")
    w(f"| Giây kể từ lúc mở nến khung EA | {dist_row(sec)} | tỉ lệ < 10s: {sum(1 for s in sec if s is not None and s < 10)}/{n} — cao → EA chỉ ra quyết định khi mở nến |")
    spread = [num(r.get("live_spread_pts")) for r in ins]
    if any(v is not None for v in spread):
        w(f"| Spread lúc vào (point, chỉ deal ghi trực tiếp) | {dist_row(spread, 0)} | max ≈ ngưỡng spread tối đa của EA nếu có |")
    for c in ind_columns(rows):
        vals = [num(r.get(c)) for r in ins]
        if all(v is None for v in vals):
            continue
        # với cột _dist: đổi dấu theo chiều lệnh để BUY/SELL cùng thang
        if c.endswith("_dist"):
            vals = [None if v is None else v * (1 if r["k_side"] == "BUY" else -1) for v, r in zip(vals, ins)]
            note = "đã đổi dấu theo chiều lệnh: dương = giá nằm phía có lợi cho lệnh"
        else:
            note = ""
        w(f"| {c} | {dist_row(vals, 2)} | {note} |")
    w("")
    hours = Counter(int(r["c_hour"]) for r in ins if r.get("c_hour") not in ("", None))
    w("Giờ server của lệnh đầu: " + ", ".join(f"{h:02d}h:{hours[h]}" for h in sorted(hours)))
    missing = [h for h in range(24) if h not in hours]
    if missing and n >= 50:
        w(f"\nKhông có lệnh đầu lúc: {', '.join(f'{h:02d}h' for h in missing)} → có thể EA giới hạn phiên.")
    days = Counter(int(r["c_weekday"]) for r in ins if r.get("c_weekday") not in ("", None))
    w("\nThứ (0 = CN): " + ", ".join(f"{d}:{days[d]}" for d in sorted(days)))
    w("")


def section_grid(rows, w):
    adds = [r for r in rows if r["entry"] == "IN" and int(r["k_idx"]) >= 2]
    w("## 2. Lệnh thêm vào rổ (lưới / DCA)\n")
    if not adds:
        w("Không có — EA chỉ vào 1 lệnh mỗi rổ.\n")
        return
    atr_col = next((c for c in ind_columns(rows) if c.startswith("i_ATR") and c.endswith("_u")), None)
    # lot lệnh đầu của từng rổ, để ước lượng hệ số nhân ít bị làm tròn: (lot_n / lot_1) ^ (1 / (n - 1))
    first_lot = {r["k_basket"]: num(r["volume"]) for r in rows if r["entry"] == "IN" and r["k_idx"] == "1"}
    w("| Lệnh đang có | Số lần | Cách lệnh trước: min / trung vị / max | Hệ số lot trung vị (min–max) | Hệ số ước lượng từ lot đầu | Lot | "
      + ("Bước / ATR trung vị (min–max) | " if atr_col else "") + "Giây trong nến (trung vị) |")
    w("|---|---|---|---|---|---|" + ("---|" if atr_col else "") + "---|")
    groups = defaultdict(list)
    for r in adds:
        groups[int(r["k_count_before"])].append(r)
    all_ratio = []
    all_geo = {}
    for n in sorted(groups):
        g = groups[n]
        d = [num(r["k_dist_last"]) for r in g]
        lr = [num(r["k_lot_ratio"]) for r in g]
        all_ratio += lr
        lots = sorted(set(r["volume"] for r in g), key=float)
        geo = [(num(r["volume"]) / first_lot[r["k_basket"]]) ** (1.0 / n) for r in g
               if first_lot.get(r["k_basket"]) and num(r["volume"])]
        all_geo[n] = q(geo, .5)
        row = (f"| {n} | {len(g)} | {f(lo(d))} / {f(q(d, .5))} / {f(hi(d))} | "
               f"{f(q(lr, .5), 3)} ({f(lo(lr), 3)}–{f(hi(lr), 3)}) | {f(q(geo, .5), 3)} | "
               f"{', '.join(lots[:5])}{'…' if len(lots) > 5 else ''} | ")
        if atr_col:
            ra = [num(r["k_dist_last"]) / num(r[atr_col]) for r in g
                  if num(r["k_dist_last"]) is not None and num(r[atr_col])]
            row += f"{f(q(ra, .5), 2)} ({f(lo(ra), 2)}–{f(hi(ra), 2)}) | "
        row += f"{f(q([num(r.get('c_sec_in_bar')) for r in g], .5))} |"
        w(row)
    w("")
    w("Cách đọc:")
    w("- Khoảng cách **min** gần như bằng nhau ở mọi bậc → bước lưới cố định (= giá trị đó). "
      "Nếu cột Bước/ATR ổn định còn khoảng cách thay đổi → bước lưới theo ATR (hệ số = Bước/ATR).")
    deep = max(all_geo) if all_geo else None
    w(f"- Hệ số lot giữa 2 lệnh liền nhau (trung vị): {f(q(all_ratio, .5), 3)} — bị nhiễu khi lot nhỏ vì làm tròn 0.01.")
    w(f"- Hệ số ước lượng từ lot đầu ở bậc sâu nhất ({deep} lệnh đang có): {f(all_geo.get(deep), 3)} — đáng tin hơn khi rổ càng sâu.")
    w("")


def section_close(baskets, w):
    w("## 3. Đóng rổ\n")
    closes, reasons, peaks, gaps, ages = [], Counter(), [], [], []
    early_rows = []
    for b in baskets.values():
        outs = [r for r in b if r["entry"] in ("OUT", "OUT_BY")]
        if not outs:
            continue
        final = [r for r in outs if r["k_count_after"] == "0"]
        if not final:
            early_rows += outs
            continue
        end_t = int(final[-1]["time_msc"])
        burst = [r for r in outs if end_t - int(r["time_msc"]) <= 5000]
        early_rows += [r for r in outs if end_t - int(r["time_msc"]) > 5000]
        first = burst[0]
        c = num(first["k_dist_avg"])
        p = num(first["k_peak_after_last"])
        closes.append(c)
        reasons[first["reason"]] += 1
        ages.append(num(first["k_basket_age_sec"]))
        if p is not None:
            peaks.append(p)
            if c is not None:
                gaps.append(p - c)
    w(f"Số rổ đã đóng hết: {len(closes)}. Phân vị min / p25 / trung vị / p75 / max.\n")
    w("| Đại lượng | Phân vị | Cách đọc |")
    w("|---|---|---|")
    w(f"| Giá đóng so với giá trung bình (dương = lãi) | {dist_row(closes)} | tập trung quanh 1 giá trị → TP cố định tính từ giá trung bình |")
    w(f"| Có lời tối đa sau lệnh cuối | {dist_row(peaks)} | min ≈ ngưỡng bắt đầu trailing (nếu đóng bằng trailing) |")
    w(f"| Có lời tối đa − giá đóng | {dist_row(gaps)} | ổn định → trailing ảo, bước trailing ≈ giá trị này (xấp xỉ theo nến M1) |")
    w(f"| Tuổi rổ (giờ) | {dist_row([None if a is None else a / 3600 for a in ages], 2)} | |")
    w("")
    w("Lý do của deal đóng đầu tiên: " + ", ".join(f"{k}: {v}" for k, v in reasons.most_common()))
    w("- DEAL_REASON_TP / SL: TP/SL đặt trên server. DEAL_REASON_EXPERT: EA tự đóng (TP ảo, trailing ảo, cắt lỗ theo tiền...).")
    w("")
    w("## 4. Đóng lệnh khi rổ vẫn còn lệnh (tỉa / đóng một phần)\n")
    if not early_rows:
        w("Không có.\n")
        return
    w("| Thời gian | Chiều | Lệnh thứ | Đang có | Còn lại | Lot | Khoảng cách của lệnh | Lãi | Lý do |")
    w("|---|---|---|---|---|---|---|---|---|")
    for r in early_rows[:150]:
        w(f"| {r['time']} | {r['k_side']} | {r['k_idx']} | {r['k_count_before']} | {r['k_count_after']} | "
          f"{r['volume']} | {r['k_pos_dist']} | {r['profit']} | {r['reason']} |")
    if len(early_rows) > 150:
        w(f"\n… còn {len(early_rows) - 150} dòng.")
    w("")


def section_pending(path, magic, symbol, w):
    w("## 5. Lệnh chờ\n")
    ev = [r for r in read_csv(path)
          if r.get("kind") == "ORDER"
          and (magic is None or r.get("magic") == str(magic))
          and (not symbol or r.get("symbol") == symbol)]
    if not ev:
        w("Không có sự kiện lệnh chờ.\n")
        return
    types = Counter(r["type"] for r in ev if r["event"] in ("NEW", "EXISTING"))
    w("Loại lệnh chờ được đặt: " + ", ".join(f"{k}: {v}" for k, v in types.most_common()) + "\n")
    w("| Sự kiện | Số lần | Khoảng cách tới giá: min / p25 / trung vị / p75 / max | Cách đọc |")
    w("|---|---|---|---|")
    new = [r for r in ev if r["event"] == "NEW"]
    w(f"| Đặt mới (NEW) | {len(new)} | {dist_row([num(r['dist']) for r in new])} | ≈ khoảng cách đặt lệnh chờ |")
    mod = [r for r in ev if r["event"] == "MODIFY" and r.get("prev_price")]
    w(f"| Dời giá (MODIFY): lệnh cũ cách giá | {len(mod)} | {dist_row([num(r['prev_dist']) for r in mod])} | min ≈ ngưỡng refresh: giá chạy xa hơn mức này thì EA dời lệnh |")
    w(f"| Dời giá (MODIFY): lệnh mới cách giá | {len(mod)} | {dist_row([num(r['dist']) for r in mod])} | ≈ khoảng cách đặt lệnh chờ |")
    for k in ("FILLED", "CANCELED", "EXPIRED", "REJECTED", "GONE"):
        g = [r for r in ev if r["event"] == k]
        if g:
            w(f"| {k} | {len(g)} | {dist_row([num(r['dist']) for r in g])} | |")
    w("")
    spreads = [num(r.get("spread_pts")) for r in new]
    if any(v is not None for v in spreads):
        w(f"Spread lúc đặt lệnh chờ (point): {dist_row(spreads, 0)}\n")

# ---------------------------------------------------------------------------
# 6. Dò khung thời gian
# ---------------------------------------------------------------------------
TFS = [("M1", 60), ("M5", 300), ("M15", 900), ("M30", 1800), ("H1", 3600), ("H4", 14400), ("D1", 86400)]
ALIGN_WINDOW = 10  # giây: lệnh trong 10s đầu của nến được coi là "vào lúc mở nến"


def tf_alignment(times_msc):
    """Với mỗi khung: tỉ lệ thời điểm rơi vào ALIGN_WINDOW giây đầu nến, so với tỉ lệ nếu ngẫu nhiên.
    Thời gian MT5 là giờ server tính từ epoch, nên nến M1…D1 bắt đầu đúng tại bội số của độ dài nến."""
    out = []
    n = len(times_msc)
    for name, per in TFS:
        hit = sum(1 for t in times_msc if (t / 1000.0) % per < ALIGN_WINDOW)
        share = hit / n if n else 0
        expect = ALIGN_WINDOW / per
        out.append((name, per, hit, share, expect))
    return out


def tf_verdict(res):
    # khung lớn nhất mà phần lớn lệnh vẫn rơi đúng lúc mở nến (vào đúng mở nến H1 thì cũng đúng mở nến M1/M5/M15)
    best = None
    for name, per, hit, share, expect in res:
        if share >= 0.7 and share > 3 * expect:
            best = name
    return best


def write_tf_table(title, times, w):
    if len(times) < 10:
        w(f"{title}: chỉ có {len(times)} mốc, cần ≥ 10 để kết luận.\n")
        return None
    res = tf_alignment(times)
    w(f"{title} ({len(times)} mốc):\n")
    w(f"| Khung | Rơi vào {ALIGN_WINDOW}s đầu nến | Nếu ngẫu nhiên | Gấp |")
    w("|---|---|---|---|")
    for name, per, hit, share, expect in res:
        w(f"| {name} | {hit} ({share:.0%}) | {expect:.1%} | {share / expect:.1f}× |")
    v = tf_verdict(res)
    w("")
    if v:
        w(f"**→ EA ra quyết định khi mở nến {v}** (khung lớn nhất mà ≥ 70% mốc rơi vào {ALIGN_WINDOW}s đầu nến). "
          f"Đặt `InpEntryTF = {v}` cho logger nếu chưa đúng.\n")
    else:
        w("**→ Không khớp lúc mở nến khung nào**: EA chạy theo tick (vào lệnh giữa nến, khi giá chạm điều kiện), "
          "hoặc vào bằng lệnh chờ được khớp (khi đó xem bảng thời điểm đặt lệnh chờ).\n")
    return v


def section_timeframe(rows, events_path, magic, symbol, w):
    w("## 6. Dò khung thời gian EA\n")
    # lệnh khớp từ lệnh chờ: giờ khớp do giá quyết định, nên xem thêm bảng "đặt / dời lệnh chờ" bên dưới
    first = [int(r["time_msc"]) for r in rows if r["entry"] == "IN" and r["k_idx"] == "1"]
    verdict = write_tf_table("Thời điểm lệnh đầu của rổ", first, w)
    adds = [int(r["time_msc"]) for r in rows if r["entry"] == "IN" and int(r["k_idx"]) >= 2]
    if adds:
        write_tf_table("Thời điểm lệnh thêm vào rổ (lưới/DCA)", adds, w)
    if events_path:
        ev = [r for r in read_csv(events_path)
              if r.get("kind") == "ORDER" and r.get("event") in ("NEW", "MODIFY")
              and (magic is None or r.get("magic") == str(magic))
              and (not symbol or r.get("symbol") == symbol) and r.get("time_msc")]
        if ev:
            v2 = write_tf_table("Thời điểm đặt / dời lệnh chờ", [int(r["time_msc"]) for r in ev], w)
            verdict = verdict or v2
    return verdict


# ---------------------------------------------------------------------------
# 7. Dò chỉ báo
# ---------------------------------------------------------------------------
def ks(a, b):
    """Thống kê Kolmogorov–Smirnov 2 mẫu: 0 = cùng phân bố, 1 = tách hẳn."""
    a, b = sorted(a), sorted(b)
    i = j = 0
    d = 0.0
    while i < len(a) and j < len(b):
        x = min(a[i], b[j])
        while i < len(a) and a[i] <= x:
            i += 1
        while j < len(b) and b[j] <= x:
            j += 1
        d = max(d, abs(i / len(a) - j / len(b)))
    return d


def add_derived(row, cols):
    """Thêm cột hiệu số: EMA/SMA nhanh − chậm cùng khung, ADX +DI − −DI, MACD/Stoch main − signal."""
    out = {}
    mas = defaultdict(list)
    for c in cols:
        p = c.split("_")  # i_EMA_H1_20
        if len(p) == 4 and p[1] in ("EMA", "SMA"):
            try:
                mas[p[2]].append((float(p[3]), c))
            except ValueError:
                pass
    for tf, lst in mas.items():
        lst.sort()
        for x in range(len(lst)):
            for y in range(x + 1, len(lst)):
                a, b = num(row.get(lst[x][1])), num(row.get(lst[y][1]))
                out[f"d_{lst[x][1][2:]}-{lst[y][1][2:]}"] = None if None in (a, b) else a - b
    for c in cols:
        if c.endswith("_pdi"):
            base = c[:-4]
            a, b = num(row.get(c)), num(row.get(base + "_mdi"))
            out[f"d_{base[2:]}_pdi-mdi"] = None if None in (a, b) else a - b
        if c.endswith("_main"):
            base = c[:-5]
            a, b = num(row.get(c)), num(row.get(base + "_sig"))
            out[f"d_{base[2:]}_main-sig"] = None if None in (a, b) else a - b
    return out


def feature_table(rows, cols):
    tab = []
    for r in rows:
        v = {c: num(r.get(c)) for c in cols}
        v.update(add_derived(r, cols))
        tab.append(v)
    return tab


def suggest(ent, pop):
    """Gợi ý điều kiện: (1) lệnh hầu như cùng dấu trong khi nền chung chia đôi — kiểu "EMA nhanh > chậm";
    (2) lệnh chỉ nằm ở một phía của phân bố chung — kiểu "RSI ≤ 30"."""
    parts = []
    pos = sum(1 for x in ent if x > 0) / len(ent)
    pop_pos = sum(1 for x in pop if x > 0) / len(pop)
    if max(pos, 1 - pos) >= 0.9 and 0.2 <= pop_pos <= 0.8:
        parts.append(f"**> 0** ở {pos:.0%} lệnh (nền chung {pop_pos:.0%})" if pos > 0.5
                     else f"**< 0** ở {1 - pos:.0%} lệnh (nền chung {1 - pop_pos:.0%})")
    e_lo, e_hi = q(ent, .05), q(ent, .95)
    if e_hi is not None and e_hi < q(pop, .75) and hi(ent) < q(pop, .9):
        parts.append(f"≤ {hi(ent):.4g}")
    if e_lo is not None and e_lo > q(pop, .25) and lo(ent) > q(pop, .1):
        parts.append(f"≥ {lo(ent):.4g}")
    return "; ".join(parts) if parts else "—"


def pick_ctx(ctx_paths, symbol, tf):
    """Chọn 1 file ctxbars (không trộn nhiều khung): đúng symbol, ưu tiên khung đoán được, rồi H1."""
    cands = [p for p in ctx_paths if not symbol or f"_ctxbars_{symbol}_" in os.path.basename(p)] or list(ctx_paths)
    for want in (tf, "H1"):
        if want:
            m = [p for p in cands if os.path.basename(p).endswith(f"_{want}.csv")]
            if m:
                return m[0]
    return cands[0] if cands else None


def section_discover(rows, ctx_paths, w, tf=None, top=12):
    w("## 7. Dò chỉ báo EA dùng (lệnh đầu so với toàn bộ nến)\n")
    symbol = Counter(r["symbol"] for r in rows).most_common(1)[0][0]
    path = pick_ctx(ctx_paths, symbol, tf)
    if not path:
        w("Không có file ctxbars.\n")
        return
    w(f"File nền chung: `{os.path.basename(path)}`" + (f" (khớp khung đoán được {tf})" if tf and path.endswith(f"_{tf}.csv") else "") + "\n")
    bars = [b for b in read_csv(path) if b.get("symbol", symbol) == symbol]
    ctx_paths = [path]
    cols = [c for c in ind_columns(rows) if bars and c in bars[0]]
    if not cols:
        w("File ctxbars không có cột i_* trùng với file deals (cần cùng chuỗi InpIndicators).\n")
        return
    pop = feature_table(bars, cols)
    w(f"Nền chung: {len(bars)} nến từ {len(ctx_paths)} file ctxbars. Cột KS: 0 = lúc vào lệnh giống mọi lúc khác "
      "(chỉ báo không liên quan), càng gần 1 càng tách biệt (EA nhiều khả năng lọc theo chỉ báo này). "
      "Cột `d_*` là hiệu số tự tạo (EMA nhanh − chậm, +DI − −DI, MACD/Stoch main − signal).\n")
    for side in ("BUY", "SELL"):
        ent_rows = [r for r in rows if r["entry"] == "IN" and r["k_idx"] == "1" and r["k_side"] == side]
        if len(ent_rows) < 15:
            w(f"### {side}: chỉ có {len(ent_rows)} lệnh đầu, cần ≥ 15 để dò.\n")
            continue
        ent = feature_table(ent_rows, cols)
        ranked = []
        for c in ent[0].keys():
            a = [x[c] for x in ent if x.get(c) is not None]
            b = [x[c] for x in pop if x.get(c) is not None]
            if len(a) < 15 or len(b) < 50:
                continue
            ranked.append((ks(a, b), c, a, b))
        ranked.sort(reverse=True)
        w(f"### {side} ({len(ent_rows)} lệnh đầu)\n")
        w("| # | Cột | KS | Lúc vào: p5 / trung vị / p95 | Mọi nến: p5 / trung vị / p95 | Gợi ý điều kiện |")
        w("|---|---|---|---|---|---|")
        for i, (d, c, a, b) in enumerate(ranked[:top], 1):
            w(f"| {i} | `{c}` | {d:.2f} | {f(q(a, .05), 2)} / {f(q(a, .5), 2)} / {f(q(a, .95), 2)} | "
              f"{f(q(b, .05), 2)} / {f(q(b, .5), 2)} / {f(q(b, .95), 2)} | {suggest(a, b)} |")
        w("")
    w("Cách đọc:")
    w("- KS ≥ 0.5 và gợi ý rõ ràng (ví dụ `≤ 30` cho RSI BUY) → gần như chắc EA dùng điều kiện đó.")
    w("- Nhiều cột cùng khung, cùng loại (EMA20, EMA50 H1) cùng cao → thường chỉ 1 điều kiện gốc (ví dụ EMA nhanh > chậm).")
    w("- Mọi cột KS < 0.2 → EA không lọc theo các chỉ báo đã ghi: thử bộ chỉ báo/khung khác, hoặc EA vào lệnh theo "
      "giờ/giá thuần (lưới, lệnh chờ quanh giá).")
    w("- Cần ≥ 30 lệnh đầu mỗi chiều để tin được; KS cao với ít lệnh có thể là ngẫu nhiên.")
    w("")


def find_files(prefix):
    """Từ tiền tố file logger (vd .../MQL5/Files/tradelog) tìm deals, events_v3, ctxbars, auto."""
    deals = prefix + "_deals.csv"
    events = prefix + "_events_v3.csv"
    ctx = sorted(glob.glob(glob.escape(prefix) + "_ctxbars_*.csv"))
    auto = prefix + "_auto.csv"
    return (deals if os.path.exists(deals) else None, events if os.path.exists(events) else None, ctx,
            auto if os.path.exists(auto) else None)


def section_auto(path, w):
    w("## Magic có trong tài khoản (file auto của logger)\n")
    rows = read_csv(path)
    w("| Magic | Symbol | Rổ | BUY / SELL | Lệnh thêm | Khung đoán (lệnh đầu) | Comment |")
    w("|---|---|---|---|---|---|---|")
    for r in sorted(rows, key=lambda r: -int(r["first_entries"] or 0)):
        w(f"| {r['magic']} | {r['symbol']} | {r['first_entries']} | {r['buy_first']} / {r['sell_first']} | "
          f"{r['adds']} | {r['tf_guess_first']} | {r['comment_sample']} |")
    w("\nTICK = không khớp lúc mở nến khung nào (EA chạy theo tick hoặc lệnh chờ); ? = chưa đủ 10 rổ.\n")


def report_one(rows, a, events, ctx, w):
    baskets = section_overview(rows, w)
    section_first(rows, w)
    section_grid(rows, w)
    section_close(baskets, w)
    magic = int(rows[0]["magic"]) if a.magic is None else a.magic
    if events:
        section_pending(events, magic, a.symbol, w)
    tf = section_timeframe(rows, events, magic, a.symbol, w)
    if ctx:
        section_discover(rows, ctx, w, tf)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("deals", nargs="?", help="file <prefix>_deals.csv (bỏ trống nếu dùng --prefix)")
    ap.add_argument("--prefix", help="tiền tố file logger, vd C:/.../MQL5/Files/tradelog: tự tìm mọi file")
    ap.add_argument("--events", help="file <prefix>_events_v3.csv (để phân tích lệnh chờ)")
    ap.add_argument("--magic", type=int, help="chỉ phân tích magic này (bỏ trống = lần lượt từng magic)")
    ap.add_argument("--symbol", help="chỉ phân tích symbol này")
    ap.add_argument("--ctxbars", nargs="*", default=[], help="file <prefix>_ctxbars_<symbol>_<TF>.csv (để dò chỉ báo)")
    ap.add_argument("--min-deals", type=int, default=20, help="bỏ qua magic có ít deal hơn (mặc định 20)")
    ap.add_argument("--out", help="ghi báo cáo Markdown ra file")
    a = ap.parse_args()

    auto = None
    deals, events, ctx = a.deals, a.events, list(a.ctxbars)
    if a.prefix:
        d2, e2, c2, auto = find_files(a.prefix)
        deals = deals or d2
        events = events or e2
        ctx = ctx or c2
    if not deals:
        ap.error("cần file deals hoặc --prefix trỏ tới nơi có <prefix>_deals.csv")

    lines = []
    w = lines.append
    w(f"# Phân tích log EA — {deals}\n")
    if auto:
        section_auto(auto, w)

    rows = load_deals(deals, a.magic, a.symbol)
    if not rows:
        w("Không có deal nào khớp bộ lọc.\n")
    elif a.magic is not None:
        report_one(rows, a, events, ctx, w)
    else:
        by_magic = defaultdict(list)
        for r in rows:
            by_magic[r["magic"]].append(r)
        order = sorted(by_magic, key=lambda m: -len(by_magic[m]))
        skipped = [m for m in order if len(by_magic[m]) < a.min_deals]
        for m in order:
            if len(by_magic[m]) < a.min_deals:
                continue
            w(f"\n---\n\n# Magic {m} ({len(by_magic[m])} deal)\n")
            report_one(by_magic[m], a, events, ctx, w)
        if skipped:
            w(f"\nBỏ qua magic ít hơn {a.min_deals} deal: {', '.join(skipped)}\n")
    text = "\n".join(lines)
    print(text)
    if a.out:
        with open(a.out, "w", encoding="utf-8") as fh:
            fh.write(text + "\n")


if __name__ == "__main__":
    main()
