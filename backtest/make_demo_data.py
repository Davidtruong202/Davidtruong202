"""Generate SYNTHETIC XAUUSD M5 bars in MT5 "Bars export" format.

Only for trying the bot out before you have real broker data. The price path is
random (session-dependent volatility, trending regimes, occasional news spikes),
so the backtest result on it means nothing about the real market.

    python make_demo_data.py --months 6 --out data/DEMO_XAUUSD_M5.csv
"""

import argparse
import math
import os
import random
from datetime import datetime, timedelta


def ny_hour(server_dt, server_to_ny=7):
    return (server_dt - timedelta(hours=server_to_ny)).hour + server_dt.minute / 60.0


def session_vol(h):
    """Relative volatility by NY hour: quiet Asia, active London, busiest NY open."""
    if 2 <= h < 5:
        return 1.35
    if 7 <= h < 11:
        return 1.7
    if 11 <= h < 16:
        return 1.05
    if 20 <= h or h < 2:
        return 0.55
    return 0.8


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--months", type=int, default=6)
    ap.add_argument("--start", default="2025-03-03")
    ap.add_argument("--price", type=float, default=2900.0)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--out", default=None)
    ap.add_argument("--m1", action="store_true", help="Xuat nen M1 (de thu chien luoc scalping)")
    args = ap.parse_args()

    rnd = random.Random(args.seed)
    t = datetime.strptime(args.start, "%Y-%m-%d")
    end = t + timedelta(days=int(args.months * 30.4))
    price = args.price
    base = 0.00055           # per-bar sigma (fraction of price) at vol 1.0
    drift = 0.0
    regime_left = 0
    args.out = args.out or ("data/DEMO_XAUUSD_M1.csv" if args.m1 else "data/DEMO_XAUUSD_M5.csv")
    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    row = "%s\t%s\t%.2f\t%.2f\t%.2f\t%.2f\t%d\t0\t%d\n"

    n = 0
    with open(args.out, "w", newline="") as f:
        f.write("<DATE>\t<TIME>\t<OPEN>\t<HIGH>\t<LOW>\t<CLOSE>\t<TICKVOL>\t<VOL>\t<SPREAD>\n")
        while t < end:
            wd = t.weekday()
            # MT5 gold hours (server GMT+2/3): Mon 01:00 -> Fri 23:55, daily break 00:00-01:00
            if wd >= 5 or t.hour == 0:
                t += timedelta(minutes=5)
                continue
            if regime_left <= 0:
                regime_left = rnd.randint(150, 1400)
                drift = rnd.gauss(0, 0.00003)
            regime_left -= 1

            h = ny_hour(t)
            sig = base * session_vol(h) * (0.75 + 0.5 * rnd.random())
            if abs(h - 8.5) < 0.05 and rnd.random() < 0.25:
                sig *= 4.5  # 08:30 NY news spike
            o = price
            # walk 5 one-minute steps to get a realistic high/low
            hi = lo = p = o
            minutes = []
            for _ in range(5):
                mo = p
                p *= math.exp(drift / 5 + sig / math.sqrt(5) * rnd.gauss(0, 1))
                # gentle mean reversion keeps swings/EQH-EQL forming
                p += (o - p) * 0.04
                hi, lo = max(hi, p), min(lo, p)
                minutes.append([mo, max(mo, p), min(mo, p), p])
            wick = sig * o * 0.35
            hi += abs(rnd.gauss(0, wick))
            lo -= abs(rnd.gauss(0, wick))
            # put the M5 wicks into one of its minutes, give the rest small wicks
            for m in minutes:
                m[1] += abs(rnd.gauss(0, wick * 0.3))
                m[2] -= abs(rnd.gauss(0, wick * 0.3))
            minutes[rnd.randrange(5)][1] = hi
            minutes[rnd.randrange(5)][2] = lo
            hi = max(m[1] for m in minutes)
            lo = min(m[2] for m in minutes)
            c = p
            price = c
            spread = int(max(8, rnd.gauss(22 if 7 <= h < 16 else 30, 5)))
            vol = int(200 + 1800 * session_vol(h) * rnd.random())
            if args.m1:
                for k, (mo, mh, ml, mc) in enumerate(minutes):
                    tm = t + timedelta(minutes=k)
                    f.write(row % (tm.strftime("%Y.%m.%d"), tm.strftime("%H:%M:%S"), mo, mh, ml, mc, vol // 5,
                                   spread + rnd.randint(-3, 3)))
                    n += 1
            else:
                f.write(row % (t.strftime("%Y.%m.%d"), t.strftime("%H:%M:%S"), o, hi, lo, c, vol, spread))
                n += 1
            t += timedelta(minutes=5)
    print("Da tao %d nen %s gia lap -> %s" % (n, "M1" if args.m1 else "M5", args.out))


if __name__ == "__main__":
    main()
