-- ==============================================================================
-- Migration: 20260922_01_invoice_due_reminders_and_cron.sql
-- Mô tả: Tự động nhắc hạn hóa đơn (FCM & pg_cron) và Trung tâm thông báo In-app
-- 1. Bảng user_fcm_tokens (Lưu trữ device token của cư dân phục vụ push FCM)
-- 2. Bảng notifications (Trung tâm thông báo in-app realtime cho cư dân)
-- 3. Trigger tự động thông báo khi có hóa đơn mới phát sinh
-- 4. Function check_and_generate_invoice_due_reminders() quét nợ trước hạn 3 ngày
-- 5. Lịch pg_cron chạy định kỳ mỗi ngày lúc 08:00 AM (01:00 UTC)
-- ==============================================================================

-- 1. Bảng lưu trữ Device Token phục vụ Push Notification qua FCM
CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    device_info TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_user_fcm_token UNIQUE(user_id, token)
);

CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user ON public.user_fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_token ON public.user_fcm_tokens(token);

ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own FCM tokens" ON public.user_fcm_tokens;
CREATE POLICY "Users can view own FCM tokens" ON public.user_fcm_tokens
    FOR SELECT USING (auth.uid() = user_id OR public.is_staff());

DROP POLICY IF EXISTS "Users can insert own FCM tokens" ON public.user_fcm_tokens;
CREATE POLICY "Users can insert own FCM tokens" ON public.user_fcm_tokens
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own FCM tokens" ON public.user_fcm_tokens;
CREATE POLICY "Users can update own FCM tokens" ON public.user_fcm_tokens
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own FCM tokens" ON public.user_fcm_tokens;
CREATE POLICY "Users can delete own FCM tokens" ON public.user_fcm_tokens
    FOR DELETE USING (auth.uid() = user_id);


-- 2. Bảng notifications (Trung tâm thông báo in-app)
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    apartment_id UUID REFERENCES public.apartments(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR(50) NOT NULL DEFAULT 'invoice_due_reminder', -- 'new_invoice', 'invoice_due_reminder', 'announcement', 'issue_update'
    payload JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON public.notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON public.notifications(created_at DESC);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Users can view own notifications" ON public.notifications
    FOR SELECT USING (auth.uid() = user_id OR public.is_staff());

DROP POLICY IF EXISTS "Users can update read status" ON public.notifications;
CREATE POLICY "Users can update read status" ON public.notifications
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Staff can insert notifications" ON public.notifications;
CREATE POLICY "Staff can insert notifications" ON public.notifications
    FOR INSERT WITH CHECK (public.is_staff() OR auth.uid() = user_id);


-- 3. Trigger tạo thông báo tự động khi hóa đơn mới được lập
CREATE OR REPLACE FUNCTION public.trigger_notify_on_new_invoice()
RETURNS TRIGGER AS $$
DECLARE
    v_apt_code TEXT;
    v_resident RECORD;
BEGIN
    SELECT code INTO v_apt_code FROM public.apartments WHERE id = NEW.apartment_id;

    FOR v_resident IN
        SELECT user_id FROM public.residents_apartments WHERE apartment_id = NEW.apartment_id
    LOOP
        INSERT INTO public.notifications (
            user_id,
            apartment_id,
            title,
            body,
            type,
            payload
        ) VALUES (
            v_resident.user_id,
            NEW.apartment_id,
            'Hóa đơn mới kỳ ' || NEW.period,
            'Căn hộ ' || COALESCE(v_apt_code, 'N/A') || ' vừa nhận được hóa đơn kỳ ' || NEW.period || 
            ' với tổng tiền ' || to_char(NEW.total_amount, 'FM999,999,999') || ' đ. Hạn thanh toán: ' || 
            to_char(NEW.due_date, 'DD/MM/YYYY') || '.',
            'new_invoice',
            jsonb_build_object(
                'invoice_id', NEW.id,
                'period', NEW.period,
                'total_amount', NEW.total_amount,
                'due_date', NEW.due_date
            )
        );
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

DROP TRIGGER IF EXISTS trg_notify_on_new_invoice ON public.invoices;
CREATE TRIGGER trg_notify_on_new_invoice
    AFTER INSERT ON public.invoices
    FOR EACH ROW
    WHEN (NEW.status = 'unpaid')
    EXECUTE FUNCTION public.trigger_notify_on_new_invoice();


-- 4. Stored Procedure quét và tự động gửi thông báo nhắc hạn hóa đơn trước 3 ngày
CREATE OR REPLACE FUNCTION public.check_and_generate_invoice_due_reminders()
RETURNS INTEGER AS $$
DECLARE
    v_inv RECORD;
    v_resident RECORD;
    v_apt_code TEXT;
    v_days_left INTEGER;
    v_count INTEGER := 0;
    v_title TEXT;
    v_body TEXT;
BEGIN
    -- Tìm các hóa đơn chưa thanh toán mà hạn chót cách hiện tại <= 3 ngày (hoặc đã quá hạn)
    FOR v_inv IN
        SELECT i.id, i.apartment_id, i.period, i.due_date, i.total_amount, a.code as apartment_code,
               (i.due_date::date - CURRENT_DATE) as days_remaining
        FROM public.invoices i
        JOIN public.apartments a ON a.id = i.apartment_id
        WHERE i.status IN ('unpaid', 'pending_confirmation')
          AND i.due_date::date <= (CURRENT_DATE + INTERVAL '3 days')::date
          AND i.due_date::date >= (CURRENT_DATE - INTERVAL '14 days')::date -- Không quét các hóa đơn quá cũ quá 14 ngày
    LOOP
        v_days_left := v_inv.days_remaining;

        -- Xác định nội dung thông báo
        IF v_days_left > 0 THEN
            v_title := 'Nhắc hạn thanh toán hóa đơn kỳ ' || v_inv.period;
            v_body := 'Căn hộ ' || v_inv.apartment_code || ': Hóa đơn kỳ ' || v_inv.period || 
                      ' (số tiền ' || to_char(v_inv.total_amount, 'FM999,999,999') || 
                      ' đ) sẽ đến hạn thanh toán trong ' || v_days_left || ' ngày tới (ngày ' || 
                      to_char(v_inv.due_date, 'DD/MM/YYYY') || '). Quý Cư dân vui lòng thanh toán đúng hạn.';
        ELSIF v_days_left = 0 THEN
            v_title := 'Hôm nay là hạn chót thanh toán hóa đơn kỳ ' || v_inv.period;
            v_body := 'Căn hộ ' || v_inv.apartment_code || ': Hóa đơn kỳ ' || v_inv.period || 
                      ' (số tiền ' || to_char(v_inv.total_amount, 'FM999,999,999') || 
                      ' đ) đến hạn chót hôm nay (' || to_char(v_inv.due_date, 'DD/MM/YYYY') || 
                      '). Quý Cư dân vui lòng hoàn tất thanh toán trong ngày.';
        ELSE
            v_title := 'Hóa đơn kỳ ' || v_inv.period || ' đã quá hạn thanh toán';
            v_body := 'Căn hộ ' || v_inv.apartment_code || ': Hóa đơn kỳ ' || v_inv.period || 
                      ' (số tiền ' || to_char(v_inv.total_amount, 'FM999,999,999') || 
                      ' đ) đã quá hạn ' || ABS(v_days_left) || ' ngày. Quý Cư dân vui lòng thanh toán ngay để tránh phát sinh gián đoạn dịch vụ.';
        END IF;

        -- Gửi thông báo cho từng cư dân của căn hộ nếu chưa gửi trong vòng 20 giờ qua
        FOR v_resident IN
            SELECT user_id FROM public.residents_apartments WHERE apartment_id = v_inv.apartment_id
        LOOP
            IF NOT EXISTS (
                SELECT 1 FROM public.notifications n
                WHERE n.user_id = v_resident.user_id
                  AND n.type = 'invoice_due_reminder'
                  AND (n.payload->>'invoice_id') = v_inv.id::text
                  AND n.created_at >= (now() - INTERVAL '20 hours')
            ) THEN
                INSERT INTO public.notifications (
                    user_id,
                    apartment_id,
                    title,
                    body,
                    type,
                    payload
                ) VALUES (
                    v_resident.user_id,
                    v_inv.apartment_id,
                    v_title,
                    v_body,
                    'invoice_due_reminder',
                    jsonb_build_object(
                        'invoice_id', v_inv.id,
                        'period', v_inv.period,
                        'total_amount', v_inv.total_amount,
                        'due_date', v_inv.due_date,
                        'days_remaining', v_days_left
                    )
                );
                v_count := v_count + 1;
            END IF;
        END LOOP;
    END LOOP;

    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;


-- 5. Đăng ký lịch tự động với pg_cron (chạy mỗi ngày lúc 08:00 AM giờ VN = 01:00 UTC)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'daily_invoice_due_reminder') THEN
        PERFORM cron.unschedule('daily_invoice_due_reminder');
    END IF;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

SELECT cron.schedule(
    'daily_invoice_due_reminder',
    '0 1 * * *', -- 01:00 AM UTC = 08:00 AM VN (UTC+7)
    'SELECT public.check_and_generate_invoice_due_reminders();'
);

-- 6. Bật realtime cho bảng notifications
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
EXCEPTION
    WHEN duplicate_object THEN NULL;
    WHEN OTHERS THEN NULL;
END $$;
