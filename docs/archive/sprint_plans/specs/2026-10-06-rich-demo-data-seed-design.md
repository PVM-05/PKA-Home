# Thiết Kế Kịch Bản Seed Dữ Liệu Demo Toàn Diện (PKA-Home)

- **Mục tiêu**: Chuẩn bị bộ dữ liệu thực tế, sinh động, đầy đủ mọi module để phục vụ buổi thuyết trình bảo vệ đồ án, giúp Dashboard Ban Quản Lý và Ứng dụng Cư Dân hiển thị đầy đủ biểu đồ, số liệu KPI, danh sách việc khẩn cấp thay vì màn hình trống.
- **Ngày thiết kế**: 06/10/2026
- **Trạng thái**: Chờ duyệt (Under Review)

---

## 1. Yêu Cầu Cốt Lõi & Quy Ước Dữ Liệu

1. **Email người dùng**: 100% sử dụng đuôi `@gmail.com` theo chỉ định của người dùng.
2. **Mật khẩu dùng chung cho mọi tài khoản demo**: `PkaHome@2026` (được mã hóa blowfish `crypt('PkaHome@2026', gen_salt('bf'))` tương thích hoàn toàn với Supabase Auth).
3. **Quy mô dữ liệu (Theo yêu cầu người dùng)**:
   - **3 Tòa nhà**: Block A (Tòa A), Block B (Tòa B), Block C (Tòa C).
   - **25 Căn hộ có người ở**: Mã căn chuẩn `A0101` - `A0502`, `B0101` - `B0403`, `C0101` - `C0305`.
   - **38 Cư dân**: Có đầy đủ thông tin tiếng Việt tự nhiên, số điện thoại Việt Nam, vai trò rõ ràng (Chủ hộ, Người thuê, Người thân).
   - **40 Phương tiện (Thẻ xe)**: 28 xe máy, 12 ô tô; 32 xe `approved`, 5 xe `pending`, 3 xe `rejected` kèm lý do từ chối cụ thể.
   - **3 Tháng hóa đơn (08/2026, 09/2026, 10/2026)**:
     - Tháng 08/2026: 100% `paid` (lịch sử doanh thu thu đủ).
     - Tháng 09/2026: 80% `paid`, 20% `overdue` (nợ đọng để demo widget việc cần xử lý).
     - Tháng 10/2026: Đang mở thanh toán (`unpaid`), có hóa đơn chờ BQL duyệt.
     - Đầy đủ phân rã chi phí: Quản lý, Điện, Nước, Phí xe.
   - **20 Giao dịch thanh toán (`payment_transactions`)**: Mã giao dịch dạng `TXN...`, lưu vết thanh toán VietQR cho hóa đơn và đặt cọc tiện ích.
   - **10 Phản ánh sự cố (`issue_reports`)**: Đầy đủ các mức ưu tiên (Khẩn cấp, Trung bình, Thấp), có sự cố kèm ảnh nghiệm thu trước/sau (`issue_images`) và đánh giá sao (`issue_ratings`).
   - **10 Đặt chỗ tiện ích (`amenity_bookings`)**: Hồ bơi, Sân tennis, BBQ ngoài trời, Phòng sinh hoạt cộng đồng; có booking đã check-in, đang chờ sử dụng.
   - **10 Thông báo tòa nhà (`announcements`)**: Thông báo khẩn cấp (PCCC, bảo trì thang máy) và thông báo định kỳ phân nhóm theo tòa nhà.
   - **5 Trang thiết bị vận hành (`equipment`)**: Thang máy Schindler, Máy phát điện Cummins, Hệ thống bơm Ebara, Trạm biến áp 1000kVA, Hệ thống PCCC Notifier; có lịch bảo dưỡng định kỳ.

---

## 2. Danh Sách Tài Khoản Thuyết Trình Trọng Tâm

| Vai trò | Họ và tên | Email đăng nhập | Mật khẩu | Chức năng demo chính |
| :--- | :--- | :--- | :--- | :--- |
| **Trưởng Ban Quản Lý (Admin)** | Nguyễn Văn An | `pkahome.admin@gmail.com` | `PkaHome@2026` | Toàn quyền Dashboard, phân công kỹ thuật, duyệt hóa đơn hàng loạt, xem KPI |
| **Kế toán viên (Accountant)** | Trần Thị Mai | `pkahome.ketoan@gmail.com` | `PkaHome@2026` | Lập hóa đơn, đối soát VietQR, duyệt thanh toán, báo cáo nợ đọng |
| **Kỹ thuật viên (Technician)** | Lê Hoàng Long | `pkahome.kythuat@gmail.com` | `PkaHome@2026` | Tiếp nhận sự cố, tải ảnh nghiệm thu sau sửa chữa, kiểm tra bảo trì thiết bị |
| **Cư dân chủ hộ (A0101)** | Phạm Minh Đức | `cudan.a0101@gmail.com` | `PkaHome@2026` | Xem hóa đơn, quét VietQR, gửi phản ánh sự cố, đặt sân Tennis, quản lý 2 xe máy |
| **Cư dân thuê nhà (B0202)** | Hoàng Thùy Linh | `cudan.b0202@gmail.com` | `PkaHome@2026` | Báo số điện nước qua ảnh quét OCR, đăng ký thẻ ô tô, đặt tiệc nướng BBQ |
| **Cư dân (C0301)** | Đỗ Quang Hải | `cudan.c0301@gmail.com` | `PkaHome@2026` | Nhận thông báo bảo trì khẩn cấp, tra cứu danh bạ khẩn cấp, đánh giá chất lượng dịch vụ |

---

## 3. Kiến Trúc Thực Thi 2 Bước

### Bước 1: Đồng bộ DDL Migrations còn thiếu lên Supabase
Thực thi các script DDL để bảo đảm các bảng sau tồn tại trên remote database:
1. `equipment` (quản lý thiết bị tòa nhà)
2. `payment_transactions` (lịch sử giao dịch thanh toán hợp nhất)
3. `meter_reading_submissions` (dữ liệu gửi chỉ số điện nước)
4. `issue_ratings` (đánh giá sao kỹ thuật viên)
5. `amenities` & `amenity_bookings` (tiện ích & đặt chỗ)

### Bước 2: Thực thi file `supabase/seed.sql`
- Script được tổ chức theo thứ tự ràng buộc khóa ngoại (Foreign Keys):
  1. `auth.users` & `public.users`
  2. `public.apartments` (cập nhật trạng thái `is_empty = false` cho 25 căn hộ)
  3. `public.residents_apartments` (gắn cư dân vào căn hộ)
  4. `public.vehicles` (thẻ xe máy, ô tô)
  5. `public.equipment` (trang thiết bị tòa nhà)
  6. `public.amenities` & `public.amenity_bookings` (tiện ích và đặt chỗ)
  7. `public.invoices` & `public.invoice_items` (hóa đơn 3 tháng)
  8. `public.payment_transactions` (giao dịch thanh toán)
  9. `public.meter_reading_submissions` (chỉ số điện nước)
  10. `public.issue_reports`, `issue_images`, `issue_ratings` (sự cố và nghiệm thu)
  11. `public.announcements` (thông báo tòa nhà)
- Tính năng **Idempotent**: Dùng `ON CONFLICT DO NOTHING` hoặc `ON CONFLICT DO UPDATE` để có thể chạy lại an toàn bất kỳ lúc nào mà không bị lỗi trùng lặp dữ liệu.

---

## 4. Tài Liệu Bàn Giao Kèm Theo
- **File kịch bản SQL**: [`supabase/seed.sql`](file:///c:/Users/ADMIN/StudioProjects/pka_home/supabase/seed.sql)
- **Tài liệu tra cứu tài khoản demo**: [`docs/demo_accounts.md`](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/demo_accounts.md) (bảng tra cứu email/mật khẩu phân loại theo từng kịch bản demo để nhóm dễ dàng mở tra cứu trong buổi bảo vệ).
