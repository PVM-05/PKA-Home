# Kế Hoạch Thực Thi: Giai Đoạn A3 & A4 - Biểu Phí Động, Quỹ Bảo Trì Thật & Chuẩn Hóa Bảo Mật Nền

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chuyển đổi toàn bộ tiền tệ sang biểu phí động theo thời gian, nối dữ liệu thật cho Quỹ bảo trì, xóa bỏ fallback căn hộ ảo trong provider và cấu hình release signing an toàn cho Android.

**Architecture:**
- Database: Tạo migration `20261027_02_dynamic_fees_and_maintenance_fund.sql` seed dữ liệu `fee_schedules`, tạo bảng `maintenance_funds` có RLS và hàm helper `get_effective_fee_schedule`.
- Flutter Data Layer: Thêm `FeeScheduleModel`, `FeeScheduleRepository`, `feeScheduleProvider`, `MaintenanceFundModel`, `maintenanceFundProvider`.
- Flutter UI Layer: `bulk_invoice_dialog.dart` & `create_invoice_screen.dart` nạp biểu phí động từ provider; `MaintenanceFundCard` xóa toàn bộ hằng số 2,45 tỷ giả và đọc từ `maintenanceFundProvider`.
- Provider Sanitization: Xóa fallback ảo `'A0110'` (1250 kWh, 80 m³) trong `meter_reading_provider.dart`.
- Android Security: Cấu hình `android/app/build.gradle.kts` nạp `key.properties` cho release build và cập nhật `.gitignore`.

**Tech Stack:** Flutter, Dart, Riverpod, PostgreSQL 15+, Supabase, Gradle (Kotlin DSL).

## Global Constraints

- Biểu phí và Quỹ bảo trì tuân thủ 100% tiếng Việt chuẩn theo `design-rules.md`.
- RLS được bật cho bảng mới `maintenance_funds`.
- Commit trực tiếp trên nhánh `main` theo quy định `AGENTS.md`.

---

### Task 1: Database Migration - Seed `fee_schedules`, Tạo Bảng `maintenance_funds` & RPC Tra Cứu

**Files:**
- Create: `supabase/migrations/20261027_02_dynamic_fees_and_maintenance_fund.sql`
- Test: `test/integration/dynamic_fees_and_maintenance_fund_migration_test.dart`

**Interfaces:**
- Consumes: Bảng `fee_schedules` đã có trong baseline.
- Produces: 
  - 5 bản ghi seed trong `fee_schedules`: `electricity` (3500), `water` (18000), `management` (16500), `parking_motorcycle` (100000), `parking_car` (1200000).
  - Bảng `maintenance_funds` với RLS và 1 bản ghi mở đầu.
  - Hàm `public.get_effective_fee_schedule(p_fee_type TEXT, p_date DATE)`.

- [ ] **Step 1: Viết test kiểm tra migration mới**
Tạo file `test/integration/dynamic_fees_and_maintenance_fund_migration_test.dart` kiểm tra sự tồn tại của migration, nội dung seed, bảng `maintenance_funds` và hàm `get_effective_fee_schedule`.

- [ ] **Step 2: Chạy test để xác nhận FAIL (TDD)**
Chạy: `flutter test test/integration/dynamic_fees_and_maintenance_fund_migration_test.dart`

- [ ] **Step 3: Viết migration `20261027_02_dynamic_fees_and_maintenance_fund.sql`**
Tạo file migration bổ sung seed biểu phí, bảng `maintenance_funds`, RLS policy và hàm `get_effective_fee_schedule`.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Chạy: `flutter test test/integration/dynamic_fees_and_maintenance_fund_migration_test.dart`

- [ ] **Step 5: Commit migration**
```bash
git add supabase/migrations/20261027_02_dynamic_fees_and_maintenance_fund.sql test/integration/dynamic_fees_and_maintenance_fund_migration_test.dart
git commit -m "feat(db): them migration bieu phi dong va bang quy bao tri maintenance_funds"
```

---

### Task 2: FeeScheduleRepository & feeScheduleProvider Phía Flutter

**Files:**
- Create: `lib/data/models/fee_schedule_model.dart`
- Create: `lib/data/repositories/fee_schedule_repository.dart`
- Create: `lib/data/providers/fee_schedule_provider.dart`
- Modify: `lib/features/management/widgets/bulk_invoice_dialog.dart`
- Modify: `lib/features/management/screens/create_invoice_screen.dart`
- Test: `test/data/repositories/fee_schedule_repository_test.dart`

**Interfaces:**
- Consumes: Bảng `fee_schedules` từ Supabase.
- Produces: `feeScheduleProvider` cung cấp danh sách biểu phí và hàm lấy đơn giá theo loại phí.

- [ ] **Step 1: Viết test đơn vị cho FeeScheduleRepository**
Tạo file `test/data/repositories/fee_schedule_repository_test.dart`.

- [ ] **Step 2: Tạo model, repository và provider cho FeeSchedule**
Tạo `fee_schedule_model.dart`, `fee_schedule_repository.dart`, `fee_schedule_provider.dart`.

- [ ] **Step 3: Cập nhật `bulk_invoice_dialog.dart` và `create_invoice_screen.dart`**
Nạp đơn giá mặc định từ `feeScheduleProvider` khi mở dialog/màn hình thay vì hardcode chuỗi '3500' và '18000'.

- [ ] **Step 4: Chạy test xác nhận PASS**
Chạy: `flutter test test/data/repositories/fee_schedule_repository_test.dart`

- [ ] **Step 5: Commit FeeSchedule**
```bash
git add lib/data/models/fee_schedule_model.dart lib/data/repositories/fee_schedule_repository.dart lib/data/providers/fee_schedule_provider.dart lib/features/management/widgets/bulk_invoice_dialog.dart lib/features/management/screens/create_invoice_screen.dart test/data/repositories/fee_schedule_repository_test.dart
git commit -m "feat(finance): tich hop bieu phi dong tu database vao giao dien lap hoa don"
```

---

### Task 3: MaintenanceFundModel & Nối Dữ Liệu Thật cho MaintenanceFundCard

**Files:**
- Create: `lib/data/models/maintenance_fund_model.dart`
- Create: `lib/data/providers/maintenance_fund_provider.dart`
- Modify: `lib/core/widgets/maintenance_fund_card.dart`
- Modify: `test/core/widgets/maintenance_fund_card_test.dart`

**Interfaces:**
- Consumes: Bảng `maintenance_funds`.
- Produces: `MaintenanceFundCard` hiển thị số dư thực tế từ `maintenanceFundProvider`, không còn các hằng số 2,45 tỷ hardcode.

- [ ] **Step 1: Cập nhật test `maintenance_fund_card_test.dart`**
Thêm kịch bản test widget `MaintenanceFundCard` hiển thị số dư từ provider.

- [ ] **Step 2: Tạo `MaintenanceFundModel` và `maintenanceFundProvider`**
Tạo model và provider đọc từ bảng `maintenance_funds`.

- [ ] **Step 3: Chuyển đổi `MaintenanceFundCard` sang đọc dữ liệu thật từ Provider**
Xóa bỏ các biến `static const double _totalFundBalance = 2450000000.0;`...
Đọc từ `ref.watch(maintenanceFundProvider)` và hiển thị đúng thông tin ngân hàng, số dư, tỷ lệ đã thu.

- [ ] **Step 4: Chạy test xác nhận PASS**
Chạy: `flutter test test/core/widgets/maintenance_fund_card_test.dart`

- [ ] **Step 5: Commit MaintenanceFund**
```bash
git add lib/data/models/maintenance_fund_model.dart lib/data/providers/maintenance_fund_provider.dart lib/core/widgets/maintenance_fund_card.dart test/core/widgets/maintenance_fund_card_test.dart
git commit -m "feat(fund): noi du lieu quy bao tri that tu database vao MaintenanceFundCard"
```

---

### Task 4: Gỡ Bỏ Fallback Căn Hộ Giả trong MeterReadingProvider

**Files:**
- Modify: `lib/data/providers/meter_reading_provider.dart:50-58`
- Test: `test/data/providers/meter_reading_provider_test.dart`

**Interfaces:**
- Consumes: `meterReadingApartmentProvider`.
- Produces: Trả về `null` khi không tìm thấy hoặc lỗi, không tự ý trả về dữ liệu ảo `'A0110'`.

- [ ] **Step 1: Viết test cho `meterReadingApartmentProvider`**
Tạo file `test/data/providers/meter_reading_provider_test.dart` xác minh khi lỗi hoặc không tìm thấy căn hộ, provider trả về `null` thay vì mock data `A0110`.

- [ ] **Step 2: Sửa `meter_reading_provider.dart`**
Xóa khối catch trả về `'A0110'` giả.

- [ ] **Step 3: Chạy test xác nhận PASS**
Chạy: `flutter test test/data/providers/meter_reading_provider_test.dart`

- [ ] **Step 4: Commit gỡ bỏ mock data**
```bash
git add lib/data/providers/meter_reading_provider.dart test/data/providers/meter_reading_provider_test.dart
git commit -m "fix(meter): loai bo du lieu fallback can ho gia A0110 trong provider"
```

---

### Task 5: Cấu Hình Android Release Signing & Bảo Mật Kho Khóa

**Files:**
- Modify: `android/app/build.gradle.kts:30-36`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: File `key.properties` (nếu có trên máy build release).
- Produces: Cấu hình release signing an toàn, chống leak key lên git.

- [ ] **Step 1: Cập nhật `.gitignore`**
Thêm `key.properties`, `*.keystore`, `*.jks` vào `.gitignore`.

- [ ] **Step 2: Cập nhật `android/app/build.gradle.kts`**
Cấu hình nạp `key.properties` nếu tồn tại cho build release, fallback debug có logging rõ ràng.

- [ ] **Step 3: Commit cấu hình bảo mật Android**
```bash
git add android/app/build.gradle.kts .gitignore
git commit -m "sec(android): cau hinh release signing an toan qua key.properties"
```

---

### Task 6: Rà Soát Toàn Diện & Verification

**Files:**
- Toàn bộ codebase

- [ ] **Step 1: Chạy `flutter analyze`**
Đảm bảo 0 errors, 0 warnings.

- [ ] **Step 2: Chạy toàn bộ test suite `flutter test`**
Đảm bảo 100% tests PASS.

- [ ] **Step 3: Commit hoàn thành Giai đoạn A3 & A4**
```bash
git commit --allow-empty -m "chore: hoan thanh xac minh giai doan A3 & A4 bieu phi dong va bao mat nen"
```
