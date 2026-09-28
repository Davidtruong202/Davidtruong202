# Kiến thức giao dịch cho EA

Thư mục này là "sách luật" để AI viết EA. Mỗi khái niệm một file, viết
**bằng lời của bạn, cụ thể tới mức lập trình được**. Link chỉ là nguồn
tham khảo — AI thường không xem được video, PDF sau đăng nhập hay khoá học
trả phí, nên nội dung quan trọng phải được chép thành chữ ở đây.

## Mẫu cho mỗi file (ví dụ `order-block.md`)

```markdown
# Order Block

## Định nghĩa
Nến giảm cuối cùng trước một cú tăng mạnh phá cấu trúc (BOS).

## Quy tắc đo được
- "Tăng mạnh" = thân nến ≥ 1.5 × ATR(14)
- Vùng OB = từ Low tới Open của nến đó
- OB hết hiệu lực khi giá đóng cửa dưới Low của OB

## Cách vào lệnh
- Chờ giá quay về vùng OB trong killzone London/NY
- SL dưới Low OB, TP1 = đỉnh gần nhất

## Hình minh hoạ
![ví dụ](hinh/order-block-1.png)

## Nguồn
- https://... (phút 12:30)
```

## Danh sách chủ đề

- [ ] Cấu trúc thị trường (swing, BOS, CHoCH)
- [ ] Thanh khoản (PDH/PDL, EQH/EQL, Asian range, sweep)
- [ ] Order Block
- [ ] Fair Value Gap
- [ ] Premium / Discount / OTE
- [ ] Killzone & Judas Swing
- [ ] Các setup vào lệnh
- [ ] Quản lý vốn & thoát lệnh
