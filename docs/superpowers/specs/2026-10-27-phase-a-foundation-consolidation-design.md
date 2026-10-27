# Bản Thiết Kế: Giai Đoạn A1 & A2 - Hợp Nhất Database & Chuẩn Hóa Hợp Đồng Client-Server

- **Ngày tạo:** 2026-10-27
- **Trạng thái:** Chờ phê duyệt (Pending Approval)
- **Tác giả:** Antigravity AI Pair Programmer & Project Lead
- **Mục tiêu:** Giải quyết dứt điểm các lỗi blocker kỹ thuật nền tảng (P0) trong hệ thống PKA-Home, phục vụ lộ trình thương mại hóa sản phẩm.

---

## 1. Bối Cảnh & Vấn Đề Hiện Tại

Sau quá trình phát triển nhanh theo phương pháp lặp (iterative sprints), hệ thống PKA-Home có 58 migration files trong `supabase/migrations/` dẫn đến các vấn đề nghiêm trọng:
1. **Migration lộn xộn & ghi đè:** Một số RPC trọng yếu như `simulate_unified_payment`, `book_amenity_slot`, `reschedule_amenity_booking`, `approve_meter_reading` bị định nghĩa lại từ 4 đến 7 lần với chữ ký khác nhau. Một số migration vô hiệu hóa tính năng rồi migration sau lại bật lại (ví dụ `20261011_01` vs `20261025_01`).
2. **Tham chiếu cột không tồn tại:** Một số migration cũ và trigger gọi các cột sai:
   - `reschedule_amenity_booking` tham chiếu `start_date`/`end_date` thay vì `start_time`/`end_time` trên bảng `amenity_maintenance_windows`.
   - Lỗi so sánh UUID với Text: `invoice_id = p_booking_id::text` trên bảng `payment_transactions`.
   - Tham chiếu sai tên cột giá tiện ích (`v_amenity.price_per_slot` hoặc `v_amenity.price` thay vì `v_amenity.fee_amount`).
3. **Lệch hợp đồng Client ↔ Server:**
   - Phía Flutter (`PaymentService`, `ResidentInvoiceService`) truyền đồng thời cả 2 tham số `p_payment_type` và `p_type`.
   - Phía RPC chỉ mong đợi hoặc xử lý không đồng nhất giữa các phiên bản migration cũ và mới.
4. **Không thể thiết lập môi trường CI/CD hoặc dev local:** Chạy toàn bộ 58 migration từ đầu trên một PostgreSQL database mới tinh sẽ gặp lỗi xung đột do các migration cũ phụ thuộc lẫn nhau một cách bất thường.

---

## 2. Mục Tiêu Giai Đoạn A1 & A2

1. **A1 - Hợp nhất Database Schema:**
   - Di chuyển an toàn toàn bộ 58 file migration cũ vào `supabase/migrations_archive/` làm tài liệu tham chiếu lịch sử.
   - Xây dựng một file migration baseline duy nhất: `supabase/migrations/20261027_01_baseline_schema.sql`.
   - Đảm bảo file baseline chứa đầy đủ 100% thực thể: extensions, types/enums, tables, constraints, indexes, RLS policies, triggers, storage buckets và canonical RPC functions.
   - Mỗi RPC chỉ có **đúng 1 định nghĩa duy nhất** với chữ ký chuẩn xác và xử lý lỗi đồng nhất.
2. **A2 - Chuẩn hóa Hợp đồng Client ↔ Server:**
   - Cập nhật toàn bộ các service và provider trong mã nguồn Flutter để gọi đúng 100% chữ ký RPC chuẩn.
   - Loại bỏ các tham số dư thừa, chuẩn hóa DTO kết quả (`PaymentResult`, `AmenityBookingResult`).
   - Đảm bảo mã Flutter vượt qua `flutter analyze` và các test hiện có chạy thành công.

---

## 3. Thiết Kế Chi Tiết

### 3.1. Cấu Trúc File Baseline Schema (`20261027_01_baseline_schema.sql`)

File baseline được tổ chức theo 9 khối logic độc lập, đảm bảo tính phụ thuộc một chiều:

```
[Khối 1: Extensions & Enums]
       ↓
[Khối 2: Bảng Dữ Liệu Cốt Lõi (Core Tables)]
       ↓
[Khối 3: Bảng Cấu Hình Biểu Phí Động (Fee Schedules)]
       ↓
[Khối 4: Khóa Phụ, Ràng Buộc & Chỉ Mục (Indexes & Constraints)]
       ↓
[Khối 5: Hàm Trợ Giúp Phân Quyền (Security Helper Functions)]
       ↓
[Khối 6: Chính Sách Bảo Mật Mức Hàng (Row-Level Security - RLS)]
       ↓
[Khối 7: Triggers & Hàm Trigger Tự Động]
       ↓
[Khối 8: Canonical RPC Business Functions]
       ↓
[Khối 9: Storage Buckets & Policies]
```

#### Khối 1: Extensions & Enums
- Extensions: `uuid-ossp`, `pgcrypto`.
- Enums:
  - `user_role`: `'admin'`, `'management'`, `'staff'`, `'resident'`.
  - `vehicle_type`: `'motorcycle'`, `'car'`, `'bicycle'`, `'electric_bike'`.
  - `invoice_status`: `'pending'`, `'paid'`, `'overdue'`, `'cancelled'`, `'under_review'`.
  - `payment_method`: `'DEMO'`, `'cash'`, `'bank_transfer'`, `'vnpay'`, `'momo'`.
  - `amenity_booking_status`: `'pending_payment'`, `'confirmed'`, `'cancelled'`, `'waitlist'`, `'completed'`.
  - `meter_submission_status`: `'pending'`, `'approved'`, `'rejected'`.
  - `issue_status`: `'reported'`, `'acknowledged'`, `'in_progress'`, `'resolved'`, `'cancelled'`.

#### Khối 2: Core Tables
- `users`: Quản lý thông tin tài khoản, liên kết `auth.users(id)`.
- `apartments`: Mã căn hộ theo định dạng chuẩn `A0110`, diện tích, trạng thái trống.
- `residents_apartments`: Quan hệ nhiều-nhiều giữa cư dân và căn hộ kèm vai trò quan hệ (`owner`, `tenant`, `member`).
- `apartment_link_requests`: Yêu cầu liên kết căn hộ từ cư dân chờ duyệt.
- `invoices`: Hóa đơn tổng hợp hàng tháng của căn hộ.
- `invoice_items`: Chi tiết từng khoản phí trong hóa đơn (điện, nước, quản lý, gửi xe...).
- `vehicles`: Phương tiện đăng ký của căn hộ.
- `building_amenities`: Danh mục tiện ích (hồ bơi, sân tennis, phòng BBQ, phòng sinh hoạt...).
- `amenity_bookings`: Lịch đặt chỗ tiện ích của cư dân.
- `amenity_maintenance_windows`: Lịch bảo trì tiện ích (`start_time`, `end_time` dạng `TIMESTAMPTZ`).
- `meter_reading_submissions`: Số công tơ điện nước do cư dân hoặc nhân viên ghi nhận.
- `payment_transactions`: Nhật ký giao dịch thanh toán (hóa đơn hoặc tiện ích).
- `announcements`: Thông báo tòa nhà gửi cư dân.
- `issue_reports`: Phản ánh sự cố kỹ thuật từ cư dân.
- `issue_images`: Hình ảnh đính kèm phản ánh sự cố.
- `equipment_maintenance_tasks`: Lịch bảo trì trang thiết bị kỹ thuật tòa nhà.
- `audit_logs`: Nhật ký kiểm toán thao tác hệ thống.

#### Khối 3: Bảng Cấu Hình Biểu Phí Động (Chuẩn bị sẵn cho A3)
- `fee_schedules`: Bảng biểu phí theo thời gian (loại phí, đơn giá, đơn vị tính, ngày hiệu lực `effective_from`, ngày hết hiệu lực `effective_to`).
- `tiered_tariffs`: Bảng biểu giá bậc thang cho điện/nước sinh hoạt (bậc 1 đến bậc 6 theo quy định).

#### Khối 5 & 6: Security Helpers & RLS Policies
- `public.is_staff_or_management()`: Kiểm tra quyền quản trị/nhân viên an toàn.
- `public.get_current_user_role()`: Lấy vai trò của người dùng hiện tại từ bảng `users`.
- RLS được bật trên tất cả các bảng. Cư dân chỉ có quyền xem/sửa dữ liệu thuộc căn hộ của mình; nhân viên kỹ thuật xử lý sự cố; BQL/Admin có toàn quyền vận hành.

#### Khối 8: Canonical RPC Functions (Định nghĩa chuẩn 1 lần duy nhất)

1. **`simulate_unified_payment`:**
   ```sql
   CREATE OR REPLACE FUNCTION public.simulate_unified_payment(
       p_reference_id UUID,
       p_payment_type TEXT DEFAULT 'INVOICE',
       p_payment_method TEXT DEFAULT 'DEMO',
       p_outcome TEXT DEFAULT 'SUCCESS',
       p_failure_reason TEXT DEFAULT NULL
   )
   RETURNS JSONB
   LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = public, pg_catalog;
   ```
   - Chấp nhận `p_reference_id` (ID hóa đơn hoặc ID đặt chỗ tiện ích).
   - `p_payment_type`: Nhận `'INVOICE'` hoặc `'AMENITY'`/`'SERVICE'`.
   - Kết quả trả về JSON đồng nhất:
     ```json
     {
       "success": true,
       "transaction_id": "...",
       "receipt_number": "...",
       "message": "Thanh toán thành công"
     }
     ```

2. **`reschedule_amenity_booking`:**
   - Tham số: `p_booking_id UUID`, `p_new_date DATE`, `p_new_time_slot VARCHAR`, `p_new_guests_count INT DEFAULT NULL`, `p_new_notes TEXT DEFAULT NULL`.
   - Sửa triệt để:
     - So khớp cửa sổ bảo trì:
       ```sql
       AND start_time <= v_day_end
       AND end_time >= v_day_start
       ```
     - Cập nhật giao dịch thanh toán:
       ```sql
       UPDATE public.payment_transactions
       SET amount = ..., updated_at = NOW()
       WHERE booking_id = p_booking_id AND status = 'PENDING';
       ```
     - Đọc giá phí chuẩn: `v_amenity.fee_amount` và `v_amenity.deposit_amount`.

3. **`book_amenity_slot`:**
   - Dùng Transaction Advisory Lock theo hash của `amenity_id + date + time_slot`.
   - Không đặt `FOR UPDATE` trên các truy vấn tính tổng (`SUM(guests_count)`, `COUNT(*)`).
   - Tự động chuyển trạng thái vào danh sách chờ (`waitlist`) nếu hết chỗ, hoặc `pending_payment`/`confirmed` tùy loại phí.

4. **`confirm_payment` & `record_manual_amenity_payment`:**
   - Xử lý xác nhận thanh toán tiền mặt/chuyển khoản do BQL thực hiện, gạch nợ nguyên tử.

5. **`approve_meter_reading` & `reject_meter_reading`:**
   - Phê duyệt chỉ số công tơ, cập nhật trạng thái và tạo bản ghi lịch sử rõ ràng.

6. **`admin_create_user`, `admin_update_user_profile`, `admin_toggle_user_status`, `admin_unlink_apartment`:**
   - Bộ RPC quản lý cư dân và tài khoản nội bộ cho Admin.

---

### 3.2. Chuẩn Hóa Phía Client (Flutter)

1. **`lib/data/services/payment_service.dart`:**
   - Chuẩn hóa hàm `simulateUnifiedPayment`:
     ```dart
     Future<PaymentResult> simulateUnifiedPayment({
       required String referenceId,
       PaymentType type = PaymentType.invoice,
       String paymentMethod = 'DEMO',
       String outcome = 'SUCCESS',
       String? failureReason,
     }) async {
       final typeString = type == PaymentType.invoice ? 'INVOICE' : 'AMENITY';
       final res = await SupabaseConfig.client.rpc(
         'simulate_unified_payment',
         params: {
           'p_reference_id': referenceId,
           'p_payment_type': typeString,
           'p_payment_method': paymentMethod,
           'p_outcome': outcome,
           if (failureReason != null) 'p_failure_reason': failureReason,
         },
       );
       return PaymentResult.fromJson(Map<String, dynamic>.from(res as Map));
     }
     ```
2. **`lib/data/providers/resident_invoice_provider.dart`:**
   - Đồng bộ `simulatePayment` gọi qua `PaymentService` hoặc truyền đúng các tham số canonical trên, loại bỏ hoàn toàn `p_type`.
3. **`lib/data/services/amenity_service.dart` & `lib/data/providers/amenity_booking_provider.dart`:**
   - Rà soát các hàm gọi `reschedule_amenity_booking` và `book_amenity_slot`, đảm bảo khớp tên tham số và kiểu dữ liệu.

---

## 4. Kế Hoạch Xác Minh & Tiêu Chuẩn Nghiệm Thu

1. **Kiểm tra cú pháp Database:**
   - Toàn bộ file baseline `20261027_01_baseline_schema.sql` có thể thực thi tuần tự từ trên xuống dưới mà không gặp bất kỳ lỗi phụ thuộc hoặc trùng lặp bảng/hàm nào.
2. **Kiểm tra chất lượng mã nguồn Flutter:**
   - `flutter analyze` đạt kết quả sạch (0 error).
3. **Kiểm tra kiểm thử tích hợp (Integration Tests):**
   - Chạy test suite `test/integration/amenity_booking_concurrency_and_rpc_test.dart` và các file test liên quan, xác nhận vượt qua tất cả bài kiểm tra.
