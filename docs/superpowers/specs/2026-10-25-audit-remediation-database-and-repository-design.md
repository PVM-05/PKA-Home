# Tài Liệu Thiết Kế Kỹ Thuật: Khắc Phục Toàn Diện 6 Vấn Đề Rà Soát Hệ Thống (SYS-01 Đến SYS-05 & UI-01)

## 1. Bối cảnh & Mục tiêu
Dựa trên kết quả rà soát mã nguồn tĩnh và đối chiếu trực tiếp với hệ cơ sở dữ liệu PostgreSQL/Supabase đang chạy thực tế, hệ thống ghi nhận 6 điểm quan trọng cần xử lý triệt để trước khi báo cáo và hoàn thiện đồ án:
- **SYS-01 (P1)**: Giao dịch Waitlist chưa hợp lệ trên CSDL thực tế (bảng `payment_transactions` thiếu cột `updated_at`, ràng buộc `check` từ chối `PENDING`, sai tên cột ngày bảo trì `start_date`/`end_date`).
- **SYS-02 (P1)**: Quyền thực thi RPC SECURITY DEFINER chưa được siết chặt đồng bộ (`confirm_payment` mở cho `anon`/`PUBLIC`, thiếu `search_path`, 6 RPCs mới chưa được áp dụng lên CSDL).
- **SYS-03 (P2)**: Các hàm cập nhật trạng thái trong `AmenityBookingRepository` không kiểm tra số bản ghi bị ảnh hưởng (`ROW_COUNT` = 0) khi gặp lỗi RLS hoặc sai ID.
- **UI-01 (P2)**: Thông báo lỗi mã PostgreSQL `23503` trong `createBooking` bị nhầm lẫn với thông báo xóa dữ liệu.
- **SYS-04 (P2)**: Hàm lấy lịch bảo trì `getMaintenanceWindows` nuốt lỗi bảng/cột làm rỗng dữ liệu mà không cảnh báo.
- **SYS-05 (P2)**: Bộ unit test migration chứa lệnh `return` sớm khi thiếu file làm mất tính xác thực; thiếu kiểm thử xác thực cấu trúc CSDL thực tế.

Tài liệu này xác định đặc tả kỹ thuật chi tiết để khắc phục trọn gói 6 vấn đề trên một cách nguyên tử, an toàn và có kiểm chứng.

---

## 2. Kiến trúc & Thiết kế Chi Tiết

### 2.1. Phân hệ CSDL: Migration `20261025_01_fix_waitlist_transactions_and_rpc_security.sql`

#### A. Khắc phục Bảng `public.payment_transactions` (Giải quyết SYS-01)
1. **Bổ sung cột `updated_at`**:
   ```sql
   ALTER TABLE public.payment_transactions 
     ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
   ```
2. **Cập nhật Check Constraint cho `status`**:
   Hiện tại CSDL chỉ cho phép `('SUCCESS', 'FAILED', 'CANCELLED')`. Cần cập nhật để hỗ trợ `'PENDING'`:
   ```sql
   ALTER TABLE public.payment_transactions DROP CONSTRAINT IF EXISTS payment_transactions_status_check;
   ALTER TABLE public.payment_transactions ADD CONSTRAINT payment_transactions_status_check 
     CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED', 'CANCELLED'));
   ```

#### B. Sửa RPC `reschedule_amenity_booking` & `book_amenity_slot` (Giải quyết SYS-01 & SYS-04)
1. **Sửa kiểm tra lịch bảo trì tiện ích**:
   Bảng `amenity_maintenance_windows` có cột `start_time` và `end_time` kiểu `TIMESTAMPTZ`. Không dùng `p_new_date BETWEEN start_date AND end_date`. Sửa thành:
   ```sql
   IF EXISTS (
       SELECT 1 FROM public.amenity_maintenance_windows
       WHERE amenity_id = v_booking.amenity_id
         AND (p_new_date >= (start_time AT TIME ZONE 'Asia/Ho_Chi_Minh')::date 
              AND p_new_date <= (end_time AT TIME ZONE 'Asia/Ho_Chi_Minh')::date)
   ) THEN
       RAISE EXCEPTION 'Tiện ích đang trong thời gian bảo trì vào ngày đã chọn.';
   END IF;
   ```
2. **Đồng bộ hóa giao dịch khi đôn Waitlist**:
   Đảm bảo câu lệnh `INSERT INTO public.payment_transactions` cung cấp đúng các trường:
   - `booking_id`: `v_next_waitlist.id`
   - `user_id`: `v_next_waitlist.booked_by`
   - `apartment_id`: `v_next_waitlist.apartment_id`
   - `amount`: `(v_promoted_fee + v_promoted_deposit)`
   - `payment_method`: `'DEMO'`
   - `status`: `'PENDING'`
   - `transaction_code`: sinh mã tiền tố `SVC...`
   - `type`: `'SERVICE'`
   - `title`: `v_amenity.name || ' (' || v_booking.time_slot || ')'`
   - `created_at`: `NOW()`
   - `updated_at`: `NOW()`

3. **Đồng bộ Trigger `handle_amenity_booking_cancellation`**:
   Cập nhật trigger hủy đặt chỗ để khi đôn waitlist sang `pending_payment` cũng tự động tạo hoặc đồng bộ giao dịch `payment_transactions` trạng thái `PENDING`.

#### C. Siết Chặt Quyền Thực Thi RPC SECURITY DEFINER (Giải quyết SYS-02)
1. **RPC `confirm_payment(UUID)`**:
   - Củng cố `SECURITY DEFINER SET search_path = public, pg_catalog`.
   - Kiểm tra vai trò nội bộ:
     ```sql
     IF NOT (public.is_admin() OR public.is_accountant()) THEN
       RAISE EXCEPTION 'Chỉ Ban quản lý hoặc Kế toán mới có quyền xác nhận thanh toán hóa đơn.';
     END IF;
     ```
   - Thu hồi quyền:
     ```sql
     REVOKE ALL ON FUNCTION public.confirm_payment(UUID) FROM PUBLIC, anon;
     GRANT EXECUTE ON FUNCTION public.confirm_payment(UUID) TO authenticated;
     ```
2. **Cập nhật `SET search_path = public, pg_catalog` cho toàn bộ các hàm helper**:
   - `is_admin`, `is_accountant`, `is_staff`, `is_technician`, `is_management`, `handle_new_user`, `recalc_invoice_total`, `prevent_role_self_escalation`, `log_role_change`.
3. **Áp dụng toàn bộ migration vào CSDL thực tế** thông qua Supabase SQL execution.

---

### 2.2. Phân hệ Repository & Client: `amenity_booking_repository.dart`

#### A. Kiểm tra số bản ghi bị ảnh hưởng khi cập nhật (Giải quyết SYS-03)
Khi cập nhật dữ liệu qua Supabase Postgrest, thêm `.select('id')` và kiểm tra độ dài danh sách trả về:
1. `cancelBooking(String bookingId)`:
   ```dart
   final response = await _client
       .from('amenity_bookings')
       .update({'status': 'cancelled', 'updated_at': DateTime.now().toIso8601String()})
       .eq('id', bookingId)
       .select('id');
   if ((response as List).isEmpty) {
     throw Exception('Không tìm thấy lượt đặt chỗ hoặc bạn không có quyền hủy.');
   }
   ```
2. `updateDepositStatus(String bookingId, String depositStatus, {String? notes})`:
   ```dart
   final response = await _client.from('amenity_bookings').update({
     'deposit_status': depositStatus,
     'deposit_notes': notes,
     'updated_at': DateTime.now().toIso8601String(),
   }).eq('id', bookingId).select('id');
   if ((response as List).isEmpty) {
     throw Exception('Không tìm thấy lượt đặt chỗ hoặc bạn không có quyền cập nhật tiền cọc.');
   }
   ```
3. `markBookingAttendance(String bookingId, String status)`:
   ```dart
   final response = await _client.from('amenity_bookings').update({
     'status': status,
     'updated_at': DateTime.now().toIso8601String(),
   }).eq('id', bookingId).select('id');
   if ((response as List).isEmpty) {
     throw Exception('Không tìm thấy lượt đặt chỗ hoặc bạn không có quyền cập nhật điểm danh.');
   }
   ```

#### B. Sửa thông báo lỗi khóa ngoại `23503` trong `createBooking` (Giải quyết UI-01)
Đổi thông báo sai nghĩa khi bắt mã lỗi `23503`:
```dart
if (e.code == '23503') {
  throw Exception('Thông tin tiện ích hoặc căn hộ liên kết không tồn tại hoặc không hợp lệ.');
}
```

#### C. Xử lý chính xác bảng bảo trì trong `getMaintenanceWindows` (Giải quyết SYS-04)
- Khi gặp mã lỗi `PGRST205` hoặc `42P01`, ghi nhận thông tin cảnh báo rõ ràng qua hệ thống logger thay vì nuốt lỗi âm thầm.
- Đảm bảo query sử dụng các trường `start_time` và `end_time` chuẩn.

---

### 2.3. Phân hệ Kiểm thử (Test Reliability): `pending_correction_migration_test.dart` (Giải quyết SYS-05)

1. **Loại bỏ nguy cơ Silent Pass**:
   - Thay thế toàn bộ mệnh đề:
     ```dart
     if (!migrationFile.existsSync()) return;
     ```
     bằng:
     ```dart
     expect(migrationFile.existsSync(), isTrue, reason: 'Tệp migration bắt buộc phải tồn tại');
     ```
2. **Bổ sung Suite kiểm thử tính toàn vẹn CSDL & Schema thực tế**:
   - Thêm các test case xác thực ràng buộc `payment_transactions_status_check`.
   - Xác thực sự tồn tại của cột `updated_at` trong `payment_transactions`.
   - Xác thực các hàm RPC `SECURITY DEFINER` đã bị `REVOKE` khỏi `anon` và `PUBLIC`.
   - Xác thực `reschedule_amenity_booking` và `book_amenity_slot` không tham chiếu cột ảo `start_date`/`end_date`.

---

## 3. Kế hoạch Kiểm Thử UI Trực Quan & Báo Cáo Thực Nghiệm
Chuẩn bị kịch bản xác minh tương tác trên giao diện người dùng:
1. **Luồng Cư dân Đặt & Đổi Lịch Tiện Ích**:
   - Đặt tiện ích vào slot đã đầy -> Chuyển vào Waitlist (`waitlist`).
   - Lượt đặt trước dời lịch hoặc hủy -> Người trong Waitlist tự động chuyển sang `pending_payment` và xuất hiện giao dịch `PENDING` tương ứng.
2. **Luồng Sửa / Hủy Phiếu Chờ Duyệt (Xe, Điện nước, Liên kết căn hộ)**:
   - Thử sửa và hủy phiếu với tài khoản người tạo -> Thành công.
   - Thử hủy bằng tài khoản cư dân khác -> Bị từ chối với thông báo chuẩn xác.
3. **Luồng Ban Quản Lý Duyệt & Điểm Danh**:
   - Thử điểm danh hoặc cập nhật tiền cọc với booking không tồn tại -> Thông báo lỗi rõ ràng thay vì giả định thành công.
   - Thử gọi RPC nhạy cảm bằng tài khoản thường -> Bị chặn cấp CSDL.

---

## 4. Tiêu Chuẩn Hoàn Thành (Definition of Done)
- [ ] File migration mới `20261025_01_fix_waitlist_transactions_and_rpc_security.sql` được tạo và kiểm thử cú pháp hợp lệ.
- [ ] DDL/SQL đã được áp dụng thành công trên CSDL Supabase thực tế.
- [ ] `AmenityBookingRepository` xử lý kiểm tra `response.isEmpty` trên tất cả thao tác `.update(...)`.
- [ ] Mã lỗi `23503` hiển thị thông báo liên kết dữ liệu hợp lệ thay vì thông báo "xóa dữ liệu".
- [ ] Tất cả các bài test trong `pending_correction_migration_test.dart` chạy thật (không return sớm).
- [ ] Chạy `flutter analyze` đạt 0 lỗi/cảnh báo.
- [ ] Chạy `flutter test` toàn bộ 368+ test case vượt qua 100%.
- [ ] Toàn bộ mã nguồn và tài liệu được commit trực tiếp vào nhánh `main`.
