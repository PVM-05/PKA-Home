# Đặc Tả Thiết Kế: Cảnh Báo SLA Đa Tầng, Phân Công Chuyên Môn & Quản Lý Vật Tư Tiêu Hao Sự Cố (D3)

- **Mã tính năng:** D3 (trong `COMMERCIAL_PRODUCT_ROADMAP.md`)
- **Tác giả:** Antigravity Engineering
- **Ngày tạo:** 2026-11-02
- **Trạng thái:** Bản thảo đề xuất (Draft)

---

## 1. Mục Tiêu & Bối Cảnh Nghiệp Vụ

Trong vận hành chung cư và khu căn hộ dịch vụ thương mại, tốc độ và tính minh bạch khi giải quyết sự cố kỹ thuật là yếu tố then chốt quyết định mức độ hài lòng của cư dân (CSAT) và tỷ lệ tái ký hợp đồng.

### Các Vấn Đề Thực Tế Cần Giải Quyết:
1. **Thiếu cam kết thời gian (SLA)**: Sự cố gửi lên dễ bị "bỏ quên", không rõ khi nào kỹ thuật viên đến xử lý dẫn đến cư dân bức xúc.
2. **Phân công chưa tối ưu**: Người tiếp nhận phân bổ ngẫu nhiên thay vì giao đúng nhân sự có chuyên môn (điện, nước, cơ khí, PCCC).
3. **Thất thoát vật tư sửa chữa**: Kho vật tư kỹ thuật (bóng đèn, van vòi, phụ kiện) bị thất thoát, không ghi nhận được lịch sử xuất kho gắn với từng sự cố.
4. **Mâu thuẫn chi phí sửa chữa**: Không rõ ràng giữa phần sở hữu chung (tòa nhà chi trả) và phần sở hữu riêng của cư dân (cư dân thanh toán), gây khó khăn cho kế toán khi thu tiền.

### Giải Pháp Đạt Chuẩn Thương Mại Của PKA-Home (D3):
- **SLA đa tầng tự động**: Tính toán hạn xử lý tự động theo mức độ ưu tiên (`high`: 2h, `medium`: 24h, `low`: 72h). Hệ thống giám sát thời gian thực và cảnh báo 3 mức màu: Xanh (Đúng hạn), Vàng (Sắp trễ hạn < 2h), Đỏ (Đã vi phạm SLA).
- **Phân công theo chuyên môn**: Phân loại danh mục sự cố (`electrical`, `plumbing`, `construction`, `elevator`, `fire_safety`, `other`) và hỗ trợ gán kỹ thuật viên tương ứng.
- **Quản lý kho vật tư tiêu hao (`maintenance_materials`)**: Quản lý số lượng tồn kho, định mức tối thiểu cảnh báo hết hàng.
- **Kê khai vật tư nghiệm thu (`issue_materials`)**: Kỹ thuật viên chụp ảnh nghiệm thu kèm kê khai vật tư sử dụng. Hệ thống hỗ trợ tích chọn "Tính phí vào hóa đơn căn hộ" (nếu là sở hữu riêng) hoặc "Chi phí vận hành tòa nhà" (nếu là sở hữu chung).

---

## 2. Kiến Trúc Dữ Liệu (Database Schema & RPCs)

### 2.1. Cập Nhật Bảng `issue_reports`
Bổ sung các cột phục vụ giám sát SLA và chuyên môn:
```sql
ALTER TABLE issue_reports
  ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'other',
  ADD COLUMN IF NOT EXISTS sla_deadline TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS acknowledged_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS sla_status TEXT NOT NULL DEFAULT 'on_time';
```

- `category`: `electrical` (Điện), `plumbing` (Nước), `construction` (Xây dựng/Nội thất), `elevator` (Thang máy), `fire_safety` (PCCC), `other` (Khác).
- `sla_deadline`: Mốc thời gian hoàn thành cam kết.
- `acknowledged_at`: Thời điểm BQL/Kỹ thuật viên bấm tiếp nhận.
- `resolved_at`: Thời điểm hoàn tất sự cố kèm minh chứng.
- `sla_status`: `on_time` (Đúng hạn), `warning` (Sắp trễ), `breached` (Đã trễ hạn).

### 2.2. Trigger Tự Động Tính `sla_deadline`
Khi tạo bản ghi mới trong `issue_reports`, trigger tự động gán `sla_deadline`:
- `priority = 'high'`: `created_at + INTERVAL '2 hours'`
- `priority = 'medium'`: `created_at + INTERVAL '24 hours'`
- `priority = 'low'`: `created_at + INTERVAL '72 hours'`

### 2.3. Bảng Kho Vật Tư Tiêu Hao `maintenance_materials`
```sql
CREATE TABLE IF NOT EXISTS maintenance_materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID REFERENCES buildings(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    name TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'other',
    unit TEXT NOT NULL DEFAULT 'cái',
    unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
    stock_quantity INT NOT NULL DEFAULT 0,
    min_stock_alert INT NOT NULL DEFAULT 5,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_material_code UNIQUE (building_id, code)
);
```

### 2.4. Bảng Vật Tư Đã Dùng Cho Sự Cố `issue_materials`
```sql
CREATE TABLE IF NOT EXISTS issue_materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_report_id UUID NOT NULL REFERENCES issue_reports(id) ON DELETE CASCADE,
    material_id UUID NOT NULL REFERENCES maintenance_materials(id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0,
    total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    is_chargeable BOOLEAN NOT NULL DEFAULT false,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 2.5. Các Hàm Stored Procedure (RPCs)
1. **`get_issue_sla_stats(p_building_id UUID)`**:
   - Trả về: `total_issues`, `on_time_count`, `warning_count`, `breached_count`, `compliance_rate` (%).
2. **`record_issue_materials_usage(p_issue_id UUID, p_materials JSONB, p_staff_id UUID)`**:
   - Khóa bản ghi vật tư `FOR UPDATE`.
   - Kiểm tra tồn kho và tự động trừ số lượng trong `maintenance_materials.stock_quantity`.
   - Thêm bản ghi vào `issue_materials`.
3. **`charge_issue_materials_to_invoice(p_issue_id UUID, p_invoice_id UUID)`**:
   - Quét các vật tư có `is_chargeable = true` thuộc sự cố.
   - Tự động thêm dòng mục `invoice_items` tương ứng với loại phí `service` (Sửa chữa kỹ thuật căn hộ).

---

## 3. Tầng Dữ Liệu & Riverpod Providers

### 3.1. Models (Dart)
- **`MaintenanceMaterialModel`**:
  - `id`, `buildingId`, `code`, `name`, `category`, `unit`, `unitPrice`, `stockQuantity`, `minStockAlert`.
  - Helpers: `isLowStock`, `categoryDisplayName`, `priceFormatted`.
- **`IssueMaterialUsageModel`**:
  - `id`, `issueReportId`, `materialId`, `materialName`, `quantity`, `unit`, `unitPrice`, `totalAmount`, `isChargeable`, `note`.
  - Helpers: `totalAmountFormatted`, `chargeableDisplayName`.
- **`IssueSlaStatsModel`**:
  - `totalIssues`, `onTimeCount`, `warningCount`, `breachedCount`, `complianceRate`.
- **Mở rộng `IssueModel`**:
  - `category`, `slaDeadline`, `acknowledgedAt`, `resolvedAt`, `slaStatus`, `materials` (`List<IssueMaterialUsageModel>`).
  - Getter tính toán thời gian SLA thời gian thực: `remainingSlaDuration`, `isSlaBreached`, `isSlaWarning`, `slaRemainingFormatted`, `categoryDisplayName`.

### 3.2. Repository & Offline Fallback Engine
- `IssueRepository` / `ManagementRepository`:
  - `fetchMaterials({String? buildingId, String? category})`
  - `fetchIssueMaterials(String issueId)`
  - `recordIssueMaterials({required String issueId, required List<Map<String, dynamic>> materials, required String staffId})`
  - `fetchSlaStats({String? buildingId})`
  - In-memory fallback dataset gồm 10 loại vật tư thông dụng (bóng đèn, van nước, át-tô-mát, dây điện, keo silicone) đảm bảo chạy mượt mà ngay cả khi không có kết nối Supabase.

### 3.3. Providers
- `maintenanceMaterialsProvider`: Danh sách vật tư kho tòa nhà.
- `issueMaterialsProvider(issueId)`: Danh sách vật tư của sự cố cụ thể.
- `issueSlaStatsProvider`: Thống kê KPI SLA toàn tòa nhà.

---

## 4. Thiết Kế Giao Diện Người Dùng (UI/UX)

### 4.1. Màn Hình Quản Lý Sự Cố BQL (`IssueManagementScreen`)
- **Dải Thẻ KPI SLA**:
  - Tổng tiếp nhận
  - Đang trong hạn (Xanh lá)
  - Cảnh báo sắp trễ < 2h (Vàng hổ phách)
  - Vi phạm SLA (Đỏ cảnh báo)
  - Tỷ lệ hoàn thành đúng hạn (%)
- **Danh sách Sự cố (Card phong cách hiện đại)**:
  - Header: Mã căn hộ, Tên người gửi, Badge Chuyên môn (`[Điện]`, `[Nước]`), Badge SLA đếm ngược với màu động.
  - Nội dung: Mô tả sự cố, hình ảnh đính kèm trước sửa chữa.
  - Footer: Tên kỹ thuật viên được giao việc, nút "Tiếp nhận & Phân công", nút "Nghiệm thu & Vật tư".
- **Hộp thoại Tiếp nhận & Phân công chuyên môn (`AssignTechnicianDialog`)**:
  - Hiển thị danh sách kỹ thuật viên phân loại theo vai trò và chuyên môn.
  - Cho phép cấu hình gia hạn SLA (nếu có lý do khách quan).
- **Bảng Nghiệm thu & Xuất kho Vật tư (`ResolveIssueWithMaterialsSheet`)**:
  - Tải lên ảnh nghiệm thu (Ảnh "Sau khi sửa").
  - Lưới thêm vật tư đã dùng:
    - Chọn vật tư từ danh mục kho (có hiển thị số lượng tồn kho).
    - Nhập số lượng sử dụng.
    - Công tắc chuyển đổi: **"Tính phí vào hóa đơn cư dân"** (Mặc định bật nếu sự cố diễn ra trong căn hộ riêng).
  - Tự động hiển thị tổng tiền vật tư dự kiến kết chuyển.

### 4.2. Màn Hình Kho Vật Tư Tiêu Hao (`MaintenanceMaterialsScreen`)
- Quản lý danh mục vật tư của tòa nhà: Tra cứu, cập nhật giá, nhập thêm số lượng kho, cảnh báo khi tồn kho chạm ngưỡng đỏ (`stock <= min_stock_alert`).

### 4.3. Màn Hình Cư Dân (`ResidentIssueScreen`, `IssueDetailScreen`, `CreateIssueScreen`)
- **Tạo sự cố (`CreateIssueScreen`)**:
  - Bổ sung chọn Chuyên môn (Điện, Nước, Khóa cửa/Nội thất, Khác).
  - Hiển thị cam kết thời gian phản hồi: *"Sự cố khẩn cấp sẽ được xử lý trong vòng 2 giờ"*.
- **Chi tiết sự cố (`IssueDetailScreen`)**:
  - Thanh tiến trình trực quan 4 bước: Đã gửi -> Đã tiếp nhận -> Đang xử lý -> Đã hoàn tất.
  - Đồng hồ đếm ngược SLA minh bạch.
  - Danh mục vật tư đã thay thế (nếu có tính phí, hiển thị rõ số tiền sẽ đưa vào hóa đơn dịch vụ kỳ tới).

---

## 5. Kế Hoạch Kiểm Thử Tự Động (TDD Plan)

1. **Migration Integration Test** (`test/integration/issue_sla_and_materials_migration_test.dart`):
   - Kiểm tra các cột SLA và category trên `issue_reports`.
   - Kiểm tra bảng `maintenance_materials`, `issue_materials`.
   - Kiểm tra các RPCs tính toán SLA và xuất kho vật tư.
2. **Data Models Unit Tests**:
   - `test/data/models/maintenance_material_model_test.dart`
   - `test/data/models/issue_material_usage_model_test.dart`
   - `test/data/models/issue_sla_info_test.dart`
3. **Repository Unit Tests**:
   - `test/data/repositories/issue_repository_materials_test.dart`
4. **Widget Tests**:
   - `test/features/management/screens/issue_management_sla_test.dart`
5. **Integration Workflow Test**:
   - `test/integration/issue_sla_and_materials_workflow_test.dart`

---

## 6. Tiêu Chí Nghiệm Thu (Acceptance Criteria)
- [ ] Migration SQL được áp dụng an toàn, đầy đủ RLS policies cho bảng kho vật tư.
- [ ] Sự cố tạo mới tự động có `sla_deadline` và trạng thái `on_time`.
- [ ] Kỹ thuật viên nghiệm thu có thể kê khai vật tư, số lượng tự động trừ trong kho.
- [ ] Vật tư đánh dấu tính phí được lưu vết đầy đủ để kết chuyển hóa đơn.
- [ ] Đạt 100% tests pass và 0 issue static analysis (`dart analyze`).

