# Kế Hoạch Triển Khai: Hệ Sinh Thái Quản Trị Ban Quản Lý (PKA Home Admin)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng và hoàn thiện trọn gói hệ sinh thái 9 phân hệ quản trị cho Ban Quản Lý (Admin PKA Home), bao gồm Dashboard trực quan, Tạo hóa đơn hàng loạt theo tháng, Quản lý cư dân 360° & khóa tài khoản, Đối soát giao dịch, Check-in QR đặt dịch vụ, Phát thông báo phân tầng và Phê duyệt phương tiện gửi xe.

**Architecture:** Áp dụng mô hình Feature-first kết hợp tầng Repository và Riverpod. Tầng backend Supabase PostgreSQL cung cấp các hàm RPC nguyên tử `generate_monthly_bulk_invoices` và `check_in_amenity_booking`. Tầng UI tuân thủ hệ thống Design System chuẩn Segoe UI / Google Fonts, 100% tiếng Việt, mã căn hộ chuẩn `A0110` / `B0110`.

**Tech Stack:** Flutter 3.x, Flutter Riverpod, Supabase (PostgreSQL RPC, RLS, Realtime), intl.

## Global Constraints

- 100% tiếng Việt chuẩn mực trên toàn bộ giao diện, nhãn dán, thông báo.
- Tuyệt đối không dùng Emoji trên UI — sử dụng Material Icons (`Icons.*`).
- Định dạng mã căn hộ chuẩn: `A0110` / `B0205` (Block + Tầng 2 chữ số + Phòng 2 chữ số).
- Màu sắc và typography tuân thủ `core/theme/app_theme.dart`.
- Phương thức thanh toán hiển thị thống nhất: `Demo Payment (Giao dịch mô phỏng)` với mã `DEMO-YYYYMMDD-XXX`.
- Mọi tác vụ phải có test kiểm thử tương ứng, 0 lỗi `dart analyze` và 100% pass `flutter test`.

---

### Task 1: Database Migration & RPCs (`vehicles`, `users.is_locked`, `generate_monthly_bulk_invoices`)

**Files:**
- Create: `supabase/migrations/20261005_04_admin_management_ecosystem.sql`
- Create: `test/data/repositories/admin_ecosystem_migration_test.dart`

**Interfaces:**
- Produces:
  - Bảng `public.vehicles` (id, apartment_id, user_id, vehicle_type, license_plate, brand_model, status, created_at).
  - Cột `users.is_locked` (boolean, default false).
  - Cột `apartments.electric_reading`, `apartments.water_reading`.
  - RPC `generate_monthly_bulk_invoices(p_period, p_due_date, p_mgmt_rate, p_electric_rate, p_water_rate)`.
  - RPC `check_in_amenity_booking(p_booking_id)`.

- [x] **Step 1: Viết test kiểm tra schema migration và các câu lệnh RPC**
- [x] **Step 2: Tạo migration SQL `20261005_04_admin_management_ecosystem.sql`**
- [x] **Step 3: Chạy test xác nhận PASS**
- [x] **Step 4: Commit vào git**

```bash
git add supabase/migrations/20261005_04_admin_management_ecosystem.sql test/data/repositories/admin_ecosystem_migration_test.dart
git commit -m "feat(db): migration he sinh thai admin pka home va cac rpc hoa don hang loat va checkin"
```

---

### Task 2: Data Models & Service Layer (Vehicle, UserModel `isLocked`, Bulk Invoicing RPC Caller)

**Files:**
- Create: `lib/data/models/vehicle_model.dart`
- Modify: `lib/data/models/user_model.dart`
- Modify: `lib/data/models/apartment_model.dart`
- Create: `lib/data/repositories/vehicle_repository.dart`
- Create: `lib/data/providers/vehicle_provider.dart`
- Modify: `lib/data/repositories/invoice_repository.dart`
- Create: `test/data/models/vehicle_model_test.dart`
- Create: `test/data/repositories/vehicle_repository_test.dart`

**Interfaces:**
- Produces:
  - `VehicleModel` (fromJson, toJson, copyWith, statusDisplayName).
  - `UserModel.isLocked`.
  - `ApartmentModel.electricReading`, `ApartmentModel.waterReading`.
  - `VehicleRepository` (getPendingVehicles, approveVehicle, rejectVehicle, registerVehicle).
  - `InvoiceRepository.generateMonthlyBulkInvoices(...)`.

- [x] **Step 1: Viết unit tests cho `VehicleModel` và `VehicleRepository`**
- [x] **Step 2: Triển khai `VehicleModel` và mở rộng `UserModel`, `ApartmentModel`**
- [x] **Step 3: Triển khai `VehicleRepository`, `vehicleProvider` và gọi RPC tạo hóa đơn hàng loạt**
- [x] **Step 4: Chạy test xác nhận PASS**
- [x] **Step 5: Commit vào git**

```bash
git add lib/data/models/ lib/data/repositories/ lib/data/providers/ test/data/
git commit -m "feat(data): them VehicleModel, cap nhat UserModel isLocked va ham tao hoa don hang loat"
```

---

### Task 3: Nâng Cấp Dashboard Quản Trị Trung Tâm (KPI Cards, Tiến Độ Thu Phí, Giao Dịch Gần Nhất)

**Files:**
- Modify: `lib/features/management/screens/management_home_screen.dart`
- Create: `test/features/management/management_dashboard_enhanced_test.dart`

**Interfaces:**
- Dashboard hiển thị:
  - 5 thẻ chỉ số: Cư dân (356), Căn hộ (280/300), Doanh thu tháng (82.5M), Booking hôm nay (24), Phản ánh tồn đọng (5).
  - Progress bar tiến độ thu phí: `82% đã thanh toán` (`230 / 280 căn hộ`).
  - Danh sách 5 giao dịch thanh toán mô phỏng gần nhất (`DEMO-...`, Căn hộ, Số tiền, Trạng thái Thành công).
  - Nút tắt nhanh: Tạo HĐ hàng loạt, Phát thông báo, Duyệt xe, Duyệt cư dân.

- [x] **Step 1: Viết widget test cho các thẻ KPI, progress bar và danh sách giao dịch**
- [x] **Step 2: Cập nhật `_buildDashboard` trong `management_home_screen.dart`**
- [x] **Step 3: Chạy test xác nhận PASS**
- [x] **Step 4: Commit vào git**

```bash
git add lib/features/management/screens/management_home_screen.dart test/features/management/management_dashboard_enhanced_test.dart
git commit -m "feat(management): nang cap dashboard voi kpi cards, tien do thu phi va giao dich gan nhat"
```

---

### Task 4: Tạo Hóa Đơn Hàng Loạt Theo Tháng (Bulk Invoice Generation UI)

**Files:**
- Create: `lib/features/management/widgets/bulk_invoice_dialog.dart`
- Modify: `lib/features/management/screens/invoice_management_screen.dart`
- Create: `test/features/management/bulk_invoice_dialog_test.dart`

**Interfaces:**
- Nút "Tạo HĐ hàng loạt" trên `InvoiceManagementScreen` mở `BulkInvoiceDialog`:
  - Chọn kỳ hóa đơn: `10/2026`.
  - Chọn hạn đóng tiền: `20/10/2026`.
  - Nhập/chọn định mức: Phí quản lý ($10.000 đ/m^2$), Phí gửi xe tự động theo xe duyệt, Điện, Nước.
  - Nút **[ TỰ ĐỘNG TẠO 280 HÓA ĐƠN ]** gọi RPC và hiển thị kết quả thành công.

- [x] **Step 1: Viết widget test cho `BulkInvoiceDialog`**
- [x] **Step 2: Triển khai `BulkInvoiceDialog` và tích hợp vào `InvoiceManagementScreen`**
- [x] **Step 3: Chạy test xác nhận PASS**
- [x] **Step 4: Commit vào git**

```bash
git add lib/features/management/widgets/bulk_invoice_dialog.dart lib/features/management/screens/invoice_management_screen.dart test/features/management/bulk_invoice_dialog_test.dart
git commit -m "feat(invoice): them tinh nang tao hoa don hang loat theo thang cho toan bo can ho"
```

---

### Task 5: Quản Lý Cư Dân 360° & Khóa Tài Khoản

**Files:**
- Create: `lib/features/management/widgets/resident_360_detail_sheet.dart`
- Modify: `lib/features/management/screens/resident_management_screen.dart`
- Create: `test/features/management/resident_360_management_test.dart`

**Interfaces:**
- `ResidentManagementScreen`:
  - Thêm cột/badge trạng thái: `🟢 Hoạt động` / `🔴 Đã khóa`.
  - Nút/Menu "Khóa tài khoản" / "Mở khóa tài khoản".
  - Nhấn vào cư dân mở `Resident360DetailSheet`: Thông tin cá nhân, Tab Phương tiện (xe máy, ô tô), Tab Hóa đơn (công nợ), Tab Dịch vụ (gói gym, bơi).

- [x] **Step 1: Viết widget test cho Resident 360 sheet và toggle khóa tài khoản**
- [x] **Step 2: Triển khai `Resident360DetailSheet` và tích hợp vào `ResidentManagementScreen`**
- [x] **Step 3: Chạy test xác nhận PASS**
- [x] **Step 4: Commit vào git**

```bash
git add lib/features/management/widgets/resident_360_detail_sheet.dart lib/features/management/screens/resident_management_screen.dart test/features/management/resident_360_management_test.dart
git commit -m "feat(resident): hoan thien quan ly cu dan 360 do va tinh nang khoa tai khoan"
```

---

### Task 6: Màn Hình Đối Soát Giao Dịch Toàn Hệ Thống (`ManagementPaymentTransactionsScreen`)

**Files:**
- Create: `lib/features/management/screens/management_payment_transactions_screen.dart`
- Modify: `lib/core/router/route_names.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/management/screens/management_home_screen.dart`
- Create: `test/features/management/management_payment_transactions_screen_test.dart`

**Interfaces:**
- Màn hình hiển thị danh sách toàn bộ các giao dịch từ `payment_transactions` (Cả Hóa đơn & Dịch vụ).
- Bộ lọc: `Tất cả`, `Hóa đơn`, `Dịch vụ`, `Thành công`, `Đang chờ`.
- Dialog xem chi tiết giao dịch: Hiển thị hóa đơn liên kết hoặc mã đặt tiện ích.

- [x] **Step 1: Viết widget test cho `ManagementPaymentTransactionsScreen`**
- [x] **Step 2: Xây dựng màn hình và đăng ký route `AppRoutes.managementPaymentTransactions`**
- [x] **Step 3: Chạy test xác nhận PASS**
- [x] **Step 4: Commit vào git**

```bash
git add lib/features/management/screens/management_payment_transactions_screen.dart lib/core/router/ test/features/management/management_payment_transactions_screen_test.dart
git commit -m "feat(payment): them man hinh doi soat giao dich toan he thong cho ban quan ly"
```

---

### Task 7: Quản Lý Dịch Vụ Tiện Ích & Xác Nhận Check-in QR Đặt Chỗ

**Files:**
- Modify: `lib/features/management/screens/amenity_management_screen.dart`
- Create: `test/features/management/amenity_management_checkin_test.dart`

**Interfaces:**
- Tab 1: Danh mục dịch vụ (Hồ bơi, Gym, Sân cầu lông, Sân tennis) - Thêm/Sửa giá, bật tắt bảo trì.
- Tab 2: Danh sách đặt chỗ (Booking List):
  - Hiển thị các lượt đặt chỗ của cư dân.
  - Nút **[ Xác Nhận Check-in ]** chuyển booking sang `completed`.
  - Ô tìm kiếm nhanh theo mã đặt chỗ `BK-XXXX` khi cư dân trình mã QR.

- [x] **Step 1: Viết widget test cho tab đặt chỗ và luồng xác nhận Check-in**
- [x] **Step 2: Nâng cấp `AmenityManagementScreen` hỗ trợ 2 tab: Dịch vụ & Danh sách đặt chỗ / Check-in**
- [x] **Step 3: Chạy test xác nhận PASS**
- [x] **Step 4: Commit vào git**

```bash
git add lib/features/management/screens/amenity_management_screen.dart test/features/management/amenity_management_checkin_test.dart
git commit -m "feat(amenity): tich hop quan ly dat cho va chuc nang xac nhan check-in qr"
```

---

### Task 8: Quản Lý & Phê Duyệt Phương Tiện Gửi Xe (`VehicleApprovalScreen`)

**Files:**
- Create: `lib/features/management/screens/vehicle_approval_screen.dart`
- Modify: `lib/core/router/route_names.dart`
- Modify: `lib/core/router/app_router.dart`
- Create: `test/features/management/vehicle_approval_screen_test.dart`

**Interfaces:**
- Màn hình hiển thị danh sách xe cư dân đăng ký chờ phê duyệt.
- Thao tác BQL:
  - Bấm **[ Phê Duyệt ]**: Cấp thẻ gửi xe, đổi trạng thái `approved`.
  - Bấm **[ Từ Chối ]**: Đổi trạng thái `rejected`.
- Tab xe đã duyệt / xe bị từ chối.

- [x] **Step 1: Viết widget test cho `VehicleApprovalScreen`**
- [x] **Step 2: Triển khai `VehicleApprovalScreen` và đăng ký route `AppRoutes.managementVehicleApproval`**
- [x] **Step 3: Chạy test xác nhận PASS**
- [x] **Step 4: Commit vào git**

```bash
git add lib/features/management/screens/vehicle_approval_screen.dart lib/core/router/ test/features/management/vehicle_approval_screen_test.dart
git commit -m "feat(vehicle): xay dung man hinh quan ly va phe duyet dang ky xe cho ban quan ly"
```

---

### Task 9: Phát Thông Báo Phân Nhóm Đối Tượng (Tất Cả, Tòa A/B, Căn Hộ Cụ Thể)

**Files:**
- Modify: `lib/features/management/screens/announcement_management_screen.dart`
- Create: `test/features/management/announcement_targeting_test.dart`

**Interfaces:**
- Form tạo thông báo nâng cấp bộ chọn đối tượng:
  - `○ Toàn bộ cư dân chung cư`
  - `● Phân nhóm theo tòa (Tòa A / Tòa B)`
  - `○ Căn hộ cụ thể (Nhập mã: VD A0110)`
- Nhãn cảnh báo: Thông thường vs Khẩn cấp.

- [x] **Step 1: Viết widget test kiểm tra chọn đối tượng gửi thông báo**
- [x] **Step 2: Cập nhật dialog tạo thông báo trong `announcement_management_screen.dart`**
- [x] **Step 3: Chạy test xác nhận PASS**
- [x] **Step 4: Commit vào git**

```bash
git add lib/features/management/screens/announcement_management_screen.dart test/features/management/announcement_targeting_test.dart
git commit -m "feat(announcement): bo sung phan tang doi tuong gui thong bao theo toa va can ho"
```

---

### Task 10: Rà Soát Toàn Diện, Static Analysis & Nghiệm Thu (Verification)

**Files:**
- Toàn bộ codebase liên quan

- [x] **Step 1: Chạy `dart analyze` toàn dự án đảm bảo 0 lỗi/cảnh báo**
- [x] **Step 2: Chạy toàn bộ test suite `flutter test` đảm bảo 100% test cases pass**
- [x] **Step 3: Kiểm tra trạng thái Git working tree sạch sẽ**
- [x] **Step 4: Cập nhật checklist hoàn tất trong tài liệu kế hoạch**
