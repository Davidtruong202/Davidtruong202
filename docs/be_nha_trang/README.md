# BE Nha Trang DCA — bản viết lại từ file .set

| File | Nội dung |
|---|---|
| [`../../MQL5/Experts/BE_NhaTrang_DCA.mq5`](../../MQL5/Experts/BE_NhaTrang_DCA.mq5) | EA viết lại (chưa compile, chưa backtest) |
| [`../../MQL5/Presets/BE_NhaTrang_DCA_lot0.02_30-40k_cent.set`](../../MQL5/Presets/BE_NhaTrang_DCA_lot0.02_30-40k_cent.set) | File .set gốc bạn gửi (giữ nguyên, UTF-16) |
| [`THU_LOG.md`](THU_LOG.md) | Thu log bot gốc bằng TradeLogger 2.00 + script phân tích để chỉnh các giả định |

> **Quan trọng:** không có mã nguồn của "BE Nha Trang v1.0.4". Logic dưới đây được **suy ra từ tên và giá trị
> tham số** trong file .set. Phần nào rõ nghĩa thì bám sát; phần nào mơ hồ thì ghi rõ là **giả định**. Muốn giống
> bot gốc 100% thì cần chạy song song 2 EA (demo) và so từng lệnh, rồi chỉnh các giả định.

Tên input giữ **đúng 100%** như bản gốc, nên file .set gốc nạp thẳng được (Strategy Tester → Inputs → Load).
Các tham số khung thời gian là `ENUM_TIMEFRAMES`, nên giá trị số trong .set được hiểu đúng: `1`=M1, `6`=M6,
`10`=M10, `12`=M12. Lưu ý: tên nhóm trong bot gốc ghi "EMA M2 / M1 / M15" nhưng file .set của bạn thực tế đặt
EMA chính = **M6**, lọc "M1" = **M12**, lọc "M15" = **M6**.

## Luồng hoạt động

Rổ **Buy** và rổ **Sell** chạy độc lập, song song (cần tài khoản **hedging**). Mỗi tick, với từng rổ:

1. **Có lệnh** → kiểm tra thoát cả rổ (TP / SL / trailing) → tỉa một phần → tỉa lệnh → DCA.
2. **Không có lệnh** → nếu qua hết bộ lọc thì mở lệnh đầu.

### Lệnh đầu (chỉ khi rổ trống)

Cần `InpAllowBuy/Sell`, trong giờ giao dịch (nếu bật), tối đa 1 lệnh đầu mỗi nến `InpEMATF`
(`InpOneEntryPerBar`), và qua mọi bộ lọc đang bật (đọc trên **nến đã đóng**):

| Bộ lọc | Điều kiện Buy (Sell ngược lại) | Mức chắc chắn |
|---|---|---|
| EMA chính (`InpEMATF`, 34/89) | EMA34 > EMA89; **A%**: khoảng cách EMA34–EMA89 ≥ 0.1% giá; **B%**: giá cách EMA34 ≤ 0.35% giá | Chiều EMA: chắc. **A%/B%: giả định** |
| EMA phụ "M1" (`InpM1TF`, 10/20) | EMA10 > EMA20 | Chắc |
| EMA phụ "M15" (`InpM15TF`, 34/89) | EMA34 > EMA89 | Chắc |
| CCI đảo chiều (tắt) | CCI vừa cắt lên khỏi −95 | Giả định |
| Price Action (tắt) | Mode 0: nến thân ≥ 85% biên độ cùng chiều; 1: nhấn chìm; 2: một trong hai | Giả định |

Lot lệnh đầu = `InpInitialLot`, nhân `InpLotReductionFactor` nếu đang trong khung giảm lot.

### DCA

- Chỉ xét **1 lần mỗi nến `InpDCATF`** (M1), dùng **giá đóng cửa nến vừa đóng**: Buy khi
  `close ≤ giá lệnh mới nhất − khoảng cách` (và giá hiện tại vẫn không cao hơn lệnh mới nhất).
- **Khoảng cách** và **hệ số nhân** lấy theo bậc: dùng bậc có *trigger lớn nhất ≤ số lệnh đang có* (các trigger
  trong .set không theo thứ tự nên EA tự sắp xếp).
- `InpDCAMode=0`: lot = lot trước × hệ số. `=1`: lot = lot trước + `InpAddLot`.
- Lot được tính từ lot gốc **chưa làm tròn** rồi mới làm tròn theo bước lot, để lot 0.006 (0.02 × 0.3) × 1.7 không
  bị kẹt mãi ở 0.01. Tối đa `InpMaxLot`, tối đa `InpMaxPositionsBuy/Sell` lệnh.

Chuỗi theo file .set của bạn (XAU, 1 pip = 0.1 giá):

| Lệnh | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15–18 | 19–20 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Lot (giờ thường) | 0.02 | 0.03 | 0.06 | 0.10 | 0.17 | 0.28 | 0.48 | 0.82 | 0.82 | 0.82 | 0.82 | 1.07 | 1.39 | 1.80 | 2.30 | 2.30 |
| Lot (giờ giảm ×0.3) | 0.01 | 0.01 | 0.02 | 0.03 | 0.05 | 0.09 | 0.14 | 0.25 | 0.25 | 0.25 | 0.25 | 0.32 | 0.42 | 0.54 | 0.70–1.54 | 2.01–2.30 |
| Khoảng cách tới lệnh trước (pip) | – | 150 | 150 | 150 | 150 | 150 | 150 | 150 | 250 | 350 | 350 | 350 | 200 | 200 | 200 | 300 |
| Cộng dồn (pip) | 0 | 150 | 300 | 450 | 600 | 750 | 900 | 1050 | 1300 | 1650 | 2000 | 2350 | 2550 | 2750 | 2950–3550 | 3850–4150 |

→ Rổ Buy đủ 20 lệnh khi giá đi ngược khoảng **415 USD** (4150 pip), tổng khoảng **22.5 lot** ở giờ thường. EA in
bảng này ra tab Experts khi khởi động để bạn đối chiếu với bot gốc.

### Thoát lệnh

- **TP cả rổ**: giá trung bình (theo khối lượng) ± `InpTakeProfit` pip (150 pip = 15 USD). Chỉ có 1 lệnh và
  `InpFirstOrderTakeProfit > 0` thì dùng TP riêng đó. TP được đặt lên server cho mọi lệnh **và** kiểm tra ảo mỗi tick.
- **SL cả rổ** (`InpStopLoss`, đang = 0 tức tắt): giá trung bình ∓ SL pip.
- **Trailing cả rổ** (tắt): khi lãi ≥ 150 pip so với giá trung bình, SL = giá − 110 pip, chỉ dời khi cải thiện ≥ 50 pip.

### Tỉa lệnh (cả hai đang tắt trong .set — **toàn bộ là giả định**)

- **Tỉa cùng chuỗi**: khi rổ ≥ `InpPruneTrigger1` (12) lệnh, lấy `InpPruneOldestCount` (2) lệnh cũ nhất đang lỗ;
  gom lãi từ các lệnh mới nhất (mỗi lệnh lãi ≥ `InpPruneTakeProfitPips`, tối đa `InpPruneMaxNewest`, 0 = không giới hạn)
  cho đến khi *lãi ròng ≥ max(`InpPruneProfitMoney`, `InpPruneProfitPercent`% × lỗ lệnh cũ)* thì đóng cả hai nhóm.
  Từ `InpPruneTrigger2` (15) lệnh chỉ cần lãi ròng ≥ `InpPruneProfitMoney`. `InpPruneMultiplier` được dùng làm hệ số
  DCA khi rổ đã ≥ `InpPruneTrigger1`. `InpPruneIgnoreMagic` = tính cả lệnh khác magic cùng symbol.
- **Tỉa một phần lệnh đầu**: khi rổ ≥ `InpPartialPruneTrigger` lệnh **hoặc** lãi/lỗ rổ ≤ `InpPartialExitLossPercent`%
  số dư: đóng `InpPartialOldLotPercent`% lot của lệnh cũ nhất, bù bằng lãi các lệnh mới nhất sao cho lãi ròng
  ≥ max(`InpPartialProfitMoney`, `InpPartialProfitPercent`% × phần lỗ).

Tiền (`...ProfitMoney`) tính theo **đơn vị tiền tài khoản** (tài khoản cent = cent).

### Giờ

- Giờ máy chủ broker, khung **tính cả giờ kết thúc**, hỗ trợ qua nửa đêm: giảm lot 11 → 5 nghĩa là từ 11:00 tới
  05:59 hôm sau (giả định — nếu bot gốc không tính giờ 5 thì sửa `InHourWindow`).
- Ngoài giờ giao dịch: không mở lệnh đầu; DCA vẫn chạy nếu `InpAllowDCAOutsideHours=true`.
- `InpBotEnabled=false`: không mở lệnh mới/DCA/tỉa, nhưng vẫn quản lý TP/SL/trailing lệnh đang có.

## Tham số thêm (không có trong bản gốc)

- `InpPipSize` (mặc định 0 = tự động): XAU/GOLD = 0.1; symbol 3/5 chữ số = 10 point; còn lại = 1 point.
  Nếu chạy BTC hoặc symbol khác, hãy đặt tay cho đúng cách bot gốc tính pip.

## Cài đặt & kiểm thử

1. Copy `BE_NhaTrang_DCA.mq5` vào `MQL5/Experts/`, compile trong MetaEditor (F7). Môi trường này không có
   MetaTrader nên **chưa compile được** — nếu báo lỗi, gửi lại nội dung lỗi để sửa.
2. Copy file .set vào `MQL5/Presets/`, nạp trong tab Inputs.
3. Chart XAUUSD (tài khoản hedging). Khung chart không ảnh hưởng — mọi khung đều lấy từ input.
4. Backtest "Every tick based on real ticks". Khi kết thúc, tab Experts in dòng `[BENT Summary]` (số lệnh đầu,
   số lần DCA, số lần đóng rổ, số lần tỉa) để thấy nhanh EA có vào lệnh không.
5. **So với bot gốc**: chạy cả hai trên cùng dữ liệu/khoảng thời gian, so thời điểm lệnh đầu, lot từng lệnh DCA,
   giá đóng rổ. Chênh ở lệnh đầu → xem lại giả định A%/B%; chênh ở DCA → xem lại "nến đã đóng" và biên bậc.

## Cảnh báo rủi ro

Đây là chiến lược DCA/martingale không có SL (`InpStopLoss=0`): lợi nhuận đều đặn nhưng một xu hướng một chiều
dài hơn ~415 USD có thể cháy tài khoản. EA không đảm bảo lợi nhuận; chỉ chạy thật sau khi đã backtest và chạy demo.
