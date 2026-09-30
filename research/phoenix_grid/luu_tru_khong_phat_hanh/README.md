# Lưu trữ — bản không phát hành

Các file ở đây **không dùng để cài lên MT5**. Chúng được giữ lại để tra cứu và để làm lại khi cần.

## `EA_PHOENIX_GRID_V0_22_TEST.mq5` — hedge theo Phoenix + tỉa bằng lời hedge

- **Ngày dựng:** 30/09/2026. Dựng từ V0.21 theo ba lựa chọn của bạn:
  - bật hedge khi breakout xác nhận ngược basket hoặc khi basket xuống sâu 6 tầng;
  - thang hedge 25 → 50 → 70 → 100% lot basket;
  - dùng lời hedge đóng lệnh lỗ xa nhất, với điều kiện tổng không âm.
- **Trạng thái:** không phát hành, chưa compile, chưa gửi cho bạn.
  - Kiểm tra tĩnh đạt: 159 hàm, 129 input, không có biến chưa khai báo, không có lời gọi sai số tham số.
- **Lý do không phát hành:**
  - Mô phỏng Python cho thấy thiết kế hedge này làm drawdown tệ hơn so với tắt hedge.
  - **Nhả hedge khi giá hồi:** giá hồi một khoảng tầng thì hedge giảm cấp. Giá đảo chiều liên tục làm hedge tăng rồi giảm cấp nhiều lần, mỗi lần chốt một khoản lỗ nhỏ. Lot 1,2, 9 tháng: 2.795 lần đổi cấp, 2 lần cháy.
  - **Khóa DCA:** khi không giảm cấp và khóa DCA, basket bị kẹt hàng nghìn giờ vì không có cơ chế phục hồi. Theo kế hoạch Phoenix, phần phục hồi là giao dịch vùng mới bằng quỹ riêng.
  - Bảng số liệu nằm trong `docs/phoenix_grid/11_EA_V0_23_BO_PP10_SET_CENT.md`, mục hedge tham khảo.
- **Bản kế tiếp:** V0.23 dựng lại từ V0.21 (bỏ PP10) chứ không từ V0.22. Muốn làm lại hedge thì cần thiết kế mới:
  - hedge là lớp bảo vệ cuối cùng;
  - có phần phục hồi;
  - kiểm định trên mô phỏng trước khi viết mã.
- Chú thích đầu file có nhắc tới `11_EA_V0_22_HEDGE_TIA.md`. Tài liệu này chưa được viết. Số 11 đã dùng cho tài liệu của V0.23.
