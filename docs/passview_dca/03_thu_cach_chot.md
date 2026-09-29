# Thử cách chốt khác: chốt cố định 5–10 USD, đóng khi tick đảo chiều

Ngày lập: 29/09/2026 · Tái lập: `python3 tools/passview/thu_cach_chot.py` · Kết quả: `ket_qua/chot_co_dinh_chinh_xac.csv`, `ket_qua/thu_cach_chot.csv`

Điểm vào giữ nguyên như Passview (7.054 lệnh đóng bằng SL), chỉ đổi cách thoát. Mỗi lệnh 0,05 lot: 1,00 giá = 5 USD, phí 0,30 USD/lệnh.

## 1. Giữ trailing, thêm chốt cố định (tính CHÍNH XÁC từ kết quả thật)

Lệnh đã kích hoạt trailing có đỉnh lãi = SL cuối + 0,50. Đỉnh ≥ mức chốt thì lệnh thoát ở mức chốt, còn lại giữ nguyên kết quả thật.
Cách tính dựa trên giả thuyết trailing 0,50 (khớp 97%, xem báo cáo 01).

| Cách thoát | Lãi ròng (USD) | PF | Win % | TB thắng | Thứ Sáu / thứ Hai |
|---|---|---|---|---|---|
| **Passview thật (không chốt cố định)** | **3.215** | **1,318** | 44,7 | 4,22 | 1.195 / 2.020 |
| Chốt +1,00 (5 USD) | −100 | 0,990 | 44,7 | 3,17 | −94 / −5 |
| Chốt +1,50 (7,5 USD) | 1.174 | 1,116 | 44,7 | 3,58 | 380 / 794 |
| Chốt +2,00 (10 USD) | 1.884 | 1,186 | 44,7 | 3,80 | 661 / 1.223 |
| Chốt +3,00 (15 USD) | 2.627 | 1,260 | 44,7 | 4,04 | 976 / 1.651 |

Win rate **không đổi**, vì chốt cố định chỉ chạm vào những lệnh vốn đã thắng và chỉ **cắt bớt** lãi của chúng.
- 26,3% lệnh chạy tới +1,00; trailing thật cho chúng thoát ở trung bình +1,36.
- 7,8% lệnh chạy tới +2,00; trailing thật cho chúng thoát ở trung bình +2,49.

Toàn bộ lợi thế nằm ở vài lệnh chạy dài. Chốt 5 USD làm bot **hết lãi**, chốt 10 USD **mất khoảng 41% lãi**.

## 2. Bỏ trailing, chỉ chốt cố định và SL 0,50 (mô phỏng, chỉ tham khảo)

Không tính chính xác được: sau khi Passview thoát, không biết giá đi tiếp tới đâu. Mô phỏng trên chuỗi giá khớp cho ra:
- chốt 5 USD: lỗ khoảng 1.500 USD;
- chốt 7,5 USD: lỗ khoảng 500 USD;
- chốt 10 USD: hòa.

Bộ mô phỏng **thiên lạc quan**: chạy lại quy tắc Passview nó cho 4.750 USD so với 3.215 USD thật. Kết quả thật có thể còn tệ hơn.
Lý do win rate tụt xuống 22–35%: không có trailing thì lệnh đã lãi +0,50 vẫn có thể quay về −0,50.

## 3. Đóng ngay khi tick đảo chiều

**Không kiểm được bằng log hiện có.** Chuỗi giá khớp có bước khoảng 0,21, không thấy nhiễu từng tick, nên mô phỏng sẽ đẹp giả.

Theo lập luận (chưa có số liệu), gần như chắc chắn **lỗ**:
- Mỗi lệnh tốn khoảng 0,16 giá chi phí (spread khoảng 0,10 + phí 0,06), tức khoảng 0,80 USD. Giá vàng đảo tick liên tục, nên đa số lệnh sẽ thoát trước khi kịp bù chi phí.
- Những lệnh chạy dài, nguồn lãi duy nhất, sẽ bị cắt ở nhịp hồi đầu tiên.
- Không đặt được SL cách giá 1 tick (vướng stops level), nên phải đóng bằng lệnh thị trường: chịu trễ và trượt giá. Hàng trăm lệnh/giây còn dễ bị sàn giới hạn.

Muốn có số liệu thật cần **tick `XAUUSD.e` của KVB** cho các ngày 25/09 và 28/09.
