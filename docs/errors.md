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
