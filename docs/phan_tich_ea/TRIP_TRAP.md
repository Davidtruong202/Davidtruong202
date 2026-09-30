# GoldVault Trip Trap — thu log để sao chép logic

File .set: [`../../MQL5/Presets/GoldVault_TripTrap.set`](../../MQL5/Presets/GoldVault_TripTrap.set) (giữ nguyên bản gốc).
EA gắn chart **H1**.

Logger: [`TradeLogger_TripTrap.mq5`](../../MQL5/Experts/TradeLogger/TradeLogger_TripTrap.mq5). Đây là bản Universal 3.00
với các input cài sẵn:

| Input | Giá trị cài sẵn | Lý do |
|---|---|---|
| `InpFilePrefix` | `triptrap` | Không ghi đè log của EA khác |
| `InpMagicFilter` | `202601` | `InpMagicNumber` trong .set |
| `InpEntryTF` | H1 | EA gắn chart H1 |
| `InpIndicators` | `ATR:H1:14,RSI:H1:14,ADX:H1:14,EMA:H1:50,EMA:H1:200` | ATR(14)×1.5 cho GridMode ATR; RSI(14) 70/30 và ADX(14) 25 là 2 bộ lọc của EA; EMA50/200 để xem bối cảnh xu hướng |
| `InpDistUnit` | Point | File .set ghi khoảng cách bằng point |

Chỉ cần đặt thêm `InpSymbolFilter` = đúng tên symbol vàng của sàn (ví dụ `XAUUSD`, `XAUUSDm`, `XAUUSDc`).

## Tham số trong .set và cách log kiểm chứng

| Tham số (.set) | Giá trị | Đoán nghĩa | Mục báo cáo kiểm chứng |
|---|---|---|---|
| `InpTradeMode` | 2 | Có lẽ 0 = chỉ Buy, 1 = chỉ Sell, 2 = cả hai | §0: tỉ lệ BUY/SELL; rổ BUY chạy song song rổ SELL không |
| `InpMaxSpreadPoints` | 300 | Không vào khi spread > 300 point | §1: spread lúc vào; §5: spread lúc đặt lệnh chờ |
| `InpPendingDistancePoints` | 100 | Đặt BUY STOP / SELL STOP cách giá 100 point | §5: "Đặt mới" và "lệnh mới cách giá" |
| `InpRefreshPending` / `InpRefreshThresholdPoints` | true / 200 | Giá chạy xa khỏi lệnh chờ quá 200 point thì dời lệnh lại | §5: "lệnh cũ cách giá" khi MODIFY. Min là ngưỡng; cần xem ngưỡng là 200 hay 100 + 200 |
| `InpGridMode` | 0 | 0 = bước cố định, 1 = theo ATR | §2: khoảng cách ổn định thì là bước cố định; cột Bước/ATR ổn định thì là bước theo ATR |
| `InpGridStepPoints` | 300 | Bước lưới 300 point | §2: khoảng cách min mỗi bậc |
| `InpATRPeriod` / `InpATRMultiplier` | 14 / 1.5 | Bước = ATR(14) × 1.5 khi GridMode = 1 | §2: cột Bước/ATR ≈ 1.5 |
| `InpStartLot` / `InpLotMultiplier` | 0.01 / 1.6 | Lot lớp n = 0.01 × 1.6^(n−1) | §2: hệ số ước lượng từ lot đầu |
| `InpMaxLot` / `InpMaxLayer` | 100 / 100 | Gần như không giới hạn | §0: độ sâu rổ lớn nhất |
| `InpUseGhostTrail` / Start / Step | true / 100 / 50 | Trailing **ảo** (không đặt SL lên server): lời ≥ 100 point thì bắt đầu, giá lùi 50 point thì đóng | §3: lý do đóng = EXPERT; "có lời tối đa − giá đóng" ≈ 50; "có lời tối đa" nhỏ nhất ≥ 100 |
| `InpUseRSI` / `InpUseADX` | false | Tắt | Nếu bật: §1 so cột `i_RSI_H1_14`, `i_ADX_H1_14` với ngưỡng |
| `InpUseCutLoss`, `InpUseMaxDD`, `InpUseDailyTarget` | false | Tắt | §4: đóng khi rổ còn lệnh sẽ không xuất hiện |
| `InpSession1-3Enable` | false | Không giới hạn giờ | §1: giờ lệnh đầu phải rải khắp 24h |
| `InpUseNewsFilter` | true, ±15 phút, chỉ USD high impact | Không vào lệnh quanh tin | §1: các khoảng trống quanh giờ tin; dùng file `ctxbars` để so với lịch tin |

**Chú ý đơn vị point**: vàng 2 chữ số thập phân (3300.25) thì 1 point = 0.01, nên 100 point = 1 USD. Vàng 3 chữ số
(3300.253) thì 1 point = 0.001, nên 100 point chỉ = 0.1 USD. Xem cột `unit` trong `triptrap_symbols.csv` để biết sàn
của bạn thuộc loại nào trước khi so với file .set.

## Các bước

1. Compile `TradeLogger_TripTrap.mq5`, gắn lên một chart **khác** chart đang chạy Trip Trap (cùng terminal, hoặc
   terminal khác đăng nhập cùng tài khoản bằng mật khẩu investor). Đặt `InpSymbolFilter`.
2. Để logger chạy **liên tục** cùng EA: việc dời lệnh chờ và trailing ảo chỉ đo được khi logger đang chạy.
   1–2 tuần là có đủ vài chục rổ.
3. Gửi lại `triptrap_deals.csv`, `triptrap_events_v3.csv`, `triptrap_symbols.csv` (và `triptrap_ctxbars_*` nếu được).
4. Chạy phân tích:

   ```
   python3 research/phan_tich_ea/phan_tich_chung.py triptrap_deals.csv --events triptrap_events_v3.csv --magic 202601 --out bao_cao_triptrap.md
   ```

Sau khi có báo cáo, có thể viết EA sao chép logic Trip Trap giống cách đã làm với BE Nha Trang, nhưng lần này dựa trên
số đo thật thay vì đoán từ tên tham số.
