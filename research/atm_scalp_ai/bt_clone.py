"""Backtest quy tac ban sao ATM SCALP AI tren file ctxbars (chi can OHLC), ghi danh sach lenh + dac trung."""
import sys, math, csv
sys.path.insert(0, sys.argv[1]); sys.path.insert(0, sys.argv[2])
from load_m1 import load
import quet_khung as Q
from trigger_hunt_lib import adx_w
path, P, out, htf_mult = sys.argv[3], sys.argv[4], sys.argv[5], int(sys.argv[6])
d=load(path,P); n=len(d["close"])
o=list(d["open"]);h=list(d["high"]);l=list(d["low"]);c=list(d["close"]);t=d["bar_time"]
E={p:Q.ema(c,p) for p in (9,14,21,34,55)}
adx,pdi,mdi,atr=adx_w(h,l,c)
# khung lon: gop htf_mult nen (vd M5 x12 = H1), EMA21/55 tren close khung lon, lay nen da dong
hc=[];hidx=[]
for i in range(n):
    if i%htf_mult==htf_mult-1: hc.append(c[i]); hidx.append(i)
H21=Q.ema(hc,21); H55=Q.ema(hc,55)
htf_trend=[0]*n; k=-1
for i in range(n):
    while k+1<len(hidx) and hidx[k+1]<=i: k+=1
    htf_trend[i]=0 if k<60 else (1 if H21[k]>H55[k] else -1)
trades=[]; pos=None
for i in range(600,n):
    if pos:
        dr=pos['dr']
        if (l[i]<=pos['sl']) if dr>0 else (h[i]>=pos['sl']):
            pos['res']= -1.0 if not pos['tp1'] else (1/3 if not pos['tp2'] else 1.0); pos['exit']=i; trades.append(pos); pos=None
        else:
            hit=lambda lv: (h[i]>=lv) if dr>0 else (l[i]<=lv)
            if hit(pos['t3']): pos['res']=2.0; pos['tp1']=pos['tp2']=True; pos['exit']=i; trades.append(pos); pos=None
            else:
                if not pos['tp1'] and hit(pos['t1']): pos['tp1']=True; pos['sl']=pos['e']
                if pos['tp1'] and not pos['tp2'] and hit(pos['t2']): pos['tp2']=True
    for dr in (1,-1):
        if pos and pos['dr']==dr: continue
        if not ((E[21][i]-E[55][i])*dr>0 and adx[i]>20 and (c[i]-E[9][i])*dr>0 and (E[9][i]-E[21][i])*dr>0 and (c[i]-o[i])*dr>0
                and ((c[i]>h[i-1]) if dr>0 else (c[i]<l[i-1]))): continue
        if not any(((l[j]<=E[14][j]) if dr>0 else (h[j]>=E[14][j])) for j in range(i-6,i+1)): continue
        if pos:  # dao chieu: dong lenh cu tai close
            pr=(c[i]-pos['e'])*pos['dr']/ (pos['R'])
            pos['res']=pr/3 + (1/3 if pos['tp1'] else 0) + (2/3 if pos['tp2'] else 0) if pos['tp1'] else pr; pos['exit']=i; pos['rev']=True; trades.append(pos); pos=None
        R=3*atr[i]
        # trend age
        k=i
        while k>0 and (E[21][k-1]-E[55][k-1])*dr>0: k-=1
        pos=dict(i=i,t=t[i],dr=dr,e=c[i],R=R,sl=c[i]-dr*R,t1=c[i]+dr*R,t2=c[i]+dr*2*R,t3=c[i]+dr*3*R,tp1=False,tp2=False,
                 hour=int(t[i][11:13]),adx=adx[i],adx_up=adx[i]>adx[i-1],ext=(c[i]-E[9][i])*dr/atr[i],body=abs(c[i]-o[i])/atr[i],
                 touch21=any(((l[j]<=E[21][j]) if dr>0 else (h[j]>=E[21][j])) for j in range(i-6,i+1)),
                 touch34=any(((l[j]<=E[34][j]) if dr>0 else (h[j]>=E[34][j])) for j in range(i-6,i+1)),
                 htf=htf_trend[i]*dr, age=i-k, di=(pdi[i]-mdi[i])*dr, atrp=atr[i]/c[i]*1e4)
        break
cols=["t","dr","res","tp1","hour","adx","adx_up","ext","body","touch21","touch34","htf","age","di","atrp","i"]
with open(out,"w",newline="") as fh:
    w=csv.writer(fh); w.writerow(cols)
    for tr in trades:
        if 'res' in tr: w.writerow([tr[k] for k in cols])
print(path.split('/')[-1], "lenh:",len(trades), "WR(TP1):", round(sum(1 for x in trades if x['tp1'])/len(trades),3),
      "R TB/lenh:", round(sum(x['res'] for x in trades)/len(trades),3))
