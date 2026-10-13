import sys, math, itertools
sys.path.insert(0, sys.argv[1]); sys.path.insert(0, sys.argv[2])
from load_m1 import load
import quet_khung as Q
ok=lambda x: x is not None and not math.isnan(x)
sets=[]
for tf,u in (("M2","U1"),("M3","U2"),("M5","U3"),("M15","U4")):
    P=f"i_{u}_DTRADE____ATM_SCALP_AI_{tf}_b"
    d=load(f"{sys.argv[3]}/ATM Demo2_ctxbars_XAUUSDm_{tf}.csv",P); n=len(d["close"])
    o=list(d["open"]);h=list(d["high"]);l=list(d["low"]);c=list(d["close"])
    B={k:list(d[P+str(k)]) for k in range(21)}
    E={p:Q.ema(c,p) for p in (9,14,21,34)}
    sigs={i:(1 if ok(B[0][i]) else -1) for i in range(n) if ok(B[0][i]) or ok(B[1][i])}
    sets.append((tf,n,o,h,l,c,B,E,sigs))
def evaluate(pb_kind,p,k,fresh,use_state):
    tp=fp=fn=0
    for tf,n,o,h,l,c,B,E,sigs in sets:
        adx=B[19]; stt=lambda i: B[2][i] if ok(B[2][i]) else 0
        def base(i,dr):
            brk=(c[i]>h[i-1]) if dr==1 else (c[i]<l[i-1])
            return B[20][i]==dr and adx[i]>20 and (c[i]-E[9][i])*dr>0 and (E[9][i]-E[21][i])*dr>0 and (c[i]-o[i])*dr>0 and brk
        def pull(i,dr):
            js=range(i-k,i) if pb_kind!="incl" else range(i-k,i+1)
            if pb_kind in ("low","incl"):
                return any(((l[j]<=E[p][j]) if dr==1 else (h[j]>=E[p][j])) for j in js)
            if pb_kind=="close":
                return any(((c[j]<=E[p][j]) if dr==1 else (c[j]>=E[p][j])) for j in js)
        s0=min(sigs)
        for i in range(max(s0,100),n):
            for dr in (1,-1):
                pred=base(i,dr) and pull(i,dr)
                if pred and use_state and stt(i-1)*dr==1: pred=False
                if pred and fresh and base(i-1,dr) and pull(i-1,dr): pred=False
                real=sigs.get(i)==dr
                tp+=pred and real; fp+=pred and not real; fn+=real and not pred
    prec=tp/(tp+fp) if tp+fp else 0; rec=tp/(tp+fn)
    return 2*prec*rec/(prec+rec) if prec+rec else 0,prec,rec,tp,fp,fn
res=[]
for pb_kind,p,k,fresh,use_state in itertools.product(("low","incl","close"),(9,14,21),(1,2,3,4,5,6,8,10),(False,True),(True,)):
    res.append((evaluate(pb_kind,p,k,fresh,use_state),(pb_kind,p,k,fresh,use_state)))
res.sort(reverse=True)
for (f1,pr,rc,tp,fp,fn),cfg in res[:12]:
    print(f"F1 {f1:.3f} prec {pr:.2f} rec {rc:.2f} tp {tp} fp {fp} fn {fn}  {cfg}")
