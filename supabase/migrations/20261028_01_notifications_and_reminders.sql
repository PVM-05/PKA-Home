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
