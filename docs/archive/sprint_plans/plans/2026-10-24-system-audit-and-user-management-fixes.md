# Kế Hoạch Triển Khai: Khắc Phục Lỗi Hệ Thống P1/P2 & Nâng Cấp Module Quản Trị Người Dùng

> **Mục tiêu**: Xử lý triệt để 100% các lỗ hổng P1/P2 đã kiểm chứng (CSDL, RLS, tính toàn vẹn tài chính, Edge Function FCM) ở Giai đoạn 1; sau đó triển khai nâng cấp toàn diện Module Quản trị Người Dùng (8 tính năng) ở Giai đoạn 2.
> **Nhánh thực hiện**: `main` (commit trực tiếp, không tạo nhánh phụ).
> **Tiêu chuẩn chất lượng**: 100% Tiếng Việt chuẩn mực trên UI, không hardcode credentials, TDD (viết test kiểm thử trước, code sau), đạt `flutter analyze` 0 cảnh báo.

---

## GIAI ĐOẠN 1: KHẮC PHỤC TRIỆT ĐỂ LỖ HỔNG P1/P2 & AN NINH HỆ THỐNG

### Nhiệm vụ 1: Lược đồ `amenity_bookings.notes` & RPC `book_amenity_slot`
- **Tập tin**:
  - `supabase/migrations/20261024_02_system_audit_p1_p2_fixes.sql`
  - `lib/data/models/amenity_booking_model.dart`
  - `test/data/repositories/amenity_booking_repository_test.dart`
- **Chi tiết**:
  - Thêm cột: `ALTER TABLE public.amenity_bookings ADD COLUMN IF NOT EXISTS notes TEXT;`.
  - Cập nhật model `AmenityBookingModel` ánh xạ trường `notes`.
  - Khôi phục đầy đủ các kiểm tra nghiệp vụ trong `book_amenity_slot`:
    1. Kiểm tra sức chứa tối đa cho tiện ích độc quyền `p_guests_count <= max_capacity`.
    2. Kiểm tra khoảng thời gian bảo trì `amenity_maintenance_windows`.
    3. Kiểm tra căn hộ: Nếu `p_apartment_id` rỗng và cư dân liên kết $> 1$ căn hộ, yêu cầu chọn rõ căn hộ thay vì tự lấy căn đầu tiên.
    4. Kiểm tra thời gian: Lấy thời gian hiện tại theo múi giờ Việt Nam `(now() AT TIME ZONE 'Asia/Ho_Chi_Minh')`. Nếu đặt trong ngày hiện tại, chặn các khung giờ đã bắt đầu hoặc đã qua.

### Nhiệm vụ 2: Siết RLS `amenity_bookings` & RPC xem chỗ trống ẩn danh
- **Tập tin**:
  - `supabase/migrations/20261024_02_system_audit_p1_p2_fixes.sql`
  - `lib/data/repositories/amenity_booking_repository.dart`
- **Chi tiết**:
  - Xóa bỏ chính sách đọc mở rộng `FOR SELECT USING (auth.uid() IS NOT NULL)`.
  - Thiết lập chính sách RLS mới: Chỉ cho phép cư dân xem các bản ghi do chính mình đặt (`booked_by = auth.uid()`) hoặc thuộc căn hộ của mình (`apartment_id IN (...)`), Ban Quản Lý (`is_staff()`) xem toàn bộ.
  - Tạo RPC `get_amenity_slot_availability(p_amenity_id UUID, p_date DATE)` (Security Definer) che giấu 100% thông tin cá nhân (PII: tên, số căn hộ, SĐT, ghi chú) của các cư dân khác khi người dùng mở màn hình kiểm tra chỗ trống.

### Nhiệm vụ 3: Idempotent `simulate_unified_payment` & Ngăn chặn PENDING trùng
- **Tập tin**:
  - `supabase/migrations/20261024_02_system_audit_p1_p2_fixes.sql`
  - `test/data/services/payment_service_test.dart`
- **Chi tiết**:
  - Khóa dòng hóa đơn / booking (`FOR UPDATE`).
  - Kiểm tra nếu đã có giao dịch `status = 'PENDING'` cho hóa đơn hoặc booking đó:
    - Nếu trùng phương thức: Tái sử dụng và trả về giao dịch hiện có (Idempotent).
    - Nếu đổi phương thức: Cập nhật phương thức trên giao dịch `PENDING` hiện tại.
    - Tuyệt đối không `INSERT` bản ghi `PENDING` trùng lặp.
  - Bổ sung Partial Unique Index ở mức động cơ CSDL:
    - `uq_pending_invoice_transaction` trên `payment_transactions(invoice_id) WHERE status = 'PENDING'`
    - `uq_pending_booking_transaction` trên `payment_transactions(booking_id) WHERE status = 'PENDING'`

### Nhiệm vụ 4: Bảo mật Edge Function FCM (`send-fcm-notification`)
- **Tập tin**:
  - `supabase/functions/send-fcm-notification/index.ts`
- **Chi tiết**:
  - Xác thực nguồn gọi: Kiểm tra header `Authorization` (Service Role Key) hoặc webhook secret `x-webhook-secret`.
  - Xác minh chéo trong CSDL `public.notifications`: Bản ghi thông báo phải tồn tại và thuộc về `user_id` người nhận.
  - Sửa phản hồi HTTP: Trả về `success: successCount > 0` và mã HTTP `200` nếu thành công, `502` nếu toàn bộ thiết bị thất bại, không trả `success: true` giả.

### Nhiệm vụ 5: Khắc phục lỗi Client & Bảo vệ Dọn Dữ Liệu
- **Tập tin**:
  - `lib/features/resident/screens/edit_issue_screen.dart`
  - `lib/main.dart` & `lib/core/supabase_config.dart`
  - `pubspec.yaml`
  - `supabase/clean_data.sql`
- **Chi tiết**:
  - Thay `Image.network` bằng `AppStorageImage` trong `edit_issue_screen.dart` để tự động tạo và làm mới Signed URL cho ảnh private.
  - Xử lý nạp `.env` an toàn khi build sạch; hiển thị màn hình báo lỗi cấu hình nếu thiếu thông tin Supabase thay vì để app mở rồi lỗi ngầm.
  - Thêm confirmation guard vào `supabase/clean_data.sql`: Bắt buộc phải có `SET pka.confirm_reset_data = 'YES_I_WANT_TO_RESET_ALL_DATA';` mới cho phép thực thi lệnh TRUNCATE dữ liệu.

---

## GIAI ĐOẠN 2: NÂNG CẤP TOÀN DIỆN MODULE QUẢN TRỊ NGƯỜI DÙNG

### Nhiệm vụ 6: Nâng cấp Lược đồ & RPC Quản Trị
- **Tập tin**:
  - `supabase/migrations/20261024_03_admin_user_management.sql`
- **Chi tiết**:
  - Bổ sung cột `email VARCHAR`, `is_active BOOLEAN DEFAULT true` vào bảng `public.users`.
  - Cập nhật trigger `handle_new_user()` đồng bộ `new.email` vào `public.users.email`.
  - Đồng bộ ngược (backfill) `email` từ `auth.users` sang `public.users`.
  - Siết chặt ở mức máy chủ: RLS và các RPC chặn mọi thao tác dữ liệu nếu `is_locked = true` hoặc `is_active = false`.
  - Tạo RPC quản trị:
    - `admin_create_user(p_email, p_full_name, p_phone, p_role, p_apartment_id, p_relation_role)`: Tạo tài khoản an toàn từ backend, tự động gửi link thiết lập mật khẩu.
    - `admin_update_user_profile(p_target_user_id, p_full_name, p_phone, p_role)`: Cập nhật thông tin hồ sơ.
    - `admin_toggle_user_status(p_target_user_id, p_action, p_reason)`: Khóa / Vô hiệu hóa (soft delete) / Kích hoạt lại tài khoản.
    - `admin_send_password_reset(p_email)`: Kích hoạt email khôi phục mật khẩu.

### Nhiệm vụ 7: Nâng cấp Model & Repository Flutter
- **Tập tin**:
  - `lib/data/models/resident_model.dart`
  - `lib/data/repositories/management_repository.dart`
  - `lib/data/providers/management_provider.dart`
- **Chi tiết**:
  - Cập nhật `ResidentModel`: Thêm trường `email`, hỗ trợ danh sách nhiều căn hộ `List<ResidentApartmentLink> apartments` kèm vai trò từng căn (chủ hộ / người thuê / thành viên).
  - Bổ sung các hàm trong `ManagementRepository`: `createUser`, `updateUserProfile`, `toggleUserStatus`, `sendPasswordResetEmail`.

### Nhiệm vụ 8: Nâng cấp Giao diện Quản Trị Cư Dân & Nhân Sự
- **Tập tin**:
  - `lib/features/management/screens/resident_management_screen.dart`
  - `lib/features/management/widgets/resident_360_detail_sheet.dart`
- **Chi tiết**:
  - Nút & Form "Thêm người dùng mới" (Họ tên, Email, SĐT, Vai trò, Chọn căn hộ & vai trò cư trú).
  - Form "Chỉnh sửa thông tin hồ sơ" (Họ tên, SĐT, Vai trò).
  - Nút "Vô hiệu hóa tài khoản" và "Khóa tài khoản" với hộp thoại xác nhận lý do rõ ràng.
  - Nút "Gửi email đặt lại mật khẩu".
  - Hiển thị danh sách đầy đủ tất cả các căn hộ liên kết của cư dân, cho phép chuyển đổi và gỡ đúng căn hộ được chọn.
  - Bộ lọc nâng cao: Lọc theo vai trò (Cư dân, Quản trị, Kế toán, Kỹ thuật), trạng thái (Hoạt động, Đã khóa, Vô hiệu hóa), căn hộ; tìm kiếm nhanh qua Email, SĐT, Họ tên.

---

## KIỂM THỬ & NGHIỆM THU
1. Chạy `flutter analyze` đảm bảo 0 lỗi lint / compile.
2. Viết mới và chạy bộ unit / integration tests cho toàn bộ các RPC và repository methods mới.
3. Chạy `flutter test` xác nhận 100% test suite vượt qua.
4. Commit và push trực tiếp lên nhánh `main`.
