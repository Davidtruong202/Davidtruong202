"""Sinh bộ SET ngẫu nhiên cho V710 (chỉ dùng input có trong mã nguồn V710).

python3 gen_sets.py N seed > sets.csv
Lot khởi đầu cố định 0.02 (như set710taikhoan20k) để các ngưỡng tiền so sánh được; lot được thử riêng ở bước cuối.
"""
import random
import sys

COLS = ["name", "Hand_FirstDist", "Hand_MinDist1", "Hand_AddGap1", "Hand_MinDist2", "Hand_AddGap2", "Hand_OrderThresh",
        "Hand_MoveStep", "Hand_InitLot", "Hand_AddLotMult", "Hand_SideTP", "Hand_SideSL", "Hand_AllStopLoss",
        "Hand_PauseLoss", "NetClosePL", "EA_StartTime", "EA_StopTime", "InpBasketMaxLoss", "InpHardSLATR",
        "InpFlattenOnClose", "InpMaxLayers", "InpMaxTotalLots", "InpDailyLossLimit", "InpPeakRetracePct",
        "InpSpikeEnable", "InpSpikeUSD", "InpSpikePauseMin", "InpSpikeRemovePend", "MaxLot", "DailyProfitTarget"]

SET20K = dict(Hand_FirstDist=70, Hand_MinDist1=100, Hand_AddGap1=110, Hand_MinDist2=140, Hand_AddGap2=160,
              Hand_OrderThresh=6, Hand_MoveStep=50, Hand_InitLot=0.02, Hand_AddLotMult=1.15, Hand_SideTP=250,
              Hand_SideSL=1000, Hand_AllStopLoss=150, Hand_PauseLoss=1500, NetClosePL=250, EA_StartTime="03:00",
              EA_StopTime="15:00", InpBasketMaxLoss=0, InpHardSLATR=0, InpFlattenOnClose="true", InpMaxLayers=0,
              InpMaxTotalLots=100, InpDailyLossLimit=0, InpPeakRetracePct=100, InpSpikeEnable="false", InpSpikeUSD=3.0,
              InpSpikePauseMin=30, InpSpikeRemovePend="true", MaxLot=10, DailyProfitTarget=0)


def rnd(r):
    def pick(*a):
        return r.choice(a)

    def off_or(p_off, lo, hi, step, off=0):
        return off if r.random() < p_off else round(r.randrange(lo, hi + 1, step), 2)

    d = dict(SET20K)
    d["Hand_FirstDist"] = r.randrange(30, 161, 10)
    d["Hand_MinDist1"] = r.randrange(50, 221, 10)
    d["Hand_AddGap1"] = r.randrange(50, 261, 10)
    d["Hand_MinDist2"] = r.randrange(80, 321, 20)
    d["Hand_AddGap2"] = r.randrange(80, 361, 20)
    d["Hand_OrderThresh"] = r.randrange(2, 11)
    d["Hand_MoveStep"] = r.randrange(20, 121, 10)
    d["Hand_AddLotMult"] = pick(1.0, 1.05, 1.1, 1.15, 1.2, 1.3, 1.4, 1.5)
    d["Hand_SideTP"] = r.randrange(50, 801, 25)
    d["Hand_SideSL"] = r.randrange(200, 3001, 100)
    d["Hand_AllStopLoss"] = r.randrange(50, 601, 25)
    d["Hand_PauseLoss"] = r.randrange(300, 3001, 100)
    d["NetClosePL"] = off_or(0.15, 50, 800, 25)
    d["EA_StartTime"] = "%02d:00" % r.randrange(0, 11)
    d["EA_StopTime"] = "%02d:00" % r.randrange(12, 22)
    d["InpBasketMaxLoss"] = off_or(0.4, 300, 4000, 100)
    d["InpHardSLATR"] = pick(0, 0, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 6.0)
    d["InpMaxLayers"] = pick(0, 0, 3, 4, 5, 6, 7, 8, 10, 12, 15)
    d["InpMaxTotalLots"] = pick(100, 100, 0.2, 0.3, 0.5, 0.8, 1.2, 2.0)
    d["InpDailyLossLimit"] = off_or(0.4, 300, 4000, 100)
    d["InpPeakRetracePct"] = pick(10, 20, 30, 50, 70, 100)
    d["InpSpikeEnable"] = pick("true", "false")
    d["InpSpikeUSD"] = pick(2.0, 3.0, 4.0, 5.0, 6.0, 8.0)
    d["InpSpikePauseMin"] = pick(10, 20, 30, 45, 60)
    d["InpSpikeRemovePend"] = pick("true", "false")
    d["MaxLot"] = pick(10, 10, 0.05, 0.08, 0.1, 0.2, 0.5)
    d["DailyProfitTarget"] = off_or(0.6, 200, 4000, 100)
    return d


def write(rows, f=sys.stdout):
    f.write(",".join(COLS) + "\n")
    for d in rows:
        f.write(",".join(str(d[c]) for c in COLS) + "\n")


if __name__ == "__main__":
    n, seed = int(sys.argv[1]), int(sys.argv[2])
    r = random.Random(seed)
    rows = [dict(SET20K, name="set710taikhoan20k")]
    for i in range(n):
        d = rnd(r)
        d["name"] = "r%d_%05d" % (seed, i)
        rows.append(d)
    write(rows)
