"""Tai du lieu truc tiep tu terminal MT5 dang dang nhap (Windows).

Can:  pip install MetaTrader5   va MT5 dang mo, da dang nhap tai khoan (demo cung duoc).

    python download_mt5.py --symbol XAUUSD --days 180                # nen M1 -> data/XAUUSD_M1.csv
    python download_mt5.py --symbol XAUUSDr --days 30 --ticks        # tick that -> data/XAUUSDr_ticks.csv

Neu broker gioi han so nen tai ve, tang "Max bars in chart" trong
Tools > Options > Charts cua MT5 (dat Unlimited) roi chay lai.
"""

import argparse
import csv
import os
import sys
from datetime import datetime, timedelta, timezone


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--symbol", default="XAUUSD")
    ap.add_argument("--days", type=int, default=180)
    ap.add_argument("--ticks", action="store_true", help="Tai tick thay vi nen M1 (nang hon nhieu)")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    try:
        import MetaTrader5 as mt5
    except ImportError:
        sys.exit("Chua cai MetaTrader5. Chay: pip install MetaTrader5  (chi co tren Windows)")

    if not mt5.initialize():
        sys.exit("Khong ket noi duoc MT5: %s. Hay mo MT5 va dang nhap truoc." % (mt5.last_error(),))
    try:
        if not mt5.symbol_select(args.symbol, True):
            sys.exit("Khong tim thay symbol %s. Kiem tra ten trong Market Watch (vd XAUUSDr, XAUUSDm, GOLD)." % args.symbol)
        info = mt5.symbol_info(args.symbol)
        print("Symbol %s: digits=%d point=%s contract=%s" % (args.symbol, info.digits, info.point, info.trade_contract_size))

        # MT5 Python API nhan datetime UTC nhung tra ve thoi gian server - dung nguyen gia tri do.
        end = datetime.now(timezone.utc) + timedelta(days=1)
        start = end - timedelta(days=args.days + 1)
        os.makedirs("data", exist_ok=True)

        if args.ticks:
            out = args.out or os.path.join("data", "%s_ticks.csv" % args.symbol)
            ticks = mt5.copy_ticks_range(args.symbol, start, end, mt5.COPY_TICKS_ALL)
            if ticks is None or len(ticks) == 0:
                sys.exit("Khong tai duoc tick: %s" % (mt5.last_error(),))
            with open(out, "w", newline="") as f:
                w = csv.writer(f)
                w.writerow(["time_msc", "bid", "ask"])
                for t in ticks:
                    w.writerow([int(t["time_msc"]), t["bid"] or "", t["ask"] or ""])
            print("Da luu %d tick -> %s" % (len(ticks), out))
        else:
            out = args.out or os.path.join("data", "%s_M1.csv" % args.symbol)
            rates = mt5.copy_rates_range(args.symbol, mt5.TIMEFRAME_M1, start, end)
            if rates is None or len(rates) == 0:
                sys.exit("Khong tai duoc nen: %s" % (mt5.last_error(),))
            with open(out, "w", newline="") as f:
                w = csv.writer(f)
                w.writerow(["time", "open", "high", "low", "close", "tick_volume", "spread"])
                for r in rates:
                    w.writerow([int(r["time"]), r["open"], r["high"], r["low"], r["close"],
                                int(r["tick_volume"]), int(r["spread"])])
            print("Da luu %d nen M1 -> %s" % (len(rates), out))
        print("Tiep theo: python run_backtest.py %s --point %s" % (out, info.point))
    finally:
        mt5.shutdown()


if __name__ == "__main__":
    main()
