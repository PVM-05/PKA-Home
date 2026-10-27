-- Migration: Tự động đồng bộ 2 chiều Họ tên giữa auth.users và public.users
-- Giúp Supabase Dashboard (Auth tab) và ứng dụng luôn nhất quán khi đổi tên

-- 1. Hàm đồng bộ từ public.users sang auth.users khi người dùng đổi tên trong App
CREATE OR REPLACE FUNCTION public.sync_user_profile_to_auth()
RETURNS trigger
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF NEW.full_name IS DISTINCT FROM OLD.full_name THEN
    UPDATE auth.users
    SET raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('full_name', NEW.full_name)
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_user_profile_to_auth ON public.users;
CREATE TRIGGER trg_sync_user_profile_to_auth
AFTER UPDATE OF full_name ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.sync_user_profile_to_auth();

-- 2. Hàm đồng bộ từ auth.users sang public.users khi quản trị viên đổi tên trên Supabase Auth Dashboard
CREATE OR REPLACE FUNCTION public.sync_auth_user_to_public()
RETURNS trigger
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  IF (NEW.raw_user_meta_data->>'full_name') IS NOT NULL 
     AND (OLD.raw_user_meta_data->>'full_name' IS DISTINCT FROM NEW.raw_user_meta_data->>'full_name') THEN
    UPDATE public.users
    SET full_name = NEW.raw_user_meta_data->>'full_name'
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_auth_user_to_public ON auth.users;
CREATE TRIGGER trg_sync_auth_user_to_public
AFTER UPDATE OF raw_user_meta_data ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.sync_auth_user_to_public();
