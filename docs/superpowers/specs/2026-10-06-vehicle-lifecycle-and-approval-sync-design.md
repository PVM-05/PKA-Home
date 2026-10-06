# Đặc Tả Thiết Kế: Đồng Bộ Vòng Đời Phương Tiện & Phê Duyệt Thẻ Xe Toàn Diện

- **Ngày tạo**: 2026-10-06
- **Trạng thái**: Hoàn thiện theo góp ý phản biện (Finalized & Approved)
- **Tác giả**: Antigravity & Nhóm phát triển PKA-Home

---

## 1. Bối Cảnh & Mục Tiêu

### 1.1. Hiện Trạng & Khoảng Trống
Trong hệ thống PKA-Home:
- Bảng CSDL `vehicles` (`20261005_04_admin_management_ecosystem.sql`) đã có các trường `status` (`pending`, `approved`, `rejected`), `brand_model`, `license_plate`.
- Ban Quản Lý đã có màn hình `VehicleApprovalScreen` với 4 tab (`Tất cả`, `Chờ phê duyệt`, `Đã phê duyệt`, `Đã từ chối`) để duyệt/từ chối cấp thẻ xe.
- Tuy nhiên, luồng phía Cư dân (`VehicleManagementScreen`) chưa được đồng bộ:
  1. Chưa cho phép nhập Hãng/Mẫu xe (`brand_model`, ví dụ: "Honda AirBlade", "Mazda CX-5").
  2. Chưa hiển thị huy hiệu trạng thái phê duyệt (`Chờ phê duyệt`, `Đã phê duyệt`, `Đã từ chối`).
  3. Khi BQL từ chối, hệ thống chưa lưu lý do từ chối (`rejection_reason`), dẫn đến cư dân không biết lý do bị từ chối để khắc phục.
  4. Trigger DB `check_vehicle_limits()` hiện tại đếm toàn bộ xe máy không phân biệt trạng thái, khiến cư dân có xe máy bị từ chối vẫn bị tính vào hạn mức 2 xe máy.
  5. Phương thức `getVehicleCounts(apartmentId)` chưa lọc trạng thái `approved`, có nguy cơ tính phí gửi xe vào hóa đơn hàng tháng cho cả xe chưa được phê duyệt.

### 1.2. Luồng Vòng Đời Phương Tiện Chuẩn (State Lifecycle)
```text
                 CƯ DÂN
                    │
                    ▼
          Đăng ký phương tiện
                    │
                    ▼
                 PENDING (Tính hạn mức, KHÔNG tính phí)
                    │
              ┌─────┴─────┐
              │           │
              ▼           ▼
          APPROVED      REJECTED (KHÔNG tính hạn mức, KHÔNG tính phí)
              │           │
              │           ├── Hiển thị lý do từ chối
              │           │
              │           └── Cư dân bấm XÓA
              │                 │
              │                 ▼
              │            Đăng ký xe mới (Lịch sử sạch)
              │                 │
              │                 ▼
              │              PENDING
              │
              ▼
       Tính phí gửi xe
              │
              ▼
       Hóa đơn hàng tháng
```

**Nguyên tắc nghiệp vụ cốt lõi**:
1. **Không cho phép sửa trực tiếp xe `rejected` thành `pending`**: Giúp lịch sử sạch sẽ, không bị mất dấu lần từ chối trước đó. Cư dân chỉ có thể bấm **Xóa** xe bị từ chối và đăng ký bản ghi xe mới.
2. **Không áp đặt UNIQUE cứng trên `license_plate`**: Cho phép sau khi xóa xe rejected, cư dân có thể đăng ký lại cùng biển số xe mà không bị lỗi ràng buộc.
3. **Tách biệt tuyệt đối 2 khái niệm Đếm (Counts)**:
   - **Active Count** (`pending + approved`): Dùng để kiểm soát hạn mức đăng ký (tối đa 2 xe máy/căn hộ).
   - **Billing Count** (`approved` only): Dùng để kết xuất phí gửi xe vào hóa đơn dịch vụ hàng tháng.

| Trạng thái | Tính hạn mức 2 xe | Tính phí gửi xe hàng tháng | Cho phép đăng ký lại |
| :--- | :---: | :---: | :---: |
| `pending` | Có (Đang giữ chỗ) | Không | Không |
| `approved` | Có (Đang sử dụng) | Có (Đã cấp thẻ xe) | Không |
| `rejected` | Không (Đã giải phóng) | Không | Có (sau khi xóa xe cũ) |

---

## 2. Thiết Kế Cơ Sở Dữ Liệu (Database Architecture)

Migration: `supabase/migrations/20261006_02_vehicle_rejection_reason_and_limit_fix.sql`

### 2.1. Bổ Sung Cột `rejection_reason`
```sql
ALTER TABLE public.vehicles 
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
```

### 2.2. Nâng Cấp Trigger Kiểm Tra Hạn Mức 2 Xe Máy (`check_vehicle_limits`)
Trigger xử lý đầy đủ cả tình huống `INSERT` và `UPDATE` (ví dụ chuyển trạng thái từ `rejected` sang `pending`/`approved` hoặc đổi loại xe):
- Chỉ kiểm tra khi bản ghi mới là xe máy (`vehicle_type = 'motorbike'`) và trạng thái khác `rejected` (`status != 'rejected'`).
- Tự loại trừ chính bản ghi đang cập nhật qua `id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)`.

```sql
CREATE OR REPLACE FUNCTION public.check_vehicle_limits()
RETURNS TRIGGER AS $$
DECLARE
    current_motorbike_count INT;
BEGIN
    -- Chỉ kiểm tra khi là xe máy và xe đang ở trạng thái pending hoặc approved
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

---

## 3. Thiết Kế Tầng Dữ Liệu (Model & Repository Layer)

### 3.1. Cập Nhật `VehicleModel` (`lib/data/models/vehicle_model.dart`)
- Bổ sung trường:
  ```dart
  final String? rejectionReason;
  ```
- Cập nhật constructor, `fromJson` (đọc `rejection_reason`), `toJson` (ghi `rejection_reason`), `copyWith`.
- Bổ sung bộ helper getters chuẩn hóa toàn hệ thống:
  ```dart
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isActive => isPending || isApproved;
  bool get hasRejectionReason =>
      rejectionReason != null && rejectionReason!.trim().isNotEmpty;
  ```

### 3.2. Cập Nhật `VehicleRepository` (`lib/data/repositories/vehicle_repository.dart`)
1. **`registerVehicle`**:
   - Nhận thêm tham số tùy chọn: `String? brandModel`.
   - Lưu vào Supabase:
     ```dart
     {
       'apartment_id': apartmentId,
       'plate_number': cleanPlate,
       'license_plate': cleanPlate,
       'vehicle_type': vehicleType,
       'brand_model': brandModel?.trim(),
       'registered_by': userId,
       'user_id': userId,
       'status': 'pending',
     }
     ```
   - Kiểm tra trước ở tầng Dart: Số lượng xe máy `isActive` (`status IN ('pending', 'approved')`) < 2.
2. **`rejectVehicle`**:
   - Nhận thêm tham số: `String? reason`.
   - Cập nhật:
     ```dart
     {
       'status': 'rejected',
       'rejection_reason': reason?.trim(),
       'updated_at': DateTime.now().toIso8601String(),
     }
     ```
3. **`getVehicleCounts(String apartmentId)` (Tính phí)**:
   - Thêm điều kiện lọc `.eq('status', 'approved')` để đảm bảo hóa đơn tự động chỉ tính tiền xe đã được phê duyệt.
4. **`getActiveMotorbikeCount(String apartmentId)` (Hạn mức)**:
   - Đếm xe máy có `status IN ('pending', 'approved')` để cung cấp cho provider `apartmentActiveMotorbikeCountProvider`.

---

## 4. Thiết Kế Giao Diện Người Dùng (UI/UX)

### 4.1. Màn Hình Cư Dân (`VehicleManagementScreen`)
- **Phân loại xe khi đăng ký**:
  - Hỗ trợ 2 loại xe: **Xe máy** (100.000 đ/tháng, tối đa 2 xe) và **Ô tô** (1.200.000 đ/tháng).
  - Loại bỏ hoàn toàn tùy chọn xe điện.
- **Form đăng ký xe**:
  - Thêm trường nhập liệu `TextFormField` cho Hãng/Mẫu xe:
    - Nhãn: *"Hãng và mẫu xe (tùy chọn)"*
    - Gợi ý: *"Ví dụ: Honda AirBlade, Toyota Vios..."*
    - Biểu tượng: `Icons.branding_watermark_outlined`.
- **Thẻ hiển thị phương tiện**:
  - Hiển thị Biển số xe cỡ lớn, Loại xe và Hãng/Mẫu xe (nếu có).
  - Badge trạng thái trực quan:
    - 🟡 `Chờ phê duyệt`: Màu cam (`AppStatusColors.pending`), nền cam nhạt.
    - 🟢 `Đã phê duyệt`: Màu xanh lá (`AppStatusColors.paid`), nền xanh nhạt.
    - 🔴 `Đã từ chối`: Màu đỏ (`AppTheme.error`), nền đỏ nhạt.
  - Khi xe ở trạng thái `rejected`:
    - Hiển thị banner cảnh báo đỏ nhẹ kèm lý do từ chối: *"Lý do từ chối: [Nội dung lý do]"*.
    - Nút xóa phương tiện (`IconButton(Icons.delete_outline)`) để cư dân xóa bỏ bản ghi bị từ chối và đăng ký lại xe mới.

### 4.2. Màn Hình Ban Quản Lý (`VehicleApprovalScreen`)
- **Hộp thoại Từ chối phê duyệt**:
  - Hiển thị thông tin xe sắp từ chối (Biển số, Căn hộ).
  - Bổ sung trường nhập văn bản *"Lý do từ chối (tùy chọn)"*.
  - Bổ sung các chip gợi ý nhanh:
    - *"Biển số không hợp lệ"*
    - *"Vượt quá hạn mức xe máy"*
    - *"Thiếu thông tin xác thực"*
- **Tab "Đã từ chối"**:
  - Hiển thị chi tiết lý do từ chối trong thẻ xe.

---

## 5. Chiến Lược Kiểm Thử (Testing Strategy)

1. **Unit Test Data Layer**:
   - `test/data/models/vehicle_model_test.dart`: Parse `rejection_reason`, `brand_model`, kiểm tra các getter `isPending`, `isApproved`, `isRejected`, `isActive`, `hasRejectionReason`.
   - `test/data/repositories/vehicle_repository_test.dart`: Kiểm tra `registerVehicle` gửi đủ các trường, `rejectVehicle` gửi lý do từ chối, `getVehicleCounts` chỉ đếm xe `approved`, `getActiveMotorbikeCount` đếm đúng xe `isActive`.
2. **Widget & Flow Test**:
   - `test/features/resident/vehicle_management_screen_test.dart`: Kiểm thử hiển thị danh sách xe với các badge trạng thái, lý do từ chối của xe rejected, form nhập hãng xe.
   - `test/features/management/vehicle_approval_screen_test.dart`: Cập nhật kiểm thử từ chối xe có lý do.
3. **Kiểm Tra Tính Toàn Vẹn**:
   - Chạy `dart analyze` đảm bảo 0 cảnh báo/lỗi.
   - Chạy `flutter test` đảm bảo 100% tests vượt qua.
