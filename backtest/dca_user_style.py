"""DCA kieu "nhoi den khi duong / chay TK, reset 0.01": thu cac kieu nhan lot, buoc, muc tieu lai.

    python dca_user_style.py   (chay trong thu muc backtest, can data/XAUUSDc_M1_*.csv)
"""
import sys, itertools, pickle, os, tempfile
sys.path.insert(0,'.')
from multiprocessing import Pool
from goldbot.data import load_bars, fmt_time
from goldbot.dca import DCAParams, DCASim
M1=None
def init(pkl):
    global M1
    M1=pickle.load(open(pkl,'rb'))
def run(c):
    p=DCAParams(direction=c[0], step_atr=c[1], tp_atr=c[2], base_lot=0.01, max_levels=500, basket_sl_pct=100.0,
                rebate_per_lot=11.0, **c[3])
    r=DCASim(M1,p,initial=5000.0).run()
    peak=max((e for _,_,e in r['curve']), default=5000.0)
    pt=max(r['curve'], key=lambda x:x[2])[0] if r['curve'] else 0
    bs=r['baskets']
    return dict(c=(c[0],c[1],c[2],c[4]), blown=r['blown'], end=r['curve'][-1][0] if r['curve'] else 0, final=r['final'],
                peak=peak, peak_t=pt, n=len(bs), maxlv=max((x[4] for x in bs),default=0), maxlots=max((x[6] for x in bs),default=0), dd=r['max_dd'])
if __name__=='__main__':
    m1=load_bars('data/XAUUSDc_M1_202401020100_202609230952.csv', tf=60, verbose=False)
    fd,pkl=tempfile.mkstemp(); pickle.dump(m1,os.fdopen(fd,'wb'))
    modes=[(dict(mult=1.3, mult2=1.2, mult2_after=5),'x1.3->x1.2 (EA ban)'),(dict(mult=1.3),'x1.3'),(dict(mult=1.2),'x1.2')]
    combos=[(d,s,t,m[0],m[1]) for d in ('trend','long') for s in (0.5,1.0,2.0) for t in (0.02,0.05,0.1,0.3) for m in modes]
    with Pool(4, initializer=init, initargs=(pkl,)) as pool: res=pool.map(run, combos)
    os.remove(pkl)
    alive=[r for r in res if not r['blown']]
    print("Tong %d bien the | CHAY TAI KHOAN: %d | song den 09/2026: %d" % (len(res), len(res)-len(alive), len(alive)))
    print("\nTheo kieu tang lot:")
    for m in [x[1] for x in modes]:
        rs=[r for r in res if r['c'][3]==m]
        bl=[r for r in rs if r['blown']]
        import statistics
        life=sorted((r['end']-M1_t0)/86400 for r in bl) if False else None
        print("  %-15s chay %2d/%d | dinh cao nhat tot nhat x%.1f" % (m, len(bl), len(rs), max(r['peak'] for r in rs)/5000))
    print("\nChi tiet (sap theo dinh cao nhat):")
    for r in sorted(res, key=lambda r: r['peak'], reverse=True)[:14]:
        c=r['c']
        print("  %-5s buoc %.1fATR tp %.1fATR %-15s | dinh x%5.1f (%s) | %s | chuoi dai nhat %3d lenh, %.2f lot" % (
            c[0], c[1], c[2], c[3], r['peak']/5000, fmt_time(r['peak_t'])[:10],
            ("CHAY %s" % fmt_time(r['end'])[:10]) if r['blown'] else "song, cuoi x%.2f DD %.0f%%" % (r['final']/5000, r['dd']), r['maxlv'], r['maxlots']))
    print("\nSong sot:")
    for r in sorted(alive, key=lambda r: r['final'], reverse=True):
        c=r['c']; print("  %-5s buoc %.1fATR tp %.1fATR %-15s | cuoi x%.2f | DD %.0f%% | %d chuoi, dai nhat %d lenh %.2f lot" % (c[0],c[1],c[2],c[3], r['final']/5000, r['dd'], r['n'], r['maxlv'], r['maxlots']))
