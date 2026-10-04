# Kế Hoạch Triển Khai: Quản Lý Bảo Trì & Bảo Dưỡng Thiết Bị Toàn Tòa Nhà (Building Equipment & Preventive Maintenance)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng module quản lý hồ sơ vòng đời thiết bị kỹ thuật tòa nhà (Thang máy, PCCC, Máy bơm, Máy phát điện...), tự động hóa chu kỳ bảo trì định kỳ, phân công kỹ thuật viên/nhà thầu ngoài, quản lý chi phí, tự động nhắc hạn bảo dưỡng và cảnh báo gián đoạn dịch vụ tới cư dân.

**Architecture:** Sử dụng kiến trúc Feature-first với 2 bảng PostgreSQL (`building_equipments`, `equipment_maintenance_tasks`), kết hợp các triggers tự động hóa vòng đời và thông báo gián đoạn dịch vụ. Tầng Flutter triển khai `EquipmentRepository`, các Riverpod AsyncNotifiers, và giao diện quản lý đa tòa nhà kèm banner thông tri cư dân.

**Tech Stack:** Flutter (Dart 3.x), Riverpod, GoRouter, Supabase Database, RLS, Triggers, RPC.

## Global Constraints

- **Language:** 100% Tiếng Việt chuẩn mực trên mọi màn hình, nhãn dán, trạng thái và thông báo.
- **UI/UX Consistency:** Sử dụng `AppCard`, `AppTheme` bo góc 12px, font Inter, hỗ trợ cả Light/Dark theme.
- **Security:** RLS Fail-closed; phân quyền BQL/Kỹ thuật viên quản lý chi phí nội bộ; cư dân chỉ xem tình trạng thiết bị và lịch bảo trì ảnh hưởng trực tiếp đến sinh hoạt.
- **TDD:** Mọi task đều viết test trước hoặc đi kèm unit/widget test độc lập. Không phá vỡ 145/145 test hiện có.

---

### Task 1: Migration Cơ Sở Dữ Liệu (`building_equipments`, `equipment_maintenance_tasks`, Triggers & RPC)

**Files:**
- Create: `supabase/migrations/20261004_02_building_equipment_maintenance.sql`

**Interfaces:**
- Table `building_equipments` (id, code, name, category, building, location, installation_date, warranty_until, maintenance_interval_days, last_maintenance_date, next_maintenance_date, status, specifications, created_at, updated_at).
- Table `equipment_maintenance_tasks` (id, equipment_id, title, task_type, scheduled_start, scheduled_end, actual_start, actual_end, technician_id, vendor_name, vendor_contact, cost, status, affects_service, service_interruption_note, notes, created_by, created_at, updated_at).
- Trigger `handle_equipment_task_completion`: Tự động tính toán `last_maintenance_date`, `next_maintenance_date = last_date + interval_days`, và cập nhật `status = 'operational'`.
- Trigger `handle_equipment_service_interruption`: Khi task `affects_service = true` chuyển sang `in_progress`, tự động đặt thiết bị thành `under_maintenance` và gửi notification tới cư dân tòa nhà đó.
- RPC `check_upcoming_equipment_maintenance()`: Quét và nhắc hạn trước 7 ngày.

- [x] **Step 1: Viết file SQL migration `20261004_02_building_equipment_maintenance.sql`**
- [x] **Step 2: Thực thi migration bằng Supabase MCP `execute_sql`**
- [x] **Step 3: Kiểm tra cấu trúc các bảng và triggers đã tạo thành công**
- [x] **Step 4: Commit migration vào git**

```bash
git add supabase/migrations/20261004_02_building_equipment_maintenance.sql
git commit -m "feat(db): tạo migration bảng thiết bị tòa nhà, phiếu bảo trì, triggers và rpc"
```

---

### Task 2: Data Models (`BuildingEquipmentModel`, `EquipmentMaintenanceTaskModel`) & Unit Tests

**Files:**
- Create: `lib/data/models/building_equipment_model.dart`
- Create: `lib/data/models/equipment_maintenance_task_model.dart`
- Create: `test/data/models/building_equipment_model_test.dart`
- Create: `test/data/models/equipment_maintenance_task_model_test.dart`

**Interfaces:**
- `BuildingEquipmentModel`:
  - `id`, `code`, `name`, `category`, `building`, `location`, `installationDate`, `warrantyUntil`, `maintenanceIntervalDays`, `lastMaintenanceDate`, `nextMaintenanceDate`, `status`, `specifications`.
  - Getters: `isUnderMaintenance`, `isUpcomingMaintenance`, `isOverdueMaintenance`, `categoryDisplayName`, `statusDisplayName`.
  - `fromJson`, `toJson`, `copyWith`.
- `EquipmentMaintenanceTaskModel`:
  - `id`, `equipmentId`, `equipmentCode`, `equipmentName`, `title`, `taskType`, `scheduledStart`, `scheduledEnd`, `actualStart`, `actualEnd`, `technicianId`, `technicianName`, `vendorName`, `vendorContact`, `cost`, `status`, `affectsService`, `serviceInterruptionNote`, `notes`.
  - Getters: `isCompleted`, `isInProgress`, `statusDisplayName`, `taskTypeDisplayName`.
  - `fromJson`, `toJson`, `copyWith`.

- [x] **Step 1: Viết failing unit tests trong `test/data/models/building_equipment_model_test.dart`**
- [x] **Step 2: Viết failing unit tests trong `test/data/models/equipment_maintenance_task_model_test.dart`**
- [x] **Step 3: Hiện thực `BuildingEquipmentModel` trong `lib/data/models/building_equipment_model.dart`**
- [x] **Step 4: Hiện thực `EquipmentMaintenanceTaskModel` trong `lib/data/models/equipment_maintenance_task_model.dart`**
- [x] **Step 5: Chạy unit tests xác nhận 100% PASS**
- [x] **Step 6: Commit vào git**

```bash
git add lib/data/models/ test/data/models/
git commit -m "feat(models): tạo BuildingEquipmentModel và EquipmentMaintenanceTaskModel"
```

---

### Task 3: Repository (`EquipmentRepository`), Riverpod Providers & Unit Tests

**Files:**
- Create: `lib/data/repositories/equipment_repository.dart`
- Create: `lib/data/providers/equipment_provider.dart`
- Create: `test/data/repositories/equipment_repository_test.dart`

**Interfaces:**
- `EquipmentRepository`:
  - `getEquipments({String? building, String? category, String? status}) -> Future<List<BuildingEquipmentModel>>`
  - `getEquipmentById(String id) -> Future<BuildingEquipmentModel>`
  - `createEquipment(Map<String, dynamic> data) -> Future<BuildingEquipmentModel>`
  - `updateEquipment(String id, Map<String, dynamic> data) -> Future<BuildingEquipmentModel>`
  - `deleteEquipment(String id) -> Future<void>`
  - `getMaintenanceTasks({String? equipmentId, String? status, String? building}) -> Future<List<EquipmentMaintenanceTaskModel>>`
  - `createMaintenanceTask(Map<String, dynamic> data) -> Future<EquipmentMaintenanceTaskModel>`
  - `updateMaintenanceTaskStatus(String taskId, String status, {DateTime? actualStart, DateTime? actualEnd}) -> Future<void>`
  - `getActiveServiceInterruptions({required String building}) -> Future<List<EquipmentMaintenanceTaskModel>>`
- Providers:
  - `equipmentRepositoryProvider`
  - `equipmentListProvider`
  - `equipmentTasksProvider`
  - `equipmentFilterBuildingProvider`, `equipmentFilterCategoryProvider`
  - `activeServiceInterruptionsProvider`

- [x] **Step 1: Viết failing tests trong `test/data/repositories/equipment_repository_test.dart`**
- [x] **Step 2: Hiện thực `EquipmentRepository` trong `lib/data/repositories/equipment_repository.dart`**
- [x] **Step 3: Tạo các Riverpod providers trong `lib/data/providers/equipment_provider.dart`**
- [x] **Step 4: Chạy test xác nhận PASS**
- [x] **Step 5: Commit vào git**

```bash
git add lib/data/repositories/equipment_repository.dart lib/data/providers/equipment_provider.dart test/data/repositories/equipment_repository_test.dart
git commit -m "feat(repo): tạo EquipmentRepository và equipment providers"
```

---

### Task 4: Giao Diện Quản Lý Thiết Bị & Bảo Trì (`EquipmentManagementScreen`, `EquipmentDetailScreen`, Dialogs)

**Files:**
- Create: `lib/features/management/screens/equipment_management_screen.dart`
- Create: `lib/features/management/screens/equipment_detail_screen.dart`
- Create: `lib/features/management/widgets/equipment_form_dialog.dart`
- Create: `lib/features/management/widgets/maintenance_task_form_dialog.dart`
- Modify: `lib/core/router/route_names.dart`
- Modify: `lib/core/router/app_router.dart`
- Create: `test/features/management/equipment_management_screen_test.dart`

**Interfaces:**
- `EquipmentManagementScreen`:
  - Thẻ tóm tắt KPIs (Tổng thiết bị, Đang hoạt động, Đang bảo trì, Sắp đến hạn).
  - Bộ lọc Tòa nhà và Phân loại.
  - Tab 1: Danh sách thiết bị (Thẻ thiết bị, chu kỳ, nút thêm).
  - Tab 2: Lịch & Phiếu bảo trì (Danh sách nhiệm vụ, nút tạo phiếu, nút chuyển trạng thái Bắt đầu/Hoàn thành).
- `EquipmentDetailScreen`:
  - Thông số kỹ thuật, lịch sử bảo dưỡng, tổng chi phí lũy kế.
- Dialogs:
  - Form thêm/sửa thiết bị và Form giao việc bảo trì.

- [x] **Step 1: Thêm routes `managementEquipment` và `managementEquipmentDetail` vào `AppRoutes` và `app_router.dart`**
- [x] **Step 2: Tạo `EquipmentFormDialog` và `MaintenanceTaskFormDialog`**
- [x] **Step 3: Tạo `EquipmentManagementScreen` và `EquipmentDetailScreen`**
- [x] **Step 4: Viết widget test trong `test/features/management/equipment_management_screen_test.dart`**
- [x] **Step 5: Chạy test xác nhận PASS**
- [x] **Step 6: Commit vào git**

```bash
git add lib/features/management/ lib/core/router/ test/features/management/
git commit -m "feat(ui): tạo giao diện quản lý thiết bị và bảo trì định kỳ cho ban quản lý"
```

---

### Task 5: Cảnh Báo Gián Đoạn Dịch Vụ Cư Dân (`EquipmentInterruptionBanner` trên `ResidentHomeScreen`)

**Files:**
- Create: `lib/features/resident/widgets/equipment_interruption_banner.dart`
- Modify: `lib/features/resident/screens/resident_home_screen.dart`
- Create: `test/features/resident/equipment_interruption_banner_test.dart`

**Interfaces:**
- `EquipmentInterruptionBanner`:
  - Lắng nghe `activeServiceInterruptionsProvider`.
  - Nếu có thiết bị tại tòa nhà đang bảo trì (`affects_service = true`), hiển thị Banner cảnh báo màu vàng nổi bật với thông điệp rõ ràng, thời gian dự kiến xong.
  - Tự động ẩn khi không có thiết bị nào gián đoạn.

- [x] **Step 1: Tạo widget `EquipmentInterruptionBanner`**
- [x] **Step 2: Tích hợp vào `ResidentHomeScreen`**
- [x] **Step 3: Viết widget test kiểm tra hiển thị/ẩn banner**
- [x] **Step 4: Chạy test xác nhận PASS**
- [x] **Step 5: Commit vào git**

```bash
git add lib/features/resident/ test/features/resident/
git commit -m "feat(ui): tích hợp banner cảnh báo bảo trì thiết bị gián đoạn dịch vụ cho cư dân"
```

---

### Task 6: Kiểm Thử Toàn Diện, Phân Tích Tĩnh & Tích Hợp Nhánh (Verification)

**Files:**
- Toàn bộ codebase liên quan

- [x] **Step 1: Chạy `dart analyze` đảm bảo 0 issues**
- [x] **Step 2: Chạy toàn bộ test suite `flutter test` đảm bảo 100% test cases pass**
- [x] **Step 3: Báo cáo kết quả và tích hợp nhánh hoàn tất**
