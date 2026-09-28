"""Chuyển file JSON kết quả thành bảng Markdown."""
import json, sys
d = json.load(open(sys.argv[1]))
cols = ['trades','net_R','max_dd_R','win_rate','profit_factor','expectancy_R','realized_RR','max_losing_streak']
hdr = ['Biến thể','Tập','Lệnh','Net R','MaxDD R','Win %','PF','Exp R','RR thực','Chuỗi thua']
print(f"Dữ liệu {d['data'][0]} → {d['data'][1]}; tách IS/OOS tại {d['cut']}\n")
for sec, title in (('tf_pairs','Cặp khung thời gian (phút HTF->LTF)'),
                   ('ablation_H1_M5','Ablation trên H1->M5 (mỗi dòng đổi 1 yếu tố so với mặc định)'),
                   ('spread_stress_H1_M5','Stress spread trên H1->M5')):
    print(f"### {title}\n")
    print('| ' + ' | '.join(hdr) + ' |')
    print('|' + '---|' * len(hdr))
    for n, x in d[sec].items():
        for part in ('IS', 'OOS'):
            s = x[part]
            print(f"| {n} | {part} | " + ' | '.join(str(s.get(c, '')) for c in cols) + ' |')
    print()
