"""Virtual wallets (direction x session) and statistics, as MatrixSignal()/MXOpen()/MXStatClose().

Each configuration ("engine") gets 12 independent wallets: direction {0 both, 1 BUY, 2 SELL} x
session {0 all, 1 Asia, 2 Europe, 3 America}; wallet id inside the engine = direction*4 + session.
A wallet holds at most one position of the family at a time (InpMatrixLenhMoiPP = 1); a
position closing on tick j frees the slot for a signal on the same tick j (positions are
managed before engines run).
"""
import numpy as np

from .config import session_table

DIR_NAMES = {0: "BUY_SELL", 1: "BUY", 2: "SELL"}
SES_NAMES = {0: "TAT_CA", 1: "A", 2: "AU", 3: "MY"}


def assign_wallets(sig, res, ticks_t, cfg, split_t=None):
    """Returns list of 12 dicts with the trade indices taken by each wallet and its statistics."""
    ses_tab, _ = session_table(cfg)
    n = len(sig["i0"])
    hours = (ticks_t[sig["i0"]] % 86400) // 3600 if n else np.zeros(0, int)
    sessions = np.array([ses_tab[h] for h in hours], int) if n else np.zeros(0, int)
    order = np.argsort(sig["i0"], kind="stable")
    out = []
    for d in range(3):
        for s in range(4):
            taken = []
            busy_until = -1
            for k in order:
                if not res["ok"][k]:
                    continue
                buy = bool(sig["buy"][k])
                if d == 1 and not buy:
                    continue
                if d == 2 and buy:
                    continue
                if s != 0 and sessions[k] != s:
                    continue
                if sig["i0"][k] < busy_until:
                    continue
                taken.append(k)
                busy_until = res["exit_i"][k]
            out.append({"dir": d, "ses": s, "idx": np.array(taken, np.int64)})
    return out


def stats(idx, sig, res, money_per_pt, capital, ticks_t, split_t=None):
    """Statistics of one wallet. money_per_pt converts price-units x lot-fraction into account money."""
    st = {"lenh": 0, "thang": 0, "thua": 0, "hoa": 0, "net": 0.0, "pf": 0.0, "wr": 0.0, "avg_r": 0.0,
          "dd_tien": 0.0, "dd_pct": 0.0, "dd_equity_tien": 0.0, "thua_lien_tiep": 0, "lenh_ep_dong": 0,
          "tb_thang": 0.0, "tb_thua": 0.0, "net_a": 0.0, "lenh_a": 0, "wr_a": 0.0, "net_b": 0.0, "lenh_b": 0,
          "wr_b": 0.0, "tp2": 0, "sl_goc": 0, "be_trail": 0}
    if len(idx) == 0:
        return st
    net = res["net"][idx] * money_per_pt
    risk = res["risk"][idx]
    r_mult = res["net"][idx] / risk
    wins = net > 1e-8
    losses = net < -1e-8
    st["lenh"] = int(len(idx))
    st["thang"] = int(wins.sum())
    st["thua"] = int(losses.sum())
    st["hoa"] = st["lenh"] - st["thang"] - st["thua"]
    st["net"] = float(net.sum())
    gw = float(net[wins].sum())
    gl = float(-net[losses].sum())
    st["pf"] = gw / gl if gl > 0 else (float("inf") if gw > 0 else 0.0)
    st["wr"] = 100.0 * st["thang"] / st["lenh"]
    st["avg_r"] = float(r_mult.mean())
    st["tb_thang"] = float(net[wins].mean()) if wins.any() else 0.0
    st["tb_thua"] = float(net[losses].mean()) if losses.any() else 0.0
    reason = res["reason"][idx]
    st["tp2"] = int((reason == 1).sum())
    st["lenh_ep_dong"] = int((reason == 2).sum())
    st["sl_goc"] = int(((reason == 0) & ~res["partial"][idx]).sum())
    st["be_trail"] = int(((reason == 0) & res["partial"][idx]).sum())
    streak = mx = 0
    for w, l in zip(wins, losses):
        if l:
            streak += 1
            mx = max(mx, streak)
        else:
            streak = 0
    st["thua_lien_tiep"] = mx
    bal = capital + np.cumsum(net)
    peak = np.maximum.accumulate(np.r_[capital, bal])[:-1]
    before = np.r_[capital, bal[:-1]]
    dd_bal = np.max(np.maximum.accumulate(np.r_[capital, bal]) - np.r_[capital, bal])
    worst_eq = before - res["mae_full"][idx] * money_per_pt
    dd_eq = np.max(np.maximum(peak - worst_eq, 0.0)) if len(idx) else 0.0
    st["dd_tien"] = float(dd_bal)
    st["dd_equity_tien"] = float(max(dd_bal, dd_eq))
    st["dd_pct"] = float(100.0 * st["dd_equity_tien"] / max(capital, 1e-9))
    if split_t is not None:
        t_in = ticks_t[sig["i0"][idx]]
        a = t_in < split_t
        for tag, mask in (("a", a), ("b", ~a)):
            if mask.any():
                st["net_" + tag] = float(net[mask].sum())
                st["lenh_" + tag] = int(mask.sum())
                st["wr_" + tag] = float(100.0 * wins[mask].sum() / mask.sum())
    return st
