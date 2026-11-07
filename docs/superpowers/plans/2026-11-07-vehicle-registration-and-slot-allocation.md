# Kế Hoạch Triển Khai: Đăng Ký Phương Tiện Minh Chứng & Phê Duyệt Gán Ô Đỗ Hầm

> **Dành cho kỹ sư/agent thực thi:** BẮT BUỘC tuân thủ TDD, viết kiểm thử trước, triển khai mã nguồn tối thiểu, chạy test xác nhận PASS trước khi commit trực tiếp vào nhánh `main`. Các bước sử dụng cú pháp checkbox (`- [ ]`) để theo dõi.

**Mục tiêu:** Hoàn thiện trọn vẹn luồng đăng ký phương tiện cư dân kèm ảnh minh chứng Giấy đăng ký xe (Cà vẹt) và quy trình phê duyệt gán vị trí ô đỗ hầm cố định (tầng B1/B2) cho ô tô.

**Kiến trúc:**
- Database & Storage: Bảng `vehicles` bổ sung `registration_image_url`, `approved_at`, `approved_by`; Bucket `vehicle-docs` lưu trữ ảnh cà vẹt.
- Repositories: `VehicleRepository` (upload ảnh, duyệt kèm gán ô đỗ), `ParkingRepository` (lấy ô đỗ ô tô còn trống, đồng bộ ô đỗ).
- UI: `vehicle_management_screen.dart` (chụp/chọn ảnh cà vẹt, xem badge ô đỗ), `vehicle_approval_screen.dart` (soi ảnh cà vẹt, dropdown chọn ô đỗ ô tô).

**Tech Stack:** Flutter, Dart, Riverpod, Supabase Flutter / Storage, Mocktail, Flutter Test.

## Quy Tắc Toàn Cục (Global Constraints)
- 100% Tiếng Việt chuẩn mực trên giao diện, thông báo lỗi và hộp thoại.
- Sử dụng Material Icons mặc định (`Icons.*`), tuyệt đối không dùng Emoji.
- Không gọi trực tiếp `SupabaseConfig.client` trong Widget, luôn qua Repository.
- Commit trực tiếp vào nhánh `main`, không tạo branch/worktree phụ.

---

### Nhiệm Vụ 1: Cơ Sở Dữ Liệu & Storage Migration

**Tập tin tác động:**
- Tạo mới: `supabase/migrations/20261107_01_vehicle_registration_and_slot_allocation.sql`
- Kiểm thử: `test/database/vehicle_registration_migration_test.dart`

- [ ] **Bước 1: Viết test kiểm tra migration SQL**
  Tạo `test/database/vehicle_registration_migration_test.dart` kiểm tra file migration tồn tại và chứa các câu lệnh `ALTER TABLE vehicles` cùng cấu hình bucket `vehicle-docs`.

- [ ] **Bước 2: Viết file migration SQL**
  Tạo `supabase/migrations/20261107_01_vehicle_registration_and_slot_allocation.sql`.

- [ ] **Bước 3: Chạy migration lên CSDL Supabase**
  Thực thi migration và xác nhận cấu trúc bảng `vehicles` cùng bucket `vehicle-docs` trên Supabase production.

- [ ] **Bước 4: Chạy test migration để xác nhận PASS**
  Chạy: `flutter test test/database/vehicle_registration_migration_test.dart`

- [ ] **Bước 5: Commit vào `main`**
  ```bash
  git add supabase/migrations/20261107_01_vehicle_registration_and_slot_allocation.sql test/database/vehicle_registration_migration_test.dart
  git commit -m "feat(db): migration bổ sung registration_image_url và bucket vehicle-docs"
  ```

---

### Nhiệm Vụ 2: Nâng Cấp Data Model `VehicleModel` & `VehicleRepository`

**Tập tin tác động:**
- Chỉnh sửa: `lib/data/models/vehicle_model.dart`
- Chỉnh sửa: `lib/data/repositories/vehicle_repository.dart`
- Kiểm thử: `test/data/repositories/vehicle_repository_test.dart`

- [ ] **Bước 1: Viết failing test cho `VehicleModel` và `VehicleRepository`**
  Bổ sung kịch bản kiểm tra `registrationImageUrl`, `parkingSlotNumber`, `uploadRegistrationImage`, `approveVehicle(..., parkingSlotId, parkingSlotNumber)`.

- [ ] **Bước 2: Chạy test để xác nhận FAIL**
  Chạy: `flutter test test/data/repositories/vehicle_repository_test.dart`

- [ ] **Bước 3: Cập nhật `VehicleModel`**
  Thêm các trường `registrationImageUrl`, `parkingSlotId`, `parkingSlotNumber`, `approvedAt`, `approvedBy` và getters `hasRegistrationImage`, `hasAssignedSlot`.

- [ ] **Bước 4: Cập nhật `VehicleRepository`**
  Thêm `uploadRegistrationImage`, cập nhật `registerVehicle`, `approveVehicle` và `rejectVehicle`.

- [ ] **Bước 5: Chạy lại test để xác nhận PASS**
  Chạy: `flutter test test/data/repositories/vehicle_repository_test.dart`

- [ ] **Bước 6: Commit vào `main`**
  ```bash
  git add lib/data/models/vehicle_model.dart lib/data/repositories/vehicle_repository.dart test/data/repositories/vehicle_repository_test.dart
  git commit -m "feat: nâng cấp VehicleModel và VehicleRepository hỗ trợ ảnh cà vẹt và gán ô đỗ"
  ```

---

### Nhiệm Vụ 3: Nâng Cấp `ParkingRepository` Hỗ Trợ Lọc Ô Đỗ Ô Tô Còn Trống

**Tập tin tác động:**
- Chỉnh sửa: `lib/data/repositories/parking_repository.dart`
- Kiểm thử: `test/data/repositories/parking_repository_test.dart`

- [ ] **Bước 1: Viết failing test cho `fetchAvailableCarSlots` và sửa `assignSlot`**
  Cập nhật `test/data/repositories/parking_repository_test.dart`.

- [ ] **Bước 2: Cập nhật `ParkingRepository`**
  Bổ sung `fetchAvailableCarSlots` và chuẩn hóa lưu `slotNumber` vào `parking_slot_number`.

- [ ] **Bước 3: Chạy test để xác nhận PASS**
  Chạy: `flutter test test/data/repositories/parking_repository_test.dart`

- [ ] **Bước 4: Commit vào `main`**
  ```bash
  git add lib/data/repositories/parking_repository.dart test/data/repositories/parking_repository_test.dart
  git commit -m "feat: bổ sung fetchAvailableCarSlots và chuẩn hóa assignSlot trong ParkingRepository"
  ```

---

### Nhiệm Vụ 4: Nâng Cấp Giao Diện Cư Dân (`vehicle_management_screen.dart`)

**Tập tin tác động:**
- Chỉnh sửa: `lib/features/resident/screens/vehicle_management_screen.dart`
- Kiểm thử: `test/features/resident/vehicle_proof_registration_test.dart`

- [ ] **Bước 1: Cập nhật modal đăng ký xe mới**
  Tích hợp nút chọn ảnh Cà vẹt xe từ máy ảnh/thư viện, hiển thị preview và tải lên Supabase Storage khi nộp.

- [ ] **Bước 2: Cập nhật thẻ xe hiển thị ảnh Cà vẹt và Badge ô đỗ**
  Hiển thị ảnh thu nhỏ Cà vẹt xe mở được `PhotoViewerScreen` và Badge ô đỗ cố định dưới hầm.

- [ ] **Bước 3: Viết widget test cho giao diện đăng ký xe cư dân**
  Tạo `test/features/resident/vehicle_proof_registration_test.dart`.

- [ ] **Bước 4: Chạy test xác nhận PASS**
  Chạy: `flutter test test/features/resident/vehicle_proof_registration_test.dart`

- [ ] **Bước 5: Commit vào `main`**
  ```bash
  git add lib/features/resident/screens/vehicle_management_screen.dart test/features/resident/vehicle_proof_registration_test.dart
  git commit -m "feat: tích hợp upload ảnh cà vẹt và hiển thị badge ô đỗ hầm trên màn hình cư dân"
  ```

---

### Nhiệm Vụ 5: Nâng Cấp Giao Diện Ban Quản Lý (`vehicle_approval_screen.dart`)

**Tập tin tác động:**
- Chỉnh sửa: `lib/features/management/screens/vehicle_approval_screen.dart`
- Kiểm thử: `test/features/management/vehicle_approval_slot_allocation_test.dart`

- [ ] **Bước 1: Cập nhật thẻ duyệt xe BQL**
  Hiển thị thumbnail ảnh Cà vẹt xe kèm nút xem phóng to.

- [ ] **Bước 2: Cập nhật modal phê duyệt ô tô**
  Dropdown chọn ô đỗ ô tô còn trống ở hầm B1/B2 và gọi duyệt kèm gán ô đỗ.

- [ ] **Bước 3: Viết widget test cho giao diện BQL**
  Tạo `test/features/management/vehicle_approval_slot_allocation_test.dart`.

- [ ] **Bước 4: Chạy test xác nhận PASS**
  Chạy: `flutter test test/features/management/vehicle_approval_slot_allocation_test.dart`

- [ ] **Bước 5: Commit vào `main`**
  ```bash
  git add lib/features/management/screens/vehicle_approval_screen.dart test/features/management/vehicle_approval_slot_allocation_test.dart
  git commit -m "feat: tích hợp xem ảnh cà vẹt và dropdown gán ô đỗ ô tô trên màn hình BQL"
  ```

---

### Nhiệm Vụ 6: Xác Minh Toàn Diện, Phân Tích Tĩnh & Cập Nhật Graphify

**Tập tin tác động:** Toàn bộ codebase liên quan.

- [ ] **Bước 1: Chạy kiểm tra tĩnh toàn bộ dự án**
  Chạy: `dart analyze lib test`
  Kết quả dự kiến: 0 issues.

- [ ] **Bước 2: Chạy kiểm thử toàn bộ module Vehicle & Parking**
  Chạy: `flutter test test/data/repositories/vehicle_repository_test.dart test/data/repositories/parking_repository_test.dart test/features/resident/vehicle_proof_registration_test.dart test/features/management/vehicle_approval_slot_allocation_test.dart`
  Kết quả dự kiến: PASS 100%.

- [ ] **Bước 3: Cập nhật Knowledge Graph**
  Chạy: `graphify update .`

- [ ] **Bước 4: Xác nhận git clean trên nhánh `main`**
  Chạy: `git status`.
