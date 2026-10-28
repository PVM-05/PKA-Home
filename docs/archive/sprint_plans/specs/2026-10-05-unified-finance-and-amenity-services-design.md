# Đặc Tả Kiến Trúc: Hợp Nhất Tài Chính & Dịch Vụ Chung Cư (Unified Demo Payment)

- **Mã tài liệu**: `SPEC-20261005-UNIFIED-PAYMENT`
- **Ngày lập**: 05/10/2026
- **Trạng thái**: Chờ duyệt (Under Review)
- **Tác giả**: Antigravity Pair Programmer & Người dùng

---

## 1. Bối Cảnh & Mục Tiêu

Ứng dụng **PKA Home** cần một cơ chế thanh toán mô phỏng (Demo Payment) thống nhất, không dùng tiền thật, phục vụ việc trình diễn đồ án trọn vẹn và thể hiện năng lực kiến trúc phần mềm doanh nghiệp:
1. **Phân tách nghiệp vụ rõ ràng**:
   - **Tài chính (Finance)**: Hóa đơn sinh hoạt định kỳ hàng tháng (quản lý, điện, nước, gửi xe). Thanh toán trọn gói 1 lần/tháng.
   - **Dịch vụ (Services)**: Tiện ích cư dân chủ động đăng ký sử dụng (Gym, Hồ bơi, Sân cầu lông).
2. **Dùng chung một hệ thống thanh toán (`PaymentService`)**:
   - Không nhân bản hệ thống thanh toán thành 2 nơi riêng biệt.
   - Cung cấp một luồng thanh toán mô phỏng duy nhất: **◉ Demo Payment** (loại bỏ chọn cổng thanh toán phức tạp).
   - Quy trình 3 bước mượt mà: `Xác nhận số tiền` $\rightarrow$ `⏳ Đang xử lý (1.2s - 1.5s)` $\rightarrow$ `✅ Thanh toán thành công (Mã DEMO-YYYYMMDD-XXX)`.
3. **Phân nhánh kết quả sau thanh toán**:
   - Hóa đơn: Cập nhật `invoices.status = 'paid'`.
   - Dịch vụ: Cập nhật `amenity_bookings.status = 'confirmed'`, mở mã QR đặt chỗ.
4. **Lịch sử thanh toán gom chung (Unified Payment History)**:
   - Hiển thị cả 2 nguồn giao dịch trên cùng một màn hình với bộ lọc: `[Tất cả]`, `[Hóa đơn]`, `[Dịch vụ]`.

---

## 2. Kiến Trúc Tổng Thể (System Architecture)

```
                            PKA HOME
                               │
             ┌─────────────────┴─────────────────┐
             ▼                                   ▼
        TÀI CHÍNH                             DỊCH VỤ
     (Hóa đơn tháng)                   (Gym, Hồ bơi, Sân thể thao)
   Quản lý, Điện, Nước, Xe                      Booking
             │                                   │
             └─────────────────┬─────────────────┘
                               ▼
                       PaymentService.pay()
                               │
                               ▼
                      UnifiedPaymentSheet
                      (Modal giao dịch)
                               │
                     [ ◉ Demo Payment ]
                               │
                               ▼
                     ⏳ Đang xử lý giao dịch...
                     (Mô phỏng trễ 1.2s - 1.5s)
                               │
                               ▼
                    PostgreSQL RPC nguyên tử
                   (simulate_unified_payment)
                               │
                               ▼
                     ✅ Thanh toán thành công
                    Mã GD: DEMO-YYYYMMDD-XXX
                               │
             ┌─────────────────┴─────────────────┐
             ▼                                   ▼
       Invoice = PAID                    Booking = CONFIRMED
    (Xem hóa đơn/biên nhận)             (Hiển thị QR Check-in)
```

---

## 3. Thiết Kế Cơ Sở Dữ Liệu (Database Schema)

### 3.1. Nâng cấp bảng `public.payment_transactions`
```sql
ALTER TABLE public.payment_transactions
ADD COLUMN IF NOT EXISTS type VARCHAR(20) NOT NULL DEFAULT 'INVOICE' 
    CHECK (type IN ('INVOICE', 'SERVICE')),
ADD COLUMN IF NOT EXISTS booking_id UUID REFERENCES public.amenity_bookings(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS title TEXT,
ALTER COLUMN invoice_id DROP NOT NULL;

CREATE INDEX IF NOT EXISTS idx_payment_transactions_booking ON public.payment_transactions(booking_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_type ON public.payment_transactions(type);
```

### 3.2. RPC Nguyên Tử: `public.simulate_unified_payment`
```sql
CREATE OR REPLACE FUNCTION public.simulate_unified_payment(
    p_type VARCHAR,            -- 'INVOICE' hoặc 'SERVICE'
    p_reference_id UUID,       -- invoice_id hoặc booking_id
    p_outcome VARCHAR DEFAULT 'SUCCESS'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_apt_id UUID;
    v_amount NUMERIC(12,2);
    v_tx_code VARCHAR;
    v_title TEXT;
    v_tx_id UUID;
BEGIN
    -- Sinh mã giao dịch chuẩn DEMO-YYYYMMDD-XXXX
    v_tx_code := 'DEMO-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');

    IF p_type = 'INVOICE' THEN
        SELECT apartment_id, total_amount, 'Hóa đơn tháng ' || period
        INTO v_apt_id, v_amount, v_title
        FROM public.invoices WHERE id = p_reference_id;

        IF p_outcome = 'SUCCESS' THEN
            UPDATE public.invoices
            SET status = 'paid', payment_method = 'Demo Payment',
                transaction_code = v_tx_code, paid_at = NOW(), updated_at = NOW()
            WHERE id = p_reference_id;
        END IF;

        INSERT INTO public.payment_transactions (
            invoice_id, user_id, apartment_id, amount, payment_method, status, transaction_code, type, title
        ) VALUES (
            p_reference_id, v_user_id, v_apt_id, v_amount, 'Demo Payment', p_outcome, v_tx_code, 'INVOICE', v_title
        ) RETURNING id INTO v_tx_id;

    ELSIF p_type = 'SERVICE' THEN
        SELECT b.apartment_id, COALESCE(b.fee_amount, 0) + COALESCE(b.deposit_amount, 0),
               a.name || ' (' || b.time_slot || ')'
        INTO v_apt_id, v_amount, v_title
        FROM public.amenity_bookings b
        JOIN public.building_amenities a ON a.id = b.amenity_id
        WHERE b.id = p_reference_id;

        IF p_outcome = 'SUCCESS' THEN
            UPDATE public.amenity_bookings
            SET status = 'confirmed', deposit_status = CASE WHEN deposit_amount > 0 THEN 'received' ELSE 'none' END,
                updated_at = NOW()
            WHERE id = p_reference_id;
        END IF;

        INSERT INTO public.payment_transactions (
            booking_id, user_id, apartment_id, amount, payment_method, status, transaction_code, type, title
        ) VALUES (
            p_reference_id, v_user_id, v_apt_id, v_amount, 'Demo Payment', p_outcome, v_tx_code, 'SERVICE', v_title
        ) RETURNING id INTO v_tx_id;
    END IF;

    RETURN jsonb_build_object(
        'success', (p_outcome = 'SUCCESS'),
        'transaction_code', v_tx_code,
        'transaction_id', v_tx_id,
        'amount', v_amount,
        'title', v_title,
        'paid_at', NOW()
    );
END;
$$;
```

---

## 4. Thiết Kế Tầng Dữ Liệu & Service (Flutter / Riverpod)

### 4.1. `PaymentType` & `PaymentResult`
```dart
enum PaymentType { invoice, service }

class PaymentResult {
  final bool success;
  final String transactionCode;
  final String transactionId;
  final double amount;
  final String title;
  final DateTime paidAt;
  final String? errorMessage;
}
```

### 4.2. `PaymentService`
Phương thức duy nhất gọi qua RPC:
```dart
class PaymentService {
  Future<PaymentResult> pay({
    required WidgetRef ref,
    required PaymentType type,
    required String referenceId,
    String outcome = 'SUCCESS',
  });
}
```

---

## 5. Thiết Kế Giao Diện (UI / UX)

### 5.1. `UnifiedPaymentSheet`
Component Bottom Sheet chung quản lý 3 trạng thái:
1. **Trạng thái 1: Xác nhận thanh toán (Confirmation)**:
   - Header: Tiêu đề giao dịch (`Thanh toán hóa đơn` hoặc `Đăng ký dịch vụ`).
   - Mã tham chiếu: `#INV-202610-A0110` hoặc `#SRV-GYM-01`.
   - Tổng tiền to, in đậm (VD: `1.480.000đ` hoặc `300.000đ`).
   - Khung phương thức thanh toán cố định:
     ```text
     ◉ Demo Payment
       Giao dịch mô phỏng (Sandbox)
     ```
   - Nút hành động: `[ THANH TOÁN ]` (Full-width, primary button).
2. **Trạng thái 2: Đang xử lý giao dịch (Processing)**:
   - Animation xoay mượt mà với 3 chấm động `● ● ●`.
   - Tiêu đề: *Đang xử lý giao dịch...*
   - Số tiền hiển thị nổi bật.
   - Timer 1.2s - 1.5s trước khi hoàn tất gọi backend RPC.
3. **Trạng thái 3: Kết quả giao dịch (Success / Failure)**:
   - Biểu tượng `✓` màu xanh lục thành công với hiệu ứng xuất hiện.
   - *Thanh toán thành công*.
   - Số tiền đã trừ, Mã giao dịch `DEMO-20261005-001`.
   - Thời gian thanh toán chuẩn mực tiếng Việt.
   - Nút hành động:
     - Với Hóa đơn: `[ XEM HÓA ĐƠN ]` / `[ HOÀN TẤT ]`.
     - Với Dịch vụ: `[ HIỂN THỊ MÃ QR CHECK-IN ]` / `[ HOÀN TẤT ]`.

### 5.2. Màn hình Lịch sử thanh toán gom chung (`PaymentHistoryScreen`)
- Hiển thị danh sách mọi giao dịch từ `payment_transactions`.
- Bộ lọc ngang (Chips):
  - `[ Tất cả ]`
  - `[ 🏠 Hóa đơn ]`
  - `[ 🏋️ Dịch vụ ]`
- Mỗi card giao dịch hiển thị:
  - Icon tương ứng (🏠 Nhà/Hóa đơn, 🏋️ Gym, 🏊 Hồ bơi, 🏸 Cầu lông).
  - Tên giao dịch & Mã căn hộ / Thời gian.
  - Số tiền (in đậm).
  - Trạng thái: `✓ Thành công` (xanh lá) hoặc `✕ Thất bại` (đỏ).
  - Mã giao dịch: `DEMO-20261005-XXX`.

---

## 6. Kế Hoạch Kiểm Thử (Testing Strategy)

1. **Unit Test**:
   - `PaymentService` xử lý đúng cả `PaymentType.invoice` và `PaymentType.service`.
   - `PaymentTransactionModel` parse đúng trường `type`, `booking_id`, `title`.
2. **Widget Test**:
   - `UnifiedPaymentSheet` hiển thị đúng thông tin, nút bấm, chuyển trạng thái `Processing` $\rightarrow$ `Success`.
   - Màn hình Lịch sử thanh toán lọc đúng theo tab Hóa đơn / Dịch vụ.
3. **Static Analysis**:
   - Đảm bảo `dart analyze` sạch 100% không lỗi / warning.
