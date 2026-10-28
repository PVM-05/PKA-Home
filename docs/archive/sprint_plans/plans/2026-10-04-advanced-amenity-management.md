# Kế Hoạch Triển Khai: Quản Lý Tiện Ích Nâng Cao (Advanced Amenity Management)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hoàn thiện module Quản lý tiện ích nâng cao cho cư dân và ban quản lý PKA-Home, khắc phục triệt để race condition khi đặt trùng slot, hỗ trợ sức chứa dùng chung/độc quyền, danh sách chờ (waitlist) tự động đôn FIFO an toàn đồng thời, lịch bảo trì tự động khóa slot, và quản lý snapshot phí/cọc.

**Architecture:** Sử dụng kiến trúc PostgreSQL Atomic RPC (`book_amenity_slot`) với khóa dòng `FOR UPDATE` và trigger đôn waitlist `FOR UPDATE SKIP LOCKED`. Ở tầng client Flutter, áp dụng Riverpod state management, tách biệt thuật toán tính khung giờ/bảo trì vào `AmenitySlotHelper` độc lập theo TDD, sau đó tích hợp vào UI Cư dân (`AmenityBookingScreen`) và màn hình BQL (`AmenityManagementScreen`).

**Tech Stack:** Flutter (Dart 3.x), Riverpod, GoRouter, Supabase PostgreSQL, Supabase RPC & RLS Policies.

## Global Constraints

- **Language:** 100% Tiếng Việt chuẩn mực trên mọi màn hình và thông báo lỗi.
- **Fail-Closed Security:** Mọi thao tác đều kiểm tra quyền hạn chặt chẽ (`public.is_staff()` hoặc quyền căn hộ `residents_apartments`).
- **Data Integrity:** Không bao giờ gọi Supabase trực tiếp từ Widget — luôn thông qua tầng Repository.
- **UI/UX Consistency:** Sử dụng `AppCard`, `AppTheme` (màu sắc ngữ nghĩa `paid`, `unpaid`, `pending`, `error`, `primary`), font Inter, không hardcode kích thước cố định gây overflow.
- **TDD:** Mọi task đều viết test trước hoặc đi kèm unit test xác minh độc lập.

---

### Task 1: Supabase Migration (Database Schema, Atomic RPC & Trigger)

**Files:**
- Create: `supabase/migrations/20261004_01_advanced_amenity_management.sql`

**Interfaces:**
- Produces:
  - Cột mới trong `public.building_amenities`: `booking_type`, `max_capacity`, `slot_duration_minutes`, `fee_amount`, `deposit_amount`, `requires_deposit`, `is_active`.
  - Bảng mới `public.amenity_maintenance_windows` + RLS policies.
  - Cột mới trong `public.amenity_bookings`: `guests_count`, `fee_amount`, `deposit_amount`, `deposit_status`, `deposit_notes`, mở rộng enum `status`.
  - RPC: `public.book_amenity_slot(p_amenity_id UUID, p_apartment_id UUID, p_booking_date DATE, p_time_slot VARCHAR, p_guests_count INT, p_allow_waitlist BOOLEAN) -> JSONB`.
  - Trigger: `trg_amenity_booking_cancellation` gọi `handle_amenity_booking_cancellation()` đôn waitlist.

- [ ] **Step 1: Soạn file migration SQL với đầy đủ 7 cải tiến an toàn**

```sql
-- Migration: 20261004_01_advanced_amenity_management.sql
-- 1. Nâng cấp building_amenities
ALTER TABLE public.building_amenities
ADD COLUMN IF NOT EXISTS booking_type VARCHAR(20) NOT NULL DEFAULT 'exclusive' 
    CHECK (booking_type IN ('exclusive', 'shared')),
ADD COLUMN IF NOT EXISTS max_capacity INT NOT NULL DEFAULT 1 CHECK (max_capacity >= 1),
ADD COLUMN IF NOT EXISTS slot_duration_minutes INT NOT NULL DEFAULT 90 CHECK (slot_duration_minutes >= 30),
ADD COLUMN IF NOT EXISTS fee_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (fee_amount >= 0),
ADD COLUMN IF NOT EXISTS deposit_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (deposit_amount >= 0),
ADD COLUMN IF NOT EXISTS requires_deposit BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- 2. Bảng amenity_maintenance_windows
CREATE TABLE IF NOT EXISTS public.amenity_maintenance_windows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    amenity_id UUID NOT NULL REFERENCES public.building_amenities(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    reason TEXT NOT NULL,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_maintenance_time CHECK (end_time > start_time)
);

CREATE INDEX IF NOT EXISTS idx_amenity_maint_time 
ON public.amenity_maintenance_windows (amenity_id, start_time, end_time);

ALTER TABLE public.amenity_maintenance_windows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Mọi người xem lịch bảo trì tiện ích" ON public.amenity_maintenance_windows;
CREATE POLICY "Mọi người xem lịch bảo trì tiện ích"
ON public.amenity_maintenance_windows FOR SELECT
USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Ban quản lý quản trị lịch bảo trì" ON public.amenity_maintenance_windows;
CREATE POLICY "Ban quản lý quản trị lịch bảo trì"
ON public.amenity_maintenance_windows FOR ALL
USING (public.is_staff());

-- 3. Nâng cấp amenity_bookings
ALTER TABLE public.amenity_bookings 
DROP CONSTRAINT IF EXISTS amenity_bookings_status_check;

ALTER TABLE public.amenity_bookings 
ADD CONSTRAINT amenity_bookings_status_check 
CHECK (status IN ('confirmed', 'waitlist', 'cancelled', 'completed', 'no_show'));

ALTER TABLE public.amenity_bookings
ADD COLUMN IF NOT EXISTS guests_count INT NOT NULL DEFAULT 1 CHECK (guests_count >= 1),
ADD COLUMN IF NOT EXISTS fee_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (fee_amount >= 0),
ADD COLUMN IF NOT EXISTS deposit_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (deposit_amount >= 0),
ADD COLUMN IF NOT EXISTS deposit_status VARCHAR(20) NOT NULL DEFAULT 'none' 
    CHECK (deposit_status IN ('none', 'pending', 'received', 'refunded', 'forfeited')),
ADD COLUMN IF NOT EXISTS deposit_notes TEXT;

-- Bỏ unique index cũ chỉ cho phép 1 lượt đặt/slot để hỗ trợ shared capacity
DROP INDEX IF EXISTS uq_active_amenity_slot;

-- 4. RPC book_amenity_slot (FOR UPDATE + interval overlap + apartment check + validation)
CREATE OR REPLACE FUNCTION public.book_amenity_slot(
    p_amenity_id UUID,
    p_apartment_id UUID,
    p_booking_date DATE,
    p_time_slot VARCHAR,
    p_guests_count INT DEFAULT 1,
    p_allow_waitlist BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_amenity RECORD;
    v_maint_count INT;
    v_current_confirmed_count INT := 0;
    v_new_status VARCHAR := 'confirmed';
    v_booking_id UUID;
    v_slot_start_time TIMESTAMPTZ;
    v_slot_end_time TIMESTAMPTZ;
    v_start_time_str TEXT;
    v_end_time_str TEXT;
    v_has_access BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Bạn cần đăng nhập để đặt tiện ích.';
    END IF;

    IF NOT public.is_staff() THEN
        SELECT EXISTS (
            SELECT 1 FROM public.residents_apartments 
            WHERE user_id = v_user_id AND apartment_id = p_apartment_id
        ) INTO v_has_access;

        IF NOT v_has_access THEN
            RAISE EXCEPTION 'Bạn không có quyền đại diện căn hộ này để đặt tiện ích.';
        END IF;
    END IF;

    IF p_booking_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Không thể đặt tiện ích cho ngày trong quá khứ.';
    END IF;

    IF p_guests_count <= 0 THEN
        RAISE EXCEPTION 'Số lượng người tham gia phải lớn hơn 0.';
    END IF;

    IF position(' - ' IN p_time_slot) = 0 THEN
        RAISE EXCEPTION 'Định dạng khung giờ không hợp lệ (Phải có dạng HH:mm - HH:mm).';
    END IF;

    v_start_time_str := split_part(p_time_slot, ' - ', 1);
    v_end_time_str := split_part(p_time_slot, ' - ', 2);
    v_slot_start_time := (p_booking_date::text || ' ' || v_start_time_str || ':00')::timestamptz;
    v_slot_end_time := (p_booking_date::text || ' ' || v_end_time_str || ':00')::timestamptz;

    IF p_booking_date = CURRENT_DATE AND v_slot_start_time <= NOW() THEN
        RAISE EXCEPTION 'Khung giờ này đã bắt đầu hoặc đã qua trong hôm nay.';
    END IF;

    -- Khóa dòng tiện ích để serialize giao dịch đồng thời
    SELECT * INTO v_amenity 
    FROM public.building_amenities 
    WHERE id = p_amenity_id AND is_active = true
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tiện ích không tồn tại hoặc đang tạm ngưng hoạt động.';
    END IF;

    IF p_guests_count > v_amenity.max_capacity THEN
        RAISE EXCEPTION 'Số lượng người đặt (% người) vượt quá sức chứa tối đa của tiện ích (% người).', 
            p_guests_count, v_amenity.max_capacity;
    END IF;

    -- Kiểm tra giao cắt khoảng bảo trì
    SELECT count(*) INTO v_maint_count
    FROM public.amenity_maintenance_windows
    WHERE amenity_id = p_amenity_id
      AND v_slot_start_time < end_time
      AND v_slot_end_time > start_time;

    IF v_maint_count > 0 THEN
        RAISE EXCEPTION 'Khung giờ này tiện ích đang tạm đóng để bảo trì/vệ sinh.';
    END IF;

    -- Đếm số chỗ đã confirmed
    IF v_amenity.booking_type = 'exclusive' THEN
        SELECT count(*) INTO v_current_confirmed_count
        FROM public.amenity_bookings
        WHERE amenity_id = p_amenity_id
          AND booking_date = p_booking_date
          AND time_slot = p_time_slot
          AND status = 'confirmed';
    ELSE
        SELECT COALESCE(SUM(guests_count), 0) INTO v_current_confirmed_count
        FROM public.amenity_bookings
        WHERE amenity_id = p_amenity_id
          AND booking_date = p_booking_date
          AND time_slot = p_time_slot
          AND status = 'confirmed';
    END IF;

    IF (v_current_confirmed_count + p_guests_count) <= v_amenity.max_capacity THEN
        v_new_status := 'confirmed';
    ELSE
        IF p_allow_waitlist THEN
            v_new_status := 'waitlist';
        ELSE
            RAISE EXCEPTION 'Khung giờ này đã hết chỗ (Sức chứa còn lại: % chỗ).', 
                GREATEST(0, v_amenity.max_capacity - v_current_confirmed_count);
        END IF;
    END IF;

    INSERT INTO public.amenity_bookings (
        amenity_id,
        apartment_id,
        booked_by,
        booking_date,
        time_slot,
        status,
        guests_count,
        fee_amount,
        deposit_amount,
        deposit_status
    ) VALUES (
        p_amenity_id,
        p_apartment_id,
        v_user_id,
        p_booking_date,
        p_time_slot,
        v_new_status,
        p_guests_count,
        v_amenity.fee_amount,
        v_amenity.deposit_amount,
        CASE WHEN v_amenity.requires_deposit THEN 'pending' ELSE 'none' END
    ) RETURNING id INTO v_booking_id;

    RETURN jsonb_build_object(
        'success', true,
        'booking_id', v_booking_id,
        'status', v_new_status,
        'message', CASE 
            WHEN v_new_status = 'confirmed' THEN 'Đặt lịch thành công!'
            ELSE 'Khung giờ đã kín chỗ, bạn đã được thêm vào Danh Sách Chờ.'
        END
    );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.book_amenity_slot(UUID, UUID, DATE, VARCHAR, INT, BOOLEAN) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.book_amenity_slot(UUID, UUID, DATE, VARCHAR, INT, BOOLEAN) TO authenticated;

-- 5. Trigger đôn Waitlist an toàn với FOR UPDATE SKIP LOCKED
CREATE OR REPLACE FUNCTION public.handle_amenity_booking_cancellation()
RETURNS TRIGGER AS $$
DECLARE
    v_amenity RECORD;
    v_waitlist_rec RECORD;
    v_current_confirmed_count INT := 0;
    v_available_capacity INT := 0;
BEGIN
    IF OLD.status = 'confirmed' AND NEW.status = 'cancelled' THEN
        SELECT * INTO v_amenity 
        FROM public.building_amenities 
        WHERE id = NEW.amenity_id 
        FOR UPDATE;

        IF FOUND THEN
            IF v_amenity.booking_type = 'exclusive' THEN
                SELECT count(*) INTO v_current_confirmed_count
                FROM public.amenity_bookings
                WHERE amenity_id = NEW.amenity_id
                  AND booking_date = NEW.booking_date
                  AND time_slot = NEW.time_slot
                  AND status = 'confirmed';
            ELSE
                SELECT COALESCE(SUM(guests_count), 0) INTO v_current_confirmed_count
                FROM public.amenity_bookings
                WHERE amenity_id = NEW.amenity_id
                  AND booking_date = NEW.booking_date
                  AND time_slot = NEW.time_slot
                  AND status = 'confirmed';
            END IF;

            v_available_capacity := v_amenity.max_capacity - v_current_confirmed_count;

            FOR v_waitlist_rec IN
                SELECT id, booked_by, guests_count
                FROM public.amenity_bookings
                WHERE amenity_id = NEW.amenity_id
                  AND booking_date = NEW.booking_date
                  AND time_slot = NEW.time_slot
                  AND status = 'waitlist'
                  AND guests_count <= v_available_capacity
                ORDER BY created_at ASC
                FOR UPDATE SKIP LOCKED
            LOOP
                UPDATE public.amenity_bookings
                SET status = 'confirmed', updated_at = NOW()
                WHERE id = v_waitlist_rec.id;

                INSERT INTO public.notifications (user_id, title, content, type)
                VALUES (
                    v_waitlist_rec.booked_by,
                    'Lịch tiện ích đã được xác nhận!',
                    format('Khung giờ %s ngày %s cho tiện ích %s đã có chỗ trống và tự động xác nhận cho bạn.', 
                        NEW.time_slot, NEW.booking_date, v_amenity.name),
                    'amenity'
                );

                v_available_capacity := v_available_capacity - v_waitlist_rec.guests_count;
                EXIT WHEN v_available_capacity <= 0;
            END LOOP;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_amenity_booking_cancellation ON public.amenity_bookings;
CREATE TRIGGER trg_amenity_booking_cancellation
AFTER UPDATE OF status ON public.amenity_bookings
FOR EACH ROW EXECUTE FUNCTION public.handle_amenity_booking_cancellation();
```

- [ ] **Step 2: Commit file migration vào git**

```bash
git add supabase/migrations/20261004_01_advanced_amenity_management.sql
git commit -m "feat: thêm migration SQL cho quản lý tiện ích nâng cao và atomic RPC"
```

---

### Task 2: Cập Nhật & Mở Rộng Data Models

**Files:**
- Modify: `lib/data/models/building_amenity_model.dart`
- Modify: `lib/data/models/amenity_booking_model.dart`
- Create: `lib/data/models/amenity_maintenance_model.dart`
- Create: `test/data/models/amenity_model_test.dart`

**Interfaces:**
- `BuildingAmenityModel`: Thêm `bookingType`, `maxCapacity`, `slotDurationMinutes`, `feeAmount`, `depositAmount`, `requiresDeposit`, `isActive`.
- `AmenityBookingModel`: Mở rộng `status` (có `isWaitlist`, `isCompleted`, `isNoShow`), thêm `guestsCount`, `feeAmount`, `depositAmount`, `depositStatus`, `depositNotes`.
- `AmenityMaintenanceModel`: `id`, `amenityId`, `startTime`, `endTime`, `reason`, `createdBy`, `createdAt`.

- [ ] **Step 1: Viết failing test cho các Model**

```dart
// test/data/models/amenity_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/building_amenity_model.dart';
import 'package:pka_home/data/models/amenity_booking_model.dart';
import 'package:pka_home/data/models/amenity_maintenance_model.dart';

void main() {
  group('BuildingAmenityModel v2', () {
    test('deserialize đầy đủ các trường nâng cao', () {
      final json = {
        'id': 'amenity-1',
        'name': 'Hồ bơi vô cực',
        'description': 'Tầng thượng',
        'open_hours': '06:00 - 21:00',
        'display_order': 1,
        'booking_type': 'shared',
        'max_capacity': 20,
        'slot_duration_minutes': 60,
        'fee_amount': 50000.0,
        'deposit_amount': 0.0,
        'requires_deposit': false,
        'is_active': true,
      };

      final model = BuildingAmenityModel.fromJson(json);
      expect(model.bookingType, 'shared');
      expect(model.maxCapacity, 20);
      expect(model.slotDurationMinutes, 60);
      expect(model.feeAmount, 50000.0);
      expect(model.isShared, isTrue);
    });
  });

  group('AmenityBookingModel v2', () {
    test('deserialize waitlist và snapshot phí/cọc', () {
      final json = {
        'id': 'booking-1',
        'amenity_id': 'amenity-1',
        'apartment_id': 'apt-1',
        'booking_date': '2026-10-10',
        'time_slot': '08:00 - 09:30',
        'status': 'waitlist',
        'guests_count': 2,
        'fee_amount': 100000.0,
        'deposit_amount': 500000.0,
        'deposit_status': 'pending',
        'deposit_notes': 'Chờ nhận cọc tại sảnh',
        'created_at': '2026-10-04T10:00:00Z',
      };

      final model = AmenityBookingModel.fromJson(json);
      expect(model.isWaitlist, isTrue);
      expect(model.guestsCount, 2);
      expect(model.feeAmount, 100000.0);
      expect(model.depositAmount, 500000.0);
      expect(model.depositStatus, 'pending');
    });
  });

  group('AmenityMaintenanceModel', () {
    test('deserialize và serialize chính xác', () {
      final json = {
        'id': 'maint-1',
        'amenity_id': 'amenity-1',
        'start_time': '2026-10-10T08:00:00Z',
        'end_time': '2026-10-10T12:00:00Z',
        'reason': 'Vệ sinh định kỳ',
      };

      final model = AmenityMaintenanceModel.fromJson(json);
      expect(model.reason, 'Vệ sinh định kỳ');
      expect(model.startTime, DateTime.parse('2026-10-10T08:00:00Z'));
    });
  });
}
```

- [ ] **Step 2: Chạy test xác nhận FAIL**
- [ ] **Step 3: Cập nhật `BuildingAmenityModel`, `AmenityBookingModel`, và tạo `AmenityMaintenanceModel`**
- [ ] **Step 4: Chạy test xác nhận PASS**
- [ ] **Step 5: Commit vào git**

```bash
git add lib/data/models/ test/data/models/amenity_model_test.dart
git commit -m "feat: cập nhật models tiện ích, booking waitlist và lịch bảo trì"
```

---

### Task 3: Bộ Tiện Ích Thuật Toán Khung Giờ & Bảo Trì (`AmenitySlotHelper`)

**Files:**
- Create: `lib/core/utils/amenity_slot_helper.dart`
- Create: `test/core/utils/amenity_slot_helper_test.dart`

**Interfaces:**
- `AmenitySlotHelper.generateSlots(String? openHours, int slotDurationMinutes) -> List<String>`
- `AmenitySlotHelper.isSlotInPast(DateTime date, String timeSlot, [DateTime? now]) -> bool`
- `AmenitySlotHelper.isSlotInMaintenance(DateTime date, String timeSlot, List<AmenityMaintenanceModel> maintenanceWindows) -> bool`

- [ ] **Step 1: Viết failing test cho `AmenitySlotHelper`**

```dart
// test/core/utils/amenity_slot_helper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/amenity_slot_helper.dart';
import 'package:pka_home/data/models/amenity_maintenance_model.dart';

void main() {
  group('AmenitySlotHelper.generateSlots', () {
    test('sinh khung giờ đúng theo khoảng mở cửa và độ dài slot', () {
      final slots = AmenitySlotHelper.generateSlots('06:00 - 09:00', 90);
      expect(slots, ['06:00 - 07:30', '07:30 - 09:00']);
    });

    test('fallback sang default nếu open_hours null hoặc sai cú pháp', () {
      final slots = AmenitySlotHelper.generateSlots(null, 90);
      expect(slots.isNotEmpty, isTrue);
    });
  });

  group('AmenitySlotHelper.isSlotInPast', () {
    test('chặn slot đã qua trong ngày hôm nay', () {
      final today = DateTime(2026, 10, 4);
      final fakeNow = DateTime(2026, 10, 4, 10, 30);

      // Slot 08:00 - 09:30 đã qua so với 10:30
      expect(AmenitySlotHelper.isSlotInPast(today, '08:00 - 09:30', fakeNow), isTrue);

      // Slot 11:00 - 12:30 chưa qua
      expect(AmenitySlotHelper.isSlotInPast(today, '11:00 - 12:30', fakeNow), isFalse);

      // Ngày mai không bị coi là quá khứ
      final tomorrow = DateTime(2026, 10, 5);
      expect(AmenitySlotHelper.isSlotInPast(tomorrow, '08:00 - 09:30', fakeNow), isFalse);
    });
  });

  group('AmenitySlotHelper.isSlotInMaintenance', () {
    test('phát hiện giao cắt khoảng bảo trì chính xác', () {
      final date = DateTime(2026, 10, 4);
      final maint = AmenityMaintenanceModel(
        id: 'm1',
        amenityId: 'a1',
        startTime: DateTime(2026, 10, 4, 8, 30),
        endTime: DateTime(2026, 10, 4, 11, 0),
        reason: 'Bảo trì',
      );

      // Slot 08:00 - 09:30 giao cắt với [08:30, 11:00]
      expect(
        AmenitySlotHelper.isSlotInMaintenance(date, '08:00 - 09:30', [maint]),
        isTrue,
      );

      // Slot 06:00 - 07:30 không giao cắt
      expect(
        AmenitySlotHelper.isSlotInMaintenance(date, '06:00 - 07:30', [maint]),
        isFalse,
      );
    });
  });
}
```

- [ ] **Step 2: Chạy test xác nhận FAIL**
- [ ] **Step 3: Hiện thực `AmenitySlotHelper`**
- [ ] **Step 4: Chạy test xác nhận PASS**
- [ ] **Step 5: Commit vào git**

```bash
git add lib/core/utils/amenity_slot_helper.dart test/core/utils/amenity_slot_helper_test.dart
git commit -m "feat: thêm AmenitySlotHelper hỗ trợ sinh slot động và kiểm tra bảo trì/quá khứ"
```

---

### Task 4: Nâng Cấp Tầng Repository & Providers

**Files:**
- Modify: `lib/data/repositories/amenity_booking_repository.dart`
- Modify: `lib/data/providers/amenity_booking_provider.dart`

**Interfaces:**
- `createBooking(...)`: Gọi RPC `book_amenity_slot`.
- `getMaintenanceWindows(String amenityId, DateTime date) -> Future<List<AmenityMaintenanceModel>>`.
- `createMaintenanceWindow(...) -> Future<void>`.
- `updateDepositStatus(String bookingId, String status, {String? notes}) -> Future<void>`.
- `markAttendance(String bookingId, String status) -> Future<void>` (status là `completed` hoặc `no_show`).

- [ ] **Step 1: Viết test mock cho `AmenityBookingRepository` với RPC mới**
- [ ] **Step 2: Cập nhật hàm `createBooking` gọi `book_amenity_slot` và thêm các phương thức quản trị**
- [ ] **Step 3: Cập nhật `amenity_booking_provider.dart` (thêm `amenityMaintenanceProvider`, provider đếm capacity)**
- [ ] **Step 4: Chạy test xác minh**
- [ ] **Step 5: Commit vào git**

```bash
git add lib/data/repositories/amenity_booking_repository.dart lib/data/providers/amenity_booking_provider.dart
git commit -m "feat: tích hợp RPC book_amenity_slot và quản trị bảo trì/cọc trong repository"
```

---

### Task 5: Nâng Cấp Giao Diện Cư Dân (`AmenityBookingScreen`)

**Files:**
- Modify: `lib/features/resident/screens/amenity_booking_screen.dart`

- [ ] **Step 1: Thay thế mảng tĩnh `_defaultSlots` bằng `AmenitySlotHelper.generateSlots`**
- [ ] **Step 2: Tích hợp `amenityMaintenanceProvider` hiển thị badge cam "Đang bảo trì" và vô hiệu hóa slot bị khóa**
- [ ] **Step 3: Kiểm tra `AmenitySlotHelper.isSlotInPast` để làm mờ slot đã trôi qua trong ngày hôm nay**
- [ ] **Step 4: Hiển thị badge sức chứa trực quan: "Còn X/Y chỗ" hoặc "Đã kín chỗ"**
- [ ] **Step 5: Thêm hộp thoại xác nhận có chi tiết phí, cọc và nút "Gia nhập danh sách chờ (Waitlist)" nếu slot đầy**
- [ ] **Step 6: Cập nhật Tab "Lịch sử của tôi" hiển thị rõ badge Waitlist và trạng thái cọc**
- [ ] **Step 7: Chạy kiểm thử widget & commit**

```bash
git add lib/features/resident/screens/amenity_booking_screen.dart
git commit -m "feat: hoàn thiện UI đặt tiện ích co giãn động, waitlist và thông tin cọc"
```

---

### Task 6: Màn Hình Quản Trị Tiện Ích Ban Quản Lý (`AmenityManagementScreen`)

**Files:**
- Create: `lib/features/management/screens/amenity_management_screen.dart`
- Modify: `lib/core/router/route_names.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/management/screens/management_home_screen.dart` (thêm shortcut vào dashboard BQL)

- [ ] **Step 1: Khởi tạo route `/management/amenities` trong `route_names.dart` và `app_router.dart`**
- [ ] **Step 2: Xây dựng màn hình `AmenityManagementScreen` gồm:**
  - Bộ lọc theo Tiện ích & Ngày.
  - Danh sách người đặt theo từng slot (hiển thị trạng thái confirmed, waitlist, completed, no_show).
  - Nút thao tác nhanh: Điểm danh (Đã sử dụng / Vắng mặt), Quản lý tiền cọc (Đã thu cọc / Hoàn cọc).
  - Nút thêm "Lịch tạm ngừng bảo trì" mở modal dialog.
- [ ] **Step 3: Thêm nút truy cập Quản trị tiện ích vào `ManagementHomeScreen`**
- [ ] **Step 4: Chạy test routing & giao diện**
- [ ] **Step 5: Commit vào git**

```bash
git add lib/features/management/ lib/core/router/
git commit -m "feat: bổ sung màn hình quản trị tiện ích, điểm danh, tiền cọc và lịch bảo trì cho BQL"
```

---

### Task 7: Rà Soát Toàn Diện, Phân Tích & Xác Minh (Verification)

**Files:**
- Toàn bộ codebase liên quan

- [ ] **Step 1: Chạy `dart analyze` đảm bảo không có lỗi linter/cảnh báo**
- [ ] **Step 2: Chạy toàn bộ test suite `flutter test` đảm bảo 100% test pass (cả 115 test cũ và các test mới)**
- [ ] **Step 3: Báo cáo kết quả xác minh trước khi kết thúc**
