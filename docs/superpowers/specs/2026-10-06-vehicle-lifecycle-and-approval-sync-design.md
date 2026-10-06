# Đặc Tả Thiết Kế: Đồng Bộ Vòng Đời Phương Tiện & Phê Duyệt Thẻ Xe Toàn Diện

- **Ngày tạo**: 2026-10-06
- **Trạng thái**: Bản thảo thiết kế đã phê duyệt (Design Approved)
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
  3. Khi BQL từ chối, hệ thống chưa lưu lý do từ chối (`rejection_reason`), dẫn đến cư dân không biết lý do bị từ chối để bổ sung/sửa đổi.
  4. Trigger DB `check_vehicle_limits()` hiện tại đếm toàn bộ xe máy không phân biệt trạng thái, khiến cư dân có xe máy bị từ chối vẫn bị tính vào hạn mức 2 xe máy.
  5. Phương thức `getVehicleCounts(apartmentId)` chưa lọc trạng thái `approved`, có nguy cơ tính phí gửi xe vào hóa đơn hàng tháng cho cả xe chưa được phê duyệt.

### 1.2. Mục Tiêu
- Đồng bộ hoàn chỉnh vòng đời phương tiện từ lúc cư dân đăng ký -> BQL tiếp nhận, phê duyệt hoặc từ chối có lý do -> cư dân theo dõi trạng thái và dọn dẹp/nộp lại.
- Tự động hóa tính phí chính xác: Chỉ tính phí gửi xe đối với xe đã được phê duyệt (`approved`).
- Đảm bảo hạn mức 2 xe máy/căn hộ chỉ áp dụng cho xe đang hoạt động (`pending` hoặc `approved`), giải phóng hạn mức cho xe đã bị từ chối (`rejected`).
- Tuân thủ 100% chuẩn UI/UX tiếng Việt, Material Icons, theme nhất quán và kiểm thử tự động.

---

## 2. Thiết Kế Cơ Sở Dữ Liệu (Database Architecture)

Migration: `supabase/migrations/20261006_02_vehicle_rejection_reason_and_limit_fix.sql`

### 2.1. Bổ Sung Cột `rejection_reason`
```sql
ALTER TABLE public.vehicles 
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
```

### 2.2. Cập Nhật Trigger Kiểm Tra Hạn Mức 2 Xe Máy (`check_vehicle_limits`)
Trigger đảm bảo mỗi căn hộ chỉ được đăng ký tối đa 2 xe máy có trạng thái `pending` hoặc `approved`. Xe đã bị `rejected` sẽ không bị tính vào hạn mức.

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
```

---

## 3. Thiết Kế Tầng Dữ Liệu (Model & Repository Layer)

### 3.1. Cập Nhật `VehicleModel` (`lib/data/models/vehicle_model.dart`)
- Bổ sung trường:
  ```dart
  final String? rejectionReason;
  ```
- Cập nhật constructor, `fromJson` (đọc `rejection_reason`), `toJson` (ghi `rejection_reason`), `copyWith`.
- Bổ sung các helper getters:
  ```dart
  bool get hasRejectionReason => rejectionReason != null && rejectionReason!.trim().isNotEmpty;
  ```

### 3.2. Cập Nhật `VehicleRepository` (`lib/data/repositories/vehicle_repository.dart`)
1. **`registerVehicle`**:
   - Nhận thêm tham số tùy chọn: `String? brandModel`.
   - Lưu vào Supabase với `brand_model: brandModel?.trim()`, `license_plate: cleanPlate`, `plate_number: cleanPlate`, `status: 'pending'`, `user_id: userId`.
   - Trước khi insert, kiểm tra số lượng xe máy đang hoạt động (`status IN ('pending', 'approved')`).
2. **`rejectVehicle`**:
   - Nhận thêm tham số tùy chọn: `String? reason`.
   - Cập nhật cả `status: 'rejected'` và `rejection_reason: reason?.trim()`.
3. **`getVehicleCounts`**:
   - Chỉ đếm các xe có `status == 'approved'` để kết xuất phí gửi xe vào hóa đơn hàng tháng.
4. **`getActiveMotorbikeCount`**:
   - Đếm số lượng xe máy có `status IN ('pending', 'approved')` của căn hộ để kiểm soát việc vô hiệu hóa tùy chọn "Xe máy" trên form đăng ký.

---

## 4. Thiết Kế Giao Diện Người Dùng (UI/UX)

### 4.1. Màn Hình Cư Dân (`VehicleManagementScreen`)
- **Bộ lọc loại xe khi đăng ký**:
  - Hỗ trợ 2 loại xe: **Xe máy** (100.000 đ/tháng, tối đa 2 xe) và **Ô tô** (1.200.000 đ/tháng).
  - Loại bỏ hoàn toàn tùy chọn xe điện khỏi giao diện đăng ký để đúng quy chế vận hành.
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
    - Nút xóa phương tiện để cư dân gỡ bỏ bản ghi bị từ chối và đăng ký lại nếu muốn.

### 4.2. Màn Hình Ban Quản Lý (`VehicleApprovalScreen`)
- **Hộp thoại Từ chối phê duyệt**:
  - Hiển thị thông tin xe sắp từ chối.
  - Bổ sung trường nhập văn bản *"Lý do từ chối (tùy chọn)"*.
  - Bổ sung danh sách các nút gợi ý nhanh lý do từ chối:
    - *"Biển số không hợp lệ"*
    - *"Vượt quá hạn mức xe máy"*
    - *"Thiếu thông tin xác thực"*
- **Tab "Đã từ chối"**:
  - Hiển thị thông tin lý do từ chối ngay dưới thẻ xe.

---

## 5. Chiến Lược Kiểm Thử (Testing Strategy)

1. **Unit Test Data Layer**:
   - `test/data/models/vehicle_model_test.dart`: Parse `rejection_reason` và `brand_model` từ JSON và serialise ngược lại.
   - `test/data/repositories/vehicle_repository_test.dart`: Kiểm tra `registerVehicle` gửi đủ các trường, `rejectVehicle` gửi lý do từ chối, `getVehicleCounts` chỉ đếm xe `approved`.
2. **Widget & Flow Test**:
   - `test/features/resident/vehicle_management_screen_test.dart`: Kiểm thử hiển thị danh sách xe với các badge trạng thái (Chờ phê duyệt, Đã phê duyệt, Đã từ chối) và lý do từ chối.
   - `test/features/management/vehicle_approval_screen_test.dart`: Cập nhật kiểm thử từ chối xe có lý do.
3. **Kiểm Tra Tính Toàn Vẹn**:
   - Chạy `dart analyze` đảm bảo 0 cảnh báo/lỗi.
   - Chạy `flutter test` đảm bảo 100% tests vượt qua.
