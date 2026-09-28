"""Describe BTCUSDc market characteristics relevant to timeframe / cost choices."""
import os

import numpy as np
import pandas as pd

import data
import indicators as ind

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")


def main():
    os.makedirs(OUT, exist_ok=True)
    m1 = data.load_m1()
    rows = []
    for tf, rule in (("M1", "1min"), ("M5", "5min"), ("M15", "15min"), ("H1", "1h")):
        b = m1 if tf == "M1" else data.resample(m1, rule)
        a = ind.atr(b, 14)
        sp = b.spread * data.POINT
        for yr, g in b.groupby(b.index.year):
            ay = a.loc[g.index]
            rows.append({
                "tf": tf, "year": yr,
                "atr_usd_median": ay.median(),
                "atr_pct_of_price": (ay / g.close).median() * 100,
                "spread_usd_median": sp.loc[g.index].median(),
                "spread_over_atr": (sp.loc[g.index] / ay).median(),
            })
        # Return autocorrelation: >0 = continuation, <0 = mean reversion
        r = np.log(b.close).diff().dropna()
        rows.append({"tf": tf, "year": "lag1_autocorr", "atr_usd_median": r.autocorr(1)})
    prof = pd.DataFrame(rows)
    prof.to_csv(os.path.join(OUT, "profile_by_tf_year.csv"), index=False)

    h1 = data.resample(m1, "1h")
    rng_pct = (h1.high - h1.low) / h1.close * 100
    hourly = rng_pct.groupby(h1.index.hour).median().rename("h1_range_pct_median")
    hourly.to_csv(os.path.join(OUT, "profile_hourly_range.csv"))
    dow = rng_pct.groupby(h1.index.dayofweek).median().rename("h1_range_pct_median")
    dow.index = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    dow.to_csv(os.path.join(OUT, "profile_weekday_range.csv"))

    # Weekend gap risk: CFD is quoted 24/7 at this broker, measure largest M1 gaps
    gaps = (m1.open - m1.close.shift(1)).abs() / m1.close.shift(1) * 100
    gap_stats = gaps.describe(percentiles=[0.99, 0.999]).rename("m1_open_gap_pct")
    gap_stats.to_csv(os.path.join(OUT, "profile_gaps.csv"))

    # Regime shares on H1
    f = ind.add_features(h1)
    reg = pd.Series({
        "trending_adx25": (f.adx >= 25).mean() * 100,
        "ranging_adx20": (f.adx < 20).mean() * 100,
        "high_vol_atrpct70": (f.atr_pct >= 0.7).mean() * 100,
        "low_vol_atrpct30": (f.atr_pct <= 0.3).mean() * 100,
    }, name="share_of_h1_bars_pct")
    reg.to_csv(os.path.join(OUT, "profile_regimes_h1.csv"))

    print(prof.round(4).to_string())
    print(hourly.round(3).to_string())
    print(dow.round(3).to_string())
    print(gap_stats.round(4).to_string())
    print(reg.round(1).to_string())


if __name__ == "__main__":
    main()
