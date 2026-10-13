import sys, math
from collections import Counter
sys.path.insert(0, sys.argv[1]); sys.path.insert(0, sys.argv[2])
from load_m1 import load
import quet_khung as Q
ok=lambda x: x is not None and not math.isnan(x)
DATA=[("M2","U1"),("M3","U2"),("M5","U3"),("M15","U4")]
rows=[]
for tf,u in DATA:
    P=f"i_{u}_DTRADE____ATM_SCALP_AI_{tf}_b"
    d=load(f"{sys.argv[3]}/ATM Demo2_ctxbars_XAUUSDm_{tf}.csv",P); n=len(d["close"])
    o=list(d["open"]);h=list(d["high"]);l=list(d["low"]);c=list(d["close"]);t=d["bar_time"]
    B={k:list(d[P+str(k)]) for k in range(21)}
    E={p:Q.ema(c,p) for p in (9,14,21,34,55)}
    adx=B[19]; atr=B[15]
    sigs={i:(1 if ok(B[0][i]) else -1) for i in range(n) if ok(B[0][i]) or ok(B[1][i])}
    s0=min(sigs)
    def cond(i,dr):
        brk=(c[i]>h[i-1]) if dr==1 else (c[i]<l[i-1])
        return B[20][i]==dr and adx[i]>20 and (c[i]-E[9][i])*dr>0 and (E[9][i]-E[21][i])*dr>0 and (c[i]-o[i])*dr>0 and brk
    stt=lambda i: B[2][i] if ok(B[2][i]) else 0
    for i in sorted(sigs):
        if not cond(i,sigs[i]): print("MISS",tf,t[i],sigs[i], "b20",B[20][i],"adx",round(adx[i],1))
    for i in range(max(s0,100),n):
        for dr in (1,-1):
            if not cond(i,dr) or stt(i-1)*dr==1: continue
            # bars since trend (b20) flip to dr
            k=i
            while k>0 and B[20][k-1]==dr: k-=1
            age=i-k
            # bars since position closed (state became 0) or since opposite entry
            k2=i-1
            while k2>0 and stt(k2)==stt(i-1): k2-=1
            st_age=i-1-k2
            # was previous bar also candidate?
            prevc=cond(i-1,dr)
            # count signals of same dir since trend flip
            same_since_flip=sum(1 for j in sigs if k<=j<i and sigs[j]==dr)
            # did trend flip produce a signal already
            rows.append(dict(tf=tf,sig=sigs.get(i)==dr,state=stt(i-1)*dr,age=age,st_age=st_age,prevc=prevc,
                             nsig_trend=same_since_flip,adx=adx[i],t=t[i]))
S=[r for r in rows if r['sig']]; N=[r for r in rows if not r['sig']]
print("ung vien (khong co lenh cung chieu):",len(rows),"tin hieu",len(S))
print("so tin hieu cung chieu da co tu khi trend doi -> tin hieu:",Counter(r['nsig_trend'] for r in S)," khong:",Counter(r['nsig_trend'] for r in N))
print("nen truoc cung la ung vien -> tin hieu:",Counter(r['prevc'] for r in S)," khong:",Counter(r['prevc'] for r in N))
def q(xs,p): xs=sorted(xs); return xs[int(p*(len(xs)-1))]
for k in ("age","st_age","adx"):
    a=[r[k] for r in S]; b=[r[k] for r in N]
    print(f"{k}: tin hieu {q(a,0):.1f}/{q(a,.25):.1f}/{q(a,.5):.1f}/{q(a,.75):.1f}/{q(a,1):.1f} | khong {q(b,0):.1f}/{q(b,.25):.1f}/{q(b,.5):.1f}/{q(b,.75):.1f}/{q(b,1):.1f}")
