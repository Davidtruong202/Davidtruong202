"""Gold Bot - giao dich tu dong tren MT5 (Windows) bang dung chien luoc da backtest.

    pip install MetaTrader5
    copy config.example.json config.json   (roi sua symbol, rui ro...)
    python live_bot.py --config config.json

MT5 phai dang mo va dang nhap. Mac dinh bot CHI chay tai khoan demo.
Dung bot: Ctrl+C (lenh dang mo van giu SL/TP tren san).
"""

import argparse
import logging
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from goldbot.config import Config  # noqa: E402
from goldbot.live import LiveTrader  # noqa: E402


def main():
    ap = argparse.ArgumentParser(description="Gold Bot live trading (MT5)")
    ap.add_argument("--config", default="config.json")
    ap.add_argument("--dry-run", action="store_true", help="Chi ghi log tin hieu, khong dat lenh")
    args = ap.parse_args()

    if not os.path.exists(args.config):
        sys.exit("Khong thay %s. Copy config.example.json thanh config.json roi sua." % args.config)
    cfg = Config.load(args.config)
    if args.dry_run:
        cfg.live["dry_run"] = True

    os.makedirs(cfg.live["log_dir"], exist_ok=True)
    fmt = logging.Formatter("%(asctime)s %(levelname)-7s %(message)s")
    root = logging.getLogger()
    root.setLevel(logging.INFO)
    for h in (logging.StreamHandler(),
              logging.FileHandler(os.path.join(cfg.live["log_dir"], "bot_%s.log" % cfg.symbol), encoding="utf-8")):
        h.setFormatter(fmt)
        root.addHandler(h)

    try:
        import MetaTrader5 as mt5
    except ImportError:
        sys.exit("Chua cai MetaTrader5. Chay: pip install MetaTrader5  (chi co tren Windows)")

    try:
        LiveTrader(cfg, mt5).run_forever()
    except RuntimeError as e:
        logging.error("%s", e)
        sys.exit(1)


if __name__ == "__main__":
    main()
