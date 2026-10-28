# Đặc Tả Kỹ Thuật: Giai Đoạn B - Kiến Trúc Đa Tòa Nhà & Tổ Chức Vận Hành (Multi-Tenancy Architecture)

**Tác giả:** Antigravity Agent & PKA-Home Team  
**Ngày lập:** 2026-10-27  
**Trạng thái:** Bản thiết kế hoàn chỉnh (Ready for Implementation Plan)  
**Mục tiêu:** Chuyển đổi hệ thống từ đơn tòa nhà (Single Building) sang hệ thống đa tổ chức, đa tòa nhà (B2B SaaS Multi-Tenancy) với khả năng cách ly dữ liệu triệt để, cho phép Ban Quản lý vận hành đồng thời nhiều tòa nhà và đảm bảo 100% tính tương thích ngược với dữ liệu và test suite hiện có.

---

## 1. Bối Cảnh & Vấn Đề (Context & Problem Statement)

1. **Ràng buộc mã căn hộ toàn cục (`UNIQUE(code)`):** Hiện tại bảng `apartments` đặt ràng buộc độc nhất trên toàn bộ hệ thống (`code VARCHAR(10) NOT NULL UNIQUE`). Trong thực tế B2B SaaS, nhiều chung cư khác nhau đều có các căn trùng tên (ví dụ: `A0110`, `B0205`). Ràng buộc này ngăn cản việc thêm tòa nhà thứ 2 vào hệ thống.
2. **Thiếu khái niệm Đơn vị Vận hành (Organization) và Cụm Tòa Nhà (Building):** Các bảng tiện ích (`building_amenities`), thông báo (`announcements`), quỹ bảo trì (`maintenance_funds`) và biểu phí (`fee_schedules`) đang giả định chỉ có duy nhất một tòa nhà đơn lẻ.
3. **Phân quyền và bảo mật (RLS Isolation):** Chưa có cơ chế phân tách dữ liệu ở tầng CSDL để nhân viên tòa Park 1 không vô tình xem hoặc sửa đổi hóa đơn, sự cố hay danh sách cư dân của tòa Park 2.

---

## 2. Thiết Kế Cơ Sở Dữ Liệu (Database Schema Design)

### 2.1. Các bảng mới

#### A. Bảng Tổ chức / Đơn vị Vận hành (`public.organizations`)
Quản lý các công ty quản lý bất động sản (khách hàng B2B của nền tảng):
```sql
CREATE TABLE IF NOT EXISTS public.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    logo_url TEXT,
    contact_phone TEXT,
    contact_email TEXT,
    status TEXT NOT NULL DEFAULT 'active', -- 'active' | 'suspended' | 'trial'
    settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

#### B. Bảng Tòa nhà / Khu chung cư (`public.buildings`)
Quản lý các tòa nhà trực thuộc tổ chức:
```sql
CREATE TABLE IF NOT EXISTS public.buildings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    address TEXT,
    total_floors INT NOT NULL DEFAULT 20,
    total_units INT NOT NULL DEFAULT 200,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

#### C. Bảng Phân công Nhân viên Quản lý Tòa nhà (`public.building_staff`)
Liên kết giữa người dùng thuộc Ban Quản lý và các tòa nhà họ được phân quyền quản trị:
```sql
CREATE TABLE IF NOT EXISTS public.building_staff (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    assigned_role TEXT NOT NULL DEFAULT 'staff', -- 'building_manager' | 'staff' | 'accountant' | 'technician'
    is_primary BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, building_id)
);
```

---

### 2.2. Bổ sung `building_id` và Cập nhật Ràng buộc

Các bảng nghiệp vụ sẽ được gắn thêm cột `building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE`:
1. **`apartments`:**
   - Thêm cột `building_id UUID NOT NULL`.
   - Bỏ ràng buộc `UNIQUE(code)`.
   - Thêm ràng buộc tổ hợp `UNIQUE(building_id, code)`.
2. **`announcements`:**
   - Thêm cột `building_id UUID`. Cho phép `NULL` khi `is_global = true` (thông báo toàn tổ chức).
3. **`building_amenities`:**
   - Thêm cột `building_id UUID NOT NULL`.
4. **`fee_schedules`:**
   - Thêm cột `building_id UUID NOT NULL`. Cho phép cấu hình biểu phí linh hoạt cho từng tòa nhà khác nhau.
5. **`maintenance_funds`:**
   - Thêm cột `building_id UUID NOT NULL`. Mỗi tòa nhà có tài khoản quỹ bảo trì 2% riêng biệt theo luật.

---

### 2.3. Chiến lược Khởi tạo Dữ liệu Mặc định (Canonical Seeding & Backfill)

Để đảm bảo toàn bộ dữ liệu hiện có và 430 unit/integration tests đang chạy không bị đứt gãy:
- **Canonical Organization:**
  - `id = '00000000-0000-0000-0000-000000000001'`
  - `name = 'Công ty Quản lý Vận hành Bất động sản PKA'`
  - `slug = 'pka-corp'`
- **Canonical Default Building:**
  - `id = '00000000-0000-0000-0000-000000000002'`
  - `name = 'Tòa nhà Landmark PKA'`
  - `code = 'PKAL'`
  - `organization_id = '00000000-0000-0000-0000-000000000001'`
- **Backfill:**
  - Tất cả các bản ghi hiện tại trong `apartments`, `announcements`, `building_amenities`, `fee_schedules`, `maintenance_funds` sẽ được cập nhật `building_id = '00000000-0000-0000-0000-000000000002'`.
  - Mọi người dùng có role quản trị (`admin`, `manager`, `accountant`, `technician`) sẽ tự động được thêm vào `building_staff` cho tòa nhà mẫu này.

---

### 2.4. Quy Tắc Bảo Mật Row-Level Security (RLS) Multi-Tenant

1. **Đối với Cư dân (`resident`):**
   - Chỉ được `SELECT` thông tin thuộc tòa nhà nơi căn hộ của họ tọa lạc:
     ```sql
     EXISTS (
         SELECT 1 FROM public.residents_apartments ra
         JOIN public.apartments a ON a.id = ra.apartment_id
         WHERE ra.user_id = auth.uid() AND a.building_id = target_table.building_id
     )
     ```
2. **Đối với Ban Quản lý / Nhân viên (`admin`, `manager`, `staff`):**
   - Chỉ được thao tác với dữ liệu của các tòa nhà mà họ được chỉ định trong `building_staff`:
     ```sql
     EXISTS (
         SELECT 1 FROM public.building_staff bs
         WHERE bs.user_id = auth.uid() AND bs.building_id = target_table.building_id
     )
     ```
   - Trường hợp đặc biệt: `super_admin` của Organization có quyền xem và quản lý toàn bộ các tòa nhà thuộc tổ chức đó.

---

## 3. Kiến Trúc Ứng Dụng Phía Client (Flutter & Riverpod)

### 3.1. Mô hình Dữ Liệu (Models)
- `lib/data/models/organization_model.dart`: ánh xạ bảng `organizations`.
- `lib/data/models/building_model.dart`: ánh xạ bảng `buildings`.
- `lib/data/models/building_staff_model.dart`: ánh xạ bảng `building_staff`.

### 3.2. Quản lý Trạng thái Tòa nhà Hiện hành (Tenancy State Management)
- Tạo `lib/data/repositories/building_repository.dart`:
  - `getUserBuildings(String userId)`: Lấy danh sách các tòa nhà mà tài khoản có quyền truy cập.
  - `getBuildingById(String buildingId)`.
- Tạo `lib/data/providers/building_provider.dart`:
  - `userBuildingsProvider`: `FutureProvider<List<BuildingModel>>` cung cấp danh sách tòa nhà nhân viên quản lý.
  - `activeBuildingIdProvider`: `StateNotifierProvider<BuildingIdNotifier, String?>` lưu giữ ID tòa nhà đang được chọn. Khi ứng dụng khởi động, nạp từ `SharedPreferences`; nếu chưa có, ưu tiên tòa nhà đầu tiên hoặc tòa nhà mẫu.
  - `activeBuildingProvider`: Provider dẫn xuất cung cấp chi tiết `BuildingModel` đang kích hoạt.
  - Đối với cư dân: `residentActiveBuildingProvider` tự động xác định tòa nhà từ căn hộ của cư dân.

### 3.3. Tích hợp Giao diện Người dùng (UI Layer)
- Thêm Widget `BuildingSwitcherDropdown`:
  - Đặt trên `AppBar` của `ManagementHomeScreen` hoặc giao diện Dashboard BQL.
  - Khi nhân viên quản lý nhiều hơn 1 tòa nhà: hiển thị dropdown cho phép chuyển đổi nhanh giữa các tòa (Park 1, Park 2...).
  - Khi đổi tòa nhà: tự động kích hoạt `ref.invalidate(...)` để tải lại danh sách căn hộ, hóa đơn, sự cố và chỉ số công tơ tương ứng với tòa nhà đó.
  - Khi nhân viên chỉ phụ trách 1 tòa: hiển thị tên tòa nhà dưới dạng nhãn tĩnh trang trọng, không có menu thả xuống.

---

## 4. Kế Hoạch Kiểm Thử & Xác Minh (Verification Strategy)

1. **Migration Verification Tests:**
   - Viết test kiểm tra cú pháp và sự tồn tại của migration `20261027_03_multi_tenancy_organizations_and_buildings.sql`.
   - Kiểm tra việc tạo các bảng `organizations`, `buildings`, `building_staff`.
   - Kiểm tra cột `building_id` trên `apartments`, `announcements`, `fee_schedules`, `maintenance_funds`.
   - Kiểm tra ràng buộc `UNIQUE(building_id, code)` trên bảng `apartments`.
2. **Unit Tests:**
   - Test Serialization/Deserialization cho `BuildingModel`, `OrganizationModel`, `BuildingStaffModel`.
   - Test `BuildingRepository` truy vấn danh sách tòa nhà theo người dùng.
   - Test `activeBuildingProvider` chuyển đổi trạng thái tòa nhà chính xác.
3. **UI / Widget Tests:**
   - Test `BuildingSwitcherDropdown` hiển thị danh sách tòa nhà và kích hoạt đổi tòa.
4. **Hồi quy toàn diện (Full Regression):**
   - Chạy `flutter analyze` (đạt 0 errors, 0 warnings).
   - Chạy `flutter test` toàn bộ 430+ tests, đảm bảo 100% test case tiếp tục pass.
