# Thiết kế RLS Policy (Row Level Security)

Để đảm bảo an toàn dữ liệu, toàn bộ các bảng trong Supabase sẽ được bật RLS. Dưới đây là các chính sách (Policy) chi tiết:

## 1. Bảng `users`
- **SELECT**: Người dùng được phép đọc thông tin của chính mình (chỉ dòng có `id = auth.uid()`). Ban quản lý được xem toàn bộ.
- **INSERT**: Tạo qua Supabase Auth trigger khi người dùng đăng ký.
- **DELETE**: Chỉ Ban quản lý mới được quyền xóa tài khoản.
- **UPDATE**: 
  - Ban quản lý có toàn quyền cập nhật (phân công vai trò, khóa tài khoản...).
  - Cư dân được phép cập nhật thông tin cá nhân (`full_name`, `phone`) nhưng **tuyệt đối không được phép sửa `role`**.
  - **Cơ chế phòng thủ 3 lớp (Defense-in-Depth) chống Leo thang đặc quyền (Privilege Escalation):**
    1. **Trigger cấp CSDL (`trg_prevent_role_self_escalation`)**: Bắt sự kiện `BEFORE UPDATE`, ném ngoại lệ nếu `role` bị thay đổi bởi bất kỳ ai không phải Management (chặn đứng mọi nỗ lực can thiệp kể cả khi vượt qua được RLS).
    2. **RLS WITH CHECK**: Policy UPDATE ràng buộc chặt chẽ `WITH CHECK (auth.uid() = id AND role = (SELECT role FROM users WHERE id = auth.uid()))`, từ chối câu lệnh UPDATE nếu payload chứa role khác.
    3. **RPC Function an toàn (`update_own_profile`)**: Đóng gói cập nhật hồ sơ với `SECURITY DEFINER`, chỉ nhận 2 tham số `p_full_name` và `p_phone`, loại bỏ hoàn toàn khả năng can thiệp cột `role` từ phía Client.

## 2. Bảng `apartments`
- **SELECT**: Cư dân được xem thông tin căn hộ của mình (dựa vào JOIN với bảng `residents_apartments`). Ban quản lý xem được toàn bộ.
- **INSERT/UPDATE/DELETE**: Cấm cư dân. Chỉ Ban quản lý mới được quyền.

## 3. Bảng `residents_apartments`
- **SELECT**: Cư dân chỉ xem được bản ghi có `user_id = auth.uid()`. Ban quản lý xem được toàn bộ.
- **INSERT/UPDATE/DELETE**: Chỉ Ban quản lý được quyền gắn hoặc gỡ bỏ cư dân khỏi căn hộ.

## 4. Bảng `invoices` và `invoice_items`
- **SELECT**: Cư dân chỉ được đọc hóa đơn thuộc `apartment_id` mà họ đang ở. Ban quản lý đọc toàn bộ.
- **UPDATE**: Cư dân chỉ được quyền cập nhật `status` từ `unpaid` sang `pending_confirmation`. Ban quản lý được quyền cập nhật mọi `status`.
- **INSERT/DELETE**: Chỉ Ban quản lý được lập hoặc xóa hóa đơn.

## 5. Bảng `issue_reports`
- **SELECT**: Cư dân đọc được các phản ánh có `reporter_id = auth.uid()` hoặc thuộc `apartment_id` của họ. BQL đọc toàn bộ.
- **INSERT**: Cư dân được phép tạo phản ánh mới (`reporter_id` bắt buộc phải là `auth.uid()`).
- **UPDATE**: Cư dân không được tự ý sửa nội dung phản ánh sau khi gửi. Ban quản lý được cập nhật `status` và `assigned_staff_id`.
- **DELETE**: Không ai được xóa (Soft delete hoặc giữ lại làm lịch sử).

## 6. Bảng `announcements`
- **SELECT**: Mọi tài khoản đã đăng nhập đều có quyền đọc.
- **INSERT/UPDATE/DELETE**: Chỉ Ban quản lý được quyền đăng hoặc chỉnh sửa thông báo.

## 7. Storage Bucket `issue-images`
- **INSERT (Upload)**: Mọi người dùng đã xác thực (`authenticated`) đều có thể tải ảnh lên đính kèm báo cáo sự cố (định dạng `/<uid>/...` hoặc `/<issue_report_id>/...`).
- **SELECT (Download)**: Giới hạn người dùng đã đăng nhập (`authenticated`), bao gồm cư dân trong tòa nhà và Ban quản lý/kỹ thuật viên xử lý sự cố.

## 8. Bảng `vehicles`
- **SELECT**: Cư dân chỉ xem các phương tiện thuộc căn hộ của mình (dựa vào `residents_apartments`). Ban quản lý xem được toàn bộ danh sách xe.
- **INSERT**: Cư dân được phép đăng ký thêm xe vào căn hộ mình đang ở (tuân thủ giới hạn tối đa 2 xe máy, 1 ô tô qua trigger).
- **UPDATE**: Cư dân chỉ được chỉnh sửa hoặc nộp lại thông tin khi trạng thái là `pending` hoặc `rejected`. Ban quản lý có quyền duyệt (`approved`) hoặc từ chối (`rejected`) kèm lý do (`rejection_reason`).
- **DELETE**: Cư dân được xóa xe ở trạng thái chờ duyệt hoặc từ chối. Ban quản lý có quyền xóa toàn bộ.

## 9. Bảng `payment_transactions`
- **SELECT**: Cư dân xem lịch sử giao dịch thanh toán thuộc căn hộ của mình. Ban quản lý và kế toán xem toàn bộ.
- **INSERT/UPDATE**: Khởi tạo và cập nhật qua các hàm an toàn `simulate_unified_payment` (RPC) hoặc `record_manual_payment` (BQL). Trực tiếp qua REST API bị hạn chế nghiêm ngặt bởi RLS.

## 10. Bảng `building_amenities` & `amenity_bookings`
- **`building_amenities`**: Mọi người dùng `authenticated` đều có quyền xem danh sách tiện ích, biểu phí và khung giờ hoạt động (`SELECT`). Chỉ Ban quản lý có quyền thêm/sửa/xóa (`INSERT/UPDATE/DELETE`).
- **`amenity_bookings`**:
  - **SELECT**: Cư dân chỉ xem lịch sử đặt chỗ của chính mình hoặc của căn hộ mình. Ban quản lý xem toàn bộ lịch sử sử dụng tiện ích của tòa nhà.
  - **INSERT**: Cư dân đăng ký đặt chỗ qua RPC an toàn `book_amenity_slot` (kiểm tra trùng lịch, giới hạn sức chứa và khung bảo trì).
  - **UPDATE**: Cư dân chỉ được hủy lịch đặt (`status = 'cancelled'`) của chính mình trước giờ bắt đầu. Ban quản lý có quyền cập nhật trạng thái nhận/hoàn tiền cọc (`deposit_status`) hoặc check-in.

## 11. Bảng `user_fcm_tokens`
- **SELECT/INSERT/UPDATE**: Ràng buộc `user_id = auth.uid()`. Mỗi người dùng chỉ được quản lý token thiết bị của chính mình để nhận thông báo đẩy qua Firebase Cloud Messaging (FCM).

---

## Danh Sách Kịch Bản Kiểm Thử RLS (Test Cases)

| Mã Case | Mô tả kiểm thử | Kỳ vọng kết quả | Bằng chứng mã kiểm thử |
| :--- | :--- | :--- | :--- |
| **RLS-01** | Cư dân đọc danh sách hóa đơn | Chỉ trả về hóa đơn thuộc căn hộ của chính mình, không thấy hóa đơn căn khác | `test/integration/rls_security_test.dart` |
| **RLS-02** | Cư dân đọc chi tiết khoản phí (`invoice_items`) | Chỉ thấy các mục phí liên kết với hóa đơn căn hộ mình | `test/integration/rls_security_test.dart` |
| **RLS-03** | Cư dân cố tình đổi `invoices.status = 'paid'` qua REST API | Bị chặn, ném lỗi hoặc không cập nhật bản ghi | `test/integration/rls_security_test.dart` |
| **RLS-04** | Cư dân đọc phản ánh sự cố (`issue_reports`) | Chỉ thấy các phản ánh do mình tạo hoặc thuộc căn hộ mình | `test/integration/rls_security_test.dart` |
| **RLS-05** | **Cư dân cố tình nâng quyền `users.role = 'management'` qua REST API** | **Trigger & RLS chặn đứng, ném ngoại lệ, role không đổi** | `test/integration/rls_security_test.dart` |

