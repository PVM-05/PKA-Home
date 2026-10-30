# Đặc Tả Thiết Kế: Gói Dịch Vụ SaaS & Kiểm Soát Hạn Mức Tòa Nhà (SaaS Subscription Plans & Quota Management)

- **Mã giai đoạn:** B3 (trong `COMMERCIAL_PRODUCT_ROADMAP.md`)
- **Ngày lập:** 30/10/2026
- **Trạng thái:** Đã phê duyệt (Approved)
- **Tác giả:** Antigravity Agent & Ban Quản Trị Hệ Thống PKA-Home

---

## 1. Mục Tiêu & Bối Cảnh Nghiệp Vụ

### 1.1. Bối cảnh
PKA-Home là nền tảng B2B SaaS phục vụ 3 nhóm đối tượng khách hàng thương mại:
1. Công ty quản lý vận hành tòa nhà chung cư chuyên nghiệp.
2. Ban quản trị tòa nhà tự quản.
3. Chủ chuỗi nhà trọ / căn hộ dịch vụ cao cấp.

Để thương mại hóa bền vững và bảo vệ doanh thu phần mềm, hệ thống cần:
- Mô hình định giá dựa trên quy mô số căn hộ và tính năng mở rộng.
- Cơ chế kiểm soát hạn mức (Quota Enforcement) bảo mật từ tầng cơ sở dữ liệu để ngăn chặn tình trạng sử dụng vượt quy mô đã đăng ký mà không thanh toán.
- Giao diện trực quan cho Ban Quản Lý (BQL) theo dõi hạn mức sử dụng (số căn hộ, số tòa nhà, số nhân viên), thời hạn gói cước, và gửi yêu cầu nâng cấp/gia hạn.

### 1.2. Mục tiêu cụ thể
1. **Quản lý 3 gói dịch vụ chuẩn hóa**:
   - **Gói Tiêu Chuẩn (Starter)**: Quy mô nhỏ $\le 100$ căn hộ, 1 tòa nhà, tối đa 2 nhân viên BQL. Phù hợp tòa nhà đơn lẻ hoặc nhà trọ 20–80 phòng.
   - **Gói Nâng Cao (Pro)**: Quy mô trung bình $101 - 500$ căn hộ, tối đa 5 tòa nhà, tối đa 10 nhân viên BQL. Mở khóa phân tích tài chính chuyên sâu, đối soát VietQR tự động, quản lý tài sản & kiểm toán.
   - **Gói Doanh Nghiệp (Enterprise)**: Quy mô lớn $> 500$ căn hộ (hạn mức tùy chỉnh hoặc vô hạn), không giới hạn tòa nhà và nhân viên, hỗ trợ kế toán chuyên sâu, xuất hóa đơn điện tử tự động, hỗ trợ ưu tiên 24/7.
2. **Kiểm soát hạn mức tự động tại tầng CSDL (Database Quota Enforcement)**:
   - Chặn thêm căn hộ nếu `count(apartments) >= max_apartments` (trừ khi gói không giới hạn: `-1`).
   - Hỗ trợ hàm RPC `check_subscription_quota(p_organization_id UUID, p_metric TEXT)` và `get_organization_subscription_status(p_building_id UUID)` tính toán chính xác số liệu sử dụng thực tế.
3. **Trải nghiệm người dùng BQL (UI/UX)**:
   - Màn hình `SubscriptionManagementScreen` hiển thị gói đang dùng, thời hạn còn lại, thanh tiến độ % hạn mức căn hộ, tòa nhà, nhân viên.
   - Bảng so sánh 3 gói dịch vụ trực quan, có nút "Yêu cầu nâng cấp / Gia hạn gói".

---

## 2. Kiến Trúc Cơ Sở Dữ Liệu (Database Schema)

### 2.1. Bảng `subscription_plans` (Danh mục gói dịch vụ)
```sql
CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE, -- 'starter', 'pro', 'enterprise'
    name TEXT NOT NULL,        -- 'Gói Tiêu Chuẩn', 'Gói Nâng Cao', 'Gói Doanh Nghiệp'
    description TEXT,
    max_apartments INT NOT NULL DEFAULT 100, -- -1 nếu không giới hạn
    max_buildings INT NOT NULL DEFAULT 1,    -- -1 nếu không giới hạn
    max_staff INT NOT NULL DEFAULT 2,        -- -1 nếu không giới hạn
    price_monthly NUMERIC(12, 2) NOT NULL DEFAULT 0,
    price_yearly NUMERIC(12, 2) NOT NULL DEFAULT 0,
    features JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT true,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 2.2. Bảng `organization_subscriptions` (Đăng ký thuê bao của tổ chức)
```sql
CREATE TABLE IF NOT EXISTS public.organization_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES public.subscription_plans(id) ON DELETE RESTRICT,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'trialing', 'past_due', 'cancelled', 'expired')),
    start_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ,
    billing_cycle TEXT NOT NULL DEFAULT 'monthly' CHECK (billing_cycle IN ('monthly', 'yearly', 'custom')),
    auto_renew BOOLEAN NOT NULL DEFAULT true,
    custom_max_apartments INT, -- Hạn mức override nếu có thỏa thuận riêng
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(organization_id)
);
```

### 2.3. RPCs và Triggers
1. **Trigger `trg_enforce_apartment_quota`**:
   - Trước khi `INSERT` vào bảng `apartments`: Xác định `organization_id` của tòa nhà (`buildings.organization_id`).
   - Kiểm tra tổng số căn hiện có trong tổ chức so với hạn mức cho phép (`custom_max_apartments` hoặc `subscription_plans.max_apartments`).
   - Nếu vượt quá: Raise exception tiếng Việt rõ ràng, báo rõ đã dùng bao nhiêu căn trên hạn mức bao nhiêu.
2. **RPC `get_organization_subscription_status(p_building_id UUID)`**:
   - Trả về JSON chứa:
     * Thông tin gói: `plan_code`, `plan_name`, `status`, `expires_at`, `days_remaining`.
     * Số liệu sử dụng: `used_apartments`, `max_apartments`, `used_buildings`, `max_buildings`, `used_staff`, `max_staff`.
     * Tính toán tỷ lệ phần trăm sử dụng (`apartment_usage_percent`, `is_near_limit`, `is_at_limit`).

---

## 3. Kiến Trúc Ứng Dụng Flutter

### 3.1. Models (`lib/data/models/`)
- `subscription_plan_model.dart`:
  - `SubscriptionPlanModel`: Chứa `id`, `code`, `name`, `description`, `maxApartments`, `maxBuildings`, `maxStaff`, `priceMonthly`, `priceYearly`, `features`, `isActive`.
- `subscription_model.dart`:
  - `OrganizationSubscriptionModel`: Trạng thái thuê bao, ngày hết hạn, số ngày còn lại.
  - `SubscriptionStatusModel`: Tổng hợp gói hiện tại + các chỉ số hạn mức (Usage Metrics) kèm tỷ lệ sử dụng.

### 3.2. Repository & Providers (`lib/data/repositories/` & `lib/data/providers/`)
- `SubscriptionRepository`:
  - `fetchSubscriptionStatus({required String buildingId})`: Gọi RPC `get_organization_subscription_status`. Có cơ chế offline calculation fallback an toàn.
  - `fetchAvailablePlans()`: Lấy danh sách các gói cước đang hoạt động từ bảng `subscription_plans`.
  - `requestPlanUpgrade({required String buildingId, required String targetPlanCode, String? note})`: Gửi yêu cầu nâng cấp gói cước.
- `subscription_provider.dart`:
  - `subscriptionStatusProvider`: `FutureProvider` nạp trạng thái thuê bao theo `activeBuildingProvider`.
  - `availablePlansProvider`: `FutureProvider` nạp danh sách 3 gói cước.

### 3.3. Giao Diện Người Dùng (`lib/features/management/screens/subscription_management_screen.dart`)
- **Phần 1: Thẻ gói cước hiện tại**:
  - Tên gói (Badge: Tiêu chuẩn / Nâng cao / Doanh nghiệp), ngày hết hạn, số ngày còn lại, trạng thái hoạt động.
  - Cảnh báo nếu sắp hết hạn trong 15 ngày hoặc đã dùng $\ge 80\%$ hạn mức căn hộ.
- **Phần 2: Đồng hồ đo lường hạn mức (Usage Gauges)**:
  - 3 thanh đo tiến độ kèm số lượng thực tế: Căn hộ ($X/100$), Tòa nhà ($Y/1$), Nhân viên BQL ($Z/2$).
  - Thanh tiến độ đổi màu linh hoạt: Xanh lá (< 80%), Cam (80% - 99%), Đỏ (100%).
- **Phần 3: Bảng so sánh 3 gói dịch vụ**:
  - Hiển thị cột tính năng, giá niêm yết theo tháng/năm, các quyền lợi nổi bật.
  - Nút "Yêu cầu nâng cấp / Gia hạn" mở hộp thoại xác nhận và chuyển tiếp thông tin tới đội ngũ vận hành.

---

## 4. Kế Hoạch Kiểm Thử & Tiêu Chí Nghiệm Thu

1. **Integration Test**:
   - `test/integration/subscription_quota_migration_test.dart`: Thẩm định file migration SQL, cấu trúc 2 bảng, trigger kiểm tra hạn mức và RPC trả về đúng cấu trúc JSON.
2. **Unit Test Models & Repo**:
   - `test/data/models/subscription_model_test.dart`: Kiểm tra parse JSON, tính toán tỷ lệ phần trăm sử dụng, cờ cảnh báo `isNearLimit`.
   - `test/data/repositories/subscription_repository_test.dart`: Kiểm tra gọi RPC và cơ chế offline fallback.
3. **Widget Test**:
   - `test/features/management/screens/subscription_management_screen_test.dart`: Kiểm tra hiển thị đầy đủ thông tin gói, thanh đo hạn mức, bảng 3 gói cước và hộp thoại gửi yêu cầu.
4. **Tiêu chuẩn chất lượng**:
   - `dart analyze`: 0 issues.
   - `flutter test`: 100% tests pass.
