# Thu log & suy ngược logic một EA bất kỳ

| File | Vai trò |
|---|---|
| [`../../MQL5/Experts/TradeLogger/TradeLogger_Universal.mq5`](../../MQL5/Experts/TradeLogger/TradeLogger_Universal.mq5) | Logger 3.00 **dùng cho mọi EA**: tự khai báo chỉ báo, đơn vị point/pip |
| [`../../MQL5/Experts/TradeLogger/TradeLogger_TripTrap.mq5`](../../MQL5/Experts/TradeLogger/TradeLogger_TripTrap.mq5) | Cùng mã với bản Universal, **cài sẵn** cho GoldVault Trip Trap (xem [`TRIP_TRAP.md`](TRIP_TRAP.md)) |
| [`../../research/phan_tich_ea/phan_tich_chung.py`](../../research/phan_tich_ea/phan_tich_chung.py) | Đọc log, in báo cáo: lệnh đầu, lưới/DCA, đóng rổ, trailing ảo, lệnh chờ, **dò khung thời gian và dò chỉ báo** (dùng khi không có file .set) |
| [`../../MQL5/Experts/TradeLogger/TradeLogger.mq5`](../../MQL5/Experts/TradeLogger/TradeLogger.mq5) | Bản 2.00 riêng cho BE Nha Trang (giữ nguyên, xem [`../be_nha_trang/THU_LOG.md`](../be_nha_trang/THU_LOG.md)) |

Logger **không đặt lệnh**. Nó chỉ đọc lịch sử và trạng thái tài khoản, nên chạy được cả khi đăng nhập bằng mật khẩu
investor. Cả hai file `.mq5` **chưa compile** (môi trường của tôi không có MetaTrader). Nếu MetaEditor báo lỗi, gửi
nguyên văn lỗi để tôi sửa.

## Cài đặt Universal cho một EA mới

| Input | Đặt thế nào |
|---|---|
| `InpFilePrefix` | **Mỗi EA một tên riêng**, nếu không các logger sẽ ghi đè file của nhau |
| `InpMagicFilter` | Magic của EA. Chưa biết thì để `0`, chạy một lúc, xem cột `magic` trong `<prefix>_deals.csv`, rồi đặt lại |
| `InpSymbolFilter` | Symbol EA chạy (trống = tất cả) |
| `InpEntryTF` | **Khung chart gắn EA** (ví dụ H1). Dùng để đo "giây kể từ mở nến" và lấy nến đã đóng |
| `InpIndicators` | Chỉ báo EA dùng, lấy từ file .set / mô tả EA (cú pháp bên dưới) |
| `InpDistUnit` | `Point` nếu file .set của EA ghi khoảng cách bằng point; `Pip` nếu ghi bằng pip |
| `InpFeatureTF` / `InpBiasTF` | Khung cho bộ đặc trưng chung (ATR/RSI/EMA20-50-200/BB/MACD/Stoch/PDH-PDL) |

Nhớ tăng Tools → Options → Charts → **Max bars in chart** để đủ lịch sử nến.

### Cú pháp `InpIndicators`

`LOẠI:KHUNG:tham số`, nhiều chỉ báo cách nhau dấu phẩy, tối đa 16. Thiếu tham số thì dùng giá trị mặc định.

| Loại | Tham số (mặc định) | Cột ghi ra |
|---|---|---|
| `EMA`, `SMA` | chu kỳ (20) | giá trị, `_dist` = (giá − MA) / đơn vị |
| `RSI` | chu kỳ (14) | giá trị |
| `ATR` | chu kỳ (14) | giá trị, `_u` = ATR đổi ra đơn vị (so trực tiếp với bước lưới) |
| `ADX` | chu kỳ (14) | ADX, `_pdi`, `_mdi` |
| `CCI` | chu kỳ (14) | giá trị |
| `BB` | chu kỳ, độ lệch (20, 2) | `_up`, `_mid`, `_lo`, `_pctb` (vị trí giá trong dải) |
| `MACD` | nhanh, chậm, tín hiệu (12, 26, 9) | `_main`, `_sig` |
| `STOCH` | K, D, slowing (5, 3, 3) | `_main`, `_sig` |

Khung viết như MT5: `M1 M5 M15 M30 H1 H4 D1 W1`… (có cả M2, M6, M12, H2, H3…).
Ví dụ: `EMA:H1:34,EMA:H1:89,RSI:M15:14,ATR:H1:14,BB:H1:20:2,MACD:H4:12:26:9`.

Mọi giá trị chỉ báo lấy trên **nến đã đóng** ngay trước lúc khớp lệnh, nên tính lại từ lịch sử cũng ra đúng giá trị EA
đã thấy lúc đó. Nếu EA dùng chỉ báo tuỳ chỉnh (file .ex5 riêng), logger không đọc được, cần bổ sung riêng.

## File xuất ra (`MQL5/Files/`)

| File | Nội dung |
|---|---|
| `<prefix>_deals.csv` | Mỗi deal một dòng, gồm các nhóm cột: thông tin deal · đặc trưng chung `f_*` · rổ lệnh `k_*` · nến khung EA `c_*` · chỉ báo `i_*` · giá tức thời `live_*` |
| `<prefix>_events_v3.csv` | Mỗi lần đặt, sửa, khớp hoặc huỷ lệnh chờ, và mỗi lần đổi SL/TP của vị thế. Có khoảng cách tới giá (`dist`); khi dời lệnh chờ có thêm giá cũ và khoảng cách cũ (`prev_price`, `prev_dist`) |
| `<prefix>_orders.csv` | Lịch sử order: market hay lệnh chờ, lý do |
| `<prefix>_ctxbars_<symbol>_<TF>.csv` | Mỗi nến khung EA kèm các cột `c_*` và `i_*`, để so "lúc EA vào lệnh" với "lúc không vào" |
| `<prefix>_bars_<symbol>_<TF>.csv` | Nến kèm đặc trưng chung |
| `<prefix>_symbols.csv` | Thông số symbol, đơn vị, chuỗi chỉ báo đã dùng |

Các cột `k_*` quan trọng nhất (khoảng cách đều theo đơn vị `k_unit`):

| Cột | Ý nghĩa |
|---|---|
| `k_basket`, `k_idx` | Rổ số mấy, lệnh thứ mấy trong rổ. Rổ = các vị thế cùng symbol, magic, chiều đang mở cùng lúc |
| `k_dist_last` | Lệnh vào cách lệnh trước bao nhiêu (dương = giá tốt hơn) → **bước lưới/DCA** |
| `k_lot_ratio` | Lot lệnh này / lot lệnh trước → **hệ số nhân** |
| `k_dist_avg` | Lúc đóng: giá đóng cách giá trung bình rổ bao nhiêu → **TP rổ** |
| `k_peak_after_last` | Có lời tối đa (so giá trung bình) từ lệnh vào cuối đến lúc đóng, xấp xỉ theo nến M1 → **trailing ảo** |
| `k_basket_age_sec` | Rổ đã mở bao lâu |

## Phân tích

```
python3 research/phan_tich_ea/phan_tich_chung.py <prefix>_deals.csv --events <prefix>_events_v3.csv --magic <magic> --out bao_cao.md
```

Tôi đã kiểm thử bằng log giả lập của một EA kiểu Trip Trap. Tham số giả lập: lệnh chờ 100, dời lệnh ở 200, lưới 300,
lot × 1.6, trailing bắt đầu 100 bước 50. Báo cáo tìm lại được:
- khoảng cách đặt lệnh chờ 100.0;
- ngưỡng dời lệnh ~200;
- bước lưới ~300;
- hệ số lot 1.585;
- trailing: có lời tối đa − giá đóng ≈ 50, có lời tối đa nhỏ nhất ≈ 104 (tức ≥ 100).

Phần MQL5 chưa được kiểm thử.

## Chỉ có tài khoản Passview (không có file .set)

Logger đọc lệnh trên server, nên đăng nhập bằng mật khẩu investor vẫn ghi đủ. Những gì không thấy được là input, khung
chart và chỉ báo của EA. Hai mục cuối của báo cáo tự dò các thông tin này:

1. Chạy logger với `InpMagicFilter = 0`, `InpDistUnit = Point`, `InpExportCtxBars = true`, `InpEntryTF = H1`, và một
   bộ chỉ báo quét rộng (đủ 16, mức tối đa):

   ```
   EMA:M15:20,EMA:M15:50,EMA:H1:20,EMA:H1:50,EMA:H1:200,EMA:H4:50,RSI:M15:14,RSI:H1:14,RSI:H4:14,ATR:H1:14,ATR:D1:14,ADX:H1:14,BB:H1:20:2,MACD:H1:12:26:9,STOCH:H1:5:3:3,CCI:H1:14
   ```

2. Sau vài ngày, chạy báo cáo:

   ```
   python3 research/phan_tich_ea/phan_tich_chung.py x_deals.csv --events x_events_v3.csv --ctxbars x_ctxbars_XAUUSD_H1.csv --out bao_cao.md
   ```

3. **Mục 6 — dò khung thời gian:** với từng khung M1…D1, đếm tỉ lệ lệnh rơi vào 10 giây đầu nến, rồi so với tỉ lệ nếu
   ngẫu nhiên. Khung lớn nhất có ≥ 70% lệnh rơi đúng lúc mở nến chính là khung EA ra quyết định. Nếu khung đó khác H1,
   đặt lại `InpEntryTF` và **đổi khung trong `InpIndicators`** cho khớp, rồi thu log lại. Nếu không khung nào khớp, EA
   chạy theo tick hoặc vào bằng lệnh chờ. Khi có file events, script cũng dò thời điểm đặt và dời lệnh chờ.
4. **Mục 7 — dò chỉ báo:** với từng cột chỉ báo `i_*`, và các cột hiệu số tự tạo `d_*` (EMA nhanh − chậm, +DI − −DI,
   MACD/Stoch main − signal), so phân bố lúc vào lệnh đầu với phân bố trên mọi nến (file ctxbars). Script tính thống kê
   KS, xếp hạng các cột, tách riêng BUY và SELL, rồi gợi ý điều kiện như `≤ 30`, `≥ 70`, `> 0 ở 100% lệnh`.
5. Bỏ những chỉ báo có KS thấp, thay bằng chỉ báo hoặc khung khác (giữ trong giới hạn 16), rồi thu log tiếp cho đến
   khi các cột đứng đầu ổn định.

Kiểm thử bằng một EA ẩn có quy tắc đã biết. Quy tắc: vào lệnh lúc mở nến H1; BUY khi RSI H1 < 30 và EMA20 > EMA50,
SELL khi RSI H1 > 70 và EMA20 < EMA50. Dữ liệu: 30 000 nến H1, 209 lệnh đầu. Báo cáo tìm ra:
- khung **H1**;
- BUY: `RSI ≤ 30`, `EMA20 − EMA50 > 0 ở 100% lệnh`;
- SELL: `RSI ≥ 70.07`, `EMA20 − EMA50 < 0 ở 100% lệnh`;
- ADX và Stoch (không liên quan) đều có KS < 0.15.

Giới hạn của việc dò:
- Chỉ tìm được chỉ báo **có trong danh sách đã ghi**. Chỉ báo tự viết (.ex5 riêng) thì không dò được.
- Cần ≥ 30 lệnh đầu mỗi chiều. Với ít lệnh, KS cao có thể chỉ là ngẫu nhiên.
- Điều kiện kết hợp, ví dụ "RSI < 30 **hoặc** giá chạm BB dưới", sẽ hiện ra yếu hơn điều kiện đơn.
- Điều kiện không sinh ra lệnh thì không thấy được trực tiếp, ví dụ lọc tin (chỉ lộ qua khoảng trống không có lệnh) và
  cắt lỗ theo equity chưa từng kích hoạt.

## Giới hạn

- Logger không chạy song song với EA khác trong Strategy Tester (Tester chỉ chạy 1 EA). Cần log từ tài khoản
  demo/thật đang chạy EA.
- `live_*` chỉ có khi logger đang chạy đúng lúc deal xảy ra. Khi dời lệnh chờ, `prev_dist` và `dist` cũng đo bằng giá
  lúc logger nhận được sự kiện, nên logger phải đang chạy.
- `k_peak_after_last` xấp xỉ theo nến M1 và giá bid (lệnh SELL chưa trừ spread), nên có thể lệch vài point.
- Hệ số lot bị nhiễu khi lot nhỏ, vì làm tròn 0.01. Báo cáo có cột "hệ số ước lượng từ lot đầu" để giảm nhiễu.
