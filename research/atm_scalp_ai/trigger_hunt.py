import sys, math, statistics as st
from collections import defaultdict
sys.path.insert(0, sys.argv[1]); sys.path.insert(0, sys.argv[2])
from load_m1 import load
import quet_khung as Q
ok=lambda x: x is not None and not math.isnan(x)
def smma(x,p):
    out=[None]*len(x); v=sum(x[:p])/p; out[p-1]=v
    for i in range(p,len(x)): v=(v*(p-1)+x[i])/p; out[i]=v
    return out
def adx_w(h,l,c,p=14):
    n=len(c); tr=Q.true_range(h,l,c); pdm=[0.0]*n; mdm=[0.0]*n
    for i in range(1,n):
        up=h[i]-h[i-1]; dn=l[i-1]-l[i]
        pdm[i]=up if up>dn and up>0 else 0.0; mdm[i]=dn if dn>up and dn>0 else 0.0
    a=smma(tr,p); sp=smma(pdm,p); sm=smma(mdm,p)
    pdi=[100*sp[i]/a[i] if a[i] else 0 for i in range(n)]; mdi=[100*sm[i]/a[i] if a[i] else 0 for i in range(n)]
    dx=[100*abs(pdi[i]-mdi[i])/(pdi[i]+mdi[i]) if (pdi[i]+mdi[i]) else 0 for i in range(n)]
    return smma(dx,p),pdi,mdi,a
def analyse(path,P,name):
    d=load(path,P); n=len(d["close"])
    o=list(d["open"]);h=list(d["high"]);l=list(d["low"]);c=list(d["close"])
    B=lambda k: list(d[P+str(k)])
    b0,b1,b2=B(0),B(1),B(2)
    E={p:Q.ema(c,p) for p in (9,14,21,34,55)}
    adx,pdi,mdi,atr=adx_w(h,l,c)
    sigi=[i for i in range(n) if ok(b0[i]) or ok(b1[i])]
    start=sigi[0]-50
    def cond(i,dr):
        return (E[21][i]-E[55][i])*dr>0 and adx[i]>20 and (c[i]-E[9][i])*dr>0 and (E[9][i]-E[21][i])*dr>0 and (c[i]-o[i])*dr>0
    sigset={i:(1 if ok(b0[i]) else -1) for i in sigi}
    rows=[]
    last_sig=-10**9
    for i in range(max(start,60),n):
        for dr in (1,-1):
            if not cond(i,dr): continue
            flat = (not ok(b2[i-1])) or b2[i-1]==0
            is_sig = sigset.get(i)==dr
            lowk=lambda k,p: (min(l[i-k:i+1])<=E[p][i]) if dr==1 else (max(h[i-k:i+1])>=E[p][i])
            f={
              "flat": flat,
              "cham EMA9 trong 3 nen": lowk(3,9), "cham EMA14 trong 3 nen": lowk(3,14), "cham EMA21 trong 3 nen": lowk(3,21),
              "cham EMA21 trong 10 nen": lowk(10,21),"cham EMA34 trong 10 nen": lowk(10,34),
              "nen truoc dong duoi EMA9": (c[i-1]-E[9][i-1])*dr<=0,
              "nen truoc nguoc chieu": (c[i-1]-o[i-1])*dr<0,
              "dong vuot dinh nen truoc": (c[i]-h[i-1])>0 if dr==1 else (l[i-1]-c[i])>0,
              "ADX tang": adx[i]>adx[i-1],
              "+DI>-DI dung chieu": (pdi[i]-mdi[i])*dr>0,
              "ADX>25": adx[i]>25,
              "trend vua doi (<20 nen)": any((E[21][j]-E[55][j])*dr<=0 for j in range(i-20,i)),
              "EMA9 vua cat EMA21 (<10 nen)": any((E[9][j]-E[21][j])*dr<=0 for j in range(i-10,i)),
              "than/ATR>0.5": abs(c[i]-o[i])/atr[i]>0.5,
              "(c-EMA9)/ATR<0.5": abs(c[i]-E[9][i])/atr[i]<0.5,
              "EMA dung thu tu 9>14>21>34>55": all((E[a][i]-E[b][i])*dr>0 for a,b in ((9,14),(14,21),(21,34),(34,55))),
            }
            rows.append((is_sig,f))
    print(f"\n=== {name}: tin hieu {len(sigi)}, nen thoa 5 dk: {len(rows)}, trong do tin hieu {sum(r[0] for r in rows)}")
    keys=rows[0][1].keys()
    S=[r[1] for r in rows if r[0]]; N=[r[1] for r in rows if not r[0]]
    for k in keys:
        a=sum(x[k] for x in S)/len(S); b=sum(x[k] for x in N)/len(N)
        print(f"  {k:32s} tin hieu {a:6.0%}   khong tin hieu {b:6.0%}")
    return rows
P1="i_U1_DTRADE____ATM_SCALP_AI_M1_b"; P5="i_U1_DTRADE____ATM_SCALP_AI_M5_b"
analyse(sys.argv[3],P1,"M1 demo")
analyse(sys.argv[4],P5,"M5 real")
