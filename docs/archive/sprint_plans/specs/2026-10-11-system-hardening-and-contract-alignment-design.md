# Thiết Kế Kỹ Thuật: Đồng Bộ Giao Diện Thanh Toán, Chuẩn Hóa Số Liệu Tài Chính & Khắc Phục Lệch Hợp Đồng RPC

- **Mã Tài Liệu**: SPEC-SYS-2026-10-11-02
- **Ngày lập**: 11/10/2026
- **Trạng thái**: Đã phê duyệt (Approved)
- **Phạm vi**: Database RPCs, Repositories, Providers, Resident UI & Dashboard

---

## 1. Bối Cảnh & Vấn Đề (Problem Statement)

Hệ thống đã áp dụng migration `20261011_01_disable_fake_online_payment.sql` để chặn giao dịch thanh toán giả lập trực tuyến, tuy nhiên việc rà soát kỹ thuật phát hiện 5 điểm lệch và nguy cơ dữ liệu:
1. **Lệch giao diện thanh toán tiện ích**: [amenity_booking_screen.dart](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/features/resident/screens/amenity_booking_screen.dart) hiển thị thông báo *"Đặt lịch tiện ích thành công!"* với màu xanh `paid` kể cả khi RPC thanh toán trả về lỗi có chủ đích.
2. **Sai lệch thống kê tài chính trên Dashboard**: [dashboard_providers.dart](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/data/providers/dashboard_providers.dart) phân loại toàn bộ hóa đơn không có trạng thái `paid` vào nợ chưa thanh toán (kể cả `cancelled`, `void`), và dùng công thức `totalRevenue = paidTotal + unpaidTotal` sai thuật ngữ tài chính.
3. **Repository đặt tiện ích che giấu lỗi backend**: [amenity_booking_repository.dart](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/data/repositories/amenity_booking_repository.dart) dùng `catch (_) { return []; }` nuốt chửng lỗi mạng và RLS, khiến người dùng hiểu nhầm là không có dữ liệu.
4. **Cập nhật hóa đơn fallback không nguyên tử**: [management_repository.dart](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/data/repositories/management_repository.dart) bắt mọi lỗi của RPC `update_invoice_with_items` (vốn đã bị DROP) rồi xóa và chèn lại các mục hóa đơn qua các lệnh API rời rạc không an toàn.
5. **Lệch hợp đồng API giữa Flutter và RPC `book_amenity_slot`**: Repository gửi `p_apartment_id` và `p_allow_waitlist`, trong khi RPC trên database thiếu hai tham số này, gây lỗi không tìm thấy hàm khi gọi qua PostgREST.

---

## 2. Thiết Kế Chi Tiết Từng Hạng Mục (Detailed Design)

### 2.1. Hạng Mục 1: Migration 20261011_03 — Khôi Phục & Đồng Bộ RPC CSDL
Tạo file migration `supabase/migrations/20261011_03_harmonize_amenity_and_invoice_rpcs.sql`:
1. **Tái tạo RPC nguyên tử `update_invoice_with_items`**:
   ```sql
   CREATE OR REPLACE FUNCTION public.update_invoice_with_items(
       p_invoice_id UUID,
       p_period VARCHAR,
       p_due_date DATE,
       p_items JSONB,
       p_apartment_id UUID DEFAULT NULL,
       p_status VARCHAR DEFAULT NULL
   )
   RETURNS JSONB
   LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = public, pg_catalog;
   ```
   - Kiểm tra `is_admin_or_accountant()`.
   - Cập nhật thông tin hóa đơn (`period`, `due_date`, `apartment_id`, `status`).
   - Xóa và chèn lại các hạng mục `invoice_items` trong cùng một transaction ACID.
   - Trả về JSON thông báo thành công.
   - `REVOKE ALL FROM anon, PUBLIC; GRANT EXECUTE TO authenticated;`.

2. **Đồng bộ RPC `book_amenity_slot`**:
   ```sql
   CREATE OR REPLACE FUNCTION public.book_amenity_slot(
       p_amenity_id UUID,
       p_booking_date DATE,
       p_time_slot VARCHAR,
       p_guests_count INT DEFAULT 1,
       p_apartment_id UUID DEFAULT NULL,
       p_allow_waitlist BOOLEAN DEFAULT TRUE,
       p_notes TEXT DEFAULT NULL
   )
   RETURNS JSONB
   LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = public, pg_catalog;
   ```
   - Nhận diện `p_apartment_id` nếu truyền lên, hoặc tự động tra cứu từ `residents_apartments` nếu để `NULL`.
   - Xử lý `p_allow_waitlist`: Khi khung giờ đã kín chỗ:
     - Nếu `p_allow_waitlist = true`: Tạo lượt đặt ở trạng thái `waitlist`.
     - Nếu `p_allow_waitlist = false`: Báo lỗi bằng `RAISE EXCEPTION 'Khung giờ này đã kín chỗ. Vui lòng chọn khung giờ khác.'`.
   - Kiểm tra trùng lặp khung giờ theo đúng quy định.

### 2.2. Hạng Mục 2: Chuẩn Hóa Quản Lý Hóa Đơn & Xử Lý Lỗi Repository
1. **[management_repository.dart](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/data/repositories/management_repository.dart)**:
   - Trong `updateInvoice`: Gọi RPC `update_invoice_with_items`.
   - Loại bỏ hoàn toàn khối `catch (_) { ... delete ... insert ... }`.
   - Nếu RPC gặp lỗi, bắt `PostgrestException` và ném ra thông báo tiếng Việt có nghĩa cho giao diện.
2. **[amenity_booking_repository.dart](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/data/repositories/amenity_booking_repository.dart)**:
   - Trong `getBookingsByAmenityAndDate`: Gọi trực tiếp truy vấn Supabase, không nuốt lỗi. Khi lỗi mạng hoặc lỗi RLS, rethrow để tầng Provider xử lý trạng thái `AsyncError`.
   - Trong `getMaintenanceWindows`: Tương tự, không dùng `catch (_) { return []; }`.

### 2.3. Hạng Mục 3: Chuẩn Hóa Logic Thống Kê Tài Chính Dashboard
Sửa [dashboard_providers.dart](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/data/providers/dashboard_providers.dart):
1. **Lớp dữ liệu `FinancialStats`**:
   - `paidTotal`: Doanh thu thực thu (`status == 'paid'`).
   - `unpaidTotal`: Tiền nợ còn phải thu (`status IN ('unpaid', 'overdue')`).
   - `pendingConfirmationTotal`: Tiền chờ BQL xác nhận (`status == 'pending_confirmation'`).
   - `cancelledTotal`: Tiền hóa đơn đã hủy (`status IN ('cancelled', 'void')`) — không tính vào nợ hay doanh thu.
   - `totalBilled`: Tổng tiền phát hành hợp lệ (`paidTotal + unpaidTotal + pendingConfirmationTotal`).
   - `actualRevenue`: Bằng `paidTotal`.
   - `collectionRate`: `totalBilled > 0 ? (paidTotal / totalBilled) : 0.0`.
2. **Phân loại trong `financialStatsProvider`**:
   - Vòng lặp `for (var inv in currentInvoices)` kiểm tra chính xác `status`:
     - `'paid'` $\rightarrow$ `paidTotal`, `paidApartments`.
     - `'unpaid'`, `'overdue'` $\rightarrow$ `unpaidTotal`, `unpaidApartments`.
     - `'pending_confirmation'` $\rightarrow$ `pendingConfirmationTotal`, `pendingApartments`.
     - Bỏ qua `'cancelled'`, `'void'`.
3. **Cập nhật `unpaidInvoicesTotalProvider`**:
   - Trả về `stats.unpaidTotal + stats.pendingConfirmationTotal`.

### 2.4. Hạng Mục 4: Đồng Bộ Giao Diện Thanh Toán & Phản Hồi Trực Quan
1. **[amenity_booking_screen.dart](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/features/resident/screens/amenity_booking_screen.dart)**:
   - Kiểm tra `totalFee > 0`:
     - Nếu `paymentRes != null && paymentRes.success`: Hiển thị dialog đặt thành công và return.
     - Nếu `paymentRes == null || !paymentRes.success`:
       - Hiển thị SnackBar màu cam cảnh báo: *"Lịch đặt đã được ghi nhận ở trạng thái Chờ thanh toán. Vui lòng liên hệ Ban Quản Lý để hoàn tất thanh toán trước giờ sử dụng."*
       - Không hiển thị SnackBar màu xanh *"Đặt lịch tiện ích thành công!"*.
2. **[resident_invoice_provider.dart](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/data/providers/resident_invoice_provider.dart)**:
   - Đổi `'p_category': 'INVOICE'` thành `'p_type': 'INVOICE'` cho đúng chữ ký của `simulate_unified_payment`.
3. **[unified_payment_sheet.dart](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/core/widgets/unified_payment_sheet.dart)**:
   - Khi giao dịch trả về lỗi (bao gồm lỗi có chủ đích `feature_not_supported`): Hiển thị rõ ràng thông báo lỗi từ backend và hướng dẫn cư dân nộp tiền trực tiếp tại BQL.

---

## 3. Kế Hoạch Kiểm Thử (Testing Strategy)

1. **Unit Test Migration Schema**:
   - Kiểm tra `20261011_03_harmonize_amenity_and_invoice_rpcs.sql` chứa đúng chữ ký của `book_amenity_slot` và `update_invoice_with_items`.
2. **Unit Test Dashboard Financial Stats**:
   - Kiểm tra `FinancialStats` tính đúng khi có hóa đơn `cancelled`, `void`, `pending_confirmation`, và không tính hóa đơn đã hủy vào nợ.
3. **Unit Test Repositories**:
   - Kiểm tra `AmenityBookingRepository` ném lỗi khi Supabase client throw exception.
   - Kiểm tra `ManagementRepository.updateInvoice` gọi đúng RPC và không xóa nhầm dữ liệu.
4. **Kiểm tra hồi quy toàn diện**:
   - `flutter analyze` $\rightarrow$ 0 lỗi (`No issues found!`).
   - `flutter test` $\rightarrow$ 100% tests pass.
