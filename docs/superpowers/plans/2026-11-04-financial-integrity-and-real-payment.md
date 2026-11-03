# Kế Hoạch Thực Thi: Gói 2 - Tính Toàn Vẹn Tài Chính, Cổng Thanh Toán Thực Tế & Bảo Mật Sổ Quỹ (FIN-01, FIN-02, FIN-03, SEC-04, SEC-05, OPS-FIX)

> **Mã kế hoạch:** `PLAN-HARDENING-02`  
> **Tài liệu đặc tả:** [`docs/superpowers/specs/2026-11-04-financial-integrity-and-real-payment-design.md`](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/superpowers/specs/2026-11-04-financial-integrity-and-real-payment-design.md)  
> **Quy tắc Git:** Toàn bộ công việc commit trực tiếp vào `main`, không tạo branch/worktree phụ.

**Mục tiêu:** Khắc phục triệt để các lỗ hổng P0 về thanh toán giả lập, bảo mật sổ quỹ bảo trì 2% chống race condition, và áp dụng nguyên tắc fail-closed cho nghiệp vụ đặt tiện ích.

**Kiến trúc:** 
- Tầng CSDL: Thu hồi quyền `simulate_unified_payment`, tạo RPC `create_payment_intent` trả về trạng thái `PENDING`, siết quyền kế toán `has_building_role` và dùng PostgreSQL sequences cho `record_maintenance_fund_transaction`.
- Tầng Dart/Flutter: `PaymentService` chuyển sang mô hình Payment Intent thực tế, `UnifiedPaymentSheet` tích hợp đối soát tự động qua webhook Napas 247 và Realtime, `AmenityBookingRepository` loại bỏ hoàn toàn fallback lén để tuân thủ fail-closed.

**Tech Stack:** Flutter/Dart, PostgreSQL/Supabase, Riverpod, Mocktail.

---

## Danh Sách Các Bước Thực Thi (Tasks)

### Task 1: Migration CSDL Tính Toàn Vẹn Tài Chính & Sequence Sổ Quỹ (`20261104_01_financial_integrity_and_real_payment.sql`)

**Files:**
- Create: `supabase/migrations/20261104_01_financial_integrity_and_real_payment.sql`
- Test: `test/database/financial_integrity_migration_test.dart`

**Interfaces:**
- Consumes: `has_building_role(p_building_id, p_allowed_roles)` từ migration `20261103_05_tenant_isolation_and_memberships.sql`.
- Produces: 
  - RPC `create_payment_intent(p_reference_id UUID, p_payment_type TEXT, p_payment_method TEXT) RETURNS JSONB`
  - Sequences: `maintenance_fund_pt_seq`, `maintenance_fund_pc_seq`
  - Ràng buộc: `uq_maintenance_fund_building_voucher`
  - Nâng cấp: `record_maintenance_fund_transaction` (kiểm tra `has_building_role`, `auth.uid()`, sinh số từ sequence)
  - Thu hồi quyền: `REVOKE EXECUTE ON FUNCTION public.simulate_unified_payment(...) FROM authenticated, anon, PUBLIC;`

- [ ] **Step 1: Viết test kiểm tra migration SQL** (`test/database/financial_integrity_migration_test.dart`)
- [ ] **Step 2: Viết migration SQL** (`supabase/migrations/20261104_01_financial_integrity_and_real_payment.sql`)
- [ ] **Step 3: Chạy test xác minh**
- [ ] **Step 4: Commit trực tiếp vào `main`**

---

### Task 2: Sửa Lỗi Fail-Closed Khi Hủy Đặt Chỗ Tiện Ích (`AmenityBookingRepository.cancelBooking`)

**Files:**
- Modify: `lib/data/repositories/amenity_booking_repository.dart`
- Test: `test/data/repositories/amenity_booking_fail_closed_test.dart`

**Interfaces:**
- Consumes: RPC `cancel_amenity_booking`.
- Produces: `AmenityBookingRepository.cancelBooking(String bookingId)` ném ngoại lệ rõ ràng khi RPC thất bại, không thực hiện `update` ngầm.

- [ ] **Step 1: Viết unit test xác nhận fail-closed** (`test/data/repositories/amenity_booking_fail_closed_test.dart`)
- [ ] **Step 2: Xóa khối fallback cập nhật lén trong `cancelBooking()`**
- [ ] **Step 3: Chạy test xác minh**
- [ ] **Step 4: Commit trực tiếp vào `main`**

---

### Task 3: Cập Nhật Dịch Vụ Thanh Toán Thực Tế (`PaymentService` & `PaymentController`)

**Files:**
- Modify: `lib/data/services/payment_service.dart`
- Modify: `lib/data/providers/payment_provider.dart`
- Test: `test/data/services/payment_service_real_test.dart`

**Interfaces:**
- Consumes: RPC `create_payment_intent`.
- Produces: `PaymentService.pay()` gọi `create_payment_intent`, trả về `PaymentResult` có `isPending = true` và `status = 'PENDING'`.

- [ ] **Step 1: Viết unit test cho `PaymentService` & `PaymentResult`** (`test/data/services/payment_service_real_test.dart`)
- [ ] **Step 2: Cập nhật `PaymentService` & `PaymentController`**
- [ ] **Step 3: Chạy test xác minh**
- [ ] **Step 4: Commit trực tiếp vào `main`**

---

### Task 4: Cập Nhật UI Thanh Toán & Hướng Dẫn VietQR Chờ Xác Nhận (`UnifiedPaymentSheet`)

**Files:**
- Modify: `lib/core/widgets/unified_payment_sheet.dart`

**Interfaces:**
- Consumes: `PaymentController.pay()`.
- Produces: Màn hình hiển thị `_PaymentStep.pendingConfirmation` thông báo rõ ràng cho cư dân đang chờ hệ thống ngân hàng đối soát.

- [ ] **Step 1: Kiểm tra và hoàn thiện luồng hiển thị `_PaymentStep.pendingConfirmation` trong `UnifiedPaymentSheet`**
- [ ] **Step 2: Chạy kiểm thử widget & tích hợp**
- [ ] **Step 3: Commit trực tiếp vào `main`**

---

### Task 5: Nghiệm Thu Gói 2, Phân Tích Tĩnh Toàn Dự Án & Cập Nhật Roadmap

**Files:**
- Modify: `docs/COMMERCIAL_PRODUCT_ROADMAP.md`
- Knowledge Graph: `graphify-out/`

- [ ] **Step 1: Chạy toàn bộ test suite Gói 2**
- [ ] **Step 2: Chạy `dart analyze lib test` (0 lỗi, 0 cảnh báo)**
- [ ] **Step 3: Cập nhật `COMMERCIAL_PRODUCT_ROADMAP.md` đánh dấu hoàn tất Gói 2**
- [ ] **Step 4: Cập nhật Knowledge Graph `python -m graphify update .`**
- [ ] **Step 5: Commit nghiệm thu Gói 2 vào `main`**
