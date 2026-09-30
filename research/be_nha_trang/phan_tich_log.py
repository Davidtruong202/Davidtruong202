#!/usr/bin/env python3
"""Phân tích file deals do TradeLogger 2.00 xuất ra để suy ngược logic bot DCA.

Chỉ dùng thư viện chuẩn (không cần pandas).

    python3 phan_tich_log.py tradelog_deals.csv --magic 967488838 --symbol XAUUSDc

In báo cáo Markdown ra màn hình, và ghi thêm vào --out nếu có.
Mỗi mục trả lời một giả định trong docs/be_nha_trang/README.md:
  1. Lệnh đầu: ngưỡng A% (độ tách EMA) và B% (giá cách EMA), EMA phụ, vào lệnh lúc nào trong nến.
  2. DCA: khoảng cách và hệ số lot theo số lệnh đang có; DCA theo nến đóng hay giá tức thời.
  3. Giảm lot theo giờ: lot lệnh đầu theo giờ server.
  4. Đóng rổ: TP bao nhiêu pip so với giá trung bình, đóng bởi TP server hay EA.
  5. Tỉa lệnh: các lần đóng lệnh khi rổ vẫn còn lệnh.
"""
import argparse
import csv
import statistics
import sys
from collections import defaultdict


def num(v):
    try:
        return float(v) if v not in ("", None) else None
    except ValueError:
        return None


def q(vals, p):
    vals = sorted(v for v in vals if v is not None)
    if not vals:
        return None
    k = (len(vals) - 1) * p
    lo = int(k)
    hi = min(lo + 1, len(vals) - 1)
    return vals[lo] + (vals[hi] - vals[lo]) * (k - lo)


def lo(vals):
    vals = [v for v in vals if v is not None]
    return min(vals) if vals else None


def hi(vals):
    vals = [v for v in vals if v is not None]
    return max(vals) if vals else None


def f(v, d=2):
    return "—" if v is None else f"{v:.{d}f}"


def load(path, magic, symbol):
    with open(path, encoding="utf-8-sig", newline="") as fh:
        rows = list(csv.DictReader(fh))
    if rows and "k_basket" not in rows[0]:
        sys.exit("File không có cột k_basket: cần file deals của TradeLogger 2.00 trở lên.")
    out = []
    for r in rows:
        if magic is not None and r.get("magic") != str(magic):
            continue
        if symbol and r.get("symbol") != symbol:
            continue
        if r.get("k_basket") in ("", "-1", None):
            continue
        out.append(r)
    out.sort(key=lambda r: int(r["time_msc"]))
    return out


def side_dir(r):
    return 1 if r["k_side"] == "BUY" else -1


def section_overview(rows, w):
    baskets = defaultdict(list)
    for r in rows:
        baskets[r["k_basket"]].append(r)
    depth = defaultdict(int)
    for b in baskets.values():
        depth[max(int(r["k_idx"]) for r in b)] += 1
    w("## 0. Tổng quan\n")
    w(f"- Số deal: {len(rows)}; số rổ: {len(baskets)} "
      f"(BUY {sum(1 for b in baskets.values() if b[0]['k_side'] == 'BUY')}, "
      f"SELL {sum(1 for b in baskets.values() if b[0]['k_side'] == 'SELL')})")
    w("- Rổ theo số lệnh tối đa: " + ", ".join(f"{k} lệnh: {v}" for k, v in sorted(depth.items())))
    w("")
    return baskets


def section_first(rows, w):
    ins = [r for r in rows if r["entry"] == "IN" and r["k_idx"] == "1"]
    w("## 1. Lệnh đầu (k_idx = 1)\n")
    if not ins:
        w("Không có lệnh đầu.\n")
        return
    gap = [num(r["b_ema_gap_pct"]) * side_dir(r) for r in ins if num(r["b_ema_gap_pct"]) is not None]
    dist = [num(r["b_px_dist_fast_pct"]) * side_dir(r) for r in ins if num(r["b_px_dist_fast_pct"]) is not None]
    agree = lambda col: sum(1 for r in ins if r[col] not in ("", "0") and int(r[col]) == side_dir(r))
    n = len(ins)
    w(f"Số lệnh đầu: {n}\n")
    w("| Kiểm tra | Kết quả | Ý nghĩa |")
    w("|---|---|---|")
    w(f"| EMA chính cùng chiều lệnh | {agree('b_ema_dir')}/{n} | = {n}/{n} thì bộ lọc EMA chính đúng là lọc chiều |")
    w(f"| Lọc phụ 1 cùng chiều | {agree('b_f1_dir')}/{n} | |")
    w(f"| Lọc phụ 2 cùng chiều | {agree('b_f2_dir')}/{n} | |")
    w(f"| Độ tách EMA theo chiều lệnh (%) min / p5 / trung vị | {f(lo(gap), 4)} / {f(q(gap, .05), 4)} / {f(q(gap, .5), 4)} | min ≈ ngưỡng A% (bot gốc đặt 0.1) |")
    w(f"| Giá cách EMA nhanh theo chiều lệnh (%) min / trung vị / max | {f(lo(dist), 4)} / {f(q(dist, .5), 4)} / {f(hi(dist), 4)} | max ≈ ngưỡng B% (0.35); dấu cho biết mua trên hay dưới EMA |")
    sec = [num(r["b_sec_in_ema_bar"]) for r in ins]
    sec = [s for s in sec if s is not None]
    if sec:
        w(f"| Giây kể từ đầu nến EMA: trung vị / tỉ lệ < 10s | {f(q(sec, .5), 1)} / {sum(1 for s in sec if s < 10)}/{len(sec)} | tỉ lệ cao → bot chỉ vào lệnh lúc mở nến mới |")
    w("")

    by_hour = defaultdict(list)
    for r in ins:
        if r["b_hour"] != "":
            by_hour[int(r["b_hour"])].append(float(r["volume"]))
    w("### Lot lệnh đầu theo giờ server (kiểm tra giảm lot)\n")
    w("| Giờ | Số lệnh | Lot (các giá trị) |")
    w("|---|---|---|")
    for h in sorted(by_hour):
        vals = sorted(set(by_hour[h]))
        w(f"| {h:02d} | {len(by_hour[h])} | {', '.join(f'{v:.2f}' for v in vals)} |")
    w("")


def section_dca(rows, w):
    dca = [r for r in rows if r["entry"] == "IN" and int(r["k_idx"]) >= 2]
    w("## 2. DCA (k_idx ≥ 2), nhóm theo số lệnh đang có\n")
    if not dca:
        w("Không có lệnh DCA.\n")
        return
    w("| Lệnh đang có | Số lần | Khoảng cách tới lệnh trước (pip) min / trung vị / max | Hệ số lot trung vị (min–max) | Lot | Giây trong nến DCA (trung vị) | Nến DCA đã đóng vượt khoảng cách |")
    w("|---|---|---|---|---|---|---|")
    groups = defaultdict(list)
    for r in dca:
        groups[int(r["k_count_before"])].append(r)
    for n in sorted(groups):
        g = groups[n]
        d = [num(r["k_dist_last_pips"]) for r in g]
        lr = [num(r["k_lot_ratio"]) for r in g]
        lots = sorted(set(r["volume"] for r in g))
        sec = [num(r["b_sec_in_dca_bar"]) for r in g]
        dmin = lo(d)
        # nến DCA vừa đóng đã vượt khoảng cách nhỏ nhất quan sát được ở bậc này chưa?
        beyond = 0
        checked = 0
        for r in g:
            c, last, pip = num(r["b_dca_c"]), num(r["k_last_price"]), num(r["k_pip"])
            if None in (c, last, pip) or dmin is None:
                continue
            checked += 1
            if side_dir(r) * (last - c) / pip >= dmin - 1e-6:
                beyond += 1
        w(f"| {n} | {len(g)} | {f(dmin, 1)} / {f(q(d, .5), 1)} / {f(hi(d), 1)} "
          f"| {f(q(lr, .5), 3)} ({f(lo(lr), 3)}–{f(hi(lr), 3)}) "
          f"| {', '.join(lots[:6])}{'…' if len(lots) > 6 else ''} | {f(q(sec, .5), 1)} | {beyond}/{checked} |")
    w("")
    w("- Khoảng cách **min** ở mỗi bậc ≈ khoảng cách cài đặt (trung vị lớn hơn do giá chạy quá trong lúc chờ).")
    w("- Cột cuối gần như toàn bộ và giây trong nến ≈ 0 → bot DCA theo **giá đóng nến**; "
      "nếu giây trong nến rải đều → DCA theo giá tức thời.")
    w("")


def section_close(baskets, w):
    w("## 3. Đóng rổ\n")
    tp, reasons, sizes = [], defaultdict(int), []
    prunes = []
    for bid, b in baskets.items():
        outs = [r for r in b if r["entry"] in ("OUT", "OUT_BY")]
        if not outs:
            continue
        final = [r for r in outs if r["k_count_after"] == "0"]
        if final:
            end_t = int(final[-1]["time_msc"])
            burst = [r for r in outs if end_t - int(r["time_msc"]) <= 5000]
            first = burst[0]
            tp.append(num(first["k_dist_avg_pips"]))
            reasons[first["reason"]] += 1
            sizes.append(int(first["k_count_before"]))
            early = [r for r in outs if end_t - int(r["time_msc"]) > 5000]
        else:
            early = outs
        for r in early:
            partial = r["k_count_after"] == r["k_count_before"]
            prunes.append((r, partial))
    w(f"- Số rổ đã đóng hết: {len(tp)}")
    w(f"- Giá đóng so với giá trung bình rổ (pip, dương = lãi): min {f(lo(tp), 1)}, "
      f"trung vị {f(q(tp, .5), 1)}, max {f(hi(tp), 1)}  (bot gốc đặt TP 150)")
    w("- Lý do deal đóng đầu tiên: " + ", ".join(f"{k}: {v}" for k, v in sorted(reasons.items())))
    w("  (DEAL_REASON_TP = TP đặt trên server; DEAL_REASON_EXPERT = EA tự đóng, kiểu TP ảo / theo tiền)")
    w("")
    w("## 4. Đóng lệnh khi rổ vẫn còn (tỉa lệnh / đóng một phần)\n")
    if not prunes:
        w("Không có — tính năng tỉa không hoạt động trong khoảng log này.\n")
        return
    w("| Thời gian | Chiều | Lệnh thứ | Lệnh đang có | Còn lại | Một phần? | Lot | Pip của lệnh | Lãi |")
    w("|---|---|---|---|---|---|---|---|---|")
    for r, partial in prunes[:200]:
        w(f"| {r['time']} | {r['k_side']} | {r['k_idx']} | {r['k_count_before']} | {r['k_count_after']} | "
          f"{'có' if partial else ''} | {r['volume']} | {r['k_pos_pips']} | {r['profit']} |")
    if len(prunes) > 200:
        w(f"\n… còn {len(prunes) - 200} dòng.")
    w("")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("deals", help="file *_deals.csv của TradeLogger 2.00")
    ap.add_argument("--magic", type=int, help="chỉ phân tích magic này (bot BE Nha Trang: 967488838)")
    ap.add_argument("--symbol", help="chỉ phân tích symbol này")
    ap.add_argument("--out", help="ghi báo cáo Markdown ra file")
    a = ap.parse_args()

    rows = load(a.deals, a.magic, a.symbol)
    lines = []
    w = lines.append
    w(f"# Phân tích log bot DCA — {a.deals}\n")
    if not rows:
        w("Không có deal nào khớp bộ lọc.")
    else:
        baskets = section_overview(rows, w)
        section_first(rows, w)
        section_dca(rows, w)
        section_close(baskets, w)
    text = "\n".join(lines)
    print(text)
    if a.out:
        with open(a.out, "w", encoding="utf-8") as fh:
            fh.write(text + "\n")


if __name__ == "__main__":
    main()
