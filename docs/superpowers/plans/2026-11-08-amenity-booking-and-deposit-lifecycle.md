# Kế Hoạch Triển Khai: Module Đặt & Quản Lý Tiện Ích Nội Khu Khép Kín (Amenity Booking & Deposit Lifecycle)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng giải pháp trọn gói thương mại B2B SaaS cho phân hệ Đặt & Quản lý tiện ích (Hồ bơi, Sân BBQ, Phòng Gym): Cư dân đặt lịch $\rightarrow$ Thanh toán VietQR cọc & phí $\rightarrow$ Vé điện tử QR check-in $\rightarrow$ Nghiệm thu hiện trường $\rightarrow$ Tự động hoàn cọc/khấu trừ cọc.

**Architecture:** Mở rộng CSDL PostgreSQL với RLS và ACID RPCs (`book_amenity_slot`, `check_in_amenity_ticket`, `inspect_and_settle_amenity_deposit`); Model Strongly-Typed kết nối Riverpod Reactive State; UI Cư dân (`AmenityBookingScreen`) tích hợp Vé QR; UI Ban Quản Lý (`AmenityManagementScreen`) tích hợp Trạm Nghiệm thu Cọc & Quét vé.

**Tech Stack:** Flutter ^3.12+, Flutter Riverpod ^2.6.1, Supabase PostgreSQL, `qr_flutter` ^4.1.0, GoRouter ^14.8.1.

## Global Constraints
- Commit trực tiếp trên nhánh `main`, không tạo branch/worktree phụ.
- 100% tiếng Việt chuẩn mực trong UI, không dùng Emoji, sử dụng Material Icons (`Icons.*`).
- Bám sát Test-Driven Development (TDD): Viết test trước, kiểm tra Red phase, hoàn thiện code Green phase.
- Static Analysis: `dart analyze lib test` đạt 0 issues.

---

### Task 1: CSDL Migration & ACID RPCs Nghiệm Thu Cọc & Vé Check-in

**Files:**
- Create: `supabase/migrations/20261108020000_amenity_lifecycle_and_deposit.sql`
- Test: `test/database/amenity_lifecycle_migration_test.dart`

**Interfaces:**
- Produces:
  - Bảng `building_amenities` mở rộng: `max_advance_days`, `max_slots_per_week`, `rules_and_regulations`.
  - Bảng `amenity_bookings` mở rộng: `qr_ticket_token`, `checked_in_by`, `inspected_by`, `inspected_at`, `inspection_result`, `forfeited_amount`, `refund_amount`, `inspection_notes`, `inspection_image_urls`.
  - RPC: `book_amenity_slot(...)`, `check_in_amenity_ticket(p_token UUID)`, `inspect_and_settle_amenity_deposit(p_booking_id UUID, p_result TEXT, p_forfeited_amount NUMERIC, p_notes TEXT, p_image_urls JSONB)`.

- [x] **Step 1: Viết failing test cho Migration SQL**
- [x] **Step 2: Chạy test xác nhận Red phase**
- [x] **Step 3: Tạo file migration `20261108020000_amenity_lifecycle_and_deposit.sql` với đầy đủ schema & 3 RPCs**
- [x] **Step 4: Chạy lại test xác nhận Green phase**
- [x] **Step 5: Commit vào `main`**

---

### Task 2: Data Models Strongly-Typed cho Tiện Ích & Vòng Đời Cọc

**Files:**
- Modify: `lib/data/models/building_amenity_model.dart`
- Modify: `lib/data/models/amenity_booking_model.dart`
- Create: `lib/data/models/amenity_inspection_model.dart`
- Test: `test/data/models/amenity_lifecycle_models_test.dart`

**Interfaces:**
- Consumes: CSDL schema từ Task 1.
- Produces:
  - `BuildingAmenityModel`: `maxAdvanceDays`, `maxSlotsPerWeek`, `rulesAndRegulations`.
  - `AmenityBookingModel`: `qrTicketToken`, `isCheckedIn`, `inspectionResult`, `refundAmount`, `forfeitedAmount`, `inspectionNotes`, `inspectionImageUrls`.
  - `AmenityInspectionModel`: DTO phục vụ gửi kết quả nghiệm thu cọc.

- [x] **Step 1: Viết test cho các trường mới và serialization**
- [x] **Step 2: Chạy test xác nhận Red phase**
- [x] **Step 3: Cập nhật `building_amenity_model.dart`, `amenity_booking_model.dart` và tạo `amenity_inspection_model.dart`**
- [x] **Step 4: Chạy test xác nhận Green phase**
- [x] **Step 5: Commit vào `main`**

---

### Task 3: Tầng Dịch Vụ, Repository & Providers Nghiệm Thu Cọc

**Files:**
- Modify: `lib/data/repositories/amenity_booking_repository.dart`
- Modify: `lib/data/providers/amenity_booking_provider.dart`
- Test: `test/data/repositories/amenity_booking_repository_lifecycle_test.dart`

**Interfaces:**
- Consumes: Models từ Task 2.
- Produces:
  - `AmenityBookingRepository.checkInTicket(String qrTicketToken)`
  - `AmenityBookingRepository.inspectAndSettleDeposit(...)`
  - `pendingInspectionsProvider`: Lấy danh sách ca cần nghiệm thu mặt bằng / xử lý cọc.

- [x] **Step 1: Viết test cho Repository các hàm check-in và nghiệm thu cọc**
- [x] **Step 2: Chạy test xác nhận Red phase**
- [x] **Step 3: Cập nhật Repository và Providers**
- [x] **Step 4: Chạy test xác nhận Green phase**
- [x] **Step 5: Commit vào `main`**

---

### Task 4: Trải Nghiệm Cư Dân - Đặt Chỗ Thông Minh & Vé Điện Tử QR Check-in

**Files:**
- Modify: `lib/features/resident/screens/amenity_booking_screen.dart`
- Test: `test/features/resident/amenity_booking_qr_ticket_ui_test.dart`

**Interfaces:**
- Consumes: `AmenityBookingModel` với `qrTicketToken`, `UnifiedPaymentSheet`.
- Produces:
  - Hiển thị quota đặt ca tuần của căn hộ.
  - Phân màu lưới ca trực quan (Còn trống / Sắp đầy / Đã kín / Bảo trì).
  - Thẻ Vé Điện Tử QR Code tại tab "Lịch của tôi" để cư dân xuất trình tại cổng.

- [x] **Step 1: Viết widget test cho hiển thị vé QR và phân màu lưới ca**
- [x] **Step 2: Chạy test xác nhận Red phase**
- [x] **Step 3: Cập nhật `AmenityBookingScreen`**
- [x] **Step 4: Chạy test xác nhận Green phase**
- [x] **Step 5: Commit vào `main`**

---

### Task 5: Bàn Quản Lý - Quét Vé Check-in & Trạm Nghiệm Thu Hoàn Cọc

**Files:**
- Modify: `lib/features/management/screens/amenity_management_screen.dart`
- Test: `test/features/management/amenity_management_inspection_ui_test.dart`

**Interfaces:**
- Consumes: `pendingInspectionsProvider`, `checkInTicket`, `inspectAndSettleDeposit`.
- Produces:
  - Tab "Lịch Đặt & Quét Check-in": Hộp thoại quét/nhập mã vé QR.
  - Tab "Nghiệm Thu & Quản Lý Cọc": Hộp thoại nghiệm thu bàn giao mặt bằng có ảnh chụp, hoàn cọc 100% hoặc khấu trừ đền bù.

- [x] **Step 1: Viết widget test cho hộp thoại check-in và nghiệm thu cọc**
- [x] **Step 2: Chạy test xác nhận Red phase**
- [x] **Step 3: Cập nhật `AmenityManagementScreen`**
- [x] **Step 4: Chạy test xác nhận Green phase**
- [x] **Step 5: Commit vào `main`**

---

### Task 6: Toàn Diện Kiểm Thử, Static Analysis & Hoàn Tất Module

**Files:**
- Test toàn bộ các file liên quan đến tiện ích và thanh toán.

- [x] **Step 1: Chạy toàn bộ test suite của module Amenity**
- [x] **Step 2: Chạy `dart analyze lib test` đảm bảo 0 issues**
- [x] **Step 3: Chạy `graphify update .`**
- [x] **Step 4: Commit hoàn tất module lên `main`**
