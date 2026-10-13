import csv, sys
path=sys.argv[1]
rows=list(csv.DictReader(open(path,encoding="utf-8-sig")))
P="i_U1_DTRADE____ATM_SCALP_AI_M5_b"
def g(r,b):
    v=r[P+str(b)]
    return float(v) if v not in ("",None) else None
# print rows around first signals
start=next(i for i,r in enumerate(rows) if g(r,0) is not None or g(r,1) is not None)
print("first signal row", start, rows[start]["bar_time"])
hdr="time                 close     b0        b1        b2  b3        b4        b5        b6        b7        b8        b9  b20 b11      b14"
print(hdr)
cnt=0
for i in range(start-3, len(rows)):
    r=rows[i]
    v=[g(r,b) for b in range(21)]
    show = v[0] is not None or v[1] is not None or (i>0 and g(rows[i-1],2)!=v[2]) or (i>0 and g(rows[i-1],20)!=v[20])
    if show:
        fm=lambda x: f"{x:9.3f}" if x is not None else "    -    "
        print(r["bar_time"], f"{float(r['close']):9.3f}", fm(v[0]),fm(v[1]), f"{v[2]:3.0f}" if v[2] is not None else " - ", fm(v[3]),fm(v[4]),fm(v[5]),fm(v[6]),fm(v[7]), fm(v[8]), (f"{v[9]:3.0f}" if v[9] is not None else " - "), f"{v[20]:3.0f}", fm(v[11]), fm(v[14]))
        cnt+=1
    if cnt>45: break
