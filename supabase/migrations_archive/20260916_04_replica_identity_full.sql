-- Kích hoạt REPLICA IDENTITY FULL cho các bảng dùng Realtime
-- Giúp Supabase Realtime gửi đầy đủ record cũ và mới khi UPDATE/DELETE,
-- giải quyết dứt điểm lỗi notification badge không tự động biến mất khi status thay đổi.

ALTER TABLE public.apartment_link_requests REPLICA IDENTITY FULL;
ALTER TABLE public.invoices REPLICA IDENTITY FULL;
ALTER TABLE public.issue_reports REPLICA IDENTITY FULL;
ALTER TABLE public.announcements REPLICA IDENTITY FULL;
