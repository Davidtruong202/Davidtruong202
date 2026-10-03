# 10 SET chạy song song EA MASTER 4PP v1.10 + Dashboard V3.40

| SET | Magic_Goc | Magic lệnh | Nội dung |
|---|---|---|---|
| S01 | 301 | 3011 | PP1 RSI M1 (gốc) |
| S02 | 302 | 3021 | PP1 RSI M5 |
| S03 | 303 | 3032 | PP2 SMC M15 |
| S04 | 304 | 3042 | PP2 SMC H1 + lọc HTF H4 |
| S05 | 305 | 3053 | PP3 Pivot bật lại M15 |
| S06 | 306 | 3063 | PP3 Pivot phá vỡ M15 |
| S07 | 307 | 3074 | PP4 QM M15 |
| S08 | 308 | 3084 | PP4 QM H1 |
| S09 | 309 | 3091-3094 | Cả 4 PP, BALANCED, độc lập |
| S10 | 310 | 3101-3104 | Cả 4 PP, SAFE, không đối nghịch, chặn ngược chiều |

Mọi SET: vốn ảo 5000 USD từ 2026.10.01 00:00 (trùng Dashboard), rủi ro 0.5%/lệnh
trên vốn ảo, nhật ký lệnh ghi vào `Common\Files\EAM_<SET>_<Magic>.csv`.

Cách chạy: mở 11 chart XAUUSD (khung chart bất kỳ). 10 chart gắn `EA_MASTER_4PP`,
tab Inputs -> Load -> chọn 1 file `EAM_Sxx_*.set` cho mỗi chart. Chart thứ 11 gắn
`EA_MAGIC_DASHBOARD_V3_40` với `EA_MAGIC_DASHBOARD_V3_40.set`.
