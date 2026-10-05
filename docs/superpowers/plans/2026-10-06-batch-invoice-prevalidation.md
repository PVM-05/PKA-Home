# Kế Hoạch Triển Khai: Tạo Hóa Đơn Hàng Loạt Có Tiền Kiểm Tra Dữ Liệu (Pre-flight Dry-Run & Idempotency)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triển khai quy trình tạo hóa đơn hàng loạt 2 bước (Pre-flight Validation -> Dry-Run -> Transaction Create) phân loại 280 căn hộ thành 4 nhóm (🟢 Hợp lệ, 🟡 Thiếu dữ liệu, 🔴 Bất thường, ⚪ Đã có hóa đơn), cho phép phát hành ngay các căn hợp lệ và chống trùng lặp tuyệt đối (Idempotency).

**Architecture:** Áp dụng Repository Pattern và Riverpod Provider. Backend Supabase PostgreSQL cung cấp Unique Constraint `(apartment_id, period)`, hàm RPC Dry-Run `validate_monthly_bulk_invoices` (không ghi DB) và hàm RPC phát hành `generate_valid_bulk_invoices` (nguyên tử với `ON CONFLICT DO NOTHING`). Frontend nâng cấp `BulkInvoiceDialog` thành quy trình 2 bước tương tác trực quan với 4 thẻ KPI và danh sách đối soát chi tiết.

**Tech Stack:** Flutter 3.x, Flutter Riverpod, Supabase (PostgreSQL RPC, Unique Constraints, Transactions), intl.

## Global Constraints

- 100% tiếng Việt chuẩn mực trên giao diện, thông báo lỗi và nhật ký.
- Tuyệt đối không dùng Emoji trên UI — sử dụng Material Icons (`Icons.fact_check_outlined`, `Icons.check_circle_outline`, `Icons.warning_amber_rounded`, `Icons.error_outline`).
- Định dạng mã căn hộ chuẩn: `A0110` / `B0110`.
- Màu sắc và typography tuân thủ `core/theme/app_theme.dart`.
- Idempotency: Không cho phép tạo hóa đơn trùng lặp cho cùng một căn hộ trong cùng một kỳ.
- Mọi tác vụ phải có test kiểm thử tương ứng, 0 lỗi `dart analyze` và 100% pass `flutter test`.

---

### Task 1: Database Migration & RPCs (`validate_monthly_bulk_invoices`, `generate_valid_bulk_invoices`)

**Files:**
- Create: `supabase/migrations/20261006_01_batch_invoice_prevalidation.sql`
- Create: `test/data/repositories/batch_invoice_migration_test.dart`

**Interfaces:**
- Produces:
  - Unique Constraint: `uq_invoices_apartment_period UNIQUE (apartment_id, period)` trên bảng `public.invoices`.
  - RPC Dry-run: `validate_monthly_bulk_invoices(p_period text, p_mgmt_rate numeric, p_electric_rate numeric, p_water_rate numeric)`:
    - Quét toàn bộ căn hộ `is_empty = false`.
    - Kiểm tra 7 rules validation:
      1. Có chỉ số điện cũ?
      2. Có chỉ số điện mới?
      3. Có chỉ số nước cũ?
      4. Có chỉ số nước mới?
      5. Điện mới >= điện cũ?
      6. Nước mới >= nước cũ?
      7. Căn hộ đã có invoice kỳ này chưa?
    - Trả về JSON: `total_scanned`, `valid_count`, `missing_count`, `invalid_count`, `already_invoiced_count`, `total_estimated_amount`, `valid_items`, `issues`.
  - RPC Create: `generate_valid_bulk_invoices(p_period text, p_due_date timestamptz, p_mgmt_rate numeric, p_electric_rate numeric, p_water_rate numeric, p_target_apartment_ids uuid[] DEFAULT NULL)`:
    - Tạo `invoices` và `invoice_items` cho các căn hợp lệ.
    - An toàn với `ON CONFLICT (apartment_id, period) DO NOTHING`.
    - Gửi thông báo hệ thống đến cư dân liên kết.
    - Trả về JSON: `success`, `invoices_created`, `total_amount`, `skipped_count`.

- [ ] **Step 1: Viết unit test kiểm tra logic phân loại và tạo hóa đơn của RPCs trong `batch_invoice_migration_test.dart`**
- [ ] **Step 2: Viết migration file `supabase/migrations/20261006_01_batch_invoice_prevalidation.sql`**
- [ ] **Step 3: Chạy test xác nhận PASS**
- [ ] **Step 4: Commit vào git**

```bash
git add supabase/migrations/20261006_01_batch_invoice_prevalidation.sql test/data/repositories/batch_invoice_migration_test.dart
git commit -m "feat(db): them rpc validate_monthly_bulk_invoices va generate_valid_bulk_invoices kem unique constraint"
```

---

### Task 2: Data Model Phân Loại Tiền Kiểm Tra (`BulkInvoiceValidationResult`)

**Files:**
- Create: `lib/data/models/bulk_invoice_validation_model.dart`
- Create: `test/data/models/bulk_invoice_validation_model_test.dart`

**Interfaces:**
- Produces:
  - `BulkInvoiceValidationModel`:
    - `period` (String)
    - `totalScanned` (int)
    - `validCount` (int)
    - `missingCount` (int)
    - `invalidCount` (int)
    - `alreadyInvoicedCount` (int)
    - `totalEstimatedAmount` (double)
    - `validItems` (List<ValidApartmentBillingItem>)
    - `issues` (List<BulkInvoiceIssueItem>)
  - `ValidApartmentBillingItem`: `apartmentId`, `apartmentCode`, `area`, `electricUsage`, `waterUsage`, `estimatedTotal`.
  - `BulkInvoiceIssueItem`: `apartmentId`, `apartmentCode`, `type` (`missing_data`, `invalid_reading`, `already_invoiced`), `message`.
  - Helpers: `canGenerateAny`, `hasIssues`, `typeDisplayName`.

- [ ] **Step 1: Viết unit test cho `BulkInvoiceValidationModel`**
- [ ] **Step 2: Triển khai `lib/data/models/bulk_invoice_validation_model.dart`**
- [ ] **Step 3: Chạy test xác nhận PASS**
- [ ] **Step 4: Commit vào git**

```bash
git add lib/data/models/bulk_invoice_validation_model.dart test/data/models/bulk_invoice_validation_model_test.dart
git commit -m "feat(invoice): them BulkInvoiceValidationModel cho tien kiem tra hoa don hang loat"
```

---

### Task 3: Cập Nhật Repository & Provider Layer

**Files:**
- Modify: `lib/data/repositories/management_repository.dart`
- Create: `test/data/repositories/bulk_invoice_repository_test.dart`

**Interfaces:**
- Produces:
  - `ManagementRepository.validateMonthlyBulkInvoices({required String period, double mgmtRate, double electricRate, double waterRate})`: Trả về `Future<BulkInvoiceValidationModel>`.
  - `ManagementRepository.generateValidBulkInvoices({required String period, required DateTime dueDate, double mgmtRate, double electricRate, double waterRate, List<String>? targetApartmentIds})`: Trả về `Future<Map<String, dynamic>>`.

- [ ] **Step 1: Viết unit test cho các phương thức repository mới**
- [ ] **Step 2: Triển khai các phương thức trong `lib/data/repositories/management_repository.dart`**
- [ ] **Step 3: Chạy test xác nhận PASS**
- [ ] **Step 4: Commit vào git**

```bash
git add lib/data/repositories/management_repository.dart test/data/repositories/bulk_invoice_repository_test.dart
git commit -m "feat(repo): them validateMonthlyBulkInvoices va generateValidBulkInvoices vao ManagementRepository"
```

---

### Task 4: Nâng Cấp `BulkInvoiceDialog` Thành Quy Trình Pre-flight 2 Bước

**Files:**
- Modify: `lib/features/management/widgets/bulk_invoice_dialog.dart`
- Create: `test/features/management/bulk_invoice_dialog_preflight_test.dart`

**Interfaces:**
- Bước 1 (Thiết lập):
  - Form chọn kỳ, hạn thanh toán, đơn giá điện, nước, quản lý.
  - Nút bấm: `[ Kiểm tra dữ liệu (Pre-check) ]` (gọi Dry-Run, không ghi DB).
- Bước 2 (Kết quả tiền kiểm tra):
  - 4 Thẻ KPI:
    - 🟢 Hợp lệ (xanh lá)
    - 🟡 Thiếu dữ liệu (vàng cam)
    - 🔴 Bất thường (đỏ)
    - ⚪ Đã có hóa đơn (xám/xanh dương)
  - Tóm tắt: Tổng căn hộ, Có thể tạo ngay, Cần xử lý sau.
  - Danh sách tab:
    - Tab 1: Căn hợp lệ (Hiển thị căn hộ, diện tích, $kWh, m^3$, số tiền dự tính).
    - Tab 2: Cần xử lý (Hiển thị căn hộ, badge phân loại lỗi và mô tả chi tiết: "Chưa có chỉ số nước", "Điện mới < cũ").
  - Nút hành động:
    - `[ Quay lại chỉnh sửa ]`
    - `[ Tạo X hóa đơn hợp lệ ]` (Chỉ tạo cho danh sách hợp lệ, không chặn bởi các căn lỗi).
- Thông báo kết quả:
  - Báo SnackBar chi tiết số hóa đơn được phát hành và doanh thu dự thu.
  - Invalidate `invoicesProvider` và đóng dialog.

- [ ] **Step 1: Viết widget test cho `BulkInvoiceDialog` quy trình 2 bước**
- [ ] **Step 2: Triển khai nâng cấp `lib/features/management/widgets/bulk_invoice_dialog.dart`**
- [ ] **Step 3: Chạy test xác nhận PASS**
- [ ] **Step 4: Commit vào git**

```bash
git add lib/features/management/widgets/bulk_invoice_dialog.dart test/features/management/bulk_invoice_dialog_preflight_test.dart
git commit -m "feat(ui): nang cap BulkInvoiceDialog thanh quy trinh Pre-flight Dry-Run 2 buoc"
```

---

### Task 5: Rà Soát Toàn Diện, Static Analysis & Nghiệm Thu

**Files:**
- Toàn bộ codebase liên quan

- [ ] **Step 1: Chạy `dart analyze` toàn dự án đảm bảo 0 lỗi/cảnh báo**
- [ ] **Step 2: Chạy toàn bộ test suite `flutter test` đảm bảo 100% test cases pass**
- [ ] **Step 3: Cập nhật checklist hoàn tất trong tài liệu kế hoạch**
- [ ] **Step 4: Commit và tổng kết cho người dùng**

```bash
git add docs/superpowers/plans/2026-10-06-batch-invoice-prevalidation.md
git commit -m "docs: hoan tat ke hoach tao hoa don hang loat co tien kiem tra"
```
