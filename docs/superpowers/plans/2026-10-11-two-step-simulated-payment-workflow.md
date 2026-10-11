# Kế Hoạch Triển Khai: Luồng Thanh Toán Mô Phỏng 2 Bước (Two-Step Simulated Payment Workflow)

> **Mục tiêu**: Hoàn thiện toàn diện quy trình thanh toán mô phỏng phục vụ đánh giá đồ án tốt nghiệp PKA-Home:
> 1. Cư dân gửi thông báo thanh toán (Chuyển khoản mô phỏng VietQR Sandbox hoặc Tiền mặt tại quầy) -> Hóa đơn chuyển `pending_confirmation`, giao dịch lưu `status = 'PENDING'`, mã giao dịch `PENDING-...`. Giao diện hiển thị trạng thái chờ xác nhận màu cam, tuyệt đối không báo thành công giả, không trừ tiền thật.
> 2. Ban Quản Lý đối soát và bấm "Xác nhận đã thu" -> RPC `record_manual_payment` cập nhật giao dịch `PENDING` hiện có thành `SUCCESS` trong cùng transaction ACID (giữ nguyên mã giao dịch ổn định), chuyển hóa đơn sang `paid`.
> 3. Kiểm soát phân quyền, chống trùng lặp (Idempotency), kiểm tra khóa `FOR UPDATE` và 100% test passing.

---

## Danh Sách File Liên Quan

| File | Hành Động | Vai Trò & Trách Nhiệm |
| :--- | :--- | :--- |
| `supabase/migrations/20261011_04_resident_payment_submission_workflow.sql` | Tạo mới | Migration nới lỏng constraint `payment_transactions_status_check` cho phép `PENDING`; cập nhật RPC `simulate_unified_payment` (gửi yêu cầu, khóa `FOR UPDATE`, idempotency); cập nhật RPC `record_manual_payment` (cập nhật `PENDING` -> `SUCCESS` giữ mã giao dịch ổn định). |
| `lib/data/models/payment_transaction_model.dart` | Chỉnh sửa | Bổ sung `isPending`, nhãn `"Chờ xác nhận"`, xử lý fallback mặc định không gán `SUCCESS` bừa bãi. |
| `lib/data/services/payment_service.dart` | Chỉnh sửa | Mở rộng `PaymentResult` với `isPending` và `status`. |
| `lib/core/widgets/unified_payment_sheet.dart` | Chỉnh sửa | Bổ sung lựa chọn phương thức (Chuyển khoản VietQR mô phỏng / Tiền mặt), watermark mô phỏng demo, bước `_PaymentStep.pendingConfirmation` (màu cam, "Chờ Ban Quản Lý xác nhận", mã `PENDING-...`). |
| `lib/features/resident/screens/resident_invoice_detail_screen.dart` | Chỉnh sửa | Khóa nút khi `pending_confirmation` (hiển thị "ĐANG CHỜ BQL XÁC NHẬN"), SnackBar cam khi gửi yêu cầu thành công. |
| `lib/features/resident/screens/amenity_booking_screen.dart` | Chỉnh sửa | Đồng bộ phản hồi thông báo chờ xác nhận dịch vụ. |
| `test/data/models/payment_transaction_model_test.dart` | Tạo mới / Cập nhật | Kiểm thử Unit cho model `PaymentTransactionModel` với trạng thái `PENDING`. |
| `test/widgets/unified_payment_sheet_test.dart` | Tạo mới / Cập nhật | Kiểm thử Widget cho `UnifiedPaymentSheet` hiển thị bước `pendingConfirmation` và nhãn mô phỏng. |
| `test/integration/payment_workflow_migration_test.dart` | Tạo mới | Kiểm thử cấu trúc migration SQL và các ràng buộc bảo mật. |

---

## Chi Tiết Các Nhiệm Vụ (Tasks)

### Task 1: Migration Database & RPCs
- **File**: `supabase/migrations/20261011_04_resident_payment_submission_workflow.sql`
- **Các bước**:
  1. Xóa và tạo lại constraint `payment_transactions_status_check` cho phép: `('SUCCESS', 'PENDING', 'FAILED', 'CANCELLED')`.
  2. Viết lại RPC `public.simulate_unified_payment`:
     - Kiểm tra `auth.uid()`.
     - Với Hóa đơn (`INVOICE`):
       - `SELECT * FROM invoices WHERE id = p_reference_id FOR UPDATE;`
       - Kiểm tra quyền sở hữu căn hộ hoặc quyền BQL.
       - Nếu `status = 'paid'` -> Exception: Hóa đơn đã được thanh toán trước đó.
       - Nếu `status = 'pending_confirmation'`: Kiểm tra giao dịch PENDING đã có; trả về thông tin giao dịch hiện có (idempotency, không sinh giao dịch trùng).
       - Nếu `status = 'unpaid'`: Cập nhật hóa đơn sang `pending_confirmation`, sinh mã `PENDING-INV-...`, chèn bản ghi `payment_transactions` với `status = 'PENDING'`.
     - Với Tiện ích (`SERVICE`):
       - Kiểm tra booking, chèn giao dịch `PENDING-SRV-...`.
  3. Viết lại RPC `public.record_manual_payment`:
     - Kiểm tra `public.is_admin_or_accountant()`.
     - Khóa `invoices FOR UPDATE`.
     - Nếu `status = 'paid'` -> Exception: Hóa đơn đã được thanh toán trước đó.
     - Kiểm tra giao dịch PENDING đang chờ của hóa đơn:
       - Nếu CÓ: Cập nhật chính giao dịch đó thành `SUCCESS`, giữ nguyên `transaction_code`, cập nhật hóa đơn sang `paid` với cùng `transaction_code` và `paid_at = NOW()`.
       - Nếu KHÔNG CÓ: Sinh mã `MANUAL-...`, tạo giao dịch mới `SUCCESS`, cập nhật hóa đơn sang `paid`.
  4. Thực thi migration trên Supabase DB qua tool `execute_sql`.

### Task 2: Cập Nhật Data Layer & Models
- **Files**:
  - `lib/data/models/payment_transaction_model.dart`
  - `lib/data/services/payment_service.dart`
  - `test/data/models/payment_transaction_model_test.dart`
- **Các bước**:
  1. Thêm `bool get isPending => status == 'PENDING';`
  2. `statusDisplayName`: Thêm case `'PENDING': return 'Chờ xác nhận';`
  3. Sửa `fromJson`: `status: json['status'] as String? ?? 'PENDING'`.
  4. Mở rộng `PaymentResult`: Thêm `isPending` và `status`.
  5. Viết unit test xác nhận các trường hợp parsing JSON.

### Task 3: Nâng Cấp Giao Diện UnifiedPaymentSheet & Screens
- **Files**:
  - `lib/core/widgets/unified_payment_sheet.dart`
  - `lib/features/resident/screens/resident_invoice_detail_screen.dart`
  - `lib/features/resident/screens/amenity_booking_screen.dart`
- **Các bước**:
  1. `UnifiedPaymentSheet`:
     - Bổ sung bước `_PaymentStep.pendingConfirmation`.
     - Thêm 2 tùy chọn phương thức thanh toán:
       - Chuyển khoản mô phỏng VietQR Sandbox (hiển thị thông tin STK demo, mã QR với watermark mô phỏng, nội dung CK).
       - Tiền mặt tại văn phòng Ban Quản Lý (hướng dẫn đóng trực tiếp tại quầy).
     - Thêm banner cảnh báo: "Giao dịch mô phỏng phục vụ đồ án, không trừ tiền thật".
     - Khi nhận kết quả PENDING: chuyển sang màn hình cam "Đã gửi thông báo thanh toán - Chờ Ban Quản Lý xác nhận", hiển thị mã `PENDING-...`.
  2. `resident_invoice_detail_screen.dart`:
     - Khi `status == 'pending_confirmation'`: Nút hành động hiển thị màu cam "ĐANG CHỜ BQL XÁC NHẬN" (disabled hoặc bấm để xem chi tiết phiếu hẹn).
     - Khi đóng sheet có kết quả pending: SnackBar màu cam "Đã gửi thông báo thanh toán! Đang chờ Ban Quản Lý xác nhận."
  3. `amenity_booking_screen.dart`:
     - Nhận kết quả pending và hiển thị thông báo chờ xác nhận.

### Task 4: Kiểm Thử Toàn Diện & Phê Duyệt
- **Files**:
  - `test/widgets/unified_payment_sheet_test.dart`
  - `test/integration/payment_workflow_migration_test.dart`
- **Các bước**:
  1. Chạy `flutter test` toàn bộ suite.
  2. Chạy `flutter analyze` đảm bảo 0 issues.
  3. Kiểm tra tính toàn vẹn của git, commit trực tiếp vào `main`.
  4. Đẩy lên remote repository `git push origin main`.
