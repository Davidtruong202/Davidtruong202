"""Thu cac cach chot loi khac tren CHINH cac lenh vao cua Passview (diem vao giu nguyen, chi doi cach thoat).

Chuoi gia gia lap = moi deal trong log (mili-giay): deal SELL = gia Bid, deal BUY = gia Ask
(quy doi Ask <-> Bid bang spread gia dinh SPREAD). Buoc gia do duoc ~0.21 (buoc luoi) nen khong thay
nhieu nho tung tick -> KHONG dung de thu cac quy tac o muc tick (vd dong khi tick dao chieu).

Kiem chung truoc: mo phong lai dung quy tac Passview (SL 0.50, trailing 0.50 kich hoat o +0.50) va so voi ket qua that.
Chay: python3 tools/passview/thu_cach_chot.py
"""
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
DATA = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "data/passview"
SPREAD = 0.10          # uoc luong trung vi (bao cao 01)
SL, OZ, COMM = 0.50, 5.0, 0.30   # SL goc, so ounce cua 0.05 lot, hoa hong moi lenh


def load():
    d = pd.read_csv(DATA / "Tradelogdca_deals.csv", dtype={"comment": str})
    ins = d[d.entry == "IN"].set_index("position_id")
    outs = d[d.entry != "IN"].set_index("position_id")
    pos = pd.DataFrame({"side": ins.type, "ms_in": ins.time_msc, "p_in": ins.price,
                        "p_out": outs.price, "reason": outs.reason})
    sgn = np.where(pos.side == "BUY", 1, -1)
    pos["gain_that"] = ((pos.p_out - pos.p_in) * sgn).round(2)
    pos["day"] = pd.to_datetime(pos.ms_in, unit="ms").dt.date
    d = d.sort_values("time_msc")
    t = d.time_msc.to_numpy()
    bid = np.where(d.type == "SELL", d.price, d.price - SPREAD)
    ask = np.where(d.type == "BUY", d.price, d.price + SPREAD)
    return pos[pos.reason == "DEAL_REASON_SL"].copy(), t, bid, ask


def exit_gain(side, ms_in, p_in, t, bid, ask, tp, trail):
    """Tra ve lai (don vi gia) khi thoat; None neu het du lieu truoc khi thoat."""
    i = np.searchsorted(t, ms_in, "right")
    px = bid[i:] if side == "BUY" else ask[i:]
    g = (px - p_in) if side == "BUY" else (p_in - px)       # lai tai tung diem gia
    stop = -SL
    for x in g:
        if x <= stop + 1e-9:
            return stop
        if tp and x >= tp - 1e-9:
            return tp
        if trail and x >= SL - 1e-9:
            stop = max(stop, round(x - SL, 2))
    return None


def summarize(gains):
    g = pd.Series(gains).dropna()
    net = g * OZ - COMM
    w, l = net[net > 0], net[net <= 0]
    return {"lenh": len(g), "win_%": round(len(w) / len(g) * 100, 1), "TB_thang_$": round(w.mean(), 2),
            "TB_thua_$": round(l.mean(), 2), "PF": round(w.sum() / -l.sum(), 3), "lai_rong_$": round(net.sum(), 0),
            "$/lenh": round(net.mean(), 3)}


def main():
    pd.set_option("display.width", 220)
    pos, t, bid, ask = load()
    rules = [("Passview: trailing 0.50 (mo phong)", 0, True),
             ("Chot +1.00 (5$) + van trailing", 1.0, True),
             ("Chot +2.00 (10$) + van trailing", 2.0, True),
             ("Chot +1.00 (5$), KHONG trailing", 1.0, False),
             ("Chot +1.50 (7.5$), KHONG trailing", 1.5, False),
             ("Chot +2.00 (10$), KHONG trailing", 2.0, False)]
    sims = {}
    for name, tp, trail in rules:
        sims[name] = [exit_gain(r.side, r.ms_in, r.p_in, t, bid, ask, tp, trail) for r in pos.itertuples()]

    # 1) kiem chung bo mo phong bang quy tac that cua Passview
    sim0 = pd.Series(sims[rules[0][0]], index=pos.index, dtype=float)
    ok = sim0.notna()
    exact = (sim0[ok] - pos.gain_that[ok]).abs() <= 0.01
    print(f"KIEM CHUNG: mo phong lai quy tac Passview tren {ok.sum()} lenh: "
          f"trung dung muc thoat {exact.mean() * 100:.1f}%, "
          f"lech TB {(sim0[ok] - pos.gain_that[ok]).mean():+.3f} gia/lenh")
    print("  that   :", summarize(pos.gain_that[ok]))
    print("  mo phong:", summarize(sim0[ok]))

    # 2) cac cach chot khac, theo tung ngay (T6 = 25/09, T2 = 28/09)
    rows = [{"cach_thoat": "THAT (Passview)", "ngay": "ca 2", **summarize(pos.gain_that[ok])}]
    for name, _, _ in rules:
        s = pd.Series(sims[name], index=pos.index, dtype=float)
        rows.append({"cach_thoat": name, "ngay": "ca 2", **summarize(s[ok])})
        for day, lab in zip(sorted(pos.day.unique()), ("T6", "T2")):
            m = ok & (pos.day == day)
            rows.append({"cach_thoat": name, "ngay": lab, **summarize(s[m])})
    out = pd.DataFrame(rows)
    print()
    print(out.to_string(index=False))
    out.to_csv(ROOT / "docs/passview_dca/ket_qua/thu_cach_chot.csv", index=False)

    # 3) CHINH XAC tu ket qua that (khong mo phong): giu trailing, them chot co dinh +X.
    #    Lenh da kich hoat trailing co dinh lai = SL cuoi + 0.50 -> dinh >= X thi thoat o X, nguoc lai giu ket qua that.
    real = pos.gain_that[ok]
    pk = real.where(real >= 0) + SL
    rows = []
    for x in (1.0, 1.5, 2.0, 3.0):
        g = real.where(~(pk >= x), x)
        for lab, m in (("ca 2", slice(None)),) + tuple(zip(("T6", "T2"), [pos.day[ok] == dd for dd in sorted(pos.day.unique())])):
            rows.append({"chot_them": f"+{x:.2f} ({x * OZ:.1f}$)", "ngay": lab, **summarize(g[m])})
    ex = pd.DataFrame(rows)
    print("\nCHINH XAC tu log: giu trailing 0.50, them chot co dinh (so sanh voi THAT 3215$, PF 1.318):")
    print(ex.to_string(index=False))
    ex.to_csv(ROOT / "docs/passview_dca/ket_qua/chot_co_dinh_chinh_xac.csv", index=False)

    # 4) vi sao chot co dinh lai bot: lenh da cham +TP roi chay tiep bao xa?
    peak = pos.gain_that.where(pos.gain_that >= 0) + SL      # dinh lai = SL cuoi + 0.50 (theo quy tac trailing)
    for tp in (1.0, 2.0):
        hit = peak >= tp
        print(f"\nLenh dat dinh >= +{tp:.2f}: {hit.sum()} ({hit.mean() * 100:.1f}%). Voi trailing thuc te chung thoat o "
              f"TB +{pos.gain_that[hit].mean():.2f} gia; chot co dinh chi lay +{tp:.2f}.")


if __name__ == "__main__":
    main()
