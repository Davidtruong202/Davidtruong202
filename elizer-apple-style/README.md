# Elizer.vn — giao diện phong cách apple.com (theme Flatsome)

Bộ file này đổi trang chủ Elizer sang bố cục giống apple.com (các khối sản phẩm
lớn, chữ to, nút bo tròn, nền trắng / xám nhạt / đen) và đổi chữ, header, nút,
thẻ sản phẩm, footer trên toàn website theo cùng phong cách.

| File | Dùng để làm gì |
| --- | --- |
| `trang-chu-ux-builder.txt` | Nội dung mới của trang chủ (thay cho code UX Builder cũ) |
| `elizer-apple.css` | CSS dán vào Flatsome: toàn website + các khối trang chủ (class `ez-…`) |
| `preview.html` | Bản xem trước: mở bằng trình duyệt. Hình ảnh và tên sản phẩm chỉ để minh hoạ |

## Bố cục trang chủ mới

1. **3 khối hero lớn** (như iPhone / Mac trên apple.com):
   Cột lọc nước Inox (nền trắng) → Màng siêu lọc PVDF UF (nền xám) →
   Máy lọc nước RO công nghiệp (nền đen). Mỗi khối có tiêu đề, một câu ngắn,
   nút **Tìm hiểu thêm** (đến trang danh mục) và **Nhận báo giá** (đến /lien-he/).
2. **Lưới 2 × 2**: Máy siêu lọc tổng từ trường, Hệ thống lọc tổng đầu nguồn,
   Máy lọc nước RO gia đình, Linh kiện phụ kiện lọc nước.
3. **Slider 2 banner cũ** (ảnh ID 6835 và 6054), bo góc, chấm điều hướng kiểu Apple.
4. **Khám phá sản phẩm**: 7 tab dạng viên thuốc, mỗi tab là một danh mục cũ
   (cat 331, 332, 330, 15, 328, 329, 333) lấy sản phẩm tự động từ WooCommerce,
   thẻ trắng bo góc kiểu Apple Store. Trên điện thoại thẻ vuốt ngang.
5. **Vì sao chọn Elizer**: 4 thẻ có biểu tượng.
6. **Tư vấn**: ảnh cũ ID 6855 + nút **Gọi 0949 814 444** + link Gửi yêu cầu tư vấn.
7. **Tin tức**: Bài viết nổi bật (ID 6884, 6736, 6440, 6346, 6408) và 3 bài mới nhất.

## Cài đặt

> Nên làm trên **một trang nháp mới**, xong mới đặt làm trang chủ, để website
> đang chạy không bị ảnh hưởng và luôn quay lại được.

### Bước 1 — Dán CSS

WP Admin › **Flatsome › Advanced › Custom CSS** › ô **All screens** → dán toàn bộ
`elizer-apple.css` vào **cuối** ô (giữ nguyên CSS đang có) → Save.
(Hoặc: Giao diện › Tùy biến › **CSS bổ sung**.)

CSS mới chỉ đổi giao diện, không đổi nội dung. Muốn bỏ phần nào thì xoá cả mục
đó (các mục được đánh số 0 → 8 và có chú thích tiếng Việt).

### Bước 2 — Font, màu, header (Giao diện › Tùy biến)

Tên mục có thể khác đôi chút tùy phiên bản Flatsome.

- **Style › Typography**: chọn font **Inter** cho Headline, Base, Navigation, Alt.
  Máy Mac/iPhone sẽ tự dùng font hệ thống SF Pro giống apple.com.
- **Style › Colors**: Primary = `#0071e3` nếu muốn mọi nút trên website cùng màu
  xanh Apple (hoặc giữ màu thương hiệu).
- **Header**: chiều cao Header Main khoảng **52px**, logo cao tối đa khoảng 34px,
  bật **Sticky header**, tắt **Uppercase** của menu. Đặt menu chính ở giữa
  header và giữ menu ngắn (tối đa khoảng 8 mục, tên ngắn), giống apple.com.
  Nếu đang có Header Bottom (thanh menu thứ hai) thì nên chuyển menu lên Header
  Main rồi tắt Header Bottom. Top Bar được CSS đổi thành dải thông báo xám nhạt;
  không cần thì tắt.

### Bước 3 — Tạo trang chủ mới

1. **Trang › Thêm trang mới**, đặt tên ví dụ "Trang chủ mới".
2. Mục **Giao diện trang (Template)** chọn **Page - Full Width**.
3. Dán toàn bộ `trang-chu-ux-builder.txt`:
   - Trình soạn thảo cổ điển: tab **Văn bản** (Text) → dán. Không dán ở tab
     **Trực quan** (Visual), code sẽ bị biến thành chữ thường.
   - Trình soạn thảo khối: menu ⋮ › **Trình soạn thảo mã** (Code editor) → dán.
4. Bấm **Lưu nháp** (không bấm Đăng).

### Bước 4 — Chọn ảnh cho 7 khối sản phẩm

Bấm **Edit with UX Builder**. Mỗi khối hero và mỗi ô lưới có một phần tử **Image**
đang trống (trên trang hiện khung viền đứt "Chọn ảnh cho khối này trong UX
Builder"). Bấm vào đó và chọn ảnh:

| Khối | Nền | Ảnh phù hợp | Kích thước gợi ý |
| --- | --- | --- | --- |
| Cột lọc nước Inox | trắng | ảnh nền trắng hoặc PNG nền trong suốt | khoảng 2200 × 1040 |
| Màng siêu lọc PVDF UF | xám | nền trắng cũng được (tự hoà vào nền xám) | khoảng 2200 × 1040 |
| Máy lọc nước RO công nghiệp | đen | PNG nền trong suốt hoặc ảnh nền tối | khoảng 2200 × 1040 |
| Máy siêu lọc tổng từ trường | đen | PNG nền trong suốt hoặc ảnh nền tối | khoảng 1400 × 800 |
| Hệ thống lọc tổng đầu nguồn | xám | nền trắng hoặc trong suốt | khoảng 1400 × 800 |
| Máy lọc nước RO gia đình | xám | nền trắng hoặc trong suốt | khoảng 1400 × 800 |
| Linh kiện, phụ kiện lọc nước | đen | PNG nền trong suốt hoặc ảnh nền tối | khoảng 1400 × 800 |

Ảnh sản phẩm đã tách nền (PNG) cho kết quả giống Apple nhất. Ảnh nền trắng đặt
trên khối đen sẽ hiện thành một khung trắng bo góc.

Xong bấm **Save** trong UX Builder và xem thử trang nháp (Xem trước).

### Bước 5 — Đưa lên trang chủ thật

Dán vào chính trang **Trang chủ** đang dùng (không đổi trang chủ ở Cài đặt › Đọc),
để giữ nguyên tiêu đề, mô tả SEO của Rank Math và đường dẫn trang.

1. Mở trang nháp "Trang chủ mới" → tab **Văn bản** → bấm vào ô code → Ctrl+A → Ctrl+C.
   Lúc này code đã có mã các ảnh vừa chọn trong UX Builder.
2. Mở trang **Trang chủ** → tab **Văn bản** → Ctrl+A → Ctrl+C, dán code cũ ra
   Notepad để dự phòng.
3. Vẫn ở ô đó: Ctrl+A → Ctrl+V dán code mới. Kiểm tra **Giao diện (Template)** là
   **Page - Full Width** → bấm **Cập nhật**.
4. Đưa trang nháp "Trang chủ mới" vào Thùng rác.

Sau đó xoá cache (plugin cache, Cloudflare nếu có) và xem thử trên điện thoại.

## Tuỳ chỉnh nhanh

- **Đổi chữ, link**: bấm vào khối chữ trong UX Builder để sửa trực tiếp.
- **Đổi nền một khối**: sửa ô **Class** (mục Advanced của phần tử):
  - Hero (phần tử Section): `ez ez-hero` = trắng, `ez ez-hero ez-gray` = xám,
    `ez ez-hero ez-dark` = đen.
  - Ô lưới (phần tử Column): `ez-tile` = xám, `ez-tile ez-white` = trắng,
    `ez-tile ez-dark` = đen.
- **Thêm ô lưới**: nhân bản (Duplicate) một Column trong row "Ô sản phẩm".
- **Dùng màu thương hiệu thay xanh Apple**: trong CSS mục 0 đổi
  `--ez-accent: #0071e3;` thành màu của bạn, ví dụ `#003d76`.
- **Số sản phẩm mỗi tab**: sửa ô Products của phần tử Products trong tab đó.
- **Đưa slider banner lên đầu trang**: kéo section "Banner" lên trên cùng trong UX Builder.

## Những gì đã sửa so với code cũ

- **Link sai**: nút "Xem tất cả" (bản điện thoại) của Máy lọc tổng từ trường đang
  trỏ sang `nemtrungnguyen.com/nem-cao-su-non/`. Đã sửa về `/may-loc-tong-tu-truong/`.
- **Link không thống nhất**: bản điện thoại dùng `/danh-muc/...`, riêng Linh kiện
  trỏ `/danh-muc/vat-lieu-loc-nuoc/`. Nay mọi nút dùng đúng link ở tiêu đề danh mục.
- **Bỏ các khối đang ẩn** còn sót từ mẫu Nệm Trung Nguyên (Báo chí nói gì về chúng
  tôi, Nệm cao su thiên nhiên, Nệm lò xo). Các khối này đang tắt nên không hiện ra.
- Link gọi điện đổi thành `tel:0949814444` (bỏ khoảng trắng). Sửa chính tả
  "phụ vụ" thành "phục vụ".
- Link trong website không còn mở tab mới.
- Tab RO công nghiệp và Lọc tổng đầu nguồn trước hiện 5 sản phẩm, nay 8 như các
  tab khác (RO công nghiệp vẫn giữ thứ tự tăng dần như cũ).
- Thêm một thẻ H1 ẩn cho SEO ("Elizer – Thiết bị và giải pháp lọc nước"); tiêu đề
  các khối dùng H2.

## Lưu ý

- **Nội dung chữ**: các câu ngắn dưới tiêu đề và 4 lý do "Vì sao chọn Elizer"
  được viết dựa trên tên danh mục và đoạn giới thiệu có sẵn trên trang. Hãy đọc
  lại và sửa cho đúng thực tế của Elizer.
- **Header, footer**: CSS được viết theo cấu trúc mặc định của Flatsome. Nếu
  header có khối HTML tự làm (ví dụ hotline 2 dòng) thì có thể cần chỉnh nhẹ.
- **Bản quyền**: không dùng logo, hình ảnh hay file font của Apple, chỉ mô phỏng
  bố cục và kiểu chữ. SF Pro chỉ hiện trên thiết bị Apple (font hệ thống); các
  máy khác dùng Inter.
- **Quay lại giao diện cũ**: dán lại code cũ vào trang Trang chủ (hoặc khôi phục
  trong ô **Bản sửa đổi** của trang) và xoá đoạn CSS đã dán.
