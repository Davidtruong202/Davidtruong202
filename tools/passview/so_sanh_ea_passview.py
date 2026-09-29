"""So sanh EA tai dung voi bot Passview, tung lenh va tong the (Giai doan 4).

Chay:
  python3 tools/passview/so_sanh_ea_passview.py --ea <PassviewV2_*.csv> [--passview data/passview/Tradelogdca_deals.csv]
  python3 tools/passview/so_sanh_ea_passview.py --tu-kiem-tra      # kiem tra chinh script

--ea la file log cua EA V2.00 (dong FILL/CLOSE) sau khi chay Strategy Tester (Every tick based on real ticks)
tren cung symbol/san va cung ngay voi log Passview. Hai ben chi duoc so tren KHUNG THOI GIAN CHUNG cua tung ngay.
Ghep lenh: cung chieu, lech thoi diem khop <= --tol-ms, lech gia khop <= --tol-gia.
"""
import argparse
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
SL_GOC = 0.50


def passview_positions(path):
    d = pd.read_csv(path, dtype={"comment": str})
    ins = d[d.entry == "IN"].set_index("position_id")
    outs = d[d.entry.isin(["OUT", "OUT_BY"])].set_index("position_id")
    pos = pd.DataFrame({"side": ins.type, "ms_in": ins.time_msc, "p_in": ins.price, "ms_out": outs.time_msc,
                        "p_out": outs.price, "profit": outs.profit,
                        "comm": ins.commission + outs.commission, "swap": outs.swap + outs.fee,
                        "reason": outs.reason}).dropna(subset=["ms_out"])
    pos["net"] = pos.profit + pos.comm + pos.swap
    return pos.reset_index(drop=True)


def ea_positions(path):
    e = pd.read_csv(path, dtype={"detail": str})
    fill = e[e.event == "FILL"].set_index("position")
    close = e[e.event == "CLOSE"].set_index("position")
    comm_in = fill.detail.str.extract(r"commission=(-?[0-9.]+)")[0].astype(float).fillna(0.0)
    profit = close.detail.str.extract(r"profit=(-?[0-9.]+)")[0].astype(float)
    reason = close.detail.str.extract(r"reason=(\w+)")[0]
    pos = pd.DataFrame({"side": fill.side, "ms_in": fill.time_msc, "p_in": fill.price,
                        "ms_out": close.time_msc.reindex(fill.index), "p_out": close.price.reindex(fill.index),
                        "profit": profit.reindex(fill.index),
                        "comm": comm_in + (close["diff"] - profit).reindex(fill.index).fillna(0.0),
                        "swap": 0.0, "reason": reason.reindex(fill.index)}).dropna(subset=["ms_out"])
    pos["net"] = pos.profit + pos.comm
    return pos.reset_index(drop=True)


def common_window(a, b):
    """Chi giu lenh khop trong khoang thoi gian ca hai ben cung hoat dong, theo tung ngay."""
    keep_a, keep_b = [], []
    day_a = pd.to_datetime(a.ms_in, unit="ms").dt.date
    day_b = pd.to_datetime(b.ms_in, unit="ms").dt.date
    for day in sorted(set(day_a) & set(day_b)):
        ga, gb = a[day_a == day], b[day_b == day]
        lo, hi = max(ga.ms_in.min(), gb.ms_in.min()), min(ga.ms_in.max(), gb.ms_in.max())
        keep_a.append(ga[ga.ms_in.between(lo, hi)])
        keep_b.append(gb[gb.ms_in.between(lo, hi)])
    if not keep_a:
        return a.iloc[0:0], b.iloc[0:0]
    return pd.concat(keep_a), pd.concat(keep_b)


def metrics(pos):
    if pos.empty:
        return {}
    sgn = np.where(pos.side == "BUY", 1, -1)
    move = ((pos.p_out - pos.p_in) * sgn).round(2)
    w, l = pos[pos.net > 0], pos[pos.net <= 0]
    eq = pos.sort_values("ms_out").net.cumsum()
    conc = pd.concat([pd.DataFrame({"ms": pos.ms_in, "x": 1, "s": pos.side}),
                      pd.DataFrame({"ms": pos.ms_out, "x": -1, "s": pos.side})]).sort_values(["ms", "x"])
    return {"Số vị thế": len(pos), "BUY / SELL": f"{(pos.side == 'BUY').sum()} / {(pos.side == 'SELL').sum()}",
            "Win rate %": round(len(w) / len(pos) * 100, 1), "TB thắng $": round(w.net.mean(), 2),
            "TB thua $": round(l.net.mean(), 2), "Profit Factor": round(w.net.sum() / -l.net.sum(), 3) if len(l) else np.nan,
            "Expectancy $/lệnh": round(pos.net.mean(), 3), "Lãi gộp $": round(pos.profit.sum(), 2),
            "Hoa hồng + phí $": round((pos.comm + pos.swap).sum(), 2), "Lãi ròng $": round(pos.net.sum(), 2),
            "% chạm SL gốc": round((move <= -SL_GOC + 1e-9).mean() * 100, 1),
            "Giữ lệnh trung vị s": round(((pos.ms_out - pos.ms_in) / 1000).median(), 1),
            "Vị thế mở cùng chiều max": int(max(g.x.cumsum().max() for _, g in conc.groupby("s"))),
            "DD thực hiện max $": round((eq.cummax() - eq).max(), 2)}


def match(pv, ea, tol_ms, tol_px):
    """Ghep 1-1 tham lam theo do lech thoi gian."""
    rows, used = [], set()
    for side in ("BUY", "SELL"):
        a = pv[pv.side == side].sort_values("ms_in")
        b = ea[ea.side == side].sort_values("ms_in")
        bt, bp, bi = b.ms_in.to_numpy(), b.p_in.to_numpy(), b.index.to_numpy()
        for ia, r in a.iterrows():
            lo, hi = np.searchsorted(bt, r.ms_in - tol_ms), np.searchsorted(bt, r.ms_in + tol_ms, "right")
            best = None
            for j in range(lo, hi):
                if bi[j] in used or abs(bp[j] - r.p_in) > tol_px:
                    continue
                if best is None or abs(bt[j] - r.ms_in) < abs(bt[best] - r.ms_in):
                    best = j
            if best is not None:
                used.add(bi[best])
                q = ea.loc[bi[best]]
                rows.append({"dt_vao_ms": q.ms_in - r.ms_in, "dp_vao": round(q.p_in - r.p_in, 2),
                             "dt_ra_ms": q.ms_out - r.ms_out, "dp_ra": round(q.p_out - r.p_out, 2),
                             "dnet": round(q.net - r.net, 2)})
    return pd.DataFrame(rows)


def report(pv, ea, tol_ms, tol_px):
    pv, ea = common_window(pv, ea)
    m = pd.DataFrame({"Passview": metrics(pv), "EA tái dựng": metrics(ea)})
    print("## Tổng thể (khung thời gian chung)\n")
    print(m.to_markdown() if hasattr(m, "to_markdown") else m.to_string())
    mt = match(pv, ea, tol_ms, tol_px)
    n_pv, n_ea = len(pv), len(ea)
    print(f"\n## Ghép lệnh (lệch <= {tol_ms} ms, <= {tol_px} giá)\n")
    if mt.empty:
        print("Không ghép được lệnh nào.")
        return 0.0
    print(f"- Lệnh Passview có lệnh EA tương ứng: {len(mt)}/{n_pv} = {len(mt) / max(1, n_pv) * 100:.1f}%")
    print(f"- Lệnh EA có lệnh Passview tương ứng: {len(mt)}/{n_ea} = {len(mt) / max(1, n_ea) * 100:.1f}%")
    print(f"- Lệch thời điểm vào: trung vị {mt.dt_vao_ms.abs().median():.0f} ms; lệch giá vào trung vị {mt.dp_vao.abs().median():.2f}")
    print(f"- Lệch thời điểm ra: trung vị {mt.dt_ra_ms.abs().median():.0f} ms; lệch giá ra trung vị {mt.dp_ra.abs().median():.2f}")
    print(f"- Chênh lãi/lỗ trên các cặp ghép: tổng {mt.dnet.sum():.2f}, trung vị {mt.dnet.median():.2f}")
    return len(mt) / max(1, n_pv)


def self_test(pv_path):
    """Tu tao log EA tu chinh lenh Passview: lech 200 ms phai ghep ~100%, lech 5 s phai ghep ~0%."""
    d = pd.read_csv(pv_path, dtype={"comment": str})
    rows = []
    for _, r in d.iterrows():
        if r.entry == "IN":
            rows.append({"time_msc": r.time_msc, "event": "FILL", "side": r.type, "position": r.position_id,
                         "price": r.price, "diff": 0.0, "detail": f"commission={r.commission:.2f}"})
        else:
            side = "BUY" if r.type == "SELL" else "SELL"
            rows.append({"time_msc": r.time_msc, "event": "CLOSE", "side": side, "position": r.position_id,
                         "price": r.price, "diff": r.profit + r.commission + r.swap + r.fee,
                         "detail": f"reason={r.reason} profit={r.profit:.2f}"})
    base = pd.DataFrame(rows)
    out = Path("/tmp") / "pvr2_selftest.csv"
    ok = True
    for shift, expect_hi in ((200, True), (5000, False)):
        base.assign(time_msc=base.time_msc + shift).to_csv(out, index=False)
        print(f"\n### Tự kiểm tra: log EA = lệnh Passview dịch {shift} ms")
        rate = report(passview_positions(pv_path), ea_positions(out), 1500, 0.10)
        ok &= (rate > 0.99) if expect_hi else (rate < 0.05)
    print("\nTỰ KIỂM TRA:", "ĐẠT" if ok else "KHÔNG ĐẠT")
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--passview", default=str(ROOT / "data/passview/Tradelogdca_deals.csv"))
    ap.add_argument("--ea")
    ap.add_argument("--tol-ms", type=int, default=1500)
    ap.add_argument("--tol-gia", type=float, default=0.10)
    ap.add_argument("--tu-kiem-tra", action="store_true")
    a = ap.parse_args()
    if a.tu_kiem_tra:
        raise SystemExit(0 if self_test(a.passview) else 1)
    if not a.ea:
        ap.error("cần --ea <file log EA> hoặc --tu-kiem-tra")
    report(passview_positions(a.passview), ea_positions(a.ea), a.tol_ms, a.tol_gia)


if __name__ == "__main__":
    main()
