# Kế Hoạch Triển Khai: Khắc Phục Toàn Bộ Lỗi P1 Giao Diện UI, Mock Data, Xử Lý Lỗi và Quản Lý Trạng Thái

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khắc phục triệt để toàn bộ 10 lỗi P1 và dữ liệu giả trong UI & State Management: thay thế mock data trong Resident360DetailSheet bằng truy vấn thật, xóa bỏ link ảnh Unsplash giả và fallback giả trong ResidentMeterReadingScreen, hiển thị đúng badge trạng thái giao dịch, ghi bản ghi payment_transactions khi BQL xác nhận thu tiền mặt, không nuốt lỗi bulk validation, hợp nhất xử lý lỗi, lọc đúng kỳ tháng cho financialStatsProvider, chặn tài khoản bị khóa trong AuthNotifier và khắc phục các widget vỡ Dark mode.

**Architecture:** Sử dụng kiến trúc Feature-first và Riverpod providers để nạp dữ liệu thật từ Supabase, chuẩn hóa tầng Repository để rethrow lỗi và tự động ghi nhận payment transaction, gộp logic chuyển đổi lỗi sang tiếng Việt vào Single Source of Truth `formatErrorMessage` / `NetworkErrorHandler`, đồng thời cập nhật UI tokens theo `AppTheme` để tương thích hoàn hảo cả Light mode và Dark mode.

**Tech Stack:** Flutter / Dart, Riverpod 2.x, Supabase Flutter, Flutter Test.

## Global Constraints
- 100% tiếng Việt chuẩn mực trong toàn bộ giao diện và thông báo lỗi.
- Không hardcode màu sắc (`Colors.white`), ưu tiên sử dụng `AppCard` hoặc `Theme.of(context)`.
- Không nuốt lỗi (catch-and-swallow), luôn hiển thị thông điệp lỗi rõ ràng cho người dùng.
- Mã căn hộ luôn được chuẩn hóa viết hoa: `code.trim().toUpperCase()`.

---

### Task 1: Xóa Mock Data & Query Thật trong `Resident360DetailSheet`

**Files:**
- Modify: `lib/features/management/widgets/resident_360_detail_sheet.dart`
- Modify: `lib/data/providers/management_provider.dart`
- Test: `test/features/management/resident_360_detail_sheet_real_data_test.dart`

**Interfaces:**
- Consumes: `resident.apartment?.id`, `resident.id`, bảng `vehicles`, `invoices`, `amenity_bookings`.
- Produces: Provider truy vấn dữ liệu chi tiết 360 cho cư dân, render danh sách thật hoặc hiển thị empty state phù hợp.

- [ ] **Step 1: Viết failing test kiểm tra Resident360DetailSheet không còn chứa mock data Honda Vision, 1.480.000 đ, Gói Gym**
- [ ] **Step 2: Chạy test để xác nhận fail**
- [ ] **Step 3: Bổ sung providers và cập nhật Resident360DetailSheet để nạp dữ liệu thật**
- [ ] **Step 4: Chạy test để xác nhận pass**
- [ ] **Step 5: Commit**

---

### Task 2: Khắc Phục `ResidentMeterReadingScreen` (Bỏ Unsplash, Bỏ Fallback Giả, Validate & Chặn Trùng Kỳ)

**Files:**
- Modify: `lib/features/resident/screens/resident_meter_reading_screen.dart`
- Test: `test/features/resident/resident_meter_reading_validation_test.dart`

**Interfaces:**
- Consumes: `currentApartmentReadingsProvider`, `residentMeterReadingsProvider`, `validateInvoicePeriod`.
- Produces: Màn hình nhập chỉ số không có ảnh Unsplash, hiển thị lỗi yêu cầu liên kết nếu chưa có căn hộ (thay vì fallback A0110), validate kỳ phí và chặn gửi trùng kỳ.

- [ ] **Step 1: Viết failing test kiểm tra validate kỳ phí và chặn fallback dữ liệu giả khi căn hộ null**
- [ ] **Step 2: Chạy test để xác nhận fail**
- [ ] **Step 3: Cập nhật ResidentMeterReadingScreen loại bỏ Unsplash, fallback giả, bổ sung validator và check trùng kỳ**
- [ ] **Step 4: Chạy test để xác nhận pass**
- [ ] **Step 5: Commit**

---

### Task 3: Chuẩn Hóa Trạng Thái Giao Dịch & Ghi Nhận Thanh Toán Khi BQL Xác Nhận Thu

**Files:**
- Modify: `lib/features/management/screens/management_payment_transactions_screen.dart`
- Modify: `lib/features/management/screens/management_invoice_detail_screen.dart`
- Modify: `lib/data/repositories/management_repository.dart`
- Test: `test/features/management/payment_status_and_cash_transaction_test.dart`

**Interfaces:**
- Consumes: `PaymentTransactionModel.status`, bảng `payment_transactions`.
- Produces: Badge màu và nhãn đúng với từng trạng thái giao dịch (`SUCCESS`, `FAILED`, `CANCELLED`), phương thức `recordPaymentTransaction` trong `ManagementRepository` được gọi khi BQL xác nhận thu tiền mặt / chuyển khoản.

- [ ] **Step 1: Viết failing test kiểm tra badge hiển thị đúng theo status và gọi recordPaymentTransaction khi xác nhận thu**
- [ ] **Step 2: Chạy test để xác nhận fail**
- [ ] **Step 3: Cập nhật ManagementPaymentTransactionsScreen và ManagementInvoiceDetailScreen**
- [ ] **Step 4: Chạy test để xác nhận pass**
- [ ] **Step 5: Commit**

---

### Task 4: Hợp Nhất Xử Lý Lỗi, Không Nuốt Lỗi & Dẹp Bỏ Lỗi Thô

**Files:**
- Modify: `lib/data/repositories/management_repository.dart`
- Modify: `lib/core/utils/error_formatter.dart`
- Modify: `lib/core/utils/network_error_handler.dart`
- Test: `test/core/utils/unified_error_formatter_test.dart`

**Interfaces:**
- Consumes: Bất kỳ ngoại lệ kỹ thuật nào.
- Produces: `validateMonthlyBulkInvoices` ném lỗi thật khi RPC thất bại, `formatErrorMessage` tích hợp `NetworkErrorHandler` để trích xuất thông điệp tiếng Việt từ Postgres RAISE EXCEPTION và mạng.

- [ ] **Step 1: Viết failing test kiểm tra validateMonthlyBulkInvoices ném lỗi khi RPC lỗi và formatErrorMessage trích xuất đúng lỗi tiếng Việt từ Postgres**
- [ ] **Step 2: Chạy test để xác nhận fail**
- [ ] **Step 3: Cập nhật ManagementRepository và hợp nhất error formatter**
- [ ] **Step 4: Chạy test để xác nhận pass**
- [ ] **Step 5: Commit**

---

### Task 5: Tối Ưu Provider, Auth Security, Chuẩn Hóa Mã Căn Hộ & Fix Dark Mode

**Files:**
- Modify: `lib/data/providers/dashboard_providers.dart`
- Modify: `lib/data/providers/auth_provider.dart`
- Modify: `lib/data/repositories/management_repository.dart`
- Modify: Dark mode widgets (`resident_handbook_screen.dart`, `management_handbook_screen.dart`, `announcement_management_screen.dart`, `notification_card.dart`, `equipment_interruption_banner.dart`)
- Test: `test/data/providers/financial_stats_monthly_period_test.dart`
- Test: `test/data/providers/auth_locked_user_test.dart`

**Interfaces:**
- Consumes: `financialStatsProvider`, `AuthNotifier`, `createApartment`.
- Produces: `financialStatsProvider` tính tiền theo kỳ hiện tại, `AuthNotifier` hủy subscription khi dispose và khóa đăng nhập nếu `isLocked == true`, mã căn hộ tự động viết hoa, các widget hiển thị tốt trên Dark mode.

- [ ] **Step 1: Viết failing test kiểm tra financialStatsProvider tính theo kỳ tháng và AuthNotifier chặn user isLocked**
- [ ] **Step 2: Chạy test để xác nhận fail**
- [ ] **Step 3: Cập nhật dashboard_providers, auth_provider, createApartment và sửa Colors.white trong các widget**
- [ ] **Step 4: Chạy test để xác nhận pass**
- [ ] **Step 5: Commit**

---

### Task 6: Kiểm Tra Tích Hợp Toàn Bộ & Xác Minh Static Analysis

**Files:**
- Toàn bộ codebase.

- [ ] **Step 1: Chạy toàn bộ các test vừa viết**
- [ ] **Step 2: Chạy toàn bộ test suite hệ thống (`flutter test`)**
- [ ] **Step 3: Chạy `flutter analyze` để đảm bảo 0 issues**
- [ ] **Step 4: Commit và hoàn tất Giai đoạn 2**
