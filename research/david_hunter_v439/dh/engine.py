"""Run one configuration of one family end to end: signals -> trades -> 12 wallets -> stats."""
import numpy as np

from .config import FAMILY_TF_KEY, session_table
from .matrix import DIR_NAMES, SES_NAMES, assign_wallets, stats
from .signals_ema import ema_signals
from .signals_pv import pv_signals
from .signals_setup import ict_signals, mm_signals, smc_signals


def family_signals(market, ind, cfg, family):
    if family == "EMA":
        return ema_signals(market, ind, cfg)
    if family == "ICT":
        return ict_signals(market, ind, cfg)
    if family == "MM":
        return mm_signals(market, ind, cfg)
    if family == "SMC":
        return smc_signals(market, ind, cfg)
    return pv_signals(market, ind, cfg, family)


def check_sessions(cfg):
    ses, _ = session_table(cfg)
    if any(s == 0 for s in ses):
        raise ValueError("V4.39 LAB enables all three sessions over 0-24h; partial coverage is not modelled")


class Runner:
    def __init__(self, market, ind, sim, capital=1000.0, split_t=None, start_t=None):
        self.m = market
        self.ind = ind
        self.sim = sim
        self.capital = capital
        self.split_t = split_t
        self.start_t = start_t  # optional: ignore signals before this time (indicator warm-up)
        self.money_per_pt = sim.lot * market.contract

    def run(self, family, cfg, label=""):
        check_sessions(cfg)
        sig = family_signals(self.m, self.ind, cfg, family)
        if self.start_t is not None and len(sig["i0"]):
            keep = self.m.ticks.t[sig["i0"]] >= self.start_t
            for k in ("i0", "buy", "entry", "sl", "tp", "model"):
                if k in sig:
                    sig[k] = sig[k][keep]
        res = self.sim.run(sig)
        wallets = assign_wallets(sig, res, self.m.ticks.t, cfg, self.split_t)
        rows = []
        for w in wallets:
            st = stats(w["idx"], sig, res, self.money_per_pt, self.capital, self.m.ticks.t, self.split_t)
            st.update({"pp": family, "cau_hinh": label, "khung": cfg[FAMILY_TF_KEY[family]],
                       "huong": DIR_NAMES[w["dir"]], "phien": SES_NAMES[w["ses"]], "vi": w["dir"] * 4 + w["ses"],
                       "tin_hieu": int(len(sig["i0"]))})
            rows.append(st)
        return rows, sig, res, wallets
