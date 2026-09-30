# Đăng ký trước TEST — set chọn sau VAL

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

Luật TEST: không cháy và DD ≤ 35% trên mọi đường, lãi > 0 ở đường gốc, bỏ tháng tốt nhất vẫn ≥ 0; set chính = hạng 1, TEST không dùng để đổi set

## Xếp hạng VAL

- hat=U4, dat_val=True, dat_val_b=True, trung_vi_diem=1.75, net_goc=3310.6, dd_goc=4.8, dd_max=4.8
- hat=U1, dat_val=True, dat_val_b=True, trung_vi_diem=0.57, net_goc=5320.1, dd_goc=14.1, dd_max=14.2
- hat=U3, dat_val=False, dat_val_b=False, trung_vi_diem=1.32, net_goc=-1690.7, dd_goc=13.9, dd_max=13.9
- hat=U5, dat_val=False, dat_val_b=False, trung_vi_diem=0.17, net_goc=5997.8, dd_goc=42.3, dd_max=98.8
- hat=U2, dat_val=False, dat_val_b=False, trung_vi_diem=-1.0, net_goc=-47299.9, dd_goc=100.1, dd_max=100.1

## Set đã chọn (hạng 1 = set chính)

### U4 — hạng 1

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

### U1 — hạng 2

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

