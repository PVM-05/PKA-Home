# Kế Hoạch Triển Khai: Đồng Bộ Vòng Đời Phương Tiện & Phê Duyệt Thẻ Xe Toàn Diện

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hoàn thiện khép kín vòng đời quản lý phương tiện căn hộ (Cư dân đăng ký -> Chờ duyệt -> BQL phê duyệt cấp thẻ hoặc từ chối có lý do -> Cư dân theo dõi, xóa và đăng ký lại), phân tách rành mạch giữa Active Count (hạn mức tối đa 2 xe máy) và Billing Count (tính phí vào hóa đơn hàng tháng).

**Architecture:** Áp dụng Repository Pattern và Riverpod Provider trong kiến trúc Feature-first của Flutter, kết hợp PostgreSQL Migration (cột `rejection_reason`, trigger `check_vehicle_limits` hỗ trợ cả INSERT & UPDATE), model helpers trong `VehicleModel`, và UI tuân thủ Design System (100% tiếng Việt, Material Icons, theme tokens).

**Tech Stack:** Flutter 3.x, Flutter Riverpod, Supabase (PostgreSQL, Triggers, RLS), intl.

## Global Constraints

- 100% tiếng Việt chuẩn mực trên toàn bộ giao diện, thông báo lỗi và nhật ký.
- Tuyệt đối không dùng Emoji trên UI — sử dụng Material Icons (`Icons.two_wheeler_outlined`, `Icons.directions_car_outlined`, `Icons.cancel_outlined`, `Icons.check_circle_outline`).
- Định dạng mã căn hộ chuẩn: `A0110` / `B0110`.
- Không gán cứng UNIQUE trên `license_plate` để cư dân có thể đăng ký lại biển số sau khi xóa xe bị từ chối.
- Tách biệt rõ ràng:
  - `getActiveMotorbikeCount`: đếm xe máy có `status IN ('pending', 'approved')` để kiểm tra hạn mức 2 xe máy.
  - `getVehicleCounts`: chỉ đếm xe có `status == 'approved'` để tính tiền phí gửi xe vào hóa đơn hàng tháng.
- Mọi tác vụ phải có test kiểm thử tương ứng, 0 lỗi `dart analyze` và 100% pass `flutter test`.

---

### Task 1: Database Migration & Trigger (`rejection_reason` & `check_vehicle_limits`)

**Files:**
- Create: `supabase/migrations/20261006_02_vehicle_rejection_reason_and_limit_fix.sql`
- Create: `test/data/repositories/vehicle_migration_test.dart`

**Interfaces:**
- Produces:
  - Bảng `public.vehicles`: thêm cột `rejection_reason text`.
  - Trigger `trg_check_vehicle_limits`: kích hoạt `BEFORE INSERT OR UPDATE ON public.vehicles`.
  - Hàm `check_vehicle_limits()`:
    - Nếu `NEW.vehicle_type = 'motorbike' AND NEW.status != 'rejected'`:
    - Đếm các xe máy có `apartment_id = NEW.apartment_id AND vehicle_type = 'motorbike' AND status IN ('pending', 'approved') AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)`.
    - Nếu count >= 2 thì ném lỗi: `'Mỗi căn hộ chỉ được đăng ký tối đa 2 xe máy theo quy định của tòa nhà.'`.

- [ ] **Step 1: Viết test kiểm tra cú pháp và logic của file SQL migration**

Tạo file `test/data/repositories/vehicle_migration_test.dart`:
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Vehicle Migration SQL Tests', () {
    test('Migration file 20261006_02_vehicle_rejection_reason_and_limit_fix.sql ton tai va dung cu phap', () {
      final file = File('supabase/migrations/20261006_02_vehicle_rejection_reason_and_limit_fix.sql');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content, contains('ADD COLUMN IF NOT EXISTS rejection_reason TEXT'));
      expect(content, contains('check_vehicle_limits()'));
      expect(content, contains("NEW.vehicle_type = 'motorbike' AND NEW.status != 'rejected'"));
      expect(content, contains("status IN ('pending', 'approved')"));
      expect(content, contains('BEFORE INSERT OR UPDATE ON public.vehicles'));
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận test thất bại (chưa có file)**

Run: `flutter test test/data/repositories/vehicle_migration_test.dart`
Expected: FAIL (File not found)

- [ ] **Step 3: Viết migration file `supabase/migrations/20261006_02_vehicle_rejection_reason_and_limit_fix.sql`**

```sql
-- ==============================================================================
-- Migration: 20261006_02_vehicle_rejection_reason_and_limit_fix.sql
-- Mô tả:
-- 1. Bổ sung cột rejection_reason cho bảng vehicles để lưu lý do BQL từ chối.
-- 2. Cập nhật trigger check_vehicle_limits() kiểm tra cả INSERT và UPDATE,
--    chỉ tính hạn mức 2 xe máy cho xe đang hoạt động (status IN ('pending', 'approved')),
--    giải phóng hạn mức cho xe đã bị từ chối (status = 'rejected').
-- ==============================================================================

-- 1. Thêm cột rejection_reason
ALTER TABLE public.vehicles 
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- 2. Cập nhật trigger kiểm tra hạn mức 2 xe máy
CREATE OR REPLACE FUNCTION public.check_vehicle_limits()
RETURNS TRIGGER AS $$
DECLARE
    current_motorbike_count INT;
BEGIN
    -- Chỉ kiểm tra khi là xe máy và bản ghi mới có trạng thái đang hoạt động (pending hoặc approved)
    IF NEW.vehicle_type = 'motorbike' AND NEW.status != 'rejected' THEN
        SELECT count(*) INTO current_motorbike_count
        FROM public.vehicles
        WHERE apartment_id = NEW.apartment_id 
          AND vehicle_type = 'motorbike'
          AND status IN ('pending', 'approved')
          AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);

        IF current_motorbike_count >= 2 THEN
            RAISE EXCEPTION 'Mỗi căn hộ chỉ được đăng ký tối đa 2 xe máy theo quy định của tòa nhà.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_vehicle_limits ON public.vehicles;
CREATE TRIGGER trg_check_vehicle_limits
BEFORE INSERT OR UPDATE ON public.vehicles
FOR EACH ROW EXECUTE FUNCTION public.check_vehicle_limits();
```

- [ ] **Step 4: Chạy test xác nhận PASS**

Run: `flutter test test/data/repositories/vehicle_migration_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20261006_02_vehicle_rejection_reason_and_limit_fix.sql test/data/repositories/vehicle_migration_test.dart
git commit -m "feat(db): them cot rejection_reason va cap nhat trigger check_vehicle_limits"
```

---

### Task 2: Cập Nhật `VehicleModel` & Model Helpers

**Files:**
- Modify: `lib/data/models/vehicle_model.dart`
- Create: `test/data/models/vehicle_model_test.dart`

**Interfaces:**
- Produces in `VehicleModel`:
  - `final String? rejectionReason;`
  - Constructor with `this.rejectionReason`
  - `fromJson(Map<String, dynamic> json)` reads `json['rejection_reason']`
  - `toJson()` outputs `'rejection_reason': rejectionReason`
  - `copyWith({..., String? rejectionReason})`
  - Getters:
    - `bool get isPending => status == 'pending';`
    - `bool get isApproved => status == 'approved';`
    - `bool get isRejected => status == 'rejected';`
    - `bool get isActive => isPending || isApproved;`
    - `bool get hasRejectionReason => rejectionReason != null && rejectionReason!.trim().isNotEmpty;`

- [ ] **Step 1: Viết test cho `VehicleModel`**

Tạo file `test/data/models/vehicle_model_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/vehicle_model.dart';

void main() {
  group('VehicleModel Tests', () {
    test('Khởi tạo VehicleModel đầy đủ và kiểm tra helper getters', () {
      final vehicle = VehicleModel(
        id: 'v-1',
        apartmentId: 'apt-1',
        vehicleType: 'motorbike',
        licensePlate: '29A-12345',
        brandModel: 'Honda AirBlade',
        status: 'pending',
        createdAt: DateTime(2026, 10, 6),
      );

      expect(vehicle.isPending, isTrue);
      expect(vehicle.isApproved, isFalse);
      expect(vehicle.isRejected, isFalse);
      expect(vehicle.isActive, isTrue);
      expect(vehicle.hasRejectionReason, isFalse);
      expect(vehicle.vehicleTypeDisplayName, 'Xe máy');
      expect(vehicle.monthlyFee, 100000.0);
    });

    test('fromJson parse dung rejection_reason va brand_model', () {
      final json = {
        'id': 'v-2',
        'apartment_id': 'apt-1',
        'vehicle_type': 'car',
        'license_plate': '30H-999.88',
        'brand_model': 'Mazda CX-5',
        'status': 'rejected',
        'rejection_reason': 'Biển số xe không rõ ràng trong ảnh chụp',
        'created_at': '2026-10-06T10:00:00.000Z',
      };

      final vehicle = VehicleModel.fromJson(json);

      expect(vehicle.isRejected, isTrue);
      expect(vehicle.isActive, isFalse);
      expect(vehicle.hasRejectionReason, isTrue);
      expect(vehicle.rejectionReason, 'Biển số xe không rõ ràng trong ảnh chụp');
      expect(vehicle.brandModel, 'Mazda CX-5');
      expect(vehicle.vehicleTypeDisplayName, 'Ô tô');
      expect(vehicle.monthlyFee, 1200000.0);

      final outJson = vehicle.toJson();
      expect(outJson['rejection_reason'], 'Biển số xe không rõ ràng trong ảnh chụp');
      expect(outJson['brand_model'], 'Mazda CX-5');
    });

    test('copyWith cap nhat dung rejection_reason', () {
      final vehicle = VehicleModel(
        id: 'v-3',
        apartmentId: 'apt-1',
        vehicleType: 'motorbike',
        licensePlate: '59-X1 56789',
        status: 'pending',
        createdAt: DateTime(2026, 10, 6),
      );

      final updated = vehicle.copyWith(
        status: 'rejected',
        rejectionReason: 'Vượt quá hạn mức 2 xe máy của căn hộ',
      );

      expect(updated.isRejected, isTrue);
      expect(updated.rejectionReason, 'Vượt quá hạn mức 2 xe máy của căn hộ');
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận test thất bại (chưa có rejectionReason)**

Run: `flutter test test/data/models/vehicle_model_test.dart`
Expected: FAIL (compilation error: rejectionReason undefined)

- [ ] **Step 3: Cập nhật `lib/data/models/vehicle_model.dart`**

Thêm trường `final String? rejectionReason;`, cập nhật constructor, `fromJson`, `toJson`, `copyWith`, và bổ sung các helper getter:
```dart
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isActive => isPending || isApproved;
  bool get hasRejectionReason =>
      rejectionReason != null && rejectionReason!.trim().isNotEmpty;
```

- [ ] **Step 4: Chạy test xác nhận PASS**

Run: `flutter test test/data/models/vehicle_model_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/vehicle_model.dart test/data/models/vehicle_model_test.dart
git commit -m "feat(model): them rejectionReason va cac helper getters vao VehicleModel"
```

---

### Task 3: Cập Nhật `VehicleRepository` & `VehicleProvider`

**Files:**
- Modify: `lib/data/repositories/vehicle_repository.dart`
- Modify: `lib/data/providers/vehicle_provider.dart`
- Create: `test/data/repositories/vehicle_repository_test.dart`

**Interfaces:**
- Produces in `VehicleRepository`:
  - `registerVehicle({required String apartmentId, required String plateNumber, required String vehicleType, required String userId, String? brandModel})`
    - Inserts with `apartment_id`, `plate_number`, `license_plate`, `vehicle_type`, `brand_model`, `registered_by`, `user_id`, `status: 'pending'`.
    - Checks motorbike limit: count of motorbikes with `status IN ('pending', 'approved')` < 2.
  - `rejectVehicle(String vehicleId, {String? reason})`
    - Updates `status: 'rejected'`, `rejection_reason: reason?.trim()`, `updated_at`.
  - `getVehicleCounts(String apartmentId)`
    - Selects motorbikes and cars with `status == 'approved'`.
  - `getActiveMotorbikeCount(String apartmentId)`
    - Selects motorbikes with `status IN ('pending', 'approved')`.
- Produces in `vehicle_provider.dart`:
  - `apartmentActiveMotorbikeCountProvider = FutureProvider.family<int, String>`

- [ ] **Step 1: Viết test cho `VehicleRepository`**

Tạo file `test/data/repositories/vehicle_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/repositories/vehicle_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockPostgrestFilterBuilder extends Mock implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

void main() {
  group('VehicleRepository Unit Tests', () {
    test('VehicleRepository khoi tao thanh cong voi SupabaseClient', () {
      final mockClient = MockSupabaseClient();
      final repo = VehicleRepository(mockClient);
      expect(repo, isNotNull);
    });
  });
}
```

- [ ] **Step 2: Cập nhật `lib/data/repositories/vehicle_repository.dart`**

Cập nhật `registerVehicle`, `rejectVehicle`, `getVehicleCounts`, `getActiveMotorbikeCount`.

- [ ] **Step 3: Cập nhật `lib/data/providers/vehicle_provider.dart`**

Thêm `apartmentActiveMotorbikeCountProvider`.

- [ ] **Step 4: Chạy test xác nhận PASS**

Run: `flutter test test/data/repositories/vehicle_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/vehicle_repository.dart lib/data/providers/vehicle_provider.dart test/data/repositories/vehicle_repository_test.dart
git commit -m "feat(repo): cap nhat registerVehicle, rejectVehicle kem ly do va phan tach active voi billing count"
```

---

### Task 4: Nâng Cấp Giao Diện Cư Dân (`VehicleManagementScreen`)

**Files:**
- Modify: `lib/features/resident/screens/vehicle_management_screen.dart`
- Create: `test/features/resident/vehicle_management_screen_test.dart`

**Interfaces:**
- Produces:
  - Form thêm xe:
    - Loại bỏ xe đạp điện, chỉ giữ **Xe máy** (100.000đ/tháng) và **Ô tô** (1.200.000đ/tháng).
    - Thêm ô nhập Hãng/Mẫu xe (`brand_model`, ví dụ: "Honda AirBlade", "Mazda CX-5").
    - Kiểm tra giới hạn 2 xe máy theo `activeMotorbikeCount`.
  - Danh sách xe:
    - Hiển thị Biển số xe, Loại xe, Hãng/Mẫu xe (nếu có).
    - Hiển thị badge trạng thái chuẩn màu:
      - `Chờ phê duyệt`: Cam (`AppStatusColors.pending`)
      - `Đã phê duyệt`: Xanh lá (`AppStatusColors.paid`)
      - `Đã từ chối`: Đỏ (`AppTheme.error`)
    - Nếu xe bị từ chối (`vehicle.isRejected`):
      - Hiển thị khối thông báo màu đỏ nhạt với nội dung: *"Lý do từ chối: [rejectionReason]"* (hoặc *"Chưa có lý do chi tiết"*).
      - Nút xóa để xóa bỏ bản ghi và cho phép đăng ký lại.

- [ ] **Step 1: Viết widget test cho `VehicleManagementScreen`**

Tạo `test/features/resident/vehicle_management_screen_test.dart` kiểm tra hiển thị đúng badge trạng thái và lý do từ chối.

- [ ] **Step 2: Cập nhật `lib/features/resident/screens/vehicle_management_screen.dart`**

Thực hiện nâng cấp form đăng ký và card hiển thị xe.

- [ ] **Step 3: Chạy test xác nhận PASS**

Run: `flutter test test/features/resident/vehicle_management_screen_test.dart`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/features/resident/screens/vehicle_management_screen.dart test/features/resident/vehicle_management_screen_test.dart
git commit -m "feat(ui): nang cap VehicleManagementScreen hien thi badge trang thai va ly do tu choi"
```

---

### Task 5: Nâng Cấp Giao Diện Ban Quản Lý (`VehicleApprovalScreen`)

**Files:**
- Modify: `lib/features/management/screens/vehicle_approval_screen.dart`
- Modify: `test/features/management/vehicle_approval_screen_test.dart`

**Interfaces:**
- Produces:
  - Khi nhấn "Từ chối":
    - Dialog từ chối có trường nhập text lý do từ chối (`TextFormField`).
    - Bổ sung 3 chip gợi ý lý do: *"Biển số không hợp lệ"*, *"Vượt quá hạn mức xe máy"*, *"Thiếu thông tin căn hộ"*.
    - Gọi `ref.read(vehicleRepositoryProvider).rejectVehicle(vehicle.id, reason: reasonText)`.
  - Trong Tab "Đã từ chối":
    - Hiển thị lý do từ chối ngay trong card thông tin xe.

- [ ] **Step 1: Cập nhật `test/features/management/vehicle_approval_screen_test.dart`**
- [ ] **Step 2: Cập nhật `lib/features/management/screens/vehicle_approval_screen.dart`**
- [ ] **Step 3: Chạy test xác nhận PASS**

Run: `flutter test test/features/management/vehicle_approval_screen_test.dart`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/features/management/screens/vehicle_approval_screen.dart test/features/management/vehicle_approval_screen_test.dart
git commit -m "feat(ui): nang cap VehicleApprovalScreen voi hop thoai nhap ly do tu choi va chip goi y"
```

---

### Task 6: Tích Hợp Tạo Hóa Đơn & Kiểm Thử Toàn Diện Hệ Thống

**Files:**
- Verify / Modify: `lib/features/management/screens/create_invoice_screen.dart`
- Create: `test/features/management/create_invoice_vehicle_billing_test.dart`

**Interfaces:**
- Ensures:
  - Khi BQL tạo hóa đơn cho căn hộ, hàm tự động điền phí gửi xe máy/ô tô chỉ lấy số lượng xe đã phê duyệt (`status == 'approved'`).

- [ ] **Step 1: Viết test xác nhận tính phí chỉ áp dụng cho xe approved**
- [ ] **Step 2: Kiểm tra `create_invoice_screen.dart` và đảm bảo kết nối đúng**
- [ ] **Step 3: Chạy test xác nhận PASS**

Run: `flutter test test/features/management/create_invoice_vehicle_billing_test.dart`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/features/management/screens/create_invoice_screen.dart test/features/management/create_invoice_vehicle_billing_test.dart
git commit -m "feat(invoice): dam bao create_invoice_screen chi tinh phi gui xe cho xe da duoc phe duyet"
```

---

### Task 7: Phân Tích Tĩnh & Toàn Bộ Bộ Test Hệ Thống

**Files:**
- Toàn bộ repo

- [ ] **Step 1: Chạy `dart analyze`**

Run: `dart analyze`
Expected: `No issues found!`

- [ ] **Step 2: Chạy toàn bộ test suite `flutter test`**

Run: `flutter test`
Expected: All tests pass (>= 220 tests pass)

- [ ] **Step 3: Commit hoàn thành kế hoạch**

```bash
git commit --allow-empty -m "docs: hoan tat ke hoach dong bo vong doi phuong tien va phe duyet the xe"
```
