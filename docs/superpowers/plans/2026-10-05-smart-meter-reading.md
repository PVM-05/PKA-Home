# Kế Hoạch Triển Khai: Khai Báo & Phê Duyệt Chỉ Số Điện Nước Thông Minh (Smart Meter Reading)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng tính năng Cư dân chụp ảnh công tơ điện nước kèm công nghệ nhận diện mô phỏng thông minh (Smart OCR Demo) tự động điền số liệu gửi cho Ban Quản Lý phê duyệt, hỗ trợ BQL đối soát ảnh thực tế và tùy chọn tạo ngay hóa đơn tháng.

**Architecture:** Áp dụng mô hình Feature-first, Repository pattern kết hợp Riverpod. Backend Supabase PostgreSQL cung cấp bảng `meter_reading_submissions` cùng các hàm RPC nguyên tử `approve_meter_reading` và `reject_meter_reading`. Tầng tiện ích cung cấp `MeterOcrSimulator` mô phỏng độ trễ phân tích quang học và trích xuất số liệu. UI tuân thủ hệ thống Design System 100% tiếng Việt chuẩn mực, mã căn hộ `A0110` / `B0110`.

**Tech Stack:** Flutter 3.x, Flutter Riverpod, Supabase (PostgreSQL RPC, RLS, Storage), intl, image_picker.

## Global Constraints

- 100% tiếng Việt chuẩn mực trên toàn bộ giao diện, nhãn dán, nút bấm, thông báo.
- Tuyệt đối không dùng Emoji trên UI — sử dụng Material Icons (`Icons.*`).
- Định dạng mã căn hộ chuẩn: `A0110` / `B0110` (Block + Tầng 2 chữ số + Phòng 2 chữ số).
- Màu sắc và typography tuân thủ `core/theme/app_theme.dart`.
- Mọi tác vụ phải có test kiểm thử tương ứng, 0 lỗi `dart analyze` và 100% pass `flutter test`.

---

### Task 1: Database Migration & RPCs (`meter_reading_submissions`, `approve_meter_reading`, `reject_meter_reading`)

**Files:**
- Create: `supabase/migrations/20261005_05_meter_reading_submissions.sql`
- Create: `test/data/repositories/meter_reading_migration_test.dart`

**Interfaces:**
- Produces:
  - Bảng `public.meter_reading_submissions` (id, apartment_id, submitted_by, period, electric_reading, water_reading, electric_image_url, water_image_url, status, reject_reason, reviewed_by, reviewed_at, created_at, updated_at).
  - RLS policies cho cư dân và BQL.
  - RPC `approve_meter_reading(p_submission_id, p_generate_invoice, p_due_date, p_mgmt_rate, p_electric_rate, p_water_rate)`.
  - RPC `reject_meter_reading(p_submission_id, p_reason)`.

- [ ] **Step 1: Viết test kiểm tra migration SQL và logic RPC**
- [ ] **Step 2: Viết migration file `20261005_05_meter_reading_submissions.sql`**
- [ ] **Step 3: Chạy test xác nhận PASS**
- [ ] **Step 4: Commit vào git**

```bash
git add supabase/migrations/20261005_05_meter_reading_submissions.sql test/data/repositories/meter_reading_migration_test.dart
git commit -m "feat(db): migration bang meter_reading_submissions va cac rpc duyet chi so"
```

---

### Task 2: Data Model & Smart OCR Simulator

**Files:**
- Create: `lib/data/models/meter_reading_submission_model.dart`
- Create: `lib/core/utils/meter_ocr_simulator.dart`
- Create: `test/data/models/meter_reading_submission_model_test.dart`
- Create: `test/core/utils/meter_ocr_simulator_test.dart`

**Interfaces:**
- Produces:
  - `MeterReadingSubmissionModel` (id, apartmentId, apartmentCode, submittedBy, submitterName, period, electricReading, waterReading, electricImageUrl, waterImageUrl, status, rejectReason, createdAt, reviewedAt).
  - Getters: `isPending`, `isApproved`, `isRejected`, `statusDisplayName`.
  - `MeterOcrSimulator.scanMeterImage({required File or path, required String meterType, double currentReading = 0})`: Mô phỏng quét 1200ms và trả về số liệu mới logic.

- [ ] **Step 1: Viết unit tests cho `MeterReadingSubmissionModel` và `MeterOcrSimulator`**
- [ ] **Step 2: Triển khai `MeterReadingSubmissionModel`**
- [ ] **Step 3: Triển khai `MeterOcrSimulator`**
- [ ] **Step 4: Chạy test xác nhận PASS**
- [ ] **Step 5: Commit vào git**

```bash
git add lib/data/models/meter_reading_submission_model.dart lib/core/utils/meter_ocr_simulator.dart test/data/models/ test/core/utils/
git commit -m "feat(meter): them MeterReadingSubmissionModel va tien ich MeterOcrSimulator"
```

---

### Task 3: Repository & Provider Layer

**Files:**
- Create: `lib/data/repositories/meter_reading_repository.dart`
- Create: `lib/data/providers/meter_reading_provider.dart`
- Create: `test/data/repositories/meter_reading_repository_test.dart`

**Interfaces:**
- Produces:
  - `MeterReadingRepository.submitReading(...)`
  - `MeterReadingRepository.getMySubmissions(String apartmentId)`
  - `MeterReadingRepository.getAllSubmissions({String? status})`
  - `MeterReadingRepository.approveReading(...)`
  - `MeterReadingRepository.rejectReading(...)`
  - Providers: `meterReadingRepositoryProvider`, `apartmentMeterReadingsProvider`, `allMeterReadingsProvider`, `pendingMeterReadingsCountProvider`.

- [ ] **Step 1: Viết unit test cho `MeterReadingRepository`**
- [ ] **Step 2: Triển khai `MeterReadingRepository` và `meter_reading_provider.dart`**
- [ ] **Step 3: Chạy test xác nhận PASS**
- [ ] **Step 4: Commit vào git**

```bash
git add lib/data/repositories/meter_reading_repository.dart lib/data/providers/meter_reading_provider.dart test/data/repositories/meter_reading_repository_test.dart
git commit -m "feat(meter): trien khai repository va providers cho khai bao chi so dien nuoc"
```

---

### Task 4: Màn Hình Cư Dân: Khai Báo Chỉ Số Điện Nước & Quét Ảnh OCR

**Files:**
- Create: `lib/features/resident/screens/resident_meter_reading_screen.dart`
- Modify: `lib/core/router/route_names.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/resident/screens/resident_home_screen.dart` (thêm nút tắt / thẻ nhanh "Gửi chỉ số điện nước")
- Create: `test/features/resident/resident_meter_reading_screen_test.dart`

**Interfaces:**
- Hiển thị chỉ số cũ của căn hộ.
- Chọn/Chụp ảnh công tơ điện $\rightarrow$ Animation quét OCR $\rightarrow$ Tự động điền $kWh$.
- Chọn/Chụp ảnh công tơ nước $\rightarrow$ Animation quét OCR $\rightarrow$ Tự động điền $m^3$.
- Bấm [ Gửi chỉ số ] lưu vào cơ sở dữ liệu.
- Tab / Danh sách lịch sử các lần gửi và trạng thái xét duyệt.

- [ ] **Step 1: Viết widget test cho `ResidentMeterReadingScreen`**
- [ ] **Step 2: Triển khai màn hình và đăng ký route `AppRoutes.residentMeterReading`**
- [ ] **Step 3: Thêm nút liên kết trên `ResidentHomeScreen`**
- [ ] **Step 4: Chạy test xác nhận PASS**
- [ ] **Step 5: Commit vào git**

```bash
git add lib/features/resident/screens/resident_meter_reading_screen.dart lib/core/router/ lib/features/resident/screens/resident_home_screen.dart test/features/resident/resident_meter_reading_screen_test.dart
git commit -m "feat(resident): them man hinh gui chi so dien nuoc kem smart ocr cho cu dan"
```

---

### Task 5: Màn Hình Ban Quản Lý: Phê Duyệt Chỉ Số & Tạo Hóa Đơn Tức Thì

**Files:**
- Create: `lib/features/management/screens/management_meter_reading_screen.dart`
- Modify: `lib/core/router/route_names.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/management/screens/management_home_screen.dart` (thêm quick action "Duyệt chỉ số")
- Create: `test/features/management/management_meter_reading_screen_test.dart`

**Interfaces:**
- Tabs: Chờ duyệt, Đã duyệt, Đã từ chối.
- Thẻ yêu cầu: Căn hộ `A0110`, Người gửi, So sánh chỉ số cũ vs mới, Tiêu thụ tạm tính.
- Nút phóng to ảnh công tơ đối chiếu.
- Thao tác:
  - Bấm [ Từ chối ] $\rightarrow$ Dialog nhập lý do $\rightarrow$ Gọi `rejectReading`.
  - Bấm [ Phê duyệt ] $\rightarrow$ Dialog xác nhận kèm Checkbox "Tự động tạo hóa đơn tháng cho căn hộ này" $\rightarrow$ Gọi `approveReading`.

- [ ] **Step 1: Viết widget test cho `ManagementMeterReadingScreen`**
- [ ] **Step 2: Triển khai màn hình và đăng ký route `AppRoutes.managementMeterReading`**
- [ ] **Step 3: Thêm nút truy cập từ `ManagementHomeScreen`**
- [ ] **Step 4: Chạy test xác nhận PASS**
- [ ] **Step 5: Commit vào git**

```bash
git add lib/features/management/screens/management_meter_reading_screen.dart lib/core/router/ lib/features/management/screens/management_home_screen.dart test/features/management/management_meter_reading_screen_test.dart
git commit -m "feat(management): them man hinh duyet chi so cong to va tao hoa don tuc thi cho bql"
```

---

### Task 6: Rà Soát Toàn Diện, Static Analysis & Nghiệm Thu

**Files:**
- Toàn bộ codebase liên quan

- [ ] **Step 1: Chạy `dart analyze` toàn dự án đảm bảo 0 lỗi/cảnh báo**
- [ ] **Step 2: Chạy toàn bộ test suite `flutter test` đảm bảo 100% test cases pass**
- [ ] **Step 3: Cập nhật checklist hoàn tất trong tài liệu kế hoạch**
- [ ] **Step 4: Commit và tổng kết kịch bản demo cho người dùng**

```bash
git add docs/superpowers/plans/2026-10-05-smart-meter-reading.md
git commit -m "docs: hoan tat ke hoach khai bao va phe duyet chi so dien nuoc"
```
