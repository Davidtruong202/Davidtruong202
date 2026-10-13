"""Doc file ctxbars lon (M1) tiet kiem bo nho: tra ve dict cot -> list (float/None)."""
import csv
from array import array
NAN=float("nan")
def load(path, prefix):
    with open(path, encoding="utf-8-sig", newline="") as fh:
        r=csv.reader(fh); hdr=next(r)
        want=["bar_time","open","high","low","close","tick_volume"]+[h for h in hdr if h.startswith(prefix)]
        idx=[hdr.index(w) for w in want]
        cols={w:([] if w=="bar_time" else array("d")) for w in want}
        for row in r:
            for w,i in zip(want,idx):
                v=row[i]
                if w=="bar_time": cols[w].append(v)
                else: cols[w].append(float(v) if v!="" else NAN)
    return cols
