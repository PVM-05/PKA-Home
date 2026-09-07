---
trigger: always_on
---

# Quy Tắc Thiết Kế Cơ Sở Dữ Liệu (Supabase/PostgreSQL)

## 1. Naming convention
- **Tên bảng và cột**: Tiếng Anh, `snake_case`, không dùng tiếng Việt có dấu. Có thể giữ tên hiển thị tiếng Việt ở tầng UI.
- **Khóa chính**: `id` (uuid, dùng `gen_random_uuid()` mặc định của Supabase).
- **Khóa ngoại**: `<ten_bang_so_it>_id` (VD: `apartment_id`, `user_id`).
- **Timestamp**: Bắt buộc trên mọi bảng phải có `created_at` và `updated_at`.
- **Định dạng mã phòng/căn hộ (`apartments.code`)**: Định dạng chuẩn có dạng `a0110` (hoặc `A0110`) — cấu trúc `<Block><Tầng 2 chữ số><Phòng 2 chữ số>` (ví dụ: `a0110` là Block a, Tầng 01, Phòng 10), thay vì `a101` / `A101`.

## 2. Schema Đề Xuất
- `users` (id, full_name, phone, role, created_at)
- `apartments` (id, code, area, is_empty, created_at)
- `residents_apartments` (id, user_id, apartment_id, relation_role)
- `invoices` (id, apartment_id, period, due_date, total_amount, status, created_at)
- `invoice_items` (id, invoice_id, fee_type, unit_price, quantity, subtotal)
- `issue_reports` (id, apartment_id, reporter_id, assigned_staff_id, status, description, created_at)
- `issue_images` (id, issue_report_id, image_url)
- `announcements` (id, title, content, is_urgent, created_at)
- `apartment_link_requests` (id, user_id, apartment_id, requested_relation_role, status, created_at)

## 3. Quy tắc bảo mật dữ liệu (RLS)
- Bật RLS cho tất cả bảng ngay khi tạo, không để mặc định public.
- Nguyên tắc chung:
  - Cư dân chỉ `SELECT` được dữ liệu gắn với `apartment_id` của mình.
  - Chỉ ban quản lý mới `UPDATE` được trạng thái `invoices.status`.
- Viết policy test-case riêng trước khi code, lưu vào tài liệu thiết kế.

## 4. Supabase Storage
- Bucket riêng cho từng loại file: `issue-images/`, `avatars/` (nếu có).
- Đặt tên file theo định dạng: `<issue_report_id>/<timestamp>.jpg` để tránh trùng và dễ truy vết.
