import sys, math
from collections import Counter
sys.path.insert(0, sys.argv[1]); sys.path.insert(0, sys.argv[2])
from load_m1 import load
import quet_khung as Q
ok=lambda x: x is not None and not math.isnan(x)
rows=[]
for tf,u in (("M2","U1"),("M3","U2"),("M5","U3"),("M15","U4")):
    P=f"i_{u}_DTRADE____ATM_SCALP_AI_{tf}_b"
    d=load(f"{sys.argv[3]}/ATM Demo2_ctxbars_XAUUSDm_{tf}.csv",P); n=len(d["close"])
    o=list(d["open"]);h=list(d["high"]);l=list(d["low"]);c=list(d["close"])
    B={k:list(d[P+str(k)]) for k in range(21)}
    E={p:Q.ema(c,p) for p in (9,14,21,34,55)}
    adx=B[19]; atr=B[15]
    sigs={i:(1 if ok(B[0][i]) else -1) for i in range(n) if ok(B[0][i]) or ok(B[1][i])}
    def parts(i,dr):
        return {"trend":B[20][i]==dr,"adx>20":adx[i]>20,"c>EMA9":(c[i]-E[9][i])*dr>0,"EMA9>EMA21":(E[9][i]-E[21][i])*dr>0,
                "nen xanh":(c[i]-o[i])*dr>0,"vuot dinh":((c[i]>h[i-1]) if dr==1 else (c[i]<l[i-1]))}
    stt=lambda i: B[2][i] if ok(B[2][i]) else 0
    for i in range(max(min(sigs),100),n):
        for dr in (1,-1):
            p=parts(i,dr)
            if not all(p.values()) or stt(i-1)*dr==1: continue
            pp=parts(i-1,dr)
            if all(pp.values()): continue
            fails=tuple(k for k,v in pp.items() if not v)
            rows.append(dict(sig=sigs.get(i)==dr,fails=fails,
               adxup=adx[i]>adx[i-1], prev2=parts(i-2,dr),
               c_ema9_prev=(c[i-1]-E[9][i-1])*dr, atr=atr[i],
               pull14=(min(l[i-3:i])<=E[14][i]) if dr==1 else (max(h[i-3:i])>=E[14][i]),
               pull21=(min(l[i-5:i])<=E[21][i]) if dr==1 else (max(h[i-5:i])>=E[21][i]),
               ))
S=[r for r in rows if r['sig']]; N=[r for r in rows if not r['sig']]
print("ung vien moi (nen truoc khong du dk):",len(rows),"tin hieu",len(S))
cs=Counter(r['fails'] for r in S); cn=Counter(r['fails'] for r in N)
keys=sorted(set(cs)|set(cn), key=lambda k:-(cs[k]+cn[k]))
print("dieu kien bi truot o NEN TRUOC  -> tin hieu / khong")
for k in keys[:15]: print(f"  {str(k):55s} {cs[k]:4d} / {cn[k]:4d}")
for k in ("adxup","pull14","pull21"):
    print(k, f"tin hieu {sum(r[k] for r in S)/len(S):.0%}  khong {sum(r[k] for r in N)/len(N):.0%}")
