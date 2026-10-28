# Kế Hoạch Thực Thi: Khắc Phục Lỗi Toàn Vẹn Dữ Liệu, Phân Quyền & Kiểm Thử Nghiệp Vụ (P1 Audit Fixes)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Khắc phục triệt để các lỗi P1 về bảo mật phân quyền sửa/hủy, thứ tự migration dọn trùng, trigger hạn mức 2 xe máy, xác thực giờ đổi lịch tiện ích theo Strict FIFO, và nâng cấp bộ kiểm thử 3 lớp đạt chuẩn nghiệm thu.

**Architecture:** Đồng bộ 3 tầng chặt chẽ: CSDL (Migration DDL sequencing, trigger an toàn, atomic RPCs), Repository (chuẩn hóa filter trạng thái và hợp đồng tham số RPC), UI & Testing (phản hồi trạng thái chính xác, unit test mock RPC, widget test và migration integrity test).

**Tech Stack:** PostgreSQL (PL/pgSQL, RLS, Triggers, Advisory Locks), Flutter/Dart, Riverpod, Supabase Flutter SDK, Mocktail.

## Global Constraints
- Tuân thủ quy định dự án: Commit trực tiếp vào nhánh `main`, không tạo branch/worktree phụ.
- Đảm bảo 100% tiếng Việt trên giao diện người dùng theo `design-rules.md`.
- Bảo toàn tính toàn vẹn tài chính và giao dịch kiểm toán: không xóa lịch sử thanh toán, không nuốt lỗi DDL.
- Quy tắc mã căn hộ chuẩn: `A0110` / `a0110`.

---

### Task 1: Migration Hardening & Chuẩn Hóa Thứ Tự DDL

**Files:**
- Modify: `supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql:22-47`
- Test: `test/data/repositories/pending_correction_migration_test.dart`

**Interfaces:**
- Consumes: Bảng `public.apartment_link_requests`, RPC `public.approve_link_request`.
- Produces: Cột `status VARCHAR(20)` có check constraint 4 trạng thái, dọn sạch trùng trước khi tạo partial unique index `uq_link_requests_active`.

- [x] **Step 1: Viết test kiểm tra thứ tự DDL và CTE dọn trùng**

Cập nhật `test/data/repositories/pending_correction_migration_test.dart`:
```dart
test('Migration phải dọn trùng dữ liệu và không chứa EXCEPTION WHEN OTHERS THEN NULL', () {
  final content = migrationFile.readAsStringSync();
  expect(content.contains('EXCEPTION WHEN OTHERS THEN NULL'), isFalse,
      reason: 'Khối nuốt lỗi DDL đã phải được loại bỏ hoàn toàn.');
  expect(content.contains('WITH duplicates AS'), isTrue,
      reason: 'Bắt buộc phải có CTE duplicates để dọn bản ghi trùng.');
  
  final dropDefaultIdx = content.indexOf('ALTER COLUMN status DROP DEFAULT');
  final alterTypeIdx = content.indexOf('ALTER COLUMN status TYPE VARCHAR(20)');
  final duplicatesIdx = content.indexOf('WITH duplicates AS');
  final createIndexIdx = content.indexOf('CREATE UNIQUE INDEX IF NOT EXISTS uq_link_requests_active');

  expect(dropDefaultIdx, isNonNegative);
  expect(alterTypeIdx, greaterThan(dropDefaultIdx));
  expect(duplicatesIdx, greaterThan(alterTypeIdx));
  expect(createIndexIdx, greaterThan(duplicatesIdx));
});
```

- [x] **Step 2: Chạy test để xác nhận test thất bại**

Run: `flutter test test/data/repositories/pending_correction_migration_test.dart`
Expected: FAIL (vì migration hiện tại vẫn chứa `EXCEPTION WHEN OTHERS THEN NULL` và chưa có `WITH duplicates AS`).

- [x] **Step 3: Cập nhật migration file với thứ tự DDL chuẩn và cập nhật các đối tượng phụ thuộc**

Tại `supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql`, thay thế khối 1.3 và 1.4:
```sql
-- 1.3 Chuyển đổi cột status của public.apartment_link_requests sang VARCHAR(20) an toàn
-- Xóa default cũ ràng buộc enum link_request_status
ALTER TABLE public.apartment_link_requests 
  ALTER COLUMN status DROP DEFAULT;

-- Chuyển kiểu dữ liệu sang VARCHAR(20)
ALTER TABLE public.apartment_link_requests 
  ALTER COLUMN status TYPE VARCHAR(20) USING status::text;

-- Gán default mới
ALTER TABLE public.apartment_link_requests 
  ALTER COLUMN status SET DEFAULT 'pending';

-- Áp dụng check constraint mới
ALTER TABLE public.apartment_link_requests DROP CONSTRAINT IF EXISTS apartment_link_requests_status_check;
ALTER TABLE public.apartment_link_requests ADD CONSTRAINT apartment_link_requests_status_check 
  CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'));

-- Xóa constraint UNIQUE cũ không điều kiện (nếu có)
ALTER TABLE public.apartment_link_requests DROP CONSTRAINT IF EXISTS apartment_link_requests_user_id_apartment_id_key;

-- Cập nhật RLS Policy "Resident tạo yêu cầu" tránh ép kiểu enum cũ
DROP POLICY IF EXISTS "Resident tạo yêu cầu" ON public.apartment_link_requests;
CREATE POLICY "Resident tạo yêu cầu" 
ON public.apartment_link_requests FOR INSERT 
WITH CHECK (user_id = auth.uid() AND status = 'pending');

-- Cập nhật RPC approve_link_request để biến v_status dùng VARCHAR(20) thay vì enum cũ
CREATE OR REPLACE FUNCTION public.approve_link_request(p_request_id UUID)
RETURNS void AS $$
DECLARE
  v_user_id UUID;
  v_apartment_id UUID;
  v_status VARCHAR(20);
  v_requested_role public.relation_type;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Chỉ Quản trị viên mới có quyền duyệt yêu cầu liên kết căn hộ.';
  END IF;

  SELECT user_id, apartment_id, status, requested_relation_role 
  INTO v_user_id, v_apartment_id, v_status, v_requested_role 
  FROM public.apartment_link_requests 
  WHERE id = p_request_id;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Không tìm thấy yêu cầu liên kết.';
  END IF;

  IF v_status != 'pending' THEN
    RAISE EXCEPTION 'Yêu cầu này đã được xử lý.';
  END IF;

  UPDATE public.apartment_link_requests
  SET status = 'approved',
      updated_at = now()
  WHERE id = p_request_id;

  INSERT INTO public.residents_apartments (user_id, apartment_id, relation_role)
  VALUES (v_user_id, v_apartment_id, v_requested_role)
  ON CONFLICT (user_id, apartment_id) DO NOTHING;

  UPDATE public.apartments
  SET is_empty = false
  WHERE id = v_apartment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

-- 1.4 Dọn dẹp bản ghi trùng lặp lịch sử trước khi tạo Partial Unique Index
-- Ưu tiên giữ lại bản ghi 'approved', nếu cùng trạng thái thì lấy bản ghi mới nhất (created_at DESC).
-- Các bản ghi trùng còn lại được chuyển sang 'cancelled'.
WITH duplicates AS (
    SELECT id,
           ROW_NUMBER() OVER (
               PARTITION BY user_id, apartment_id 
               ORDER BY (CASE WHEN status = 'approved' THEN 1 ELSE 2 END), created_at DESC
           ) as rn
    FROM public.apartment_link_requests
    WHERE status IN ('pending', 'approved')
)
UPDATE public.apartment_link_requests
SET status = 'cancelled', updated_at = NOW()
WHERE id IN (SELECT id FROM duplicates WHERE rn > 1);

-- Thiết lập Partial Unique Index
CREATE UNIQUE INDEX IF NOT EXISTS uq_link_requests_active 
ON public.apartment_link_requests(user_id, apartment_id) 
WHERE status IN ('pending', 'approved');
```

- [x] **Step 4: Chạy test để xác nhận test vượt qua**

Run: `flutter test test/data/repositories/pending_correction_migration_test.dart`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql test/data/repositories/pending_correction_migration_test.dart
git commit -m "fix: chuẩn hóa thứ tự DDL migration và dọn trùng link requests an toàn"
```

---

### Task 2: Thống Nhất Quyền Sở Hữu Nghiêm Ngặt Cho Phương Tiện & Phiếu Điện Nước

**Files:**
- Modify: `supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql:130-140, 456-464, 518-526`
- Test: `test/data/repositories/pending_correction_migration_test.dart`

**Interfaces:**
- Consumes: Bảng `public.vehicles`, `public.meter_reading_submissions`.
- Produces: RPC `update_pending_vehicle`, `cancel_pending_vehicle`, `update_pending_meter_reading`, `cancel_pending_meter_reading` loại bỏ hoàn toàn kiểm tra `residents_apartments`.

- [x] **Step 1: Viết test kiểm tra quyền nghiêm ngặt trong migration test**

Cập nhật `test/data/repositories/pending_correction_migration_test.dart`:
```dart
test('Các RPC sửa/hủy xe và điện nước không được chứa quyền thao tác chéo qua residents_apartments', () {
  final content = migrationFile.readAsStringSync();
  // Tìm khối RPC update_pending_vehicle
  final vehicleUpdateStart = content.indexOf('FUNCTION public.update_pending_vehicle');
  final vehicleUpdateEnd = content.indexOf('FUNCTION public.reschedule_amenity_booking');
  final vehicleUpdateBlock = content.substring(vehicleUpdateStart, vehicleUpdateEnd);
  expect(vehicleUpdateBlock.contains('residents_apartments'), isFalse,
      reason: 'update_pending_vehicle không được cho phép cư dân cùng căn hộ sửa xe.');

  // Tìm khối RPC meter reading
  final meterStart = content.indexOf('FUNCTION public.update_pending_meter_reading');
  final meterEnd = content.indexOf('FUNCTION public.cancel_apartment_link_request');
  final meterBlock = content.substring(meterStart, meterEnd);
  expect(meterBlock.contains('residents_apartments'), isFalse,
      reason: 'RPCs phiếu điện nước không được cho phép cư dân cùng căn hộ sửa/hủy chéo.');
});
```

- [x] **Step 2: Chạy test để xác nhận test thất bại**

Run: `flutter test test/data/repositories/pending_correction_migration_test.dart`
Expected: FAIL.

- [x] **Step 3: Cập nhật điều kiện quyền trong RPCs của migration**

Trong `supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql`:
1. `update_pending_vehicle`:
```sql
    -- Kiểm tra quyền: chỉ người tạo xe hoặc BQL (không cho phép cư dân cùng căn hộ thao tác chéo)
    IF v_vehicle.user_id != v_user_id 
       AND v_vehicle.registered_by != v_user_id 
       AND NOT public.is_staff() THEN
        RAISE EXCEPTION 'Bạn không có quyền chỉnh sửa thông tin phương tiện này.';
    END IF;
```
2. `update_pending_meter_reading`:
```sql
    -- Kiểm tra quyền: chỉ người nộp phiếu hoặc BQL
    IF v_sub.submitted_by != v_user_id AND NOT public.is_staff() THEN
        RAISE EXCEPTION 'Bạn không có quyền chỉnh sửa phiếu chỉ số này.';
    END IF;
```
3. `cancel_pending_meter_reading`:
```sql
    UPDATE public.meter_reading_submissions
    SET status = 'cancelled',
        updated_at = NOW()
    WHERE id = p_submission_id 
      AND status = 'pending'
      AND (
          submitted_by = v_user_id 
          OR public.is_staff()
      );
```

- [x] **Step 4: Chạy test để xác nhận test vượt qua**

Run: `flutter test test/data/repositories/pending_correction_migration_test.dart`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql test/data/repositories/pending_correction_migration_test.dart
git commit -m "fix: thống nhất quyền sở hữu nghiêm ngặt cho phương tiện và phiếu điện nước"
```

---

### Task 3: Củng Cố Hạn Mức 2 Xe Máy Cấp CSDL & Sửa Bộ Đếm Dart

**Files:**
- Modify: `supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql`
- Modify: `lib/data/repositories/vehicle_repository.dart:58-68`
- Test: `test/data/repositories/pending_correction_migration_test.dart`
- Test: `test/data/repositories/pending_requests_correction_repository_test.dart`

**Interfaces:**
- Consumes: Bảng `public.vehicles`, `VehicleRepository.getActiveMotorbikeCount`.
- Produces: Trigger `trg_check_vehicle_limits` cấp CSDL với `SECURITY DEFINER` và `SET search_path = public, pg_catalog`; bộ đếm Dart lọc chính xác `inFilter('status', ['pending', 'approved'])`.

- [x] **Step 1: Viết test cho trigger và bộ đếm xe máy**

Thêm vào `test/data/repositories/pending_correction_migration_test.dart`:
```dart
test('Migration phải định nghĩa trigger check_vehicle_limits có SECURITY DEFINER và khóa FOR UPDATE', () {
  final content = migrationFile.readAsStringSync();
  expect(content.contains('CREATE OR REPLACE FUNCTION public.check_vehicle_limits()'), isTrue);
  expect(content.contains('SECURITY DEFINER'), isTrue);
  expect(content.contains('SET search_path = public, pg_catalog'), isTrue);
  expect(content.contains('PERFORM 1 FROM public.apartments WHERE id = NEW.apartment_id FOR UPDATE'), isTrue);
  expect(content.contains('NEW.status IN (\'pending\', \'approved\')'), isTrue);
  expect(content.contains('CREATE TRIGGER trg_check_vehicle_limits'), isTrue);
});
```

- [x] **Step 2: Chạy test để xác nhận test thất bại**

Run: `flutter test test/data/repositories/pending_correction_migration_test.dart`
Expected: FAIL.

- [x] **Step 3: Bổ sung trigger check_vehicle_limits vào migration và sửa VehicleRepository**

1. Thêm định nghĩa trigger vào `supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql`:
```sql
-- 2.3 Củng cố Trigger kiểm tra hạn mức 2 xe máy cấp CSDL
CREATE OR REPLACE FUNCTION public.check_vehicle_limits()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    current_motorbike_count INT;
BEGIN
    -- Chỉ kiểm tra khi là xe máy và bản ghi ở trạng thái hoạt động (pending hoặc approved)
    IF NEW.vehicle_type = 'motorbike' AND NEW.status IN ('pending', 'approved') THEN
        IF NEW.apartment_id IS NULL THEN
            RAISE EXCEPTION 'Căn hộ không hợp lệ (apartment_id không được để trống).';
        END IF;

        -- Khóa dòng căn hộ để tuần tự hóa chống Race Condition đăng ký đồng thời
        PERFORM 1 FROM public.apartments WHERE id = NEW.apartment_id FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Không tìm thấy căn hộ tương ứng trong hệ thống.';
        END IF;

        -- Đếm số xe máy active của căn hộ, loại trừ chính bản ghi đang cập nhật
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
$$;

REVOKE ALL ON FUNCTION public.check_vehicle_limits() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.check_vehicle_limits() TO authenticated, service_role;

DROP TRIGGER IF EXISTS trg_check_vehicle_limits ON public.vehicles;
CREATE TRIGGER trg_check_vehicle_limits
BEFORE INSERT OR UPDATE ON public.vehicles
FOR EACH ROW EXECUTE FUNCTION public.check_vehicle_limits();
```

2. Cập nhật `lib/data/repositories/vehicle_repository.dart`:
```dart
  /// Lấy số lượng xe máy ĐANG HOẠT ĐỘNG (pending hoặc approved) để kiểm tra hạn mức 2 xe máy
  Future<int> getActiveMotorbikeCount(String apartmentId) async {
    final response = await _client
        .from('vehicles')
        .select('id')
        .eq('apartment_id', apartmentId)
        .eq('vehicle_type', 'motorbike')
        .inFilter('status', ['pending', 'approved']);

    return (response as List).length;
  }
```

- [x] **Step 4: Chạy test để xác nhận test vượt qua**

Run: `flutter test test/data/repositories/pending_correction_migration_test.dart`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql lib/data/repositories/vehicle_repository.dart test/data/repositories/pending_correction_migration_test.dart
git commit -m "fix: củng cố trigger hạn mức xe máy CSDL và sửa bộ đếm Dart loại trừ cancelled"
```

---

### Task 4: Khắc Phục Toàn Vẹn Đổi Lịch Tiện Ích & Đôn Waitlist Theo Strict FIFO

**Files:**
- Modify: `supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql:186-407`
- Test: `test/data/repositories/pending_correction_migration_test.dart`

**Interfaces:**
- Consumes: Bảng `public.amenity_bookings`, `public.building_amenities`, `public.payment_transactions`.
- Produces: RPC `public.reschedule_amenity_booking` xác thực regex định dạng giờ, `open_hours`, tính sức chứa slot cũ và đôn Waitlist theo Strict FIFO kèm đồng bộ thanh toán.

- [x] **Step 1: Viết test cho logic đổi lịch và Strict FIFO trong migration test**

Cập nhật `test/data/repositories/pending_correction_migration_test.dart`:
```dart
test('reschedule_amenity_booking phải kiểm tra định dạng giờ regex, logic start < end và Strict FIFO', () {
  final content = migrationFile.readAsStringSync();
  expect(content.contains('invalid_datetime_format'), isFalse,
      reason: 'Không được nuốt lỗi invalid_datetime_format trong đổi lịch.');
  expect(content.contains('^[0-2][0-9]:[0-5][0-9]'), isTrue,
      reason: 'Phải kiểm tra regex định dạng khung giờ.');
  expect(content.contains('v_slot_start_time >= v_slot_end_time'), isTrue,
      reason: 'Phải kiểm tra giờ bắt đầu nhỏ hơn giờ kết thúc.');
  expect(content.contains('v_old_slot_avail'), isTrue,
      reason: 'Phải tính sức chứa còn lại của slot cũ.');
  expect(content.contains('rescheduled_confirmed'), isTrue,
      reason: 'Phải trả về action cụ thể để UI hiển thị chuẩn.');
});
```

- [x] **Step 2: Chạy test để xác nhận test thất bại**

Run: `flutter test test/data/repositories/pending_correction_migration_test.dart`
Expected: FAIL.

- [x] **Step 3: Cập nhật toàn bộ RPC `reschedule_amenity_booking` trong migration**

Thay thế RPC `reschedule_amenity_booking` trong `supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql`:
```sql
CREATE OR REPLACE FUNCTION public.reschedule_amenity_booking(
    p_booking_id UUID,
    p_new_date DATE,
    p_new_time_slot VARCHAR,
    p_new_guests_count INT DEFAULT NULL,
    p_new_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID;
    v_booking RECORD;
    v_amenity RECORD;
    v_h_old BIGINT;
    v_h_new BIGINT;
    v_lock1 BIGINT;
    v_lock2 BIGINT;
    v_now_vn TIMESTAMP := (now() AT TIME ZONE 'Asia/Ho_Chi_Minh');
    v_slot_start_time TIME;
    v_slot_end_time TIME;
    v_open_start TIME;
    v_open_end TIME;
    v_final_guests INT;
    v_current_slot_capacity INT := 0;
    v_is_same_slot BOOLEAN := false;
    v_next_waitlist RECORD;
    v_new_fee NUMERIC;
    v_old_slot_used_guests INT := 0;
    v_old_slot_used_count INT := 0;
    v_old_slot_avail INT := 0;
    v_waitlist_promoted BOOLEAN := false;
    v_promoted_fee NUMERIC := 0;
    v_promoted_deposit NUMERIC := 0;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn chưa đăng nhập vào hệ thống';
    END IF;

    -- 1. Lấy thông tin booking hiện tại
    SELECT * INTO v_booking
    FROM public.amenity_bookings
    WHERE id = p_booking_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Lượt đặt tiện ích không tồn tại';
    END IF;

    IF v_booking.booked_by != v_user_id AND NOT public.is_staff() THEN
        RAISE EXCEPTION 'Bạn không có quyền đổi lịch cho lượt đặt tiện ích này.';
    END IF;

    IF v_booking.status NOT IN ('confirmed', 'pending_payment', 'waitlist') THEN
        RAISE EXCEPTION 'Chỉ có thể đổi lịch cho các lượt đặt đang xác nhận, chờ thanh toán hoặc trong hàng đợi.';
    END IF;

    -- 2. Lấy thông tin tiện ích
    SELECT * INTO v_amenity
    FROM public.building_amenities
    WHERE id = v_booking.amenity_id AND is_active = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tiện ích không tồn tại hoặc đã ngừng hoạt động';
    END IF;

    -- 3. Xác thực định dạng khung giờ mới bằng regex
    IF p_new_time_slot !~ '^[0-2][0-9]:[0-5][0-9]\s*-\s*[0-2][0-9]:[0-5][0-9]$' THEN
        RAISE EXCEPTION 'Định dạng khung giờ không hợp lệ. Yêu cầu định dạng HH:mm - HH:mm (VD: 08:00 - 10:00).';
    END IF;

    v_slot_start_time := TRIM(SPLIT_PART(p_new_time_slot, '-', 1))::time;
    v_slot_end_time := TRIM(SPLIT_PART(p_new_time_slot, '-', 2))::time;

    IF v_slot_start_time >= v_slot_end_time THEN
        RAISE EXCEPTION 'Khung giờ không hợp lệ: giờ bắt đầu (%) phải nhỏ hơn giờ kết thúc (%).', 
            v_slot_start_time, v_slot_end_time;
    END IF;

    -- Kiểm tra giờ mở cửa của tiện ích
    IF v_amenity.open_hours IS NOT NULL AND v_amenity.open_hours ~ '^[0-2][0-9]:[0-5][0-9]\s*-\s*[0-2][0-9]:[0-5][0-9]$' THEN
        v_open_start := TRIM(SPLIT_PART(v_amenity.open_hours, '-', 1))::time;
        v_open_end := TRIM(SPLIT_PART(v_amenity.open_hours, '-', 2))::time;
        IF v_slot_start_time < v_open_start OR v_slot_end_time > v_open_end THEN
            RAISE EXCEPTION 'Khung giờ mới (%) nằm ngoài giờ mở cửa của tiện ích (%).',
                p_new_time_slot, v_amenity.open_hours;
        END IF;
    END IF;

    -- 4. Kiểm tra slot cũ và slot mới so với thời điểm hiện tại
    IF v_booking.booking_date < (v_now_vn::date) THEN
        RAISE EXCEPTION 'Lượt đặt tiện ích này đã diễn ra trong quá khứ, không thể đổi lịch.';
    ELSIF v_booking.booking_date = (v_now_vn::date) THEN
        IF (v_now_vn::time) >= (TRIM(SPLIT_PART(v_booking.time_slot, '-', 1))::time) THEN
            RAISE EXCEPTION 'Lượt đặt hiện tại (%) đã bắt đầu hoặc đã qua, không thể đổi lịch.', v_booking.time_slot;
        END IF;
    END IF;

    IF p_new_date < (v_now_vn::date) THEN
        RAISE EXCEPTION 'Không thể dời lịch sang ngày trong quá khứ.';
    ELSIF p_new_date = (v_now_vn::date) THEN
        IF (v_now_vn::time) >= v_slot_start_time THEN
            RAISE EXCEPTION 'Khung giờ mới (%) đã bắt đầu hoặc đã qua trong hôm nay.', p_new_time_slot;
        END IF;
    END IF;

    -- Kiểm tra lịch bảo trì định kỳ tại slot mới
    IF EXISTS (
        SELECT 1 FROM public.amenity_maintenance_windows
        WHERE amenity_id = v_booking.amenity_id
          AND p_new_date BETWEEN start_date AND end_date
    ) THEN
        RAISE EXCEPTION 'Tiện ích đang trong thời gian bảo trì vào ngày đã chọn.';
    END IF;

    -- 5. Sắp xếp khóa Advisory theo thứ tự băm chống Deadlock
    v_h_old := hashtext(v_booking.amenity_id::text || '_' || v_booking.booking_date::text || '_' || v_booking.time_slot);
    v_h_new := hashtext(v_booking.amenity_id::text || '_' || p_new_date::text || '_' || p_new_time_slot);
    v_lock1 := LEAST(v_h_old, v_h_new);
    v_lock2 := GREATEST(v_h_old, v_h_new);

    PERFORM pg_advisory_xact_lock(v_lock1);
    IF v_lock1 <> v_lock2 THEN
        PERFORM pg_advisory_xact_lock(v_lock2);
    END IF;

    v_is_same_slot := (v_booking.booking_date = p_new_date AND v_booking.time_slot = p_new_time_slot);

    -- 6. Xác định số khách và tính toàn vẹn tài chính
    IF v_booking.status = 'confirmed' THEN
        v_final_guests := v_booking.guests_count;
    ELSE
        v_final_guests := COALESCE(p_new_guests_count, v_booking.guests_count, 1);
        IF v_final_guests < 1 THEN v_final_guests := 1; END IF;
        IF v_final_guests > v_amenity.max_capacity THEN
            RAISE EXCEPTION 'Số lượng người (% người) vượt quá sức chứa tối đa của tiện ích (% người)', 
                v_final_guests, v_amenity.max_capacity;
        END IF;
    END IF;

    -- 7. Kiểm tra sức chứa tại slot mới
    IF v_amenity.booking_type = 'exclusive' THEN
        SELECT COUNT(*) INTO v_current_slot_capacity
        FROM public.amenity_bookings
        WHERE amenity_id = v_booking.amenity_id
          AND booking_date = p_new_date
          AND time_slot = p_new_time_slot
          AND status IN ('confirmed', 'pending_payment')
          AND id <> p_booking_id;

        IF v_current_slot_capacity > 0 THEN
            RAISE EXCEPTION 'Khung giờ mới đã có người đặt trước (Độc quyền).';
        END IF;
    ELSE
        SELECT COALESCE(SUM(guests_count), 0) INTO v_current_slot_capacity
        FROM public.amenity_bookings
        WHERE amenity_id = v_booking.amenity_id
          AND booking_date = p_new_date
          AND time_slot = p_new_time_slot
          AND status IN ('confirmed', 'pending_payment')
          AND id <> p_booking_id;

        IF (v_current_slot_capacity + v_final_guests) > v_amenity.max_capacity THEN
            RAISE EXCEPTION 'Khung giờ mới không đủ chỗ cho % khách (chỉ còn trống % chỗ).',
                v_final_guests, (v_amenity.max_capacity - v_current_slot_capacity);
        END IF;
    END IF;

    -- 8. Điều chỉnh trạng thái và tiền nếu từ waitlist chuyển sang slot trống
    IF v_booking.status = 'waitlist' THEN
        IF COALESCE(v_amenity.fee_amount, 0) > 0 OR COALESCE(v_amenity.deposit_amount, 0) > 0 THEN
            v_booking.status := 'pending_payment';
        ELSE
            v_booking.status := 'confirmed';
        END IF;
    ELSIF v_booking.status = 'pending_payment' AND v_amenity.booking_type = 'shared' THEN
        v_new_fee := COALESCE(v_amenity.fee_amount, 0) * v_final_guests;
        UPDATE public.amenity_bookings
        SET fee_amount = v_new_fee
        WHERE id = p_booking_id;

        UPDATE public.payment_transactions
        SET amount = (v_new_fee + COALESCE(v_booking.deposit_amount, 0))
        WHERE (booking_id = p_booking_id OR invoice_id = p_booking_id::text)
          AND status = 'PENDING';
    END IF;

    -- 9. Cập nhật booking sang slot mới
    UPDATE public.amenity_bookings
    SET booking_date = p_new_date,
        time_slot = p_new_time_slot,
        guests_count = v_final_guests,
        notes = COALESCE(p_new_notes, notes),
        status = v_booking.status,
        updated_at = NOW()
    WHERE id = p_booking_id;

    -- 10. Đôn Waitlist cho slot cũ theo quy tắc Strict FIFO
    IF NOT v_is_same_slot THEN
        -- Tính sức chứa đã sử dụng của slot cũ sau khi lượt đặt dời đi
        SELECT COALESCE(SUM(guests_count), 0), COUNT(*) 
        INTO v_old_slot_used_guests, v_old_slot_used_count
        FROM public.amenity_bookings
        WHERE amenity_id = v_booking.amenity_id
          AND booking_date = v_booking.booking_date
          AND time_slot = v_booking.time_slot
          AND status IN ('confirmed', 'pending_payment');

        v_old_slot_avail := v_amenity.max_capacity - v_old_slot_used_guests;

        -- Tìm lượt Waitlist đầu tiên của slot cũ
        SELECT * INTO v_next_waitlist
        FROM public.amenity_bookings
        WHERE amenity_id = v_booking.amenity_id
          AND booking_date = v_booking.booking_date
          AND time_slot = v_booking.time_slot
          AND status = 'waitlist'
        ORDER BY created_at ASC
        LIMIT 1
        FOR UPDATE;

        IF FOUND THEN
            -- Kiểm tra điều kiện đôn:
            -- Exclusive: slot hoàn toàn chưa có ai xác nhận/chờ thanh toán
            -- Shared: số khách lượt đầu <= sức chứa còn trống
            IF (v_amenity.booking_type = 'exclusive' AND v_old_slot_used_count = 0)
               OR (v_amenity.booking_type = 'shared' AND v_next_waitlist.guests_count <= v_old_slot_avail) THEN
                
                v_promoted_fee := COALESCE(v_amenity.fee_amount, 0) * v_next_waitlist.guests_count;
                v_promoted_deposit := COALESCE(v_amenity.deposit_amount, 0);

                IF (v_promoted_fee + v_promoted_deposit) > 0 THEN
                    UPDATE public.amenity_bookings
                    SET status = 'pending_payment',
                        fee_amount = v_promoted_fee,
                        deposit_amount = v_promoted_deposit,
                        deposit_status = CASE WHEN v_promoted_deposit > 0 THEN 'pending' ELSE 'none' END,
                        updated_at = NOW()
                    WHERE id = v_next_waitlist.id;

                    UPDATE public.payment_transactions
                    SET amount = (v_promoted_fee + v_promoted_deposit),
                        updated_at = NOW()
                    WHERE booking_id = v_next_waitlist.id AND status = 'PENDING';
                ELSE
                    UPDATE public.amenity_bookings
                    SET status = 'confirmed', updated_at = NOW()
                    WHERE id = v_next_waitlist.id;
                END IF;

                v_waitlist_promoted := true;
            END IF;
            -- Nếu không đủ chỗ: giữ nguyên trong Waitlist (Strict FIFO - không nhảy cóc)
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'action', CASE 
            WHEN v_booking.status = 'confirmed' THEN 'rescheduled_confirmed'
            ELSE 'rescheduled_pending_payment'
        END,
        'status', v_booking.status,
        'waitlist_promoted', v_waitlist_promoted,
        'message', 'Đổi lịch đặt tiện ích thành công',
        'booking_id', p_booking_id,
        'new_date', p_new_date,
        'new_time_slot', p_new_time_slot
    );
END;
$$;
```

- [x] **Step 4: Chạy test để xác nhận test vượt qua**

Run: `flutter test test/data/repositories/pending_correction_migration_test.dart`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql test/data/repositories/pending_correction_migration_test.dart
git commit -m "fix: xác thực khung giờ nghiêm ngặt và đôn Waitlist theo Strict FIFO"
```

---

### Task 5: Viết Lại Repository Unit Test Chuẩn Mực & Cập Nhật UI SnackBar

**Files:**
- Modify: `lib/features/resident/screens/amenity_booking_screen.dart:1230-1244`
- Modify: `test/data/repositories/pending_requests_correction_repository_test.dart`
- Test: `test/data/repositories/pending_requests_correction_repository_test.dart`
- Test: `test/features/resident/amenity_reschedule_test.dart`

**Interfaces:**
- Consumes: `VehicleRepository`, `AmenityBookingRepository`, `MeterReadingRepository`.
- Produces: Bộ unit test Mocktail xác minh từng tham số RPC, dữ liệu trả về và ngoại lệ; UI hiển thị SnackBar theo `action` và `status`.

- [x] **Step 1: Viết bộ unit test repository toàn diện với Mocktail**

Viết lại toàn bộ `test/data/repositories/pending_requests_correction_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/repositories/vehicle_repository.dart';
import 'package:pka_home/data/repositories/amenity_booking_repository.dart';
import 'package:pka_home/data/repositories/meter_reading_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('Repository Unit Tests: Sửa sai & Hủy yêu cầu chờ duyệt', () {
    late MockSupabaseClient mockClient;

    setUp(() {
      mockClient = MockSupabaseClient();
    });

    group('VehicleRepository', () {
      test('updatePendingVehicle gọi đúng RPC update_pending_vehicle và map tham số', () async {
        when(() => mockClient.rpc(
              'update_pending_vehicle',
              params: any(named: 'params'),
            )).thenAnswer((_) async => {'success': true, 'message': 'OK'});

        final repo = VehicleRepository(mockClient);
        await repo.updatePendingVehicle(
          vehicleId: 'veh-123',
          licensePlate: '29A-12345',
          vehicleType: 'motorbike',
          brandModel: 'Honda Wave',
        );

        verify(() => mockClient.rpc('update_pending_vehicle', params: {
              'p_vehicle_id': 'veh-123',
              'p_license_plate': '29A-12345',
              'p_vehicle_type': 'motorbike',
              'p_brand_model': 'Honda Wave',
            })).called(1);
      });

      test('cancelPendingVehicle gọi đúng RPC cancel_pending_vehicle', () async {
        when(() => mockClient.rpc(
              'cancel_pending_vehicle',
              params: any(named: 'params'),
            )).thenAnswer((_) async => {'success': true, 'message': 'OK'});

        final repo = VehicleRepository(mockClient);
        await repo.cancelPendingVehicle('veh-123');

        verify(() => mockClient.rpc('cancel_pending_vehicle', params: {
              'p_vehicle_id': 'veh-123',
            })).called(1);
      });

      test('cancelPendingVehicle ném Exception khi RPC trả về success = false', () async {
        when(() => mockClient.rpc(
              'cancel_pending_vehicle',
              params: any(named: 'params'),
            )).thenAnswer((_) async => {'success': false, 'message': 'Không có quyền'});

        final repo = VehicleRepository(mockClient);
        expect(
          () => repo.cancelPendingVehicle('veh-123'),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Không có quyền'))),
        );
      });
    });

    group('AmenityBookingRepository', () {
      test('rescheduleBooking gọi đúng RPC reschedule_amenity_booking với đúng định dạng tham số', () async {
        final targetDate = DateTime(2026, 11, 1);
        when(() => mockClient.rpc(
              'reschedule_amenity_booking',
              params: any(named: 'params'),
            )).thenAnswer((_) async => {
              'success': true,
              'action': 'rescheduled_confirmed',
              'status': 'confirmed',
              'message': 'Đổi lịch thành công',
            });

        final repo = AmenityBookingRepository(mockClient);
        final res = await repo.rescheduleBooking(
          bookingId: 'bk-123',
          newDate: targetDate,
          newTimeSlot: '08:00 - 10:00',
          newGuestsCount: 2,
          newNotes: 'Ghi chú',
        );

        verify(() => mockClient.rpc('reschedule_amenity_booking', params: {
              'p_booking_id': 'bk-123',
              'p_new_date': '2026-11-01',
              'p_new_time_slot': '08:00 - 10:00',
              'p_new_guests_count': 2,
              'p_new_notes': 'Ghi chú',
            })).called(1);

        expect(res['action'], 'rescheduled_confirmed');
        expect(res['status'], 'confirmed');
      });

      test('rescheduleBooking ném Exception khi RPC trả về success = false', () async {
        when(() => mockClient.rpc(
              'reschedule_amenity_booking',
              params: any(named: 'params'),
            )).thenAnswer((_) async => {'success': false, 'message': 'Khung giờ đã hết chỗ'});

        final repo = AmenityBookingRepository(mockClient);
        expect(
          () => repo.rescheduleBooking(
            bookingId: 'bk-123',
            newDate: DateTime(2026, 11, 1),
            newTimeSlot: '08:00 - 10:00',
          ),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Khung giờ đã hết chỗ'))),
        );
      });
    });

    group('MeterReadingRepository', () {
      test('updatePendingSubmission gọi đúng RPC update_pending_meter_reading', () async {
        when(() => mockClient.rpc(
              'update_pending_meter_reading',
              params: any(named: 'params'),
            )).thenAnswer((_) async => {'success': true, 'message': 'OK'});

        final repo = MeterReadingRepository(mockClient);
        await repo.updatePendingSubmission(
          submissionId: 'sub-123',
          electricReading: 120.5,
          waterReading: 30.0,
          clearElectricImage: true,
        );

        verify(() => mockClient.rpc('update_pending_meter_reading', params: {
              'p_submission_id': 'sub-123',
              'p_electric_reading': 120.5,
              'p_water_reading': 30.0,
              'p_electric_image_url': null,
              'p_water_image_url': null,
              'p_clear_electric_image': true,
              'p_clear_water_image': false,
            })).called(1);
      });

      test('cancelPendingSubmission gọi đúng RPC cancel_pending_meter_reading', () async {
        when(() => mockClient.rpc(
              'cancel_pending_meter_reading',
              params: any(named: 'params'),
            )).thenAnswer((_) async => {'success': true, 'message': 'OK'});

        final repo = MeterReadingRepository(mockClient);
        await repo.cancelPendingSubmission('sub-123');

        verify(() => mockClient.rpc('cancel_pending_meter_reading', params: {
              'p_submission_id': 'sub-123',
            })).called(1);
      });
    });
  });
}
```

- [x] **Step 2: Cập nhật thông báo đổi lịch trong AmenityBookingScreen**

Tại `lib/features/resident/screens/amenity_booking_screen.dart`:
```dart
      if (mounted) {
        Navigator.pop(context);
        final action = res['action'] as String?;
        final status = res['status'] as String?;

        String successMsg;
        if (action == 'rescheduled_pending_payment' || status == 'pending_payment') {
          successMsg = 'Đổi lịch thành công! Vui lòng hoàn tất thanh toán cho lịch đặt mới.';
        } else {
          successMsg = 'Đổi lịch đặt chỗ thành công!';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: AppTheme.success,
          ),
        );
      }
```
Và trong khối catch ngoại lệ của `rescheduleBooking`:
```dart
    } catch (e) {
      if (mounted) {
        final errText = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errText),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
```

- [x] **Step 3: Chạy test repository**

Run: `flutter test test/data/repositories/pending_requests_correction_repository_test.dart`
Expected: PASS.

- [x] **Step 4: Chạy test UI amenity reschedule**

Run: `flutter test test/features/resident/amenity_reschedule_test.dart`
Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add lib/features/resident/screens/amenity_booking_screen.dart test/data/repositories/pending_requests_correction_repository_test.dart
git commit -m "test: nâng cấp unit test repository với Mocktail và chuẩn hóa SnackBar UI"
```

---

### Task 6: Kiểm Thử Toàn Diện & Phân Tích Mã Nguồn (Verification)

**Files:**
- Toàn bộ codebase.

- [x] **Step 1: Chạy Dart Code Analysis**

Run: `dart analyze`
Expected: No errors / warnings.

- [x] **Step 2: Chạy toàn bộ bộ kiểm thử Flutter**

Run: `flutter test`
Expected: 100% tests pass.

- [x] **Step 3: Commit xác nhận nghiệm thu**

```bash
git commit --allow-empty -m "chore: hoàn tất kiểm thử toàn diện và xác minh chất lượng hệ thống"
```
