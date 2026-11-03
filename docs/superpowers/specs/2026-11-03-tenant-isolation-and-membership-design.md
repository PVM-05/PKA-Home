# Đặc Tả Thiết Kế: Cách Ly Tenant & Mô Hình Membership Đa Tầng (SEC-01, SEC-02, SaaS-01)

**Mã tài liệu:** `SPEC-HARDENING-01`  
**Giai đoạn:** GIAI ĐOẠN 0 – Product Hardening (Ưu tiên cao nhất)  
**Tác giả:** Antigravity  
**Ngày lập:** 03/11/2026  
**Trạng thái:** Bản dự thảo kỹ thuật chờ phê duyệt  

---

## 1. Bối Cảnh & Vấn Đề Cần Giải Quyết (Problem Statement)

Bản kiểm toán mã nguồn ngày 03/11/2026 đã chỉ ra các lỗ hổng P0 nghiêm trọng trong hệ thống:
1. **RLS chưa thực sự cách ly Tenant:**
   - Trong `20261027_03_multi_tenancy_organizations_and_buildings.sql`, các bảng `organizations`, `buildings`, `building_staff` đều đang dùng `FOR SELECT TO authenticated USING (true)`.
   - Bảng `maintenance_fund_transactions` trong `20261027_05_maintenance_fund_ledger.sql` cũng dùng `USING (true)`.
   - Hậu quả: Bất kỳ người dùng đã đăng nhập nào (kể cả cư dân của Công ty A) cũng có thể truy vấn và đọc toàn bộ thông tin tổ chức B, tòa nhà B, nhân viên B và sổ quỹ tài chính B.
2. **Thiếu mô hình Membership đa tầng:**
   - Hệ thống phụ thuộc vào trường `users.role` toàn cục.
   - Một người dùng không thể đóng nhiều vai trò tại nhiều tòa nhà khác nhau (ví dụ: vừa là Kế toán tại Tòa A, vừa là Cư dân tại Tòa B).
   - Thu hồi quyền tại một tòa nhà có nguy cơ làm mất quyền truy cập toàn cục hoặc không thu hồi được ngay lập tức.

---

## 2. Mục Tiêu & Tiêu Chí Nghiệm Thu (Success Criteria)

- [ ] **SEC-01 - Cách ly Tenant 100%:** Người dùng thuộc Tổ chức A tuyệt đối không thể đọc hoặc chỉnh sửa dữ liệu của Tổ chức B qua Supabase Client / GraphQL / PostgREST.
- [ ] **SEC-02 - Siết chặt RLS:** Xóa bỏ hoàn toàn tất cả chính sách `USING (true)` trên `organizations`, `buildings`, `apartments`, `building_memberships`, `maintenance_funds`.
- [ ] **SaaS-01 - Membership Đa Cấp:** Hỗ trợ 1 tài khoản có nhiều vai trò tại các tòa nhà/tổ chức khác nhau; hỗ trợ ủy quyền có thời hạn (`expires_at`).
- [ ] **Data Security Helper Functions:** Hàm bảo mật trong PostgreSQL kiểm tra quyền tập trung, tối ưu hiệu năng và an toàn trước SQL injection.
- [ ] **Không làm gián đoạn mã nguồn hiện có:** Tự động di chuyển dữ liệu cũ từ `building_staff` và `residents_apartments` sang `building_memberships`.

---

## 3. Kiến Trúc Cơ Sở Dữ Liệu & Migration SQL

### 3.1. Bảng `organization_memberships`
Quản lý quyền sở hữu và quản trị cấp Tổ chức / Công ty vận hành:
```sql
CREATE TABLE IF NOT EXISTS public.organization_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    org_role VARCHAR(30) NOT NULL DEFAULT 'member', -- 'owner', 'admin', 'member'
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(organization_id, user_id)
);
```

### 3.2. Bảng `building_memberships`
Quản lý vai trò cụ thể tại từng cơ sở / tòa nhà:
```sql
CREATE TABLE IF NOT EXISTS public.building_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    building_role VARCHAR(30) NOT NULL, -- 'manager', 'accountant', 'technician', 'security', 'receptionist', 'board_member', 'resident'
    apartment_id UUID REFERENCES public.apartments(id) ON DELETE SET NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    expires_at TIMESTAMPTZ DEFAULT NULL, -- Hết hạn ủy quyền
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bm_user_building ON public.building_memberships(user_id, building_id);
CREATE INDEX IF NOT EXISTS idx_bm_active ON public.building_memberships(is_active) WHERE is_active = true;
```

### 3.3. Các Hàm Hỗ Trợ Phân Quyền (Security Functions)
Sử dụng `SECURITY DEFINER` và `STABLE` để PostgREST tối ưu kế hoạch thực thi:

1. **`get_user_accessible_organizations(p_user_id UUID DEFAULT auth.uid())`**:
   - Trả về danh sách `organization_id` mà user là thành viên kích hoạt (`is_active = true`).
2. **`get_user_accessible_buildings(p_user_id UUID DEFAULT auth.uid())`**:
   - Trả về danh sách `building_id` mà user có `building_memberships` kích hoạt VÀ chưa hết hạn (`expires_at IS NULL OR expires_at > now()`), HOẶC user là `owner`/`admin` của tổ chức sở hữu tòa nhà đó.
3. **`has_building_role(p_building_id UUID, p_required_roles TEXT[])`**:
   - Trả về `BOOLEAN`: Xác nhận người gọi có một trong các vai trò yêu cầu tại tòa nhà tương ứng.

### 3.4. Hệ Thống RLS Mới (Tenant Isolation)

| Bảng | Thao tác | Điều kiện RLS Mới |
| :--- | :--- | :--- |
| `organizations` | `SELECT` | `id IN (SELECT get_user_accessible_organizations())` |
| `organizations` | `UPDATE/DELETE` | Là `owner` của tổ chức (`org_role = 'owner'`) |
| `buildings` | `SELECT` | `id IN (SELECT get_user_accessible_buildings())` |
| `buildings` | `ALL` | Là `owner` hoặc `admin` của tổ chức sở hữu tòa nhà |
| `building_memberships` | `SELECT` | Thuộc tòa nhà mình có quyền xem (`building_id IN (SELECT get_user_accessible_buildings())`) |
| `apartments` | `SELECT` | Thuộc tòa nhà mà người dùng có quyền quản trị, HOẶC là căn hộ gắn với `apartment_id` của cư dân |
| `maintenance_funds` | `SELECT` | `building_id IN (SELECT get_user_accessible_buildings())` |
| `maintenance_funds` | `UPDATE` | `has_building_role(building_id, ARRAY['manager', 'accountant'])` |
| `maintenance_fund_transactions` | `SELECT` | `building_id IN (SELECT get_user_accessible_buildings())` |
| `maintenance_fund_transactions` | `INSERT` | `has_building_role(building_id, ARRAY['manager', 'accountant'])` |

---

## 4. Tầng Dữ Liệu Dart (Flutter Client)

1. **Models:**
   - [`OrganizationMembershipModel`](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/data/models/organization_membership_model.dart): `id`, `organizationId`, `userId`, `orgRole`, `isActive`.
   - [`BuildingMembershipModel`](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/data/models/building_membership_model.dart): `id`, `buildingId`, `userId`, `buildingRole`, `apartmentId`, `isActive`, `expiresAt`.
2. **Repository:**
   - [`MembershipRepository`](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/data/repositories/membership_repository.dart):
     - `fetchUserBuildingMemberships(String userId)`
     - `fetchBuildingMembers(String buildingId)`
     - `assignBuildingMembership(...)`
     - `revokeBuildingMembership(...)`

---

## 5. Chiến Lược Kiểm Thử (Testing Strategy)

1. **Kiểm thử Migration SQL (`test/database/tenant_isolation_migration_test.dart`):**
   - Kiểm tra định nghĩa bảng `organization_memberships`, `building_memberships`.
   - Kiểm tra các hàm `get_user_accessible_organizations`, `get_user_accessible_buildings`, `has_building_role`.
   - Kiểm tra không còn bất kỳ policy `USING (true)` nào trên các bảng nhạy cảm.
2. **Kiểm thử Data Model (`test/data/models/membership_model_test.dart`):**
   - Khởi tạo, parse `fromJson`, xuất `toJson` và `copyWith`.
3. **Kiểm thử Repository & Logic Phân Quyền (`test/data/repositories/membership_repository_test.dart`):**
   - Truy vấn danh sách membership theo tòa nhà.
   - Kiểm tra kiểm soát vai trò và trạng thái hết hạn.
