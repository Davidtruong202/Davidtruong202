import csv, sys, statistics as st
sys.path.insert(0, __import__("os").path.join(__import__("os").path.dirname(__import__("os").path.abspath(__file__)), "..", "phan_tich_ea"))
import quet_khung as Q
rows=list(csv.DictReader(open(sys.argv[1],encoding="utf-8-sig")))
P="i_U1_DTRADE____ATM_SCALP_AI_M5_b"
o=[float(r["open"]) for r in rows]; h=[float(r["high"]) for r in rows]; l=[float(r["low"]) for r in rows]; c=[float(r["close"]) for r in rows]
def buf(b): return [float(r[P+str(b)]) if r[P+str(b)] else None for r in rows]
b=[buf(i) for i in range(21)]
E={p:Q.ema(c,p) for p in (9,14,21,34,55)}
W=range(2000,len(rows))
def agree(pred):
    ok=sum(1 for i in W if pred(i)==b[20][i]); return ok/len(W)
cands={}
for a in (9,14,21,34,55):
    cands[f"close>EMA{a}"]=lambda i,a=a: 1.0 if c[i]>E[a][i] else -1.0
    for d in (9,14,21,34,55):
        if d>a: cands[f"EMA{a}>EMA{d}"]=lambda i,a=a,d=d: 1.0 if E[a][i]>E[d][i] else -1.0
res=sorted(((agree(f),k) for k,f in cands.items()),reverse=True)
print("b20 vs:",res[:5])
print("b9 == (b20==-1)?", sum(1 for i in W if (b[9][i]==1.0)==(b[20][i]==-1.0))/len(W))
# b17/b18/b19: try |close-EMA|, body, DI etc
tr=Q.true_range(h,l,c)
def smma(x,p):
    out=[None]*len(x); v=sum(x[:p])/p; out[p-1]=v
    for i in range(p,len(x)): v=(v*(p-1)+x[i])/p; out[i]=v
    return out
def err(a,t):
    d=[abs(a[i]-t[i]) for i in W if a[i] is not None and t[i] is not None]; return st.median(d)
cand2={}
for p in (9,14,21,34,55):
    cand2[f"|c-EMA{p}|"]=[abs(c[i]-E[p][i]) for i in range(len(c))]
    cand2[f"|EMA9-EMA{p}|"]=[abs(E[9][i]-E[p][i]) for i in range(len(c))]
cand2["body"]=[abs(c[i]-o[i]) for i in range(len(c))]
cand2["range"]=[h[i]-l[i] for i in range(len(c))]
atr=b[15]
for k in list(cand2):
    v=cand2[k]; cand2[k+"/ATR"]=[v[i]/atr[i] if atr[i] else None for i in range(len(c))]
    for p in (3,5,9,14):
        cand2[f"EMA({k},{p})"]=Q.ema([x if x is not None else 0 for x in v],p)
# ADX wilder
def adx_w(p):
    n=len(c); pdm=[0]*n; mdm=[0]*n
    for i in range(1,n):
        up=h[i]-h[i-1]; dn=l[i-1]-l[i]
        pdm[i]=up if up>dn and up>0 else 0; mdm[i]=dn if dn>up and dn>0 else 0
    a=smma(tr,p); sp=smma(pdm,p); sm=smma(mdm,p)
    pdi=[100*sp[i]/a[i] if a[i] else None for i in range(n)]; mdi=[100*sm[i]/a[i] if a[i] else None for i in range(n)]
    dx=[100*abs(pdi[i]-mdi[i])/(pdi[i]+mdi[i]) if pdi[i] is not None and (pdi[i]+mdi[i]) else 0 for i in range(n)]
    return smma(dx,p),pdi,mdi
for p in (7,10,14,20,21,28):
    a,pd,md=adx_w(p); cand2[f"ADXw({p})"]=a; cand2[f"+DIw({p})"]=pd; cand2[f"-DIw({p})"]=md
for t in (17,18,19):
    r=sorted((err(v,b[t]),k) for k,v in cand2.items()); print(f"b{t}:",r[:3])
