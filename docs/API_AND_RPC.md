# Danh Mục Stored Procedures & API Contracts (PKA-Home)

> Toàn bộ các thao tác tài chính, đặt lịch tiện ích, phát hành hóa đơn hàng loạt và hủy lịch trong PKA-Home đều được đóng gói thành các **PostgreSQL Remote Procedure Calls (RPC)** thực thi nguyên tử (ACID Transactions). Nếu có bất kỳ lỗi nào xảy ra trong chuỗi xử lý, PostgreSQL sẽ tự động Rollback toàn bộ trạng thái, ngăn ngừa tuyệt đối rác dữ liệu.

---

## 1. Danh Sách 10 RPCs Cốt Lõi Hệ Thống

| STT | Tên Stored Procedure | Quyền Hạn (RBAC) | Mục Đích Nghiệp Vụ |
| :--- | :--- | :--- | :--- |
| 1 | `create_invoice_with_items` | `accountant`, `admin`, `management` | Tạo hóa đơn kèm mảng các hạng mục phí nguyên tử trong 1 giao dịch. |
| 2 | `generate_valid_bulk_invoices` | `accountant`, `admin`, `management` | Lập hóa đơn hàng loạt tự động theo danh sách căn hộ kèm bước kiểm tra trùng lặp. |
| 3 | `simulate_unified_payment` | `authenticated` (Cư dân & BQL) | Cổng thanh toán đồng nhất: xử lý VietQR, Chuyển khoản (`PENDING`) và Tiền mặt. |
| 4 | `record_manual_payment` | `accountant`, `admin`, `management` | BQL/Kế toán xác nhận thu tiền trực tiếp và chuyển trạng thái giao dịch sang `paid`. |
| 5 | `book_amenity_slot` | `resident`, `management` | Đặt lịch tiện ích, kiểm tra sức chứa khả dụng theo thời gian thực và đẩy vào danh sách chờ. |
| 6 | `cancel_amenity_booking` | `resident` (chính chủ), `management` | Tự hủy lịch an toàn, hoàn phí/cọc và đôn người trong danh sách chờ (`waitlist`) lên thay thế. |
| 7 | `check_and_generate_invoice_due_reminders` | `accountant`, `admin`, `cron_job` | Quét tự động các hóa đơn chưa thanh toán theo 3 cấp độ (trước hạn 3 ngày, đúng hạn, quá hạn). |
| 8 | `approve_meter_reading` | `accountant`, `admin`, `management` | Thẩm định số điện nước cư dân gửi, duyệt chỉ số và kết chuyển sang hóa đơn dịch vụ. |
| 9 | `record_maintenance_fund_expense` | `accountant`, `admin` | Trích tiền từ Quỹ Bảo Trì tòa nhà phục vụ sửa chữa lớn, tự động ghi sổ cái kiểm toán. |
| 10 | `is_admin_or_accountant` | `SECURITY DEFINER Helper` | Hàm tiện ích nội tại kiểm tra vai trò người dùng trong CSDL an toàn. |
| 11 | `process_bank_payment_webhook` | `service_role`, `gateway` | Webhook biến động số dư VietQR Napas 247: tự động gạch nợ hóa đơn, chống trùng, kích hoạt audit log và thông báo. |
| 12 | `get_effective_user_role` | `authenticated` | Tính toán vai trò thực tế của người dùng kết hợp ủy quyền vai trò có thời hạn (`role_delegations`). |

---

## 2. Chi Tiết Hợp Đồng Giao Tiếp (Contract Specification)

### 2.1. RPC: `create_invoice_with_items`
Tạo một hóa đơn mới kèm danh sách các hạng mục phí con trong một giao dịch ACID.

- **Chữ ký (Signature):**
  ```sql
  create_invoice_with_items(
      p_apartment_id UUID,
      p_period DATE,
      p_due_date DATE,
      p_items JSONB,
      p_notes TEXT DEFAULT NULL
  ) RETURNS UUID
  ```
- **Tham số vào:**
  - `p_apartment_id`: ID căn hộ cần lập hóa đơn.
  - `p_period`: Kỳ thu phí (VD: `'2026-10-01'`).
  - `p_due_date`: Hạn chót thanh toán (VD: `'2026-10-15'`).
  - `p_items`: Mảng JSON chứa chi tiết các khoản phí:
    ```json
    [
      {"fee_type": "rent", "unit_price": 5000000, "quantity": 1, "description": "Tiền phòng tháng 10"},
      {"fee_type": "electricity", "unit_price": 3500, "quantity": 120, "description": "Điện tiêu thụ 120 kWh"},
      {"fee_type": "water", "unit_price": 25000, "quantity": 8, "description": "Nước sinh hoạt 8 m3"}
    ]
    ```
- **Giá trị trả về:** `UUID` của hóa đơn vừa tạo trong bảng `invoices`.
- **Cơ chế lỗi:** Nếu bất kỳ item nào sai cấu trúc hoặc không thể ghi vào DB, toàn bộ thao tác bị hủy và trả về mã lỗi `400 / 500`.

---

### 2.2. RPC: `generate_valid_bulk_invoices`
Phát hành hóa đơn hàng loạt cho toàn bộ cơ sở hoặc danh sách căn hộ được chọn lọc trước.

- **Chữ ký (Signature):**
  ```sql
  generate_valid_bulk_invoices(
      p_period DATE,
      p_due_date DATE,
      p_notes TEXT DEFAULT NULL,
      p_target_apartment_ids UUID[] DEFAULT NULL
  ) RETURNS TABLE(created_count INT, skipped_count INT)
  ```
- **Nghiệp vụ:**
  - Quét danh sách căn hộ thuộc mục tiêu (`p_target_apartment_ids` hoặc toàn bộ căn hộ đang có người ở).
  - Kiểm tra điều kiện: Căn hộ nào đã có hóa đơn trong kỳ `p_period` sẽ tự động bỏ qua (`skipped_count`).
  - Tự động trích xuất biểu phí mặc định từ `building_fee_configs` để tính toán tiền phòng, phí quản lý, phí gửi xe.
- **Giá trị trả về:** Bảng kết quả gồm số lượng hóa đơn tạo thành công (`created_count`) và số lượng bị bỏ qua (`skipped_count`).

---

### 2.3. RPC: `simulate_unified_payment`
Xử lý thanh toán đồng nhất cho cả Tiện ích lẫn Hóa đơn dịch vụ.

- **Chữ ký (Signature):**
  ```sql
  simulate_unified_payment(
      p_target_type TEXT, -- 'invoice' hoặc 'amenity_booking'
      p_target_id UUID,
      p_payment_method TEXT, -- 'vietqr' | 'bank_transfer' | 'cash'
      p_amount NUMERIC,
      p_is_pending BOOLEAN DEFAULT false
  ) RETURNS JSONB
  ```
- **Hành vi xử lý:**
  - Khi `p_is_pending = true` (Chuyển khoản cần đối soát): Trạng thái hóa đơn chuyển sang `pending_confirmation`.
  - Khi `p_is_pending = false` (Thanh toán trực tuyến thành công): Trạng thái hóa đơn chuyển sang `paid`, gán `paid_at = now()`, sinh mã biên lai điện tử và tự động kích hoạt trigger gửi thông báo cho Cư Dân.
  - Tích hợp cơ chế **Chống gửi lặp (Idempotency)** và khóa dòng `FOR UPDATE` chống race-condition.

---

### 2.4. RPC: `cancel_amenity_booking`
Cư dân hoặc Ban quản lý tự hủy lịch sử dụng tiện ích nội khu an toàn.

- **Chữ ký (Signature):**
  ```sql
  cancel_amenity_booking(p_booking_id UUID) RETURNS JSONB
  ```
- **Nghiệp vụ tự động hóa:**
  1. Kiểm tra quyền: Người gọi phải là người đặt lịch (`booked_by = auth.uid()`) hoặc nhân sự quản lý (`management`).
  2. Cập nhật trạng thái phiếu hiện tại sang `'cancelled'`.
  3. Quét bảng `amenity_bookings` tìm kiếm người đang ở hàng chờ (`status = 'waitlist'`) sớm nhất cùng khung giờ.
  4. Nếu có người chờ: Tự động đôn lên trạng thái `'confirmed'` hoặc `'pending_payment'`, tự động gửi thông báo chúc mừng tới điện thoại của họ.
  5. Trả về kết quả:
     ```json
     {"success": true, "promoted_booking_id": "uuid-cua-nguoi-ke-tiep"}
     ```

---

### 2.5. RPC: `check_and_generate_invoice_due_reminders`
Quét và tự động phát hành thông báo nhắc phí đa tầng.

- **Chữ ký (Signature):**
  ```sql
  check_and_generate_invoice_due_reminders(p_building_id UUID DEFAULT NULL) RETURNS INT
  ```
- **Quy tắc 3 Cấp Độ Cảnh Báo:**
  1. **Trước hạn 3 ngày (`invoice_due_soon`):** Hóa đơn có `due_date - CURRENT_DATE = 3`.
  2. **Đúng hạn hôm nay (`invoice_due_today`):** Hóa đơn có `due_date = CURRENT_DATE`.
  3. **Đã quá hạn (`invoice_overdue`):** Hóa đơn có `due_date < CURRENT_DATE` và chưa đóng tiền (`unpaid`).
- **Chống làm phiền (Rate Limiting):** Mỗi hóa đơn chỉ nhận tối đa 1 thông báo cùng loại trong vòng 24 giờ.
- **Giá trị trả về:** Tổng số thông báo đã được gửi đi thành công (`INT`).

---

### 2.6. RPC: `process_bank_payment_webhook`
Nhận Webhook biến động số dư từ cổng ngân hàng / VietQR Napas 247 để tự động gạch nợ hóa đơn chuẩn thương mại.

- **Chữ ký (Signature):**
  ```sql
  process_bank_payment_webhook(p_payload JSONB) RETURNS JSONB
  ```
- **Tham số vào:**
  - `p_payload`: Dữ liệu biến động số dư từ ngân hàng (chứa `gateway_transaction_id`, `amount`, `content` / `description`).
- **Nghiệp vụ cốt lõi:**
  1. **Idempotency Key:** Kiểm tra `gateway_transaction_id` trong `payment_transactions`, từ chối trùng lặp (`DUPLICATE`).
  2. **Khóa bản ghi (Row Locking):** Khóa hóa đơn tương ứng với `FOR UPDATE` theo `payment_code` trích xuất từ nội dung chuyển khoản.
  3. **Tự động gạch nợ:** Nếu số tiền nhận $\ge$ `total_amount`, cập nhật `invoices.status = 'paid'`, sinh mã biên nhận `receipt_number`.
  4. **Kích hoạt Audit & Notification:** Kích hoạt trigger `trg_audit_invoice_changes` (ghi nhật ký kiểm toán bất biến) và `trg_notify_on_invoice_paid` (bắn thông báo biên lai tới cư dân).
  5. **Xử lý bất thường:** Tự động phát hiện và phân loại `UNMATCHED` (không tìm thấy hóa đơn), `OVERPAID` (nộp thừa tiền), `PARTIAL_PAID` (nộp thiếu tiền).

---

### 2.7. RPC: `get_effective_user_role`
Tính toán vai trò thực tế của người dùng kết hợp ủy quyền vai trò có thời hạn (`role_delegations`).

- **Chữ ký (Signature):**
  ```sql
  get_effective_user_role(p_user_id UUID, p_building_id UUID DEFAULT NULL) RETURNS TEXT
  ```
- **Nghiệp vụ:**
  - Kiểm tra các ủy quyền còn hiệu lực trong bảng `role_delegations` (`now() BETWEEN start_date AND end_date` và `is_revoked = false`).
  - Trả về vai trò được ủy quyền ưu tiên cao hơn (VD: `resident` được ủy quyền quyền `management` trong 7 ngày) hoặc trả về vai trò gốc từ bảng `users`.

