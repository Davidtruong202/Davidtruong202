"""Dựng lại hành vi Hydra 4.5 VIP từ lịch sử deal do script PG_XuatLichSu.mq5 xuất (chỉ đọc).

Đầu vào: PG_lich_su_deal_<server>_<từ>_<đến>.csv (phân cách ';'). Tùy chọn:
  - file PG_lich_su_lenh_... để đo độ trễ khớp lệnh;
  - file .set Hydra đang chạy để đối chiếu từng tham số với hành vi thật.
Chỉ lấy deal của các magic Hydra: mặc định 20260826 (lệnh DCA, comment "Hydra N") và 20260827 (lệnh pyramid, comment
"Hydra Py N"). Kết quả không có số tài khoản, ticket, nạp / rút hay lệnh của EA khác.

Một basket = từ lúc Hydra mở vị thế đầu tiên (không còn vị thế nào của hai magic) tới lúc đóng hết vị thế.
Giá trị 1 lot khi giá đi 1 USD lấy từ chính các deal đã đóng (lãi / (khoảng giá x lot)), không tự giả định.
"Điểm" trong input Hydra: mặc định 0,01 USD (--diem-hydra); báo cáo kiểm tra lại bằng khoảng tầng thật.
Chỉ đo cái đã xảy ra trên tài khoản. Không phải backtest, không suy ra hiệu suất tương lai.

Chạy:
  python3 phan_tich_hydra.py --deal <file deal.csv> [--lenh <file lệnh.csv>] [--set <file .set>] [--out <thư mục>]
                             [--ten <tên file md>]
  python3 phan_tich_hydra.py --tu-kiem-tra
"""
import argparse
import math
import os
import re
import sys
import tempfile

import numpy as np
import pandas as pd

MAGIC_DCA = 20260826
MAGIC_PY = 20260827
GIAY_GOP_DOT = 2.0        # các lần đóng cách nhau không quá số giây này tính là một đợt đóng


def bang(df):
    """Bảng markdown (không cần thư viện tabulate)."""
    if df is None or len(df) == 0:
        return "_(không có dữ liệu)_\n"

    def o(v):
        if isinstance(v, (float, np.floating)):
            return "" if v != v else f"{v:.2f}"
        return str(v)
    cot = [str(c) for c in df.columns]
    dong = ["| " + " | ".join(cot) + " |", "|" + "---|" * len(cot)]
    for r in df.itertuples(index=False):
        dong.append("| " + " | ".join(o(v) for v in r) + " |")
    return "\n".join(dong) + "\n"


def doc_deal(duong_dan, magics):
    d = pd.read_csv(duong_dan, sep=";", dtype={"comment": str}, keep_default_na=False)
    d = d[d["magic"].isin(magics) & d["type"].isin(["DEAL_TYPE_BUY", "DEAL_TYPE_SELL"])].copy()
    for c in ("volume", "price", "profit", "commission", "swap", "fee"):
        d[c] = pd.to_numeric(d[c], errors="coerce").fillna(0.0)
    d["t"] = pd.to_datetime(d["time"], format="%Y.%m.%d %H:%M:%S")
    return d.sort_values(["time_msc", "ticket"]).reset_index(drop=True)


def doc_set(duong_dan):
    """File .set của MT5 (UTF-16 LE hoặc UTF-8): dict tên -> giá trị (bỏ phần tối ưu hóa sau '||')."""
    raw = open(duong_dan, "rb").read()
    if raw.startswith(b"\xff\xfe"):
        txt = raw[2:].decode("utf-16-le")
    elif raw.startswith(b"\xef\xbb\xbf"):
        txt = raw[3:].decode("utf-8")
    else:
        txt = raw.decode("utf-8", "replace")
    kv = {}
    for l in txt.splitlines():
        l = l.strip()
        if not l or l.startswith(";") or "=" not in l:
            continue
        k, v = l.split("=", 1)
        kv[k.strip()] = v.split("||")[0].strip()
    return kv


def tang_tu_comment(c):
    """'Hydra 7' -> ('DCA', 7); 'Hydra Py 1' -> ('PY', 1); khác -> ('?', 0)."""
    m = re.search(r"Py\s*(\d+)", c or "")
    if m:
        return "PY", int(m.group(1))
    m = re.search(r"(\d+)\s*$", c or "")
    return ("DCA", int(m.group(1))) if m else ("?", 0)


def dung_basket(d, magic_py):
    """Ghép deal thành basket. Trả về danh sách dict, mỗi basket có danh sách lệnh vào và các lần đóng."""
    mo, ds, cur = {}, [], None
    for r in d.itertuples(index=False):
        huong = 1 if r.type == "DEAL_TYPE_BUY" else -1
        if r.entry == "DEAL_ENTRY_IN":
            if not mo:
                cur = {"vao": [], "dong": []}
                ds.append(cur)
            loai, so = tang_tu_comment(r.comment)
            if r.magic == magic_py:
                loai = "PY"
            v = {"pid": r.position_id, "t": r.t, "ms": r.time_msc, "huong": huong, "lot": r.volume, "gia": r.price,
                 "loai": loai, "so": so}
            cur["vao"].append(v)
            mo[r.position_id] = dict(v, con=r.volume)
        elif r.entry in ("DEAL_ENTRY_OUT", "DEAL_ENTRY_OUT_BY") and r.position_id in mo:
            p = mo[r.position_id]
            cur["dong"].append({"pid": r.position_id, "t": r.t, "ms": r.time_msc, "lot": r.volume, "gia": r.price,
                                "lai": r.profit + r.commission + r.swap + r.fee, "loai": p["loai"], "so": p["so"],
                                "gia_vao": p["gia"], "huong": p["huong"], "ly_do": r.reason})
            p["con"] -= r.volume
            if p["con"] <= 1e-9:
                del mo[r.position_id]
            if not mo:
                cur["xong"] = True
    return ds


def gia_tri_lot(ds):
    """Tiền tài khoản mỗi 1 lot khi giá đi 1: trung vị lãi / (khoảng giá x lot) của các lần đóng đủ lớn."""
    r = []
    for b in ds:
        for c in b["dong"]:
            kg = (c["gia"] - c["gia_vao"]) * c["huong"]
            if abs(kg) >= 0.5 and c["lot"] > 0:
                r.append(c["lai"] / (kg * c["lot"]))
    return float(np.median(r)) if r else float("nan"), len(r)


def dot_dong(dong):
    """Gom các lần đóng thành đợt: cách nhau không quá GIAY_GOP_DOT giây."""
    dot, truoc = [], None
    for c in sorted(dong, key=lambda x: x["ms"]):
        if truoc is None or (c["ms"] - truoc) / 1000.0 > GIAY_GOP_DOT:
            dot.append([])
        dot[-1].append(c)
        truoc = c["ms"]
    return dot


def tom_tat_basket(b, vpl):
    vao = b["vao"]
    dca = [v for v in vao if v["loai"] == "DCA"]
    py = [v for v in vao if v["loai"] == "PY"]
    h = (dca or vao)[0]["huong"]
    t0, t1 = vao[0]["t"], (b["dong"][-1]["t"] if b["dong"] else pd.NaT)
    buoc = [(dca[i - 1]["gia"] - dca[i]["gia"]) * h for i in range(1, len(dca))]
    # giây giữa hai lệnh DCA thêm vào (tầng 2 -> 3 trở đi) và từ lệnh đầu tới lệnh DCA đầu tiên
    giay_dca = [(dca[i]["ms"] - dca[i - 1]["ms"]) / 1000.0 for i in range(2, len(dca))]
    giay_dau = [(dca[1]["ms"] - dca[0]["ms"]) / 1000.0] if len(dca) > 1 else []
    lot_dca = sum(v["lot"] for v in dca)
    tb = sum(v["lot"] * v["gia"] for v in dca) / lot_dca if lot_dca > 0 else float("nan")
    # thả nổi lúc mở tầng sâu nhất, định giá bằng giá khớp của tầng đó (xấp xỉ, chưa trừ spread)
    sau = dca[-1]["gia"] if dca else float("nan")
    tha_noi = sum((sau - v["gia"]) * h * v["lot"] * vpl for v in dca) if dca else float("nan")
    dot = dot_dong(b["dong"])
    lai = sum(c["lai"] for c in b["dong"])
    gia_cuoi = b["dong"][-1]["gia"] if b["dong"] else float("nan")
    py_cach = [(p["gia"] - dca[0]["gia"]) * h for p in py] if dca else []
    py_toi_dong = [(t1 - p["t"]).total_seconds() for p in py] if b["dong"] else []
    # pyramid đóng cùng đợt cuối với các lệnh DCA
    py_cung_dot = sum(1 for p in py if dot and any(c["pid"] == p["pid"] for c in dot[-1])
                      and any(c["loai"] == "DCA" for c in dot[-1]))
    return {
        "bat_dau": t0, "ket_thuc": t1, "huong": "BUY" if h > 0 else "SELL", "so_tang": len(dca), "so_py": len(py),
        "lot_tang": "/".join(f"{v['lot']:.2f}" for v in dca), "lot_max": lot_dca + sum(p["lot"] for p in py),
        "tang_lot": [(v["so"], v["lot"]) for v in dca], "buoc": buoc, "giay_dca": giay_dca, "giay_dau": giay_dau,
        "gia_tang1": dca[0]["gia"] if dca else float("nan"), "gia_tb": tb, "gia_dong": gia_cuoi,
        "dong_tru_tb": (gia_cuoi - tb) * h, "dong_tru_tang1": (gia_cuoi - dca[0]["gia"]) * h if dca else float("nan"),
        "lai": lai, "lai_moi_001": lai / (lot_dca * 100.0) if lot_dca > 0 else float("nan"),
        "so_dot_dong": len(dot), "tha_noi_tang_sau": tha_noi, "py_cach_tang1": py_cach, "py_toi_dong_s": py_toi_dong,
        "py_cung_dot": py_cung_dot, "phut": (t1 - t0).total_seconds() / 60.0 if b["dong"] else float("nan"),
        "xong": b.get("xong", False), "gia_vao_dau": vao[0]["gia"], "h": h,
        "ly_do_dong": ",".join(sorted({c["ly_do"].replace("DEAL_REASON_", "") for c in b["dong"]})),
    }


def mo_ta(x, dv=""):
    x = pd.Series(x, dtype=float).dropna()
    if len(x) == 0:
        return "_(không có)_"
    return (f"n = {len(x)}; nhỏ nhất {x.min():.2f}{dv}; 10% {x.quantile(0.1):.2f}; trung vị {x.median():.2f}; "
            f"90% {x.quantile(0.9):.2f}; lớn nhất {x.max():.2f}{dv}")


def lot_theo_bang(kv, i, st=0.01):
    """Lot tầng i (0 = lệnh đầu) theo bảng hệ số của Hydra, làm tròn như MathRound theo bước lot."""
    lot = float(kv.get("InpBaseLot", "0.01"))
    for j in range(1, i + 1):
        he_so = float(kv.get("InpLotMultiplier", "1"))
        if kv.get("InpUseSegmentedMultiplier", "false") == "true":
            he_so = 1.0                          # sau nhóm cuối: chưa biết Hydra dùng gì, giả định × 1,00
            for n in range(1, 6):
                if j <= int(float(kv.get(f"InpTier{n}End", "0"))):
                    he_so = float(kv.get(f"InpTier{n}Mult", "1"))
                    break
        lot *= he_so
    return round(math.floor(lot / st + 0.5) * st, 2)


def doi_chieu_set(kv, bs, diem):
    """Bảng: tham số trong set -> giá trị quy ra USD / giây -> cái thấy trong lịch sử -> nhận xét."""
    f = lambda k: float(kv[k]) if k in kv else float("nan")
    q = lambda k: f(k) * diem
    xong = [b for b in bs if b["xong"]]
    buoc = pd.Series([x for b in bs for x in b["buoc"]], dtype=float)
    giay = pd.Series([x for b in bs for x in b["giay_dca"]], dtype=float)
    giay_dau = pd.Series([x for b in bs for x in b["giay_dau"]], dtype=float)
    gap = pd.Series([(bs[i]["bat_dau"] - bs[i - 1]["ket_thuc"]).total_seconds() for i in range(1, len(bs))
                     if bs[i - 1]["xong"]], dtype=float)
    vao_lai = pd.Series([abs(bs[i]["gia_vao_dau"] - bs[i - 1]["gia_dong"]) for i in range(1, len(bs)) if bs[i - 1]["xong"]],
                        dtype=float)
    pyc = pd.Series([x for b in bs for x in b["py_cach_tang1"]], dtype=float)
    # lot: so với bảng hệ số (tầng i = "Hydra N" với i = N - 1)
    lech = [(n, l, lot_theo_bang(kv, n - 1)) for b in bs for n, l in b["tang_lot"] if abs(lot_theo_bang(kv, n - 1) - l) > 1e-9]
    so_tl = sum(len(b["tang_lot"]) for b in bs)
    # đóng quanh mốc hòa vốn chung: basket nhiều tầng không có pyramid
    nhieu = [b for b in xong if b["so_tang"] >= 2 and b["so_py"] == 0]
    arm, san = q("InpCombinedBEArmPoints"), q("InpCombinedBEFloorPoints")
    trong = [b for b in nhieu if san - 0.05 <= b["dong_tru_tb"] < arm]
    tren = [b for b in nhieu if b["dong_tru_tb"] >= arm]
    py_tong = sum(b["so_py"] for b in bs)
    rows = [
        ("Bước DCA", "InpGridStepPoints", f"{f('InpGridStepPoints'):.0f} = {q('InpGridStepPoints'):.2f} USD",
         f"trung vị {buoc.median():.2f}, 10% {buoc.quantile(0.1):.2f} USD (giá khớp, gồm spread)",
         "khớp" if abs(buoc.median() - q("InpGridStepPoints")) <= 0.25 else "lệch"),
        ("Lot từng tầng", "InpBaseLot + bảng InpTier*", "×1,2 tới cấp 6, ×1,05 tới 14, ×1,5 tới 18, ×1,05 tới 26, ×1,3 tới 30",
         f"{so_tl - len(lech)}/{so_tl} lệnh DCA đúng lot tính từ bảng (tầng N dùng cấp N − 1)",
         "khớp" if not lech else f"lệch {len(lech)}: {lech[:5]}"),
        ("Giãn cách hai lệnh DCA", "InpDCAMinSecsApart", f"{f('InpDCAMinSecsApart'):.0f} giây",
         (f"giữa hai lệnh DCA thêm vào: ngắn nhất {giay.min():.0f} giây (n = {len(giay)}); lệnh đầu → DCA đầu tiên: "
          f"ngắn nhất {giay_dau.min():.0f} giây") if len(giay) else "—",
         ("khớp (không áp dụng từ lệnh đầu sang DCA đầu tiên)" if giay.min() >= f("InpDCAMinSecsApart") - 1 else "cần xem")
         if len(giay) else "—"),
        ("Chờ sau khi đóng basket", "InpReentryCooldownSec", f"{f('InpReentryCooldownSec'):.0f} giây",
         f"ngắn nhất {gap.min():.0f} giây, trung vị {gap.median():.0f} giây" if len(gap) else "—",
         "khớp" if len(gap) and gap.min() >= f("InpReentryCooldownSec") - 1 else "cần xem"),
        ("Vào lại cách giá đóng trước", "InpReentryMinPoints", f"{f('InpReentryMinPoints'):.0f} = {q('InpReentryMinPoints'):.2f} USD",
         f"|giá lệnh đầu − giá đóng trước|: nhỏ nhất {vao_lai.min():.2f}, trung vị {vao_lai.median():.2f} USD" if len(vao_lai) else "—",
         "gần khớp (một bên là Ask, một bên là Bid: lệch cỡ spread)"),
        ("Pyramid cách tầng 1", "InpPyramidStepPoints", f"{f('InpPyramidStepPoints'):.0f} = {q('InpPyramidStepPoints'):.2f} USD",
         f"nhỏ nhất {pyc.min():.2f}, trung vị {pyc.median():.2f} USD (Ask − Ask)" if len(pyc) else "—",
         "khớp (điều kiện theo Bid, khớp lệnh ở Ask)" if len(pyc) and pyc.min() >= q("InpPyramidStepPoints") - 0.05 else "cần xem"),
        ("Pyramid không đóng một mình", "InpPyramidNeverExitAlone", kv.get("InpPyramidNeverExitAlone", "?"),
         f"{sum(b['py_cung_dot'] for b in bs)}/{py_tong} lệnh pyramid đóng cùng đợt với lệnh DCA", "khớp"),
        ("Hòa vốn chung (SL ẩn)", "InpCombinedBEArmPoints / FloorPoints",
         f"kích hoạt +{arm:.2f}, sàn +{san:.2f} USD trên giá trung bình",
         f"basket ≥ 2 tầng không pyramid: {len(trong)}/{len(nhieu)} đóng ở +{san:.2f}…+{arm:.2f} trên giá TB, "
         f"{len(tren)} đóng cao hơn (trailing)", "khớp với cách đóng sát hòa vốn"),
        ("Trailing rổ DCA", "InpHiddenTrailStart / Step (+ mỗi tầng)",
         f"bắt đầu +{q('InpHiddenTrailStartPoints'):.2f} (+{q('InpHiddenTrailStartPerLevel'):.2f}/tầng), "
         f"bước {q('InpHiddenTrailStepPoints'):.2f} (+{q('InpHiddenTrailStepPerLevel'):.2f}/tầng); khóa {f('InpPeakLockPct'):.0f}% đỉnh",
         "các basket đóng trên mốc hòa vốn chung: " + (", ".join(f"+{b['dong_tru_tb']:.2f}" for b in tren) if tren else "—"),
         "không kiểm được nếu không có tick"),
        ("Cắt lỗ", "InpStopLossPoints", kv.get("InpStopLossPoints", "?"),
         "mọi lần đóng do EA (EXPERT), không SL / TP trên server", "khớp"),
        ("Số tầng tối đa", "InpMaxDCALevels", kv.get("InpMaxDCALevels", "?"),
         f"sâu nhất đã thấy: {max(b['so_tang'] for b in bs)} tầng", "chưa chạm"),
    ]
    return pd.DataFrame(rows, columns=["Cơ chế", "Input", "Giá trị trong set", "Lịch sử", "Nhận xét"])


def bao_cao(d, ten_nguon, lenh=None, magic_dca=MAGIC_DCA, magic_py=MAGIC_PY, kv=None, diem=0.01):
    ds = dung_basket(d, magic_py)
    vpl, n_vpl = gia_tri_lot(ds)
    bs = [tom_tat_basket(b, vpl) for b in ds]
    xong = [b for b in bs if b["xong"]]
    out = [f"# Hành vi Hydra (magic {magic_dca} DCA, {magic_py} pyramid) dựng lại từ lịch sử deal", "",
           f"Nguồn: `{ten_nguon}` (chỉ các deal của hai magic trên). Không có số tài khoản, ticket, nạp / rút hay lệnh "
           "của EA khác. Chỉ mô tả cái đã xảy ra, không phải backtest.", ""]
    if not bs:
        out.append("_(không có deal Hydra)_")
        return "\n".join(out) + "\n", pd.DataFrame()
    t0, t1 = d["t"].min(), d["t"].max()
    gio = (t1 - t0).total_seconds() / 3600.0
    lai = sum(b["lai"] for b in xong)
    out += ["## 1. Tổng quan", "",
            f"- Khoảng dữ liệu: {t0} → {t1} (giờ server), {gio:.2f} giờ; {len(d)} deal.",
            f"- Giá trị 1 lot khi giá đi 1 đơn vị: **{vpl:.1f}** tiền tài khoản (trung vị từ {n_vpl} lần đóng).",
            f"- Basket đã đóng hết: {len(xong)} / {len(bs)}; hướng: "
            f"{sum(b['huong'] == 'BUY' for b in bs)} BUY, {sum(b['huong'] == 'SELL' for b in bs)} SELL.",
            f"- Lãi đã chốt: **{lai:.2f}** ({lai / gio:.2f} mỗi giờ); basket lãi {sum(b['lai'] > 0 for b in xong)}, "
            f"lỗ {sum(b['lai'] <= 0 for b in xong)}.",
            f"- Lý do đóng: {', '.join(sorted({b['ly_do_dong'] for b in xong}))}.", ""]
    n = 2
    if kv:
        out += [f"## {n}. Đối chiếu file set đang chạy với lịch sử", "",
                f"Quy đổi \"điểm\" của Hydra = {diem} USD. Kiểm tra: bước DCA trong set / khoảng tầng thật ≈ "
                f"{np.median([x for b in bs for x in b['buoc']]) / float(kv.get('InpGridStepPoints', 'nan')):.4f} USD "
                "mỗi điểm.", "", bang(doi_chieu_set(kv, bs, diem)), ""]
        n += 1
    out += [f"## {n}. Số tầng DCA và lot từng tầng", ""]
    sd = pd.Series([b["so_tang"] for b in bs]).value_counts().sort_index()
    out += [bang(pd.DataFrame({"Số tầng DCA": sd.index, "Số basket": sd.values})), ""]
    lt = {}
    for b in ds:
        for v in b["vao"]:
            if v["loai"] == "DCA":
                lt.setdefault(v["so"], set()).add(round(v["lot"], 2))
    t = pd.DataFrame({"Tầng": list(lt.keys()), "Lot đã thấy": [", ".join(f"{x:.2f}" for x in sorted(s)) for s in lt.values()]})
    if kv:
        t["Lot theo bảng trong set"] = [f"{lot_theo_bang(kv, k - 1):.2f}" for k in t["Tầng"]]
    out += [bang(t.sort_values("Tầng")), ""]
    n += 1
    buoc = [x for b in bs for x in b["buoc"]]
    giay = [x for b in bs for x in b["giay_dca"]]
    giay_dau = [x for b in bs for x in b["giay_dau"]]
    out += [f"## {n}. Khoảng giữa hai tầng DCA liên tiếp", "",
            "- Theo giá khớp, hướng bất lợi: " + mo_ta(buoc, " USD"),
            f"- Dưới 1,2 USD: {sum(1 for x in buoc if x < 1.2)} lần (tầng sau mở khi giá chưa đi đủ một bước tính từ "
            "giá khớp tầng trước).",
            "- Thời gian giữa hai lệnh DCA thêm vào (tầng 2 → 3 trở đi): " + mo_ta(giay, " giây"),
            "- Thời gian từ lệnh đầu tới lệnh DCA đầu tiên: " + mo_ta(giay_dau, " giây"), ""]
    n += 1
    pyc = [x for b in bs for x in b["py_cach_tang1"]]
    pyt = [x for b in bs for x in b["py_toi_dong_s"]]
    bpy = [b for b in bs if b["so_py"] > 0]
    out += [f"## {n}. Lệnh pyramid", "",
            f"- Basket có pyramid: {len(bpy)} / {len(bs)}; số pyramid mỗi basket lớn nhất: "
            f"{max([b['so_py'] for b in bs])}; số tầng DCA của các basket có pyramid: "
            f"{sorted({b['so_tang'] for b in bpy})}.",
            "- Giá khớp pyramid cách giá khớp tầng 1 (theo hướng có lợi): " + mo_ta(pyc, " USD"),
            "- Từ lúc mở pyramid tới lúc đóng hết basket: " + mo_ta(pyt, " giây"),
            f"- Pyramid đóng cùng đợt với lệnh DCA: {sum(b['py_cung_dot'] for b in bs)} / {sum(b['so_py'] for b in bs)}.",
            ""]
    n += 1
    out += [f"## {n}. Đóng basket", "",
            f"- Đóng một đợt (các lệnh cách nhau ≤ {GIAY_GOP_DOT:.0f} giây): {sum(b['so_dot_dong'] == 1 for b in xong)}; "
            f"nhiều đợt: {sum(b['so_dot_dong'] > 1 for b in xong)}.",
            "- Lãi mỗi basket: " + mo_ta([b["lai"] for b in xong]),
            "- Lãi trên mỗi 0,01 lot DCA: " + mo_ta([b["lai_moi_001"] for b in xong]),
            "- Giá đóng trừ giá trung bình DCA: " + mo_ta([b["dong_tru_tb"] for b in xong], " USD"),
            "- Giá đóng trừ giá tầng 1: " + mo_ta([b["dong_tru_tang1"] for b in xong], " USD"),
            "- Thời gian giữ basket: " + mo_ta([b["phut"] for b in xong], " phút"),
            "- Thả nổi lúc mở tầng sâu nhất (định giá bằng giá khớp tầng đó, chưa gồm spread, không phải đáy thật): "
            + mo_ta([b["tha_noi_tang_sau"] for b in bs]), ""]
    n += 1
    gap = [(bs[i]["bat_dau"] - bs[i - 1]["ket_thuc"]).total_seconds() for i in range(1, len(bs)) if bs[i - 1]["xong"]]
    vao_lai = [abs(bs[i]["gia_vao_dau"] - bs[i - 1]["gia_dong"]) for i in range(1, len(bs)) if bs[i - 1]["xong"]]
    out += [f"## {n}. Từ lúc đóng basket tới lệnh tầng 1 kế tiếp", "", "- Thời gian: " + mo_ta(gap, " giây"),
            "- |Giá lệnh đầu mới − giá đóng basket trước|: " + mo_ta(vao_lai, " USD"), ""]
    n += 1
    if lenh is not None and len(lenh):
        tre = (pd.to_datetime(lenh["time_done"], format="%Y.%m.%d %H:%M:%S")
               - pd.to_datetime(lenh["time_setup"], format="%Y.%m.%d %H:%M:%S")).dt.total_seconds()
        out += [f"## {n}. Lệnh gửi lên server", "",
                f"- Loại lệnh: {', '.join(f'{k} {v}' for k, v in lenh['type'].value_counts().items())}.",
                f"- SL / TP khác 0: {int(((lenh['sl'] != 0) | (lenh['tp'] != 0)).sum())} lệnh.",
                "- Từ lúc đặt tới lúc khớp: " + mo_ta(tre, " giây") + " (MT5 chỉ lưu tới giây).", ""]
        n += 1
    tb = pd.DataFrame([{
        "#": i + 1, "Bắt đầu": b["bat_dau"].strftime("%m-%d %H:%M:%S"), "Hướng": b["huong"], "Tầng": b["so_tang"],
        "Py": b["so_py"], "Lot tầng": b["lot_tang"], "Giá tầng 1": round(b["gia_tang1"], 3),
        "Giá TB": round(b["gia_tb"], 3), "Giá đóng": round(b["gia_dong"], 3), "Đóng − TB": b["dong_tru_tb"],
        "Đóng − tầng 1": b["dong_tru_tang1"], "Lãi": b["lai"], "Đợt đóng": b["so_dot_dong"], "Phút": b["phut"]}
        for i, b in enumerate(bs)])
    out += [f"## {n}. Từng basket", "", bang(tb)]
    return "\n".join(out) + "\n", tb


def tu_kiem_tra():
    """Dựng file deal giả: basket 1 = 3 tầng BUY đóng một lần; basket 2 = tầng 1 + pyramid; basket 3 = 2 tầng SELL,
    tầng 2 đóng trước (tỉa) rồi tầng 1. Kèm file .set giả để kiểm tra phần đối chiếu."""
    cot = "ticket;order;position_id;magic;symbol;time;time_msc;type;entry;reason;volume;price;profit;commission;swap;fee;sl;tp;comment"
    dong, tk = [cot], [1000]
    goc = 1790740000000

    def them(pid, magic, t, loai, vao, vol, gia, lai, cm):
        tk[0] += 1
        h, m, s = (int(x) for x in t.split(":"))
        ms = goc + ((h * 60 + m) * 60 + s) * 1000 + tk[0] % 7
        dong.append(f"{tk[0]};{tk[0]};{pid};{magic};XAUUSDc;2026.09.30 {t};{ms};DEAL_TYPE_{loai};"
                    f"DEAL_ENTRY_{'IN' if vao else 'OUT'};DEAL_REASON_EXPERT;{vol:.2f};{gia:.3f};{lai:.2f};0.00;0.00;0.00;"
                    f"0.000;0.000;{cm}")
    # basket 1: 0.01 @4100, 0.01 @4098.5, 0.02 @4097 (tầng 3 lot 0.02 sai bảng: bảng cho 0.01); đóng hết @4099
    them(1, MAGIC_DCA, "01:00:00", "BUY", True, 0.01, 4100.0, 0, "Hydra 1")
    them(2, MAGIC_DCA, "01:01:00", "BUY", True, 0.01, 4098.5, 0, "Hydra 2")
    them(3, MAGIC_DCA, "01:02:00", "BUY", True, 0.02, 4097.0, 0, "Hydra 3")
    for pid, gv, v in ((1, 4100.0, 0.01), (2, 4098.5, 0.01), (3, 4097.0, 0.02)):
        them(pid, MAGIC_DCA, "01:05:00", "SELL", False, v, 4099.0, (4099.0 - gv) * v * 100, "")
    # basket 2: tầng 1 @4100, pyramid @4101.8, đóng hết @4101.4 (pyramid đóng sau 1 giây: vẫn cùng đợt)
    them(4, MAGIC_DCA, "01:06:00", "BUY", True, 0.01, 4100.0, 0, "Hydra 1")
    them(5, MAGIC_PY, "01:07:00", "BUY", True, 0.01, 4101.8, 0, "Hydra Py 1")
    them(4, MAGIC_DCA, "01:07:05", "SELL", False, 0.01, 4101.4, 1.4, "")
    them(5, MAGIC_PY, "01:07:06", "SELL", False, 0.01, 4101.4, -0.4, "")
    # basket 3: SELL @4100, @4101.5; tầng 2 đóng trước @4100.5 (+1), tầng 1 sau @4099.5 (+0.5)
    them(6, MAGIC_DCA, "01:10:00", "SELL", True, 0.01, 4100.0, 0, "Hydra 1")
    them(7, MAGIC_DCA, "01:11:00", "SELL", True, 0.01, 4101.5, 0, "Hydra 2")
    them(7, MAGIC_DCA, "01:12:00", "BUY", False, 0.01, 4100.5, 1.0, "")
    them(6, MAGIC_DCA, "01:13:00", "BUY", False, 0.01, 4099.5, 0.5, "")
    # deal của EA khác và nạp tiền: phải bị bỏ qua
    them(8, 12345, "01:14:00", "BUY", True, 0.10, 4100.0, 0, "khac")
    dong.append(f"9999;0;0;0;;2026.09.30 01:15:00;{goc + 99999999};DEAL_TYPE_BALANCE;DEAL_ENTRY_IN;DEAL_REASON_CLIENT;"
                "0.00;0.00;1000.00;0.00;0.00;0.00;0.00000;0.00000;D-TEST")
    set_txt = ("; thu\r\nInpBaseLot=0.01\r\nInpUseSegmentedMultiplier=true\r\nInpTier1End=6\r\nInpTier1Mult=1.2\r\n"
               "InpTier2End=14\r\nInpTier2Mult=1.05\r\nInpTier3End=18\r\nInpTier3Mult=1.5\r\nInpTier4End=26\r\n"
               "InpTier4Mult=1.05\r\nInpTier5End=30\r\nInpTier5Mult=1.3\r\nInpGridStepPoints=150||150||1||1500||N\r\n"
               "InpDCAMinSecsApart=20\r\nInpReentryCooldownSec=10\r\nInpReentryMinPoints=150\r\n"
               "InpPyramidStepPoints=150\r\nInpPyramidNeverExitAlone=true\r\nInpCombinedBEArmPoints=80\r\n"
               "InpCombinedBEFloorPoints=15\r\nInpHiddenTrailStartPoints=250\r\nInpHiddenTrailStepPoints=180\r\n"
               "InpHiddenTrailStartPerLevel=2\r\nInpHiddenTrailStepPerLevel=1\r\nInpPeakLockPct=40\r\n"
               "InpStopLossPoints=0\r\nInpMaxDCALevels=1000\r\n")
    loi = []
    with tempfile.TemporaryDirectory() as tmp:
        f = os.path.join(tmp, "PG_lich_su_deal_TEST.csv")
        with open(f, "w", encoding="utf-8", newline="\r\n") as fh:
            fh.write("\n".join(dong) + "\n")
        fs = os.path.join(tmp, "hydra.set")
        with open(fs, "wb") as fh:
            fh.write(b"\xff\xfe" + set_txt.encode("utf-16-le"))
        kv = doc_set(fs)
        if kv.get("InpGridStepPoints") != "150" or len(kv) != 27:
            loi.append(f"đọc set sai: {len(kv)} dòng, InpGridStepPoints = {kv.get('InpGridStepPoints')}")
        d = doc_deal(f, [MAGIC_DCA, MAGIC_PY])
        md, tb = bao_cao(d, "PG_lich_su_deal_TEST.csv", kv=kv)
    if len(tb) != 3:
        loi.append(f"số basket {len(tb)} != 3")
    else:
        kv_ = [("Tầng", [3, 1, 2]), ("Py", [0, 1, 0]), ("Hướng", ["BUY", "BUY", "SELL"]), ("Đợt đóng", [1, 1, 2])]
        for c, v in kv_:
            if list(tb[c]) != v:
                loi.append(f"{c} = {list(tb[c])} != {v}")
        for c, v in (("Lãi", [3.5, 1.0, 1.5]), ("Giá TB", [4098.125, 4100.0, 4100.75]), ("Đóng − tầng 1", [-1.0, 1.4, 0.5])):
            if not np.allclose(list(tb[c]), v, atol=1e-6):
                loi.append(f"{c} = {list(tb[c])} != {v}")
    lot_mong = [0.01, 0.01, 0.01, 0.02, 0.02, 0.02, 0.03, 0.03, 0.03, 0.03, 0.04]
    lot_bang = [lot_theo_bang(kv, i) for i in range(11)]
    if lot_bang != lot_mong:
        loi.append(f"lot theo bảng {lot_bang} != {lot_mong}")
    for chu in ("**100.0**", "Dưới 1,2 USD: 0 lần", "Basket có pyramid: 1 / 3", "nhiều đợt: 1",
                "5/6 lệnh DCA đúng lot", "1/1 lệnh pyramid đóng cùng đợt", "ngắn nhất 60 giây",
                "Pyramid đóng cùng đợt với lệnh DCA: 1 / 1"):
        if chu not in md:
            loi.append(f"báo cáo thiếu '{chu}'")
    if "D-TEST" in md or "12345" in md:
        loi.append("báo cáo lộ deal không phải Hydra")
    print("TỰ KIỂM TRA:", "ĐẠT" if not loi else "LỖI")
    for x in loi:
        print("  -", x)
    return 0 if not loi else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--deal", help="file PG_lich_su_deal_*.csv")
    ap.add_argument("--lenh", help="file PG_lich_su_lenh_*.csv (tùy chọn)")
    ap.add_argument("--set", help="file .set Hydra đang chạy (tùy chọn)")
    ap.add_argument("--diem-hydra", type=float, default=0.01, help="1 điểm trong input Hydra = bao nhiêu USD (mặc định 0,01)")
    ap.add_argument("--magic-dca", type=int, default=MAGIC_DCA)
    ap.add_argument("--magic-py", type=int, default=MAGIC_PY)
    ap.add_argument("--out", help="thư mục ghi báo cáo .md")
    ap.add_argument("--ten", default="hanh_vi_hydra.md", help="tên file báo cáo")
    ap.add_argument("--tu-kiem-tra", action="store_true")
    a = ap.parse_args()
    if a.tu_kiem_tra:
        return tu_kiem_tra()
    if not a.deal:
        ap.error("cần --deal hoặc --tu-kiem-tra")
    d = doc_deal(a.deal, [a.magic_dca, a.magic_py])
    lenh = None
    if a.lenh:
        lenh = pd.read_csv(a.lenh, sep=";", dtype={"comment": str}, keep_default_na=False)
        lenh = lenh[lenh["magic"].isin([a.magic_dca, a.magic_py])].copy()
        for c in ("sl", "tp"):
            lenh[c] = pd.to_numeric(lenh[c], errors="coerce").fillna(0.0)
    kv = doc_set(a.set) if a.set else None
    # tên nguồn bỏ tiền tố tải lên (nếu có) để không lộ đường dẫn máy
    ten = re.sub(r"^[0-9a-f]{8}-", "", os.path.basename(a.deal))
    md, _ = bao_cao(d, ten, lenh, a.magic_dca, a.magic_py, kv, a.diem_hydra)
    print(md)
    if a.out:
        os.makedirs(a.out, exist_ok=True)
        with open(os.path.join(a.out, a.ten), "w", encoding="utf-8") as f:
            f.write(md)
    return 0


if __name__ == "__main__":
    sys.exit(main())
