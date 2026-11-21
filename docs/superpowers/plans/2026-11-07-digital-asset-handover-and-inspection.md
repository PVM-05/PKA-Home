# Kế Hoạch Triển Khai: Biên Bản Bàn Giao & Kiểm Kê Tài Sản Căn Hộ Số Hóa (Digital Move-in/Move-out & Asset Inspection)

> **Dành cho kỹ sư triển khai:** BẮT BUỘC SỬ DỤNG KỸ NĂNG: `superpowers:subagent-driven-development` hoặc `superpowers:executing-plans` để thực thi kế hoạch theo từng nhiệm vụ. Các bước sử dụng cú pháp checkbox (`- [ ]`) để theo dõi tiến độ.

**Mục tiêu:** Xây dựng module nghiệp vụ bàn giao căn hộ và kiểm kê tài sản số hóa thương mại B2B SaaS (nhận nhà Move-in, trả phòng Move-out), bao gồm quản lý danh mục tài sản theo căn hộ, trạm kiểm kê hiện trường, chốt chỉ số điện/nước, chữ ký cảm ứng trực tiếp trên màn hình, đối soát cấn trừ cọc và tự động kết xuất biên bản PDF A4 chuẩn mực.

**Kiến trúc:** Clean Architecture + Feature-First (Flutter & Riverpod). Lưu trữ CSDL PostgreSQL & Storage trên Supabase có RLS cách ly tenant, offline-first fallback engine và tính toàn vẹn bất biến khi biên bản đã ký chốt.

**Tech Stack:** Flutter 3.x, Riverpod 2.x, Supabase (PostgreSQL 15+, Storage), PDF/Printing Engine, CustomPainter Canvas.

## Global Constraints
- Tuân thủ 100% tiếng Việt chuẩn mực trong toàn bộ giao diện, nhãn nút và thông báo lỗi.
- Không sử dụng Emoji trên UI; chỉ sử dụng `Icons.*` thuộc Material Icons chuẩn.
- Commit trực tiếp trên nhánh `main`, không tạo branch phụ hay git worktree.
- Tuân thủ TDD: Viết test trước, chạy test thấy fail, code giải pháp, chạy test pass 100%.
- Định dạng mã căn hộ chuẩn: `A0110` / `a0110` (Block + Tầng 2 số + Phòng 2 số).

---

### Task 1: Migration Cơ Sở Dữ Liệu & Supabase Storage

**Files:**
- Create: `supabase/migrations/20261107020000_digital_asset_handover_and_inspection.sql`
- Test: `test/database/handover_migration_test.dart`

**Interfaces:**
- Produces: Bảng `apartment_assets`, `apartment_handovers`, `handover_items`, storage bucket `handover-docs`, triggers sinh mã `HO-YYYYMM-XXXXX` và trigger khóa bất biến khi `confirmed`.

- [x] **Step 1: Viết test kiểm tra migration SQL**
  Tạo `test/database/handover_migration_test.dart` kiểm tra tính hợp lệ cú pháp SQL, sự tồn tại của các bảng, triggers, indexes và RLS policies.
- [x] **Step 2: Chạy test để xác nhận test thất bại**
  `flutter test test/database/handover_migration_test.dart` (Fails vì chưa có file SQL).
- [x] **Step 3: Viết file migration SQL**
  Tạo `supabase/migrations/20261107020000_digital_asset_handover_and_inspection.sql` với đầy đủ schema theo đặc tả thiết kế.
- [x] **Step 4: Chạy test để xác nhận test pass**
  `flutter test test/database/handover_migration_test.dart` (Pass).
- [x] **Step 5: Commit lên nhánh main**
  `git add supabase/migrations/20261107020000_digital_asset_handover_and_inspection.sql test/database/handover_migration_test.dart`
  `git commit -m "feat(db): migration bien ban ban giao va kiem ke tai san can ho so hoa"`

---

### Task 2: Data Models Strongly-Typed

**Files:**
- Create: `lib/data/models/apartment_asset_model.dart`
- Create: `lib/data/models/handover_item_model.dart`
- Create: `lib/data/models/apartment_handover_model.dart`
- Test: `test/data/models/handover_models_test.dart`

**Interfaces:**
- Produces:
  - `ApartmentAssetModel` (id, apartmentId, buildingId, roomArea, name, assetCode, quantity, condition, replacementPrice, note).
  - `HandoverItemModel` (id, handoverId, assetId, itemName, roomArea, quantity, condition, repairCost, note, photos).
  - `ApartmentHandoverModel` (id, apartmentId, buildingId, residentId, contractId, handoverType, reportCode, handoverDate, conductedBy, initialElectricityReading, initialWaterReading, depositHeld, totalDeduction, depositRefund, status, staffSignatureUrl, residentSignatureUrl, lookupCode, items).

- [x] **Step 1: Viết test unit cho các models**
  Tạo `test/data/models/handover_models_test.dart` test fromJson, toJson, copyWith, và các getters tiếng Việt chuẩn (`roomAreaDisplayName`, `conditionDisplayName`, `statusDisplayName`).
- [x] **Step 2: Chạy test kiểm tra thất bại**
  `flutter test test/data/models/handover_models_test.dart`
- [x] **Step 3: Cài đặt các class Model**
  Viết `apartment_asset_model.dart`, `handover_item_model.dart`, `apartment_handover_model.dart`.
- [x] **Step 4: Chạy test kiểm tra pass**
  `flutter test test/data/models/handover_models_test.dart`
- [x] **Step 5: Commit lên main**
  `git commit -m "feat(models): bo sung data models kiem ke va ban giao tai san"`

---

### Task 3: HandoverRepository & Offline-First Fallback Engine

**Files:**
- Create: `lib/data/repositories/handover_repository.dart`
- Create: `lib/data/providers/handover_provider.dart`
- Test: `test/data/repositories/handover_repository_test.dart`

**Interfaces:**
- Produces:
  - `HandoverRepository`:
    - `fetchAssetsByApartment(String apartmentId)`
    - `fetchHandoversByBuilding(String buildingId, {String? status, String? type})`
    - `fetchHandoversByResident(String residentId)`
    - `fetchHandoverDetail(String handoverId)`
    - `createHandover(ApartmentHandoverModel handover, List<HandoverItemModel> items)`
    - `updateHandoverItem(HandoverItemModel item)`
    - `signByStaff(String handoverId, Uint8List signatureBytes, {String? notes})`
    - `signByResident(String handoverId, Uint8List signatureBytes, {String? notes})`
    - `disputeByResident(String handoverId, String disputeReason)`
    - `uploadHandoverPhoto(String handoverId, Uint8List photoBytes, String fileName)`
    - `uploadSignature(String handoverId, String role, Uint8List signatureBytes)`

- [x] **Step 1: Viết test cho HandoverRepository**
  Tạo `test/data/repositories/handover_repository_test.dart` kiểm tra mock Supabase client và offline fallback engine.
- [x] **Step 2: Chạy test kiểm tra thất bại**
  `flutter test test/data/repositories/handover_repository_test.dart`
- [x] **Step 3: Cài đặt HandoverRepository & Providers**
  Cài đặt logic gọi Supabase RPC/Tables kèm offline fallback, tính toán cấn trừ cọc, lưu ảnh và chữ ký.
- [x] **Step 4: Chạy test kiểm tra pass**
  `flutter test test/data/repositories/handover_repository_test.dart`
- [x] **Step 5: Commit lên main**
  `git commit -m "feat(repo): cai dat HandoverRepository va offline-first engine"`

---

### Task 4: Khung Vẽ Chữ Ký Cảm Ứng (SignaturePadDialog)

**Files:**
- Create: `lib/core/widgets/signature_pad_dialog.dart`
- Test: `test/core/widgets/signature_pad_dialog_test.dart`

**Interfaces:**
- Produces: `SignaturePadDialog` (Hộp thoại mở khung vẽ chữ ký cảm ứng, hỗ trợ xóa nét, lưu xuất ra `Uint8List` ảnh PNG trong suốt).

- [x] **Step 1: Viết test widget cho SignaturePadDialog**
  Tạo `test/core/widgets/signature_pad_dialog_test.dart` kiểm tra hiển thị hộp thoại, thao tác kéo nét vẽ và trả về dữ liệu chữ ký.
- [x] **Step 2: Chạy test kiểm tra thất bại**
  `flutter test test/core/widgets/signature_pad_dialog_test.dart`
- [x] **Step 3: Cài đặt SignaturePadDialog với CustomPainter**
  Viết `lib/core/widgets/signature_pad_dialog.dart` mượt mà, hỗ trợ cả màn hình cảm ứng điện thoại và chuột trên Web.
- [x] **Step 4: Chạy test kiểm tra pass**
  `flutter test test/core/widgets/signature_pad_dialog_test.dart`
- [x] **Step 5: Commit lên main**
  `git commit -m "feat(ui): widget khung ve chu ky cam ung so hoa SignaturePadDialog"`

---

### Task 5: Giao Diện Ban Quản Lý (Danh sách & Trạm Kiểm Kê Hiện Trường)

**Files:**
- Create: `lib/features/management/screens/handover_management_screen.dart`
- Create: `lib/features/management/screens/inspection_workstation_screen.dart`
- Test: `test/features/management/handover_management_screen_test.dart`
- Test: `test/features/management/inspection_workstation_screen_test.dart`

**Interfaces:**
- Produces:
  - `HandoverManagementScreen`: Dải KPI, bộ lọc loại bàn giao và trạng thái, nút "Tạo biên bản mới".
  - `InspectionWorkstationScreen`: Giao diện duyệt kiểm kê từng phòng, chọn tình trạng tài sản, chụp ảnh hư hỏng, ghi chỉ số điện nước, mở `SignaturePadDialog` để BQL ký và gửi Cư dân.

- [x] **Step 1: Viết test widget cho màn hình BQL**
  Kiểm tra render KPI, danh sách biên bản, form kiểm kê và các chip trạng thái.
- [x] **Step 2: Chạy test kiểm tra thất bại**
  `flutter test test/features/management/handover_management_screen_test.dart`
- [x] **Step 3: Cài đặt HandoverManagementScreen & InspectionWorkstationScreen**
  Viết UI tuân thủ thiết kế design-rules: tiếng Việt chuẩn mực, Material Icons, responsive.
- [x] **Step 4: Chạy test kiểm tra pass**
  `flutter test test/features/management/handover_management_screen_test.dart`
  `flutter test test/features/management/inspection_workstation_screen_test.dart`
- [x] **Step 5: Commit lên main**
  `git commit -m "feat(management): man hinh quan tri va tram kiem ke ban giao tai san BQL"`

---

### Task 6: Giao Diện Cư Dân (Xem Biên Bản, Đối Soát & Ký Xác Nhận)

**Files:**
- Create: `lib/features/resident/screens/resident_handover_screen.dart`
- Create: `lib/features/resident/screens/resident_handover_detail_screen.dart`
- Test: `test/features/resident/resident_handover_screen_test.dart`

**Interfaces:**
- Produces:
  - `ResidentHandoverScreen`: Danh sách biên bản bàn giao gắn với căn hộ/người thuê.
  - `ResidentHandoverDetailScreen`: Xem chi tiết từng món đồ, ảnh hiện trường hư hỏng, bảng chiết tính tiền cọc, nút "Khiếu nại" và nút "Ký tên xác nhận".

- [x] **Step 1: Viết test widget cho màn hình Cư Dân**
  Tạo `test/features/resident/resident_handover_screen_test.dart`.
- [x] **Step 2: Chạy test kiểm tra thất bại**
  `flutter test test/features/resident/resident_handover_screen_test.dart`
- [x] **Step 3: Cài đặt ResidentHandoverScreen & ResidentHandoverDetailScreen**
  Hoàn thiện giao diện cho cư dân kiểm tra và ký số.
- [x] **Step 4: Chạy test kiểm tra pass**
  `flutter test test/features/resident/resident_handover_screen_test.dart`
- [x] **Step 5: Commit lên main**
  `git commit -m "feat(resident): man hinh doi soat va ky xac nhan ban giao can ho cho cu dan"`

---

### Task 7: Bộ Máy Xuất PDF Biên Bản Kiểm Kê A4 Chuẩn Pháp Lý

**Files:**
- Create: `lib/core/utils/handover_pdf_builder.dart`
- Test: `test/core/utils/handover_pdf_builder_test.dart`

**Interfaces:**
- Produces: `HandoverPdfBuilder.buildHandoverReportPdf(...)` sinh tài liệu A4 chuẩn pháp lý, nhúng bảng kê tài sản, chỉ số điện nước, bảng chiết tính cọc, mã tra cứu QR code và hai khung chữ ký điện tử.

- [x] **Step 1: Viết test unit cho HandoverPdfBuilder**
  Kiểm tra sinh byte data PDF không null, dung lượng > 0 và hỗ trợ Unicode tiếng Việt.
- [x] **Step 2: Chạy test kiểm tra thất bại**
  `flutter test test/core/utils/handover_pdf_builder_test.dart`
- [x] **Step 3: Cài đặt HandoverPdfBuilder**
  Sử dụng thư viện `pdf` và font tiếng Việt của hệ thống.
- [x] **Step 4: Chạy test kiểm tra pass**
  `flutter test test/core/utils/handover_pdf_builder_test.dart`
- [x] **Step 5: Commit lên main**
  `git commit -m "feat(pdf): bo may xuat bien ban ban giao can ho A4 HandoverPdfBuilder"`

---

### Task 8: Tích Hợp Menu Điều Hướng, Verification & Đồng Bộ Graphify

**Files:**
- Modify: `lib/core/router/route_names.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/management/screens/management_home_screen.dart`
- Modify: `lib/features/resident/screens/resident_home_screen.dart`
- Modify: `lib/features/resident/screens/resident_handover_screen.dart`
- Modify: `lib/features/resident/screens/resident_handover_detail_screen.dart`
- Modify: `lib/features/management/screens/handover_management_screen.dart`
- Modify: `lib/features/management/screens/inspection_workstation_screen.dart`

- [x] **Step 1: Thêm lối tắt điều hướng tại Dashboard BQL và Cư dân**
- [x] **Step 2: Chạy toàn bộ test suite liên quan**
  `flutter test test/database/handover_migration_test.dart`
  `flutter test test/data/models/handover_models_test.dart`
  `flutter test test/data/repositories/handover_repository_test.dart`
  `flutter test test/core/widgets/signature_pad_dialog_test.dart`
  `flutter test test/features/management/handover_management_screen_test.dart`
  `flutter test test/features/management/inspection_workstation_screen_test.dart`
  `flutter test test/features/resident/resident_handover_screen_test.dart`
  `flutter test test/core/utils/handover_pdf_builder_test.dart`
- [x] **Step 3: Chạy Static Analysis kiểm tra 0 issues**
  `dart analyze lib test` (0 issues)
- [x] **Step 4: Cập nhật Knowledge Graph**
  `graphify update .`
- [x] **Step 5: Commit hoàn thành module lên main**
  `git commit -m "feat: hoan tat tich hop module bien ban ban giao va kiem ke tai san so hoa"`
