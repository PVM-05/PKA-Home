# Kế Hoạch Triển Khai: Đấu Nối Supabase Production & Loại Bỏ Mock RAM (Zero-Mock)

> **Mục tiêu:** Chuyển đổi 5 Repository trọng yếu (`ParkingRepository`, `MaterialRepository`, `FrontDeskRepository`, `CommunityRepository`, `DebtPredictionRepository`) từ lưu trữ giả lập trong bộ nhớ RAM sang lưu trữ vĩnh viễn trên 58 bảng và Stored Functions của Supabase Production.

---

## Danh Sách Các Task Thực Thi

### Task 1: Chuyển đổi ParkingRepository sang Supabase Cloud Thật
* **Files:**
  * `lib/data/repositories/parking_repository.dart`
  * `test/data/repositories/parking_repository_test.dart`
* **Nội dung:**
  * Xóa bỏ các biến lưu tạm `_inMemorySlots` và `_inMemoryTickets`.
  * Thay thế các câu lệnh đọc/ghi sang bảng `parking_slots` và `visitor_parking_tickets` của Supabase.
  * Trong `fetchSlots`: Lấy danh sách ô xe thực tế từ Supabase theo `building_id`, phân tầng `floor` và `slot_number`.
  * Trong `assignSlot` và `releaseSlot`: Cập nhật trực tiếp `is_occupied` và `vehicle_id` trên CSDL.
  * Cập nhật unit test để xác minh logic.
* **Xác minh:** Chạy `flutter test test/data/repositories/parking_repository_test.dart` đạt 100% pass.

---

### Task 2: Chuyển đổi MaterialRepository & Thống kê SLA Sự cố Thật
* **Files:**
  * `lib/data/repositories/material_repository.dart`
  * `test/data/repositories/material_repository_test.dart`
* **Nội dung:**
  * Xóa bỏ các biến `_inMemoryMaterials` và `_inMemoryIssueMaterials`.
  * Truy vấn danh mục vật tư thực tế từ bảng `maintenance_materials`.
  * Cập nhật xuất kho `useMaterialForIssue`: Giảm `stock_quantity` trong bảng `maintenance_materials` và thêm bản ghi vào `issue_materials`.
  * Thay thế hàm `fetchSlaStats`: Tính toán số lượng sự cố, sự cố đúng hạn/trễ hạn và tỉ lệ hoàn thành trực tiếp từ bảng `issue_reports` của tòa nhà, xóa bỏ con số giả lập 12 sự cố / 91.7%.
* **Xác minh:** Chạy `flutter test test/data/repositories/material_repository_test.dart` đạt 100% pass.

---

### Task 3: Chuyển đổi FrontDeskRepository sang RPCs và Bảng Lễ tân Thật
* **Files:**
  * `lib/data/repositories/front_desk_repository.dart`
  * `test/data/repositories/front_desk_repository_test.dart`
* **Nội dung:**
  * Xóa bỏ `_mockPasses` và `_mockParcels`.
  * Đấu nối `fetchVisitorPasses` và `createVisitorPass` vào bảng `visitor_access_passes`.
  * Đấu nối `checkInVisitor` và `checkOutVisitor` vào RPCs `check_in_visitor_pass` và `check_out_visitor_pass`.
  * Đấu nối `fetchParcels`, `receiveParcel` vào bảng `parcels`.
  * Đấu nối `collectParcel` vào RPC `collect_parcel` để kiểm tra mã PIN 6 số.
  * Đấu nối `fetchFrontDeskStats` vào RPC `get_front_desk_stats`.
* **Xác minh:** Chạy `flutter test test/data/repositories/front_desk_repository_test.dart` đạt 100% pass.

---

### Task 4: Chuyển đổi CommunityRepository sang Biểu Quyết & Kiến Nghị CSDL Thật
* **Files:**
  * `lib/data/repositories/community_repository.dart`
  * `test/data/repositories/community_repository_test.dart`
* **Nội dung:**
  * Xóa bỏ `_mockVotedApartments` và `_mockEndorsedApartments` trong RAM.
  * Đọc khảo sát từ bảng `polls` và `poll_options`.
  * Ghi nhận phiếu biểu quyết qua RPC `submit_poll_vote` (tuân thủ Điều 102 Luật Nhà ở 2023).
  * Đọc và tạo kiến nghị trên bảng `resident_petitions`.
  * Ký kiến nghị qua RPC `endorse_petition`.
* **Xác minh:** Chạy `flutter test test/data/repositories/community_repository_test.dart` đạt 100% pass.

---

### Task 5: Chuyển đổi DebtPredictionRepository sang Radar Rủi ro Thật
* **Files:**
  * `lib/data/repositories/debt_prediction_repository.dart`
  * `test/data/repositories/debt_prediction_repository_test.dart`
* **Nội dung:**
  * Xóa bỏ mảng `_mockApartmentsSeed` và `_offlineDunningActions`.
  * Gọi RPC `get_building_debt_radar` từ Supabase để lấy số liệu tuổi nợ thật.
  * Gọi RPC `calculate_apartment_debt_risk` để tính điểm rủi ro thật.
  * Lưu vết đôn đốc vào bảng `dunning_actions`.
* **Xác minh:** Chạy `flutter test test/data/repositories/debt_prediction_repository_test.dart` đạt 100% pass.

---

### Task 6: Kiểm thử Toàn diện & Xác thực Trực tiếp trên Cloud
* **Files:** Toàn bộ dự án
* **Nội dung:**
  * Chạy `dart analyze lib test` đảm bảo 0 issues.
  * Chạy kiểm thử tự động toàn diện `flutter test`.
  * Chạy script Python kiểm tra truy vấn đọc/ghi mẫu vào các bảng trên Supabase cloud để xác nhận tính nhất quán và quyền RLS.
  * Commit và push lên nhánh `main`.

