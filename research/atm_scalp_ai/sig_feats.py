import csv, sys, statistics as st
sys.path.insert(0, __import__("os").path.join(__import__("os").path.dirname(__import__("os").path.abspath(__file__)), "..", "phan_tich_ea"))
import quet_khung as Q
rows=list(csv.DictReader(open(sys.argv[1],encoding="utf-8-sig")))
P="i_U1_DTRADE____ATM_SCALP_AI_M5_b"
o=[float(r["open"]) for r in rows]; h=[float(r["high"]) for r in rows]; l=[float(r["low"]) for r in rows]; c=[float(r["close"]) for r in rows]
v=[float(r["tick_volume"]) for r in rows]
def buf(b): return [float(r[P+str(b)]) if r[P+str(b)] else None for r in rows]
b=[buf(i) for i in range(21)]
E={p:Q.ema(c,p) for p in (9,14,21,34,55)}
# test b17/b18 as volume ratios
W=range(2000,len(rows))
def err(a,t):
    d=[abs(a[i]-t[i]) for i in W if a[i] is not None and t[i] is not None]; return st.median(d)
best=[]
for p in range(2,60):
    s=Q.sma(v,p); e=Q.ema(v,p)
    best.append((err([v[i]/s[i] if s[i] else None for i in range(len(v))],b[17]),f"vol/SMA{p}"))
    best.append((err([v[i]/e[i] if e[i] else None for i in range(len(v))],b[17]),f"vol/EMA{p}"))
    best.append((err([v[i]/s[i-1] if i and s[i-1] else None for i in range(len(v))],b[17]),f"vol/SMA{p}prev"))
best.sort(); print("b17:",best[:3])
best=[x for x in best]; 
best2=[]
for p in range(2,60):
    s=Q.sma(v,p); e=Q.ema(v,p)
    best2.append((err([v[i]/s[i] if s[i] else None for i in range(len(v))],b[18]),f"vol/SMA{p}"))
    best2.append((err([v[i]/s[i-1] if i and s[i-1] else None for i in range(len(v))],b[18]),f"vol/SMA{p}prev"))
best2.sort(); print("b18:",best2[:3])
start=next(i for i in range(len(rows)) if b[2][i] is not None and b[2][i]!=0)
sig=[i for i in range(start,len(rows)) if b[0][i] is not None or b[1][i] is not None]
print("signals",len(sig),"BUY",sum(1 for i in sig if b[0][i] is not None),"SELL",sum(1 for i in sig if b[1][i] is not None))
def feats(i,d):
    return {
     "trend(b20)==dir": b[20][i]==d,
     "ADX": round(b[19][i],1),
     "c>EMA9 (dir)": (c[i]-E[9][i])*d>0,
     "cross EMA9": (c[i]-E[9][i])*d>0 and (c[i-1]-E[9][i-1])*d<=0,
     "EMA9>EMA21 (dir)": (E[9][i]-E[21][i])*d>0,
     "EMA9 cross EMA21": (E[9][i]-E[21][i])*d>0 and (E[9][i-1]-E[21][i-1])*d<=0,
     "nen cung chieu": (c[i]-o[i])*d>0,
     "b17": round(b[17][i],2), "b18": round(b[18][i],2),
     "flat truoc": b[2][i-1]==0,
    }
import collections
agg=collections.defaultdict(list)
for i in sig:
    d=1 if b[0][i] is not None else -1
    for k,x in feats(i,d).items(): agg[k].append(x)
print("--- tai nen tin hieu ---")
for k,xs in agg.items():
    if isinstance(xs[0],bool): print(f"{k:22s} {sum(xs)}/{len(xs)}")
    else: print(f"{k:22s} min {min(xs)} p10 {sorted(xs)[len(xs)//10]} med {st.median(xs)} max {max(xs)}")
# baseline: bars in window with trend==dir, flat before, not signal
base=collections.defaultdict(list)
for i in range(start,len(rows)):
    if i in sig: continue
    d=b[20][i]
    for k,x in feats(i,d).items(): base[k].append(x)
print("--- moi nen khac trong cung giai doan (lay chieu = trend) ---")
for k,xs in base.items():
    if isinstance(xs[0],bool): print(f"{k:22s} {sum(xs)/len(xs):.1%}")
    else: print(f"{k:22s} med {st.median(xs)}")
# bao nhieu nen thoa du 5 dieu kien can ma khong co tin hieu?
def cond(i,d):
    return b[20][i]==d and b[19][i]>20 and (c[i]-E[9][i])*d>0 and (E[9][i]-E[21][i])*d>0 and (c[i]-o[i])*d>0
allc=[i for i in range(start,len(rows)) for d in (1,-1) if cond(i,d)]
flat_c=[i for i in range(start,len(rows)) for d in (1,-1) if cond(i,d) and b[2][i-1]==0]
first_c=[i for i in range(start,len(rows)) for d in (1,-1) if cond(i,d) and b[2][i-1]==0 and not cond(i-1,d)]
s=set(sig)
print("nen thoa 5 dieu kien:",len(allc),"trong do co tin hieu:",len(s&set(allc)))
print("  + dang khong co lenh:",len(flat_c),"co tin hieu:",len(s&set(flat_c)))
print("  + nen dau tien thoa:",len(first_c),"co tin hieu:",len(s&set(first_c)))
