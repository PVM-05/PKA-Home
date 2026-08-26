# Thiết kế RLS Policy (Row Level Security)

Để đảm bảo an toàn dữ liệu, toàn bộ các bảng trong Supabase sẽ được bật RLS. Dưới đây là các chính sách (Policy) chi tiết:

## 1. Bảng `users`
- **SELECT**: Người dùng được phép đọc thông tin của chính mình (chỉ dòng có `id = auth.uid()`). Ban quản lý được xem toàn bộ.
- **INSERT/UPDATE/DELETE**: Chỉ Ban quản lý mới được thêm hoặc cập nhật dữ liệu.

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
- **INSERT (Upload)**: Mọi người dùng đã đăng nhập đều có thể tải ảnh lên. Tên file buộc phải nằm trong thư mục có định dạng trùng với mã định danh của họ (VD: `/<uid>/...`).
- **SELECT (Download)**: Công khai cho bất kỳ ai có đường dẫn (vì ảnh báo lỗi thường không quá nhạy cảm, hoặc có thể giới hạn chỉ người báo lỗi và BQL được xem).
