-- Kích hoạt REPLICA IDENTITY FULL cho bảng vehicles
-- Cho phép Supabase Realtime gửi đầy đủ thông tin cũ khi DELETE (phục vụ filter theo apartment_id)
ALTER TABLE public.vehicles REPLICA IDENTITY FULL;
