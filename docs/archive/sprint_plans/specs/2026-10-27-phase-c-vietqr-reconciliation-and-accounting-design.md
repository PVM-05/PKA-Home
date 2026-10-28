# Đặc Tả Kỹ Thuật: Giai Đoạn C - Chuẩn Hoá Nghiệp Vụ Thương Mại (VietQR EMVCo, Biên Lai Điện Tử & Đối Soát Kế Toán)

**Tác giả:** Antigravity Agent & PKA-Home Team  
**Ngày lập:** 2026-10-27  
**Trạng thái:** Bản thiết kế hoàn chỉnh (Ready for Implementation Plan)  
**Mục tiêu:** Thương mại hoá toàn diện quy trình thanh toán và tài chính của PKA-Home: thay thế mã QR mô phỏng bằng mã VietQR chuẩn Napas 247 (EMVCo) sinh trực tiếp offline, cung cấp biên lai thu tiền điện tử có mã tra cứu và chức năng xuất báo cáo đối soát tài chính theo kỳ ra file Excel cho Ban Quản trị / Kế toán.

---

## 1. Bối Cảnh & Vấn Đề

1. **Thanh toán QR đang ở dạng "Mô phỏng":** `UnifiedPaymentSheet` hiện hiển thị chuỗi giả định `PKA-HOME-DEMO-PAYMENT...` với nhãn đỏ `DEMO ONLY` và số tài khoản demo `88889999DEMO`. Khi đưa vào vận hành thật, cư dân không thể quét chuyển khoản qua ứng dụng ngân hàng thông thường.
2. **Thiếu cấu hình tài khoản thụ hưởng theo Tòa nhà:** Mỗi tòa nhà thuộc các đơn vị vận hành khác nhau có tài khoản nhận kinh phí vận hành tại các ngân hàng khác nhau (MB, Vietcombank, BIDV...).
3. **Thiếu phiếu thu / biên lai điện tử hợp chuẩn:** Khi cư dân hoàn thành nộp tiền, họ cần phiếu thu điện tử có số chứng từ (`receipt_number`), ngày giờ xác nhận, danh mục chi tiết và số tiền đọc bằng chữ tiếng Việt để lưu trữ đối chiếu.
4. **Kế toán cần file Excel đối soát:** Ban Quản lý cần trích xuất dữ liệu thu tiền và công nợ theo kỳ ra bảng tính Excel để nộp báo cáo ban quản trị hoặc tích hợp phần mềm kế toán (như MISA, FAST).

---

## 2. Thiết Kế Cơ Sở Dữ Liệu

### 2.1. Cập Nhật Bảng `buildings`
Thêm thông tin tài khoản ngân hàng thụ hưởng cho từng tòa nhà:
```sql
ALTER TABLE public.buildings
    ADD COLUMN IF NOT EXISTS bank_bin VARCHAR(10) DEFAULT '970418', -- Mặc định BIDV
    ADD COLUMN IF NOT EXISTS bank_name TEXT DEFAULT 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam (BIDV)',
    ADD COLUMN IF NOT EXISTS bank_account_number TEXT DEFAULT '1234567890',
    ADD COLUMN IF NOT EXISTS bank_account_name TEXT DEFAULT 'BQL TOA NHA LANDMARK PKA';
```

### 2.2. Cập Nhật Bảng `invoices` & `payment_transactions`
Bổ sung các trường chứng từ kế toán:
```sql
ALTER TABLE public.invoices
    ADD COLUMN IF NOT EXISTS receipt_number VARCHAR(30),
    ADD COLUMN IF NOT EXISTS einvoice_lookup_code VARCHAR(32),
    ADD COLUMN IF NOT EXISTS paid_amount NUMERIC(12,2);

ALTER TABLE public.payment_transactions
    ADD COLUMN IF NOT EXISTS receipt_number VARCHAR(30),
    ADD COLUMN IF NOT EXISTS einvoice_lookup_code VARCHAR(32);
```

### 2.3. RPC Tạo Số Phiếu Thu Tự Động & Mã Tra Cứu
Hàm sinh số phiếu thu chuẩn `PT-YYYYMM-XXXXX` khi hóa đơn được thanh toán:
```sql
CREATE OR REPLACE FUNCTION public.generate_receipt_number(p_invoice_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_seq INT;
    v_period TEXT;
    v_receipt_number TEXT;
    v_lookup_code TEXT;
BEGIN
    SELECT to_char(CURRENT_DATE, 'YYYYMM') INTO v_period;
    
    -- Lấy số thứ tự phiếu thu trong tháng
    SELECT COALESCE(COUNT(*), 0) + 1 INTO v_seq
    FROM public.invoices
    WHERE receipt_number LIKE 'PT-' || v_period || '-%';
    
    v_receipt_number := 'PT-' || v_period || '-' || LPAD(v_seq::text, 5, '0');
    v_lookup_code := UPPER(SUBSTRING(MD5(p_invoice_id::text || clock_timestamp()::text) FROM 1 FOR 8));
    
    UPDATE public.invoices
    SET receipt_number = v_receipt_number,
        einvoice_lookup_code = v_lookup_code
    WHERE id = p_invoice_id AND receipt_number IS NULL;
    
    RETURN v_receipt_number;
END;
$$;
```

---

## 3. Kiến Trúc VietQR Generator (EMVCo Napas 247)

### 3.1. Chuẩn TLV (Tag-Length-Value)
Chuỗi dữ liệu VietQR bao gồm các tag chính:
- `00`: Payload Format Indicator (độ dài 02, giá trị `01`)
- `01`: Point of Initiation Method (độ dài 02, giá trị `12` cho QR động kèm số tiền)
- `38`: Merchant Account Information (Napas):
  - Sub-tag `00`: Guid `A000000727`
  - Sub-tag `01`: Beneficiary Organization:
    - Sub-tag `00`: Bank BIN (ví dụ: `970418` - BIDV, `970422` - MB, `970436` - VCB)
    - Sub-tag `01`: Bank Account Number
  - Sub-tag `02`: Service code `QRIBFTTA`
- `53`: Transaction Currency (`704` - VNĐ)
- `54`: Transaction Amount (Số tiền)
- `58`: Country Code (`VN`)
- `62`: Additional Data Field (Nội dung chuyển khoản syntax `PKA <MÃ_HÓA_ĐƠN>`)
- `63`: CRC16-CCITT (4 ký tự Hex kiểm tra toàn vẹn)

Sinh mã hoàn toàn độc lập, ngoại tuyến (offline), hiển thị qua `QrImageView` trong ứng dụng.

---

## 4. Giao Diện Biên Lai Thu Tiền Điện Tử & Tiện Ích Đọc Số Tiền

1. **Tiện ích chuyển đổi số tiền sang chữ tiếng Việt (`vietnamese_currency_words.dart`):**
   - Chuyển `1.250.000` thành *"Một triệu hai trăm năm mươi nghìn đồng chẵn"*.
   - Đảm bảo tuân thủ ngữ pháp tiếng Việt (mười / mươi, một / mốt, năm / lăm).
2. **Component `ElectronicReceiptSheet`:**
   - Mẫu phiếu thu: Logo PKA-Home, Tên tòa nhà, Số phiếu thu `PT-202610-00001`, Ngày thu, Tên cư dân, Căn hộ.
   - Bảng kê chi tiết các khoản phí.
   - Tổng cộng bằng số và bằng chữ.
   - Mã tra cứu điện tử (Lookup code) kèm nút sao chép và chia sẻ (Share).

---

## 5. Kế Toán & Xuất Báo Cáo Đối Soát Ra File Excel

- Sử dụng thư viện `excel` (đã có trong `pubspec.yaml`):
  - Bảng kê danh sách hóa đơn theo kỳ: Căn hộ, Kỳ thanh toán, Tiền quản lý, Tiền điện, Tiền nước, Phí gửi xe, Tổng tiền, Trạng thái (Đã thu / Chưa thu), Số phiếu thu, Ngày nộp tiền.
  - Tổng kết doanh thu thực thu so với dự thu.
  - Lưu file vào bộ nhớ thiết bị qua `path_provider` và mở menu chia sẻ qua `share_plus`.

---

## 6. Kế Hoạch Kiểm Thử & Verification

1. **Migration Test:** Kiểm tra migration mới cập nhật `buildings`, `invoices`, `payment_transactions` và hàm `generate_receipt_number`.
2. **VietQR Generator Test:** Kiểm tra cấu trúc chuỗi EMVCo, tính toán CRC16-CCITT và kiểm tra định dạng Napas 247.
3. **Vietnamese Currency Words Test:** Kiểm tra đọc số tiền tiếng Việt các mốc (hàng chục, trăm, nghìn, triệu, tỷ, các trường hợp mốt/lăm).
4. **E-Receipt Widget Test:** Kiểm tra hiển thị đầy đủ các thông tin phiếu thu và mã tra cứu.
5. **Accounting Export Service Test:** Kiểm tra tạo file Excel chứa đầy đủ các sheet và cột dữ liệu.
6. **Hồi quy toàn diện:** Chạy `flutter analyze` (0 issues) và `flutter test` (100% PASS).
