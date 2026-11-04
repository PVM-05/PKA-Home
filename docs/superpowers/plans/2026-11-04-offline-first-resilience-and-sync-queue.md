# Kế Hoạch Triển Khai F3: Hàng Đợi Đồng Bộ Ngoại Tuyến & Độ Tin Cậy Vận Hành (Offline-First Persistent Sync Queue & Resilience)

## Mục tiêu
Triển khai toàn bộ tính năng **F3: Offline-First & Resilience** giải quyết triệt để vấn đề mất sóng trong hầm gửi xe, thang máy và khu vực sóng yếu tại chung cư:
- Tầng Lưu Trữ & Hàng Đợi: Model `SyncActionModel`, `OfflineSyncQueueStorage` lưu trữ bền vững vào SharedPreferences.
- Tầng Quản Lý & Điều Phối: `OfflineSyncManager` xử lý hàng đợi FIFO, cơ chế Exponential Backoff, Idempotency Key, tự động đồng bộ khi có kết nối mạng.
- Tầng UI: `SyncStatusBar` hiển thị trạng thái ngoại tuyến/đồng bộ/thành công, tích hợp vào Dashboard BQL và Trang chủ Cư Dân.
- Kiểm thử: Đầy đủ unit và widget tests, 100% pass, 0 issues `dart analyze`.

---

## Chi Tiết Các Task Triển Khai

### Task 1: Model & Storage Hàng Đợi Bền Vững (Storage & Model Layer)
- **Tập tin:**
  - `lib/core/sync/sync_action_model.dart`
  - `lib/core/sync/offline_sync_queue_storage.dart`
  - `test/core/sync/offline_sync_queue_storage_test.dart`
- **Nội dung:**
  - Định nghĩa model `SyncActionModel` với các trạng thái (`pending`, `syncing`, `failed`, `completed`) kèm `toJson`/`fromJson`.
  - Triển khai `OfflineSyncQueueStorage` quản lý mảng hàng đợi persistent trong `SharedPreferences`.
  - Viết unit tests kiểm tra tính toàn vẹn của hàng đợi và persistence.
- **Cam kết:** Commit vào `main` với message `feat(sync): triển khai model và storage hàng đợi đồng bộ ngoại tuyến`.

### Task 2: Trình Quản Lý Đồng Bộ & Retry Backoff (Sync Manager Engine)
- **Tập tin:**
  - `lib/core/sync/offline_sync_manager.dart`
  - `lib/core/sync/sync_providers.dart`
  - `test/core/sync/offline_sync_manager_test.dart`
- **Nội dung:**
  - Xây dựng `OfflineSyncManager` lắng nghe trạng thái kết nối và xử lý hàng đợi theo thứ tự FIFO.
  - Triển khai cơ chế Exponential Backoff khi gặp lỗi mạng và Idempotency Key chống lặp.
  - Thiết lập các Riverpod providers theo dõi trạng thái `syncStateProvider` và `pendingSyncCountProvider`.
  - Viết unit tests kiểm tra xử lý đồng bộ, retry và fallback.
- **Cam kết:** Commit vào `main` với message `feat(sync): xây dựng offline sync manager với cơ chế retry backoff`.

### Task 3: Giao Diện Thanh Trạng Thái & Tích Hợp (UI & Integration)
- **Tập tin:**
  - `lib/core/widgets/sync_status_bar.dart`
  - Tích hợp vào `lib/features/management/screens/management_dashboard_screen.dart` hoặc `lib/features/resident/screens/resident_home_screen.dart`.
  - `test/core/widgets/sync_status_bar_test.dart`
- **Nội dung:**
  - Tạo widget `SyncStatusBar` với 3 trạng thái trực quan (Offline với số tác vụ chờ, Đang đồng bộ, Đồng bộ thành công).
  - Nút bấm thủ công "Đồng bộ ngay".
  - Viết widget tests kiểm tra giao diện thanh trạng thái.
- **Cam kết:** Commit vào `main` với message `feat(ui): tích hợp thanh trạng thái đồng bộ ngoại tuyến sync status bar`.

### Task 4: Nghiệm Thu F3, Phân Tích Tĩnh & Đồng Bộ Hệ Thống
- **Nội dung:**
  - Chạy toàn bộ test suites F3.
  - Chạy `dart analyze lib test` (0 issues).
  - Đánh dấu hoàn tất `[x]` Offline-First & Resilience trong `docs/COMMERCIAL_PRODUCT_ROADMAP.md`.
  - Cập nhật Knowledge Graph: `python -m graphify update .`.
  - Push toàn bộ commits lên GitHub remote `origin/main`.
- **Cam kết:** Commit vào `main` với message `feat(f3): hoàn tất nghiệm thu hàng đợi đồng bộ ngoại tuyến và cập nhật roadmap`.

