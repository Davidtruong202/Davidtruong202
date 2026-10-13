import csv, sys
def rd(p):
    rows=list(csv.DictReader(open(p)))
    for r in rows:
        for k in ("res","adx","ext","body","atrp","di"): r[k]=float(r[k])
        for k in ("hour","htf","age","dr"): r[k]=int(float(r[k]))
        for k in ("tp1","adx_up","touch21","touch34"): r[k]= r[k]=="True"
    return rows
def stat(rs):
    if not rs: return "   -   "
    return f"n{len(rs):5d} WR{sum(r['tp1'] for r in rs)/len(rs):5.0%} R{sum(r['res'] for r in rs)/len(rs):+.3f}"
for f in sys.argv[1:]:
    rows=rd(f); half=len(rows)//2; A=rows[:half]; B=rows[half:]
    print(f"\n######## {f}   tat ca: nua dau {stat(A)} | nua sau {stat(B)}")
    tests={
     "Khung lon cung chieu (htf=+1)": lambda r:r['htf']==1,
     "Khung lon nguoc chieu": lambda r:r['htf']==-1,
     "ADX 20-25": lambda r:r['adx']<25, "ADX 25-35": lambda r:25<=r['adx']<35, "ADX >=35": lambda r:r['adx']>=35,
     "ADX dang tang": lambda r:r['adx_up'], "ADX dang giam": lambda r:not r['adx_up'],
     "Gia gan EMA9 (ext<0.3ATR)": lambda r:r['ext']<0.3, "Gia xa EMA9 (ext>0.8ATR)": lambda r:r['ext']>0.8,
     "Than nen nho (<0.5ATR)": lambda r:r['body']<0.5, "Than nen lon (>1.2ATR)": lambda r:r['body']>1.2,
     "Hoi sau cham EMA21": lambda r:r['touch21'], "Hoi sau cham EMA34": lambda r:r['touch34'],
     "Xu huong moi (<30 nen)": lambda r:r['age']<30, "Xu huong gia (>150 nen)": lambda r:r['age']>150,
     "+DI-−DI > 10": lambda r:r['di']>10,
     "Gio 00-06": lambda r:0<=r['hour']<7, "Gio 07-12": lambda r:7<=r['hour']<13, "Gio 13-17": lambda r:13<=r['hour']<18, "Gio 18-23": lambda r:r['hour']>=18,
    }
    for name,fn in tests.items():
        a=[r for r in A if fn(r)]; b=[r for r in B if fn(r)]
        print(f"  {name:32s} nua dau {stat(a)} | nua sau {stat(b)}")
