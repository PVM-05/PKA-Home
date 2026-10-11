# Thiết Kế Chi Tiết: Vá Các Lỗ Hổng Bảo Mật & Toàn Vẹn Dữ Liệu Nghiệp Vụ (P0/P1)

**Ngày lập:** 11/10/2026  
**Mục tiêu:** Khắc phục triệt để 5 vấn đề bảo mật, toàn vẹn dữ liệu và kiểm thử được rà soát từ mã nguồn và cơ sở dữ liệu thực tế.

---

## 1. Bối Cảnh & Đánh Giá Thực Tế

Sau khi kiểm tra trực tiếp qua hệ thống kiểm thử tự động, mã nguồn Flutter và schema Supabase PostgreSQL, kết quả đối chiếu xác nhận:

| STT | Vấn đề | Mức độ | Trạng thái xác minh | Hướng khắc phục |
| :--- | :--- | :--- | :--- | :--- |
| **1** | RPC `simulate_unified_payment` không kiểm tra quyền sở hữu hóa đơn / booking | **P0** (Nghiêm trọng) | **Chính xác**: Hàm `SECURITY DEFINER` không kiểm tra `auth.uid()` thuộc căn hộ hay sở hữu booking. Cư dân A có thể thanh toán thay cho B. | Kiểm tra `auth.uid()`, khóa `FOR UPDATE`, xác minh quyền trong `residents_apartments` hoặc `booked_by`, chặn thanh toán trùng / đã hủy. |
| **2** | Test RLS integration luôn bị bỏ qua (`skip`) | **P0** (Kiểm thử) | **Chính xác**: Biến `shouldSkip = true` được gán vào `skip:` khi test runner đăng ký test tĩnh, trong khi `setUpAll()` chạy sau đó nên bài test luôn bị skip. | Đọc cấu hình môi trường đồng bộ trước khi đăng ký group test, đảm bảo test chạy thật khi có credentials. |
| **3** | Duyệt chỉ số điện nước có thể làm giảm chỉ số gốc căn hộ | **P1** (Nghiệp vụ) | **Chính xác**: `approve_meter_reading` tính chênh lệch `GREATEST(0, ...)` nhưng vẫn cập nhật chỉ số lùi vào `apartments`, gây sai lệch kỳ sau. | Khóa bản ghi `apartments FOR UPDATE`, từ chối duyệt (`RAISE EXCEPTION`) nếu chỉ số mới nhỏ hơn chỉ số cũ. |
| **4** | Cấu hình `.env` thiếu xử lý ngoại lệ khi clone mới | **P1** (Môi trường) | **Chính xác**: `.env` trong assets nhưng bị gitignore, `dotenv.load()` thiếu try-catch fallback có thể crash app lúc khởi động. | Đóng gói thêm `.env.example`, bổ sung cơ chế fallback trong `main.dart` và thông báo cấu hình thân thiện trong `SupabaseConfig`. |
| **5** | Báo cáo `analyze_output.txt` ghi nhận lỗi phân tích tĩnh | **P1** (Đối chiếu) | **Đã sạch**: Chạy `flutter analyze` thực tế kết quả **"No issues found! (0 warnings, 0 errors)"**. File log cũ đã lỗi thời. | Cập nhật lại nội dung `analyze_output.txt` theo kết quả thực tế hiện tại. |

---

## 2. Thiết Kế Chi Tiết Từng Hạng Mục

### 2.1. Hạng mục 1 (P0): Siết chặt bảo mật RPC `simulate_unified_payment`

#### Mã SQL cũ gặp lỗi:
- `v_user_id := auth.uid();` không kiểm tra null.
- Nhánh `INVOICE`: `SELECT apartment_id, total_amount INTO v_apt_id, v_amount FROM public.invoices WHERE id = p_reference_id FOR UPDATE;` -> không kiểm tra `v_user_id` có quyền đối với `apartment_id`.
- Nhánh `SERVICE`: Lấy booking không kiểm tra `b.user_id = v_user_id`.
- `p_outcome`: Chấp nhận mọi chuỗi, không kiểm tra `upper(p_outcome) IN ('SUCCESS', 'FAILED')`.
- Không kiểm tra trạng thái hiện tại (`status = 'paid'`, `'cancelled'`, `'confirmed'`).

#### Giải pháp thiết kế:
```sql
CREATE OR REPLACE FUNCTION public.simulate_unified_payment(
  p_type VARCHAR,
  p_reference_id UUID,
  p_payment_method VARCHAR DEFAULT 'bank_transfer',
  p_outcome VARCHAR DEFAULT 'SUCCESS',
  p_failure_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_user_role VARCHAR;
  v_apt_id UUID;
  v_amount NUMERIC(12, 2);
  v_tx_id UUID;
  v_tx_code VARCHAR;
  v_title TEXT;
  v_clean_type VARCHAR := upper(p_type);
  v_clean_outcome VARCHAR := upper(p_outcome);
  v_inv_status VARCHAR;
  v_booking_user UUID;
  v_booking_status VARCHAR;
BEGIN
  -- 1. Bắt buộc đăng nhập
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Yêu cầu đăng nhập để thực hiện thanh toán';
  END IF;

  -- 2. Kiểm tra loại thanh toán & kết quả hợp lệ
  IF v_clean_type NOT IN ('INVOICE', 'SERVICE') THEN
    RAISE EXCEPTION 'Loại thanh toán không hợp lệ (chỉ hỗ trợ INVOICE hoặc SERVICE): %', p_type;
  END IF;

  IF v_clean_outcome NOT IN ('SUCCESS', 'FAILED') THEN
    RAISE EXCEPTION 'Kết quả thanh toán không hợp lệ (chỉ hỗ trợ SUCCESS hoặc FAILED): %', p_outcome;
  END IF;

  SELECT role INTO v_user_role FROM public.users WHERE id = v_user_id;

  v_tx_code := 'SIM-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') || '-' || upper(substr(gen_random_uuid()::text, 1, 6));

  -- 3. Xử lý nhánh INVOICE
  IF v_clean_type = 'INVOICE' THEN
    SELECT apartment_id, total_amount, status INTO v_apt_id, v_amount, v_inv_status
    FROM public.invoices
    WHERE id = p_reference_id FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Hóa đơn không tồn tại: %', p_reference_id;
    END IF;

    -- Kiểm tra trạng thái hóa đơn
    IF v_inv_status = 'paid' THEN
      RAISE EXCEPTION 'Hóa đơn này đã được thanh toán trước đó';
    END IF;
    IF v_inv_status = 'cancelled' THEN
      RAISE EXCEPTION 'Hóa đơn này đã bị hủy, không thể thanh toán';
    END IF;

    -- Kiểm soát phân quyền: Chỉ cư dân của căn hộ hoặc Admin/Manager mới được thanh toán
    IF COALESCE(v_user_role, 'resident') NOT IN ('admin', 'manager') THEN
      IF NOT EXISTS (
        SELECT 1 FROM public.residents_apartments 
        WHERE apartment_id = v_apt_id AND user_id = v_user_id
      ) THEN
        RAISE EXCEPTION 'Bạn không có quyền thanh toán hóa đơn của căn hộ này';
      END IF;
    END IF;

    v_title := 'Thanh toán hóa đơn tiền phòng/dịch vụ';

    IF v_clean_outcome = 'SUCCESS' THEN
      UPDATE public.invoices
      SET status = 'paid',
          payment_method = p_payment_method,
          transaction_code = v_tx_code,
          paid_at = now(),
          updated_at = now()
      WHERE id = p_reference_id;
    END IF;

    INSERT INTO public.payment_transactions (
      transaction_code, user_id, apartment_id, invoice_id, amount,
      payment_method, type, title, status, failure_reason, created_at
    ) VALUES (
      v_tx_code, v_user_id, v_apt_id, p_reference_id, v_amount,
      p_payment_method, 'INVOICE', v_title, v_clean_outcome,
      CASE WHEN v_clean_outcome = 'FAILED' THEN COALESCE(p_failure_reason, 'Giao dịch mô phỏng thất bại') ELSE NULL END,
      now()
    ) RETURNING id INTO v_tx_id;

  -- 4. Xử lý nhánh SERVICE
  ELSE
    SELECT b.apartment_id, b.user_id, b.status, b.fee_amount, a.name 
    INTO v_apt_id, v_booking_user, v_booking_status, v_amount, v_title
    FROM public.amenity_bookings b
    JOIN public.building_amenities a ON a.id = b.amenity_id
    WHERE b.id = p_reference_id FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Lượt đặt tiện ích không tồn tại: %', p_reference_id;
    END IF;

    -- Kiểm tra trạng thái lượt đặt
    IF v_booking_status = 'confirmed' THEN
      RAISE EXCEPTION 'Lượt đặt tiện ích này đã được xác nhận/thanh toán trước đó';
    END IF;
    IF v_booking_status IN ('cancelled', 'rejected') THEN
      RAISE EXCEPTION 'Lượt đặt tiện ích này đã bị hủy hoặc từ chối, không thể thanh toán';
    END IF;

    -- Kiểm soát quyền sở hữu: Người đặt, cư dân cùng căn hộ hoặc BQL
    IF COALESCE(v_user_role, 'resident') NOT IN ('admin', 'manager') THEN
      IF v_booking_user != v_user_id AND NOT EXISTS (
        SELECT 1 FROM public.residents_apartments
        WHERE apartment_id = v_apt_id AND user_id = v_user_id
      ) THEN
        RAISE EXCEPTION 'Bạn không có quyền thanh toán cho lượt đặt tiện ích này';
      END IF;
    END IF;

    v_title := 'Thanh toán dịch vụ ' || COALESCE(v_title, 'tiện ích');

    IF v_clean_outcome = 'SUCCESS' THEN
      UPDATE public.amenity_bookings
      SET status = 'confirmed',
          updated_at = now()
      WHERE id = p_reference_id;
    END IF;

    INSERT INTO public.payment_transactions (
      transaction_code, user_id, apartment_id, booking_id, amount,
      payment_method, type, title, status, failure_reason, created_at
    ) VALUES (
      v_tx_code, v_user_id, v_apt_id, p_reference_id, v_amount,
      p_payment_method, 'SERVICE', v_title, v_clean_outcome,
      CASE WHEN v_clean_outcome = 'FAILED' THEN COALESCE(p_failure_reason, 'Giao dịch mô phỏng thất bại') ELSE NULL END,
      now()
    ) RETURNING id INTO v_tx_id;
  END IF;

  RETURN jsonb_build_object(
    'success', v_clean_outcome = 'SUCCESS',
    'transaction_id', v_tx_id,
    'transaction_code', v_tx_code,
    'status', v_clean_outcome
  );
END;
$$;
```

---

### 2.2. Hạng mục 2 (P0): Sửa điều kiện kiểm thử RLS trong `test/integration/rls_security_test.dart`

#### Nguyên nhân:
- `shouldSkip` được tính toán trong `setUpAll()`, nhưng `skip:` ở tham số hàm `test()` được Dart Test Runner đọc ngay lúc gọi hàm `main()`. Do đó `shouldSkip = true` ban đầu làm test luôn bị skip.

#### Giải pháp thiết kế:
- Khởi tạo và nạp cấu hình môi trường đồng bộ ngay đầu `main()`:
```dart
void main() {
  if (File('.env').existsSync()) {
    try {
      dotenv.testLoad(fileString: File('.env').readAsStringSync());
    } catch (_) {}
  }

  final testResidentEmail = Platform.environment['TEST_RESIDENT_EMAIL'] ?? 
      dotenv.env['TEST_RESIDENT_EMAIL'] ?? 'resident101@test.com';
  final testResidentPassword = Platform.environment['TEST_RESIDENT_PASSWORD'] ?? 
      dotenv.env['TEST_RESIDENT_PASSWORD'] ?? 'password123';
  final testResidentApartmentId = Platform.environment['TEST_RESIDENT_APARTMENT_ID'] ?? 
      dotenv.env['TEST_RESIDENT_APARTMENT_ID'];

  final supabaseUrl = Platform.environment['SUPABASE_URL'] ?? dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = Platform.environment['SUPABASE_ANON_KEY'] ?? dotenv.env['SUPABASE_ANON_KEY'];

  final bool isConfigured = supabaseUrl != null &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey != null &&
      supabaseAnonKey.isNotEmpty &&
      testResidentApartmentId != null &&
      testResidentApartmentId.isNotEmpty &&
      testResidentApartmentId != 'FILL_UUID_HERE';

  final skipReason = isConfigured ? null : 'Chưa cấu hình tài khoản test thực tế trong .env';

  group('Kiểm thử RLS Bảo mật (Integration)', () {
    // Truyền skipReason tính toán đồng bộ vào group hoặc từng test
    ...
  }, skip: skipReason);
}
```

---

### 2.3. Hạng mục 3 (P1): Ngăn giảm chỉ số điện nước trong `approve_meter_reading`

#### Nguyên nhân:
- `approve_meter_reading` tính `v_elec_diff := GREATEST(0, v_sub.electric_reading - v_old_elec)` và `v_water_diff := GREATEST(0, v_sub.water_reading - v_old_water)`, nhưng sau đó vẫn cập nhật `apartments.electric_reading = v_sub.electric_reading` ngay cả khi chỉ số mới nhỏ hơn chỉ số cũ.
- Bảng `apartments` không được khóa `FOR UPDATE` trong transaction.

#### Giải pháp thiết kế:
1. Thêm `FOR UPDATE` khi đọc dữ liệu bảng `apartments`:
   ```sql
   SELECT area, COALESCE(electric_reading, 0), COALESCE(water_reading, 0)
   INTO v_area, v_old_elec, v_old_water
   FROM public.apartments
   WHERE id = v_sub.apartment_id FOR UPDATE;
   ```
2. Kiểm tra chặn chỉ số nhỏ hơn:
   ```sql
   IF v_sub.electric_reading < v_old_elec THEN
     RAISE EXCEPTION 'Chỉ số điện mới (%) không được nhỏ hơn chỉ số cũ (%) của căn hộ', v_sub.electric_reading, v_old_elec;
   END IF;

   IF v_sub.water_reading < v_old_water THEN
     RAISE EXCEPTION 'Chỉ số nước mới (%) không được nhỏ hơn chỉ số cũ (%) của căn hộ', v_sub.water_reading, v_old_water;
   END IF;

   v_elec_diff := v_sub.electric_reading - v_old_elec;
   v_water_diff := v_sub.water_reading - v_old_water;
   ```

---

### 2.4. Hạng mục 4 (P1): Quản lý an toàn cấu hình `.env` cho dự án clone mới

#### Giải pháp thiết kế:
1. Trong `pubspec.yaml`: Khai báo thêm `.env.example` trong danh sách assets:
   ```yaml
   flutter:
     assets:
       - .env.example
       - .env
   ```
2. Trong `lib/main.dart`:
   ```dart
   try {
     await dotenv.load(fileName: ".env");
   } catch (e) {
     debugPrint("Không thể nạp .env, thử nạp dự phòng .env.example: $e");
     try {
       await dotenv.load(fileName: ".env.example");
     } catch (_) {
       debugPrint("Chưa có file môi trường hợp lệ (.env hoặc .env.example)");
     }
   }
   ```
3. Trong `lib/core/supabase_config.dart`:
   Kiểm tra nếu thiếu `supabaseUrl` hoặc `supabaseAnonKey`, in cảnh báo rõ ràng hướng dẫn tạo file `.env` từ `.env.example`, tránh crash âm thầm với thông báo khó hiểu.

---

### 2.5. Hạng mục 5 (P1): Cập nhật báo cáo phân tích mã nguồn `analyze_output.txt`

- Cập nhật file `analyze_output.txt` phản ánh kết quả `flutter analyze` hiện tại: **No issues found!** để tránh gây hiểu nhầm khi review mã nguồn.

---

## 3. Kế Hoạch Xác Minh (Verification Strategy)

1. **Unit Test & Migration Content Test**: Chạy `flutter test test/data/migrations/p0_security_migration_content_test.dart` và `test/data/repositories/payment_and_timezone_verification_test.dart` để xác minh nội dung DDL/RPC.
2. **Cơ sở dữ liệu thực tế (Supabase MCP)**:
   - Thi hành migration vá lỗi trên PostgreSQL qua MCP `execute_sql`.
   - Kiểm tra hàm bằng truy vấn thử nghiệm (kiểm tra exception khi gọi trái phép hoặc chỉ số nhỏ hơn).
3. **Phân tích tĩnh**: Chạy `flutter analyze` xác nhận 0 lỗi, 0 cảnh báo.
4. **Toàn bộ Test Suite**: Chạy `flutter test` đảm bảo toàn bộ > 270 test đều PASS.
