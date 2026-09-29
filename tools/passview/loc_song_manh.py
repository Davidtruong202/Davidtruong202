"""Kiem tra bo loc 'chi rai luoi khi co song manh' tren log Passview, KHONG nhin truoc.

Don vi quyet dinh: moi chu ky luoi. Ket qua cua chu ky = lai/lo rong cua moi vi the khop tu lenh cua chu ky do.
Bo bot chu ky khong lam thay doi ket qua cac chu ky con lai (moi lenh co SL/trailing rieng, luoi moi chi phu thuoc gia).
Bien du bao chi dung du lieu CO TRUOC luc dat luoi:
  - bien do / dich chuyen gia trong W giay truoc (tu gia khop cua deal, do chinh xac mili-giay),
  - so lan khop trong W giay truoc,
  - bien do va ATR14 cua nen M5 DA DONG gan nhat.
Chon nguong tren thu 6 (giu top X% chu ky), kiem tra nguyen nguong do tren thu 2.

Phan 2 - bo k bac sat gia (chi vao lenh khi gia da chay >= k x 0.21 trong luc luoi con song):
cac bac ngoai la dung nhung lenh do (cung gia, cung thoi diem khop, cung SL/trailing) nen tinh duoc chinh xac tu log.
"""
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
DATA = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "data/passview"


def load():
    d = pd.read_csv(DATA / "Tradelogdca_deals.csv", dtype={"comment": str})
    o = pd.read_csv(DATA / "Tradelogdca_orders.csv", dtype={"comment": str})
    b = pd.read_csv(sorted(DATA.glob("Tradelogdca_bars_*.csv"))[0])
    o["ts"] = pd.to_datetime(o.time_setup, format="%Y.%m.%d %H:%M:%S")
    b["t"] = pd.to_datetime(b.feat_bar_time, format="%Y.%m.%d %H:%M:%S")
    return d, o, b


def cycles(d, o, b):
    p = o[o.type.isin(["ORDER_TYPE_BUY_STOP", "ORDER_TYPE_SELL_STOP"])].sort_values("order_ticket").copy()
    p["side"] = np.where(p.type == "ORDER_TYPE_BUY_STOP", "B", "S")
    p["cyc"] = (((p.side == "B") & (p.side.shift() != "B")) | (p.ts.diff().dt.total_seconds() > 60)).cumsum()
    ins = d[d.entry == "IN"].set_index("position_id")
    outs = d[d.entry != "IN"].set_index("position_id")
    net = (outs.profit + outs.commission + outs.swap + outs.fee).add(ins.commission, fill_value=0)
    pos = pd.DataFrame({"order": ins.order_ticket, "net": net.reindex(ins.index)}).dropna()
    pos["cyc"] = p.set_index("order_ticket").cyc.reindex(pos.order).values
    # bac danh so tu phia ngoai (ngoai cung = 10) vi bac bi thieu thuong la bac sat gia
    asc = p.side == "B"
    p["r"] = np.where(asc, p.groupby(["cyc", "side"]).price_open.rank(method="first"),
                      p.groupby(["cyc", "side"]).price_open.rank(method="first", ascending=False))
    p["bac"] = (10 - (p.groupby(["cyc", "side"]).price_open.transform("size") - p.r)).astype(int)
    pos["bac"] = p.set_index("order_ticket").bac.reindex(pos.order).values
    pos["day"] = p.set_index("order_ticket").ts.reindex(pos.order).dt.date.values
    c = p.groupby("cyc").agg(t0=("ts", "min"))
    c["net"] = pos.groupby("cyc").net.sum().reindex(c.index).fillna(0.0)
    c["day"] = c.t0.dt.date
    c["ms0"] = (c.t0 - pd.Timestamp("1970-01-01")).dt.total_seconds() * 1000   # < thoi diem dat that (lam tron xuong giay)

    # gia khop truoc luc dat luoi (moi deal, ca bid va ask; sai so <= spread)
    px = d.sort_values("time_msc")[["time_msc", "price"]].to_numpy()
    for w in (30, 60, 120):
        rng, mov, cnt = [], [], []
        for ms in c.ms0:
            i, j = np.searchsorted(px[:, 0], ms - w * 1000), np.searchsorted(px[:, 0], ms)
            seg = px[i:j, 1]
            rng.append(seg.max() - seg.min() if len(seg) else 0.0)
            mov.append(abs(seg[-1] - seg[0]) if len(seg) else 0.0)
            cnt.append(len(seg))
        c[f"bien_do_{w}s"], c[f"dich_chuyen_{w}s"], c[f"so_deal_{w}s"] = rng, mov, cnt

    # nen M5 da dong gan nhat (nen bat dau truoc t0 - 5 phut)
    bb = b.assign(bien_do_m5=b.f_range_atr * b.f_atr, atr_m5=b.f_atr).set_index("t")[["bien_do_m5", "atr_m5"]]
    last_closed = (c.t0 - pd.Timedelta(minutes=5)).dt.floor("5min")
    c["bien_do_nen_M5_truoc"] = bb.bien_do_m5.reindex(last_closed).values
    c["ATR14_M5_truoc"] = bb.atr_m5.reindex(last_closed).values
    return c, pos


def stats(g):
    w, l = g.net[g.net > 0].sum(), -g.net[g.net < 0].sum()
    return len(g), g.net.sum(), (w / l if l > 0 else np.nan)


def main():
    pd.set_option("display.width", 220)
    d, o, b = load()
    c, pos = cycles(d, o, b)
    days = sorted(c.day.unique())
    train, test = c[c.day == days[0]], c[c.day == days[1]]
    n0, p0, pf0 = stats(train)
    n1, p1, pf1 = stats(test)
    print(f"Goc (khong loc): thu 6 {n0} chu ky, lai {p0:.0f}, PF {pf0:.2f} | thu 2 {n1} chu ky, lai {p1:.0f}, PF {pf1:.2f}\n")
    feats = [f for f in c.columns if f.startswith(("bien_do", "dich_chuyen", "so_deal", "ATR14"))]
    rows = []
    for f in feats:
        tr = train.dropna(subset=[f])
        rho = tr[f].rank().corr(tr.net.rank())             # Spearman, khong can scipy
        rho_te = test[f].rank().corr(test.net.rank())
        for keep in (0.75, 0.5, 0.25):
            thr = tr[f].quantile(1 - keep)              # nguong chon tren thu 6
            a, b2 = tr[tr[f] >= thr], test[test[f] >= thr]
            na, pa, pfa = stats(a)
            nb, pb, pfb = stats(b2)
            rows.append({"bien": f, "giu_top": f"{int(keep * 100)}%", "nguong": round(thr, 2),
                         "rho_T6": round(rho, 3), "rho_T2": round(rho_te, 3),
                         "T6_%chu_ky": round(na / n0 * 100), "T6_lai": round(pa), "T6_PF": round(pfa, 2),
                         "T2_%chu_ky": round(nb / n1 * 100), "T2_lai": round(pb), "T2_PF": round(pfb, 2),
                         "T2_lai/chu_ky": round(pb / max(1, nb), 3)})
    r = pd.DataFrame(rows)
    print(r.to_string(index=False))
    print(f"\nThu 2 goc: lai/chu ky = {p1 / n1:.3f}")
    out = ROOT / "docs/passview_dca/ket_qua/loc_song_manh.csv"
    r.to_csv(out, index=False)

    print("\n--- Phan 2: lai/lo theo bac (1 = sat gia nhat)")
    lv = pos.groupby(["bac", "day"]).net.agg(["size", "sum", "mean"]).round(2).unstack("day")
    print(lv.to_string())
    rows = []
    for k in range(0, 7):
        row = {"bo_k_bac": k, "bac_dau_cach_gia": round(0.21 * (k + 1), 2)}
        for day, name in zip(days, ("T6", "T2")):
            g = pos[(pos.day == day) & (pos.bac > k)]
            n, pnl, pf = stats(g)
            row.update({f"{name}_lenh": n, f"{name}_lai": round(pnl), f"{name}_PF": round(pf, 2),
                        f"{name}_TB/lenh": round(pnl / max(1, n), 3)})
        rows.append(row)
    kk = pd.DataFrame(rows)
    print(kk.to_string(index=False))
    kk.to_csv(ROOT / "docs/passview_dca/ket_qua/bo_bac_sat_gia.csv", index=False)
    print(f"Da ghi {out} va bo_bac_sat_gia.csv")


if __name__ == "__main__":
    main()
