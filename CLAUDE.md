# Hướng dẫn cho AI viết EA trong repo này

File này được Claude Code tự động đọc mỗi phiên làm việc. Đọc hết trước khi
viết hoặc sửa bất kỳ EA nào.

## Bối cảnh

- Chủ repo tự giao dịch, cần EA MetaTrader 5 (MQL5) theo phương pháp ICT/SMC.
- EA hiện có: `MQL5/Experts/XAUUSD_ICT_M5.mq5` (XAUUSD, khung M5, bias H4).
  Mô tả chi tiết và các điểm đã đơn giản hoá: xem `README.md`.
- Dữ liệu lịch sử BTCUSDc (M1, file .zip ở thư mục gốc) và ghi chú nghiên
  cứu: `docs/btcusd_research/`.

## Kiến thức giao dịch — nguồn chuẩn

Toàn bộ quy tắc giao dịch nằm trong `docs/kien-thuc/`. **Khi có mâu thuẫn,
tài liệu trong `docs/kien-thuc/` được ưu tiên hơn hiểu biết chung của AI về
ICT/SMC.** Nếu một quy tắc chưa đủ rõ để lập trình (ví dụ "nến mạnh" là
bao nhiêu ATR), hỏi lại chủ repo thay vì tự đoán, hoặc đưa thành tham số
input và ghi rõ giả định trong README.

## Quy tắc bắt buộc khi viết EA

1. Chỉ ra quyết định khi nến đóng cửa (không dùng dữ liệu intrabar), không
   repaint.
2. In log tổng kết khi backtest kết thúc (số tín hiệu, số lệnh, lý do bị
   lọc) để không bao giờ gặp lại tình huống "backtest 0 lệnh không rõ vì
   sao".
3. Quản lý rủi ro theo % tài khoản; có giới hạn lỗ ngày và số lệnh thua
   liên tiếp.
4. Múi giờ server ↔ New York phải là tham số input, không hard-code.
5. Môi trường của AI không có MetaTrader: ghi rõ trong phản hồi rằng code
   chưa được compile/backtest.
6. Mọi chỗ đơn giản hoá so với tài liệu phải được liệt kê trong README.
