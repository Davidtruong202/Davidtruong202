import csv, sys, statistics as st
sys.path.insert(0, __import__("os").path.join(__import__("os").path.dirname(__import__("os").path.abspath(__file__)), "..", "phan_tich_ea"))
import quet_khung as Q
rows=list(csv.DictReader(open(sys.argv[1],encoding="utf-8-sig")))
P="i_U1_DTRADE____ATM_SCALP_AI_M5_b"
o=[float(r["open"]) for r in rows]; h=[float(r["high"]) for r in rows]; l=[float(r["low"]) for r in rows]; c=[float(r["close"]) for r in rows]
def buf(b): return [float(r[P+str(b)]) if r[P+str(b)] else None for r in rows]
W=range(2000,len(rows))
def err(a,b):
    d=[abs(a[i]-b[i]) for i in W if a[i] is not None and b[i] is not None]
    return st.median(d) if d else 9e9
hl2=[(h[i]+l[i])/2 for i in range(len(c))]; hlc3=[(h[i]+l[i]+c[i])/3 for i in range(len(c))]
srcs={"close":c,"hl2":hl2,"hlc3":hlc3}
def wma(x,p):
    out=[None]*len(x); den=p*(p+1)/2
    for i in range(p-1,len(x)): out[i]=sum(x[i-p+1+j]*(j+1) for j in range(p))/den
    return out
def smma(x,p):
    out=[None]*len(x); v=sum(x[:p])/p; out[p-1]=v
    for i in range(p,len(x)): v=(v*(p-1)+x[i])/p; out[i]=v
    return out
for b in (8,11,12,13,14):
    tgt=buf(b); best=[]
    for sn,s in srcs.items():
        for p in list(range(2,60))+[89,100,144,200]:
            for kind,fn in (("EMA",Q.ema),("SMA",Q.sma),("SMMA",smma)):
                best.append((err(tgt,fn(s,p)),f"{kind}({sn},{p})"))
    best.sort(); print(f"b{b}:", best[:3])
tr=Q.true_range(h,l,c)
for b in (15,16,17,18,19):
    tgt=buf(b); best=[]
    for p in range(2,60):
        best.append((err(tgt,Q.sma(tr,p)),f"ATR_SMA({p})"))
        best.append((err(tgt,smma(tr,p)),f"ATR_Wilder({p})"))
        best.append((err(tgt,Q.ema(tr,p)),f"ATR_EMA({p})"))
    if b==19:
        for p in range(5,40):
            a,_,_=Q.adx(h,l,c,p); best.append((err(tgt,a),f"ADX_MT5({p})"))
    best.sort(); print(f"b{b}:", best[:3], " median tgt", st.median([v for v in tgt if v]))
# SL distance vs b15 / ATR
b2=buf(2); b3=buf(3); b4=buf(4); b15=buf(15); b17=buf(17)
atr14=Q.sma(tr,14)
print("signal bars: risk, risk/b15, risk/ATR14, (tp1-e)/risk,(tp2-e)/risk,(tp3-e)/risk")
b5=buf(5);b6=buf(6);b7=buf(7)
for i in range(1,len(rows)):
    if b3[i] is not None and (b3[i-1]!=b3[i]):
        risk=abs(b3[i]-b4[i])
        print(rows[i]["bar_time"], f"{risk:7.3f} {risk/b15[i]:6.3f} {risk/atr14[i]:6.3f} {abs(b5[i]-b3[i])/risk:5.2f} {abs(b6[i]-b3[i])/risk:5.2f} {abs(b7[i]-b3[i])/risk:5.2f}  b15={b15[i]:.3f} b15prev={b15[i-1]:.3f}")
