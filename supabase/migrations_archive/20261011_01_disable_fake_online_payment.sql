-- PKA-Home: disable fake online-payment success until a real provider is configured.
-- This project has no real payment gateway. Never create a successful transaction
-- or mark invoices/bookings as paid/confirmed through a simulated client RPC.
CREATE OR REPLACE FUNCTION public.simulate_unified_payment(
  p_type VARCHAR,
  p_reference_id UUID,
  p_payment_method VARCHAR DEFAULT 'bank_transfer',
  p_outcome VARCHAR DEFAULT 'SUCCESS',
  p_failure_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Yêu cầu đăng nhập để tiếp tục';
  END IF;

  RAISE EXCEPTION USING
    ERRCODE = 'feature_not_supported',
    MESSAGE = 'Thanh toán trực tuyến chưa được cấu hình. Hệ thống không ghi nhận giao dịch demo; vui lòng liên hệ Ban Quản Lý để xác nhận thanh toán.';
END;
$$;

REVOKE ALL ON FUNCTION public.simulate_unified_payment(VARCHAR, UUID, VARCHAR, VARCHAR, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.simulate_unified_payment(VARCHAR, UUID, VARCHAR, VARCHAR, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.simulate_unified_payment(VARCHAR, UUID, VARCHAR, VARCHAR, TEXT) TO authenticated;
