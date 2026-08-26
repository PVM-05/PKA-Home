# Thiết kế Giao diện (Theme Spec)

Tài liệu này lưu trữ các biến số thiết kế để sử dụng trong mã nguồn Flutter (`lib/core/theme/`).

## 1. Màu Sắc (Color Palette)
- **Màu Chính (Primary)**: `#1E88E5` (Xanh biển) - dùng cho các nút bấm chính, tiêu đề nổi bật.
- **Màu Phụ (Secondary)**: `#03A9F4` (Xanh sáng) - dùng cho các biểu tượng (icon) hoặc hiệu ứng hover.
- **Màu Thành công (Success)**: `#4CAF50` (Xanh lá) - trạng thái hóa đơn đã thanh toán, sự cố đã giải quyết.
- **Màu Cảnh báo (Warning)**: `#FF9800` (Cam) - hóa đơn đang chờ xác nhận, phản ánh đang xử lý.
- **Màu Lỗi/Nguy hiểm (Error)**: `#F44336` (Đỏ) - hóa đơn quá hạn nợ đọng, cắt điện/nước.
- **Màu Nền (Background)**: `#F5F7FA` (Xám rất nhạt) - nền ứng dụng giúp nổi bật các Card trắng.
- **Màu Bề mặt (Surface)**: `#FFFFFF` (Trắng) - dùng cho các Card, Panel.
- **Màu Văn bản Chính (Text Primary)**: `#212121` (Xám đen) - độ tương phản cao, dễ đọc.
- **Màu Văn bản Phụ (Text Secondary)**: `#757575` (Xám trung tính) - dùng cho chú thích, ngày tháng.

## 2. Kiểu Chữ (Typography)
- **Font chữ gốc**: `Segoe UI` (Ưu tiên), hoặc `Google Fonts Inter` nếu không nạp được tệp TTF tĩnh.
- **Tiêu đề lớn (Headline Large)**: 24px, Đậm (Bold). Dùng cho lời chào Trang chủ.
- **Tiêu đề vừa (Headline Medium)**: 20px, Đậm (Semi-Bold). Dùng cho tiêu đề màn hình (AppBar).
- **Tiêu đề thẻ (Title Large)**: 18px, Đậm (Bold). Dùng cho tiêu đề thông báo.
- **Văn bản thân (Body Medium)**: 14px, Thường (Regular). Dùng cho nội dung chung, mô tả.
- **Văn bản nhỏ (Label Small)**: 12px, Thường (Regular). Dùng cho ngày tháng, ghi chú phụ.

## 3. Khoảng Cách và Hình Khối (Spacing & Shape)
- **Margin / Padding cơ bản**:
  - `xs`: 4px
  - `sm`: 8px
  - `md`: 16px (Được dùng nhiều nhất cho viền màn hình và khoảng cách giữa các khối lớn)
  - `lg`: 24px
  - `xl`: 32px
- **Độ bo góc (Border Radius)**:
  - Thẻ thông thường (Card/Container): `12px`
  - Nút bấm (Button): `8px`
  - Hình đại diện (Avatar): `50%` (Tròn hoàn toàn)
- **Đổ bóng (Elevation/Shadow)**:
  - Đổ bóng cực nhẹ (Blur 4px, độ mờ 5%, hắt xuống) cho thẻ nội dung.
