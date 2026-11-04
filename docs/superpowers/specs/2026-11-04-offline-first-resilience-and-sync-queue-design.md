# Thiết Kế Chi Tiết F3: Hàng Đợi Đồng Bộ Ngoại Tuyến & Độ Tin Cậy Vận Hành (Offline-First Persistent Sync Queue & Resilience)

## 1. Bối cảnh & Mục tiêu Nghiệp Vụ
Tại các tòa nhà chung cư thương mại, nhân viên ban quản lý và cư dân thường xuyên phải thao tác ứng dụng trong các môi trường không có sóng di động hoặc wifi chập chờn:
- Tầng hầm giữ xe B1, B2, B3 (ghi nhận thẻ xe, check-in phương tiện, kiểm tra bưu kiện).
- Thang máy, hộp kỹ thuật, phòng máy phát điện, bể ngầm (kỹ thuật viên xử lý sự cố, ghi nhận chỉ số công tơ điện nước).
- Cư dân sinh sống tại các góc khuất tòa nhà khi phát hiện sự cố khẩn cấp.

Nếu ứng dụng chỉ hoạt động theo mô hình Online-Only, các thao tác nghiệp vụ sẽ bị lỗi ngay lập tức (`SocketException`, `TimeoutException`) và dữ liệu người dùng vừa nhập bị mất trắng, gây gián đoạn vận hành nghiêm trọng.

**Mục tiêu của Giai đoạn F3 (Offline-First & Resilience):**
1. **Lưu trữ Hàng Đợi Cục Bộ Bền Vững (Persistent FIFO Sync Queue):** Mọi thao tác ghi dữ liệu (mutations) khi mất mạng đều được serialize và lưu trữ bền vững vào `SharedPreferences`, bảo toàn 100% dữ liệu ngay cả khi ứng dụng bị tắt nguồn hoặc khởi động lại.
2. **Cơ Chế Tự Động Đồng Bộ & Exponential Backoff:** Khi mạng kết nối trở lại, hệ thống tự động xử lý hàng đợi theo thứ tự thời gian phát sinh (FIFO), có khóa Idempotency Key chống gửi trùng lặp, tự động thử lại với độ trễ lũy thừa ($2^n$ giây) nếu gặp lỗi mạng tạm thời.
3. **Trải Nghiệm Người Dùng Minh Bạch (Transparent UI Feedback):** Cung cấp thanh trạng thái `SyncStatusBar` trực quan thông báo trạng thái ngoại tuyến, số tác vụ chờ gửi và nút bấm "Đồng bộ ngay" (Manual Sync Now).

---

## 2. Kiến Trúc Kỹ Thuật

### 2.1. Cấu Trúc Dữ Liệu `SyncActionModel`
```dart
enum SyncStatus { pending, syncing, failed, completed }

class SyncActionModel {
  final String id;              // UUID duy nhất của action
  final String actionType;      // vd: create_issue, log_meter, dunning_action
  final String endpoint;        // RPC hoặc bảng Supabase
  final Map<String, dynamic> payload; // Tham số dữ liệu nghiệp vụ
  final DateTime createdAt;     // Thời điểm phát sinh offline
  final int retryCount;         // Số lần đã thử lại
  final SyncStatus status;      // Trạng thái hiện tại
  final String? lastError;      // Thông báo lỗi nếu có
  final String idempotencyKey;  // Khóa chống lặp dữ liệu trên server
}
```

### 2.2. Tầng Lưu Trữ Hàng Đợi (`OfflineSyncQueueStorage`)
- Sử dụng key `pka_home_offline_sync_queue` trong `SharedPreferences`.
- Cung cấp các thao tác CRUD an toàn trên hàng đợi với cơ chế ghi atomic.
- Tự động dọn dẹp các tác vụ đã hoàn tất (`completed`) để tối ưu dung lượng lưu trữ cục bộ.

### 2.3. Trình Quản Lý Đồng Bộ (`OfflineSyncManager`)
- **Quản lý trạng thái kết nối:** Trạng thái online/offline, cờ đang đồng bộ (`isSyncing`), số lượng tác vụ đang chờ (`pendingCount`).
- **Xử lý Hàng Đợi (Queue Processor):**
  - Duyệt các phần tử có `status == pending || status == failed` theo thứ tự `createdAt` (FIFO).
  - Định tuyến theo `actionType`:
    + `create_issue`: Gửi RPC hoặc chèn vào bảng `issue_reports`.
    + `dunning_action`: Gửi RPC `execute_dunning_action`.
    + `log_meter_reading`: Gửi RPC `record_meter_reading`.
    + `submit_poll_vote`: Gửi RPC `submit_poll_vote`.
  - Nếu kết quả thành công: Đánh dấu `completed` và xóa khỏi hàng đợi.
  - Nếu thất bại do kết nối mạng: Giữ nguyên trong hàng đợi, tăng `retryCount`, tính toán thời gian chờ Backoff $\min(60, 2^{\text{retryCount}})$ giây.
  - Nếu thất bại do logic nghiệp vụ (4xx): Đánh dấu `failed`, ghi nhận `lastError` để báo cáo người dùng.

### 2.4. Giao Diện Người Dùng (`SyncStatusBar`)
- Widget thông minh gắn ở đầu màn hình Dashboard Ban Quản Lý và Trang chủ Cư Dân:
  - Khi Offline: Nền màu cam hổ phách, icon `cloud_off_rounded`, hiển thị *"Đang ngoại tuyến (Offline) - Đã lưu X tác vụ chờ đồng bộ"* kèm nút *"Đồng bộ ngay"*.
  - Khi Đang đồng bộ: Nền màu xanh dương nhẹ, CircularProgressIndicator nhỏ xoay đều, hiển thị *"Đang đồng bộ X tác vụ lên máy chủ..."*.
  - Khi Đồng bộ thành công: Nền màu xanh ngọc, icon `check_circle_rounded`, hiển thị *"Đã đồng bộ toàn bộ dữ liệu thành công"* (tự ẩn sau 3 giây).

---

## 3. Kế Hoạch Kiểm Thử
1. **Kiểm thử Storage:** `test/core/sync/offline_sync_queue_storage_test.dart` xác minh serialize/deserialize, enqueue, dequeue, update và persistence.
2. **Kiểm thử Engine:** `test/core/sync/offline_sync_manager_test.dart` xác minh cơ chế FIFO, tự động đồng bộ khi online, retry backoff khi mất mạng, xử lý idempotent.
3. **Kiểm thử Giao diện:** `test/core/widgets/sync_status_bar_test.dart` xác minh hiển thị đúng 3 trạng thái (offline, syncing, success) và kích hoạt hành động "Đồng bộ ngay".

