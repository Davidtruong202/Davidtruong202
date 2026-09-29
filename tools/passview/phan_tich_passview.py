"""Tai dung va kiem chung quy tac bot Passview tu log TradeLogger (deals/orders/bars/symbols).

Chay:  python3 tools/passview/phan_tich_passview.py [thu_muc_du_lieu] [thu_muc_ket_qua]
Mac dinh doc data/passview/Tradelogdca_*.csv, ghi CSV ket qua vao docs/passview_dca/ket_qua/.
Moi con so trong docs/passview_dca/01_bao_cao_tai_dung_V2.md deu in ra tu script nay.
"""
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
DATA = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "data/passview"
OUT = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "docs/passview_dca/ket_qua"
PREFIX = "Tradelogdca"
STEP, SL_DIST = 0.21, 0.50          # gia tri do duoc, dung de dem ty le khop


def load():
    d = pd.read_csv(DATA / f"{PREFIX}_deals.csv", dtype={"comment": str})
    o = pd.read_csv(DATA / f"{PREFIX}_orders.csv", dtype={"comment": str})
    bars = sorted(DATA.glob(f"{PREFIX}_bars_*.csv"))
    b = pd.read_csv(bars[0]) if bars else None
    s = pd.read_csv(DATA / f"{PREFIX}_symbols.csv")
    o["ts"] = pd.to_datetime(o.time_setup, format="%Y.%m.%d %H:%M:%S")
    o["td"] = pd.to_datetime(o.time_done, format="%Y.%m.%d %H:%M:%S")
    d["t"] = pd.to_datetime(d.time, format="%Y.%m.%d %H:%M:%S")
    if b is not None:
        b["t"] = pd.to_datetime(b.feat_bar_time, format="%Y.%m.%d %H:%M:%S")
    return d, o, b, s


def section(title):
    print(f"\n=== {title}")


def quality(d, o, b, s):
    section("1. Chat luong du lieu")
    print(s.to_string(index=False))
    print(f"deals : {len(d)} dong, {d.time.min()} -> {d.time.max()}, trung deal_ticket={d.deal_ticket.duplicated().sum()}, "
          f"trung ca dong={d.duplicated().sum()}")
    print(f"orders: {len(o)} dong, {o.time_setup.min()} -> {o.time_done.max()}, trung order_ticket={o.order_ticket.duplicated().sum()}")
    if b is not None:
        print(f"bars  : {len(b)} nen, {b.feat_bar_time.min()} -> {b.feat_bar_time.max()}, trung={b.feat_bar_time.duplicated().sum()}, "
              f"o trong={int(b.isna().sum().sum())}")
        gaps = b.t.diff().dt.total_seconds() / 60
        g = pd.DataFrame({"tu": b.t.shift()[gaps > 5], "den": b.t[gaps > 5], "phut": gaps[gaps > 5]})
        print("khoang trong nen M5 (nghi hang ngay -> suy ra mui gio server):")
        print(g.to_string(index=False))
    print("deals theo magic/reason/entry:")
    print(d.groupby(["magic", "reason", "entry"]).size().to_string())
    print("orders theo type/state/reason:")
    print(o.groupby(["type", "state", "reason"]).size().to_string())
    print("comment deal IN:", d[d.entry == "IN"].comment.fillna("<trong>").value_counts().to_dict())
    print("o trong trong deals:", d.isna().sum()[d.isna().sum() > 0].to_dict())


def pending_and_cycles(o):
    """Lenh cho cua bot + chu ky dat/huy luoi."""
    p = o[o.type.isin(["ORDER_TYPE_BUY_STOP", "ORDER_TYPE_SELL_STOP"])].sort_values("order_ticket").copy()
    p["side"] = np.where(p.type == "ORDER_TYPE_BUY_STOP", "B", "S")
    # chu ky moi: bat dau mot loat BUY STOP (bot dat BUY truoc, SELL sau) hoac cach nhau > 60 giay
    new = ((p.side == "B") & (p.side.shift() != "B")) | (p.ts.diff().dt.total_seconds() > 60)
    p["cyc"] = new.cumsum()
    p["day"] = p.ts.dt.date
    p["gap"] = p.groupby(["cyc", "side"]).price_open.diff().abs().round(2)
    p["sl_dist"] = np.where(p.side == "B", p.price_open - p.sl, p.sl - p.price_open).round(2)
    c = p.groupby("cyc").agg(day=("day", "first"), t0=("ts", "min"), t1=("ts", "max"),
                             nB=("side", lambda x: (x == "B").sum()), nS=("side", lambda x: (x == "S").sum()))
    c["minB"] = p[p.side == "B"].groupby("cyc").price_open.min()
    c["maxS"] = p[p.side == "S"].groupby("cyc").price_open.max()
    c["khe_trong"] = (c.minB - c.maxS).round(2)
    c["huy"] = p[p.state == "ORDER_STATE_CANCELED"].groupby("cyc").td.min()
    c["song_s"] = (c.huy - c.t1).dt.total_seconds()
    c["chu_ky_s"] = c.t0.diff().dt.total_seconds()
    c["khop"] = p[p.state == "ORDER_STATE_FILLED"].groupby("cyc").size().reindex(c.index).fillna(0).astype(int)
    return p, c


def positions(d, o):
    ins = d[d.entry == "IN"].set_index("position_id")
    outs = d[d.entry.isin(["OUT", "OUT_BY"])].set_index("position_id")
    pos = pd.DataFrame({"side": ins.type, "t_in": ins.t, "ms_in": ins.time_msc, "p_in": ins.price, "sl0": ins.sl,
                        "order": ins.order_ticket, "comm_in": ins.commission,
                        "t_out": outs.t, "ms_out": outs.time_msc, "p_out": outs.price, "profit": outs.profit,
                        "comm_out": outs.commission, "swap": outs.swap, "fee": outs.fee, "reason": outs.reason,
                        "cmt_out": outs.comment})
    sgn = np.where(pos.side == "BUY", 1, -1)
    stop_px = o.set_index("order_ticket").price_open
    pos["stop_px"] = stop_px.reindex(pos.order).values
    pos["sl_final"] = pos.cmt_out.str.extract(r"\[sl ([0-9.]+)\]")[0].astype(float)
    pos["truot_vao"] = ((pos.p_in - pos.stop_px) * sgn).round(2)
    pos["truot_ra"] = ((pos.sl_final - pos.p_out) * sgn).round(2)
    pos["sl_vs_vao"] = ((pos.sl_final - pos.p_in) * sgn).round(2)
    pos["giu_s"] = (pos.ms_out - pos.ms_in) / 1000.0
    pos["net"] = pos.profit + pos.comm_in + pos.comm_out + pos.swap + pos.fee
    pos["day"] = pos.t_in.dt.date
    return pos


def trail_lower_bound(d, pos):
    """Can duoi cua khoang trailing: gia tot nhat QUAN SAT DUOC trong doi vi the - muc SL cuoi.
    Gia BID quan sat = deal SELL, gia ASK = deal BUY (do chinh xac mili-giay)."""
    bid = d[d.type == "SELL"][["time_msc", "price"]].sort_values("time_msc").to_numpy()
    ask = d[d.type == "BUY"][["time_msc", "price"]].sort_values("time_msc").to_numpy()
    out = []
    for _, r in pos[pos.sl_vs_vao >= 0].iterrows():
        arr, fn = (bid, np.max) if r.side == "BUY" else (ask, np.min)
        i, j = np.searchsorted(arr[:, 0], r.ms_in), np.searchsorted(arr[:, 0], r.ms_out)
        if j > i:
            m = fn(arr[i:j, 1])
            out.append(round(m - r.sl_final if r.side == "BUY" else r.sl_final - m, 2))
    return pd.Series(out, name="d_est")


def episodes(pos):
    """Dot = khoang thoi gian lien tuc co it nhat 1 vi the cung chieu dang mo (tuong duong 'basket')."""
    rows = []
    for side, g in pos.sort_values("ms_in").groupby("side"):
        end, eid, ids = -1, -1, []
        for _, r in g.iterrows():
            if r.ms_in > end:
                eid += 1
            end = max(end, r.ms_out)
            ids.append(eid)
        rows.append(g.assign(ep=ids))
    e = pd.concat(rows)
    ep = e.groupby(["side", "ep"]).agg(so_lenh=("net", "size"), net=("net", "sum"), t0=("t_in", "min"), t1=("t_out", "max"),
                                       tat_ca_sl_goc=("sl_vs_vao", lambda s: bool((s == -SL_DIST).all())))
    ep["dai_s"] = (ep.t1 - ep.t0).dt.total_seconds()
    return ep


def perf(pos, label):
    w, l = pos[pos.net > 0], pos[pos.net <= 0]
    eq = pos.sort_values("ms_out").net.cumsum()
    return {"nhom": label, "vi_the": len(pos), "lai_gop": round(pos.profit.sum(), 2),
            "hoa_hong": round((pos.comm_in + pos.comm_out).sum(), 2), "swap": round(pos.swap.sum(), 2),
            "lai_rong": round(pos.net.sum(), 2), "win_%": round(len(w) / max(1, len(pos)) * 100, 1),
            "TB_thang": round(w.net.mean(), 3), "TB_thua": round(l.net.mean(), 3),
            "PF": round(w.net.sum() / -l.net.sum(), 3) if len(l) else np.nan,
            "ky_vong_moi_lenh": round(pos.net.mean(), 3),
            "DD_thuc_hien_max": round((eq.cummax() - eq).max(), 2)}


def rule_checks(p, c, pos, label):
    s = pos.sl_vs_vao.dropna()
    return {"phien": label, "lenh_cho": len(p), "chu_ky": len(c),
            "R3_buoc_0.21_%": round((p.gap.dropna() == STEP).mean() * 100, 2),
            "R3_10_bac_BUY_%": round((c.nB == 10).mean() * 100, 1),
            "R3_10_bac_SELL_%": round((c.nS == 10).mean() * 100, 1),
            "R3_ca_2_phia_%": round(((c.nB > 0) & (c.nS > 0)).mean() * 100, 2),
            "R5_SL_0.50_%": round((p.sl_dist == SL_DIST).mean() * 100, 2),
            "R5_TP_0_%": round((p.tp == 0).mean() * 100, 2),
            "R5_lot_0.05_%": round((p.volume_initial == 0.05).mean() * 100, 2),
            "R6_huy_sau_5s_%": round((c.song_s == 5).mean() * 100, 1),
            "R6_huy_4-6s_%": round(c.song_s.between(4, 6).mean() * 100, 1),
            "R7_thoat_bang_SL_%": round((pos.reason == "DEAL_REASON_SL").mean() * 100, 2),
            "R8_SL_giua_-0.5_va_0": int(((s > -SL_DIST) & (s < 0)).sum()),
            "R8_SL_giu_nguyen_%": round((s == -SL_DIST).mean() * 100, 1),
            "R8_SL_len_>=hoa_von_%": round((s >= 0).mean() * 100, 1),
            "truot_gia_vao_max": float(pos.truot_vao.abs().max()),
            "truot_gia_SL_max": float(pos.truot_ra.abs().max())}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    pd.set_option("display.width", 220)
    pd.set_option("display.max_columns", 40)
    d, o, b, s = load()
    quality(d, o, b, s)

    p, c = pending_and_cycles(o)
    pos = positions(d, o)

    section("2. Thoi gian hoat dong (gio server)")
    for day, g in c.groupby("day"):
        print(f"{day}: {g.t0.min()} -> {g.t1.max()}, {len(g)} chu ky")
    long_gaps = c.chu_ky_s[c.chu_ky_s > 15]
    print("khoang ngung dat luoi > 15 s trong phien:", int(long_gaps[long_gaps < 3600].count()))

    section("3. Hinh hoc luoi")
    print("so bac moi lan dat (BUY x SELL):")
    print(pd.crosstab(c.nB, c.nS).to_string())
    print("khoang cach bac:", p.gap.value_counts().head(5).to_dict())
    print("khoang cach SL:", p.sl_dist.value_counts().head(3).to_dict(), " TP:", p.tp.value_counts().head(3).to_dict(),
          " lot:", p.volume_initial.value_counts().to_dict())
    print("thoi gian song cua luoi (s, tu luc dat xong toi luc huy):", c.song_s.value_counts().sort_index().to_dict())
    print("chu ky (s, bat dau -> bat dau):", c.chu_ky_s[c.chu_ky_s < 60].value_counts().sort_index().to_dict())
    print("khe giua BUY STOP thap nhat va SELL STOP cao nhat, theo so bac:")
    print(c.groupby(["nB", "nS"]).khe_trong.agg(["count", "median"]).query("count >= 5").to_string())

    # bac bi thieu co trung vi the dang mo khong? (gia thuyet 'bo qua bac da co lenh')
    occ = []
    for (cy, sd), lv in p.groupby(["cyc", "side"]).price_open:
        t = c.loc[cy, "t0"]
        side = "BUY" if sd == "B" else "SELL"
        op = pos[(pos.side == side) & (pos.t_in <= t) & (pos.t_out > t)].p_in.to_numpy()
        slot = lv.min() - STEP if sd == "B" else lv.max() + STEP
        occ.append((len(lv), bool(len(op) and (np.abs(op - slot) <= STEP / 2).any())))
    occ = pd.DataFrame(occ, columns=["so_bac", "bac_thieu_trung_vi_the"])
    print("ty le 'o trong' trung vi the dang mo:", occ.groupby("so_bac").bac_thieu_trung_vi_the.mean().round(3).to_dict())

    section("3b. Toc do: dat lenh nhanh nhung luoi song ~5 giay")
    print("thoi gian dat xong ca luoi (s, lenh dau -> lenh cuoi):", (c.t1 - c.t0).dt.total_seconds().value_counts().sort_index().to_dict())
    fills = p[p.state == "ORDER_STATE_FILLED"].copy()
    fills["fill_ms"] = d[d.entry == "IN"].set_index("order_ticket").time_msc.reindex(fills.order_ticket).values
    wait = fills.fill_ms / 1000 - (fills.ts - pd.Timestamp("1970-01-01")).dt.total_seconds()
    print(f"khop sau khi dat > 2 s: {(wait > 2).mean() * 100:.1f}%, > 4 s: {(wait > 4).mean() * 100:.1f}% (sai so +-1 s)")
    canc = p[p.state == "ORDER_STATE_CANCELED"]
    near = pd.concat([canc[canc.side == "B"].groupby("cyc").apply(lambda g: (g.price_open - g.price_current).loc[g.price_open.idxmin()]),
                      canc[canc.side == "S"].groupby("cyc").apply(lambda g: (g.price_current - g.price_open).loc[g.price_open.idxmax()])])
    print("luc huy, bac gan gia nhat cach gia:", near.describe(percentiles=[.05, .5, .95]).round(2).to_dict(),
          "(neu lenh bi doi gia theo gia se luon ~0.2)")
    print("tu luc huy luoi cu toi luc dat luoi moi (s):",
          (c.t0.shift(-1) - canc.groupby("cyc").td.max()).dt.total_seconds().value_counts().sort_index().head(3).to_dict())

    section("4. Vi the va cach thoat")
    print("truot gia vao (khop - gia stop):", pos.truot_vao.value_counts().head(3).to_dict())
    print("truot gia ra (muc SL - khop):", pos.truot_ra.value_counts().head(3).to_dict())
    print("SL cuoi so voi gia vao:", pos.sl_vs_vao.describe(percentiles=[.25, .5, .75, .95]).round(3).to_dict())
    lb = trail_lower_bound(d, pos)
    print(f"can duoi khoang trailing (n={len(lb)}): p50={lb.median():.2f} p95={lb.quantile(.95):.2f} "
          f"ty le <=0.50: {(lb <= 0.50).mean() * 100:.1f}%")
    print("thoi gian giu (s):", pos.giu_s.describe(percentiles=[.25, .5, .75, .95]).round(1).to_dict())
    conc = pd.concat([pd.DataFrame({"ms": pos.ms_in, "x": 1, "side": pos.side}),
                      pd.DataFrame({"ms": pos.ms_out, "x": -1, "side": pos.side})]).sort_values(["ms", "x"])
    print("so vi the mo dong thoi lon nhat:",
          {sd: int(g.x.cumsum().max()) for sd, g in conc.groupby("side")}, "tong:", int(conc.x.cumsum().max()))
    print("dong tay (CLIENT):", int((pos.reason == "DEAL_REASON_CLIENT").sum()))

    section("5. Hieu suat")
    tbl = pd.DataFrame([perf(pos, "Tat ca")] + [perf(g, str(k)) for k, g in pos.groupby("day")]
                       + [perf(g, k) for k, g in pos.groupby("side")])
    print(tbl.to_string(index=False))
    ep = episodes(pos)
    bins = [0, 1, 2, 3, 5, 10, 20, 1000]
    print(f"dot (basket) cung chieu: {len(ep)}, win% {(ep.net > 0).mean() * 100:.1f}, so lenh trung vi {ep.so_lenh.median():.0f}, "
          f"max {ep.so_lenh.max()}")
    print(ep.groupby(pd.cut(ep.so_lenh, bins)).net.agg(["count", "mean", "sum"]).round(2).to_string())
    print(f"dot ma moi lenh deu cham SL goc: {int(ep.tat_ca_sl_goc.sum())}, tong {ep[ep.tat_ca_sl_goc].net.sum():.2f}")
    if b is not None:
        b["bien_do"] = b.f_range_atr * b.f_atr
        pb = pos.assign(bar=pos.t_in.dt.floor("5min")).groupby("bar").net.sum().to_frame()
        pb = pb.join(b.set_index("t").bien_do, how="left")
        print(f"lai theo bien do nen M5 ({len(pb)} nen co giao dich), tuong quan={pb.net.corr(pb.bien_do):.3f}:")
        print(pb.groupby(pd.qcut(pb.bien_do, 4)).net.agg(["count", "mean", "sum"]).round(2).to_string())

    section("6. Kiem tra doc lap theo thoi gian (thu 6 = suy luan, thu 2 = kiem tra)")
    days = sorted(pos.day.unique())
    checks = pd.DataFrame([rule_checks(p[p.day == dd], c[c.day == dd], pos[pos.day == dd], str(dd)) for dd in days])
    print(checks.T.to_string())

    pos.to_csv(OUT / "vi_the.csv")
    c.to_csv(OUT / "chu_ky_luoi.csv")
    ep.to_csv(OUT / "dot_cung_chieu.csv")
    tbl.to_csv(OUT / "hieu_suat.csv", index=False)
    checks.to_csv(OUT / "kiem_tra_quy_tac.csv", index=False)
    print(f"\nDa ghi ket qua vao {OUT}")


if __name__ == "__main__":
    main()
