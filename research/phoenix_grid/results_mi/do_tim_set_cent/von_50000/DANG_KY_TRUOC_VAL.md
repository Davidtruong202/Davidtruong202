# Đăng ký trước VAL — ứng viên sau DEV

Ghi (commit) trước khi chạy giai đoạn kế tiếp; không sửa sau khi đã chạy.

## Luật (trích `do_tim_set_cent.py`)

```
Luật (cố định trong mã này, trước khi chạy):
  đường giá = đường gốc (cực trị gần giá mở đi trước) và NHIEU_VT đường có thứ tự đỉnh / đáy trong từng nến M1 ngẫu
              nhiên — phần mô phỏng không biết chắc khi không có tick thật;
  điểm      = lãi / DD lớn nhất (tiền); cháy tài khoản thì điểm = −1;
  DEV       = bước 1: SO_NGAU_NHIEN cấu hình ngẫu nhiên (lot tầng 0 cố định 0,01) + cấu hình tham chiếu, đường gốc;
              bước 2: mọi cấu hình không cháy và có lãi ở đường gốc chạy thêm NHIEU_VT đường; "bền" = không cháy trên
              cả 5 đường; mức theo DD lớn nhất của 5 đường: A ≤ DD_TOI_DA %, B ≤ DD_MUC_B %, C còn lại; xếp theo mức
              rồi trung vị điểm 5 đường;
              bước 3: SO_DANG_KY cấu hình bền đứng đầu chạy mọi láng giềng một bước (đường gốc, gồm lot tầng 0 0,02);
              điểm vùng = trung vị điểm của (láng giềng + 5 đường); đăng ký theo mức rồi điểm vùng;
  VAL       = chạy đường gốc + NHIEU_VT; chọn các ứng viên không cháy và DD ≤ DD_TOI_DA trên mọi đường, lãi > 0 ở
              đường gốc (không ứng viên nào đạt thì dùng DD ≤ DD_MUC_B và ghi rõ mức B); xếp theo trung vị điểm; tối đa
              SO_CHON;
  TEST      = đạt khi: không cháy và DD ≤ ngưỡng đã dùng ở VAL trên mọi đường, lãi > 0 và bỏ tháng tốt nhất vẫn ≥ 0 ở
              đường gốc.
Chỉ số thoát lệnh (báo cáo, không dùng để xếp hạng): giờ giữ basket trung vị / phân vị 95 / lớn nhất, số basket mỗi
ngày, số lệnh.
```

## Ứng viên

### U1 (nguồn N029) — mức A

| Khóa | Input EA | Giá trị |
|---|---|---|
| lot0 | InpLotCoSo | 0.01 |
| kieu_lot | InpHeSoLot / InpDungBangLot | 1.15 |
| lot_max | InpLotTangToiDa | 0.05 |
| buoc_min | InpBuocMinUSD | 8.0 |
| buoc_atr | InpBuocATR | 0.5 |
| so_tang | InpSoTangToiDa | 20 |
| tia_tp | InpTiaTPBuoc | 1.5 |
| tp_atr | InpGioTPATR | 1.5 |
| trail | InpTrailClear / InpTrailGiuPT | 60 |
| hoa_von_tang | InpHoaVonTuTang | 2 |
| xoa | InpXoaTangLo / InpXoaGomLai | 0 |
| xoa_tu | InpXoaTuSoTang | 4 |
| loc_xh | InpChanNguocXH | False |
| ma_h1 | InpPP0MA | 200 |
| giay_dca | InpGiayGiuaDCA | 180 |
| tia_lap_lai | InpTiaLapLai | True |
| cho_clear | InpGiayChoSauClear | 60 |

### U2 (nguồn N188) — mức A

| Khóa | Input EA | Giá trị |
|---|---|---|
| lot0 | InpLotCoSo | 0.01 |
| kieu_lot | InpHeSoLot / InpDungBangLot | 1.3 |
| lot_max | InpLotTangToiDa | 0.1 |
| buoc_min | InpBuocMinUSD | 4.5 |
| buoc_atr | InpBuocATR | 0.5 |
| so_tang | InpSoTangToiDa | 30 |
| tia_tp | InpTiaTPBuoc | 0.5 |
| tp_atr | InpGioTPATR | 0.5 |
| trail | InpTrailClear / InpTrailGiuPT | 80 |
| hoa_von_tang | InpHoaVonTuTang | 4 |
| xoa | InpXoaTangLo / InpXoaGomLai | tat |
| xoa_tu | InpXoaTuSoTang | 4 |
| loc_xh | InpChanNguocXH | True |
| ma_h1 | InpPP0MA | 50 |
| giay_dca | InpGiayGiuaDCA | 60 |
| tia_lap_lai | InpTiaLapLai | True |
| cho_clear | InpGiayChoSauClear | 60 |

### U3 (nguồn N044) — mức A

| Khóa | Input EA | Giá trị |
|---|---|---|
| lot0 | InpLotCoSo | 0.01 |
| kieu_lot | InpHeSoLot / InpDungBangLot | bang |
| lot_max | InpLotTangToiDa | 0.02 |
| buoc_min | InpBuocMinUSD | 15.0 |
| buoc_atr | InpBuocATR | 2.0 |
| so_tang | InpSoTangToiDa | 40 |
| tia_tp | InpTiaTPBuoc | 1.5 |
| tp_atr | InpGioTPATR | 1.0 |
| trail | InpTrailClear / InpTrailGiuPT | 60 |
| hoa_von_tang | InpHoaVonTuTang | 0 |
| xoa | InpXoaTangLo / InpXoaGomLai | tat |
| xoa_tu | InpXoaTuSoTang | 4 |
| loc_xh | InpChanNguocXH | False |
| ma_h1 | InpPP0MA | 200 |
| giay_dca | InpGiayGiuaDCA | 180 |
| tia_lap_lai | InpTiaLapLai | True |
| cho_clear | InpGiayChoSauClear | 10 |

### U4 (nguồn N112) — mức A

| Khóa | Input EA | Giá trị |
|---|---|---|
| lot0 | InpLotCoSo | 0.01 |
| kieu_lot | InpHeSoLot / InpDungBangLot | 1.2 |
| lot_max | InpLotTangToiDa | 0.5 |
| buoc_min | InpBuocMinUSD | 20.0 |
| buoc_atr | InpBuocATR | 0.5 |
| so_tang | InpSoTangToiDa | 40 |
| tia_tp | InpTiaTPBuoc | 2.0 |
| tp_atr | InpGioTPATR | 0.5 |
| trail | InpTrailClear / InpTrailGiuPT | 60 |
| hoa_von_tang | InpHoaVonTuTang | 8 |
| xoa | InpXoaTangLo / InpXoaGomLai | 2 |
| xoa_tu | InpXoaTuSoTang | 2 |
| loc_xh | InpChanNguocXH | False |
| ma_h1 | InpPP0MA | 100 |
| giay_dca | InpGiayGiuaDCA | 180 |
| tia_lap_lai | InpTiaLapLai | True |
| cho_clear | InpGiayChoSauClear | 10 |

### U5 (nguồn N171) — mức A

| Khóa | Input EA | Giá trị |
|---|---|---|
| lot0 | InpLotCoSo | 0.01 |
| kieu_lot | InpHeSoLot / InpDungBangLot | 1.15 |
| lot_max | InpLotTangToiDa | 0.1 |
| buoc_min | InpBuocMinUSD | 1.5 |
| buoc_atr | InpBuocATR | 0.8 |
| so_tang | InpSoTangToiDa | 40 |
| tia_tp | InpTiaTPBuoc | 0.5 |
| tp_atr | InpGioTPATR | 2.0 |
| trail | InpTrailClear / InpTrailGiuPT | tat |
| hoa_von_tang | InpHoaVonTuTang | 2 |
| xoa | InpXoaTangLo / InpXoaGomLai | 2 |
| xoa_tu | InpXoaTuSoTang | 2 |
| loc_xh | InpChanNguocXH | False |
| ma_h1 | InpPP0MA | 20 |
| giay_dca | InpGiayGiuaDCA | 60 |
| tia_lap_lai | InpTiaLapLai | True |
| cho_clear | InpGiayChoSauClear | 60 |

