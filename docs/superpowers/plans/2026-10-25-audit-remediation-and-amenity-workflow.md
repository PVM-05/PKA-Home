# Kế Hoạch Triển Khai: Khắc Phục 21 Điểm Rà Soát Hệ Thống & Nâng Cấp Đặt Lịch Tiện Ích (Phương Án 1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khắc phục triệt để các lỗ hổng leo thang đặc quyền, chuẩn hóa chữ ký RPC thanh toán, đồng bộ key JSON giữa Flutter và CSDL, dọn dẹp storage bucket, giải quyết dứt điểm lỗi Cư dân không hủy được lịch tiện ích, và nâng cấp giao diện Admin Quản trị tiện ích thành 3 Tab toàn diện (Duyệt lịch chuẩn A7/A8 + Cấu hình sức chứa động + Lịch bảo trì).

**Architecture:** Kiến trúc Feature-first Flutter + Supabase PostgreSQL. Mọi thay đổi CSDL dùng migration lũy thừa (`SECURITY DEFINER` với `search_path = public, pg_catalog`), đồng bộ hóa các model Dart, xử lý Responsive giao diện trên màn hình 360dp và tuân thủ TDD.

**Tech Stack:** Flutter 3.x, Dart 3.x, Riverpod 2.x, Supabase Flutter / PostgreSQL, PostgREST.

## Global Constraints
- Làm việc và commit trực tiếp trên nhánh `main` với Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`).
- 100% tiếng Việt tự nhiên trên giao diện người dùng, không chèn tiếng Anh trong ngoặc đơn.
- Không để xảy ra bất kỳ lỗi RenderFlex overflow nào trên màn hình 360dp–390dp.
- Phải viết kịch bản test trước (TDD), chạy test pass và chạy `dart analyze lib test` đạt 0 lỗi, 0 cảnh báo.

---

### Task 1: Migration CSDL Khắc Phục Lỗ Hổng Bảo Mật, Đồng Bộ RPC & Khởi Tạo Sức Chứa

**Files:**
- Create: `supabase/migrations/20261025_03_audit_remediation_and_amenity_system.sql`
- Test: `test/data/migrations/audit_remediation_and_amenity_migration_test.dart`

**Interfaces:**
- Produces:
  - `public.handle_new_user()` (ép cứng role resident)
  - `public.simulate_unified_payment(p_payment_type text, p_reference_id uuid, p_payment_method text, p_outcome text, p_failure_reason text, p_type text)`
  - `public.cancel_amenity_booking(p_booking_id uuid)`
  - `public.get_amenity_slot_availability(p_amenity_id uuid, p_date date)`
  - `public.reschedule_amenity_booking` (sửa `booking_id = p_booking_id` kiểu UUID)
  - `public.validate_monthly_bulk_invoices` (trả thêm `'estimated_total'`)
  - `public.generate_valid_bulk_invoices` (trả thêm `'invoices_created'` và `'total_amount'`)
  - Sức chứa cập nhật cho `building_amenities` (Gym 20, Bể bơi 30, BBQ 15, Tennis 4, v.v.)
  - `UPDATE storage.buckets SET public = false WHERE id = 'issue-images'`

- [ ] **Step 1: Viết test kiểm tra migration SQL**

Tạo file `test/data/migrations/audit_remediation_and_amenity_migration_test.dart`:
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Migration 20261025_03 phải chứa các định nghĩa vá bảo mật và RPC tiện ích', () {
    final file = File('supabase/migrations/20261025_03_audit_remediation_and_amenity_system.sql');
    expect(file.existsSync(), isTrue);

    final content = file.readAsStringSync();
    expect(content.contains("'resident'::public.user_role"), isTrue);
    expect(content.contains('cancel_amenity_booking'), isTrue);
    expect(content.contains('simulate_unified_payment'), isTrue);
    expect(content.contains('get_amenity_slot_availability'), isTrue);
    expect(content.contains('booking_id = p_booking_id'), isTrue);
    expect(content.contains('estimated_total'), isTrue);
    expect(content.contains('invoices_created'), isTrue);
  });
}
```

- [ ] **Step 2: Chạy test để đảm bảo test thất bại (do chưa có file migration)**

Run: `flutter test test/data/migrations/audit_remediation_and_amenity_migration_test.dart`
Expected: FAIL

- [ ] **Step 3: Viết file migration SQL `20261025_03_audit_remediation_and_amenity_system.sql`**

Nội dung bao gồm:
1. Vá `handle_new_user()` chống leo thang đặc quyền.
2. Siết `admin_create_user` và `admin_update_user_profile` chỉ cho phép `is_admin()`.
3. Chuẩn hóa `simulate_unified_payment` với 6 tham số (hỗ trợ alias `p_type`).
4. RPC `cancel_amenity_booking` tự động hủy transaction PENDING và đôn waitlist.
5. Sửa `reschedule_amenity_booking` bỏ so sánh UUID với text và dùng `start_time`/`end_time`.
6. Sửa `validate_monthly_bulk_invoices` trả `estimated_total` và `generate_valid_bulk_invoices` trả `invoices_created`.
7. Cài đặt RPC `get_amenity_slot_availability` ẩn danh PII.
8. Cập nhật sức chứa và booking_type của `building_amenities` sang giá trị thực tế hợp lý.
9. Đặt bucket `issue-images` về `public = false`.

- [ ] **Step 4: Chạy test kiểm tra nội dung migration và áp dụng lên Supabase DB thực tế**

Run: `flutter test test/data/migrations/audit_remediation_and_amenity_migration_test.dart`
Expected: PASS
Chạy python script kết nối Postgres để thực thi migration và kiểm tra thành công trên cloud database.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20261025_03_audit_remediation_and_amenity_system.sql test/data/migrations/audit_remediation_and_amenity_migration_test.dart
git commit -m "fix(db): va lo hong dac quyen dong bo rpc va khoi tao suc chua tien ich"
```

---

### Task 2: Sửa Model, Key JSON và Dịch Vụ Thanh Toán (#4, #8, #9, #13, #15)

**Files:**
- Modify: `lib/data/models/bulk_invoice_validation_model.dart`
- Modify: `lib/features/management/widgets/bulk_invoice_dialog.dart`
- Modify: `lib/data/models/vehicle_model.dart`
- Modify: `lib/data/providers/dashboard_providers.dart`
- Modify: `lib/data/services/payment_service.dart`
- Modify: `lib/data/providers/resident_invoice_provider.dart`
- Test: `test/data/models/bulk_invoice_and_vehicle_model_test.dart`

**Interfaces:**
- Consumes: JSON từ các RPC đã cập nhật ở Task 1
- Produces: `BulkInvoiceValidationModel` đọc được `estimated_total`, `VehicleModel` hiển thị đúng `cancelled`, `apartmentsStreamProvider` không crash HTTP.

- [ ] **Step 1: Viết test cho Model & Provider**

Tạo `test/data/models/bulk_invoice_and_vehicle_model_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/bulk_invoice_validation_model.dart';
import 'package:pka_home/data/models/vehicle_model.dart';

void main() {
  test('ValidApartmentBillingItem đọc đúng estimated_total từ cả estimated_total và total_amount', () {
    final item1 = ValidApartmentBillingItem.fromJson({
      'apartment_id': 'apt-1',
      'apartment_code': 'A0101',
      'area': 70.0,
      'electric_usage': 100,
      'water_usage': 10,
      'total_amount': 1500000,
    });
    expect(item1.estimatedTotal, 1500000.0);

    final item2 = ValidApartmentBillingItem.fromJson({
      'apartment_id': 'apt-2',
      'apartment_code': 'A0102',
      'area': 80.0,
      'electric_usage': 120,
      'water_usage': 12,
      'estimated_total': 1800000,
    });
    expect(item2.estimatedTotal, 1800000.0);
  });

  test('VehicleModel xử lý chuẩn trạng thái cancelled', () {
    final v = VehicleModel(
      id: 'v-1',
      apartmentId: 'apt-1',
      vehicleType: 'motorbike',
      licensePlate: '29A-12345',
      status: 'cancelled',
      createdAt: DateTime.now(),
    );
    expect(v.isCancelled, isTrue);
    expect(v.statusDisplayName, 'Đã hủy');
  });
}
```

- [ ] **Step 2: Chạy test để xác minh test thất bại**

Run: `flutter test test/data/models/bulk_invoice_and_vehicle_model_test.dart`
Expected: FAIL

- [ ] **Step 3: Triển khai code sửa đổi**

1. `bulk_invoice_validation_model.dart`: Hỗ trợ cả `estimated_total` và `total_amount`.
2. `bulk_invoice_dialog.dart`: Đọc `result['invoices_created'] ?? result['created_count'] ?? 0` và `result['total_amount']`.
3. `vehicle_model.dart`: Thêm `case 'cancelled': return 'Đã hủy';` và `bool get isCancelled => status == 'cancelled';`.
4. `dashboard_providers.dart`: Sửa `apartmentsStreamProvider` select `id, code, area, is_empty, building_code, floor_number`.
5. `payment_service.dart` & `resident_invoice_provider.dart`: Gửi đồng bộ tham số `p_payment_type` và `p_type`.

- [ ] **Step 4: Chạy lại test**

Run: `flutter test test/data/models/bulk_invoice_and_vehicle_model_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/ lib/features/management/widgets/bulk_invoice_dialog.dart lib/data/providers/dashboard_providers.dart lib/data/services/payment_service.dart lib/data/providers/resident_invoice_provider.dart test/data/models/bulk_invoice_and_vehicle_model_test.dart
git commit -m "fix(model): dong bo key json hoa don xe va provider apartments"
```

---

### Task 3: Cập Nhật Repositories & Helpers (#14, #19, Hủy Lịch Tiện Ích, Cấu Hình Sức Chứa #12)

**Files:**
- Modify: `lib/data/repositories/issue_repository.dart`
- Modify: `lib/data/repositories/amenity_booking_repository.dart`
- Modify: `lib/data/repositories/handbook_repository.dart`
- Test: `test/data/repositories/amenity_and_issue_repository_test.dart`

**Interfaces:**
- `AmenityBookingRepository.cancelBooking(String bookingId)`: gọi RPC `cancel_amenity_booking`
- `AmenityBookingRepository.getBookingsByAmenityAndDate(...)`: hỗ trợ gọi `get_amenity_slot_availability`
- `HandbookRepository.updateBuildingAmenity(...)`: bổ sung `bookingType`, `maxCapacity`, `feeAmount`, `depositAmount`, `requiresDeposit`
- `IssueRepository`: chuẩn hóa `_extractStoragePath`

- [ ] **Step 1: Viết test cho Repositories**

Tạo `test/data/repositories/amenity_and_issue_repository_test.dart` kiểm tra logic trích xuất path, gọi RPC hủy lịch, và các tham số cập nhật tiện ích.

- [ ] **Step 2: Chạy test để kiểm tra thất bại**

Run: `flutter test test/data/repositories/amenity_and_issue_repository_test.dart`
Expected: FAIL

- [ ] **Step 3: Triển khai cập nhật Repositories**

1. Trong `amenity_booking_repository.dart`:
   - `cancelBooking(String bookingId)`: Gọi RPC `cancel_amenity_booking` với tham số `p_booking_id`.
   - `getBookingsByAmenityAndDate`: Sử dụng RPC `get_amenity_slot_availability` cho cư dân để hiển thị các slot đã kín của cư dân khác mà không lộ thông tin cá nhân.
2. Trong `handbook_repository.dart`:
   - Thêm các trường `bookingType`, `maxCapacity`, `feeAmount`, `depositAmount`, `requiresDeposit`, `slotDurationMinutes` vào `updateBuildingAmenity` và `createBuildingAmenity`.
3. Trong `issue_repository.dart`:
   - Viết static helper `_extractStoragePath(String urlOrPath)` trích xuất đúng object path cho cả URL đầy đủ và object path thuần, áp dụng đồng nhất trong `createIssue`, `updateIssue`, `deleteIssue`.

- [ ] **Step 4: Chạy test để kiểm tra vượt qua**

Run: `flutter test test/data/repositories/amenity_and_issue_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/ test/data/repositories/amenity_and_issue_repository_test.dart
git commit -m "feat(repo): tich hop rpc huy tien ich suc chua va chuan hoa storage path"
```

---

### Task 4: Cải Tiến Giao Diện Đặt Lịch Cư Dân (`AmenityBookingScreen`)

**Files:**
- Modify: `lib/features/resident/screens/amenity_booking_screen.dart`
- Test: `test/features/resident/amenity_booking_resident_screen_test.dart`

**Interfaces:**
- Giao diện Cư dân hỗ trợ:
  - Nút thao tác trong thẻ Lịch Đã Đặt bọc trong `Wrap` (không tràn viền, nút Hủy lịch luôn nhìn thấy và bấm được).
  - Slot đã đặt của cư dân tại Tab 1 hiển thị rõ badge "Lịch của bạn" + nút bấm mở chi tiết / hủy nhanh.
  - Sức chứa dạng `shared` hiển thị chỗ trống động và trừ đúng `guests_count`.

- [ ] **Step 1: Viết widget test cho `AmenityBookingScreen`**

Tạo `test/features/resident/amenity_booking_resident_screen_test.dart`:
Kiểm tra trên màn hình 360x640dp:
- Thẻ lịch đặt trong Tab Lịch Đã Đặt hiển thị đầy đủ nút "Hủy lịch này", bấm mở AlertDialog xác nhận.
- Tab Chọn Khung Giờ hiển thị chính xác slot của mình và chỗ trống còn lại.

- [ ] **Step 2: Chạy test để xác minh lỗi hiển thị hiện tại**

Run: `flutter test test/features/resident/amenity_booking_resident_screen_test.dart`
Expected: FAIL

- [ ] **Step 3: Cải tạo giao diện `AmenityBookingScreen`**

1. Thay `Row(mainAxisAlignment: MainAxisAlignment.end)` ở dòng 885 bằng `Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end)`.
2. Trong `_buildBookingTab`:
   - Kiểm tra `existingBookings.any((b) => b.timeSlot == slot && (b.isConfirmed || b.isPendingPayment) && b.isMyBooking)`: Nếu là lịch của mình, hiển thị badge màu xanh lá "Lịch của bạn" kèm icon `check_circle`.
   - Tính toán chỗ trống cho tiện ích `shared`: `final availableCapacity = widget.amenity.maxCapacity - confirmedGuests;` phản ánh đúng `maxCapacity` từ CSDL.
3. Cho phép cư dân nhập / chọn số khách `_guestsCount` ngay trên giao diện trước khi bấm đặt lịch hoặc vào danh sách chờ.

- [ ] **Step 4: Chạy test để xác minh pass 100% không tràn**

Run: `flutter test test/features/resident/amenity_booking_resident_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/resident/screens/amenity_booking_screen.dart test/features/resident/amenity_booking_resident_screen_test.dart
git commit -m "feat(resident): sua loi huy lich wrap responsive va hien thi slot da dat"
```

---

### Task 5: Nâng Cấp Giao Diện Quản Trị Tiện Ích Admin 3 Tab (`AmenityManagementScreen`) theo chuẩn A7/A8

**Files:**
- Modify: `lib/features/management/screens/amenity_management_screen.dart`
- Modify: `lib/features/management/screens/handbook_management_screen.dart`
- Test: `test/features/management/amenity_management_3tabs_test.dart`

**Interfaces:**
- `AmenityManagementScreen`:
  - Tab 1: Duyệt Lịch Đặt Chỗ (Tất cả, Chờ duyệt, Chờ thanh toán, Đã xác nhận, Đã Check-in, Đã hủy) - Thẻ chuẩn A7, Dialog chuẩn A8.
  - Tab 2: Cấu hình Tiện ích & Sức chứa (danh sách tiện ích, nút sửa sức chứa `max_capacity`, hình thức `shared`/`exclusive`, đơn giá, tiền cọc).
  - Tab 3: Lịch Bảo Trì (giữ nguyên).
- `HandbookManagementScreen._showAmenityDialog`: Bổ sung các trường sức chứa và hình thức sử dụng.

- [ ] **Step 1: Viết widget test cho `AmenityManagementScreen` 3 Tab**

Tạo `test/features/management/amenity_management_3tabs_test.dart`:
Kiểm tra màn hình hiển thị đủ 3 Tab:
- Tab 1: 'Duyệt Lịch Đặt Chỗ'
- Tab 2: 'Tiện Ích & Sức Chứa'
- Tab 3: 'Lịch Bảo Trì'
- Nút Duyệt lịch và hộp thoại sửa sức chứa mở thành công.

- [ ] **Step 2: Chạy test để xác minh thất bại**

Run: `flutter test test/features/management/amenity_management_3tabs_test.dart`
Expected: FAIL

- [ ] **Step 3: Triển khai giao diện Admin 3 Tab**

1. Tăng `TabController(length: 3, vsync: this)`.
2. Triển khai **Tab 1: Duyệt Lịch Đặt Chỗ**:
   - Sử dụng `allAmenityBookingsProvider` hoặc stream bookings.
   - Thêm thanh tìm kiếm căn hộ và các Filter Chip: *Tất cả*, *Chờ duyệt / thanh toán*, *Đã xác nhận*, *Đã Check-in*, *Đã hủy*.
   - Thẻ công việc chuẩn **A7** và Dialog duyệt/từ chối chuẩn **A8**.
3. Triển khai **Tab 2: Cấu hình Tiện ích & Sức Chứa**:
   - Danh sách tiện ích tòa nhà hiển thị rõ: *Tên, Sức chứa tối đa (người), Hình thức (Dùng chung / Trọn gói), Phí, Tiền cọc*.
   - Nút Chỉnh sửa mở Dialog cập nhật trực tiếp `max_capacity`, `booking_type`, `fee_amount`, `deposit_amount` gọi `handbookRepositoryProvider.updateBuildingAmenity`.
4. Cập nhật `handbook_management_screen.dart` `_showAmenityDialog` đồng bộ đầy đủ các trường sức chứa.

- [ ] **Step 4: Chạy test xác minh**

Run: `flutter test test/features/management/amenity_management_3tabs_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/management/screens/amenity_management_screen.dart lib/features/management/screens/handbook_management_screen.dart test/features/management/amenity_management_3tabs_test.dart
git commit -m "feat(admin): nang cap 3 tab quan tri tien ich duyet lich va sua suc chua dong"
```

---

### Task 6: Kiểm Thử Toàn Diện, Responsive 360dp, Phân Tích Tĩnh & Đồng Bộ Kho Lưu Trữ

**Files:**
- Test: `test/integration/amenity_responsive_and_workflow_test.dart`

- [ ] **Step 1: Viết test tích hợp Responsive 360dp cho các màn hình mới**

Kiểm tra `AmenityBookingScreen` và `AmenityManagementScreen` trên độ phân giải 360x640dp không có lỗi tràn viền (0 overflow).

- [ ] **Step 2: Chạy toàn bộ test suite dự án**

Run: `flutter test`
Expected: Tất cả bài test đều PASS.

- [ ] **Step 3: Chạy static analysis**

Run: `dart analyze lib test`
Expected: `No issues found!` (0 errors, 0 warnings, 0 lints).

- [ ] **Step 4: Commit và Push lên GitHub `origin/main`**

```bash
git add .
git commit -m "test: bo sung kiem thu tich hop responsive tien ich va hoan tat ra soat he thong"
git push origin main
```
