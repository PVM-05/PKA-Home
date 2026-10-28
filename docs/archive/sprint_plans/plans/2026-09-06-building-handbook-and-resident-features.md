# Kế Hoạch Triển Khai: Cẩm Nang Tòa Nhà Động & Các Tính Năng Bổ Trợ PKA-Home

> **Dành cho agentic worker:** BẮT BUỘC SỬ DỤNG: `superpowers:subagent-driven-development` (khuyên dùng) hoặc `superpowers:executing-plans` để thực thi plan này theo từng task. Các bước dùng cú pháp checkbox (`- [ ]`).

**Mục tiêu:** Xây dựng hệ thống quản lý động Cẩm nang tòa nhà (Đường dây nóng, Nội quy, Tiện ích, Biểu phí/FAQ) với CRUD đầy đủ cho BQL, tra cứu nhanh và gọi điện trực tiếp cho Cư dân; bổ sung hóa đơn 2-tab, chỉnh sửa hồ sơ cá nhân (SĐT), hiển thị người cùng căn hộ và chỉ số tỷ lệ lấp đầy trên Dashboard BQL.

**Kiến trúc:** Feature-first Flutter, Supabase Backend với RLS & Realtime, Riverpod state management, 100% tiếng Việt, Material Icons và AppTheme chuẩn mực.

**Tech Stack:** Flutter, Dart, Supabase Flutter, Riverpod, url_launcher, intl.

## Quy Định Bắt Buộc (Global Constraints)
- Toàn bộ giao diện 100% tiếng Việt chuẩn mực, không dùng từ lóng, không emoji.
- Màu sắc lấy từ `AppTheme` và `AppStatusColors`, không hardcode mã màu hex/RGB.
- Icons sử dụng `Icons.*` thuộc Material Design, tuyệt đối không dùng `Icons.circle`.
- Tự động co giãn nội dung thẻ (Card), bọc text trong `FittedBox` hoặc `overflow: TextOverflow.ellipsis` tránh RenderFlex overflow.
- Mọi bảng Supabase đều phải bật RLS. Cư dân chỉ có quyền `SELECT` trên cẩm nang; BQL có quyền `ALL`. Cư dân chỉ `UPDATE` được record của chính mình trong `users`.

---

### Task 1: Migration CSDL & Cấu Hình Thư Viện

**Files:**
- Create: `supabase/migrations/20260906_01_building_handbook_and_resident_features.sql`
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: Tables `building_rules`, `emergency_contacts`, `building_amenities`, RLS policies, Realtime publication, và dependency `url_launcher`.

- [ ] **Bước 1: Bổ sung dependency `url_launcher` vào `pubspec.yaml`**
Thêm `url_launcher: ^6.3.0` vào mục `dependencies:` trong `pubspec.yaml`.

- [ ] **Bước 2: Chạy `flutter pub get`**
Chạy `flutter pub get` để tải gói thư viện.

- [ ] **Bước 3: Viết file migration SQL cho Supabase**
Tạo file `supabase/migrations/20260906_01_building_handbook_and_resident_features.sql` với:
```sql
-- 1. Bảng emergency_contacts
CREATE TABLE IF NOT EXISTS public.emergency_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR NOT NULL,
    phone VARCHAR NOT NULL,
    contact_type VARCHAR DEFAULT 'security', -- 'security', 'fire', 'management', 'technical'
    display_order INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Bảng building_rules
CREATE TABLE IF NOT EXISTS public.building_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR NOT NULL,
    content TEXT NOT NULL,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Bảng building_amenities
CREATE TABLE IF NOT EXISTS public.building_amenities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR NOT NULL,
    description TEXT,
    open_hours VARCHAR,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Triggers updated_at
CREATE TRIGGER update_emergency_contacts_modtime BEFORE UPDATE ON public.emergency_contacts FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();
CREATE TRIGGER update_building_rules_modtime BEFORE UPDATE ON public.building_rules FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();
CREATE TRIGGER update_building_amenities_modtime BEFORE UPDATE ON public.building_amenities FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();

-- 5. Bật RLS
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.building_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.building_amenities ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies
CREATE POLICY "Mọi user đăng nhập xem emergency_contacts" ON public.emergency_contacts FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Management toàn quyền emergency_contacts" ON public.emergency_contacts FOR ALL USING (public.is_management());

CREATE POLICY "Mọi user đăng nhập xem building_rules" ON public.building_rules FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Management toàn quyền building_rules" ON public.building_rules FOR ALL USING (public.is_management());

CREATE POLICY "Mọi user đăng nhập xem building_amenities" ON public.building_amenities FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Management toàn quyền building_amenities" ON public.building_amenities FOR ALL USING (public.is_management());

-- 7. Cho phép user cập nhật thông tin chính mình trên bảng users
DO $$ BEGIN
    CREATE POLICY "Users có thể cập nhật thông tin của chính mình" 
    ON public.users FOR UPDATE 
    USING (auth.uid() = id) 
    WITH CHECK (auth.uid() = id);
EXCEPTION WHEN duplicate_object THEN null;
END $$;

-- 8. Thêm vào publication supabase_realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.emergency_contacts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.building_rules;
ALTER PUBLICATION supabase_realtime ADD TABLE public.building_amenities;

-- 9. Dữ liệu mẫu ban đầu (Seed data)
INSERT INTO public.emergency_contacts (name, phone, contact_type, display_order) VALUES
('Bảo vệ sảnh A (24/7)', '02431234567', 'security', 1),
('Bảo vệ sảnh B (24/7)', '02431234568', 'security', 2),
('Văn phòng Ban Quản Lý (Giờ HC)', '0901234567', 'management', 3),
('Đội Kỹ Thuật & Điện Nước Trực Ban', '0912345678', 'technical', 4),
('Cảnh sát PCCC & Cứu nạn cứu hộ', '114', 'fire', 5)
ON CONFLICT DO NOTHING;

INSERT INTO public.building_rules (title, content, display_order) VALUES
('Quy định về tiếng ồn và giờ giấc sinh hoạt', 'Không gây ồn ào, mở nhạc lớn, khoan đục sau 22:00 đêm và trước 07:00 sáng. Các ngày cuối tuần chỉ thi công từ 08:30 đến 11:30 và từ 14:00 đến 17:00.', 1),
('Quy định về rác thải và vệ sinh môi trường', 'Cư dân phân loại rác theo quy định. Rác sinh hoạt buộc kín trong túi và bỏ vào phòng rác tầng. Tuyệt đối không để rác ở hành lang chung hoặc vứt tàn thuốc qua ban công.', 2),
('Quy định về nuôi giữ vật nuôi', 'Vật nuôi phải được đăng ký với Ban Quản Lý và tiêm phòng dại đầy đủ. Khi ra khu vực công cộng phải đeo rọ mõm và có dây xích kiểm soát.', 3),
('Quy định phòng cháy chữa cháy', 'Không che chắn tủ chữa cháy và họng nước cứu hỏa. Nghiêm cấm đốt vàng mã ngoài khu vực lò đốt quy định tại sân thượng hoặc chân tòa nhà.', 4)
ON CONFLICT DO NOTHING;

INSERT INTO public.building_amenities (name, description, open_hours, display_order) VALUES
('Hồ bơi ngoài trời (Tầng 5)', 'Miễn phí cho cư dân có thẻ. Vui lòng mặc trang phục bơi quy định và tắm tráng trước khi xuống hồ.', '06:00 - 21:00', 1),
('Phòng Gym & Yoga (Tầng 4)', 'Trang bị máy tập hiện đại. Cư dân tự mang khăn cá nhân và xếp gọn tạ sau khi sử dụng.', '05:30 - 22:00', 2),
('Phòng sinh hoạt cộng đồng (Tầng 1)', 'Khu vực họp cư dân, đọc sách và tổ chức sự kiện gia đình (cần đăng ký trước với BQL).', '08:00 - 21:30', 3)
ON CONFLICT DO NOTHING;
```

- [ ] **Bước 4: Xác nhận syntax và file sẵn sàng**

---

### Task 2: Data Models (TDD)

**Files:**
- Create: `lib/data/models/emergency_contact_model.dart`
- Create: `lib/data/models/building_rule_model.dart`
- Create: `lib/data/models/building_amenity_model.dart`
- Modify: `lib/data/models/user_model.dart`
- Create: `test/data/models/handbook_models_test.dart`

**Interfaces:**
- Produces: `EmergencyContactModel`, `BuildingRuleModel`, `BuildingAmenityModel`, và `UserModel` có trường `phone`.

- [ ] **Bước 1: Viết failing test cho các Data Model**
Tạo file `test/data/models/handbook_models_test.dart` kiểm tra serialization (`fromJson` và `toJson`) cho cả 3 model và trường `phone` của `UserModel`.

- [ ] **Bước 2: Chạy test để xác nhận test fail**
Chạy: `flutter test test/data/models/handbook_models_test.dart`
Kỳ vọng: Test fail vì chưa tạo file model.

- [ ] **Bước 3: Tạo `EmergencyContactModel`**
Trong `lib/data/models/emergency_contact_model.dart`:
```dart
class EmergencyContactModel {
  final String id;
  final String name;
  final String phone;
  final String contactType;
  final int displayOrder;
  final DateTime? createdAt;

  EmergencyContactModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.contactType,
    required this.displayOrder,
    this.createdAt,
  });

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    return EmergencyContactModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      contactType: json['contact_type'] as String? ?? 'security',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'contact_type': contactType,
    'display_order': displayOrder,
  };
}
```

- [ ] **Bước 4: Tạo `BuildingRuleModel`**
Trong `lib/data/models/building_rule_model.dart`:
```dart
class BuildingRuleModel {
  final String id;
  final String title;
  final String content;
  final int displayOrder;
  final DateTime? createdAt;

  BuildingRuleModel({
    required this.id,
    required this.title,
    required this.content,
    required this.displayOrder,
    this.createdAt,
  });

  factory BuildingRuleModel.fromJson(Map<String, dynamic> json) {
    return BuildingRuleModel(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'display_order': displayOrder,
  };
}
```

- [ ] **Bước 5: Tạo `BuildingAmenityModel`**
Trong `lib/data/models/building_amenity_model.dart`:
```dart
class BuildingAmenityModel {
  final String id;
  final String name;
  final String? description;
  final String? openHours;
  final int displayOrder;
  final DateTime? createdAt;

  BuildingAmenityModel({
    required this.id,
    required this.name,
    this.description,
    this.openHours,
    required this.displayOrder,
    this.createdAt,
  });

  factory BuildingAmenityModel.fromJson(Map<String, dynamic> json) {
    return BuildingAmenityModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      openHours: json['open_hours'] as String?,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'open_hours': openHours,
    'display_order': displayOrder,
  };
}
```

- [ ] **Bước 6: Cập nhật `UserModel` bổ sung trường `phone`**
Trong `lib/data/models/user_model.dart`:
Bổ sung `final String? phone;` vào constructor, `fromJson`, `toJson`.

- [ ] **Bước 7: Chạy lại test để xác nhận test pass**
Chạy: `flutter test test/data/models/handbook_models_test.dart`
Kỳ vọng: PASS toàn bộ.

---

### Task 3: Repositories & Providers (Handbook & Profile)

**Files:**
- Create: `lib/data/repositories/handbook_repository.dart`
- Create: `lib/data/repositories/user_repository.dart`
- Create: `lib/data/providers/handbook_provider.dart`
- Create: `lib/data/providers/co_residents_provider.dart`

**Interfaces:**
- Produces:
  - `handbookRepositoryProvider`
  - `emergencyContactsProvider`
  - `buildingRulesProvider`
  - `buildingAmenitiesProvider`
  - `userRepositoryProvider`
  - `coResidentsProvider(apartmentId)`

- [ ] **Bước 1: Viết `HandbookRepository`**
Tạo `lib/data/repositories/handbook_repository.dart` chứa:
- `fetchEmergencyContacts()`, `createEmergencyContact()`, `updateEmergencyContact()`, `deleteEmergencyContact()`
- `fetchBuildingRules()`, `createBuildingRule()`, `updateBuildingRule()`, `deleteBuildingRule()`
- `fetchBuildingAmenities()`, `createBuildingAmenity()`, `updateBuildingAmenity()`, `deleteBuildingAmenity()`
- `watchRawContacts()`, `watchRawRules()`, `watchRawAmenities()` để hỗ trợ tự động trigger refresh khi có realtime event.

- [ ] **Bước 2: Viết `UserRepository`**
Tạo `lib/data/repositories/user_repository.dart` chứa:
- `updateProfile({required String userId, String? fullName, String? phone})` gọi `.from('users').update({...}).eq('id', userId)`
- `fetchCoResidents(String apartmentId)` gọi `.from('residents_apartments').select('relation_role, users(id, full_name, phone)').eq('apartment_id', apartmentId)`

- [ ] **Bước 3: Viết `HandbookProvider`**
Tạo `lib/data/providers/handbook_provider.dart` sử dụng Riverpod `FutureProvider.autoDispose`:
- `emergencyContactsProvider`
- `buildingRulesProvider`
- `buildingAmenitiesProvider`

- [ ] **Bước 4: Viết `CoResidentsProvider`**
Tạo `lib/data/providers/co_residents_provider.dart` dạng family provider:
`coResidentsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, apartmentId) ...)`

- [ ] **Bước 5: Chạy `flutter analyze` xác nhận không có lỗi type**

---

### Task 4: UI Cư Dân — Màn Hình Cẩm Nang Tòa Nhà & Shortcut Trang Chủ

**Files:**
- Create: `lib/features/resident/screens/resident_handbook_screen.dart`
- Modify: `lib/features/resident/screens/resident_home_screen.dart`

**Interfaces:**
- Consumes: `emergencyContactsProvider`, `buildingRulesProvider`, `buildingAmenitiesProvider`, `url_launcher`
- Produces: Màn hình Cẩm nang với 4 tab (Khẩn cấp, Nội quy, Tiện ích, Biểu phí & FAQ).

- [ ] **Bước 1: Viết Helper gọi điện `url_launcher` an toàn**
Viết hàm `makePhoneCall(String phoneNumber)` sử dụng `launchUrl(Uri.parse('tel:$phoneNumber'))`.

- [ ] **Bước 2: Xây dựng màn hình `ResidentHandbookScreen`**
Tạo `lib/features/resident/screens/resident_handbook_screen.dart`:
- `DefaultTabController` với 4 tab:
  - Tab 1: **Khẩn cấp** (`Icons.emergency_outlined`) — Danh sách thẻ contact với icon màu đỏ/cam, số điện thoại to rõ, nút "Gọi ngay" (ElevatedButton màu đỏ hoặc xanh lá).
  - Tab 2: **Nội quy** (`Icons.gavel_outlined`) — `ExpansionTile` hoặc Card hiển thị danh sách điều lệ rõ ràng, dễ đọc.
  - Tab 3: **Tiện ích** (`Icons.pool_outlined`) — Thẻ tiện ích gồm tên, giờ hoạt động (badge xanh), mô tả và lưu ý.
  - Tab 4: **Biểu phí & FAQ** (`Icons.help_outline`) — Giải thích công thức tính phí quản lý (đơn giá × diện tích), bậc thang điện/nước, phí gửi xe máy/ô tô, và các câu hỏi thường gặp.

- [ ] **Bước 3: Thêm Shortcut "Cẩm nang tòa nhà" trên Trang chủ Cư dân**
Trong `lib/features/resident/screens/resident_home_screen.dart`:
Thêm một Thẻ Quick Action hoặc Thẻ Thông tin nổi bật:
"Cẩm nang tòa nhà & Hotline khẩn cấp" -> bấm vào điều hướng sang `ResidentHandbookScreen`.

- [ ] **Bước 4: Chạy `flutter analyze` xác minh**

---

### Task 5: UI Cư Dân — Hóa Đơn 2 Tab & Hồ Sơ Cá Nhân (SĐT + Người Cùng Phòng)

**Files:**
- Modify: `lib/features/resident/screens/resident_invoice_screen.dart`
- Modify: `lib/features/resident/screens/resident_profile_screen.dart`

**Interfaces:**
- Consumes: `residentInvoicesProvider`, `coResidentsProvider`, `userRepositoryProvider`

- [ ] **Bước 1: Nâng cấp `ResidentInvoiceScreen` thành 2 Tab**
Chuyển đổi giao diện `resident_invoice_screen.dart`:
- Tab 1: **Cần thanh toán** — Lọc các hóa đơn có `status == 'unpaid'` hoặc `'pending_confirmation'`. Nếu rỗng, hiển thị empty state: "Tuyệt vời! Bạn không còn hóa đơn nào cần thanh toán."
- Tab 2: **Lịch sử đã đóng** — Lọc các hóa đơn có `status == 'paid'`, sắp xếp theo ngày/kỳ mới nhất đến cũ nhất.

- [ ] **Bước 2: Thêm Dialog chỉnh sửa hồ sơ (Họ tên, SĐT) trong `ResidentProfileScreen`**
Trong `resident_profile_screen.dart`:
- Thêm nút icon bút chì hoặc nút "Chỉnh sửa thông tin" bên cạnh tên.
- Mở Dialog nhập Họ và tên, Số điện thoại.
- Gọi `userRepositoryProvider.updateProfile(...)` và cập nhật lại state của `authProvider`.

- [ ] **Bước 3: Thêm mục "Thành viên cùng căn hộ" trong `ResidentProfileScreen`**
Trong `resident_profile_screen.dart`:
- Đọc danh sách căn hộ của cư dân.
- Với mỗi căn hộ, gọi `coResidentsProvider(apartmentId)` để hiển thị danh sách người đang cùng ở (Họ tên, SĐT, Vai trò: Chủ hộ / Người thuê).

- [ ] **Bước 4: Chạy `flutter analyze` và test thủ công**

---

### Task 6: UI Ban Quản Lý — Quản Trị Cẩm Nang & Thống Kê Dashboard BQL

**Files:**
- Create: `lib/features/management/screens/handbook_management_screen.dart`
- Modify: `lib/features/management/screens/management_home_screen.dart`
- Modify: `lib/data/providers/dashboard_providers.dart`

**Interfaces:**
- Consumes: `handbookRepositoryProvider`, `totalApartmentsProvider`, `apartmentsProvider`
- Produces: `occupancyRateProvider`, màn hình CRUD cẩm nang cho BQL.

- [ ] **Bước 1: Bổ sung Provider tính Tỷ lệ lấp đầy (`occupancyRateProvider`)**
Trong `lib/data/providers/dashboard_providers.dart`:
```dart
final occupancyRateProvider = Provider<AsyncValue<double>>((ref) {
  return ref.watch(apartmentsProvider).whenData((apartments) {
    if (apartments.isEmpty) return 0.0;
    final occupied = apartments.where((a) => !a.isEmpty).length;
    return occupied / apartments.length;
  });
});
```

- [ ] **Bước 2: Hiển thị Thẻ "Tỷ lệ lấp đầy" trên Dashboard BQL**
Trong `management_home_screen.dart`:
Thêm một `StatCard` hoặc bổ sung vào mục tổng quan:
"Tỷ lệ lấp đầy": hiển thị `${(rate * 100).toStringAsFixed(1)}%` (VD: 85.3%).

- [ ] **Bước 3: Xây dựng màn hình `HandbookManagementScreen`**
Tạo `lib/features/management/screens/handbook_management_screen.dart`:
- TabBar 3 mục: "Đường dây nóng", "Nội quy", "Tiện ích".
- Danh sách Card có nút Sửa (Icon `Icons.edit_outlined`) và Xóa (Icon `Icons.delete_outline`).
- Nút FAB `Icons.add` mở Dialog thêm mới (Form nhập tên/tiêu đề, SĐT/nội dung, thứ tự hiển thị).
- Dialog chỉnh sửa điền sẵn dữ liệu cũ, cho phép lưu hoặc hủy.
- Dialog xóa có xác nhận an toàn "Bạn có chắc chắn muốn xóa không?".

- [ ] **Bước 4: Thêm lối tắt vào "Quản lý Cẩm nang" trên màn hình BQL**
Trong `management_home_screen.dart`: Thêm Card chức năng "Quản lý Cẩm nang tòa nhà" trong tab Vận hành hoặc menu AppBar.

- [ ] **Bước 5: Chạy `flutter analyze` xác minh**

---

### Task 7: Kiểm Thử Toàn Diện & Đóng Gói Hoàn Tất

**Files:**
- Test files: `test/`
- Documentation: `docs/superpowers/plans/2026-09-06-building-handbook-and-resident-features.md`

- [ ] **Bước 1: Chạy toàn bộ Unit Test**
Chạy: `flutter test test/data/models/ test/data/providers/ test/core/`
Kỳ vọng: 100% tests PASS.

- [ ] **Bước 2: Chạy `flutter analyze`**
Chạy: `flutter analyze`
Kỳ vọng: No issues found! (0 errors, 0 warnings).

- [ ] **Bước 3: Cập nhật tài liệu Walkthrough và tổng kết kết quả**
Cập nhật `walkthrough.md` với các tính năng mới đã hoàn thành.
