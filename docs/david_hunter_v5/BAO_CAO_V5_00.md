# DAVID HUNTER V5.00 TICK AI — Báo cáo phát triển (bản TEST)

| Mục | Nội dung |
|---|---|
| Ngày phát triển | 29–30/09/2026 |
| Phiên bản gốc | Không có. Viết mới, độc lập với dòng V4.x: không dùng lại mã, Magic, GlobalVariable hay thư mục log của V4.x |
| File | `MQL5/Experts/DavidHunterV5/EA_DAVID_HUNTER_V5_00_TICK_AI_TEST.mq5` (UTF-8 có BOM, không cần file include), SET `set_v500_mac_dinh.set` |
| Magic mặc định | `500500` (V4.x dùng 68999, không trùng) |
| Trạng thái | **TEST. Chưa compile bằng MetaEditor, chưa backtest bằng MT5 Strategy Tester. Không dùng cho tài khoản thật.** |
| Không bị sửa | Repo EA-PRO, Baseline V4.53, V4.52, V4.48 và mọi file SET cũ |
| Quyết định của chủ dự án | Chấp nhận giới hạn lỗ ngày 10% (30/09/2026) |

## Tóm tắt

1. **Đã có một EA hoàn chỉnh.** EA phân tích từng tick, tự nhận diện 7 trạng thái thị trường và tự chọn 1 trong 3 phương pháp riêng. Mỗi tín hiệu được chấm điểm 0–100. EA học từ lệnh ảo, và mọi lệnh phải qua lớp kiểm soát rủi ro độc lập, khóa cứng trong mã.
2. **Lớp bảo vệ vốn đạt mọi bài kiểm tra trong bộ giả lập:**
   - rủi ro dự kiến lớn nhất 0,997% mỗi lệnh (kể cả khi trượt giá 0,30 mọi lệnh);
   - lỗ ngày không vượt giới hạn đặt (10% → lớn nhất 9,37%; đặt 2% → 1,97%);
   - không có vị thế nào thiếu SL/TP, không giữ lệnh qua đêm hay cuối tuần;
   - khôi phục đúng sau 6 lần khởi động lại khi đang giữ lệnh;
   - nạp/rút tiền không làm cầu dao sập nhầm;
   - tài khoản thật chưa được cho phép thì không gửi lệnh nào.
3. **Chưa phương pháp nào chứng minh được lợi thế.** Trên 9 tháng mô phỏng, mọi cấu hình đều lãi ở T1–T6 nhưng lỗ ở T7–T9. Kỳ vọng của toàn bộ tín hiệu thô xấp xỉ −0,03R. Điểm chất lượng tín hiệu không dự báo được kết quả. Kết quả thay đổi mạnh chỉ vì đổi một ngưỡng (xem mục 7). Kết luận này khớp với kiểm chứng MT5 9 tháng của V4.39: 6 phương pháp chọn từ dữ liệu ngắn đều lỗ.
4. **Vì vậy mặc định rất thận trọng:**
   - tài khoản THẬT chỉ phân tích, trừ khi bật công tắc riêng;
   - học theo chế độ "chứng minh trước": chỉ vào lệnh thật ở ô PP × hướng × phiên đã có kỳ vọng dương bằng lệnh ảo;
   - cầu dao sụt giảm tổng 20% từ đỉnh vốn.
5. **Việc cần làm trước mọi quyết định:** compile trong MetaEditor, backtest MT5 "Every tick based on real ticks" 9 tháng, rồi chạy demo có ghi log (mục 10).

---

## 1. Kiến trúc

| Tầng | Việc làm | Cập nhật |
|---|---|---|
| Bộ phân tích tick | Bộ đệm theo giây (1 giờ) và theo phút. Tính: tốc độ 5s/30s, gia tốc, cường độ tick (60 giây so với nền 30 phút), biến động thực, hiệu suất xu hướng 15 phút, cao/thấp 60 giây, spread trung bình, sốc giá, spread đột biến. Mất tick quá 90 giây thì khởi động lại dữ liệu | Mỗi tick, tính nặng mỗi giây |
| Bối cảnh khung lớn | Từ nến của terminal nên có ngay khi khởi động: ATR M1/M5/H1, EMA50 H1 và độ dốc, EMA20/50 M15, ER M5 (12 nến), đỉnh/đáy ngày trước, biên độ phiên Á, đỉnh/đáy 4 giờ, hộp tích lũy | Mỗi nến M1 mới |
| Nhận diện trạng thái | KHỞI ĐỘNG, SỐC, YẾU (chi phí cao), TĂNG, GIẢM, ĐI NGANG, CHUYỂN TIẾP | Mỗi giây |
| 3 phương pháp | Mỗi PP chỉ chạy ở trạng thái phù hợp (mục 2) | Thiết lập mỗi giây, kích hoạt theo tick |
| Chấm điểm | 6 thành phần: xu hướng, động lượng, gia tốc, cường độ, chi phí, cấu trúc → điểm 0–100 | Mỗi tín hiệu |
| Học thích nghi | Mỗi tín hiệu là một lệnh ảo (cùng SL/TP/hòa vốn/trailing). 18 ô PP × hướng × phiên + mô hình hồi quy logistic trực tuyến (chỉ phủ quyết) | Mỗi lệnh ảo đóng |
| Kiểm soát rủi ro | Độc lập với phần học máy; giới hạn khóa cứng trong mã (mục 4) | Trước mỗi lệnh và mỗi tick |
| Quản lý vị thế | SL/TP gắn ở máy chủ; hòa vốn tại 1R; trailing 1R từ 1,5R; giữ tối đa 240 phút; đóng hết lúc 20:40 giờ máy chủ | Mỗi tick |
| Khôi phục, log | Nhận lại vị thế theo comment `DH5|PP|mã` + GlobalVariable; log CSV theo tháng | Khi khởi động, mỗi sự kiện |

## 2. Ba phương pháp riêng

| PP | Trạng thái cho phép | Điểm vào (theo tick) | SL gốc |
|---|---|---|---|
| **PP1 Xu hướng – hồi – tiếp diễn** | TĂNG (chỉ BUY) / GIẢM (chỉ SELL) | Giá hồi 0,8–2,5 ATR M5 từ đỉnh/đáy 1 giờ. Đáy/đỉnh hồi đã hình thành ít nhất 20 giây, giá đã bật lại 0,25–1,0 ATR. Vào lệnh khi giá vượt cao/thấp 60 giây, đồng thời tốc độ 5s, 30s và gia tốc cùng chiều | Ngoài đáy/đỉnh hồi + 0,15 ATR |
| **PP2 Phá vỡ hộp tích lũy** | ĐI NGANG, CHUYỂN TIẾP, hoặc cùng chiều xu hướng | Hộp 45 phút nén (cao ≤ 0,9 × biên độ thường). Vào lệnh khi giá vượt hộp 0,1 ATR, cường độ tick ≥ 1,3 lần nền, tốc độ cùng chiều | Giữa hộp ∓ 0,1 ATR |
| **PP3 Quét thanh khoản – đảo chiều** | Mọi trạng thái giao dịch được, trừ đánh ngược xu hướng (không SELL khi TĂNG, không BUY khi GIẢM) | Giá quét qua đỉnh/đáy ngày trước, phiên Á hoặc 4 giờ từ 0,15 đến 1,5 ATR, rồi quay lại trong 900 giây với tốc độ và gia tốc ngược chiều quét | Ngoài cực trị lúc quét + 0,15 ATR |

Chung cho cả 3 PP:
- SL tối thiểu max(4,0; 0,8 ATR M5); SL tối đa 20,0, xa hơn thì bỏ tín hiệu.
- TP = 2R. Hòa vốn tại 1R; trailing 1R từ 1,5R; giữ lệnh tối đa 240 phút.
- Chỉ mở lệnh Thứ Hai–Thứ Sáu, 01:00–20:00 giờ máy chủ; đóng hết lúc 20:40.
- Mỗi PP tối đa 1 vị thế, tổng mặc định 1 vị thế (tối đa 3).

## 3. Chấm điểm và học thích nghi

- **Điểm** = 100 × (0,25 xu hướng + 0,20 động lượng + 0,10 gia tốc + 0,10 cường độ + 0,10 chi phí + 0,25 cấu trúc). Ngưỡng vào lệnh 55. Trọng số đặt trước, chưa được kiểm chứng. Mọi thành phần đều được ghi vào log `tin_hieu` để nghiên cứu lại.
- **Lệnh ảo:** mọi tín hiệu hợp lệ đều được theo dõi như lệnh ảo, kể cả tín hiệu bị bỏ qua. Nhờ vậy việc học không bị lệch do chính bộ lọc gây ra.
- **Ô học (18 ô):** kỳ vọng R trượt theo chu kỳ nhớ 40 lệnh.
  - *Chứng minh trước* (mặc định): mọi ô bắt đầu ở trạng thái chỉ lệnh ảo. Ô được bật khi có ≥ 30 lệnh ảo và kỳ vọng ≥ +0,10R; tắt lại khi kỳ vọng < 0.
  - *Tắt khi âm*: mọi ô bật từ đầu; tắt khi kỳ vọng < −0,10R, bật lại khi ≥ 0.
- **Mô hình xác suất thắng:** hồi quy logistic trực tuyến, 12 đặc trưng, học sau mỗi lệnh ảo. Sau 200 mẫu, mô hình phủ quyết tín hiệu có xác suất thắng < 0,36. Mô hình không có quyền tăng lot hay đổi SL/TP.
- **Lưu trữ:** trên Demo/Real, dữ liệu học được lưu mỗi 30 phút và khi tắt EA, vào `DavidHunterV5\DH5_<magic>_<symbol>_hoc.csv`, và được nạp lại khi khởi động. Trong Tester, mặc định EA không nạp dữ liệu học đã lưu, để tránh dùng thông tin tương lai.

## 4. Lớp kiểm soát rủi ro độc lập — đối chiếu yêu cầu nhóm D

| Yêu cầu | Cách làm trong V5.00 | Kiểm chứng trong bộ giả lập |
|---|---|---|
| Lấy toàn bộ số dư MT5 làm cơ sở | Vốn cơ sở = min(Balance, Equity): không bao giờ vượt 1% số dư, kể cả khi đang lãi thả nổi | — |
| Tối đa 1% mỗi vị thế | Khóa cứng `DH5_RUI_RO_TRAN = 1.0`, Input đặt cao hơn thì EA không khởi động. Lot tính theo khoảng SL, **cộng sẵn trượt giá dự phòng 0,30**, làm tròn xuống. Nếu lot tối thiểu vượt 1% thì bỏ lệnh, không làm tròn lên. Sau khi khớp, rủi ro thực > 1,05 × ngân sách thì đóng ngay | Lớn nhất 0,9719% (mặc định), 0,9974% (spread +0,10, trượt giá 0,30 mọi lệnh) |
| Lỗ ngày 10% vốn đầu ngày | Khóa cứng `DH5_LO_NGAY_TRAN = 10.0`. Vốn đầu ngày = Balance lúc 00:00 giờ máy chủ, tính lại từ lịch sử nên không mất khi khởi động lại | 9,37% (không học, 2.312 lệnh); đặt 2% → 1,97% |
| Tính cả đã đóng và thả nổi | Mặc định toàn tài khoản: lỗ ngày = −(Equity − Balance 00:00 − nạp/rút trong ngày). Tùy chọn chỉ tính lệnh EA | — |
| Không mở lệnh khi rủi ro vượt giới hạn | Trước mỗi lệnh: lỗ ngày hiện tại + rủi ro còn lại của mọi vị thế EA (tới SL hiện tại) + rủi ro lệnh mới ≤ 10%. Nhờ vậy tổng lỗ dự kiến không vượt 10% | Như trên |
| Dừng giao dịch khi chạm giới hạn ngày | Dừng mở lệnh đến ngày giao dịch sau, đóng mọi lệnh của EA; trạng thái lưu trong GlobalVariable | Như trên |
| Kiểm tra margin | Ký quỹ của lot thực ≤ 95% ký quỹ tự do, và mức ký quỹ sau khi vào lệnh ≥ 300% (sàn khóa cứng 150%) | — |
| AI không tự đổi giới hạn vốn | Mô hình và ô học chỉ quyết định có vào lệnh hay không. Không hàm học nào đọc hay ghi giới hạn vốn | Đọc mã |
| Không Martingale/DCA | Lot chỉ tính theo rủi ro; không nhồi lệnh, không tăng lot sau khi thua; mỗi PP tối đa 1 vị thế | Số vị thế đồng thời lớn nhất: 1 |
| Mất kết nối / khởi động lại MT5 | SL/TP gắn ở máy chủ ngay khi mở; vị thế thiếu SL/TP thì đặt lại hoặc đóng. Nhận lại vị thế theo comment + GlobalVariable. Lệnh có kết quả chưa rõ thì đối chiếu 15 giây trước khi nhận tín hiệu mới. Mất kết nối thì không mở lệnh. Mất tick > 90 giây thì khởi động lại dữ liệu | 6 lần khởi động lại giữa lệnh: nhận lại đủ, giữ cờ hòa vốn, đóng đúng R |
| Ghi nhận rủi ro gap/trượt giá | Log từng lệnh: giá yêu cầu, giá khớp, trượt giá, trượt tại SL, R thực tế. Lệnh lỗ vượt 1,1R ghi sự kiện `VUOT_RUI_RO_DU_KIEN` | Có trong log và bảng kết quả |
| **Bổ sung:** cầu dao sụt giảm tổng | Equity giảm ≥ 20% từ đỉnh → dừng hẳn và đóng lệnh của EA. Chỉ mở lại bằng Input `InpDatLaiDinhVon`. Nạp/rút tiền dời đỉnh tương ứng | Sập đúng ở 20,00%; rút 3.000 / nạp 2.000 không sập nhầm |

Lý do thêm cầu dao sụt giảm: khi tắt học thích nghi, bộ giả lập cho max DD **57,5%** dù đã giới hạn 1%/lệnh và 10%/ngày. Hai giới hạn đó không chặn được sụt giảm tích lũy qua nhiều ngày khi phương pháp không có lợi thế. Đặt `InpSutGiamToiDa = 0` để tắt.

## 5. Vận hành

- **Tài khoản thật:** `InpChoPhepTaiKhoanThat = false` (mặc định) → EA chỉ phân tích và ghi lệnh ảo, không gửi lệnh. Có thể chạy song song với V4.53 để thu thập dữ liệu mà không ảnh hưởng tài khoản.
- **Giờ (máy chủ Exness GMT+0):** chỉ mở lệnh từ 01:00 đến trước 20:00. Đóng hết lúc 20:40, trước giờ nghỉ hằng ngày (~21:00 mùa hè, ~22:00 mùa đông) và trước giờ đóng cửa cuối tuần. Nhờ vậy EA không giữ lệnh qua gap.
- **Tạm dừng tự động:**
  - sốc giá: biến động 5 giây ≥ max(10 lần mức thường, 4,0), dừng 300 giây;
  - spread đột biến: ≥ 2,5 lần trung bình;
  - chi phí cao: spread/ATR M5 > 0,08;
  - thị trường đóng: 5 phút;
  - lỗi sàn nghiêm trọng: 15 phút; 5 lần trong ngày thì khóa đến hết ngày.
- **Log** (`MQL5\Files\Common\DavidHunterV5\`, mỗi tháng một file):

  | File | Nội dung |
  |---|---|
  | `DH5_<magic>_YYYY_MM_tin_hieu.csv` | Mọi tín hiệu, 6 thành phần điểm, đặc trưng tick, quyết định và lý do |
  | `DH5_<magic>_YYYY_MM_lenh.csv` | Mở/đóng lệnh: trượt giá, tiền rủi ro, R, MFE/MAE, thời gian giữ |
  | `DH5_<magic>_YYYY_MM_lenh_ao.csv` | Kết quả mọi lệnh ảo |
  | `DH5_<magic>_YYYY_MM_su_kien.csv` | Đổi trạng thái, sốc, dừng ngày, cầu dao, khôi phục, lỗi |
  | `DH5_<magic>_ket_qua_<từ>_<đến>.csv` | Chỉ trong Tester: chỉ số tổng, theo PP, phiên, hướng, trạng thái, ô học |

- **Bảng trạng thái** (`Comment`, 1 giây/lần): chế độ, trạng thái thị trường, số liệu tick, lỗ ngày/giới hạn, sụt giảm/cầu dao, vị thế, kết quả học từng ô, tín hiệu gần nhất.

## 6. Kiểm tra kỹ thuật

| Hạng mục | Kết quả |
|---|---|
| **Compile MetaEditor** | **CHƯA KIỂM TRA ĐƯỢC.** Môi trường không có MetaEditor/MT5 |
| Kiểm tra cú pháp/kiểu thay thế | Dịch mã MQL5 sang C++ (`tools/mt5sim/mq5_to_cpp.py`) và biên dịch bằng g++ `-Wall -Wextra` cùng lớp giả lập API MQL5: **0 lỗi, 0 cảnh báo**. Cách này bắt được lỗi định danh, sai số tham số, sai kiểu, gọi hàm chưa khai báo. Nó không thay thế MetaEditor: một số quy tắc riêng của MQL5 không được kiểm tra |
| Lỗi runtime | Chạy 2,73 triệu tick thật và 51 triệu tick sinh: không tràn chỉ số mảng (mảng có kiểm tra chỉ số), không chia cho 0 (bẫy FE_DIVBYZERO/FE_INVALID giống lỗi "zero divide" của MQL5) |
| Lỗi đã phát hiện và sửa khi kiểm thử | (1) Mã tín hiệu lặp lại sau khởi động lại → nay lưu trong GlobalVariable. (2) Nạp tiền làm cầu dao sập nhầm (đỉnh bị cộng hai lần do độ trễ đọc lịch sử 5 giây) → nay Balance đổi là đọc lịch sử ngay trong tick đó. (3) Ngưỡng sốc giá quá nhạy (15–17 lần/ngày trên tick thật) → hiệu chỉnh theo tần suất còn ~1–3 lần/ngày. (4) `GetTickCount64` có thể là giờ thật trong Tester → các nhịp ảnh hưởng giao dịch dùng giờ máy chủ của tick |
| Khởi động lại EA | 6 lần OnDeinit+OnInit khi đang giữ lệnh (giả lập đổi khung): nhận lại đủ vị thế, R0, tiền rủi ro, cờ hòa vốn; không vị thế nào thiếu SL/TP |
| Tài khoản thật chưa cho phép | 0 lệnh; 62 tín hiệu đủ điều kiện bị chặn với lý do `TAI_KHOAN_THAT_CHUA_DUOC_PHEP` |
| Input vượt khóa cứng | Rủi ro > 1%, lỗ ngày > 10%, ký quỹ < 150%, số vị thế > 3 → `INIT_PARAMETERS_INCORRECT` |
| Input tiếng Việt có dấu | 67 Input và mọi lựa chọn enum đều có mô tả tiếng Việt có dấu |

## 7. Kết quả mô phỏng (bộ giả lập mt5sim — KHÔNG phải backtest MT5)

Chung cho mọi lượt chạy:
- Vốn 10.000 USD, đòn bẩy 1:200, contract 100, lot 0,01–200.
- Commission 0, swap 0 (EA không giữ lệnh qua đêm).
- SL/TP khớp tại giá tick, gồm cả gap.

Có hai loại dữ liệu:
- **Tick thật:** Exness XAUUSDm 01/01 23:05 → 12/01/2026 13:00 (2,73 triệu tick). Bối cảnh H1 cần khoảng 80 nến nên EA chỉ bắt đầu giao dịch từ khoảng 06/01.
- **Tick sinh:** từ nến M1 01/01 → 27/09/2026 (51 triệu tick; số tick mỗi phút = tick_volume; đường giá trong phút là cầu Brown qua O–H–L–C).

Trên cùng giai đoạn 01–12/01, tick sinh cho số lệnh tương đương tick thật (33 so với 34) nhưng cơ cấu PP khác nhiều, vì tín hiệu tick phụ thuộc vi động thái giá thật. **Vì vậy kết quả 9 tháng chỉ là ước lượng thô.**

### 7.1. Chín tháng, tick sinh

| Cấu hình | Lệnh | WR | PF | Net | Kỳ vọng | Max DD | T1–T6 | T7–T9 |
|---|---|---|---|---|---|---|---|---|
| **Mặc định** (chứng minh trước + cầu dao 20%) | 338 | 39,4% | 1,10 | +21,7% | +0,074R | 20,0%, cầu dao sập 03/09 | +4.308 | −2.142 |
| Chứng minh trước, tắt cầu dao | 391 | 38,4% | 1,07 | +17,4% | +0,055R | 25,8% | +4.308 | −2.564 |
| Tắt khi âm, tắt cầu dao | 823 | 34,8% | 1,00 | +0,7% | +0,008R | 25,3% | +892 | −817 |
| Không học, không mô hình, tắt cầu dao | 2.312 | 33,4% | 0,95 | −42,2% | −0,020R | **57,5%** | −2.697 | −1.521 |
| Stress: spread +0,10, trượt giá 0,30 mọi lệnh (mặc định, tắt cầu dao) | 119 | 33,6% | 0,99 | −0,6% | +0,003R | 17,0% | −16 | −47 |

Theo tháng, cấu hình chứng minh trước tắt cầu dao: +911 · +428 · +1.654 · −55 · +1.314 · +56 · **−415 · −1.661 · −488**.

### 7.2. Tick thật 01–12/01/2026

| Cấu hình | Lệnh | WR | PF | Net | Max DD | Lỗ ngày lớn nhất |
|---|---|---|---|---|---|---|
| Mặc định | 0 (96 tín hiệu, chưa ô nào đủ 30 lệnh ảo dương) | — | — | 0 | 0 | 0 |
| Tắt khi âm | 44 | 18,2% | 0,41 | −14,7% | 14,8% | 6,45% |

### 7.3. Phân tích toàn bộ lệnh ảo (4.686 tín hiệu, 9 tháng, tick sinh, bản cuối)

Kỳ vọng R ± sai số chuẩn (số lệnh ảo):

| Nhóm | T1–T6 | T7–T9 |
|---|---|---|
| PP1 | +0,007 ± 0,038 (1.041) | −0,089 ± 0,050 (553) |
| PP2 | −0,022 ± 0,045 (699) | +0,073 ± 0,064 (383) |
| PP3 | −0,037 ± 0,033 (1.251) | −0,071 ± 0,042 (759) |
| Điểm 65–75 | +0,081 ± 0,045 (750) | −0,060 ± 0,062 (356) |
| Điểm 75–100 | −0,046 ± 0,067 (313) | +0,113 ± 0,103 (150) |
| BUY | −0,129 ± 0,030 (1.453) | −0,053 ± 0,039 (876) |
| SELL | +0,087 ± 0,031 (1.538) | −0,035 ± 0,042 (819) |

Không nhóm nào dương ổn định ở cả hai nửa với sai số đủ nhỏ. Tôi đã kiểm thêm 2 giả thuyết đặt trước, đều không đạt:
- chỉ giao dịch cùng xu hướng D1: cùng chiều và ngược chiều cho kết quả như nhau ở cả hai nửa;
- trôi giá theo giờ/phiên: không giờ nào có ý nghĩa thống kê ổn định.

Các file: `research/david_hunter_v5/`.

**Độ nhạy:** chỉ đổi ngưỡng độ dốc H1 từ 0,10 xuống 0,05 (hiệu chỉnh theo tần suất để trạng thái xu hướng chiếm ~23% thay vì ~12% thời gian, quyết định trước khi xem lãi/lỗ) đã làm PP1 đổi từ PF 1,21 thành PF 0,25 trên cùng dữ liệu. Tôi giữ 0,05 vì đó là quyết định đặt trước, **không chọn ngưỡng theo lãi/lỗ**.

**Kết luận:** Chưa đạt tiêu chí nghiệm thu. Không đưa lên tài khoản thật.

## 8. Đánh giá rủi ro gap và trượt giá

Số liệu gap từ nến M1 Exness XAUUSDm 01/01–27/09/2026:

| Loại nghỉ | Số lần | Trung vị | p90 | Lớn nhất |
|---|---|---|---|---|
| Cuối tuần/lễ | 40 | 14,1 | 52,4 | 98,0 (30/01→01/02) |
| Nghỉ hằng ngày (~1 giờ) | 151 | 2,6 | 12,2 | 34,6 |

- Nếu giữ lệnh qua gap, một lệnh SL 5,0 (rủi ro dự kiến 1%) gặp gap 20 sẽ lỗ khoảng 4%, gặp gap 98 sẽ lỗ khoảng 20%. V5.00 đóng hết lúc 20:40 nên không chịu các gap này. Trong mọi lượt mô phỏng không có lệnh nào giữ qua giờ đóng cuối ngày hay cuối tuần.
- Rủi ro còn lại là gap/trượt giá **trong phiên**, khi có tin (692 nến M1 có biên độ ≥ 20 trong 9 tháng). Mô phỏng ghi nhận lỗ vượt 1,1R ở khoảng 1% số lệnh, và 3,4% khi thêm trượt giá 0,30 mỗi lệnh. Lệnh xấu nhất −1,32R (tick sinh) và −1,02R (tick thật). Trên tài khoản thật, trượt giá tại SL có thể lớn hơn; EA ghi lại từng trường hợp để theo dõi.

## 9. Chưa kiểm chứng và giới hạn đã biết

- Chưa compile bằng MetaEditor. Nếu MetaEditor báo lỗi hay cảnh báo, gửi lại nguyên văn để sửa.
- Chưa backtest bằng MT5. Bộ giả lập không mô phỏng: requote, từ chối lệnh, thị trường đóng, stop level/freeze level thật, commission/swap thật.
- Kết quả 9 tháng dùng tick sinh từ nến M1, nên tín hiệu cấp tick khác thực tế.
- Tick thật hiện chỉ có 01–12/01/2026 (1/15 file zip); cần tải thêm các phần còn lại.
- Trọng số điểm, ngưỡng PP và tham số mô hình là giá trị đặt trước, chưa tối ưu và chưa được kiểm chứng.
- Lỗ ngày phạm vi "toàn tài khoản" tính Equity so với Balance 00:00. Vị thế tay/EA khác giữ qua đêm sẽ mang lãi/lỗ thả nổi từ hôm trước vào ngày mới.
- Rút tiền lúc EA không chạy, sang ngày khác, có thể bị cầu dao hiểu là sụt giảm. Khi đó dùng `InpDatLaiDinhVon = true` một lần.
- Hai EA cùng Magic trên cùng symbol sẽ dùng chung log và GlobalVariable. Mỗi biểu đồ cần một Magic riêng.

## 10. Hướng dẫn kiểm thử trên MT5 và tiêu chí nghiệm thu

1. Chép `EA_DAVID_HUNTER_V5_00_TICK_AI_TEST.mq5` vào `MQL5\Experts\`, mở bằng MetaEditor, compile (F7), rồi ghi lại số lỗi và cảnh báo.
2. Strategy Tester:
   - chọn XAUUSDm (hoặc symbol đang dùng), chế độ **Every tick based on real ticks**, 01/01 → 27/09/2026;
   - vốn 10.000 USD, Execution tùy sàn, nạp `set_v500_mac_dinh.set`.
3. Chạy 3 lượt để so sánh:

   | Lượt | Thay đổi so với SET mặc định |
   |---|---|
   | A | Giữ nguyên mặc định |
   | B | `InpSutGiamToiDa=0` (xem trọn giai đoạn) |
   | C | B + `InpCheDoHoc=1` |

   Sau mỗi lượt, lấy file `DH5_500500_ket_qua_*.csv` và thư mục log `Common\Files\DavidHunterV5\`.
4. **Tiêu chí nghiệm thu:** lượt B phải đạt đủ các điều kiện sau thì mới xét tới chạy demo. Không đạt thì giữ nguyên hiện trạng, không đưa V5.00 lên tài khoản thật.
   - PF ≥ 1,20 ở **cả** T1–T6 và T7–T9;
   - ≥ 200 lệnh;
   - kỳ vọng ≥ +0,10R;
   - max DD ≤ 20%;
   - lỗ ngày lớn nhất ≤ 10%;
   - rủi ro mỗi lệnh ≤ 1% (kiểm tra cột `tien_rui_ro` trong log `lenh`);
   - lượt stress spread cao vẫn PF > 1.
5. **Demo:** chạy ít nhất 4–8 tuần với magic riêng. Theo dõi `lenh_ao` và bảng học, so sánh với backtest.
6. **Tài khoản thật:** chỉ khi chủ dự án phê duyệt. Bật `InpChoPhepTaiKhoanThat = true` trên tài khoản cent trước.

## 11. Cài đặt và rollback

- V5.00 là EA mới, chạy độc lập với V4.x (Magic, GlobalVariable, thư mục log khác nhau). Không cần rollback V4.x.
- Gỡ V5.00: tháo EA khỏi biểu đồ. Vị thế của V5.00 (nếu có) giữ nguyên SL/TP ở máy chủ. Muốn xóa sạch, xóa GlobalVariable có tiền tố `DH5_500500_` và thư mục `Common\Files\DavidHunterV5\`.

## 12. Tệp liên quan

| Đường dẫn | Nội dung |
|---|---|
| `MQL5/Experts/DavidHunterV5/EA_DAVID_HUNTER_V5_00_TICK_AI_TEST.mq5` | Mã EA |
| `MQL5/Experts/DavidHunterV5/set_v500_mac_dinh.set` | SET mặc định (UTF-16) |
| `tools/mt5sim/` | Bộ dịch MQL5 → C++, lớp giả lập API và bộ giả lập MT5 (xem README) |
| `research/david_hunter_v5/` | Script nghiên cứu dữ liệu tick/M1 và kết quả mô phỏng (`ket_qua/`) |
