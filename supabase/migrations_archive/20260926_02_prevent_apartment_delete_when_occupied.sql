-- Migration: Chặn xóa căn hộ ở tầng CSDL nếu còn cư dân đang cư trú hoặc có dữ liệu hóa đơn
CREATE OR REPLACE FUNCTION public.prevent_apartment_delete_when_occupied()
RETURNS TRIGGER AS $$
DECLARE
  v_resident_count INT;
  v_invoice_count INT;
BEGIN
  -- 1. Kiểm tra cư dân đang liên kết
  SELECT COUNT(*) INTO v_resident_count
  FROM public.residents_apartments
  WHERE apartment_id = OLD.id;

  IF v_resident_count > 0 THEN
    RAISE EXCEPTION 'Không thể xóa căn hộ đang có % cư dân liên kết. Vui lòng hủy liên kết cư dân trước!', v_resident_count
      USING ERRCODE = 'P0001';
  END IF;

  -- 2. Kiểm tra hóa đơn gắn liền với căn hộ
  SELECT COUNT(*) INTO v_invoice_count
  FROM public.invoices
  WHERE apartment_id = OLD.id;

  IF v_invoice_count > 0 THEN
    RAISE EXCEPTION 'Không thể xóa căn hộ đang có % hóa đơn trong hệ thống. Dữ liệu tài chính cần được bảo toàn!', v_invoice_count
      USING ERRCODE = 'P0001';
  END IF;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_apartment_delete_when_occupied ON public.apartments;

CREATE TRIGGER trg_prevent_apartment_delete_when_occupied
BEFORE DELETE ON public.apartments
FOR EACH ROW
EXECUTE FUNCTION public.prevent_apartment_delete_when_occupied();
