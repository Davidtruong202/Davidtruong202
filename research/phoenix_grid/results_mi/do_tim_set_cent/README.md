# Dò set Phoenix Grid cho tài khoản cent — kết quả mô phỏng

Tất cả số liệu ở đây là **mô phỏng Python**, không phải backtest MT5:

- mô phỏng: `mo_phong_phoenix.py`;
- dò set: `do_tim_set_cent.py`;
- dữ liệu: nến XAUUSDm M1, 01/01–27/09/2026.

Báo cáo đầy đủ: [`docs/phoenix_grid/11_EA_V0_23_BO_PP10_SET_CENT.md`](../../../../docs/phoenix_grid/11_EA_V0_23_BO_PP10_SET_CENT.md).

| Thư mục / file | Nội dung |
|---|---|
| `so_sanh_mo_hinh_duong_gia.csv` | So sánh 3 mô hình đường giá. Mô hình 4 điểm / nến của lượt dò đầu cho kết quả lạc quan, nên lượt đó đã dừng |
| `von_5000/` | Vốn 5.000 USC, lot 0,01 — chỉ DEV. Không có set an toàn; không chạy VAL / TEST |
| `von_10000/` | Vốn 10.000 USC (100 USD) — DEV, rồi VAL (không set nào đạt). Kèm 5 ứng viên chạy ở 200 / 500 USD (`von_cao.csv`, không đạt). Không chạy TEST |
| `von_50000/` | Vốn 50.000 USC (500 USD), tiêu chí DD ≤ 35%. Các bước: DEV → VAL → tối ưu lot → TEST một lần: **U4 lot 0,01 ĐẠT**. Kèm bảng vốn – lot – lãi mỗi ngày (`quy_doi_von_hang1_9thang*.csv`) |

Trong mỗi thư mục:

- **Theo bước:**
  - `dev_1_ngau_nhien.csv`: bước 1, dò ngẫu nhiên, đường giá gốc;
  - `dev_5_ben.csv`: 4 đường giá nhiễu;
  - `dev_6_lang_gieng_ben.csv`: láng giềng một bước;
  - `dev_7_nhieu_them.csv`: 16 đường DEV thêm, chỉ để tham khảo;
  - `dev_4_hedge_tham_khao.csv`: hedge V0.22, tham khảo.
- **Đăng ký trước (commit trước khi chạy bước kế tiếp):**
  - `ung_vien_dang_ky.json` + `DANG_KY_TRUOC_VAL.md`: ứng viên, trước VAL;
  - `chon_sau_val.json` + `DANG_KY_TRUOC_TEST.md`: set chọn, trước TEST;
  - `chon_lot.json`: lot chọn, trước TEST.
- **Kết quả kiểm định:**
  - `val.csv`: VAL;
  - `test_lot.csv`: TEST, chỉ chạy một lần;
  - `ca_9_thang_lot.csv`: cả 9 tháng, tham khảo.
- **Tóm tắt:** `BAO_CAO_DO_TIM.md`, gồm mọi biến thể, kể cả các biến thể cháy tài khoản.
