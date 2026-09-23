"""One JSON config drives both the backtest and the live bot (see config.example.json)."""

import json
from dataclasses import fields, asdict

from .common import Account
from .engine import RiskParams
from .strategies import STRATEGIES

DEFAULT_LIVE = dict(
    magic=26092301,
    poll_seconds=1.0,
    history_bars=3000,
    deviation_points=30,
    allow_real_account=False,   # safety: refuse to trade a real account unless set to true
    dry_run=False,              # true = log signals only, send no orders
    log_dir="logs",
    mt5_path="",                # terminal64.exe path; empty = attach to the running terminal
    login=0,
    password="",
    server="",
)


def _coerce(cls, values, where):
    known = {f.name: f.type for f in fields(cls)}
    out = {}
    for k, v in (values or {}).items():
        if k.startswith("_"):
            continue
        if k not in known:
            raise ValueError("%s: khong co tham so '%s'. Co: %s" % (where, k, ", ".join(known)))
        out[k] = convert(known[k], v)
    return cls(**out)


def convert(tp, v):
    if tp in (bool, "bool"):
        return v if isinstance(v, bool) else str(v).strip().lower() in ("1", "true", "yes", "on")
    if tp in (int, "int"):
        return int(float(v))
    if tp in (float, "float"):
        return float(v)
    return v


class Config:
    def __init__(self, data=None):
        data = data or {}
        self.symbol = data.get("symbol", "XAUUSD")
        self.strategy_key = data.get("strategy", "breakout")
        if self.strategy_key not in STRATEGIES:
            raise ValueError("strategy phai la mot trong: %s" % ", ".join(STRATEGIES))
        cls = STRATEGIES[self.strategy_key]
        self.strategy_params = _coerce(cls.Params, data.get("strategy_params"), "strategy_params")
        self.risk = _coerce(RiskParams, data.get("risk"), "risk")
        self.account = _coerce(Account, data.get("backtest_account"), "backtest_account")
        live = dict(DEFAULT_LIVE)
        live.update({k: v for k, v in (data.get("live") or {}).items() if not k.startswith("_")})
        self.live = live

    @classmethod
    def load(cls, path):
        with open(path, encoding="utf-8") as f:
            return cls(json.load(f))

    def make_strategy(self):
        return STRATEGIES[self.strategy_key](self.strategy_params)

    def set_param(self, key, value):
        """--set name=value : strategy param first, then risk param."""
        for obj in (self.strategy_params, self.risk):
            names = {f.name: f.type for f in fields(obj)}
            if key in names:
                setattr(obj, key, convert(names[key], value))
                return
        raise ValueError("Khong co tham so '%s'" % key)

    def to_dict(self):
        return dict(symbol=self.symbol, strategy=self.strategy_key,
                    strategy_params=asdict(self.strategy_params), risk=asdict(self.risk), live=self.live)
