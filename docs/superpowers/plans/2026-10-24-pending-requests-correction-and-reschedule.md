# Kế Hoạch Triển Khai: Cơ Chế Sửa Sai và Hủy Yêu Cầu Đang Chờ Duyệt (Gói 1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cung cấp đầy đủ cơ chế sửa sai và hủy an toàn cho cư dân đối với 4 nhóm nghiệp vụ đang chờ duyệt (`pending`): Phương tiện, Đặt tiện ích, Chỉ số điện nước và Yêu cầu liên kết căn hộ, đảm bảo tính toàn vẹn CSDL, chống Deadlock & Race Condition, và giữ gìn dữ liệu tài chính / kiểm toán.

**Architecture:** Sử dụng Atomic PostgreSQL RPCs có khóa Advisory Lock tuần tự (`pg_advisory_xact_lock`) để bảo đảm tính nhất quán dữ liệu ở tầng CSDL; nới lỏng Partial Unique Index cho phép gửi lại yêu cầu sau khi hủy; kết nối qua tầng Repository của Flutter và tích hợp nút thao tác trực quan (Inline Actions, Dialogs, BottomSheet) trên các màn hình cư dân tương ứng; quản lý trạng thái tự động qua Riverpod.

**Tech Stack:** PostgreSQL / Supabase, Flutter 3.x, Dart, Flutter Riverpod, Mockito / Test fakes.

## Global Constraints
- Commit trực tiếp trên nhánh `main` (không tạo nhánh phụ).
- 100% tiếng Việt chuẩn mực trên giao diện người dùng theo `design-rules.md`.
- Tuân thủ cấu trúc Feature-first và Riverpod AsyncNotifier theo `coding-rules.md`.
- `flutter analyze` đạt 0 cảnh báo, 0 lỗi trước khi hoàn tất task.
- TDD: Viết test trước, triển khai mã nguồn sau.

---

### Task 1: Thiết Kế & Triển Khai Migration CSDL (Deadlock-Free RPCs & Constraints)

**Files:**
- Create: `supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql`
- Test: `test/data/repositories/pending_correction_migration_test.dart`

**Interfaces:**
- Produces:
  - RPC `cancel_pending_vehicle(p_vehicle_id UUID)`
  - RPC `update_pending_vehicle(p_vehicle_id UUID, p_license_plate VARCHAR, p_vehicle_type VARCHAR, p_brand_model VARCHAR)`
  - RPC `reschedule_amenity_booking(p_booking_id UUID, p_new_date DATE, p_new_time_slot VARCHAR, p_new_guests_count INT, p_new_notes TEXT)`
  - RPC `update_pending_meter_reading(p_submission_id UUID, p_electric_reading NUMERIC, p_water_reading NUMERIC, p_electric_image_url TEXT, p_water_image_url TEXT, p_clear_electric_image BOOLEAN, p_clear_water_image BOOLEAN)`
  - RPC `cancel_pending_meter_reading(p_submission_id UUID)`
  - RPC `cancel_apartment_link_request(p_request_id UUID)`

- [ ] **Step 1: Viết test kiểm tra cú pháp và logic gọi các RPC mới**

Viết file test `test/data/repositories/pending_correction_migration_test.dart` kiểm tra các hợp đồng gọi RPC với đầy đủ tham số và trường hợp trả về.

- [ ] **Step 2: Chạy test để xác nhận fail**

Run: `flutter test test/data/repositories/pending_correction_migration_test.dart`
Expected: FAIL (RPC / repository methods chưa được triển khai)

- [ ] **Step 3: Viết migration file `20261024_04_pending_requests_correction_and_reschedule.sql`**

Nội dung bao gồm:
1. `ALTER TABLE public.vehicles DROP CONSTRAINT IF EXISTS vehicles_status_check;`
   `ALTER TABLE public.vehicles ADD CONSTRAINT vehicles_status_check CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'));`
2. `ALTER TABLE public.meter_reading_submissions DROP CONSTRAINT IF EXISTS meter_reading_submissions_status_check;`
   `ALTER TABLE public.meter_reading_submissions ADD CONSTRAINT meter_reading_submissions_status_check CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'));`
3. Chuyển đổi cột `apartment_link_requests.status` sang `VARCHAR(20)` có check constraint `status IN ('pending', 'approved', 'rejected', 'cancelled')`. Xóa constraint `UNIQUE(user_id, apartment_id)`, tạo Partial Unique Index `uq_link_requests_active ON public.apartment_link_requests(user_id, apartment_id) WHERE status IN ('pending', 'approved')`.
4. RPC `cancel_pending_vehicle`: Chỉ cho phép người đăng ký hoặc BQL hủy, kiểm tra `status = 'pending'`.
5. RPC `update_pending_vehicle`: Khóa advisory theo căn hộ, kiểm tra giới hạn 2 xe máy, đồng bộ cả `plate_number` và `license_plate`.
6. RPC `reschedule_amenity_booking`: Sắp xếp khóa advisory (`LEAST` & `GREATEST`), kiểm tra slot cũ chưa diễn ra, kiểm tra slot mới, loại trừ `id <> p_booking_id`, giữ nguyên phí đối với `confirmed`, tính lại phí cho `pending_payment`, đôn Waitlist cho slot cũ sang `pending_payment` (có phí) hoặc `confirmed` (miễn phí).
7. RPC `update_pending_meter_reading`: Ràng buộc không âm, hỗ trợ cờ xóa/giữ ảnh.
8. RPC `cancel_pending_meter_reading`: Cập nhật `status = 'cancelled'`.
9. RPC `cancel_apartment_link_request`: Cập nhật `status = 'cancelled'`.
10. Cấp quyền `GRANT EXECUTE` cho `authenticated`, thu hồi khỏi `anon, PUBLIC`.

- [ ] **Step 4: Chạy test kiểm tra cú pháp SQL và contract**

Run: `flutter test test/data/repositories/pending_correction_migration_test.dart`
Expected: PASS

- [ ] **Step 5: Commit migration**

```bash
git add supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql test/data/repositories/pending_correction_migration_test.dart
git commit -m "feat(db): migration 20261024_04 rpcs sua sai va huy yeu cau cho duyet"
```

---

### Task 2: Cập Nhật Tầng Repositories & Riverpod Providers

**Files:**
- Modify: `lib/data/repositories/vehicle_repository.dart`
- Modify: `lib/data/repositories/amenity_booking_repository.dart`
- Modify: `lib/data/repositories/meter_reading_repository.dart`
- Modify: `lib/data/providers/link_request_provider.dart`
- Test: `test/data/repositories/pending_requests_correction_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 RPCs
- Produces:
  - `VehicleRepository.updatePendingVehicle`
  - `VehicleRepository.cancelPendingVehicle`
  - `AmenityBookingRepository.rescheduleBooking`
  - `MeterReadingRepository.updatePendingSubmission`
  - `MeterReadingRepository.cancelPendingSubmission`
  - `LinkRequestNotifier.cancelPendingRequest`

- [ ] **Step 1: Viết test cho tầng Repository**

Tạo `test/data/repositories/pending_requests_correction_repository_test.dart` với các test cases:
1. `updatePendingVehicle` gọi đúng RPC `update_pending_vehicle`.
2. `cancelPendingVehicle` gọi đúng RPC `cancel_pending_vehicle`.
3. `rescheduleBooking` gọi đúng RPC `reschedule_amenity_booking`.
4. `updatePendingSubmission` và `cancelPendingSubmission` gọi đúng RPC.
5. `cancelPendingRequest` gọi đúng RPC `cancel_apartment_link_request`.

- [ ] **Step 2: Chạy test để xác nhận fail**

Run: `flutter test test/data/repositories/pending_requests_correction_repository_test.dart`
Expected: FAIL (Thiếu methods trên repository)

- [ ] **Step 3: Bổ sung code vào các repository & provider**

- Cập nhật `lib/data/repositories/vehicle_repository.dart`:
  - `updatePendingVehicle`
  - `cancelPendingVehicle`
- Cập nhật `lib/data/repositories/amenity_booking_repository.dart`:
  - `rescheduleBooking`
- Cập nhật `lib/data/repositories/meter_reading_repository.dart`:
  - `updatePendingSubmission`
  - `cancelPendingSubmission`
- Cập nhật `lib/data/providers/link_request_provider.dart`:
  - `cancelPendingRequest`

- [ ] **Step 4: Chạy test để xác nhận pass**

Run: `flutter test test/data/repositories/pending_requests_correction_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit tầng Repository**

```bash
git add lib/data/repositories/ lib/data/providers/link_request_provider.dart test/data/repositories/pending_requests_correction_repository_test.dart
git commit -m "feat(repo): bo sung cac ham sua sai va huy yeu cau cho duyet"
```

---

### Task 3: Giao Diện Chỉnh Sửa & Hủy Phương Tiện (`vehicle_management_screen.dart`)

**Files:**
- Modify: `lib/features/resident/screens/vehicle_management_screen.dart`
- Test: `test/features/resident/vehicle_edit_cancel_test.dart`

- [ ] **Step 1: Viết widget test kiểm tra nút Sửa & Hủy cho xe pending**

Kiểm tra thẻ xe `status == 'pending'` hiển thị nút Chỉnh sửa và Hủy; xe `status == 'approved'` không hiển thị nút Sửa/Hủy.

- [ ] **Step 2: Chạy test để xác nhận fail**

Run: `flutter test test/features/resident/vehicle_edit_cancel_test.dart`
Expected: FAIL

- [ ] **Step 3: Triển khai UI trên `vehicle_management_screen.dart`**

1. Thêm `_showEditVehicleDialog(BuildContext context, WidgetRef ref, VehicleModel vehicle)`: Điền sẵn biển số, loại xe, hãng xe. Validate biển số không rỗng.
2. Thêm `_confirmCancelVehicle(BuildContext context, WidgetRef ref, VehicleModel vehicle)`: Dialog xác nhận hủy.
3. Khi lưu/hủy: Gọi repository, hiển thị loading trong nút, invalidate `residentVehiclesProvider` và `apartmentVehiclesProvider`, hiển thị SnackBar.

- [ ] **Step 4: Chạy test để xác nhận pass**

Run: `flutter test test/features/resident/vehicle_edit_cancel_test.dart`
Expected: PASS

- [ ] **Step 5: Commit UI phương tiện**

```bash
git add lib/features/resident/screens/vehicle_management_screen.dart test/features/resident/vehicle_edit_cancel_test.dart
git commit -m "feat(resident): giao dien chinh sua va huy dang ky phuong tien cho duyet"
```

---

### Task 4: Giao Diện Đổi Lịch Đặt Tiện Ích (`amenity_booking_screen.dart`)

**Files:**
- Modify: `lib/features/resident/screens/amenity_booking_screen.dart`
- Test: `test/features/resident/amenity_reschedule_test.dart`

- [ ] **Step 1: Viết widget test cho tính năng đổi lịch tiện ích**

Kiểm tra nút "Đổi lịch" hiển thị trên booking tương lai có status `confirmed`, `pending_payment`, `waitlist`.

- [ ] **Step 2: Chạy test để xác nhận fail**

Run: `flutter test test/features/resident/amenity_reschedule_test.dart`
Expected: FAIL

- [ ] **Step 3: Triển khai BottomSheet Đổi Lịch trên `amenity_booking_screen.dart`**

1. Tạo phương thức `_showRescheduleSheet(BuildContext context, AmenityBookingModel booking)`.
2. Cho phép chọn ngày mới (chỉ từ hôm nay trở đi).
3. Tải danh sách slot và hiển thị danh sách slot để người dùng chọn.
4. Nếu booking `confirmed`: Khóa trường số khách và hiển thị ghi chú tài chính bảo toàn cọc/phí.
5. Gọi `rescheduleBooking`, xử lý loading và hiển thị lỗi thân thiện.

- [ ] **Step 4: Chạy test để xác nhận pass**

Run: `flutter test test/features/resident/amenity_reschedule_test.dart`
Expected: PASS

- [ ] **Step 5: Commit UI đổi lịch tiện ích**

```bash
git add lib/features/resident/screens/amenity_booking_screen.dart test/features/resident/amenity_reschedule_test.dart
git commit -m "feat(resident): bo sung chuc nang doi lich dat tien ich an toan"
```

---

### Task 5: Giao Diện Sửa & Hủy Chỉ Số Điện Nước (`resident_meter_reading_screen.dart`)

**Files:**
- Modify: `lib/features/resident/screens/resident_meter_reading_screen.dart`
- Test: `test/features/resident/meter_reading_edit_cancel_test.dart`

- [ ] **Step 1: Viết widget test kiểm tra nút Sửa & Hủy phiếu chỉ số pending**

- [ ] **Step 2: Chạy test để xác nhận fail**

Run: `flutter test test/features/resident/meter_reading_edit_cancel_test.dart`
Expected: FAIL

- [ ] **Step 3: Triển khai Dialog Sửa & Hủy trên `resident_meter_reading_screen.dart`**

1. Hiển thị nút "Sửa chỉ số" và "Hủy phiếu" trên thẻ `pending`.
2. Dialog sửa: Nạp sẵn số điện, số nước. Hiển thị thumbnail ảnh cũ, có nút chọn ảnh mới và nút xóa ảnh cũ (`clearImage`).
3. Dialog xác nhận hủy phiếu gửi chỉ số.
4. Invalidate provider dữ liệu chỉ số sau khi thành công.

- [ ] **Step 4: Chạy test để xác nhận pass**

Run: `flutter test test/features/resident/meter_reading_edit_cancel_test.dart`
Expected: PASS

- [ ] **Step 5: Commit UI chỉ số điện nước**

```bash
git add lib/features/resident/screens/resident_meter_reading_screen.dart test/features/resident/meter_reading_edit_cancel_test.dart
git commit -m "feat(resident): cho phep sua va huy phieu chi so dien nuoc cho duyet"
```

---

### Task 6: Giao Diện Hủy Yêu Cầu Liên Kết Căn Hộ (`link_request_screen.dart`)

**Files:**
- Modify: `lib/features/resident/screens/link_request_screen.dart`
- Test: `test/features/resident/link_request_cancel_test.dart`

- [ ] **Step 1: Viết widget test cho nút Hủy yêu cầu liên kết**

Kiểm tra nút "Hủy yêu cầu này" hiển thị khi state là `LinkStatus.pending`.

- [ ] **Step 2: Chạy test để xác nhận fail**

Run: `flutter test test/features/resident/link_request_cancel_test.dart`
Expected: FAIL

- [ ] **Step 3: Triển khai trên `link_request_screen.dart`**

1. Bổ sung nút "Hủy yêu cầu liên kết này" khi `state.status == LinkStatus.pending`.
2. Dialog xác nhận: `"Bạn có chắc chắn muốn hủy yêu cầu liên kết căn hộ này không?"`.
3. Gọi `ref.read(linkRequestProvider.notifier).cancelPendingRequest(requestId)`.
4. Sau khi hủy: State tự động chuyển về `LinkStatus.none`, màn hình hiển thị lại form nhập mã căn hộ.

- [ ] **Step 4: Chạy test để xác nhận pass**

Run: `flutter test test/features/resident/link_request_cancel_test.dart`
Expected: PASS

- [ ] **Step 5: Commit UI hủy liên kết căn hộ**

```bash
git add lib/features/resident/screens/link_request_screen.dart test/features/resident/link_request_cancel_test.dart
git commit -m "feat(resident): cho phep huy yeu cau lien ket can ho dang cho duyet"
```

---

### Task 7: Nghiệm Thu Toàn Diện & Phân Tích Tĩnh (Regression & Static Analysis)

**Files:** Toàn bộ project

- [ ] **Step 1: Chạy toàn bộ test suite**

Run: `flutter test`
Expected: 100% tests pass.

- [ ] **Step 2: Chạy static analysis**

Run: `flutter analyze`
Expected: No issues found! (0 warnings, 0 errors).

- [ ] **Step 3: Kiểm tra git status & Push**

Run: `git push origin main`
Expected: Remote đồng bộ hoàn tất.
