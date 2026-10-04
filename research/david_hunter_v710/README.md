# David Hunter EA V710 – tìm bộ SET cho tài khoản 20.000

> **Đây là mô phỏng bằng bộ giả lập tự viết, KHÔNG phải backtest MT5.** Các SET dưới đây là **cấu hình đề xuất**,
> chưa được kiểm chứng trong MetaTrader 5 Strategy Tester. Không cam kết lợi nhuận.

EA: `CHINH_CHU/David_Hunter_EA_V710.mq5` (version 710.09) trong gói `David_Hunter_CHINH_CHU_V710_702_CHO_CLAUDE.zip`.
Không sửa mã EA. Chỉ dùng 34 input có trong mã nguồn V710 (không áp dụng cho bản 7.02).

## 1. Kết luận nhanh

| Bộ SET (file trong `SET/`) | Lãi 9 tháng | Max DD (từ đỉnh vốn) | PF | Tháng lãi | Spread +100 | Chart M5 | Nhiễu khác | Tick thật 02–12/01 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| **DH_V710_20k_CanBang.set** (khuyến nghị) | +17.988 | 4.191 (11,6%) | 1,16 | 8/9 | +14.367 | +20.939 | +15.637 | +380 |
| DH_V710_20k_AnToan.set (như trên, lot 0,01) | +7.592 | 2.486 (10,5%) | 1,14 | 7/9 | +5.627 | +8.522 | +7.010 | +111 |
| DH_V710_20k_DuPhong_DDthap.set | +18.794 | 3.257 | 1,19 | 8/9 | +12.320 | +16.114 | +14.122 | +110 |
| set710taikhoan20k.set (bộ bạn gửi) | +1.697 | **26.343** | 1,00 | 4/9 | −8.082 | +19.334 | +14.928 | +2.465 |
| Mặc định V710 (lot 0,01) | −1.826 | 2.449 | 0,94 | 4/9 | | | | −191 |

Vốn đầu 20.000 đơn vị tiền tài khoản, XAUUSDm Exness 01/01 → 27/09/2026, tick dựng có nhiễu (mục 3).
Lãi theo tháng của các bộ chốt: `ket_qua/chot_9thang.csv`; lãi lỗ từng ngày: `ket_qua/nhat_ky/*_ngay.csv`.

**Đọc kỹ trước khi dùng:**

1. **Bộ 20k bạn gửi lãi lớn ở T1–T2 (+21,8k) rồi lỗ nặng T6–T9 (−23,2k).** Chạy liên tục 9 tháng, vốn lên ~44k rồi rơi
   về ~18k (DD 26k). Nguyên nhân: không giới hạn tầng/lot (lên tới 15 tầng, 0,97 lot), không có SL cứng, cắt lỗ rổ hay
   giới hạn lỗ ngày.
2. **Chiến lược V710 nhạy với giai đoạn thị trường.** Trong 1.500 bộ ngẫu nhiên, 1.015 bộ lãi T1–T5 nhưng chỉ 77 bộ
   lãi T6–T9. Tương quan xếp hạng giữa hai giai đoạn là −0,04. Chọn set "tốt nhất" theo T1–T5 thì 79/81 bộ lỗ ở T6–T9.
   Nếu lãi/lỗ hai giai đoạn độc lập, kỳ vọng ~52 bộ lãi cả hai do may mắn; thực tế 65 bộ, nghĩa là **không có bằng
   chứng một bộ chọn theo một giai đoạn sẽ lãi ở giai đoạn sau**.
3. Bộ khuyến nghị được chọn bằng **cả 9 tháng** (lãi cả ba quý, rồi tinh chỉnh). Vì vậy kết quả 9 tháng là
   **trong mẫu**. Phần kiểm chứng độc lập hơn chỉ gồm: biến thể lân cận (100% biến thể của họ r11_01238 và r11_00920
   vẫn lãi), các kịch bản sai lệch (spread, khung chart, nhiễu tick), và tick thật 02–12/01 (7 ngày, quá ngắn để
   kết luận). **Bắt buộc backtest MT5 và chạy demo trước khi dùng tiền thật.**
4. DD 4.191 trên vốn 20.000 là ~21% vốn ban đầu. Muốn rủi ro thấp hơn, dùng bản **AnToan** (lot 0,01).

## 2. Bộ khuyến nghị khác bộ 20k của bạn ở đâu

| Input | set710taikhoan20k | CanBang | Ý nghĩa |
|---|---|---|---|
| EA_StartTime / EA_StopTime | 03:00 / 15:00 | **09:00 / 18:00** | Giờ server (Exness GMT+0) = phiên London + New York |
| Hand_FirstDist | 70 | 160 | Lệnh đầu cách giá 1,60 thay vì 0,70 (đã nhân 10 vì giá 3 số lẻ) |
| Hand_MinDist1 / AddGap1 | 100 / 110 | 90 / 200 | Thêm tầng thưa hơn (giá phải đi ngược ≥ ~2,9) |
| Hand_MinDist2 / AddGap2 | 140 / 160 | 240 / 320 | Tầng sau ngưỡng còn thưa hơn |
| Hand_OrderThresh | 6 | 5 | |
| Hand_AddLotMult | 1,15 | 1,20 | |
| Hand_SideTP / SideSL | 250 / 1000 | 525 / 2200 | |
| Hand_AllStopLoss / PauseLoss | 150 / 1500 | 450 / 1400 | |
| NetClosePL / InpPeakRetracePct | 250 / 100 | 375 / 50 | |
| InpBasketMaxLoss | 0 (tắt) | **1300** | Cắt cả rổ khi lỗ nổi ≥ 1.300 |
| InpHardSLATR | 0 (tắt) | **6,0** | SL cứng 6 × ATR M15 cho từng lệnh |
| InpMaxLayers | 0 (không giới hạn) | **7** | |
| InpSpikeEnable / USD / PauseMin / RemovePend | false / 3 / 30 / true | **true / 6 / 20 / false** | |
| MaxLot | 10 | **0,2** | |

Các input còn lại giữ như bộ 20k (InpMaxTotalLots=100, InpDailyLossLimit=0, DailyProfitTarget=0,
InpFlattenOnClose=true, InpGridAutoScale=true, InpMagic=71020001). Hai họ set tốt nhất (r11_01238 và r11_00920) tìm
độc lập nhưng cùng hội tụ về **giờ 09:00/10:00–18:00, SL cứng 6×ATR, lọc biến động 6 USD, tối đa 6–7 tầng**.

## 3. Cách làm

1. **Đọc hết mã V710** và chép lại đúng thứ tự gọi hàm trong `OnTick` → `ManageTrailHedge` vào bộ giả lập C++
   `dh710sim.cpp`: lưới lệnh chờ Buy Stop/Sell Stop (`PlaceGridBuy/Sell`, `ManagePendingStops`), lot
   `GetGridLot`, chốt lãi ròng theo điểm xu hướng (`ManageHedge`, `UpdateTrend`/`ScoreOneTF`), SL cứng ATR M15,
   cắt lỗ rổ, chốt lời/cắt lỗ một hướng, trailing fractal theo đáy/đỉnh nến trước, TP động khi ≥5 lệnh, giới hạn
   ngày, lọc biến động nến M1, đóng ngoài giờ. Giữ cả chi tiết dùng `g_pos` cũ (chưa cập nhật) giữa các bước như EA.
   Cơ chế tỉa lệnh đầu/cuối có cổng 1.000 lệnh nên không bao giờ chạy – bỏ qua.
2. **Dữ liệu** (repo EA-PRO): nến M1 XAUUSDm Exness 01/01–27/09/2026 (260.662 nến, spread theo từng nến) và tick thật
   02–12/01/2026 (2,73 triệu tick). `prep.py` tính ATR M1/M15 và điểm xu hướng M1/M5/M15 từ nến đã đóng.
3. **Tick dựng**: thử hai cách trên 300 bộ ngẫu nhiên, so với tick thật 02–12/01:
   - đường thẳng O→L→H→C: tương quan xếp hạng lãi 0,65, lãi trung vị lệch cao gấp 4 lần;
   - **cầu Brown có nhiễu trong biên nến** (số tick = tick_volume, biên độ 0,45): tương quan 0,75, lãi trung vị 115
     so với 129 của tick thật, tương quan max DD 0,94. Dùng cách này cho mọi lượt chạy 9 tháng (56 triệu tick).
4. **Tìm kiếm**: 1.500 bộ ngẫu nhiên (lot 0,02) trên T1–T5 → kiểm tra T6–T9 → lọc bộ lãi đủ 3 quý (58 bộ) → kiểm tra
   sức chịu đựng 14 bộ → tinh chỉnh 240 biến thể quanh 6 bộ → kiểm tra sức chịu đựng các bộ chốt.

## 4. Giả định tài khoản và symbol

- **Đơn vị tiền**: mọi số tiền trong input (SideTP, SideSL, AllStopLoss, PauseLoss, NetClosePL, BasketMaxLoss,
  DailyLossLimit, DailyProfitTarget) là tiền tài khoản. Với Exness, 0,01 lot XAUUSD đi 1 USD giá = 1 USD (tài khoản
  USD) và 0,01 lot XAUUSDc đi 1 USD giá = 1 USC (tài khoản cent). Số học giống nhau nên **cùng một SET dùng được cho
  20.000 USD hoặc 20.000 USC**, nhưng 20.000 USC chỉ là 200 USD – rủi ro tiền thật khác nhau 100 lần.
- **Symbol**: 3 chữ số thập phân, point 0,001, lot min/step 0,01 → EA tự nhân 10 các khoảng cách lưới
  (`InpGridAutoScale=true`). Sàn 2 chữ số thì khoảng cách bị hiểu khác – không dùng SET này.
- **Spread**: theo nến M1 của XAUUSDm (thường 160 point = 0,16). Tài khoản cent đo được ~260 point → kịch bản
  "spread +100" (lãi CanBang giảm từ 18,0k xuống 14,4k). Commission = 0, swap = 0 vì EA đóng hết lúc 18:00.
- **Giờ server**: GMT+0 (Exness). Sàn khác giờ thì phải dời EA_StartTime/EA_StopTime tương ứng.
- **Đòn bẩy/margin**: không mô phỏng (Exness gần như không giới hạn; khối lượng tối đa ~0,5 lot).
- **Khung chart**: trailing của EA dùng nến của khung đang gắn (`PERIOD_CURRENT`). Giả lập mặc định **M1**; kịch bản
  M5 vẫn lãi cho các bộ chốt. Nên gắn EA lên chart **XAUUSD M1**.

## 5. Sai khác đã biết giữa giả lập và MT5

- ATR, điểm xu hướng tính trên nến **đã đóng**; EA dùng cả nến đang chạy.
- Tick dựng chỉ hiệu chỉnh trên 7 ngày tick thật; thứ tự giá trong nến là giả định.
- Lệnh chờ/SL/TP khớp ở giá tick hiện tại, không trượt giá thêm, không requote, không độ trễ.
- `PendingStopsHelper` theo chế độ Strategy Tester (`--live 1` để mô phỏng tài khoản thật).

## 6. Hướng dẫn backtest MT5 để kiểm chứng

1. MetaEditor mở `BACKTEST/David_Hunter_EA_V710_BACKTEST.mq5`, nhấn F7 (chưa ai biên dịch thử bản này).
2. Strategy Tester: Expert = V710_BACKTEST, Symbol = XAUUSDm (hoặc XAUUSDc), **Period = M1**,
   Model = **Every tick based on real ticks**, Deposit = **20000**, Leverage theo tài khoản thật,
   Dates 2026.01.01 → 2026.09.27 (rồi chạy thêm từng quý).
3. Inputs → Load → chọn file `.set`. Kiểm tra các dòng giờ, lot, MaxLot đã nạp đúng.
4. So các số sau với bảng mục 1: **Total Net Profit, Profit Factor, Equity Drawdown Maximal, Total Trades**, lãi từng
   tháng. Lệch lớn (ví dụ khác dấu lãi/lỗ) thì gửi lại báo cáo Tester để đối chiếu lệnh.
5. Đạt tiêu chí gợi ý: PF > 1,05, Equity DD ≤ 25% vốn, lãi ít nhất 2/3 quý. Sau đó chạy demo ≥ 1 tháng.

## 7. Chạy lại

```bash
pip install numpy pandas
python3 prep.py                                   # cần repo EA-PRO cạnh repo này (hoặc đặt biến EA_PRO)
python3 -c "import prep; prep.main_bridge(); prep.main_bridge_seed(8)"
g++ -O3 -march=native -std=c++17 -pthread dh710sim.cpp -o dh710sim
python3 gen_sets.py 1500 11 > sets_v1.csv
./dh710sim --ticks du_lieu/ticks_bridge.bin --from 2026-01-01 --to 2026-06-01 --sets sets_v1.csv --out v1_train.csv
./stress.sh sets_chot.csv chot                    # 5 kịch bản sức chịu đựng
python3 write_set.py sets_chot.csv CanBang SET/ten.set
```

| File | Nội dung |
|---|---|
| `dh710sim.cpp` | Bộ giả lập V710, nhiều SET song song |
| `prep.py` | Chuẩn bị nến/chỉ báo/tick dựng |
| `gen_sets.py`, `select_sets.py`, `write_set.py`, `stress.sh`, `stress_table.py`, `cmp.py` | Sinh, chọn, xuất SET, kiểm tra |
| `sets_*.csv` | Các bộ SET đã chạy |
| `ket_qua/` | Kết quả: `val_*` (hiệu chỉnh tick), `v1_*` (vòng 1), `uv1_*`/`uv2_*` (sức chịu đựng), `v2_9thang` (tinh chỉnh), `chot_9thang`, `nhat_ky/` |
| `SET/` | File .set cho MT5 |
