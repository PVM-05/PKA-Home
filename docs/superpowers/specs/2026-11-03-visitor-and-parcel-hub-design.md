# Đặc Tả Thiết Kế: An Ninh Tòa Nhà, Đăng Ký Khách Trước Bằng Mã QR & Quản Lý Bưu Kiện Lễ Tân (D6)

> **Mục tiêu:** Xây dựng giải pháp an ninh kiểm soát khách ra vào tòa nhà thông minh bằng mã QR và số hóa trung tâm giao nhận bưu kiện tại sảnh lễ tân (Front-Desk Parcel Hub), loại bỏ hoàn toàn sổ giấy ghi chép thủ công và tình trạng thất lạc bưu phẩm của cư dân.

---

## 1. Bối Cảnh Nghiệp Vụ & Bài Toán Thực Tế

### A. Vấn đề đón khách vãng lai:
- Khi khách đến tòa nhà chung cư, bảo vệ/lễ tân phải chặn lại yêu cầu xuất trình CCCD, ghi chép sổ sách thủ công tốn thời gian, hoặc phải gọi intercom lên từng phòng để xác nhận.
- Cư dân không chủ động nắm được khách đã đến sảnh hay chưa, gây ùn tắc giao thông trước cổng sảnh tòa nhà vào giờ cao điểm.

### B. Vấn đề bưu kiện thương mại điện tử (Shopee, Lazada, TikTok, bưu phẩm):
- Mỗi ngày sảnh chung cư tiếp nhận hàng trăm kiện hàng từ các đơn vị vận chuyển (SPX, GHTK, GHN, Viettel Post, J&T). Hàng hóa chất đống tại bàn lễ tân hoặc gầm cầu thang, dễ bị cầm nhầm, rách vỡ hoặc thất lạc.
- Cư dân không biết bưu phẩm đã đến nơi hay chưa, lễ tân phải gọi điện từng người gây quá tải.

### C. Giải pháp chuẩn thương mại của PKA-Home:
1. **Vé khách điện tử (Visitor QR Pass):** Cư dân tạo trước vé đón khách trong vài giây trên app, gửi mã QR vé cho khách qua Zalo/SMS. Khách đến cổng chỉ cần quét mã tại trạm an ninh để bảo vệ xác thực và mở barie/thang máy.
2. **Trạm Bưu Kiện Lễ Tân (Front-Desk Parcel Hub):** Lễ tân chụp ảnh kiện hàng, chọn căn hộ, nhập mã vận đơn và vị trí kệ lưu trữ. Hệ thống tự động bắn thông báo tức thời tới cư dân và cấp mã PIN 6 số bí mật. Cư dân xuống sảnh đọc mã PIN hoặc đưa mã QR để lễ tân bàn giao chính xác 100%.

---

## 2. Kiến Trúc Cơ Sở Dữ Liệu (PostgreSQL / Supabase)

### A. Bảng `visitor_access_passes` (Vé khách ra vào):
```sql
CREATE TABLE public.visitor_access_passes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pass_code TEXT NOT NULL UNIQUE, -- Định dạng: VP-YYYYMM-XXXXX
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    host_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    visitor_name TEXT NOT NULL,
    visitor_phone TEXT,
    license_plate TEXT,
    vehicle_type TEXT NOT NULL DEFAULT 'none', -- none, motorcycle, car
    visitor_count INTEGER NOT NULL DEFAULT 1,
    expected_arrival TIMESTAMPTZ NOT NULL,
    expected_departure TIMESTAMPTZ,
    purpose TEXT NOT NULL DEFAULT 'visit', -- visit, delivery, repair, other
    qr_payload TEXT NOT NULL, -- Dữ liệu mã hóa: PKAPASS:VP-YYYYMM-XXXXX:<hash>
    status TEXT NOT NULL DEFAULT 'pending', -- pending, checked_in, checked_out, cancelled, expired
    check_in_at TIMESTAMPTZ,
    check_in_guard_id UUID REFERENCES public.users(id),
    check_out_at TIMESTAMPTZ,
    check_out_guard_id UUID REFERENCES public.users(id),
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);
```

### B. Bảng `parcels` (Quản lý bưu kiện tại lễ tân):
```sql
CREATE TABLE public.parcels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parcel_code TEXT NOT NULL UNIQUE, -- Định dạng: PCL-YYYYMM-XXXXX
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    recipient_name TEXT,
    carrier TEXT NOT NULL DEFAULT 'SPX', -- SPX, GHTK, GHN, Viettel Post, J&T, NinjaVan, Khác
    tracking_number TEXT,
    description TEXT,
    shelf_location TEXT NOT NULL DEFAULT 'Kệ chung', -- Kệ A1, Kệ B2, Tủ mát, Bàn lễ tân
    image_url TEXT,
    pickup_pin TEXT NOT NULL, -- Mã PIN 6 số ngẫu nhiên: 582914
    status TEXT NOT NULL DEFAULT 'arrived', -- arrived, collected, returned
    arrived_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    received_staff_id UUID REFERENCES public.users(id),
    collected_at TIMESTAMPTZ,
    handover_staff_id UUID REFERENCES public.users(id),
    collected_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);
```

### C. Database Triggers & Auto-generation:
1. `trg_generate_visitor_pass_code`: Tự động sinh `pass_code` và `qr_payload` khi tạo mới.
2. `trg_generate_parcel_code_and_pin`: Tự động sinh `parcel_code` và mã PIN ngẫu nhiên 6 chữ số khi lễ tân tiếp nhận kiện hàng.
3. Cập nhật `updated_at` tự động cho cả 2 bảng.

### D. Bộ RPCs Hỗ Trợ Nghiệp Vụ:
1. `check_in_visitor_pass(p_pass_code TEXT, p_guard_id UUID)`: Chuyển vé sang `checked_in`, ghi nhận thời gian vào.
2. `check_out_visitor_pass(p_pass_code TEXT, p_guard_id UUID)`: Chuyển vé sang `checked_out`, ghi nhận thời gian ra.
3. `collect_parcel(p_parcel_id UUID, p_pickup_pin TEXT, p_staff_id UUID, p_collected_by TEXT)`: Xác thực mã PIN, bàn giao kiện hàng cho cư dân.
4. `get_front_desk_stats(p_building_id UUID)`: Lấy các số liệu thống kê thời gian thực phục vụ trạm làm việc lễ tân.

---

## 3. Thiết Kế Tầng Dữ Liệu & Riverpod State Management

### A. Data Models:
- `VisitorPassModel`:
  - `id`, `passCode`, `apartmentId`, `hostUserId`, `visitorName`, `visitorPhone`, `licensePlate`, `vehicleType`, `visitorCount`, `expectedArrival`, `expectedDeparture`, `purpose`, `qrPayload`, `status`, `checkInAt`, `checkOutAt`, `note`.
  - Getters: `statusDisplayName`, `purposeDisplayName`, `vehicleDisplayName`, `isCheckInAllowed`, `isExpired`.
- `ParcelModel`:
  - `id`, `parcelCode`, `apartmentId`, `recipientName`, `carrier`, `trackingNumber`, `description`, `shelfLocation`, `imageUrl`, `pickupPin`, `status`, `arrivedAt`, `collectedAt`, `collectedBy`.
  - Getters: `statusDisplayName`, `carrierDisplayName`, `daysInStorage`, `isOverdueStorage` (> 3 ngày).
- `FrontDeskStatsModel`:
  - `totalExpectedVisitors`, `visitorsInBuilding`, `pendingParcels`, `overdueParcels`.

### B. Repositories & Offline Fallback Engine:
- `FrontDeskRepository`:
  - `fetchVisitorPasses({String? status, String? apartmentId})`
  - `createVisitorPass(...)`
  - `cancelVisitorPass(String passId)`
  - `checkInVisitor(String passCode, String guardId)`
  - `checkOutVisitor(String passCode, String guardId)`
  - `fetchParcels({String? status, String? apartmentId})`
  - `receiveParcel(...)`
  - `collectParcel(...)`
  - `fetchFrontDeskStats()`
  - Tích hợp Offline Fallback Engine: Cung cấp sẵn mock data chuẩn mực giúp ứng dụng hoạt động thông suốt cả khi mất kết nối mạng.

---

## 4. Thiết Kế Giao Diện Người Dùng (UI/UX)

### A. Ban Quản Lý: Trạm Lễ Tân & An Ninh ([`FrontDeskWorkstationScreen`](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/features/management/screens/front_desk_workstation_screen.dart))
- Bố cục 2 Tabs lớn mượt mà:
  - **Tab 1: Quản lý Khách vào ra (Visitor Control):**
    - Thanh KPI: Khách dự kiến hôm nay, Khách đang trong tòa nhà, Đã rời khỏi.
    - Bộ lọc tìm kiếm: Theo mã vé, tên khách, số điện thoại, mã căn hộ.
    - Thao tác nhanh: Nút "Quét / Nhập mã vé khách" mở hộp thoại xử lý check-in/check-out tức thời.
    - Danh sách thẻ khách trực quan: Hiển thị đầy đủ căn hộ đón tiếp, biển số xe, mục đích và nút bấm check-in/check-out một chạm.
  - **Tab 2: Trạm Bưu Kiện Lễ Tân (Parcel Hub):**
    - Thanh KPI: Đang chờ nhận, Tồn kho quá 3 ngày (cảnh báo đỏ), Đã bàn giao hôm nay.
    - Nút nổi bật "Tiếp nhận bưu kiện mới": Modal nhập thông tin shipper, căn hộ, mã vận đơn, vị trí kệ, chụp ảnh bưu phẩm.
    - Thẻ bưu kiện: Ảnh thumbnail, hãng vận chuyển (SPX, GHTK, Viettel Post...), thời gian lưu kho, vị trí kệ.
    - Nút "Bàn giao bưu kiện": Modal nhập mã PIN 6 số hoặc quét mã QR lấy hàng từ cư dân.

### B. Cư Dân: Quản Lý Khách & Bưu Kiện ([`ResidentVisitorParcelScreen`](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/features/resident/screens/resident_visitor_parcel_screen.dart))
- **Tab 1: Khách viếng thăm:**
  - Nút "Đăng ký đón khách": Form nhập họ tên khách, số điện thoại, biển số xe, ngày giờ dự kiến đến, mục đích.
  - Thẻ vé khách điện tử: Hiển thị mã QR vé kích thước lớn rõ nét, chip trạng thái (Chờ đến, Đang trong nhà, Đã về), nút "Chia sẻ vé" (chia sẻ thông tin và mã QR qua các ứng dụng nhắn tin).
  - Nút hủy vé khi khách thay đổi lịch.
- **Tab 2: Bưu kiện của tôi:**
  - Danh sách các kiện hàng đang lưu tại sảnh lễ tân.
  - Thẻ kiện hàng chi tiết: Ảnh chụp bưu phẩm thực tế tại kệ, đơn vị vận chuyển, mã vận đơn, vị trí kệ sảnh.
  - Khung bảo mật mã nhận hàng: Mã PIN 6 số nổi bật to rõ ràng và mã QR lấy hàng đưa cho lễ tân khi xuống nhận.

---

## 5. Quy Trình Kiểm Thử & Tiêu Chí Nghiệm Thu (Quality Gate)
- **TDD:** Viết test trước cho toàn bộ SQL migration, models, repository và widget/integration tests.
- **Static Analysis:** `dart analyze` toàn bộ codebase đạt 0 issues (0 errors, 0 warnings).
- **Quy tắc thiết kế:** 100% tiếng Việt chuẩn mực, không hardcode màu sắc, co giãn linh hoạt word-wrap.
- **Commit:** Commit trực tiếp trên nhánh `main`.
