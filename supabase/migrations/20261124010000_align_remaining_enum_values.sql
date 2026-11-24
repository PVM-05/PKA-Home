-- ==============================================================================
-- Vivona Production Commercial SaaS: Migration 20261124010000_align_remaining_enum_values.sql
-- Mục tiêu:
--   Bổ sung giá trị 'cancelled' cho public.vehicle_status và public.meter_submission_status
--   trong một transaction tách biệt trước khi các hàm/policy ở migration 20261124020000 sử dụng.
--   Khắc phục lỗi runtime SQL crash trên cancel_pending_vehicle & cancel_pending_meter_reading.
-- ==============================================================================

ALTER TYPE public.vehicle_status ADD VALUE IF NOT EXISTS 'cancelled';
ALTER TYPE public.meter_submission_status ADD VALUE IF NOT EXISTS 'cancelled';
