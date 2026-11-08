# Kế Hoạch Triển Khai: Động Cơ Chốt Chỉ Số Điện - Nước & Tự Động Lập Hóa Đơn (Utility Meter Reading & Automated Billing Engine)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng giải pháp trọn gói thương mại B2B SaaS cho phân hệ Chốt Chỉ Số Tiện Ích & Động Cơ Lập Hóa Đơn Tự Động: Kỹ thuật viên chốt số theo tầng $\rightarrow$ Tính toán tiêu thụ & phát hiện bất thường $\rightarrow$ Duyệt & tự động sinh Hóa đơn tháng kèm VietQR Napas 247/SePay $\rightarrow$ Cư dân nhận thông báo và thanh toán tức thì.

**Architecture:** CSDL Supabase PostgreSQL mở rộng biểu giá `building_utility_rates`, ACID RPC `approve_meter_reading_and_generate_invoice`, `batch_record_meter_readings`; Models Strongly-Typed; Repository & Riverpod Providers; Bàn Quản Lý `ManagementMeterReadingScreen` tích hợp Trạm Chốt Số Nhanh Theo Tầng.

**Tech Stack:** Flutter ^3.12+, Flutter Riverpod ^2.6.1, Supabase PostgreSQL, Material 3.

## Global Constraints
- Commit trực tiếp trên nhánh `main`, không tạo branch/worktree phụ.
- 100% tiếng Việt chuẩn mực trong UI, không dùng Emoji, sử dụng Material Icons (`Icons.*`).
- Bám sát Test-Driven Development (TDD): Viết test trước, kiểm tra Red phase, hoàn thiện code Green phase.
- Static Analysis: `dart analyze lib test` đạt 0 issues.

---

### Task 1: CSDL Migration: Bảng Biểu Giá Điện Nước & ACID RPC Phê Duyệt Tự Động Lập Hóa Đơn

**Files:**
- Create: `supabase/migrations/20261108_03_utility_billing_engine.sql`
- Test: `test/database/utility_billing_engine_migration_test.dart`

**Interfaces:**
- Produces:
  - Bảng `building_utility_rates` (id, utility_type, pricing_model, base_unit_price, vat_percentage, environment_fee_percentage, tiers, is_active).
  - Bổ sung cột trên `meter_reading_submissions`: `previous_electric_reading`, `previous_water_reading`, `electric_consumed`, `water_consumed`, `invoice_id`.
  - RPC: `approve_meter_reading(p_submission_id, p_generate_invoice, p_due_date)`.
  - RPC: `batch_record_meter_readings(p_period, p_readings)`.

- [x] **Step 1: Viết failing test cho Migration SQL**
- [x] **Step 2: Chạy test xác nhận Red phase**
- [x] **Step 3: Tạo file migration `20261108_03_utility_billing_engine.sql` với đầy đủ schema & 2 RPCs**
- [x] **Step 4: Chạy lại test xác nhận Green phase**
- [x] **Step 5: Commit vào `main`**

---

### Task 2: Data Models Strongly-Typed cho Biểu Giá & Tiêu Thụ Điện Nước

**Files:**
- Create: `lib/data/models/building_utility_rate_model.dart`
- Modify: `lib/data/models/meter_reading_submission_model.dart`
- Test: `test/data/models/utility_billing_models_test.dart`

**Interfaces:**
- Consumes: CSDL schema từ Task 1.
- Produces:
  - `BuildingUtilityRateModel`: Hỗ trợ biểu giá cố định và bậc thang EVN/nước sạch.
  - `MeterReadingSubmissionModel`: Bổ sung `previousElectricReading`, `previousWaterReading`, `electricConsumed`, `waterConsumed`, `invoiceId`.

- [x] **Step 1: Viết test cho models mới và serialization**
- [x] **Step 2: Chạy test xác nhận Red phase**
- [x] **Step 3: Tạo `building_utility_rate_model.dart` và cập nhật `meter_reading_submission_model.dart`**
- [x] **Step 4: Chạy test xác nhận Green phase**
- [x] **Step 5: Commit vào `main`**

---

### Task 3: Tầng Dịch Vụ, Repository & Providers Động Cơ Tính Tiền Điện Nước

**Files:**
- Modify: `lib/data/repositories/meter_reading_repository.dart`
- Modify: `lib/data/providers/meter_reading_provider.dart`
- Test: `test/data/repositories/utility_billing_repository_test.dart`

**Interfaces:**
- Consumes: Models từ Task 2.
- Produces:
  - `MeterReadingRepository.getUtilityRates()`
  - `MeterReadingRepository.batchRecordReadings(period, readings)`
  - `MeterReadingRepository.approveReading(submissionId, generateInvoice, dueDate)`

- [x] **Step 1: Viết test cho Repository các hàm lấy biểu giá và chốt số hàng loạt**
- [x] **Step 2: Chạy test xác nhận Red phase**
- [x] **Step 3: Cập nhật Repository và Providers**
- [x] **Step 4: Chạy test xác nhận Green phase**
- [x] **Step 5: Commit vào `main`**

---

### Task 4: Nâng Cấp Bàn Quản Lý: Trạm Chốt Số Nhanh & Duyệt Phát Hành Hóa Đơn

**Files:**
- Modify: `lib/features/management/screens/management_meter_reading_screen.dart`
- Test: `test/features/management/management_meter_reading_billing_ui_test.dart`

**Interfaces:**
- Consumes: `MeterReadingRepository`, `utilityRatesProvider`.
- Produces:
  - Tab "Chốt Số Nhanh Theo Tầng": Kỹ thuật viên chọn Tầng, nhập nhanh số mới từng căn, hiển thị tiêu thụ chênh lệch và cảnh báo bất thường trực quan.
  - Hộp thoại Phê duyệt nâng cấp: Tính toán trước chi phí và tích hợp sinh hóa đơn tự động sang phân hệ kế toán.

- [x] **Step 1: Viết widget test cho Trạm Chốt Số Nhanh và Hộp thoại phê duyệt sinh hóa đơn**
- [x] **Step 2: Chạy test xác nhận Red phase**
- [x] **Step 3: Cập nhật `ManagementMeterReadingScreen`**
- [x] **Step 4: Chạy test xác nhận Green phase**
- [x] **Step 5: Commit vào `main`**

---

### Task 5: Toàn Diện Kiểm Thử, Static Analysis & Hoàn Tất Module

**Files:**
- Toàn bộ test suite liên quan đến tiện ích, chỉ số điện nước và hóa đơn.

- [x] **Step 1: Chạy toàn bộ test suite của phân hệ điện nước & hóa đơn**
- [x] **Step 2: Chạy `dart analyze lib test` đảm bảo 0 issues**
- [x] **Step 3: Chạy `graphify update .`**
- [x] **Step 4: Commit hoàn tất module lên `main`**

