"""Drive the live bot through a fake MT5 and check it trades like the backtest.

    python tests/test_live_vs_backtest.py [data.csv] [--bars 12000]
"""

import argparse
import logging
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
sys.path.insert(0, HERE)

from fake_mt5 import FakeMT5  # noqa: E402
from goldbot.config import Config  # noqa: E402
from goldbot.data import load_bars  # noqa: E402
from goldbot.engine import Backtester  # noqa: E402
from goldbot.live import LiveTrader  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("data", nargs="?", default=os.path.join(os.path.dirname(HERE), "data", "DEMO_XAUUSD_M5.csv"))
    ap.add_argument("--bars", type=int, default=12000)
    ap.add_argument("--history", type=int, default=2000)
    args = ap.parse_args()
    logging.basicConfig(level=logging.WARNING)

    bars = load_bars(args.data, verbose=False).tail(args.bars)
    tmp = tempfile.mkdtemp()
    cfg = Config(dict(symbol="XAUUSD", live=dict(log_dir=tmp, history_bars=args.history)))

    # --- live bot on a fake terminal, starting once it has `history` bars of history
    fake = FakeMT5(bars, start=args.history)
    bot = LiveTrader(cfg, fake, sleep=lambda s: None)
    bot.connect()
    while True:
        bot.step()
        if not fake.advance():
            break
    live = [(d.time - d.time % 300, d.type) for d in fake.deals if d.entry == 0]

    # --- backtest on the same bars, entries only after the same warm-up
    bt = Backtester(bars, cfg.make_strategy(), risk=cfg.risk, trade_from=bars.t[args.history]).run()
    back = [(p.open_t, 0 if p.buy else 1) for p in bt.trades]

    ls, bs = set(live), set(back)
    both = ls & bs
    print("Lenh backtest: %d | lenh bot live: %d | trung khop: %d" % (len(bs), len(ls), len(both)))
    print("Ty le khop: %.1f%%" % (100.0 * len(both) / max(1, len(ls | bs))))
    print("Von cuoi backtest $%.2f | bot live $%.2f" % (bt.balance, fake.balance))
    only_b, only_l = sorted(bs - ls)[:5], sorted(ls - bs)[:5]
    if only_b or only_l:
        print("Chi co o backtest:", only_b)
        print("Chi co o live    :", only_l)
    assert len(both) >= 0.9 * max(len(ls), len(bs)), "Bot live lech qua nhieu so voi backtest"
    print("OK - bot live giao dich giong backtest")


if __name__ == "__main__":
    main()
