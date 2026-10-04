import sys, pandas as pd
P=sys.argv[1]
d={}
for k in ['9thang','spread100','chartM5','seed8','tickthat']:
    x=pd.read_csv(f'ket_qua/{P}_{k}.csv').set_index('name'); d[k]=x
t=pd.DataFrame({'lai_9th':d['9thang'].net,'dd_9th':d['9thang'].maxdd,'pf':d['9thang'].pf,'lenh':d['9thang'].trades,
 'ngay_lo_max':d['9thang'].worst_day,'lai_spread+100':d['spread100'].net,'lai_chartM5':d['chartM5'].net,'lai_seed8':d['seed8'].net,
 'dd_seed8':d['seed8'].maxdd,'lai_tickthat_T1':d['tickthat'].net})
mcols=[c for c in d['9thang'].columns if c.startswith('m_')]
t['thang_lai']=(d['9thang'][mcols]>0).sum(1)
t['min_kichban']=t[['lai_9th','lai_spread+100','lai_chartM5','lai_seed8']].min(1)
pd.set_option('display.width',250)
print(t.sort_values('min_kichban',ascending=False).round(0).to_string())
print(d['9thang'][mcols].round(0).to_string())
