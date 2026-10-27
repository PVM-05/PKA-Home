# Đặc Tả Kỹ Thuật: Giai Đoạn E1 - Tự Động Hóa Truyền Thông, Nhắc Phí Thông Minh & Thông Báo Đích Danh

**Tác giả:** Antigravity Agent & PKA-Home Team  
**Ngày lập:** 2026-10-28  
**Trạng thái:** Bản thiết kế hoàn chỉnh (Ready for Implementation Plan)  
**Mục tiêu:** Nâng cấp hệ thống truyền thông và quản lý thông báo của PKA-Home: triển khai trung tâm thông báo thời gian thực (In-app notifications) có hỗ trợ phân loại theo từng tòa nhà (Multi-tenancy), phát tán thông báo có mục tiêu linh hoạt (theo Toàn tòa, Block, Tầng, Căn hộ), và cơ chế tự động quét nhắc nợ hóa đơn định kỳ (trước hạn 3 ngày, đúng hạn, quá hạn).

---

## 1. Bối Cảnh & Vấn Đề

1. **Bảng `notifications` và `user_fcm_tokens` chưa được chuẩn hóa vào migration chính thức:** Tầng Data Repository (`NotificationRepository`) hiện đang truy vấn bảng `notifications` và RPC `check_and_generate_invoice_due_reminders`, tuy nhiên các bảng này chưa nằm trong các migration chuẩn của hệ thống sau đợt hợp nhất Baseline.
2. **Thông báo BQL chưa có bộ lọc đối tượng linh hoạt:** `AnnouncementModel` hiện đang gắn cố định nhãn `block_a`, `block_b` mà chưa hỗ trợ phân nhóm động theo tầng, block thực tế hoặc căn hộ cụ thể của từng tòa nhà.
3. **Cư dân chưa có cơ chế nhắc phí tự động đa tầng:** Cần có RPC tự động quét các hóa đơn chưa thanh toán (`status = 'pending'`) theo 3 mức độ cảnh báo (trước hạn 3 ngày, đúng hạn, và quá hạn) để gửi thông báo nhắc nhở kịp thời mà không bị gửi lặp trong ngày.

---

## 2. Thiết Kế Cơ Sở Dữ Liệu (PostgreSQL / Supabase)

### 2.1. Tạo Bảng `notifications` & `user_fcm_tokens`
```sql
CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    device_info TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_fcm_token UNIQUE(user_id, token)
);

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    apartment_id UUID REFERENCES public.apartments(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR(50) NOT NULL DEFAULT 'invoice_due_reminder', -- 'new_invoice', 'invoice_due_reminder', 'announcement', 'issue_update'
    payload JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON public.notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_building ON public.notifications(building_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON public.notifications(created_at DESC);
```

### 2.2. Nâng Cấp Bảng `announcements`
```sql
ALTER TABLE public.announcements
    ADD COLUMN IF NOT EXISTS target_type VARCHAR(20) NOT NULL DEFAULT 'all', -- 'all', 'block', 'floor', 'apartment'
    ADD COLUMN IF NOT EXISTS target_value VARCHAR(50); -- Mã block (VD: 'A'), số tầng (VD: '05'), hoặc mã căn hộ (VD: 'A0110')
```

### 2.3. RPC Quét & Tự Động Sinh Thông Báo Nhắc Phí (`check_and_generate_invoice_due_reminders`)
```sql
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

        -- Tìm cư dân gắn với căn hộ
        FOR v_res IN
            SELECT user_id FROM public.residents_apartments WHERE apartment_id = v_inv.apartment_id
        LOOP
            -- Chống gửi lặp trong cùng ngày
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

---

## 3. Kiến Trúc Tầng Logic & Dữ Liệu (Data Layer)

### 3.1. Models
- `NotificationModel`: Bổ sung `buildingId`, getters `isInvoiceReminder`, `isAnnouncement`, `typeDisplayName`.
- `AnnouncementModel`: Chuẩn hóa `targetType` (`all`, `block`, `floor`, `apartment`) và `targetValue`.

### 3.2. Repositories & Providers
- `NotificationRepository`:
  - `getNotifications({required String userId, String? buildingId})`
  - `markAsRead(String id)`
  - `markAllAsRead(String userId)`
  - `triggerInvoiceRemindersScan(String? buildingId)`
- Providers:
  - `notificationsStreamProvider` (Real-time stream theo `user_id` và `activeBuilding`)
  - `unreadNotificationCountProvider`
  - `notificationFilterTypeProvider` ('ALL', 'INVOICE', 'ANNOUNCEMENT', 'ISSUE')

---

## 4. Giao Diện Người Dùng (UI/UX)

### 4.1. Màn hình Quản lý Thông báo BQL (`AnnouncementManagementScreen`)
- Form tạo/chỉnh sửa thông báo:
  - Chọn phạm vi đối tượng: Toàn tòa nhà / Theo Block / Theo Tầng / Căn hộ cụ thể.
  - Trường nhập dữ liệu mục tiêu tự động thích ứng với phạm vi đã chọn (Ví dụ: chọn Căn hộ -> hiện ô nhập căn hộ định dạng `A0110`).
  - Nút **"Quét nhắc nợ hóa đơn"** (Quét nợ tự động & hiển thị SnackBar kết quả số thông báo gửi đi).

### 4.2. Màn hình Trung tâm Thông báo Cư dân (`NotificationCenterScreen`)
- Tabs bộ lọc: Tất cả / Chưa đọc / Hóa đơn & Phí / Tòa nhà.
- Thao tác: "Đánh dấu tất cả đã đọc".
- Chạm vào thông báo hóa đơn -> Chuyển hướng xem chi tiết hóa đơn.

---

## 5. Quy Chuẩn Đảm Bảo (Quality & Verification Gates)

- Tuân thủ 100% tiếng Việt tự nhiên theo `design-rules.md`.
- Viết Unit test & Widget test đầy đủ trước khi hoàn tất.
- `flutter analyze` 0 lỗi linter, giữ nguyên tính tương thích của toàn bộ 465+ tests hiện có.
