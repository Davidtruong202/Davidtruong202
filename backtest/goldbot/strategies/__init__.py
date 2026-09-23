"""Strategy registry. Every strategy here runs in both the backtester and the live bot."""

from .breakout import SessionBreakout
from .meanrev import MeanReversion
from .pullback import TrendPullback
from .scalper import Scalper

STRATEGIES = {s.key: s for s in (SessionBreakout, TrendPullback, MeanReversion, Scalper)}
