import sys, math, statistics as st
from collections import defaultdict
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
