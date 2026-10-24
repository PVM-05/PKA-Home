# Nhật Ký Lỗi & Khắc Phục (Bug Log)

## 1. Huỷ phương tiện báo thành công nhưng UI chưa cập nhật (ĐÃ XỬ LÝ)
- **Mô tả lỗi**: Cư dân bấm hủy xe, nhận thông báo thành công nhưng trên màn hình vẫn hiển thị 1 xe đã hủy.
- **Nguyên nhân gốc rễ**:
  1. Thiếu `REPLICA IDENTITY FULL` trên bảng `public.vehicles` trong Supabase, khiến gói tin WAL khi `DELETE` chỉ chứa cột `id` mà không có `apartment_id`, dẫn tới filter `.eq('apartment_id', apartmentId)` của Supabase Realtime Stream bỏ qua sự kiện xóa.
  2. Ở tầng Flutter, sau khi gọi `deleteVehicle`, chưa chủ động làm mới (`ref.invalidate`) các provider `apartmentVehiclesProvider`, `apartmentVehicleCountsProvider` và `residentVehiclesProvider`.
- **Giải pháp xử lý**:
  1. Thêm migration `20261005_01_vehicles_replica_identity_full.sql` bật `REPLICA IDENTITY FULL` trên bảng `vehicles`.
  2. Bổ sung `ref.invalidate(...)` ngay sau khi đăng ký hoặc hủy xe thành công trong `vehicle_management_screen.dart`.
  3. Bổ sung `RefreshIndicator` hỗ trợ vuốt kéo làm mới danh sách xe.
- **Trạng thái**: Đã sửa và kiểm thử PASS 100%.

## 2. Realtime WebSocket 1002 close event & Cơ chế Fallback HTTP (ĐÃ XỬ LÝ)
- **Mô tả lỗi**: Màn hình Dashboard BQL thỉnh thoảng mất kết nối Realtime khi chuyển đổi liên tục giữa các tab hoặc mạng không ổn định, nhận mã lỗi WebSocket 1002.
- **Nguyên nhân**: Kênh kết nối WebSocket của Supabase Realtime bị ngắt đột ngột khi thiết bị ngủ hoặc mạng chập chờn, khiến StreamProvider bị kẹt ở trạng thái Error.
- **Giải pháp xử lý**:
  1. Xây dựng tiện ích `NetworkErrorHandler` bọc các lời gọi mạng.
  2. Triển khai cơ chế Resilience: Nếu Stream Realtime báo lỗi, tự động chuyển đổi sang HTTP Polling định kỳ và tự động tái kết nối Realtime khi đường truyền mạng sẵn sàng.
- **Trạng thái**: Đã xử lý và kiểm thử PASS 100%.

## 3. Lỗi RPC `generate_valid_bulk_invoices` không tương thích tham số (ĐÃ XỬ LÝ)
- **Mô tả lỗi**: Khi Ban quản lý chọn lọc danh sách căn hộ cụ thể để phát hành hóa đơn, lời gọi RPC thất bại với lỗi `function generate_valid_bulk_invoices(...) does not exist`.
- **Nguyên nhân**: Migration trước đó nạp chồng chữ ký hàm chỉ nhận `p_period DATE, p_due_date DATE, p_notes TEXT` mà bỏ sót tham số mảng `p_target_apartment_ids UUID[] DEFAULT NULL`.
- **Giải pháp xử lý**:
  1. Hợp nhất vào `supabase/migrations/20261024_01_system_audit_consolidation.sql` với chữ ký chuẩn đầy đủ `(p_period DATE, p_due_date DATE, p_notes TEXT, p_target_apartment_ids UUID[] DEFAULT NULL)`.
  2. Bổ sung kiểm tra quyền quản trị/kế toán `is_admin_or_accountant()`.
- **Trạng thái**: Đã hợp nhất và kiểm thử PASS 100%.

## 4. Vi phạm Enum `invoice_status` khi tạo hóa đơn (`'pending'` vs `'unpaid'`) (ĐÃ XỬ LÝ)
- **Mô tả lỗi**: Lời gọi `approve_meter_reading` hoặc `create_invoice_with_items` ném ngoại lệ CSDL `invalid input value for enum invoice_status: "pending"`.
- **Nguyên nhân**: Migration cũ `20261010_01` gán `status = 'pending'`, trong khi kiểu enum `public.invoice_status` của PostgreSQL chỉ chấp nhận 3 giá trị: `'unpaid'`, `'pending_confirmation'`, `'paid'`.
- **Giải pháp xử lý**:
  1. Sửa toàn bộ các hàm RPC liên quan sang khởi tạo trạng thái chuẩn `'unpaid'`.
  2. Cập nhật trong migration hợp nhất `20261024_01_system_audit_consolidation.sql`.
- **Trạng thái**: Đã sửa và kiểm thử PASS 100%.

## 5. Quyền hạn role `'management'` và cột `booked_by` trong `simulate_unified_payment` (ĐÃ XỬ LÝ)
- **Mô tả lỗi**: Cư dân thanh toán tiền cọc tiện ích hoặc thanh toán hóa đơn bị lỗi `column v_booking.total_fee does not exist` hoặc kiểm tra quyền BQL bị từ chối với tài khoản `management`.
- **Nguyên nhân**: Bảng `amenity_bookings` lưu người đặt là `booked_by` (không phải `user_id`), và cột phí là `fee_amount` + `deposit_amount` (không phải `total_fee`). Kiểm tra quyền trước đó chỉ so sánh `role = 'admin'` thay vì `role = 'management'`.
- **Giải pháp xử lý**:
  1. Chuẩn hóa hàm `simulate_unified_payment` trong migration hợp nhất: kiểm tra role `'management'`, trích xuất đúng cột `booked_by`, `fee_amount`, `deposit_amount`.
  2. Hỗ trợ đầy đủ luồng xác nhận 2 bước cho chuyển khoản ngân hàng (`is_pending: true`).
- **Trạng thái**: Đã hợp nhất và kiểm thử PASS 100%.

## 6. Tính toán sai sức chứa tiện ích dùng chung (`SUM(guests_count)`) (ĐÃ XỬ LÝ)
- **Mô tả lỗi**: Tiện ích dùng chung (shared) như Bể bơi/Gym cho phép quá số người tối đa hoặc từ chối đặt khi vẫn còn chỗ.
- **Nguyên nhân**: Hàm `book_amenity_slot` cũ dùng `COUNT(*)` để đếm số bản ghi đặt chỗ thay vì tính tổng số người tham gia `COALESCE(SUM(guests_count), 0)`.
- **Giải pháp xử lý**:
  1. Cập nhật thuật toán tính tải: `v_current_guests + p_guests_count > v_amenity.max_capacity`.
  2. Cho phép người dùng chọn số lượng khách đi cùng (`dialogGuestsCount`) trên giao diện và tính phí/cọc chính xác.
- **Trạng thái**: Đã sửa và kiểm thử PASS 100%.

## 7. Rò rỉ bộ nhớ FocusNode trong `OtpInputBoxes` (ĐÃ XỬ LÝ)
- **Mô tả lỗi**: Màn hình nhập OTP quên mật khẩu bị văng ứng dụng khi bàn phím ảo hiển thị lại hoặc rebuild với assertion: `_focusNodes.length == widget.length`.
- **Nguyên nhân**: Trong `build()`, code khởi tạo `focusNode: FocusNode()` tạm thời trực tiếp trên cây widget khiến các node không được dispose và tái tạo vô hạn.
- **Giải pháp xử lý**:
  1. Khởi tạo danh sách `List<FocusNode> _keyboardFocusNodes` trong `initState()`.
  2. Gắn kết persistent FocusNode và giải phóng toàn bộ trong `dispose()`.
- **Trạng thái**: Đã sửa và kiểm thử PASS 100%.

## 8. Lỗi cú pháp XML trong file iOS `Info.plist` (ĐÃ XỬ LÝ)
- **Mô tả lỗi**: Xcode / iOS runner báo lỗi cú pháp XML `unclosed tag <array>` ở dòng 46.
- **Nguyên nhân**: Khối cấu hình xoay màn hình iPad `<key>UISupportedInterfaceOrientations~ipad</key>` bị thiếu thẻ đóng `</array>`.
- **Giải pháp xử lý**: Bổ sung thẻ `</array>` hợp lệ vào `ios/Runner/Info.plist`.
- **Trạng thái**: Đã sửa và kiểm thử PASS 100%.

## 9. Dữ liệu Seeding xe máy vượt hạn mức & Bỏ qua trigger (ĐÃ XỬ LÝ)
- **Mô tả lỗi**: File `supabase/seed.sql` chứa 57KB bản ghi xe trùng lặp biển số và phải sử dụng lệnh nguy hiểm `DISABLE TRIGGER trg_check_vehicle_limits;`.
- **Nguyên nhân**: Lệnh insert lặp vòng nhiều lần mà không kiểm soát biển số độc nhất và số lượng xe trên mỗi căn hộ.
- **Giải pháp xử lý**:
  1. Viết script rút gọn và tái tạo toàn bộ 40 phương tiện mẫu hợp lệ (28 xe máy, 12 ô tô) với biển số chuẩn duy nhất.
  2. Đảm bảo mỗi căn hộ không quá 2 xe máy và 1 ô tô.
  3. Gỡ bỏ hoàn toàn việc vô hiệu hóa trigger, đảm bảo toàn vẹn dữ liệu.
- **Trạng thái**: Đã xử lý và kiểm thử PASS 100%.

## 10. Nguy cơ lộ bí mật môi trường do đưa `.env` vào Assets (ĐÃ XỬ LÝ)
- **Mô tả lỗi**: File `.env` được khai báo dưới mục `assets:` trong `pubspec.yaml`, dẫn đến nguy cơ đóng gói secrets vào gói cài đặt IPA/APK.
- **Nguyên nhân**: Cấu hình mẫu ban đầu vô tình thêm đường dẫn `- .env`.
- **Giải pháp xử lý**: Loại bỏ `- .env` khỏi `pubspec.yaml`. Ứng dụng đọc cấu hình qua file `app_constants.dart` an toàn.
- **Trạng thái**: Đã loại bỏ và kiểm thử PASS 100%.

