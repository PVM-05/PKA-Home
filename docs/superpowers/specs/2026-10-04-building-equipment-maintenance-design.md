# Đặc Tả Thiết Kế: Quản Lý Bảo Trì & Bảo Dưỡng Thiết Bị Toàn Tòa Nhà (Building Equipment & Preventive Maintenance)

**Mã tài liệu:** `SPEC-2026-10-04-BUILDING-EQUIPMENT-MAINTENANCE`  
**Ngày lập:** 04/10/2026  
**Trạng thái:** Đã phê duyệt kiến trúc (Approved)  
**Thuộc Đợt:** Đợt 1 — Hoàn thiện vận hành cốt lõi (Giai đoạn 2)  
**Phạm vi:** Quản lý tài sản kỹ thuật tòa nhà, chu kỳ bảo trì định kỳ, phân công kỹ thuật viên/nhà thầu, hạch toán chi phí, và thông tri cư dân.

---

## 1. Mục Tiêu Nghiệp Vụ

Hệ thống chung cư đòi hỏi vận hành liên tục và an toàn cao cho các hệ thống kỹ thuật trọng yếu (Thang máy, Hệ thống PCCC, Máy bơm nước sinh hoạt, Máy phát điện dự phòng, Hệ thống trạm biến áp và xử lý nước thải). Ban quản lý không chỉ xử lý sự cố phát sinh (Corrective Maintenance) mà cốt lõi là **bảo dưỡng phòng ngừa (Preventive Maintenance)** định kỳ.

Mục tiêu của module:
1. **Quản lý vòng đời tài sản (Equipment Registry):** Lưu trữ hồ sơ thiết bị, mã định danh, hãng sản xuất, vị trí (tòa nhà, tầng), chu kỳ bảo dưỡng định kỳ (ngày/tuần/tháng/năm).
2. **Kế hoạch & Phiếu bảo trì (Maintenance Tasks & Work Orders):** Lập lịch bảo dưỡng định kỳ hoặc đột xuất; phân công nhân viên kỹ thuật tòa nhà hoặc gọi nhà thầu chuyên dụng bên ngoài (kèm thông tin liên hệ).
3. **Tự động hóa chu kỳ & Nhắc hạn (Auto Recurrence & Smart Reminders):** Khi một lần bảo dưỡng hoàn thành, hệ thống tự động cập nhật ngày bảo dưỡng gần nhất và tính toán ngày bảo dưỡng tiếp theo; tự động gửi thông báo cảnh báo trước 7 ngày khi sắp đến hạn.
4. **Kiểm soát chi phí & Lịch sử (Cost & Audit Trail):** Lưu vết toàn bộ các lần bảo dưỡng, chi phí vật tư/nhân công, phục vụ kiểm toán quỹ bảo trì 2% của chung cư.
5. **Thông tri gián đoạn dịch vụ tới Cư dân (Service Interruption Alerts):** Nếu việc bảo trì làm gián đoạn tiện ích sinh hoạt (vd: cắt thang máy 2 tiếng, tạm ngắt nước để súc rửa máy bơm), hệ thống tự động phát cảnh báo tới cư dân thuộc tòa nhà bị ảnh hưởng.

---

## 2. Kiến Trúc Luồng Nghiệp Vụ

```
[BQL / Kỹ Thuật Viên]
        │
        ├─► 1. Tạo/Quản lý Hồ sơ Thiết bị (building_equipments)
        │      (Mã: TM-A01, Loại: Thang máy, Tòa A, Chu kỳ: 30 ngày)
        │
        ├─► 2. Lập Phiếu Bảo Trì (equipment_maintenance_tasks)
        │      (Định kỳ / Đột xuất / Kiểm định an toàn, Giao Kỹ thuật viên / Nhà thầu, Chi phí)
        │
        │   ┌─── Cờ affects_service = true (Tạm ngưng dịch vụ)
        ▼   ▼
[Trigger: Phát thông báo tới Cư dân tòa nhà bị ảnh hưởng]
        │
        ▼
[Kỹ thuật viên thực hiện -> Cập nhật: 'in_progress' -> 'completed']
        │
        ▼
[Trigger Database: Tự động cập nhật vòng đời thiết bị]
  - last_maintenance_date = thời điểm hoàn thành
  - next_maintenance_date = last_maintenance_date + maintenance_interval_days
  - status = 'operational' (Hoạt động tốt)
        │
        ▼
[Hệ thống tự động nhắc hạn bảo dưỡng tiếp theo trước 7 ngày]
```

---

## 3. Thiết Kế Cơ Sở Dữ Liệu (PostgreSQL / Supabase Schema)

### 3.1. Bảng `building_equipments` (Danh mục Hồ sơ Thiết bị)

| Tên Cột | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `uuid` | `PRIMARY KEY, DEFAULT gen_random_uuid()` | Khóa chính |
| `code` | `text` | `NOT NULL, UNIQUE` | Mã thiết bị (vd: `TM-A01`, `PCCC-B1`, `MPD-01`) |
| `name` | `text` | `NOT NULL` | Tên thiết bị (vd: "Thang máy chở khách A1") |
| `category` | `text` | `NOT NULL` | Phân loại: `elevator`, `fire_safety`, `water_pump`, `generator`, `electrical`, `hvac`, `other` |
| `building` | `text` | `NOT NULL DEFAULT 'Toàn khu'` | Tòa nhà (vd: "Tòa A", "Tòa B", "Tòa C", "Toàn khu") |
| `location` | `text` | `NOT NULL` | Vị trí cụ thể (vd: "Trục A - Tầng hầm B1 đến Tầng 25", "Phòng kỹ thuật tầng hầm") |
| `installation_date` | `date` | `NULL` | Ngày lắp đặt / đưa vào sử dụng |
| `warranty_until` | `date` | `NULL` | Ngày hết hạn bảo hành của hãng |
| `maintenance_interval_days` | `integer` | `NOT NULL DEFAULT 30` | Chu kỳ bảo dưỡng định kỳ (số ngày: vd 30, 90, 180, 365) |
| `last_maintenance_date` | `timestamptz` | `NULL` | Ngày bảo dưỡng hoàn thành gần nhất |
| `next_maintenance_date` | `timestamptz` | `NULL` | Ngày bảo dưỡng định kỳ dự kiến kế tiếp |
| `status` | `text` | `NOT NULL DEFAULT 'operational'` | `operational` (tốt), `under_maintenance` (đang bảo dưỡng), `degraded` (cần sửa), `inactive` (ngừng hoạt động) |
| `specifications` | `text` | `NULL` | Thông số kỹ thuật / Tải trọng / Hãng sản xuất |
| `created_at` | `timestamptz` | `NOT NULL DEFAULT now()` | Thời điểm tạo |
| `updated_at` | `timestamptz` | `NOT NULL DEFAULT now()` | Thời điểm cập nhật |

### 3.2. Bảng `equipment_maintenance_tasks` (Phiếu Bảo Trì & Nhật Ký Sửa Chữa)

| Tên Cột | Kiểu Dữ Liệu | Ràng Buộc | Mô Tả |
| :--- | :--- | :--- | :--- |
| `id` | `uuid` | `PRIMARY KEY, DEFAULT gen_random_uuid()` | Khóa chính |
| `equipment_id` | `uuid` | `NOT NULL, REFERENCES building_equipments(id) ON DELETE CASCADE` | Thuộc thiết bị nào |
| `title` | `text` | `NOT NULL` | Tiêu đề phiếu (vd: "Bảo dưỡng định kỳ Tháng 10 - Hệ thống phanh & cáp") |
| `task_type` | `text` | `NOT NULL DEFAULT 'scheduled'` | `scheduled` (định kỳ), `unscheduled` (đột xuất), `inspection` (kiểm định an toàn bắt buộc) |
| `scheduled_start` | `timestamptz` | `NOT NULL` | Thời gian dự kiến bắt đầu |
| `scheduled_end` | `timestamptz` | `NOT NULL` | Thời gian dự kiến kết thúc |
| `actual_start` | `timestamptz` | `NULL` | Thời gian thực tế bắt đầu |
| `actual_end` | `timestamptz` | `NULL` | Thời gian thực tế kết thúc |
| `technician_id` | `uuid` | `NULL, REFERENCES users(id) ON DELETE SET NULL` | Kỹ thuật viên nội bộ phụ trách |
| `vendor_name` | `text` | `NULL` | Đơn vị / Nhà thầu ngoài thực hiện (vd: "Schindler Elevator Corp") |
| `vendor_contact` | `text` | `NULL` | Số hotline / người phụ trách của nhà thầu |
| `cost` | `numeric(12, 2)` | `NOT NULL DEFAULT 0` | Chi phí bảo dưỡng (VNĐ) |
| `status` | `text` | `NOT NULL DEFAULT 'pending'` | `pending` (chờ), `in_progress` (đang làm), `completed` (xong), `cancelled` (hủy) |
| `affects_service` | `boolean` | `NOT NULL DEFAULT false` | Có tạm dừng thiết bị ảnh hưởng cư dân không |
| `service_interruption_note` | `text` | `NULL` | Ghi chú thông báo cư dân (vd: "Tạm ngưng thang từ 09:00 - 11:30") |
| `notes` | `text` | `NULL` | Nhật ký chi tiết, tình trạng linh kiện |
| `created_by` | `uuid` | `NULL, REFERENCES users(id)` | Người lập phiếu |
| `created_at` | `timestamptz` | `NOT NULL DEFAULT now()` | Thời điểm tạo |
| `updated_at` | `timestamptz` | `NOT NULL DEFAULT now()` | Thời điểm cập nhật |

---

## 4. Tự Động Hóa & Triggers (Postgres Database Logic)

### 4.1. Trigger: Tự Động Cập Nhật Vòng Đời Thiết Bị (`handle_equipment_task_completion`)
* Khi một dòng trong `equipment_maintenance_tasks` được cập nhật sang `status = 'completed'`:
  - `building_equipments.last_maintenance_date = coalesce(NEW.actual_end, now())`
  - `building_equipments.next_maintenance_date = coalesce(NEW.actual_end, now()) + (building_equipments.maintenance_interval_days || ' days')::interval`
  - `building_equipments.status = 'operational'`
* Khi một dòng được cập nhật sang `status = 'in_progress'` có `affects_service = true`:
  - `building_equipments.status = 'under_maintenance'`

### 4.2. Trigger: Tự Động Gửi Thông Báo Tới Cư Dân Khi Gián Đoạn Dịch Vụ
* Khi task có `affects_service = true` chuyển sang `in_progress`:
  - Hệ thống tự động tạo bản ghi trong bảng `notifications` cho tất cả cư dân sinh sống tại `building` tương ứng với tiêu đề:
    `[Bảo trì thiết bị] [Tên thiết bị] tạm dừng hoạt động để bảo dưỡng`.

### 4.3. RPC: Quét Nhắc Hạn Bảo Trì Sắp Đến Hạn (`check_upcoming_equipment_maintenance`)
* Tìm các thiết bị có `next_maintenance_date <= (now() + interval '7 days')` và `status != 'under_maintenance'`.
* Tự động sinh thông báo nhắc nhở nội bộ cho Ban Quản Lý và Kỹ Thuật Viên.

---

## 5. Chính Sách Bảo Mật (Row Level Security - RLS)

* **`building_equipments`**:
  - `SELECT`: Mọi người dùng đã đăng nhập (Cư dân & BQL) đều xem được danh mục thiết bị và tình trạng hoạt động (để cư dân biết thang máy/máy bơm nào đang vận hành).
  - `INSERT / UPDATE / DELETE`: Chỉ người dùng có vai trò `management` hoặc được ủy quyền kỹ thuật `technician`.
* **`equipment_maintenance_tasks`**:
  - `SELECT`: BQL và Kỹ thuật viên xem đầy đủ thông tin (kể cả chi phí `cost` và hợp đồng).
  - Cư dân: Chỉ xem được các task có `affects_service = true` (để theo dõi lịch bảo dưỡng tạm ngắt tiện ích). Cột `cost` sẽ được lọc không hiển thị trên giao diện cư dân.
  - `INSERT / UPDATE / DELETE`: Chỉ `management` hoặc `technician`.

---

## 6. Thiết Kế Giao Diện (Flutter UI/UX)

### 6.1. Ban Quản Lý (Management)
1. **Màn hình Danh mục Thiết bị & Bảo trì (`EquipmentManagementScreen` - `/management/equipment`)**:
   - Thống kê nhanh trên đầu trang: Tổng thiết bị, Đang hoạt động tốt (Xanh), Đang bảo trì (Cam), Sắp đến hạn trong 7 ngày (Vàng).
   - Bộ lọc theo Tòa nhà (`Tất cả`, `Tòa A`, `Tòa B`...) và Danh mục (`Thang máy`, `PCCC`, `Máy bơm`, `Máy phát điện`...).
   - 2 Tab chuyển đổi:
     - **Tab 1: Danh sách Thiết bị**: Thẻ thiết bị hiển thị mã, vị trí, chu kỳ, ngày bảo dưỡng gần nhất và ngày dự kiến tiếp theo, nút thêm thiết bị mới.
     - **Tab 2: Lịch & Phiếu bảo trì**: Danh sách các đợt bảo trì (Sắp tới, Đang làm, Lịch sử), hiển thị kỹ thuật viên phụ trách, đơn vị ngoài, chi phí và trạng thái.
2. **Màn hình Chi tiết Thiết bị (`EquipmentDetailScreen`)**:
   - Thông số kỹ thuật, bảo hành, trạng thái hiện tại.
   - Toàn bộ lịch sử các lần bảo dưỡng của thiết bị đó kèm chi phí tích lũy.
   - Nút "Tạo phiếu bảo trì ngay".
3. **Dialog / Form Phiếu Bảo Trì**:
   - Chọn loại (Định kỳ / Đột xuất / Kiểm định), ngày giờ dự kiến, chọn Kỹ thuật viên tòa nhà hoặc nhập Nhà thầu ngoài (tên, hotline).
   - Ô nhập chi phí ước tính / thực tế.
   - Switch chọn: "Có tạm dừng thiết bị (Ảnh hưởng cư dân)".

### 6.2. Cư Dân (Resident)
1. **Thẻ Cảnh báo Bảo trì trên Trang Chủ (`ResidentHomeScreen`)**:
   - Khi có thiết bị tại tòa nhà của cư dân đang ở trạng thái `under_maintenance` có `affects_service = true`:
   - Hiển thị Banner màu vàng nổi bật: *"Thang máy A1 đang được bảo dưỡng định kỳ. Dự kiến hoàn tất lúc 11:30. Xin lỗi quý cư dân vì sự bất tiện này."*

---

## 7. Kế Hoạch Kiểm Thử (Testing Matrix)

1. **Unit Test Models:**
   - Parse JSON $\leftrightarrow$ Object cho `BuildingEquipmentModel` và `EquipmentMaintenanceTaskModel`.
   - Kiểm tra các getter tiện ích (`isOverdue`, `isUpcomingWithin7Days`, `statusBadgeColor`).
2. **Unit Test Repository:**
   - Test `getEquipments({building, category, status})`.
   - Test `createEquipment()`, `updateEquipment()`, `deleteEquipment()`.
   - Test `getMaintenanceTasks({equipmentId, status})`.
   - Test `createMaintenanceTask()`, `updateTaskStatus()`.
3. **Database Migration Test:**
   - Test Trigger tự động tính lại `next_maintenance_date` khi task `completed`.
   - Test Trigger tự động chuyển trạng thái `under_maintenance`.
4. **Widget Test:**
   - Test hiển thị danh mục thiết bị, chip đếm số lượng theo trạng thái.
   - Test form tạo thiết bị và phân công phiếu bảo trì.
   - Test banner cảnh báo gián đoạn dịch vụ trên giao diện cư dân.
