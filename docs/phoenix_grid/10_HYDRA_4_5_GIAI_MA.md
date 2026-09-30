# Hydra 4.5 VIP — giải mã từ file set và lịch sử giao dịch

**DAVID HUNTER – PHOENIX GRID – 0941920986**

> **Trạng thái: phân tích, không có mã nguồn Hydra.**
>
> - Nguồn:
>   - file set Hydra đang chạy bạn gửi ngày 30/09/2026;
>   - lịch sử deal và lệnh do script `PG_XuatLichSu.mq5` xuất từ tài khoản real;
>   - các dòng log Experts của Hydra trong ảnh bạn gửi trước đó.
> - Hydra mới chạy từ **30/09 03:50 tới 07:01** (giờ server): **3,2 giờ, 25 basket, toàn bộ BUY**, sâu nhất 9 tầng.
>   Chưa có basket SELL, basket sâu, hedge hay lần kích hoạt bảo vệ vốn nào. Các phần đó chỉ đọc được từ file set, chưa
>   kiểm được bằng lịch sử.
> - Lịch sử gốc của tài khoản real **không đưa lên repo**. Repo chỉ có kết quả tổng hợp (chỉ các lệnh Hydra, không số
>   tài khoản, không nạp / rút):
>   [`results_hydra/hanh_vi_hydra_4_5_XAUUSDc_20260930.md`](../../research/phoenix_grid/results_hydra/hanh_vi_hydra_4_5_XAUUSDc_20260930.md),
>   tạo bằng [`phan_tich_hydra.py`](../../research/phoenix_grid/phan_tich_hydra.py).
> - 3,2 giờ không đủ để đánh giá Hydra lãi hay lỗ. Không có con số hiệu suất nào ở đây là dự báo.

## 1. Tóm tắt

Hydra là một bot DCA **vào lệnh liên tục**:

- **Lệnh đầu** theo hướng MA50 H1. Mở lại sau khi rổ đóng 10 giây, khi giá đã cách giá đóng khoảng 1,5 USD.
- **Lưới DCA hẹp**: 1,5 USD mỗi tầng. Lot tăng dần theo bảng hệ số, 3 tầng đầu 0,01.
- **Thoát cả rổ rất sớm**, ngay khi giá vượt giá trung bình một chút:
  - hòa vốn chung: kích hoạt ở +0,80 USD, đóng khi giá lùi về +0,15 USD trên giá trung bình;
  - trailing cho các đợt giá chạy xa.
- **Một lệnh pyramid** khi lệnh đầu đã có lời 1,5 USD. Lệnh pyramid luôn đóng cùng rổ.
- **Hedge cứu lệnh** khi DD 15% (70% khối lượng) và 25% (100%).
- Không cắt lỗ. Không đặt SL / TP trên server: mọi lệnh do EA tự đóng.

Trong 3,2 giờ: 25 basket đều đóng có lãi, lãi mỗi basket trung vị 1,2 USC. Basket giữ trung vị 4 phút, lâu nhất 24
phút.

## 2. Hydra nhận diện lệnh của mình thế nào

| Magic | Comment | Vai trò | Số deal |
|---|---|---|---|
| 20260826 | `Hydra 1`, `Hydra 2`, … (số tầng) | Lệnh đầu và lệnh DCA | 106 |
| 20260827 | `Hydra Py 1` | Lệnh pyramid (magic + 1) | 24 |

MI Shadow theo dõi Hydra phải để magic 0 (mọi lệnh XAUUSDc). Đặt 20260826 sẽ sót lệnh pyramid.

Hydra tính "điểm" = 0,01 USD: 150 điểm trong set tương ứng khoảng 1,5 USD trên lịch sử. Tỷ lệ đo được là
0,0103 USD mỗi điểm.

## 3. Đối chiếu file set với lịch sử

| Cơ chế | Input | Giá trị trong set | Lịch sử 30/09 | Kết luận |
|---|---|---|---|---|
| Hướng lệnh đầu | `InpMAPeriod`, `InpMATimeframe` | 50, H1 | 25/25 basket BUY. Giá 4.166–4.193, MA50 H1 trong log Hydra khoảng 4.153 | Khớp. Loại MA (SMA hay EMA) chưa rõ |
| Bước DCA | `InpGridStepPoints` | 150 = 1,50 USD | Giá khớp hai tầng liên tiếp: trung vị 1,55, 10% thấp nhất 1,34 USD. Mức 1,34 là do điều kiện xét theo Bid, lệnh khớp ở Ask | Khớp |
| Lot từng tầng | `InpBaseLot` và bảng `InpTier*` | 0,01; ×1,2 tới cấp 6, ×1,05 tới 14, ×1,5 tới 18, ×1,05 tới 26, ×1,3 tới 30. Làm tròn theo bước lot 0,01 | 53/53 lệnh DCA đúng lot tính từ bảng: 0,01 ×3, 0,02 ×3, 0,03 ×3 | Khớp. Lệnh đầu không nhân hệ số, tầng N dùng cấp N − 1 |
| Giãn cách DCA | `InpDCAMinSecsApart` | 20 giây | Giữa hai lệnh DCA ngắn nhất 21 giây. Từ lệnh đầu tới lệnh DCA đầu tiên ngắn nhất 18 giây | Khớp; không áp dụng cho lệnh đầu |
| Chờ sau khi đóng rổ | `InpReentryCooldownSec` | 10 giây | Ngắn nhất 10 giây, trung vị 74 giây | Khớp |
| Vào lại cách giá đóng | `InpReentryMinPoints` | 150 = 1,50 USD | Trung vị 1,50 USD, thấp nhất 1,02 (so Ask với Bid, lệch cỡ spread) | Gần khớp |
| Pyramid | `InpPyramidStepPoints`, `InpUsePyramid` | 150 = 1,50 USD | 12/25 basket có đúng 1 pyramid, giá khớp cách tầng 1 từ 1,49 tới 2,06 USD. Chỉ có ở basket 1–2 tầng | Khớp |
| Pyramid không đóng một mình | `InpPyramidNeverExitAlone` | true | 12/12 lệnh pyramid đóng cùng đợt với lệnh DCA, 0–9 giây sau khi mở | Khớp |
| Hòa vốn chung (SL ẩn) | `InpCombinedBEArmPoints`, `InpCombinedBEFloorPoints` | +0,80 và +0,15 USD trên giá trung bình | Basket ≥ 2 tầng không có pyramid: 8/13 đóng ở +0,17 tới +0,66 USD trên giá trung bình | Khớp với cách đóng sát hòa vốn |
| Trailing rổ DCA | `InpHiddenTrail*`, `InpPeakLockPct` | bắt đầu +2,50 USD (+0,02 mỗi tầng), bước 1,80 (+0,01 mỗi tầng), khóa 40% đỉnh | 5 basket đóng cao hơn: +1,29, +1,84, +1,92, +3,88, +4,48 USD trên giá trung bình | Hợp lý, cần tick để kiểm |
| Cắt lỗ | `InpStopLossPoints` | 0 | Mọi lần đóng do EA; không lệnh nào có SL / TP trên server | Khớp |
| Số tầng tối đa | `InpMaxDCALevels`, `InpMaxSingleLot`, `InpMaxTotalLots` | 1000; 0; 0 (không giới hạn) | Sâu nhất 9 tầng, 0,18 lot | Chưa chạm |

Ví dụ basket sâu nhất: 05:06 – 05:30, 9 tầng BUY, giá tầng 1 là 4.179,69, tầng 9 là 4.166,02 (13,7 USD dưới tầng 1),
tổng 0,18 lot. Giá hồi lên 4.172,86: dưới tầng 1 tới 6,8 USD, nhưng trên giá trung bình (4.170,94) 1,92 USD. Hydra
đóng cả 9 lệnh cùng lúc, lãi 34,6 USC. Rổ không cần giá quay về tầng 1: lot tăng dần kéo giá trung bình xuống gần
giá hiện tại, và rổ thoát ngay khi vượt giá trung bình.

## 4. Các cơ chế trong set chưa xuất hiện trong lịch sử

| Nhóm | Input chính | Giá trị |
|---|---|---|
| Bảo vệ vốn | `InpUseEquityGuard`, `InpMaxDrawdownPercent`, `InpEquityGuardAutoResume` | bật, DD 20%, tự chạy lại. Chưa rõ hành động: ngừng mở lệnh hay đóng hết |
| Hedge cứu lệnh | `InpHedgePartialDD` / `Ratio`; `InpHedgeFullDD` / `Ratio`; `InpHedgeMarginLevel`; `InpHedgeMaxPerCycle` | DD 15% → hedge 70%; DD 25% → 100%; margin level 250%; tối đa 2 lần mỗi chu kỳ. Nhả hedge có đệm 3 USD, vùng chết 15%, leo thang thêm 3 USD, tối đa 12 giờ |
| Chốt lời từng phần | `InpPartialCloseTriggerPoints`, `InpPartialClosePercent` | +2,50 USD, 50% |
| Tỉa cặp lệnh | `InpPairTrimStartLevel`, `InpPairTrimMaxWinners`, `InpPairTrimPoints` | từ tầng 30, tối đa 4 lệnh lãi bù 1 lệnh lỗ, 0,40 USD |
| Giai đoạn theo độ sâu | `InpStage2Legs`, `InpStage2BEArmPoints`, `InpStage2BEFloorPoints` | từ 12 tầng: hòa vốn kích hoạt +0,30, sàn +0,05 USD |
| Trailing rổ pyramid | `InpPyramidTrailStart`, `Step`, `Tighten`, `MinStep`; `InpPyramidBEArmPoints` / `FloorPoints`; `InpCombinedExitMinPoints` | bắt đầu 0,60, bước 0,25 (×0,85, tối thiểu 0,12); hòa vốn +0,30 / +0,15; đóng chung khi ≥ 0,20 USD |
| Chế độ từng phía | `InpUseSideModes`, `InpModeDecidePoints`, `InpModeRescuePoints` | 0,40 và 2,00 USD. Đây là các dòng đổi chế độ PYRAMID / DCA đã thấy trong log |
| Chống kẹt lệnh | `InpFixedTPPoints`, `InpMaxHoldingHours` | TP 4,00 USD; rổ giữ quá 72 giờ thì đóng khi ≥ hòa vốn |
| Bộ lọc | `InpUseNewsFilter`, `InpMaxSpreadPoints` | tin mức 3, trước / sau 30 phút; spread tối đa 0,35 USD. Phiên, xu hướng H4, DXY, cuối tuần đều tắt |

## 5. Rủi ro của bộ tham số Hydra — phép tính số học

Giả định:

- vốn 5.000 USC, 0,01 lot = 1 USC mỗi 1 USD giá;
- mỗi 1,5 USD mở một tầng theo bảng lot ở trên (sau cấp 30 giả định × 1,00);
- chưa tính spread, chưa tính hedge và bảo vệ vốn.

| Mốc | Giá ngược từ tầng 1 | Số tầng | Tổng lot |
|---|---|---|---|
| DD 15% (Hydra bắt đầu hedge 70%) | khoảng 28 USD | 19 | 0,95 |
| DD 20% (bảo vệ vốn) | khoảng 30 USD | 21 | 1,43 |
| DD 25% (hedge 100%) | khoảng 32 USD | 22 | 1,69 |
| Vốn về 0 nếu không hedge | khoảng 44,5 USD | 30 | 4,90 |

Lot từng tầng theo bảng: tầng 1–3: 0,01; 4–6: 0,02; 7–10: 0,03; 11–15: 0,04; 16: 0,07; 17: 0,10; 18: 0,15; 19: 0,22;
20–27: 0,23 → 0,33; 28: 0,43; 29: 0,56; 30: 0,72; 31: 0,94.

Tính từ một điểm vào bất kỳ trên nến M1 XAUUSDm 01–09/2026 (phụ lục 02, Mục A.5), giá đi ngược ≥ 20 USD:

- trong 1 giờ: 15,7% (BUY) / 14,4% (SELL);
- trong 24 giờ: 71% / 69%.

Nghĩa là với 5.000 USC, Hydra sẽ **thường xuyên** chạm ngưỡng hedge. Lớp hedge là thứ giữ tài khoản, không phải lưới
DCA. Vốn lớn hơn thì các mốc trên xa hơn theo tỷ lệ.

## 6. So sánh với Phoenix V0.21

| | Hydra 4.5 VIP (set đang chạy) | Phoenix V0.21 (mặc định) |
|---|---|---|
| Lệnh đầu | Liên tục. Hướng MA50 H1, chờ 10 giây, cách giá đóng trước 1,5 USD | Liên tục (PP0). Hướng MA50 H1, chờ 10 giây. Thêm chặn ngược breakout và ngược xu hướng M5; PP10 / PP1 ưu tiên |
| Khoảng tầng | 1,5 USD cố định | max(6 USD, 1,15 × ATR M5), cố định trong basket |
| Lot | Bảng hệ số: 0,01 → 0,94 ở tầng 31, không trần | 0,01 đều. Bảng hệ số giống Hydra có sẵn nhưng tắt; trần 0,50 lot mỗi tầng |
| Số tầng tối đa | 1000 | 40 |
| Giãn cách DCA | 20 giây | 20 giây |
| Tỉa | Tỉa cặp từ tầng 30 | Mỗi tầng có TP ở mức tầng trên, mở lại khi giá quay xuống (tuần hoàn). Clear từng phần từ 3 tầng |
| Thoát cả rổ | Hòa vốn chung +0,80 / +0,15 trên giá trung bình; trailing +2,50 / 1,80; TP 4 USD; đóng rổ quá 72 giờ | Trailing clear (mốc 1 × ATR M5 × giá trị lot tầng 0, giữ 60% đỉnh); hòa vốn khi đã xuống tầng 4 |
| Pyramid | 1 lệnh khi giá thuận +1,5 USD từ tầng 1; đóng cùng rổ | Không có |
| Hedge | DD 15% → 70%, 25% → 100%, tối đa 2 lần mỗi chu kỳ | Chưa có (MI TEST 2+) |
| Cắt lỗ | Không | Không |
| Giá ngược tới DD 15% / vốn về 0 (5.000, chưa tính hedge) | ~28 / ~44,5 USD | ~92 / ~242 USD |

Hai cách "xử lý lệnh" khác nhau:

- **Hydra** chịu rủi ro ở số tầng và lot: lưới hẹp, lot tăng. Đổi lại rổ thoát rất nhanh, rồi dựa vào hedge khi giá
  chạy xa.
- **Phoenix** chịu rủi ro ở độ dài chu kỳ: lưới rộng, lot đều, tỉa từng tầng. Rổ sống sót được đợt ngược dài hơn
  nhiều, nhưng cần giá hồi nhiều hơn mới clear được.

## 7. Lựa chọn cho bản sau — chờ bạn chọn, chưa làm

Mỗi lựa chọn là một nhóm thay đổi riêng, làm thành phiên bản mới. Có thể chọn nhiều.

| # | Lựa chọn | Lấy từ Hydra | Ảnh hưởng dự kiến |
|---|---|---|---|
| A | Hòa vốn chung: rổ ≥ 2 tầng đạt +X trên giá trung bình thì kích hoạt, lùi về +Y thì đóng cả rổ | +0,80 / +0,15 USD | Chu kỳ ngắn hơn, DD chuỗi DCA thấp hơn; mỗi rổ lãi ít hơn |
| B | Vào lại khi giá cách giá clear trước ít nhất một khoảng | 1,5 USD | Tránh mở rổ mới đúng đỉnh / đáy vừa chốt |
| C | Pyramid: 1 lệnh khi lệnh đầu có lời một khoảng tầng, đóng cùng rổ | +1,5 USD | Thêm lãi khi giá chạy thuận ngay từ đầu |
| D | Lưới hẹp hơn: khoảng tầng tối thiểu nhỏ hơn 6 USD, có thể bật bảng lot | 1,5 USD, bảng lot | Rổ thoát nhanh hơn nhưng giá ngược tới cháy giảm mạnh (bảng Mục 5). Không nên làm nếu chưa có E |
| E | Hedge khẩn cấp theo DD (lớp bảo vệ cuối) | 15% → 70%, 25% → 100% | Đây là hướng TEST 2+ của Market Intelligence |

## 8. Dữ liệu còn cần để kiểm chứng phần còn lại

1. Log Experts của Hydra ngày 30/09 (`MQL5\Logs\20260930.log` trên MT5 real). Log có lý do từng lần đóng: hòa vốn
   chung, trailing, pyramid, đổi chế độ. Dùng để kiểm các dòng "Hợp lý, cần tick để kiểm" ở Mục 3.
2. Tick XAUUSDc ngày 30/09 03:45–07:05. Lấy trong MT5: View → Symbols → Ticks → XAUUSDc → chọn khoảng giờ → Request →
   Export. Có tick thì dựng lại từng lần kích hoạt trailing.
3. Lịch sử dài hơn (vài ngày, có basket SELL, basket sâu, hedge): chạy lại `PG_XuatLichSu` sau vài ngày.
