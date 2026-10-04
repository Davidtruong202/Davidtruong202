import sys, pandas as pd
a=pd.read_csv(sys.argv[1]); b=pd.read_csv(sys.argv[2])
m=a.merge(b,on='name',suffixes=('_r','_s'))
sp=lambda x,y: x.rank().corr(y.rank())
for c in ['net','pf','maxdd','trades']:
    print(c, 'pearson %.3f spearman %.3f'%(m[c+'_r'].corr(m[c+'_s']), sp(m[c+'_r'],m[c+'_s'])), 'median r %.1f s %.1f'%(m[c+'_r'].median(), m[c+'_s'].median()))
print('sign agree net', ((m.net_r>0)==(m.net_s>0)).mean())
top=m.sort_values('net_s',ascending=False).head(20); print('top20 syn -> real net mean %.1f, all real mean %.1f, real top20 mean %.1f'%(top.net_r.mean(), m.net_r.mean(), m.net_r.nlargest(20).mean()))
