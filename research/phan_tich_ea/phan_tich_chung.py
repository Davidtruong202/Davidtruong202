#!/usr/bin/env python3
"""Phân tích log của TradeLogger_Universal / TradeLogger_TripTrap 3.00 để suy ngược logic một EA bất kỳ.

Chỉ dùng thư viện chuẩn (không cần pandas).

    python3 phan_tich_chung.py triptrap_deals.csv --events triptrap_events_v3.csv --magic 202601 --out bao_cao.md

Các mục của báo cáo:
  0. Tổng quan: số rổ, chiều, độ sâu rổ.
  1. Lệnh đầu: giờ/thứ, giây trong nến (vào lúc mở nến hay giữa nến), chỉ báo lúc vào (cột i_*), spread.
  2. Lưới/DCA: khoảng cách & hệ số lot theo số lệnh đang có; so bước lưới với ATR nếu có cột ATR.
  3. Đóng rổ: giá đóng so với giá trung bình, biên độ có lời tối đa sau lệnh cuối (trailing ảo), lý do đóng.
  4. Đóng khi rổ vẫn còn lệnh (tỉa / đóng một phần).
  5. Lệnh chờ (cần --events): khoảng cách lúc đặt, ngưỡng dời lệnh (refresh), khớp hay huỷ.
Mọi khoảng cách theo đơn vị logger đã chọn (cột k_unit / unit: point hoặc pip).
"""
import argparse
import csv
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


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("deals", help="file <prefix>_deals.csv")
    ap.add_argument("--events", help="file <prefix>_events_v3.csv (để phân tích lệnh chờ)")
    ap.add_argument("--magic", type=int, help="chỉ phân tích magic này")
    ap.add_argument("--symbol", help="chỉ phân tích symbol này")
    ap.add_argument("--out", help="ghi báo cáo Markdown ra file")
    a = ap.parse_args()

    rows = load_deals(a.deals, a.magic, a.symbol)
    lines = []
    w = lines.append
    w(f"# Phân tích log EA — {a.deals}\n")
    if not rows:
        w("Không có deal nào khớp bộ lọc.\n")
    else:
        baskets = section_overview(rows, w)
        section_first(rows, w)
        section_grid(rows, w)
        section_close(baskets, w)
    if a.events:
        section_pending(a.events, a.magic, a.symbol, w)
    text = "\n".join(lines)
    print(text)
    if a.out:
        with open(a.out, "w", encoding="utf-8") as fh:
            fh.write(text + "\n")


if __name__ == "__main__":
    main()
