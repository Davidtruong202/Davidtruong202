"""Strategy registry. Every strategy here runs in both the backtester and the live bot."""

from .breakout import SessionBreakout

STRATEGIES = {SessionBreakout.key: SessionBreakout}
