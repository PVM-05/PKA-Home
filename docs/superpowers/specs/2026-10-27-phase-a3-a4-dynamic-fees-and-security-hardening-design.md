# Bản Thiết Kế: Giai Đoạn A3 & A4 - Biểu Phí Động, Quỹ Bảo Trì Thật & Chuẩn Hóa Bảo Mật Nền

- **Ngày tạo:** 2026-10-27
- **Trạng thái:** Chờ phê duyệt (Pending Approval)
- **Tác giả:** Antigravity AI Pair Programmer & Project Lead
- **Mục tiêu:** Xóa bỏ hoàn toàn hardcode tiền tệ (#4), loại bỏ dữ liệu ảo trong UI (#9), và nâng cao bảo mật cấu hình ứng dụng (#7).

---

## 1. Bối Cảnh & Vấn Đề Cần Giải Quyết

1. **Hardcode biểu phí:** Giá điện (3.500đ), nước (18.000đ), quản lý (16.500đ) bị gắn chết trong các màn hình Flutter (`bulk_invoice_dialog.dart`, `create_invoice_screen.dart`), các hàm repository (`management_repository.dart`) và SQL functions. Khi giá thay đổi, hệ thống buộc phải sửa code và deploy lại.
2. **Dữ liệu giả trong UI:**
   - `MaintenanceFundCard` hardcode 2,45 tỷ VNĐ, 127,4 triệu lãi ngân hàng, số tài khoản Vietcombank cứng.
   - `meter_reading_provider.dart` tự sinh bản ghi căn hộ `A0110` giả với 1250 kWh điện và 80 m³ nước khi xảy ra lỗi kết nối.
3. **Bảo mật cấu hình Release:** `android/app/build.gradle.kts` gán chết `signingConfig = signingConfigs.getByName("debug")` cho release build.

---

## 2. Kiến Trúc & Thiết Kế Kỹ Thuật

### 2.1. Biểu Phí Động (Dynamic Fee Schedules - A3)

#### A. Migration Database: `20261027_02_dynamic_fees_and_maintenance_fund.sql`
1. **Seed dữ liệu chuẩn cho `fee_schedules`:**
   - `electricity`: Đơn giá điện sinh hoạt 3.500 đ/kWh (đơn vị: 'kWh').
   - `water`: Đơn giá nước sinh hoạt 18.000 đ/m³ (đơn vị: 'm³').
   - `management`: Phí quản lý vận hành 16.500 đ/m² (đơn vị: 'm²').
   - `parking_motorcycle`: Phí trông giữ xe máy 100.000 đ/tháng (đơn vị: 'xe/tháng').
   - `parking_car`: Phí trông giữ ô tô 1.200.000 đ/tháng (đơn vị: 'xe/tháng').
2. **Hàm SQL tra cứu biểu phí theo thời gian:**
   ```sql
   CREATE OR REPLACE FUNCTION public.get_effective_fee_schedule(
       p_fee_type TEXT,
       p_date DATE DEFAULT CURRENT_DATE
   )
   RETURNS NUMERIC
   LANGUAGE sql
   STABLE
   SECURITY DEFINER
   SET search_path = public, pg_catalog
   AS $$
       SELECT unit_price FROM public.fee_schedules
       WHERE fee_type = p_fee_type
         AND is_active = true
         AND effective_from <= p_date
         AND (effective_to IS NULL OR effective_to >= p_date)
       ORDER BY effective_from DESC
       LIMIT 1;
   $$;
   ```
3. **Cập nhật `generate_valid_bulk_invoices`:**
   - Nếu client không truyền hoặc truyền `p_electric_rate IS NULL`, RPC tự động dùng `get_effective_fee_schedule('electricity')` (fallback về 3500 nếu chưa cấu hình).
   - Tương tự với `p_water_rate`.

#### B. Phía Client Flutter
1. **`FeeScheduleModel` & `FeeScheduleRepository`:**
   - Cung cấp phương thức `getFeeSchedules()` và `getEffectiveRate(String feeType)`.
2. **`feeScheduleProvider`:**
   - Riverpod `FutureProvider` cache danh sách biểu phí hiện hành.
3. **Màn hình lập hóa đơn (`bulk_invoice_dialog.dart`, `create_invoice_screen.dart`):**
   - Nạp giá trị ban đầu vào controller từ `feeScheduleProvider`. Khi BQL mở form, giá điện/nước hiển thị đúng biểu phí hiện hành từ DB.

---

### 2.2. Quỹ Bảo Trì Thực Tế (Maintenance Fund - A4/C5)

#### A. Database Schema
1. **Bảng `maintenance_funds`:**
   - `id UUID PRIMARY KEY DEFAULT gen_random_uuid()`
   - `total_balance NUMERIC(14,2) NOT NULL DEFAULT 0.0`
   - `annual_interest_earned NUMERIC(14,2) NOT NULL DEFAULT 0.0`
   - `interest_rate_percent NUMERIC(5,2) NOT NULL DEFAULT 0.0`
   - `collected_percent NUMERIC(5,2) NOT NULL DEFAULT 0.0`
   - `bank_name TEXT`
   - `bank_account_number TEXT`
   - `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`
   - `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`
2. **RLS Policies:**
   - Mọi người dùng đã đăng nhập (authenticated) được phép xem số liệu quỹ bảo trì minh bạch (`SELECT USING (true)`).
   - Chỉ Ban Quản Lý/Admin mới có quyền cập nhật số dư và thông tin quỹ (`public.is_staff_or_management()`).
3. **Seed 1 bản ghi ban đầu:** Số dư ban đầu hợp lệ hoặc 0 đ minh bạch.

#### B. Phía Client Flutter
1. **`MaintenanceFundModel` & `maintenanceFundProvider`:**
   - Lấy thông tin quỹ bảo trì từ bảng `maintenance_funds`.
2. **`MaintenanceFundCard`:**
   - Chuyển sang `ConsumerStatefulWidget`.
   - Đọc dữ liệu từ `maintenanceFundProvider`.
   - Hiển thị đúng số liệu thực tế từ database, xử lý trạng thái Loading / Error / Empty rõ ràng.

---

### 2.3. Loại Bỏ Dữ Liệu Ảo (Mock Data Sanitization - A4)

1. **`meter_reading_provider.dart`:**
   - Xóa bỏ khối fallback tự trả về căn hộ ảo `A0110` (1250 kWh, 80 m³).
   - Trả về `null` khi không tìm thấy hoặc lỗi, để giao diện hiển thị trạng thái căn hộ chưa có dữ liệu công tơ thực tế.

---

### 2.4. Cấu Hình Android Release Signing Chuẩn (Security Hardening - A4)

1. **`android/app/build.gradle.kts`:**
   - Đọc file `key.properties` nếu có.
   - Cấu hình `signingConfigs.create("release")` sử dụng `storeFile`, `storePassword`, `keyAlias`, `keyPassword`.
   - Khi không có `key.properties` (môi trường phát triển nội bộ), fallback dùng `signingConfigs.getByName("debug")` kèm thông báo log.
2. **`.gitignore`:**
   - Đảm bảo các file nhạy cảm `key.properties`, `*.keystore`, `*.jks` không bao giờ bị đưa lên git.

---

## 3. Kế Hoạch Xác Minh & Tiêu Chuẩn Nghiệm Thu

1. **Kiểm tra biên dịch tĩnh:** `flutter analyze` đạt 0 issues.
2. **Kiểm tra kiểm thử tự động:** Toàn bộ test suite vượt qua (100% PASS).
3. **Kiểm thử logic:**
   - Biểu phí động được fetch và hiển thị đúng trên UI lập hóa đơn.
   - `MaintenanceFundCard` render dữ liệu từ provider, không crash và không còn số liệu 2,45 tỷ hardcode.
   - `meter_reading_provider` không còn trả về fallback `A0110` ảo.
