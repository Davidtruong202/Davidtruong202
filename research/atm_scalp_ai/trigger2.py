import sys, math
sys.path.insert(0, sys.argv[1]); sys.path.insert(0, sys.argv[2])
from load_m1 import load
import quet_khung as Q
from trigger_hunt_lib import adx_w
ok=lambda x: x is not None and not math.isnan(x)
def run(path,P,name):
    d=load(path,P); n=len(d["close"])
    o=list(d["open"]);h=list(d["high"]);l=list(d["low"]);c=list(d["close"]); t=d["bar_time"]
    b0,b1,b2=[list(d[P+str(k)]) for k in (0,1,2)]
    E={p:Q.ema(c,p) for p in (9,14,21,34,55)}
    adx,pdi,mdi,atr=adx_w(h,l,c)
    sigs={i:(1 if ok(b0[i]) else -1) for i in range(n) if ok(b0[i]) or ok(b1[i])}
    start=min(sigs)-50
    def cond(i,dr):
        brk=(c[i]>h[i-1]) if dr==1 else (c[i]<l[i-1])
        return (E[21][i]-E[55][i])*dr>0 and adx[i]>20 and (c[i]-E[9][i])*dr>0 and (E[9][i]-E[21][i])*dr>0 and (c[i]-o[i])*dr>0 and brk
    st=lambda i: b2[i] if ok(b2[i]) else 0
    tot=sig=0; ex=[]
    for i in range(start,n):
        for dr in (1,-1):
            if cond(i,dr):
                tot+=1
                if sigs.get(i)==dr: sig+=1
                elif st(i-1)==0: ex.append((i,dr))
    nf=[i for i in sigs if st(i-1)!=0]
    print(f"\n=== {name}: nen thoa 6 dk {tot}, tin hieu {sig}/{len(sigs)}; thoa 6 dk + dang flat ma KHONG co tin hieu: {len(ex)}")
    print("  tin hieu khi dang co lenh:",[(t[i], 'BUY' if sigs[i]==1 else 'SELL', 'dang '+('BUY' if st(i-1)==1 else 'SELL')) for i in nf])
    # trang thai: bao nhieu nen tu khi lenh truoc dong
    def since_close(i):
        k=i-1
        while k>start and st(k)==0: k-=1
        return i-1-k
    print("  so nen flat truoc tin hieu (flat):", sorted(since_close(i) for i in sigs if st(i-1)==0)[:30])
    print("  so nen flat truoc nen bi bo qua :", sorted(since_close(i) for i,_ in ex)[:30])
    # xem 12 vi du bi bo qua
    for i,dr in ex[:12]:
        print("   bo qua", t[i], "BUY" if dr==1 else "SELL", f"adx={adx[i]:.1f} than/atr={abs(c[i]-o[i])/atr[i]:.2f} flat_since={since_close(i)}")
run(sys.argv[3],"i_U1_DTRADE____ATM_SCALP_AI_M1_b","M1 demo")
run(sys.argv[4],"i_U1_DTRADE____ATM_SCALP_AI_M5_b","M5 real")
