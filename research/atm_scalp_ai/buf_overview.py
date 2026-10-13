import csv, sys, statistics as st
path=sys.argv[1]
rows=list(csv.DictReader(open(path,encoding="utf-8-sig")))
print("rows",len(rows),"from",rows[0]["bar_time"],"to",rows[-1]["bar_time"])
cols=[c for c in rows[0] if c.startswith("i_U1")]
def f(v):
    try: return float(v)
    except: return None
for c in cols:
    vals=[f(r[c]) for r in rows]
    nn=[v for v in vals if v is not None]
    nz=[v for v in nn if v!=0]
    # first/last month with non-empty non-zero
    idx=[i for i,v in enumerate(vals) if v not in (None,0.0)]
    first=rows[idx[0]]["bar_time"][:10] if idx else "-"
    last=rows[idx[-1]]["bar_time"][:10] if idx else "-"
    changes=sum(1 for i in range(1,len(vals)) if vals[i]!=vals[i-1])
    # relation to close
    near=[abs(f(r[c])-f(r["close"])) for r in rows if f(r[c]) not in (None,0.0)]
    pricey = (st.median(near) < 50) if near and st.median(nz or [0])>100 else False
    uniq=len(set(nz))
    print(f"{c[-4:]:>5} nonempty={len(nn)/len(rows):6.1%} nonzero={len(nz)/len(rows):6.1%} uniq={uniq:6d} changes={changes:6d} "
          f"min={min(nz) if nz else '-':>12} med={st.median(nz) if nz else '-':>12} max={max(nz) if nz else '-':>12} "
          f"{'GIA' if pricey else '   '} {first}..{last}")
