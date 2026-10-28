# Thiết Kế Kỹ Thuật: Hệ Thống Cổng Thanh Toán Mô Phỏng (Demo Payment Gateway & Transactions)

## 1. Mục Tiêu & Bối Cảnh (Context & Goal)
- **Mục tiêu**: Xây dựng hệ thống cổng thanh toán mô phỏng (Demo Payment Simulation) chuẩn kiến trúc thanh toán doanh nghiệp cho ứng dụng PKA-Home, phục vụ việc trình diễn đồ án và thử nghiệm thực tế mà không yêu cầu chuyển tiền thật.
- **Thay đổi so với hệ thống cũ**: Loại bỏ hoàn toàn luồng quét mã VietQR và cơ chế duyệt thủ công từng hóa đơn; thay thế bằng quy trình thanh toán trực tuyến 1 chạm (Simulated Payment) với 3 kịch bản: `Thành công`, `Thất bại`, `Hủy giao dịch`.
- **Nguyên tắc bảo mật cốt lõi**:
  - Tuyệt đối **không** cho phép Client Flutter tự ý cập nhật `UPDATE invoices SET status = 'paid'`.
  - Mọi giao dịch phải được thực thi thông qua PostgreSQL Remote Procedure Call (RPC) `simulate_invoice_payment` nguyên tử (Atomic Transaction), kiểm tra session đăng nhập, quyền hạn căn hộ của cư dân, ghi nhận bảng giao dịch `payment_transactions`, cập nhật trạng thái hóa đơn và sinh mã kiểm toán `audit_logs` tự động.

---

## 2. Kiến Trúc & Cơ Sở Dữ Liệu (Database Architecture)

### 2.1. Bảng Giao Dịch Thanh Toán (`public.payment_transactions`)
Bảng mới lưu trữ lịch sử mọi lần thử thanh toán của cư dân:
```sql
CREATE TABLE IF NOT EXISTS public.payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    payment_method VARCHAR(50) NOT NULL DEFAULT 'DEMO',
    status VARCHAR(20) NOT NULL CHECK (status IN ('SUCCESS', 'FAILED', 'CANCELLED')),
    transaction_code VARCHAR(100) NOT NULL UNIQUE,
    failure_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_transactions_invoice ON public.payment_transactions(invoice_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_apartment ON public.payment_transactions(apartment_id);
```

### 2.2. Row Level Security (RLS) cho `payment_transactions`
- Bật RLS: `ALTER TABLE public.payment_transactions ENABLE ROW LEVEL SECURITY;`
- **Quyền SELECT**:
  - Cư dân chỉ được xem các giao dịch thuộc căn hộ mà họ có liên kết trong `public.residents_apartments`.
  - Ban Quản Lý (`public.is_staff()`) có toàn quyền xem mọi giao dịch trên toàn hệ thống.
- **Quyền INSERT / UPDATE / DELETE**:
  - Không cho phép Client INSERT/UPDATE trực tiếp từ PostgREST API (chỉ hàm RPC `SECURITY DEFINER` mới được tạo bản ghi).

### 2.3. Nâng cấp bảng `public.invoices`
- Thêm cột `payment_method VARCHAR(50) DEFAULT 'unpaid'` (lưu `'DEMO'`, `'cash'`, v.v.).
- Thêm cột `transaction_id UUID REFERENCES public.payment_transactions(id)` hoặc `transaction_code VARCHAR(100)`.
- Thêm cột `paid_at TIMESTAMPTZ`.

### 2.4. PostgreSQL RPC: `public.simulate_invoice_payment`
```sql
CREATE OR REPLACE FUNCTION public.simulate_invoice_payment(
    p_invoice_id UUID,
    p_outcome VARCHAR -- 'SUCCESS', 'FAILED', 'CANCELLED'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
...
$$;
```
**Các bước xử lý tuần tự trong RPC**:
1. Xác thực người dùng hiện tại `v_user_id := auth.uid()`. Nếu `NULL` $\rightarrow$ ném ngoại lệ chưa đăng nhập.
2. Khóa dòng hóa đơn: `SELECT * FROM public.invoices WHERE id = p_invoice_id FOR UPDATE;`
3. Kiểm tra quyền hạn: Người dùng phải là cư dân của căn hộ chứa hóa đơn này (hoặc `public.is_staff()`).
4. Kiểm tra trạng thái: Hóa đơn không được đang ở trạng thái `paid`.
5. Tạo mã giao dịch chuẩn hóa: `PAY-YYYYMMDD-XXXXX` (kết hợp ngày tháng và chuỗi ngẫu nhiên/số thứ tự).
6. Nếu `p_outcome = 'SUCCESS'`:
   - Ghi bản ghi vào `payment_transactions` với `status = 'SUCCESS'`.
   - Cập nhật hóa đơn `status = 'paid'`, `payment_method = 'DEMO'`, `paid_at = NOW()`.
   - Ghi nhận `audit_logs` (thao tác thanh toán hóa đơn).
   - Thêm thông báo `notifications` tới cư dân (và BQL).
   - Trả về JSON `{ "success": true, "status": "paid", "transaction_code": v_code, "amount": v_amount }`.
7. Nếu `p_outcome = 'FAILED'`:
   - Ghi bản ghi vào `payment_transactions` với `status = 'FAILED'`, `failure_reason = 'Giao dịch bị từ chối bởi cổng thanh toán mô phỏng (Demo)'`.
   - Hóa đơn giữ nguyên trạng thái `unpaid`.
   - Trả về JSON `{ "success": false, "status": "unpaid", "transaction_code": v_code, "message": "Giao dịch thanh toán thất bại (Thử nghiệm)." }`.
8. Nếu `p_outcome = 'CANCELLED'`:
   - Ghi nhận giao dịch `CANCELLED` hoặc không cập nhật trạng thái hóa đơn.

---

## 3. Thiết Kế Tầng Dữ Liệu (Data Layer & Repository)

### 3.1. Data Model: `PaymentTransactionModel`
- File: `lib/data/models/payment_transaction_model.dart`
- Thuộc tính: `id`, `invoiceId`, `userId`, `apartmentId`, `amount`, `paymentMethod`, `status`, `transactionCode`, `failureReason`, `createdAt`.
- Getters: `isSuccess`, `isFailed`, `isCancelled`, `formattedAmount`, `statusDisplayName`.
- Phương thức: `fromJson`, `toJson`.

### 3.2. Repository: `InvoiceRepository` / `ResidentInvoiceService`
- Mở rộng phương thức trong `lib/data/repositories/` hoặc `ResidentInvoiceService`:
  ```dart
  Future<Map<String, dynamic>> simulatePayment({
    required String invoiceId,
    required String outcome, // 'SUCCESS' hoặc 'FAILED'
  })
  ```
- Gọi trực tiếp RPC `simulate_invoice_payment`.

---

## 4. Thiết Kế Giao Diện Người Dùng (UI/UX Design)

### 4.1. Màn hình Chi tiết Hóa đơn (`ResidentInvoiceDetailScreen`)
- Loại bỏ hoàn toàn `_showPaymentBottomSheet` có mã QR VietQR cũ.
- Khi người dùng bấm nút **"THANH TOÁN NGAY"**:
  - Mở Bottom Sheet **"Cổng Thanh Toán Mô Phỏng (Demo Payment)"**:
    - **Header**: Biểu tượng thẻ ngân hàng, tiêu đề "Thanh Toán Hóa Đơn Trực Tuyến".
    - **Tóm tắt đơn hàng**:
      - Mã hóa đơn & Kỳ thu (VD: `INV-2026-00125 • Kỳ 10/2026`).
      - Bảng phân rã chi phí ngắn gọn (Phí quản lý, Nước, Xe...).
      - **Tổng tiền nổi bật**: Font to, màu `AppTheme.primary`.
    - **Phương thức thanh toán**:
      - Thẻ chọn "Cổng thanh toán điện tử PKA (Mô phỏng Demo)".
      - Huy hiệu "Môi trường thử nghiệm / Miễn phí 100%".
    - **Nút hành động chính**: Bấm **"TIẾN HÀNH THANH TOÁN"**.

### 4.2. Hộp thoại Xác nhận Mô phỏng (Simulated Gateway Dialog)
- Khi bấm "Tiến hành thanh toán", hiển thị Modal Dialog giả lập cổng thanh toán:
  - Hiển thị số tiền: `500.000 đ`.
  - Hộp thông tin: "Chọn kịch bản kiểm thử để kiểm tra luồng xử lý của hệ thống:".
  - **Nút 1 (Xanh lá)**: `[✓ Thanh toán thành công (Mô phỏng)]`
    - Khi bấm: Hiển thị vòng xoay đang xử lý giao dịch 1.2s $\rightarrow$ gọi RPC `SUCCESS` $\rightarrow$ nổ pháo hoa / icon check xanh thành công $\rightarrow$ chuyển hóa đơn sang `paid` và cấp biên nhận điện tử.
  - **Nút 2 (Đỏ cam)**: `[✕ Thanh toán thất bại (Mô phỏng)]`
    - Khi bấm: Hiển thị vòng xoay đang xử lý 1.0s $\rightarrow$ gọi RPC `FAILED` $\rightarrow$ thông báo lỗi thanh toán không thành công $\rightarrow$ hóa đơn giữ nguyên `unpaid`.
  - **Nút 3**: `[Hủy bỏ]` $\rightarrow$ Đóng hộp thoại, không thay đổi dữ liệu.

### 4.3. Nâng cấp Biên nhận điện tử (Digital Receipt)
- Biên nhận hiển thị rõ:
  - Mã biên nhận: `REC-XXXXX`
  - Mã giao dịch: `PAY-YYYYMMDD-XXXXX`
  - Phương thức: `Demo Payment (Cổng thanh toán mô phỏng)`
  - Thời gian thanh toán: Định dạng `dd/MM/yyyy HH:mm:ss`.

---

## 5. Kế Hoạch Kiểm Thử (Testing & TDD)
1. **Unit Test**:
   - `test/data/models/payment_transaction_model_test.dart`: Parse JSON, format tiền tệ, kiểm tra getters trạng thái.
2. **Widget Test**:
   - `test/features/resident/demo_payment_sheet_test.dart`: Render giao diện thanh toán mô phỏng, chọn thành công/thất bại, hiển thị đúng số tiền và thông tin kỳ thu.
3. **Regression Test**:
   - Chạy toàn bộ 171 test cases hiện có đảm bảo 100% PASS không có hồi quy.
