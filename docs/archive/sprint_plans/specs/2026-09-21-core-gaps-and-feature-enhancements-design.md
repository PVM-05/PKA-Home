# Đặc Tả Thiết Kế: Lấp Khoảng Trống Nghiệp Vụ & Nâng Cấp Tính Năng Cốt Lõi (PKA-Home)

- **Ngày tạo**: 2026-09-21
- **Trạng thái**: Đã triển khai và vượt qua toàn bộ kiểm thử tự động (Verified & Passing)
- **Tác giả**: Antigravity & Nhóm phát triển PKA-Home

---

## 1. Bối Cảnh & Khoảng Trống Thực Tế

Trong quá trình đối soát tài liệu Cẩm nang Cư dân (FAQ) với kiến trúc hệ thống PKA-Home, các khoảng trống và cơ hội nâng cấp quan trọng đã được xác định:
1. **Khoảng trống Đăng ký xe (Vehicles)**: FAQ nêu rõ quy định *"Phí gửi xe máy: 100.000đ/tháng/xe — Đăng ký tối đa 2 xe máy/căn hộ"* và *"Phí gửi ô tô: 1.200.000đ/tháng/xe"*, nhưng tầng CSDL chưa có bảng `vehicles`, tầng UI thiếu màn hình đăng ký xe cho cư dân, và màn hình lập hóa đơn của Ban Quản Lý phải gõ tay số lượng xe.
2. **Tiện ích chung (Amenity Booking) chỉ có thông tin tĩnh**: Bảng `building_amenities` chỉ chứa mô tả tĩnh, chưa hỗ trợ cư dân đặt lịch sử dụng theo khung giờ và chưa có cơ chế chống trùng lịch (double-booking) tại tầng DB.
3. **Thiếu minh chứng hoàn thành sự cố (Issue Resolution Proof)**: Bảng `issue_images` chỉ lưu ảnh chụp lúc cư dân báo cáo. Kỹ thuật viên khi sửa xong không có cơ chế tải ảnh hiện trạng sau xử lý, dẫn đến thiếu minh bạch và không thể đối chiếu Trước / Sau.

---

## 2. Kiến Trúc Cơ Sở Dữ Liệu (Database Architecture)

Migration: `supabase/migrations/20260921_01_vehicles_amenity_bookings_and_resolution_proof.sql`

### 2.1. Bảng `public.vehicles` & Ràng buộc Giới hạn 2 xe máy
```sql
CREATE TABLE public.vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    plate_number VARCHAR(20) NOT NULL,
    vehicle_type VARCHAR(20) NOT NULL CHECK (vehicle_type IN ('motorbike', 'car')),
    registered_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Trigger đảm bảo toàn vẹn dữ liệu: Tối đa 2 xe máy/căn hộ
CREATE OR REPLACE FUNCTION public.check_vehicle_limits()
RETURNS TRIGGER AS $$
DECLARE
    current_motorbike_count INT;
BEGIN
    IF NEW.vehicle_type = 'motorbike' THEN
        SELECT count(*) INTO current_motorbike_count
        FROM public.vehicles
        WHERE apartment_id = NEW.apartment_id 
          AND vehicle_type = 'motorbike'
          AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);

        IF current_motorbike_count >= 2 THEN
            RAISE EXCEPTION 'Mỗi căn hộ chỉ được đăng ký tối đa 2 xe máy theo quy định của tòa nhà.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### 2.2. Bảng `public.amenity_bookings` & Chống Trùng Khung Giờ
- Sử dụng **Partial Unique Index** trên các booking có trạng thái `confirmed`:
```sql
CREATE TABLE public.amenity_bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    amenity_id UUID NOT NULL REFERENCES public.building_amenities(id) ON DELETE CASCADE,
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    booked_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    booking_date DATE NOT NULL,
    time_slot VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'confirmed' CHECK (status IN ('confirmed', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Khi hủy đặt (cancelled), khung giờ được tự động giải phóng cho cư dân khác
CREATE UNIQUE INDEX uq_active_amenity_slot 
ON public.amenity_bookings (amenity_id, booking_date, time_slot) 
WHERE (status = 'confirmed');
```

### 2.3. Cột `image_role` Trong `public.issue_images`
- Mở rộng bảng `issue_images`:
```sql
ALTER TABLE public.issue_images 
ADD COLUMN image_role VARCHAR(30) NOT NULL DEFAULT 'report' 
CHECK (image_role IN ('report', 'resolution_proof'));
```

---

## 3. Kiến Trúc Tầng Ứng Dụng (Flutter Architecture)

### 3.1. Models & Repositories
- **`VehicleModel` & `VehicleRepository`**: Cung cấp `getVehiclesByApartment`, `streamVehiclesByApartment`, `registerVehicle`, `deleteVehicle`, và `getVehicleCounts(apartmentId)` trả về map số lượng xe máy và ô tô.
- **`AmenityBookingModel` & `AmenityBookingRepository`**: Cung cấp `getBookingsByAmenityAndDate`, `getMyBookings`, `createBooking` (bảo vệ chống trùng ở client và DB), `cancelBooking`.
- **`IssueModel` & `IssueImageModel`**: Hỗ trợ phân loại getter `reportImages` (ảnh báo cáo ban đầu) và `resolutionProofImages` (ảnh nghiệm thu của kỹ thuật viên).

### 3.2. Màn Hình & Trải Nghiệm Người Dùng (UI/UX)
- **`VehicleManagementScreen`**:
  - Thẻ thông tin hạn mức căn hộ trực quan (Badge X/2 xe máy).
  - Form thêm phương tiện chuẩn hóa biển số và loại xe.
  - Hủy xe an toàn kèm popup xác nhận.
  - Lối vào đặt tại `resident_profile_screen.dart` ("Phương tiện đã đăng ký").
- **Tự động điền hóa đơn (`create_invoice_screen.dart`)**:
  - Khi BQL chọn căn hộ trong danh sách, hệ thống tự động tra cứu số lượng xe đã đăng ký và điền sẵn vào `_motorbikeQtyController` và `_carQtyController`.
- **`AmenityBookingScreen`**:
  - Thanh chọn ngày ngang 7 ngày tiếp theo.
  - Danh sách khung giờ hiển thị rõ slot "Còn trống" vs "Đã có người đặt (Căn hộ XXX)".
  - Tab "Lịch đã đặt" cho phép cư dân theo dõi và hủy đặt chỗ khi cần.
  - Lối vào đặt tại nút "Đặt lịch sử dụng" trên từng thẻ tiện ích trong `resident_handbook_screen.dart`.
- **Nghiệm thu sự cố Trước / Sau**:
  - Trong `issue_management_screen.dart`: Bắt buộc Kỹ thuật viên chụp hoặc chọn ít nhất 1 ảnh hiện trạng hoàn thành khi bấm "Đánh dấu Hoàn thành".
  - Trong `resident_issue_screen.dart`: Hiển thị phân tách rõ "Ảnh lúc báo cáo" và thẻ xanh "Ảnh minh chứng đã khắc phục (Sau khi sửa)" với verified icon.

---

## 4. Kết Quả Kiểm Thử & Đảm Bảo Chất Lượng (Verification)

1. **Phân tích tĩnh (`dart analyze`)**: Đạt **0 issues** (No issues found).
2. **Bộ kiểm thử tự động (`flutter test`)**: Vượt qua **78/78 tests**.
3. **Database execution**: Cả 2 bản migration `20260920_01` và `20260921_01` đã thực thi thành công trên PostgreSQL của Supabase.
