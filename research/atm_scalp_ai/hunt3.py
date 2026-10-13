import sys, math, statistics as st
from collections import defaultdict
sys.path.insert(0, sys.argv[1]); sys.path.insert(0, sys.argv[2])
from load_m1 import load
import quet_khung as Q
from trigger_hunt_lib import adx_w
ok=lambda x: x is not None and not math.isnan(x)
DATA=[(f"{sys.argv[3]}/ATM Demo2_ctxbars_XAUUSDm_M2.csv","i_U1_DTRADE____ATM_SCALP_AI_M2_b","M2"),
      (f"{sys.argv[3]}/ATM Demo2_ctxbars_XAUUSDm_M3.csv","i_U2_DTRADE____ATM_SCALP_AI_M3_b","M3"),
      (f"{sys.argv[3]}/ATM Demo2_ctxbars_XAUUSDm_M5.csv","i_U3_DTRADE____ATM_SCALP_AI_M5_b","M5"),
      (f"{sys.argv[3]}/ATM Demo2_ctxbars_XAUUSDm_M15.csv","i_U4_DTRADE____ATM_SCALP_AI_M15_b","M15")]
allrows=[]
for path,P,name in DATA:
    d=load(path,P); n=len(d["close"])
    o=list(d["open"]);h=list(d["high"]);l=list(d["low"]);c=list(d["close"]);v=list(d["tick_volume"]);t=d["bar_time"]
    B={k:list(d[P+str(k)]) for k in range(21)}
    E={p:Q.ema(c,p) for p in (9,14,21,34,55)}
    adx=B[19]; atr=B[15]
    sigs={i:(1 if ok(B[0][i]) else -1) for i in range(n) if ok(B[0][i]) or ok(B[1][i])}
    s0=min(sigs)
    # check b20 vs EMA21>EMA55 on this TF
    agree=sum(1 for i in range(200,n) if B[20][i]==(1 if E[21][i]>E[55][i] else -1))/(n-200)
    def cond(i,dr):
        brk=(c[i]>h[i-1]) if dr==1 else (c[i]<l[i-1])
        return B[20][i]==dr and adx[i]>20 and (c[i]-E[9][i])*dr>0 and (E[9][i]-E[21][i])*dr>0 and (c[i]-o[i])*dr>0 and brk
    stt=lambda i: B[2][i] if ok(B[2][i]) else 0
    cand=0; hit=0
    for i in range(max(s0-20,100),n):
        for dr in (1,-1):
            if not cond(i,dr): continue
            cand+=1; s=sigs.get(i)==dr; hit+=s
            # bars since last signal any dir, same dir
            ls=[j for j in sigs if j<i]
            last=max(ls) if ls else None
            allrows.append(dict(tf=name,sig=s,dr=dr,flat=stt(i-1)==0,state=stt(i-1)*dr,
                b17=B[17][i],b18=B[18][i],b17p=B[17][i-1],b18p=B[18][i-1],
                adx=adx[i],adxp=adx[i-1],body=abs(c[i]-o[i])/atr[i],
                since_sig=(i-last) if last is not None else 999,
                last_dir=(sigs[last]*dr) if last is not None else 0,
                vol=v[i]/ (sum(v[i-20:i])/20)))
    print(f"{name}: rows {n}, signals {len(sigs)} (B {sum(1 for x in sigs.values() if x==1)}/S {sum(1 for x in sigs.values() if x==-1)}), b20~EMA21>55 {agree:.3%}, 6dk: {cand} nen, tin hieu {hit}/{len(sigs)}")
S=[r for r in allrows if r['sig']]; N=[r for r in allrows if not r['sig']]
print(f"\nTong: tin hieu {len(S)}, nen thoa 6 dk khong tin hieu {len(N)}")
def q(xs,p): xs=sorted(xs); return xs[int(p*(len(xs)-1))]
for k in ("b17","b18","b17p","b18p","adx","body","vol","since_sig"):
    a=[r[k] for r in S if ok(r[k])]; b=[r[k] for r in N if ok(r[k])]
    print(f"{k:9s} tin hieu p5/p50/p95 {q(a,.05):8.3f} {q(a,.5):8.3f} {q(a,.95):8.3f} | khong {q(b,.05):8.3f} {q(b,.5):8.3f} {q(b,.95):8.3f}")
for k in ("flat",):
    print(k, f"{sum(r[k] for r in S)/len(S):.0%} vs {sum(r[k] for r in N)/len(N):.0%}")
from collections import Counter
print("state(prev, theo chieu) tin hieu:",Counter(r['state'] for r in S)," khong:",Counter(r['state'] for r in N))
print("last signal dir (cung chieu=1) tin hieu:",Counter(r['last_dir'] for r in S)," khong:",Counter(r['last_dir'] for r in N))
