import sys, math, statistics as st
sys.path.insert(0, sys.argv[2]); sys.path.insert(0, sys.argv[3])
from load_m1 import load
import quet_khung as Q
P="i_U1_DTRADE____ATM_SCALP_AI_M1_b"
d=load(sys.argv[1],P); n=len(d["close"])
c=list(d["close"]); h=list(d["high"]); l=list(d["low"]); o=list(d["open"]); t=d["bar_time"]
B={k:list(d[P+str(k)]) for k in range(16)}
ok=lambda x: not math.isnan(x)
sig=[i for i in range(n) if ok(B[0][i]) or ok(B[1][i])]
print("rows",n,t[0],"->",t[-1]," signals",len(sig),"BUY",sum(ok(B[0][i]) for i in sig),"SELL",sum(ok(B[1][i]) for i in sig))
print("first signal",t[sig[0]],"last",t[sig[-1]])
# signals per month
from collections import Counter
cm=Counter(t[i][:7] for i in sig); print("per month:",dict(sorted(cm.items())))
# formula checks on M1
W=range(3000,n)
def err(a,b): 
    xs=[abs(a[i]-b[i]) for i in W if ok(a[i]) and b[i] is not None and ok(b[i])]; return st.median(xs)
for k,p in ((8,9),(10,9),(11,14),(12,21),(13,34),(14,55)):
    print(f"b{k} vs EMA{p}: median err {err(B[k],Q.ema(c,p)):.2e}")
tr=Q.true_range(h,l,c)
def smma(x,p):
    out=[None]*len(x); v=sum(x[:p])/p; out[p-1]=v
    for i in range(p,len(x)): v=(v*(p-1)+x[i])/p; out[i]=v
    return out
atr=smma(tr,14)
print(f"b15 vs ATR Wilder14: {err(B[15],atr):.2e}")
# SL/TP ratios at signals
rs=[];r1=[];r2=[];r3=[]
for i in sig:
    e=B[3][i]; sl=B[4][i]
    if not ok(e) or not ok(sl): continue
    R=abs(e-sl); rs.append(R/atr[i]); r1.append(abs(B[5][i]-e)/R); r2.append(abs(B[6][i]-e)/R); r3.append(abs(B[7][i]-e)/R)
    if abs(e-c[i])>1e-6: pass
print("SL/ATR min/med/max",min(rs),st.median(rs),max(rs)," TP R:",st.median(r1),st.median(r2),st.median(r3))
print("entry==close at signal:",sum(1 for i in sig if ok(B[3][i]) and abs(B[3][i]-c[i])<1e-6),"/",len(sig))
