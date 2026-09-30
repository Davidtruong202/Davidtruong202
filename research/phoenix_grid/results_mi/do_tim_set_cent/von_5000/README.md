# Dò set với vốn 5.000 USC (~50 USD), lot tầng 0 0,01 — chỉ DEV, KHÔNG chạy VAL / TEST

- Đây là mô phỏng Python (`mo_phong_phoenix.py`), không phải backtest MT5.
- Giai đoạn DEV 01/01–30/04/2026, có phiên 30/01/2026 biên độ 768 USD.
- Luật và mã: `do_tim_set_cent.py` tại commit chứa thư mục này.

## Kết quả

- **Bước 1** — 363 cấu hình ngẫu nhiên và cấu hình tham chiếu: 300 cháy tài khoản ít nhất một lần; 0 đạt mức A (DD ≤ 30%), 6 đạt mức B, 26 đạt mức C.
- **Bước 2 và 3** — 8 hạt giống, 194 láng giềng, 48 lần chạy nhiễu: 0 ứng viên.
  - Chỉ cần đổi thứ tự đỉnh / đáy trong nến M1, cùng một cấu hình lúc cháy, lúc không.
  - Lệch giờ bắt đầu không đổi kết quả, vì thời gian đó vẫn nằm trong giai đoạn làm nóng MA.
- **Bước "bền"** — 160 cấu hình không cháy ở đường gốc chạy thêm 4 đường giá: 37 cấu hình không cháy trên cả 5 đường.
  - Chỉ 1 cấu hình có DD lớn nhất ≤ 50%, là 41,9%.
  - Không cấu hình nào có DD ≤ 30%.
- **Kết luận:** với 5.000 USC trên mỗi 0,01 lot, không có set nào vừa không cháy vừa có DD thấp trên giai đoạn này.

## Vì sao dừng ở đây

- Ngày 30/09/2026 bạn cho biết vốn tài khoản cent có thể là 100–200 USD, hoặc 500 USD (10.000–50.000 USC).
- Việc dò được làm lại với vốn mới. Các ứng viên trong `ung_vien_dev_von_5000.json` **không** được chạy VAL / TEST và không dùng làm set.
