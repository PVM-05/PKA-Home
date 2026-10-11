-- ==============================================================================
-- PKA-Home: Migration 20261011_02_secure_applied_migrations.sql
-- Mục đích: Kích hoạt Row Level Security (RLS) và thu hồi quyền từ role API (anon, authenticated)
-- trên bảng public._applied_migrations nhằm khắc phục triệt để cảnh báo bảo mật PostgREST.
-- ==============================================================================

DO $$
BEGIN
  -- Chỉ áp dụng nếu bảng public._applied_migrations tồn tại
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = '_applied_migrations'
  ) THEN
    -- 1. Kích hoạt Row Level Security (RLS) để PostgREST áp dụng cơ chế Default Deny
    ALTER TABLE public._applied_migrations ENABLE ROW LEVEL SECURITY;
    
    -- 2. Ép buộc RLS kể cả đối với table owner (nếu không phải superuser)
    ALTER TABLE public._applied_migrations FORCE ROW LEVEL SECURITY;

    -- 3. Thu hồi toàn bộ quyền truy cập dữ liệu đối với người dùng vãng lai (anon) và người dùng đăng nhập (authenticated)
    REVOKE ALL ON TABLE public._applied_migrations FROM anon, authenticated;

    -- 4. Đảm bảo quyền quản trị cho postgres superuser và service_role
    GRANT ALL ON TABLE public._applied_migrations TO postgres, service_role;
  END IF;
END $$;
