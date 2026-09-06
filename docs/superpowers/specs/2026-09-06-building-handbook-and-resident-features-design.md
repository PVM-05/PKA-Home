# Đặc Tả Thiết Kế: Cẩm Nang Tòa Nhà Động & Các Tính Năng Bổ Trợ Quản Lý Chung Cư

> **Ngày tạo:** 06/09/2026  
> **Dự án:** PKA-Home (Hệ thống Quản lý Chung cư)  
> **Mục tiêu:** Xây dựng hệ thống quản trị động nội quy, tiện ích, danh bạ khẩn cấp kèm theo các tính năng hồ sơ cư dân, hóa đơn 2-tab, thành viên căn hộ và chỉ số dashboard BQL.

---

## 1. Mục Tiêu & Yêu Cầu Tổng Thể

### 1.1 Mục tiêu nghiệp vụ
- **Cư dân:** Tra cứu tức thì số hotline khẩn cấp (có nút gọi ngay), nội quy sinh hoạt, tiện ích tòa nhà; xem lịch sử hóa đơn rõ ràng; cập nhật thông tin cá nhân (SĐT); xem thành viên đang cùng cư trú tại căn hộ.
- **Ban quản lý (BQL):** Quản trị động (CRUD) toàn bộ nội quy, đường dây nóng, tiện ích mà không cần chỉnh sửa mã nguồn; theo dõi các chỉ số vận hành cốt lõi (tỷ lệ lấp đầy căn hộ, doanh thu theo kỳ).

### 1.2 Nguyên tắc tuân thủ
- **Ngôn ngữ & Thẩm mỹ:** 100% tiếng Việt chuẩn mực, sử dụng Material Icons, tuân thủ `AppTheme` và các quy tắc `design-rules.md`.
- **Bảo mật:** Bật RLS toàn diện trên Supabase theo chuẩn `database-rules.md`.
- **Kiến trúc:** Feature-first, phân tách rõ tầng Data (Model, Repository, Riverpod Provider) và Presentation (Screen, Widget).

---

## 2. Thiết Kế Cơ Sở Dữ Liệu (Supabase / PostgreSQL)

### 2.1 Bảng `emergency_contacts` (Đường dây nóng / Liên hệ khẩn cấp)
| Cột | Kiểu | Mô tả |
| :--- | :--- | :--- |
| `id` | UUID PK | `gen_random_uuid()` |
| `name` | VARCHAR | Tên đầu mối (VD: "Bảo vệ sảnh A", "Kỹ thuật điện nước") |
| `phone` | VARCHAR | Số điện thoại gọi nhanh |
| `contact_type` | VARCHAR | Phân loại: `'security'`, `'fire'`, `'management'`, `'technical'` |
| `display_order` | INT | Thứ tự hiển thị ưu tiên (tăng dần) |
| `created_at` / `updated_at` | TIMESTAMPTZ | Thời gian tạo và cập nhật |

### 2.2 Bảng `building_rules` (Nội quy chung cư)
| Cột | Kiểu | Mô tả |
| :--- | :--- | :--- |
| `id` | UUID PK | `gen_random_uuid()` |
| `title` | VARCHAR | Tiêu đề nội quy (VD: "Quy định về tiếng ồn và giờ giấc") |
| `content` | TEXT | Nội dung chi tiết nội quy |
| `display_order` | INT | Thứ tự hiển thị (tăng dần) |
| `created_at` / `updated_at` | TIMESTAMPTZ | Thời gian tạo và cập nhật |

### 2.3 Bảng `building_amenities` (Tiện ích tòa nhà)
| Cột | Kiểu | Mô tả |
| :--- | :--- | :--- |
| `id` | UUID PK | `gen_random_uuid()` |
| `name` | VARCHAR | Tên tiện ích (VD: "Hồ bơi vô cực tầng 5", "Phòng Gym & Yoga") |
| `description` | TEXT | Mô tả vị trí, lưu ý sử dụng |
| `open_hours` | VARCHAR | Giờ mở cửa (VD: "06:00 - 21:30 hàng ngày") |
| `display_order` | INT | Thứ tự hiển thị |
| `created_at` / `updated_at` | TIMESTAMPTZ | Thời gian tạo và cập nhật |

### 2.4 Bổ sung RLS Policy cho `users`
Cư dân cần quyền `UPDATE` thông tin của chính mình (`full_name`, `phone`):
```sql
CREATE POLICY "Users có thể cập nhật thông tin của chính mình" 
ON public.users FOR UPDATE 
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);
```

### 2.5 Realtime & RLS cho 3 bảng mới
```sql
-- Kích hoạt RLS
ALTER TABLE public.building_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.building_amenities ENABLE ROW LEVEL SECURITY;

-- Policy SELECT cho user đăng nhập
CREATE POLICY "User đăng nhập xem building_rules" ON public.building_rules FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "User đăng nhập xem emergency_contacts" ON public.emergency_contacts FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "User đăng nhập xem building_amenities" ON public.building_amenities FOR SELECT USING (auth.uid() IS NOT NULL);

-- Policy ALL cho Management
CREATE POLICY "Management toàn quyền building_rules" ON public.building_rules FOR ALL USING (public.is_management());
CREATE POLICY "Management toàn quyền emergency_contacts" ON public.emergency_contacts FOR ALL USING (public.is_management());
CREATE POLICY "Management toàn quyền building_amenities" ON public.building_amenities FOR ALL USING (public.is_management());

-- Kích hoạt Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE 
  public.building_rules, 
  public.emergency_contacts, 
  public.building_amenities;
```

---

## 3. Kiến Trúc Mã Nguồn (Flutter & Riverpod)

### 3.1 Data Layer
- **Models:**
  - `lib/data/models/building_rule_model.dart`
  - `lib/data/models/emergency_contact_model.dart`
  - `lib/data/models/building_amenity_model.dart`
- **Repositories:**
  - `lib/data/repositories/handbook_repository.dart`: Các hàm CRUD cho rules, contacts, amenities.
  - `lib/data/repositories/user_repository.dart`: Cập nhật thông tin profile `updateProfile({String? fullName, String? phone})` và truy vấn danh sách người ở cùng căn hộ `fetchCoResidents(String apartmentId)`.
- **Providers:**
  - `lib/data/providers/handbook_provider.dart`: Cung cấp danh sách rules, contacts, amenities (lắng nghe realtime hoặc future).
  - `lib/data/providers/co_residents_provider.dart`: Cung cấp danh sách người ở cùng căn hộ.

### 3.2 Presentation Layer (Giao diện)

#### Phía Cư Dân (`features/resident/`)
1. **Màn hình Cẩm Nang Cư Dân (`resident_handbook_screen.dart`):**
   - Tab 1: **Khẩn cấp** — Thẻ danh bạ bảo vệ, kỹ thuật, PCCC kèm nút gọi điện `url_launcher` (`tel:...`).
   - Tab 2: **Nội quy** — Danh sách Accordion / ExpansionTile hiển thị các điều khoản sinh hoạt.
   - Tab 3: **Tiện ích** — Thẻ hiển thị hồ bơi, gym, sinh hoạt kèm giờ mở cửa và quy định.
   - Tab 4: **Biểu phí & FAQ** — Diễn giải công thức tính phí (quản lý, điện, nước, gửi xe) và câu hỏi thường gặp.
   - Đặt lối tắt vào màn hình này ngay tại **Trang chủ Cư dân** (`resident_home_screen.dart`) qua thẻ nổi bật / Quick action.
2. **Màn hình Hóa Đơn 2 Tab (`resident_invoice_screen.dart`):**
   - Tab 1: **Cần thanh toán** (Trạng thái `unpaid`, `pending_confirmation`).
   - Tab 2: **Lịch sử đã đóng** (Trạng thái `paid`, sắp xếp theo kỳ mới nhất đến cũ nhất).
3. **Màn hình Tài Khoản Của Tôi (`resident_profile_screen.dart`):**
   - Nút **"Chỉnh sửa hồ sơ"**: Mở Dialog hoặc BottomSheet cho phép đổi Họ tên và Số điện thoại.
   - Mục **"Người cùng căn hộ"**: Hiển thị danh sách các thành viên đang liên kết với cùng `apartment_id` (Tên, SĐT, Vai trò: Chủ hộ / Người thuê).

#### Phía Ban Quản Lý (`features/management/`)
1. **Màn hình Quản Lý Cẩm Nang (`handbook_management_screen.dart`):**
   - Quản lý tab Đường dây nóng, Nội quy, Tiện ích.
   - Hỗ trợ thêm mới (FAB), chỉnh sửa và xóa với xác nhận an toàn.
   - Dialog thêm/sửa trực quan, có nhập tiêu đề/tên, nội dung/mô tả, giờ mở cửa/SĐT, và thứ tự hiển thị (`display_order`).
2. **Nâng cấp Dashboard BQL (`management_home_screen.dart`):**
   - Thẻ thống kê: **Tỷ lệ lấp đầy căn hộ** (`occupancyRate` = số căn hộ có người ở / tổng số căn hộ × 100%).
   - Thêm nút chuyển nhanh đến "Quản lý Cẩm nang tòa nhà" trong menu quản trị.

---

## 4. Kế Hoạch Xác Minh & Kiểm Thử

1. **Kiểm thử Database & RLS:**
   - Cư dân chỉ có quyền `SELECT` trên 3 bảng cẩm nang; thử thao tác `INSERT/UPDATE` bị chặn.
   - BQL có quyền `ALL` trên 3 bảng.
   - Cư dân cập nhật được `phone`, `full_name` của chính mình; không sửa được tài khoản người khác.
2. **Kiểm thử Ứng Dụng:**
   - `flutter analyze` đạt 0 lỗi, 0 cảnh báo.
   - `flutter test` pass toàn bộ unit test.
   - Test gọi điện khẩn cấp bằng `url_launcher`.
   - Test chia tab hóa đơn: Hóa đơn sau khi BQL duyệt `paid` tự động nhảy từ tab "Cần thanh toán" sang tab "Lịch sử đã đóng".
