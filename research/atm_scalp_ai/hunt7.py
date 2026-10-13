import sys, math
from collections import Counter
sys.path.insert(0, sys.argv[1]); sys.path.insert(0, sys.argv[2])
from load_m1 import load
import quet_khung as Q
ok=lambda x: x is not None and not math.isnan(x)
FP=[];FN=[];TP=[]
for tf,u in (("M2","U1"),("M3","U2"),("M5","U3"),("M15","U4")):
    P=f"i_{u}_DTRADE____ATM_SCALP_AI_{tf}_b"
    d=load(f"{sys.argv[3]}/ATM Demo2_ctxbars_XAUUSDm_{tf}.csv",P); n=len(d["close"])
    o=list(d["open"]);h=list(d["high"]);l=list(d["low"]);c=list(d["close"]);t=d["bar_time"]
    B={k:list(d[P+str(k)]) for k in range(21)}
    E={p:Q.ema(c,p) for p in (9,14,21)}
    adx=B[19]
    sigs={i:(1 if ok(B[0][i]) else -1) for i in range(n) if ok(B[0][i]) or ok(B[1][i])}
    stt=lambda i: B[2][i] if ok(B[2][i]) else 0
    def base(i,dr):
        brk=(c[i]>h[i-1]) if dr==1 else (c[i]<l[i-1])
        return B[20][i]==dr and adx[i]>20 and (c[i]-E[9][i])*dr>0 and (E[9][i]-E[21][i])*dr>0 and (c[i]-o[i])*dr>0 and brk
    def pull(i,dr,k=6):
        return any(((l[j]<=E[14][j]) if dr==1 else (h[j]>=E[14][j])) for j in range(i-k,i+1))
    lastsig=None
    for i in range(max(min(sigs),100),n):
        for dr in (1,-1):
            pred=base(i,dr) and pull(i,dr) and stt(i-1)*dr!=1
            real=sigs.get(i)==dr
            ls=[j for j in sigs if j<i]; last=max(ls) if ls else None
            info=dict(tf=tf,t=t[i],dr=dr,state=stt(i-1)*dr,since=(i-last) if last else 999,lastdir=(sigs[last]*dr if last else 0),
                      prev_sig=(sigs.get(i-1,0)*dr), adx=round(adx[i],1), sigsame_in7=sum(1 for j in range(i-7,i) if sigs.get(j)==dr),
                      sigopp_in7=sum(1 for j in range(i-7,i) if sigs.get(j)==-dr))
            if pred and real: TP.append(info)
            elif pred: FP.append(info)
            elif real: FN.append(info)
print("TP",len(TP),"FP",len(FP),"FN",len(FN))
for name,L in (("TP",TP),("FP",FP)):
    print(name,"state:",Counter(r['state'] for r in L),"lastdir:",Counter(r['lastdir'] for r in L),
          "sig cung chieu trong 7 nen:",Counter(r['sigsame_in7'] for r in L),"nguoc chieu trong 7:",Counter(r['sigopp_in7'] for r in L))
    print("   since:",sorted(r['since'] for r in L)[:25])
print("FN:"); [print("  ",r) for r in FN]
print("FP mau:"); [print("  ",r) for r in FP[:15]]
print("\nADX<21: TP",sum(1 for r in TP if r['adx']<21),"FP",sum(1 for r in FP if r['adx']<21))
for th in (20,20.5,21,22,23):
    print(f" nguong ADX>{th}: TP {sum(1 for r in TP if r['adx']>th)} FP {sum(1 for r in FP if r['adx']>th)}")
hr=lambda r:int(r['t'][11:13])
print("gio TP:",sorted(Counter(hr(r) for r in TP).items()))
print("gio FP:",sorted(Counter(hr(r) for r in FP).items()))
