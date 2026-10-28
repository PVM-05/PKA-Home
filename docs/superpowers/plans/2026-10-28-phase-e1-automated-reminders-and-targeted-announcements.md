# Kế Hoạch Thực Thi: Giai Đoạn E1 - Tự Động Hóa Truyền Thông, Nhắc Phí Thông Minh & Thông Báo Đích Danh

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chuẩn hóa cơ sở dữ liệu thông báo và FCM token vào migration chính thức, triển khai RPC tự động quét nhắc phí 3 cấp độ (sắp đến hạn 3 ngày, đúng hạn, quá hạn), nâng cấp thông báo BQL hỗ trợ gửi đích danh theo Block/Tầng/Căn hộ và trung tâm thông báo cư dân thời gian thực hỗ trợ lọc theo ngữ cảnh.

**Architecture:**
- Database: Migration `20261028_01_notifications_and_reminders.sql` tạo bảng `user_fcm_tokens`, `notifications`, nâng cấp `announcements` với `target_type` và `target_value`, cùng hàm `check_and_generate_invoice_due_reminders` chống gửi lặp trong ngày.
- Models & Data Layer: `NotificationModel` bổ sung `buildingId` và helper getters; `AnnouncementModel` mở rộng hỗ trợ `targetType` linh hoạt (`all`, `block`, `floor`, `apartment`); `NotificationRepository` hỗ trợ lọc theo tòa nhà và kích hoạt RPC nhắc nợ; `notification_provider.dart` cung cấp các bộ lọc 'Tất cả', 'Chưa đọc', 'Hóa đơn', 'Tòa nhà'.
- Flutter UI: Màn hình Cư dân `NotificationCenterScreen` với tab lọc đa năng và biểu tượng trực quan; màn hình BQL `AnnouncementManagementScreen` với bộ chọn phạm vi thông báo linh hoạt (Block/Tầng/Căn hộ) và nút thao tác "Quét nhắc nợ hóa đơn".

**Tech Stack:** Flutter, Dart, Riverpod, PostgreSQL 15+, Supabase Realtime & RPC.

## Global Constraints

- Tuân thủ 100% tiếng Việt chuẩn trong nhãn UI theo `design-rules.md`. Tuyệt đối không dùng emoji.
- Toàn bộ commit thực hiện trực tiếp trên nhánh `main` theo quy định `AGENTS.md`.
- Định dạng mã căn hộ chuẩn `A0110` / `a0110` theo `coding-rules.md`.
- TDD: Viết test trước, xác nhận fail, viết code, xác nhận pass.
- Đảm bảo 100% kiểm thử hệ thống hiện có tiếp tục vượt qua thành công.

---

### Task 1: Database Migration Bảng `notifications`, `user_fcm_tokens` & RPC Quét Nhắc Nợ

**Files:**
- Create: `supabase/migrations/20261028_01_notifications_and_reminders.sql`
- Create: `test/integration/notifications_and_reminders_migration_test.dart`

**Interfaces:**
- Consumes: Bảng `users`, `apartments`, `buildings`, `invoices`, `residents_apartments`.
- Produces:
  - Bảng `public.user_fcm_tokens` (id, user_id, token, device_info, created_at, updated_at).
  - Bảng `public.notifications` (id, building_id, user_id, apartment_id, title, body, type, payload, is_read, created_at).
  - Cột `target_type`, `target_value` trên bảng `public.announcements`.
  - RPC Function `public.check_and_generate_invoice_due_reminders(p_building_id UUID DEFAULT NULL) RETURNS INT`.

- [ ] **Step 1: Viết failing test kiểm tra migration SQL file**

Tạo file `test/integration/notifications_and_reminders_migration_test.dart`:
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Notifications and Reminders Migration Tests', () {
    final migrationFile = File('supabase/migrations/20261028_01_notifications_and_reminders.sql');

    test('Tập tin migration 20261028_01_notifications_and_reminders.sql phải tồn tại', () {
      expect(migrationFile.existsSync(), isTrue);
    });

    test('Migration phải định nghĩa bảng user_fcm_tokens và notifications', () {
      final content = migrationFile.readAsStringSync();
      expect(content.contains('CREATE TABLE IF NOT EXISTS public.user_fcm_tokens'), isTrue);
      expect(content.contains('CREATE TABLE IF NOT EXISTS public.notifications'), isTrue);
      expect(content.contains('uq_user_fcm_token UNIQUE(user_id, token)'), isTrue);
    });

    test('Migration phải nâng cấp bảng announcements với target_type và target_value', () {
      final content = migrationFile.readAsStringSync();
      expect(content.contains('ALTER TABLE public.announcements'), isTrue);
      expect(content.contains('target_type'), isTrue);
      expect(content.contains('target_value'), isTrue);
    });

    test('Migration phải định nghĩa RPC check_and_generate_invoice_due_reminders với logic 3 mức nhắc', () {
      final content = migrationFile.readAsStringSync();
      expect(content.contains('FUNCTION public.check_and_generate_invoice_due_reminders'), isTrue);
      expect(content.contains('invoice_due_soon'), isTrue);
      expect(content.contains('invoice_due_today'), isTrue);
      expect(content.contains('invoice_overdue'), isTrue);
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận FAIL**

Chạy:
```bash
flutter test test/integration/notifications_and_reminders_migration_test.dart
```
Kỳ vọng: FAIL vì file migration chưa được tạo.

- [ ] **Step 3: Tạo migration `supabase/migrations/20261028_01_notifications_and_reminders.sql`**

Nội dung SQL hoàn chỉnh:
```sql
-- Migration: 20261028_01_notifications_and_reminders.sql
-- Mô tả: Chuẩn hóa bảng user_fcm_tokens, notifications, nâng cấp announcements và RPC nhắc nợ hóa đơn tự động

-- 1. Bảng lưu trữ FCM tokens của người dùng
CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    device_info TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_fcm_token UNIQUE(user_id, token)
);

-- RLS cho user_fcm_tokens
ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_fcm_tokens' AND policyname = 'user_fcm_tokens_user_all') THEN
        CREATE POLICY user_fcm_tokens_user_all ON public.user_fcm_tokens
            FOR ALL TO authenticated
            USING (auth.uid() = user_id)
            WITH CHECK (auth.uid() = user_id);
    END IF;
END $$;

-- 2. Bảng notifications trung tâm
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    apartment_id UUID REFERENCES public.apartments(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR(50) NOT NULL DEFAULT 'invoice_due_reminder',
    payload JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON public.notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_building ON public.notifications(building_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON public.notifications(created_at DESC);

-- RLS cho notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'notifications_user_select') THEN
        CREATE POLICY notifications_user_select ON public.notifications
            FOR SELECT TO authenticated
            USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'notifications_user_update') THEN
        CREATE POLICY notifications_user_update ON public.notifications
            FOR UPDATE TO authenticated
            USING (auth.uid() = user_id)
            WITH CHECK (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'notifications_manager_all') THEN
        CREATE POLICY notifications_manager_all ON public.notifications
            FOR ALL TO authenticated
            USING (
                EXISTS (
                    SELECT 1 FROM public.users u
                    WHERE u.id = auth.uid()
                      AND u.role IN ('admin', 'bql', 'manager')
                )
            );
    END IF;
END $$;

-- 3. Nâng cấp bảng announcements: hỗ trợ phân nhóm đối tượng thông báo linh hoạt
ALTER TABLE public.announcements
    ADD COLUMN IF NOT EXISTS target_type VARCHAR(20) NOT NULL DEFAULT 'all',
    ADD COLUMN IF NOT EXISTS target_value VARCHAR(50);

-- 4. Hàm RPC Quét và tự động sinh thông báo nhắc phí
CREATE OR REPLACE FUNCTION public.check_and_generate_invoice_due_reminders(p_building_id UUID DEFAULT NULL)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_inv RECORD;
    v_res RECORD;
    v_count INT := 0;
    v_reminder_type TEXT;
    v_title TEXT;
    v_body TEXT;
    v_days_diff INT;
BEGIN
    FOR v_inv IN
        SELECT i.id, i.apartment_id, i.period, i.due_date, i.total_amount, a.code as apt_code, a.building_id
        FROM public.invoices i
        JOIN public.apartments a ON i.apartment_id = a.id
        WHERE i.status = 'pending'
          AND (p_building_id IS NULL OR a.building_id = p_building_id)
    LOOP
        v_days_diff := (v_inv.due_date - CURRENT_DATE);

        IF v_days_diff = 3 THEN
            v_reminder_type := 'invoice_due_soon';
            v_title := 'Nhắc hạn thanh toán phí kỳ ' || v_inv.period;
            v_body := 'Hóa đơn căn hộ ' || v_inv.apt_code || ' số tiền ' || to_char(v_inv.total_amount, 'FM999,999,999,999') || ' đ sắp đến hạn (còn 3 ngày nữa).';
        ELSIF v_days_diff = 0 THEN
            v_reminder_type := 'invoice_due_today';
            v_title := 'Hóa đơn kỳ ' || v_inv.period || ' đến hạn hôm nay';
            v_body := 'Hôm nay là hạn cuối thanh toán hóa đơn căn hộ ' || v_inv.apt_code || '. Vui lòng hoàn tất thanh toán để tránh phát sinh gián đoạn dịch vụ.';
        ELSIF v_days_diff < 0 THEN
            v_reminder_type := 'invoice_overdue';
            v_title := 'Cảnh báo: Hóa đơn kỳ ' || v_inv.period || ' đã quá hạn';
            v_body := 'Hóa đơn căn hộ ' || v_inv.apt_code || ' đã quá hạn ' || ABS(v_days_diff) || ' ngày. Vui lòng thanh toán ngay qua ứng dụng.';
        ELSE
            CONTINUE;
        END IF;

        FOR v_res IN
            SELECT user_id FROM public.residents_apartments WHERE apartment_id = v_inv.apartment_id
        LOOP
            IF NOT EXISTS (
                SELECT 1 FROM public.notifications n
                WHERE n.user_id = v_res.user_id
                  AND n.type = v_reminder_type
                  AND (n.payload->>'invoice_id') = v_inv.id::text
                  AND n.created_at::date = CURRENT_DATE
            ) THEN
                INSERT INTO public.notifications (
                    building_id,
                    user_id,
                    apartment_id,
                    title,
                    body,
                    type,
                    payload,
                    is_read,
                    created_at
                ) VALUES (
                    v_inv.building_id,
                    v_res.user_id,
                    v_inv.apartment_id,
                    v_title,
                    v_body,
                    v_reminder_type,
                    jsonb_build_object('invoice_id', v_inv.id, 'period', v_inv.period, 'amount', v_inv.total_amount),
                    false,
                    now()
                );
                v_count := v_count + 1;
            END IF;
        END LOOP;
    END LOOP;

    RETURN v_count;
END;
$$;
```

- [ ] **Step 4: Chạy test để xác nhận PASS**

Chạy:
```bash
flutter test test/integration/notifications_and_reminders_migration_test.dart
```
Kỳ vọng: PASS (4 tests passing).

- [ ] **Step 5: Commit migration**

```bash
git add supabase/migrations/20261028_01_notifications_and_reminders.sql test/integration/notifications_and_reminders_migration_test.dart
git commit -m "feat(db): migration bang notifications fcm tokens va rpc nhac no hoa don"
```

---

### Task 2: Nâng Cấp Data Models (`NotificationModel` & `AnnouncementModel`)

**Files:**
- Modify: `lib/data/models/notification_model.dart`
- Modify: `lib/data/models/announcement_model.dart`
- Create: `test/data/models/notification_model_phase_e1_test.dart`
- Create: `test/data/models/announcement_model_phase_e1_test.dart`

**Interfaces:**
- Produces:
  - `NotificationModel`: bổ sung `buildingId` (`String?`), getters `isInvoiceReminder`, `isAnnouncement`, `isIssueUpdate`, `typeDisplayName`.
  - `AnnouncementModel`: bổ sung `targetValue` (`String?`), chuẩn hóa `targetDisplayName` cho `'all'`, `'block'`, `'floor'`, `'apartment'`, `'block_a'`, `'block_b'`.

- [ ] **Step 1: Viết failing unit tests cho NotificationModel và AnnouncementModel**

Tạo `test/data/models/notification_model_phase_e1_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/notification_model.dart';

void main() {
  group('NotificationModel Phase E1 Tests', () {
    test('Khởi tạo NotificationModel có buildingId và các helper getters', () {
      final notif = NotificationModel(
        id: 'notif-1',
        buildingId: 'bld-1',
        userId: 'usr-1',
        apartmentId: 'apt-1',
        title: 'Nhắc nợ',
        body: 'Hóa đơn quá hạn',
        type: 'invoice_overdue',
        createdAt: DateTime(2026, 10, 28),
      );

      expect(notif.buildingId, equals('bld-1'));
      expect(notif.isInvoiceReminder, isTrue);
      expect(notif.isAnnouncement, isFalse);
      expect(notif.typeDisplayName, equals('Hóa đơn'));
    });

    test('NotificationModel.fromJson và toJson tương thích hoàn toàn', () {
      final json = {
        'id': 'notif-2',
        'building_id': 'bld-99',
        'user_id': 'usr-2',
        'apartment_id': 'apt-2',
        'title': 'Thông báo bảo trì',
        'body': 'Bảo trì thang máy',
        'type': 'equipment_maintenance',
        'payload': {'code': 'TM01'},
        'is_read': true,
        'created_at': '2026-10-28T10:00:00.000Z',
      };

      final model = NotificationModel.fromJson(json);
      expect(model.buildingId, equals('bld-99'));
      expect(model.isRead, isTrue);
      expect(model.typeDisplayName, equals('Bảo trì'));

      final outJson = model.toJson();
      expect(outJson['building_id'], equals('bld-99'));
    });
  });
}
```

Tạo `test/data/models/announcement_model_phase_e1_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/announcement_model.dart';

void main() {
  group('AnnouncementModel Phase E1 Tests', () {
    test('targetDisplayName hiển thị đúng theo targetType và targetValue linh hoạt', () {
      final annBlock = AnnouncementModel(
        id: '1',
        title: 'Mất nước',
        content: 'Nội dung',
        isUrgent: false,
        targetType: 'block',
        targetValue: 'B',
        createdAt: DateTime.now(),
      );
      expect(annBlock.targetDisplayName, equals('Block B'));

      final annFloor = AnnouncementModel(
        id: '2',
        title: 'Sơn hành lang',
        content: 'Nội dung',
        isUrgent: false,
        targetType: 'floor',
        targetValue: '08',
        createdAt: DateTime.now(),
      );
      expect(annFloor.targetDisplayName, equals('Tầng 08'));

      final annApt = AnnouncementModel(
        id: '3',
        title: 'Kiểm tra gas',
        content: 'Nội dung',
        isUrgent: true,
        targetType: 'apartment',
        targetValue: 'A0110',
        createdAt: DateTime.now(),
      );
      expect(annApt.targetDisplayName, equals('Căn hộ A0110'));

      final annAll = AnnouncementModel(
        id: '4',
        title: 'Họp cư dân',
        content: 'Nội dung',
        isUrgent: false,
        targetType: 'all',
        createdAt: DateTime.now(),
      );
      expect(annAll.targetDisplayName, equals('Toàn bộ cư dân'));
    });

    test('Tương thích ngược với targetApartment và block_a, block_b cũ', () {
      final legacy = AnnouncementModel.fromJson({
        'id': 'legacy-1',
        'title': 'Test cũ',
        'content': 'Test',
        'is_urgent': false,
        'target_type': 'block_a',
        'created_at': '2026-10-28T00:00:00.000Z',
      });
      expect(legacy.targetDisplayName, equals('Tòa A'));
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận FAIL**

```bash
flutter test test/data/models/notification_model_phase_e1_test.dart test/data/models/announcement_model_phase_e1_test.dart
```
Kỳ vọng: FAIL vì thiếu `buildingId`, getters trên `NotificationModel` và `targetValue` trên `AnnouncementModel`.

- [ ] **Step 3: Triển khai cập nhật `NotificationModel` và `AnnouncementModel`**

Chỉnh sửa `lib/data/models/notification_model.dart`:
- Bổ sung `final String? buildingId;`
- Getters: `isInvoiceReminder`, `isAnnouncement`, `isIssueUpdate`, `typeDisplayName`.
- Cập nhật `fromJson`, `toJson`, `copyWith` bao gồm `building_id`.

Chỉnh sửa `lib/data/models/announcement_model.dart`:
- Bổ sung `final String? targetValue;`
- Cập nhật `targetDisplayName` xử lý `block`, `floor`, `apartment`, `all`.
- Cập nhật `fromJson` và `toJson`.

- [ ] **Step 4: Chạy test để xác nhận PASS**

```bash
flutter test test/data/models/notification_model_phase_e1_test.dart test/data/models/announcement_model_phase_e1_test.dart
```
Kỳ vọng: PASS (tất cả các unit tests mô hình đạt 100%).

- [ ] **Step 5: Commit Models**

```bash
git add lib/data/models/notification_model.dart lib/data/models/announcement_model.dart test/data/models/notification_model_phase_e1_test.dart test/data/models/announcement_model_phase_e1_test.dart
git commit -m "feat(models): cap nhat notification model va announcement model ho tro target value"
```

---

### Task 3: Cập Nhật `NotificationRepository` & `NotificationProvider`

**Files:**
- Modify: `lib/data/repositories/notification_repository.dart`
- Modify: `lib/data/providers/notification_provider.dart`
- Create: `test/data/repositories/notification_repository_phase_e1_test.dart`
- Create: `test/data/providers/notification_provider_phase_e1_test.dart`

**Interfaces:**
- Consumes: `SupabaseConfig.client`, `activeBuildingProvider`, `authProvider`.
- Produces:
  - `NotificationRepository.getNotifications({required String userId, String? buildingId})`
  - `NotificationRepository.triggerInvoiceRemindersScan({String? buildingId})`
  - `notificationFilterTypeProvider`: StateProvider enum/String ('ALL', 'UNREAD', 'INVOICE', 'BUILDING')
  - `filteredNotificationsProvider`: Provider danh sách thông báo đã qua bộ lọc được chọn.

- [ ] **Step 1: Viết test cho `NotificationRepository` và `NotificationProvider`**

Tạo `test/data/repositories/notification_repository_phase_e1_test.dart` và `test/data/providers/notification_provider_phase_e1_test.dart`.

- [ ] **Step 2: Chạy test để xác nhận FAIL**

```bash
flutter test test/data/repositories/notification_repository_phase_e1_test.dart test/data/providers/notification_provider_phase_e1_test.dart
```

- [ ] **Step 3: Cập nhật `NotificationRepository` và `NotificationProvider`**

- `NotificationRepository`:
  - `getNotifications({required String userId, String? buildingId})`: nếu `buildingId != null`, thêm `.eq('building_id', buildingId)`.
  - `triggerInvoiceRemindersScan({String? buildingId})`: truyền `params: {'p_building_id': buildingId}` vào `.rpc('check_and_generate_invoice_due_reminders', params: ...)`.
- `NotificationProvider`:
  - `notificationFilterTypeProvider` (StateProvider<String> default 'ALL')
  - `filteredNotificationsProvider` (Provider<List<NotificationModel>>) kết hợp `notificationsStreamProvider` và `notificationFilterTypeProvider`.

- [ ] **Step 4: Chạy test để xác nhận PASS**

```bash
flutter test test/data/repositories/notification_repository_phase_e1_test.dart test/data/providers/notification_provider_phase_e1_test.dart
```

- [ ] **Step 5: Commit Repository & Providers**

```bash
git add lib/data/repositories/notification_repository.dart lib/data/providers/notification_provider.dart test/data/repositories/notification_repository_phase_e1_test.dart test/data/providers/notification_provider_phase_e1_test.dart
git commit -m "feat(repo): nang cap notification repository va filter providers"
```

---

### Task 4: Nâng Cấp Giao Diện Trung Tâm Thông Báo Cư Dân (`NotificationCenterScreen`)

**Files:**
- Modify: `lib/features/resident/screens/notification_center_screen.dart`
- Create: `test/features/resident/screens/notification_center_screen_test.dart`

**Interfaces:**
- Consumes: `notificationsStreamProvider`, `filteredNotificationsProvider`, `notificationFilterTypeProvider`, `notificationRepositoryProvider`.
- Produces: UI hoàn thiện với thanh tab/chips phân loại ('Tất cả', 'Chưa đọc', 'Hóa đơn & Phí', 'Tòa nhà'), đếm số thông báo chưa đọc, phân biệt trực quan trạng thái quá hạn và dẫn hướng trực tiếp đến hóa đơn / phản ánh.

- [ ] **Step 1: Viết widget test cho `NotificationCenterScreen`**

Tạo `test/features/resident/screens/notification_center_screen_test.dart` kiểm tra hiển thị chip bộ lọc, danh sách thông báo và xử lý chạm đánh dấu đã đọc.

- [ ] **Step 2: Chạy test để xác nhận FAIL**

```bash
flutter test test/features/resident/screens/notification_center_screen_test.dart
```

- [ ] **Step 3: Triển khai giao diện trong `NotificationCenterScreen`**

- Thêm hàng Filter Chips ngang dưới AppBar:
  - "Tất cả"
  - "Chưa đọc"
  - "Hóa đơn & Phí"
  - "Tòa nhà"
- Cập nhật Card thông báo:
  - Phân biệt màu sắc trực quan: `invoice_overdue` (màu đỏ `AppTheme.error`), `invoice_due_today` (màu cam), `invoice_due_soon` (màu xanh dương).
  - Badge trạng thái "Chưa đọc" tinh tế.
- Nhấn vào thông báo loại hóa đơn điều hướng đến `ResidentInvoiceScreen`.

- [ ] **Step 4: Chạy test để xác nhận PASS**

```bash
flutter test test/features/resident/screens/notification_center_screen_test.dart
```

- [ ] **Step 5: Commit UI Cư dân**

```bash
git add lib/features/resident/screens/notification_center_screen.dart test/features/resident/screens/notification_center_screen_test.dart
git commit -m "feat(ui): them bo loc danh muc va chi bao trang thai cho trung tam thong bao"
```

---

### Task 5: Nâng Cấp Màn Hình Quản Lý Thông Báo BQL (`AnnouncementManagementScreen`)

**Files:**
- Modify: `lib/features/management/screens/announcement_management_screen.dart`
- Modify: `lib/data/repositories/announcement_repository.dart`
- Create: `test/features/management/screens/announcement_management_screen_phase_e1_test.dart`

**Interfaces:**
- Consumes: `AnnouncementRepository`, `NotificationRepository`, `activeBuildingProvider`.
- Produces:
  - Nút **"Quét nhắc nợ hóa đơn"** trên AppBar hoặc Action Header của màn hình BQL.
  - Dialog Thêm/Sửa thông báo cho phép chọn: "Toàn bộ cư dân", "Theo Block", "Theo Tầng", "Căn hộ cụ thể" kèm trường nhập dữ liệu `targetValue` tương ứng (validate mã căn hộ chuẩn `A0110`).

- [ ] **Step 1: Viết test cho Dialog phạm vi thông báo và nút Quét nợ BQL**

Tạo `test/features/management/screens/announcement_management_screen_phase_e1_test.dart`.

- [ ] **Step 2: Chạy test để xác nhận FAIL**

```bash
flutter test test/features/management/screens/announcement_management_screen_phase_e1_test.dart
```

- [ ] **Step 3: Cập nhật `AnnouncementRepository` & `AnnouncementManagementScreen`**

- `AnnouncementRepository`: cập nhật `createAnnouncement` và `updateAnnouncement` hỗ trợ tham số `targetType` và `targetValue`.
- `AnnouncementManagementScreen`:
  - Thêm Action Button "Quét nhắc nợ" với Icon `Icons.schedule_send_outlined`. Khi nhấn: gọi `ref.read(notificationRepositoryProvider).triggerInvoiceRemindersScan(activeBuilding?.id)`, hiển thị `SnackBar` thông báo: `Đã quét và phát sinh $count thông báo nhắc nợ thành công.`
  - Cập nhật Form tạo/sửa:
    - DropdownButtonFormField chọn loại đối tượng:
      - `all`: Toàn bộ cư dân
      - `block`: Theo Block (hiện ô nhập mã Block, VD: A, B)
      - `floor`: Theo Tầng (hiện ô nhập số tầng, VD: 05, 12)
      - `apartment`: Căn hộ cụ thể (hiện ô nhập mã căn hộ, placeholder `A0110`)

- [ ] **Step 4: Chạy test để xác nhận PASS**

```bash
flutter test test/features/management/screens/announcement_management_screen_phase_e1_test.dart
```

- [ ] **Step 5: Commit UI Ban Quản Lý**

```bash
git add lib/features/management/screens/announcement_management_screen.dart lib/data/repositories/announcement_repository.dart test/features/management/screens/announcement_management_screen_phase_e1_test.dart
git commit -m "feat(ui): them bo chon pham vi thong bao linh hoat va nut quet nhac no hoa don"
```

---

### Task 6: Kiểm Thử Tổng Thể & Xác Nhận Hệ Thống (Verification Gate)

**Files:**
- Toàn bộ codebase.

**Interfaces:**
- Đảm bảo toàn bộ 465+ tests và các test mới của Giai đoạn E1 chạy thành công 100%.
- Kiểm tra linter không có warning/error nào (`flutter analyze`).

- [ ] **Step 1: Chạy `flutter analyze`**

```bash
flutter analyze
```
Kỳ vọng: `No issues found!`.

- [ ] **Step 2: Chạy `flutter test` toàn bộ hệ thống**

```bash
flutter test
```
Kỳ vọng: 100% tests PASS.

- [ ] **Step 3: Cập nhật tài liệu SRS / Architecture / Database Rules nếu cần & Commit**

```bash
git add .
git commit -m "docs: hoan tat giai doan E1 tu dong hoa truyen thong va nhac phi thong minh"
```
