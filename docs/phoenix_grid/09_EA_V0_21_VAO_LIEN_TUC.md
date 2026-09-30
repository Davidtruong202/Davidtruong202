# EA Phoenix Grid V0.21 TEST — vào lệnh liên tục (PP0) + sửa lỗi hiển thị

**DAVID HUNTER – PHOENIX GRID – 0941920986**

> **Trạng thái: TEST.**
>
> - File: [`EA_PHOENIX_GRID_V0_21_TEST.mq5`](../../MQL5/Experts/PhoenixGrid/EA_PHOENIX_GRID_V0_21_TEST.mq5).
>   [`EA_PHOENIX_GRID_V0_20_TEST.mq5`](../../MQL5/Experts/PhoenixGrid/EA_PHOENIX_GRID_V0_20_TEST.mq5) giữ nguyên để
>   quay lại.
> - **Đã compile trên MetaEditor của bạn (30/09/2026): 0 lỗi, 1 cảnh báo.** Cảnh báo là
>   "version '0.21' is incompatible with MQL5 Market, must be xx.yyy" (dòng 36): chỉ liên quan tới việc bán trên MQL5
>   Market, không ảnh hưởng EA chạy. Môi trường của tôi không có MetaEditor; kết quả trên là từ ảnh bạn gửi.
> - **Chưa backtest.** Không có con số hiệu suất nào trong tài liệu này.
> - Xử lý lệnh (DCA, tỉa, 4 cơ chế clear, không SL) giữ nguyên V0.20: xem
>   [`06_EA_V0_20_DCA_TIA.md`](06_EA_V0_20_DCA_TIA.md). Tài liệu này chỉ ghi phần thay đổi.
> - Không cam kết lợi nhuận. Vào lệnh liên tục nghĩa là tài khoản gần như lúc nào cũng có basket (Mục 3).

## 1. Quyết định của bạn ngày 30/09/2026

| Nội dung bạn viết | Ghi nhận |
|---|---|
| "Tôi muốn vào lệnh liên tục cho Phoenix, còn lại là ở tư duy xử lí lệnh của Phoenix. Bản chất bot DCA là phải xử lí được lệnh" | Phương án A bạn chọn: **PP0**. Không có basket thì mở lệnh đầu ngay khi hết thời gian chờ sau clear, hướng theo MA50 H1 như lệnh đầu của Hydra. PP10, PP1 và mọi bộ lọc Phoenix giữ nguyên |
| Lý do đổi | Đo trên nến 2026: PP10 như đang hiểu chỉ có 3 tín hiệu trong 9 tháng, PP1 khoảng 0,67 đợt mỗi ngày ([`tan_suat_vao_lenh_V0_20.md`](../../research/phoenix_grid/results_mi/tan_suat_vao_lenh_V0_20.md)). V0.20 gần như không vào lệnh |
| Ảnh bảng V0.20: "Hôm nay −1000.00 (−103.96%)", chữ "Label" ở đầu bảng | Hai lỗi hiển thị, sửa ở Mục 4. Không ảnh hưởng lệnh |
| File set Hydra đang chạy | Hướng lệnh đầu của Hydra: `InpMAPeriod=50`, `InpMATimeframe=16385` (H1), chờ 10 giây sau khi đóng rổ. PP0 dùng đúng MA50 H1 và thời gian chờ 10 giây (`InpGiayChoSauClear`, có từ V0.20). Phần giải mã Hydra: [`10_HYDRA_4_5_GIAI_MA.md`](10_HYDRA_4_5_GIAI_MA.md) |

## 2. PP0 — vào lệnh liên tục

Thứ tự mỗi tick (V0.20 thêm bước cuối):

```
QUẢN LÝ BASKET ─► PP10 (khi có nến M2 mới) ─► PP1 (mỗi nến M1, khi giá ở vùng biên hộp) ─► PP0 (tối đa mỗi giây một lần)
```

PP0 chỉ xét khi **không có basket**:

1. Đọc giá trị MA (mặc định SMA 50, khung H1, nến hiện tại).
2. Hướng: Bid > MA → **BUY**; Ask < MA → **SELL**. Giá đang chạm MA (Bid ≤ MA ≤ Ask) thì chưa vào.
3. Qua toàn bộ điều kiện mở basket của V0.20 (hàm `LyDoChanMoBasket`):
   - được gửi lệnh; không tạm dừng; không lỗi nghiêm trọng; không có vị thế lạ;
   - không bị khóa sau stop out; DD chưa vượt ngưỡng (tắt mặc định);
   - hết 10 giây chờ sau khi clear basket;
   - bộ lọc: đủ dữ liệu, trong phiên, không sát giờ nghỉ, không mất tick, spread đạt;
   - không gần tin USD quan trọng; chưa đủ số lệnh trong ngày; margin đạt.
4. Qua bộ lọc Phoenix theo hướng (hàm `ChanTheoPhoenix`):
   - không vào ngược breakout đang cảnh báo / xác nhận;
   - không vào ngược xu hướng M5 của Phoenix.

   PP0 **không** bị chặn khi Phoenix nhận SIDEWAYS. Chặn sideways chỉ áp dụng cho PP10 như V0.20.
5. Đạt hết thì mở basket như V0.20: tầng 0 lot 0,01, khoảng tầng max(6 USD, 1,15 × ATR M5), TP tỉa ở mức tầng liền
   trên. Basket ghi nguồn `PP0`: trên bảng ("BUY PP0 · n lệnh"), thông báo, log basket, trạng thái lưu (mã 20).

PP10 và PP1 vẫn được ưu tiên: trong cùng một tick, hai PP này được xét trước PP0. Thực tế PP0 mở basket ngay khi hết
thời gian chờ, nên PP10 và PP1 hiếm khi còn cơ hội. Muốn chạy lại cách vào lệnh của V0.20 (có các bản sửa lỗi): đặt
`InpDungPP0 = false`.

Điều cần biết khi xem bảng và log:

- Sau mỗi lần clear: khoảng 10 giây sau là basket mới, nếu không bị chặn.
- MA50 H1 và xu hướng M5 của Phoenix ngược nhau (ví dụ giá vừa gãy xuống dưới MA50 H1, M5 vẫn TĂNG): **không mở
  basket** tới khi hai bên thuận nhau, hoặc M5 về KHÔNG RÕ / SIDEWAYS. Việc này có thể kéo dài nhiều giờ. Dòng cuối
  khối PHOENIX DCA ghi "Xét gần nhất: PP0 … BI_CHAN: Ngược xu hướng M5 Phoenix".
- Log tín hiệu không ghi mỗi giây. PP0 chỉ ghi một dòng khi hướng, kết quả hoặc lý do thay đổi, và một dòng `VAO_LENH`
  mỗi lần mở basket.

## 3. Rủi ro khi vào lệnh liên tục

Rủi ro của mỗi basket không đổi so với V0.20: lot 0,01 đều, tối đa 40 tầng, khoảng tầng tối thiểu 6 USD. Vốn 5.000
cạn khi giá đi ngược khoảng **242 USD** tính từ tầng 0 (tài liệu 06, Mục 9). DD 15% khi giá ngược khoảng 92 USD, 20%
khoảng 107 USD, 25% khoảng 120 USD.

Cái thay đổi là **thời gian có mặt trên thị trường**. V0.20 hầu như đứng ngoài; V0.21 gần như lúc nào cũng có basket.
Mọi đợt giá chạy mạnh đều gặp một basket đang mở. Hướng basket lấy theo MA50 H1, vốn trễ: lúc thị trường đảo chiều,
basket mới vẫn mở theo xu hướng cũ.

Số đo biến động ngược từ một điểm vào bất kỳ trên nến M1 XAUUSDm 01–09/2026 (phụ lục
[`02_PHU_LUC_THONG_KE_DU_LIEU.md`](02_PHU_LUC_THONG_KE_DU_LIEU.md), Mục A.5). Đây là đặc tính của giá, không phải kết
quả backtest. Basket có thể đã clear trước khi giá đi hết mức ngược:

| Trong vòng | Giá ngược ≥ 100 USD (BUY / SELL) | ≥ 200 USD | ≥ 300 USD |
|---|---|---|---|
| 24 giờ | 16,8% / 14,1% | 3,8% / 2,2% | 2,0% / 0,7% |
| 3 ngày | 35,7% / 29,7% | 10,6% / 9,4% | 5,6% / 2,4% |
| 5 ngày | 47,2% / 39,3% | 18,0% / 17,5% | 7,7% / 5,2% |

Với cách vào lệnh liên tục, khả năng gặp một đợt ngược vượt mức cháy (khoảng 242 USD) trong vài tuần là đáng kể. Theo
quyết định "tới khi nào bị cháy tài khoản thì nạp lại", EA không có cắt lỗ. Lớp phòng thủ (khóa DCA, hedge khi
breakout) là phần TEST 2+ của Market Intelligence, chưa có trong V0.21.

## 4. Sửa lỗi hiển thị

### 4.1. "Hôm nay" trừ hai lần tiền nạp

- **Hiện tượng:** bảng V0.20 ghi "Hôm nay −1000.00 (−103.96%)" dù tài khoản không lỗ.
- **Nguyên nhân:** "Hôm nay" = Equity − Equity đầu ngày − nạp / rút trong ngày. Khi gắn lại EA trong cùng ngày
  (compile lại, nạp file set, mở lại MT5), V0.20 cộng mọi khoản nạp từ 00:00. Khoản nạp trước lúc EA lấy Equity đầu
  ngày đã nằm trong Equity đầu ngày, nên bị trừ thêm lần nữa.
- **Sửa:** EA lưu thêm thời điểm lấy Equity đầu ngày (GlobalVariable `…dau_ngay_luc`). Khi gắn lại, chỉ cộng nạp / rút
  **sau** thời điểm đó. Nạp tiền lúc EA đang chạy vẫn được tính như cũ.
- **Lần đầu gắn V0.21 trong ngày:** trạng thái lưu từ V0.20 không có thời điểm này. EA lấy lại Equity đầu ngày từ lúc
  gắn, nên "Hôm nay" bắt đầu từ 0.

### 4.2. Chữ "Label" ở đầu bảng

- **Nguyên nhân:** MT5 hiện chữ "Label" khi đối tượng nhãn có nội dung rỗng. Dòng tóm tắt ở đầu bảng (dùng khi thu gọn
  bảng) và các dòng thông báo trống đều có nội dung rỗng.
- **Sửa:** nhãn rỗng được ghi bằng một dấu cách.

## 5. Input mới và input đổi mặc định

| Nhóm | Input | Mặc định | Ý nghĩa |
|---|---|---|---|
| 3 | PP0: vào lệnh liên tục (`InpDungPP0`) | true | Tắt thì vào lệnh như V0.20 |
| 3 | PP0: khung thời gian của MA (`InpPP0TF`) | H1 | Như Hydra |
| 3 | PP0: chu kỳ MA (`InpPP0MA`) | 50 | Như Hydra. Tối thiểu 2 |
| 3 | PP0: loại MA (`InpPP0Loai`) | SMA | Set Hydra không ghi loại MA; chọn SMA, cần xác nhận từ log Hydra |
| 9 | Số lệnh mở tối đa mỗi ngày (`InpLenhToiDaNgay`) | **1000** (V0.20: 200) | Chỉ là chốt an toàn. Vào lệnh liên tục cần nhiều lệnh hơn |

117 input (V0.20: 113). File set: [`PG_V021_DEMO_5000USD.set`](../../MQL5/Presets/PhoenixGrid/PG_V021_DEMO_5000USD.set)
(mặc định, trừ `InpChoPhepTKThat = false` để chặn tài khoản thật).

## 6. Log

- Tiền tố file đổi thành `PG_V021_`. Log `PG_V020_` cũ giữ nguyên.
- Log tín hiệu thêm cột cuối `ma_pp0`: giá trị MA lúc PP0 xét (23 cột). Các log khác giữ nguyên cột.
- `research/phoenix_grid/phan_tich_log_v020.py` đọc được cả hai tiền tố. Thêm `--phien-ban V021` để chỉ đọc V0.21.

## 7. Nâng cấp từ V0.20 trên MT5 demo

1. Chép thư mục `MQL5` trong gói
   [`PhoenixGrid_V0_21_MI_V0_01.zip`](../../goi_cai_dat/PhoenixGrid_V0_21_MI_V0_01.zip) vào Data Folder. Compile
   `EA_PHOENIX_GRID_V0_21_TEST.mq5` (F7, phải "0 errors").
2. Kéo `EA_PHOENIX_GRID_V0_21_TEST` thả vào **chính chart** đang chạy V0.20. MT5 hỏi thay EA → Yes. Tab Inputs → Load →
   `PG_V021_DEMO_5000USD.set`. Không chạy V0.20 và V0.21 cùng lúc trên một tài khoản.
3. Basket V0.20 đang mở (nếu có) được V0.21 nhận lại và xử lý tiếp: cùng magic 20260930, cùng trạng thái lưu.
4. Chart MI Shadow giữ nguyên, không cần gắn lại.

Hướng dẫn từng bước đầy đủ trong `HUONG_DAN_CAI_DAT.txt` của gói (phần "NẾU MT5 DEMO ĐANG CHẠY PHOENIX V0.20").

## 8. Kiểm tra kỹ thuật

| Hạng mục | Kết quả |
|---|---|
| Compile MQL5 | **Đạt trên MetaEditor của bạn (30/09/2026): 0 lỗi, 1 cảnh báo "version '0.21' is incompatible with MQL5 Market, must be xx.yyy" (dòng 36): chỉ liên quan tới việc bán trên MQL5 Market, không ảnh hưởng EA chạy** |
| Kiểm tra tĩnh `kiem_tra_tinh_mq5.py` | Đạt: ngoặc cân bằng, 140 hàm, mọi lời gọi có nguồn, không hàm trùng, mọi biến `g_` có khai báo, 117 input |
| Dựng từ V0.20 | Bằng script thay thế có kiểm tra: mỗi đoạn được thay phải khớp đúng một lần, sai là dừng |
| File set | `tao_file_set.py --kiem-tra`: 117 input khớp EA |
| Gói cài đặt | `dong_goi_cai_dat.py`: đạt (BOM, include, set khớp input) |
| `phan_tich_log_v020.py --tu-kiem-tra` | Đạt (tiêu đề đọc từ V0.21: tín hiệu 23 cột; đọc được cả hai tiền tố) |
| Backtest | **Chưa chạy** |

## 9. Quay lại V0.20

- EA, set `PG_V020_DEMO_5000USD.set` và gói `PhoenixGrid_V0_20_MI_V0_01.zip` giữ nguyên.
- Kéo V0.20 thả vào chart để thay V0.21. Basket đang mở chuyển qua lại được giữa hai bản. Basket mở bằng PP0 hiện tên
  "PP10" trên bảng V0.20, vì V0.20 không biết mã 20. Cách xử lý lệnh không đổi.
