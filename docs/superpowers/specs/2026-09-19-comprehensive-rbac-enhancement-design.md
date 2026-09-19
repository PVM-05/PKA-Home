# Đặc Tả Thiết Kế: Hệ Thống RBAC Toàn Diện & Trải Nghiệm Vai Trò (PKA-Home)

- **Ngày tạo**: 2026-09-19
- **Trạng thái**: Đã phê duyệt thiết kế kiến trúc
- **Tác giả**: Antigravity & Nhóm phát triển PKA-Home

---

## 1. Mục Tiêu & Bối Cảnh

Hệ thống phân quyền dựa trên vai trò (RBAC) trước đây đã bước đầu phân tách các vai trò: Quản trị viên (`admin`), Kế toán (`accountant`), Kỹ thuật viên (`technician`) và Cư dân (`resident`). Tuy nhiên, hệ thống còn tồn tại các hạn chế:
1. **Lỗ hổng Least Privilege ở tầng CSDL**: Hàm `is_management()` cũ gộp cả `accountant` và `technician`, vô tình cho phép nhân viên kỹ thuật/kế toán toàn quyền `INSERT/UPDATE/DELETE` trên các bảng quản trị căn hộ, thông báo, cẩm nang.
2. **Thiếu lớp phòng thủ thứ 2 (Defense-in-Depth) ở tầng UI**: Các màn hình con chưa được bảo vệ bằng guard, dẫn tới nguy cơ hiển thị màn hình trống hoặc lỗi RLS không thân thiện khi truy cập sai quyền.
3. **Chưa hỗ trợ nghiệp vụ Ủy quyền tạm thời (Role Delegation)**: Khi Kế toán/Kỹ thuật viên nghỉ phép, hệ thống chưa có cơ chế ủy quyền có giới hạn thời gian an toàn.
4. **Nhật ký hoạt động (Audit Trail) còn đơn điệu**: Chưa có bộ lọc theo người thực hiện và chưa có thống kê hiệu suất Kỹ thuật viên cho Admin.
5. **Trải nghiệm người dùng (UX) khi phân vai trò mới**: Thiếu hướng dẫn onboarding theo vai trò và thiếu bảng ma trận quyền hạn trực quan (Permission Matrix).

---

## 2. Thiết Kế Tầng CSDL & Phân Quyền RLS (Database Security)

### 2.1. Tách bạch `is_management()`, `is_admin()` và `is_staff()`
- **`is_admin()`** (Xác nhận từ `20260916_03_rbac_roles_and_permissions.sql`):
  ```sql
  CREATE OR REPLACE FUNCTION public.is_admin()
  RETURNS BOOLEAN AS $$
  BEGIN
    RETURN EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role IN ('admin', 'management')
    );
  END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;
  ```
  *(Đã bao gồm cả `'management'` để tương thích ngược hoàn toàn với tài khoản BQL cũ).*

- **`is_management()`**: Được chuẩn hóa lại để tương đương với `is_admin()`, đại diện cho nhóm Quản trị viên/BQL cấp cao, **không còn chứa `'accountant'` và `'technician'`**:
  ```sql
  CREATE OR REPLACE FUNCTION public.is_management()
  RETURNS BOOLEAN AS $$
  BEGIN
    RETURN EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role IN ('management', 'admin')
    );
  END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;
  ```

- **`is_staff()`**: Đại diện cho toàn thể nhân sự nội bộ thuộc Ban quản lý (dành cho các thao tác xem chung hoặc hỗ trợ):
  ```sql
  CREATE OR REPLACE FUNCTION public.is_staff()
  RETURNS BOOLEAN AS $$
  BEGIN
    RETURN EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role IN ('management', 'admin', 'accountant', 'technician')
    );
  END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;
  ```

### 2.2. Bảng Ủy quyền Vai trò Tạm thời (`role_delegations`)
```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE IF NOT EXISTS public.role_delegations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delegator_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  delegate_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  delegated_role public.user_role NOT NULL,
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  -- 1. Chặn ủy quyền vai trò admin / management (Chống leo thang đặc quyền)
  CONSTRAINT chk_no_admin_delegation CHECK (delegated_role IN ('accountant', 'technician')),
  -- 2. Thời điểm kết thúc phải sau thời điểm bắt đầu
  CONSTRAINT chk_valid_time_range CHECK (ends_at > starts_at),
  -- 3. Không thể tự ủy quyền cho chính mình
  CONSTRAINT chk_no_self_delegation CHECK (delegator_id <> delegate_id),
  -- 4. Chống chồng lấn khoảng thời gian ủy quyền cho CÙNG 1 VAI TRÒ của 1 nhân sự
  -- (Vẫn cho phép 1 nhân sự được ủy quyền 2 vai trò khác nhau như accountant + technician cùng lúc)
  CONSTRAINT no_overlapping_delegations EXCLUDE USING gist (
    delegate_id WITH =,
    delegated_role WITH =,
    tstzrange(starts_at, ends_at) WITH &&
  )
);

ALTER TABLE public.role_delegations ENABLE ROW LEVEL SECURITY;

-- Policy: Admin toàn quyền quản lý bảng role_delegations
CREATE POLICY "Admin toàn quyền trên role_delegations"
ON public.role_delegations FOR ALL
USING (public.is_admin());

-- Policy: Người được ủy quyền có thể xem bản ghi ủy quyền của mình
CREATE POLICY "Delegate xem ủy quyền của mình"
ON public.role_delegations FOR SELECT
USING (delegate_id = auth.uid());
```

### 2.3. Cập Nhật Hàm RLS Nhận Diện Ủy Quyền
- `is_admin()`: **Giữ nguyên tuyệt đối**, không kiểm tra `role_delegations`.
- `is_accountant()`: Mở rộng kiểm tra ủy quyền `accountant` còn hiệu lực.
  ```sql
  CREATE OR REPLACE FUNCTION public.is_accountant()
  RETURNS BOOLEAN AS $$
  BEGIN
    RETURN EXISTS (
      SELECT 1 FROM public.users 
      WHERE id = auth.uid() AND role IN ('accountant', 'admin', 'management')
    ) OR EXISTS (
      SELECT 1 FROM public.role_delegations
      WHERE delegate_id = auth.uid() 
        AND delegated_role = 'accountant'
        AND now() BETWEEN starts_at AND ends_at
    );
  END;
  $$ LANGUAGE plpgsql SECURITY DEFINER;
  ```
- `is_technician()`: Mở rộng kiểm tra ủy quyền `technician` còn hiệu lực tương tự.

### 2.4. Chuẩn hóa RLS trên các bảng nghiệp vụ
- `apartments`, `residents_apartments`, `announcements`, `building_rules`, `building_amenities`, `emergency_contacts`: Chỉ `is_management()` (hoặc `is_admin()`) mới có quyền tạo/sửa/xóa (`FOR ALL` hoặc `FOR INSERT/UPDATE/DELETE`). Nhân viên nội bộ (`is_staff()`) và cư dân chỉ có quyền `SELECT`.
- `invoices`, `invoice_items`: Quản lý bởi `is_accountant()`.
- `issue_reports`: Cập nhật trạng thái sự cố bởi `is_technician()`.
- `apartment_link_requests`: 
  - **Đồng bộ triệt để cả Phê duyệt (Approve) và Từ chối (Reject)**:
    - RPC `approve_link_request` kiểm tra `public.is_admin()` (đã bao gồm `admin` và `management`).
    - Policy trên bảng `apartment_link_requests` được chuẩn hóa:
      `CREATE POLICY "Admin toàn quyền trên apartment_link_requests" ON public.apartment_link_requests FOR ALL USING (public.is_admin());`
    - Nhờ đó, cả hành động Approve (qua RPC) và Reject (qua UPDATE status) đều dùng chung một gate duy nhất `is_admin()`, hoàn toàn khớp với `AppPermissions.linkRequestManagement.allowedRoles = ['admin', 'management']`.


---

## 3. Nguồn Sự Thật Duy Nhất (Single Source of Truth)

File: `lib/core/constants/permissions.dart`

```dart
class PermissionItem {
  final String key;
  final String name;
  final String category;
  final String description;
  final List<String> allowedRoles;

  const PermissionItem({
    required this.key,
    required this.name,
    required this.category,
    required this.description,
    required this.allowedRoles,
  });

  bool allows(String? role, {List<String> activeDelegations = const []}) {
    if (role == null) return false;
    if (allowedRoles.contains(role)) return true;
    return activeDelegations.any((delRole) => allowedRoles.contains(delRole));
  }
}

class AppPermissions {
  static const invoiceManagement = PermissionItem(
    key: 'invoice_management',
    name: 'Quản lý & Lập hóa đơn',
    category: 'Tài chính & Hóa đơn',
    description: 'Lập hóa đơn, xác nhận thanh toán và thống kê công nợ.',
    allowedRoles: ['admin', 'management', 'accountant'],
  );

  static const issueManagement = PermissionItem(
    key: 'issue_management',
    name: 'Xử lý & Cập nhật phản ánh',
    category: 'Sự cố & Kỹ thuật',
    description: 'Tiếp nhận, xử lý và cập nhật tiến độ sự cố kỹ thuật.',
    allowedRoles: ['admin', 'management', 'technician'],
  );

  static const residentManagement = PermissionItem(
    key: 'resident_management',
    name: 'Quản lý cư dân & Phân vai trò',
    category: 'Cư dân & Căn hộ',
    description: 'Xem danh sách cư dân, đổi vai trò thành viên.',
    allowedRoles: ['admin', 'management'],
  );

  static const linkRequestManagement = PermissionItem(
    key: 'link_request_management',
    name: 'Duyệt liên kết căn hộ',
    category: 'Cư dân & Căn hộ',
    description: 'Duyệt hoặc từ chối yêu cầu liên kết căn hộ của cư dân.',
    allowedRoles: ['admin', 'management'],
  );

  static const apartmentManagement = PermissionItem(
    key: 'apartment_management',
    name: 'Quản trị căn hộ & Tòa nhà',
    category: 'Cư dân & Căn hộ',
    description: 'Quản lý danh sách phòng, tầng, sơ đồ tòa nhà.',
    allowedRoles: ['admin', 'management'],
  );

  static const handbookManagement = PermissionItem(
    key: 'handbook_management',
    name: 'Quản trị cẩm nang cư dân',
    category: 'Thông tin & Cẩm nang',
    description: 'Quản lý nội quy, tiện ích và danh bạ khẩn cấp.',
    allowedRoles: ['admin', 'management'],
  );

  static const roleDelegation = PermissionItem(
    key: 'role_delegation',
    name: 'Ủy quyền vai trò tạm thời',
    category: 'Hệ thống & Phân quyền',
    description: 'Ủy quyền vai trò Kế toán/Kỹ thuật viên có thời hạn.',
    allowedRoles: ['admin', 'management'],
  );

  static const List<PermissionItem> all = [
    invoiceManagement,
    issueManagement,
    residentManagement,
    linkRequestManagement,
    apartmentManagement,
    handbookManagement,
    roleDelegation,
  ];
}
```

---

## 4. Lớp Phòng Thủ Giao Diện: `RoleGuard`

File: `lib/core/widgets/role_guard.dart`

- Nhận vào `PermissionItem permission`, `Widget child`, tùy chọn `Widget? fallback`.
- Lấy `currentUser` và danh sách ủy quyền active của user từ provider `activeDelegationsProvider`.
- **Cơ chế đánh giá thời gian thực (Real-time Expiration Handling)**:
  - `activeDelegationsProvider` kết hợp Stream/lắng nghe thay đổi bảng `role_delegations` cùng bộ lọc thời gian client-side:
    `now.isAfter(del.startsAt) && now.isBefore(del.endsAt)`.
  - Thiết lập Timer định kỳ (mỗi 60 giây) hoặc tính toán lại tại thời điểm build UI để tự động vô hiệu hóa ủy quyền ngay khi vừa qua mốc `ends_at`, triệt tiêu độ trễ giữa thời gian thực tế và UI mà không phụ thuộc vào mutation từ CSDL.
- Nếu không có quyền: Trả về giao diện từ chối truy cập chuẩn mực (Biểu tượng khóa đỏ, thông báo quyền hạn hiện tại, quyền yêu cầu và nút "Quay lại").
- Áp dụng bọc quanh:
  - `InvoiceManagementScreen`, `CreateInvoiceScreen`, `EditInvoiceScreen`
  - `IssueManagementScreen`
  - `ApartmentManagementScreen`
  - `ResidentManagementScreen`
  - `LinkRequestManagementScreen`
  - `HandbookManagementScreen`
  - `RoleDelegationScreen`

---

## 5. Nâng Cấp `AuditTrailScreen` & Thẻ Hiệu Suất Kỹ Thuật Viên

1. **Bộ lọc danh mục**:
   - Filter Chips: *Tất cả*, *Hóa đơn*, *Sự cố*, *Liên kết*, *Phân quyền & Ủy quyền*.
2. **Bộ lọc theo người thực hiện**:
   - Switch / Filter: "Chỉ hoạt động của tôi" (`changed_by == auth.uid()`).
3. **Thẻ Tổng Kết Hiệu Suất Kỹ Thuật Viên (Technician Performance Card)**:
   - Dành riêng cho Quản trị viên (`admin`).
   - Tổng hợp từ `issue_reports`:
     - Số sự cố đã phân công cho kỹ thuật viên.
     - Số sự cố đã xử lý thành công (`resolved`).
     - Tỷ lệ hoàn thành & thời gian xử lý trung bình (giờ/ngày).

---

## 6. Onboarding Dialog Theo Vai Trò

- Thư viện: `shared_preferences: ^2.5.4`.
- Lưu key: `has_seen_role_onboarding_${user.id}_${user.role}`.
- Khi người dùng vào `ManagementHomeScreen`, nếu cờ là `false`:
  - Hiển thị Dialog chào mừng trực quan mang màu sắc thương hiệu của vai trò.
  - Tóm tắt các chức năng chính người dùng được phép thực hiện.
  - Hướng dẫn liên hệ Quản trị viên nếu cần cấp thêm quyền.
  - Nút "Bắt đầu làm việc" -> đánh dấu `true` vào SharedPreferences.

---

## 7. Màn Hình Quản Lý Ủy Quyền Tạm Thời (`RoleDelegationScreen`)

- Chỉ Admin mới có quyền truy cập.
- **Danh sách ủy quyền**: Hiển thị thẻ các ủy quyền đang hoạt động (Active), sắp đến hạn, hoặc đã kết thúc/hủy.
- **Thao tác tạo mới**:
  - Chọn nhân sự nhận ủy quyền (dropdown chỉ hiển thị staff).
  - Chọn vai trò ủy quyền: Kế toán (`accountant`) hoặc Kỹ thuật viên (`technician`).
  - Chọn khoảng thời gian (`showDateRangePicker` hoặc bộ chọn thời gian).
  - Nhập lý do/ghi chú ủy quyền (VD: "Kế toán A nghỉ phép 3 ngày").
- **Thao tác hủy**: Cho phép Admin thu hồi ủy quyền trước hạn (`Revoke`).

---

## 8. Màn Hình Bảng Ma Trận Quyền Hạn (`PermissionMatrixScreen`)

- Trực tiếp duyệt mảng `AppPermissions.all`.
- Hiển thị bảng dạng lưới/DataTable responsive:
  - Cột: Chức năng / Nghiệp vụ | Quản trị viên | Kế toán viên | Kỹ thuật viên | Cư dân.
  - Biểu tượng: Check xanh tròn (`Icons.check_circle_rounded`), Chéo đỏ (`Icons.cancel_outlined`).
- Có chú thích rõ ràng nguyên tắc: Least Privilege & Defense-in-Depth (RLS + Presentation Guard).
- Truy cập từ Menu `ManagementHomeScreen` ("Bảng phân quyền").

---

## 9. Kế Hoạch Kiểm Thử & Xác Minh (Verification)

1. **Automated Unit & Widget Tests**:
   - Test logic `AppPermissions.allows()` cho mọi vai trò và các trường hợp có/không có ủy quyền active.
   - Widget test cho `RoleGuard`: Hiển thị `child` khi có quyền, hiển thị access-denied view khi không có quyền.
   - Unit test cho parser và model `RoleDelegationModel`.
2. **Kiểm tra Tĩnh & Phân tích Mã nguồn**:
   - Chạy `dart analyze` đảm bảo 0 cảnh báo, 0 lỗi.
3. **Manual Verification**:
   - Kiểm tra đăng nhập lần đầu với tài khoản Kế toán: Xuất hiện Onboarding Dialog.
   - Thử mở `IssueManagementScreen` bằng Kế toán: Bị chặn bởi `RoleGuard`.
   - Tạo ủy quyền Kế toán cho một Kỹ thuật viên: Kỹ thuật viên vào được `InvoiceManagementScreen` và thao tác hóa đơn thành công.
