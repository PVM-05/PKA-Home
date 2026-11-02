# Đặc Tả Kỹ Thuật: Quản Lý Ô Đỗ Hầm, Sức Chứa Bãi Xe & Vé Xe Vãng Lai (D2)

- **Mã tính năng:** D2 (thuộc `COMMERCIAL_PRODUCT_ROADMAP.md`)
- **Trạng thái:** Sẵn sàng thực thi (Approved)
- **Tác giả:** Antigravity Team
- **Ngày tạo:** 02/11/2026
- **Quy chuẩn thực thi:** TDD (Test-Driven Development), commit trực tiếp vào `main`.

---

## 1. Mục Tiêu & Yêu Cầu Nghiệp Vụ

Trong mô hình quản lý vận hành chung cư và tòa nhà thương mại:
1. **Minh bạch vị trí đỗ ô tô:** Cư dân trả phí hàng tháng cần có ô đỗ định danh cố định (ví dụ `P-B1-01`), tránh tình trạng tranh chấp vị trí hoặc đỗ tràn lối thoát hiểm.
2. **Kiểm soát sức chứa tầng hầm thời gian thực (Capacity Management):** Ban Quản Lý và Bảo vệ cổng luôn biết rõ hầm B1, B2 còn bao nhiêu chỗ trống cho ô tô và xe máy trước khi cho xe ngoài vào.
3. **Số hóa vé xe vãng lai (Visitor Parking Tickets):** Khách đến liên hệ công tác hoặc thăm cư dân được cấp vé điện tử có mã QR. Khi xe ra, hệ thống tự động tính cước theo giờ (lũy tiến, phụ thu qua đêm) và sinh mã VietQR động gạch nợ tức thời, chống thất thoát doanh thu tiền mặt.

---

## 2. Thiết Kế Kiến Trúc Cơ Sở Dữ Liệu (PostgreSQL / Supabase)

### 2.1. Bảng `parking_slots` (Ô đỗ xe tầng hầm)
```sql
CREATE TABLE IF NOT EXISTS public.parking_slots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE,
    zone VARCHAR(20) NOT NULL DEFAULT 'B1', -- 'B1', 'B2', 'B3', 'Khu A', 'Khu B'
    slot_number VARCHAR(30) NOT NULL,       -- 'P-B1-01', 'P-B1-02', 'M-B1-01'
    slot_type VARCHAR(20) NOT NULL DEFAULT 'car', -- 'car', 'motorcycle'
    status VARCHAR(20) NOT NULL DEFAULT 'available', -- 'available', 'occupied', 'reserved', 'maintenance'
    assigned_vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
    assigned_apartment_id UUID REFERENCES public.apartments(id) ON DELETE SET NULL,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(building_id, zone, slot_number)
);
```

### 2.2. Bảng `visitor_parking_tickets` (Vé xe vãng lai / Khách thăm)
```sql
CREATE TABLE IF NOT EXISTS public.visitor_parking_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE,
    ticket_code VARCHAR(30) NOT NULL UNIQUE, -- 'TKT-YYYYMM-XXXXX'
    license_plate VARCHAR(20) NOT NULL,
    vehicle_type VARCHAR(20) NOT NULL DEFAULT 'motorcycle', -- 'car', 'motorcycle'
    check_in_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    check_out_at TIMESTAMPTZ,
    status VARCHAR(20) NOT NULL DEFAULT 'in_parking', -- 'in_parking', 'completed', 'cancelled'
    hourly_rate NUMERIC NOT NULL DEFAULT 5000,
    total_hours NUMERIC,
    fee_amount NUMERIC NOT NULL DEFAULT 0,
    payment_status VARCHAR(20) NOT NULL DEFAULT 'unpaid', -- 'unpaid', 'paid'
    payment_method VARCHAR(20), -- 'vietqr', 'cash'
    qr_payload TEXT NOT NULL,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 2.3. Bổ sung trường vào `public.vehicles`
- `parking_slot_id`: UUID REFERENCES `public.parking_slots(id)` ON DELETE SET NULL.
- `parking_slot_number`: VARCHAR(30) lưu nhanh vị trí ô đỗ (phục vụ hiển thị không cần JOIN phức tạp).

### 2.4. Các Hàm & Thủ Tục Lưu Trữ (PostgreSQL RPCs)
1. `get_parking_capacity_stats(p_building_id UUID)`:
   - Trả về JSON tổng hợp: tổng số slot ô tô, đã đỗ, còn trống; tổng số slot xe máy, đã đỗ, còn trống; số lượng xe vãng lai hiện tại trong bãi.
2. `calculate_visitor_parking_fee(p_ticket_id UUID, p_check_out_at TIMESTAMPTZ)`:
   - Quy tắc tính cước:
     - Xe máy: 2 giờ đầu 5.000đ; mỗi giờ tiếp theo +3.000đ/h; qua đêm (23:00 - 06:00) phụ thu 20.000đ.
     - Ô tô: 2 giờ đầu 25.000đ; mỗi giờ tiếp theo +15.000đ/h; qua đêm phụ thu 70.000đ.
3. `checkout_visitor_ticket(p_ticket_id UUID, p_payment_method VARCHAR)`:
   - Cập nhật `check_out_at`, `status = 'completed'`, `payment_status = 'paid'`, giải phóng sức chứa và ghi log kiểm toán.

---

## 3. Thiết Kế Tầng Dữ Liệu Dart & Riverpod Providers

### 3.1. Models Strongly-typed
- `ParkingSlotModel`: Ánh xạ bảng `parking_slots` (`id`, `zone`, `slotNumber`, `slotType`, `status`, `assignedVehicleId`, `assignedApartmentId`, `displayStatus`).
- `VisitorParkingTicketModel`: Ánh xạ bảng `visitor_parking_tickets` (`ticketCode`, `licensePlate`, `vehicleType`, `checkInAt`, `checkOutAt`, `feeAmount`, `paymentStatus`, `qrPayload`).
- `ParkingCapacityStatsModel`: Thống kê tổng quan (`carTotal`, `carOccupied`, `carAvailable`, `motoTotal`, `motoOccupied`, `motoAvailable`, `visitorCount`).

### 3.2. Repository & Offline Fallback Engine
- `ParkingRepository`:
  - `fetchSlots({String? buildingId, String? zone, String? type, String? status})`
  - `fetchCapacityStats(String? buildingId)`
  - `createSlot(ParkingSlotModel slot)`
  - `assignSlotToVehicle({required String slotId, required String vehicleId, required String apartmentId})`
  - `releaseSlot(String slotId)`
  - `createVisitorTicket({required String licensePlate, required String vehicleType, String? buildingId})`
  - `checkoutVisitorTicket({required String ticketCode, required String paymentMethod})`

### 3.3. Providers
- `parkingSlotsProvider`: Stream/FutureProvider danh sách ô đỗ hầm theo bộ lọc.
- `parkingCapacityStatsProvider`: Provider dải chỉ số sức chứa.
- `activeVisitorTicketsProvider`: Danh sách các xe vãng lai đang đỗ trong bãi.

---

## 4. Thiết Kế Giao Diện Người Dùng (UI/UX)

### 4.1. Màn hình Quản Lý Bãi Xe & Trạm Soát Vé (`ParkingManagementScreen`)
Đường dẫn route: `/management/parking` (Tích hợp vào Dashboard và Sidebar BQL).
Bao gồm 2 Tabs:

#### Tab 1: Sơ đồ Ô đỗ Tầng Hầm (Slots Grid)
- Bộ lọc Chip nhanh: `Tất cả`, `Tầng B1`, `Tầng B2`, `Ô tô`, `Xe máy`, `Còn trống`, `Đã có xe`.
- Lưới các ô đỗ hiển thị trực quan:
  - Màu xanh lá nhạt: `Còn trống (Available)` - Nhấn vào để gán nhanh xe/căn hộ.
  - Màu xanh dương: `Đã có xe (Occupied)` - Hiển thị biển số xe và mã căn hộ, nút giải phóng chỗ.
  - Màu cam: `Đang bảo trì (Maintenance)`.
- Nút "Thêm ô đỗ mới" mở BottomSheet cấu hình.

#### Tab 2: Trạm Soát Vé Cổng & Xe Vãng Lai (Gate Workstation)
- Thanh KPI sức chứa: Thanh đo tỷ lệ lấp đầy % của Ô tô và Xe máy.
- Thanh công cụ hành động tức thời:
  - Nút **[+ Check-in Xe Vào]**: Mở modal nhập Biển số, chọn Ô tô/Xe máy -> Tự động sinh mã vé `TKT-...`, hiển thị mã QR vé xe.
  - Ô tìm kiếm / quét vé nhanh: Nhập biển số hoặc quét QR vé để Check-out.
- Bảng danh sách các xe vãng lai đang trong bãi:
  - Biển số xe, Loại xe, Giờ vào, Thời gian đã đỗ (VD: `1 giờ 45 phút`), Tiền tạm tính.
  - Nút **[Check-out & Thu tiền]**: Mở hộp thoại thanh toán có mã VietQR động để khách quét thanh toán ngay tại barie.

### 4.2. Giao Diện Cư Dân (`VehicleManagementScreen`)
- Thẻ phương tiện của cư dân hiển thị nhãn nổi bật:
  - Với xe ô tô đã được duyệt: Hiển thị badge vị trí ô đỗ cố định (VD: `Vị trí: Ô P-B1-08`).
  - Nếu chưa có ô đỗ: Hiển thị nhãn `Chờ BQL sắp xếp ô đỗ hầm`.

---

## 5. Kế Hoạch Kiểm Thử Tự Động (TDD Testing Strategy)

1. **Migration & RPC Integration Tests:**
   - Kiểm tra tạo bảng `parking_slots`, `visitor_parking_tickets`.
   - Kiểm tra hàm `get_parking_capacity_stats` tính đúng số lượng slot trống/đã đỗ.
   - Kiểm tra hàm `calculate_visitor_parking_fee` tính cước lũy tiến và phụ thu qua đêm.
2. **Model & Repository Unit Tests:**
   - Serialization & Deserialization `ParkingSlotModel`, `VisitorParkingTicketModel`, `ParkingCapacityStatsModel`.
   - Repository offline fallback khi mất mạng.
3. **Widget & Flow Tests:**
   - Test lưới ô đỗ `ParkingSlotsGrid` hiển thị đúng màu và trạng thái.
   - Test modal Check-in sinh vé và Check-out hiển thị VietQR thu phí.
   - Test thẻ xe cư dân hiển thị vị trí ô đỗ.
