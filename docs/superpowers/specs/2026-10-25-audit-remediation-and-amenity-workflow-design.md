# Đặc Tả Thiết Kế: Khắc Phục Toàn Diện 21 Điểm Rà Soát Hệ Thống (P0-P3) & Nâng Cấp Luồng Đặt Lịch Tiện Ích

> **Tài liệu thiết kế kỹ thuật (Spec Document)**
> **Ngày lập:** 25/10/2026
> **Mục tiêu:** Khắc phục triệt để các lỗ hổng bảo mật đặc quyền, chuẩn hóa chữ ký RPC, đồng bộ key JSON giữa Backend và Flutter, dọn dẹp migration, giải quyết lỗi hủy lịch của cư dân, xây dựng giao diện Admin duyệt lịch và cấu hình sức chứa tiện ích động.

---

## 1. Bối cảnh & Mục Tiêu

Dựa trên kết quả rà soát toàn diện mã nguồn Flutter và các migration Supabase PostgreSQL:
1. **Bảo mật & Phân quyền (P0/P2):** Lỗ hổng đọc `role` từ metadata trong `handle_new_user`, RPC quản trị cho phép staff tự cấp quyền admin, bucket ảnh sự cố đang ở chế độ public, đọc chéo dữ liệu tiện ích giữa các cư dân.
2. **Toàn vẹn RPC & CSDL (P0/P1):** Chữ ký `simulate_unified_payment` lệch tham số (`p_type` vs `p_payment_type`), cột `invoice_id` kiểu UUID bị so sánh với text trong `reschedule_amenity_booking`, lệch key JSON trong tạo hóa đơn hàng loạt (`estimated_total`, `created_count`), lỗi query cột `building` không tồn tại trong `apartmentsStreamProvider`.
3. **Tính năng Đặt Lịch Tiện Ích & Duyệt Quản Trị:** Cư dân không bấm được nút hủy do tràn thanh nút (`Row` overflow trên 360dp), tất cả tiện ích trong CSDL đang cố định sức chứa = 1 và hình thức độc quyền (`exclusive`), thiếu giao diện Admin duyệt lịch tổng hợp (chuẩn A7/A8) và màn hình sửa sức chứa tiện ích.

---

## 2. Thiết Kế Kiến Trúc & CSDL (Supabase PostgreSQL)

### 2.1. Bản vá Bảo mật Leo Thang Đặc Quyền (Mục #16, #17)

#### Trigger `handle_new_user()`
Ép cứng `role = 'resident'::public.user_role` khi người dùng tự đăng ký qua Auth. Tuyệt đối không đọc `role` từ `raw_user_meta_data`. Chỉ BQL cấp cao (`admin`) mới có quyền nâng quyền cho người dùng thông qua RPC bảo mật.

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, full_name, email, role, is_active, is_locked)
  VALUES (
    new.id, 
    coalesce(new.raw_user_meta_data->>'full_name', 'Người dùng mới'),
    lower(trim(new.email)),
    'resident'::public.user_role, -- Ép cứng resident, chống leo thang đặc quyền
    true,
    false
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### Siết quyền trong `admin_create_user` và `admin_update_user_profile`
- Chỉ `public.is_admin()` mới có quyền tạo hoặc đổi `role` thành `admin`, `accountant`, `technician`.
- Nếu tài khoản staff thông thường gọi RPC đổi role hoặc tạo role admin -> Bắn ngoại lệ từ chối ngay lập tức.

---

### 2.2. Chuẩn Hóa Chữ Ký RPC `simulate_unified_payment` (Mục #4)

Hợp nhất thành một chữ ký RPC duy nhất hỗ trợ tương thích ngược đầy đủ:

```sql
CREATE OR REPLACE FUNCTION public.simulate_unified_payment(
    p_payment_type text DEFAULT 'INVOICE'::text,
    p_reference_id uuid DEFAULT NULL::uuid,
    p_payment_method text DEFAULT 'DEMO'::text,
    p_outcome text DEFAULT 'SUCCESS'::text,
    p_failure_reason text DEFAULT NULL::text,
    p_type text DEFAULT NULL::text -- Hỗ trợ alias cũ
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog;
```
Trong hàm: `v_effective_type := UPPER(COALESCE(p_type, p_payment_type, 'INVOICE'));`

---

### 2.3. Sửa Lỗi Cột và Kiểu Dữ Liệu Tiện Ích (Mục #5, #6, #11)

1. Trong `reschedule_amenity_booking`:
   - Sửa `WHERE (booking_id = p_booking_id OR invoice_id = p_booking_id::text)` thành:
     `WHERE booking_id = p_booking_id AND status = 'PENDING';`
   - Đảm bảo dùng `start_time` và `end_time` (TIMESTAMPTZ) khi đối chiếu với `amenity_maintenance_windows`.
2. Trong `book_amenity_slot`:
   - Khung giờ độc quyền (`exclusive`) tính cả các trạng thái `confirmed`, `pending_payment`, `completed` để tránh đặt trùng khung giờ đã check-in.

---

### 2.4. RPC Nguyên Tử Hủy Lịch Tiện Ích `cancel_amenity_booking`

Tạo RPC `cancel_amenity_booking(p_booking_id UUID)`:
- Kiểm tra quyền: Người đặt (`booked_by = auth.uid()`) hoặc Ban quản lý (`is_staff_or_management()`).
- Chuyển trạng thái lượt đặt sang `'cancelled'`.
- Tự động hủy giao dịch thanh toán liên quan nếu còn đang ở trạng thái `'PENDING'`.
- Tự động đôn cư dân tiếp theo trong danh sách chờ (`waitlist`) theo nguyên tắc FIFO nguyên tử.

---

### 2.5. Đồng Bộ Key JSON và Dữ Liệu Hóa Đơn Hàng Loạt (Mục #7, #8, #9, #10)

1. Trong `validate_monthly_bulk_invoices`:
   - Thêm `'estimated_total': v_apt_total` vào từng phần tử của `valid_items` song song với `'total_amount'`.
2. Trong `generate_valid_bulk_invoices`:
   - Thêm `'invoices_created': v_created_count` và `'total_amount': v_total_generated_amount` vào JSON trả về để đồng bộ tuyệt đối với `BulkInvoiceDialog`.
   - Trạng thái hóa đơn luôn là `'unpaid'` (chuẩn ENUM `invoice_status`).
3. Trong `approve_meter_reading`:
   - Ghi nhận `prev_electric_reading` và `prev_water_reading` vào `meter_reading_submissions` lúc phê duyệt.

---

### 2.6. Khôi Phục Bảo Mật Lưu Trữ & RPC Ẩn Danh (Mục #19, #21)

1. **Storage Bucket**: Chuyển `issue-images` về `public = false`. Toàn bộ ảnh sự cố hiển thị thông qua Signed URL bảo mật.
2. **RPC Lấy Lịch Tiện Ích Ẩn Danh**: Cài đặt và cấp quyền cho `get_amenity_slot_availability(p_amenity_id UUID, p_date DATE)` giúp cư dân xem được slot đã kín chỗ mà không rò rỉ bất kỳ thông tin cá nhân nào của cư dân khác.

---

## 3. Thiết Kế Tầng Flutter (Data & Presentation)

### 3.1. Sửa Lỗi Hủy Lịch Cư Dân & Giao Diện Khung Giờ (`AmenityBookingScreen`)

1. **Hàng nút thao tác trong thẻ Lịch Đã Đặt (`_buildMyBookingsTab`)**:
   - Thay thế `Row(mainAxisAlignment: MainAxisAlignment.end)` bằng `Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end)`.
   - Đảm bảo các nút *Mã QR*, *Đổi lịch*, *Hủy lịch này*, *Thanh toán ngay* tự động xuống dòng mượt mà trên màn hình 360dp–390dp, không tràn viền.
2. **Tab Chọn Khung Giờ (`_buildBookingTab`)**:
   - Tích hợp `get_amenity_slot_availability` qua repository.
   - Khi cư dân đã đặt một khung giờ, thẻ khung giờ đó hiển thị huy hiệu nổi bật **"Lịch của bạn"** kèm nút bấm mở chi tiết / hủy lịch ngay tại chỗ.
   - Khi tiện ích ở hình thức `shared`: Hiển thị rõ số chỗ còn lại `= max_capacity - SUM(guests_count)`.

### 3.2. Cấu Hình Sức Chứa Tiện Ích & UI Admin Duyệt Lịch (`AmenityManagementScreen`)

1. **Tab 1: Duyệt Lịch Tiện Ích (Admin Approval Tab)**:
   - Danh sách toàn bộ lịch đặt chỗ toàn tòa nhà với bộ lọc: *Tất cả*, *Chờ duyệt*, *Chờ thanh toán*, *Đã xác nhận*, *Đã Check-in*, *Đã hủy*.
   - Thanh tìm kiếm theo mã căn hộ (`A0110`), tên cư dân, số điện thoại.
   - Thẻ công việc chuẩn **A7**: Tên tiện ích + Mã căn -> Trạng thái & Mức phí -> Thời gian & Người đặt -> Nút hành động chính.
   - Hộp thoại duyệt/từ chối chuẩn **A8**: Phân nhóm thông tin rõ ràng, nút **Duyệt lịch**, **Từ chối lịch** (nhập lý do), **Thu phí** và **Check-in**.
2. **Tab 2: Cấu Hình Tiện Ích & Sức Chứa (Amenity Capacity Config)**:
   - Danh sách tiện ích tòa nhà hiển thị: Tên, Hình thức (`shared` / `exclusive`), Sức chứa tối đa (`max_capacity`), Đơn giá, Tiền cọc.
   - Nút chỉnh sửa mở hộp thoại cho phép Ban quản lý sửa ngay:
     - Hình thức sử dụng: *Dùng chung chia sẻ sức chứa (shared)* vs *Trọn gói căn hộ (exclusive)*.
     - Sức chứa tối đa: Cho phép nhập số người (VD: Bể bơi: 30, Gym: 20, Tennis: 4, BBQ: 15).
     - Đơn giá & Tiền cọc.
   - Cập nhật dữ liệu ngay vào bảng `building_amenities`.
3. **Tab 3: Lịch Bảo Trì**:
   - Giữ nguyên luồng quản lý khung giờ bảo trì/vệ sinh.

### 3.3. Các Sửa Lỗi Tầng Data & UI Khác (Mục #13, #14, #15)

1. **`VehicleModel`**: Bổ sung `case 'cancelled': return 'Đã hủy';` và `bool get isCancelled => status == 'cancelled';`.
2. **`IssueRepository`**: Chuẩn hóa helper `_extractStoragePath(String urlOrPath)` dùng chung cho xóa, cập nhật và hiển thị ảnh sự cố. Lưu object path đồng nhất.
3. **`apartmentsStreamProvider`**: Sửa query thành `select('id, code, area, is_empty, building_code, floor_number')` loại bỏ hoàn toàn lỗi crash HTTP ban đầu.
4. **`PaymentService` & `ResidentInvoiceService`**: Chuẩn hóa tham số gửi sang RPC `simulate_unified_payment`.

---

## 4. Kế Hoạch Kiểm Thử (TDD & Verification)

1. **Migration Verification**:
   - Script Python kiểm thử migration thực thi lũy thừa trên Supabase thực tế.
   - Xác minh `handle_new_user` không nhận role từ metadata.
   - Xác minh `admin_create_user` chặn staff tạo admin.
   - Xác minh `cancel_amenity_booking` hủy thành công lượt đặt và đôn waitlist.
2. **Flutter Unit & Integration Tests**:
   - Unit test kiểm tra `BulkInvoiceValidationModel` đọc đúng `estimated_total`.
   - Unit test kiểm tra `VehicleModel` xử lý đúng trạng thái `cancelled`.
   - Unit test kiểm tra `apartmentsStreamProvider` không còn gọi cột sai.
   - Widget test cho `AmenityBookingScreen` và `AmenityManagementScreen` đảm bảo không tràn lỗi trên màn hình 360dp.
3. **Static Analysis**: Chạy `dart analyze lib test` đạt 0 lỗi, 0 cảnh báo.
