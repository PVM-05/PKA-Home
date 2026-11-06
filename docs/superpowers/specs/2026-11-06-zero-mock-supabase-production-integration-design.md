# Thiết kế Kỹ thuật: Đấu nối Supabase Production & Loại bỏ Hoàn toàn Dữ liệu Mock RAM (Zero-Mock)

**Mã tài liệu:** SPEC-20261106-ZERO-MOCK-PROD  
**Ngày lập:** 06/11/2026  
**Trạng thái:** Đã phê duyệt (Approved)  
**Phạm vi:** `lib/data/repositories/` (`parking_repository.dart`, `material_repository.dart`, `front_desk_repository.dart`, `community_repository.dart`, `debt_prediction_repository.dart`)  

---

## 1. Bối cảnh & Mục tiêu (Context & Objectives)

Sau khi hoàn tất thành công việc áp dụng 28 bản ghi migration lên cơ sở dữ liệu Supabase Production (tạo lập đầy đủ 58 bảng và hệ thống Stored Procedures/RPCs bảo mật), hạ tầng backend của hệ thống PKA-Home đã sẵn sàng 100%.

Tuy nhiên, trong mã nguồn Flutter của tầng Repository, 5 module nghiệp vụ quan trọng vẫn đang chứa các biến lưu tạm trong bộ nhớ RAM (`_inMemorySlots`, `_inMemoryMaterials`, `_mockPasses`, `_mockParcels`, `_mockApartmentsSeed`, v.v.). Điều này dẫn đến tình trạng:
1. Khi tắt ứng dụng hoặc chạy trên thiết bị khác, dữ liệu bị đưa về mặc định ban đầu.
2. Dữ liệu thực tế phát sinh không được lưu trữ vĩnh viễn trên Cloud.
3. Không đồng bộ trạng thái giữa các vai trò (Ban Quản Lý, Cư dân, Kỹ thuật viên, Lễ tân).

**Mục tiêu cốt lõi của tài liệu này:**
* Loại bỏ 100% các biến lưu tạm trong RAM khỏi 5 Repository production.
* Đấu nối trực tiếp tất cả các phương thức CRUD và báo cáo vào các bảng và RPCs tương ứng trên Supabase.
* Đảm bảo nguyên tắc bảo mật **Fail-Closed**: Trong môi trường Production (mặc định), nếu có lỗi mạng hoặc lỗi CSDL thì quăng `AppException` có thông điệp thân thiện và UI hiển thị trạng thái kèm nút "Thử lại", tuyệt đối không âm thầm trả dữ liệu giả lập.
* Duy trì 100% tính tương thích ngược với các Widget và Riverpod Providers hiện tại.

---

## 2. Kiến trúc & Ma trận Ánh xạ Repository - Supabase

| Module Nghiệp vụ | Repository Class | Bảng Supabase Tương Ứng | Stored Functions / RPCs | Dữ liệu RAM Bị Loại Bỏ |
| :--- | :--- | :--- | :--- | :--- |
| **Bãi đỗ xe** | `ParkingRepository` | `parking_slots`, `visitor_parking_tickets`, `vehicles` | N/A (Trực tiếp bảng qua RLS) | `_inMemorySlots` (50 ô xe ảo), `_inMemoryTickets` |
| **Vật tư & SLA** | `MaterialRepository` | `maintenance_materials`, `issue_materials`, `issue_reports` | Truy vấn tính SLA trực tiếp | `_inMemoryMaterials`, `_inMemoryIssueMaterials`, SLA hardcode |
| **Lễ tân & Bưu kiện** | `FrontDeskRepository` | `visitor_access_passes`, `parcels`, `apartments` | `check_in_visitor_pass`, `check_out_visitor_pass`, `collect_parcel`, `get_front_desk_stats` | `_mockPasses`, `_mockParcels` |
| **Biểu quyết & Kiến nghị**| `CommunityRepository` | `polls`, `poll_options`, `poll_votes`, `resident_petitions`, `petition_endorsements` | `submit_poll_vote`, `endorse_petition` | `_mockVotedApartments`, `_mockEndorsedApartments` |
| **Radar Rủi ro Công nợ** | `DebtPredictionRepository` | `debt_risk_scores`, `dunning_actions` | `get_building_debt_radar`, `calculate_apartment_debt_risk`, `execute_dunning_action` | `_mockApartmentsSeed`, `_offlineDunningActions` |

---

## 3. Đặc tả Chi tiết Từng Module

### 3.1. Quản lý Bãi đỗ xe (`ParkingRepository`)
* **Truy vấn danh sách ô đỗ (`fetchSlots`):**
  * Đọc từ bảng `parking_slots` theo `building_id`, sắp xếp theo `floor`, `slot_number`.
  * Hỗ trợ bộ lọc tầng (`floor`) và loại phương tiện (`vehicle_type`).
* **Cập nhật phân bổ ô đỗ (`assignSlot`, `releaseSlot`):**
  * `assignSlot`: Cập nhật `is_occupied = true`, gán `vehicle_id` và `updated_at = now()`.
  * `releaseSlot`: Cập nhật `is_occupied = false`, gán `vehicle_id = null`.
* **Vé đỗ xe vãng lai (`createVisitorTicket`, `fetchActiveVisitorTickets`, `checkoutVisitorTicket`):**
  * Ghi và cập nhật trực tiếp vào bảng `visitor_parking_tickets`.

### 3.2. Vật tư Bảo trì & Thống kê SLA (`MaterialRepository`)
* **Danh mục vật tư (`fetchMaterials`):**
  * Truy vấn bảng `maintenance_materials` sắp xếp theo tên. Đã có sẵn 10 bản ghi danh mục mẫu (Aptomat, Đèn LED, Van nước...).
* **Xuất kho vật tư cho sự cố (`useMaterialForIssue`):**
  * Giảm `stock_quantity` trong bảng `maintenance_materials`.
  * Thêm bản ghi lịch sử vào `issue_materials` (gồm `issue_report_id`, `material_id`, `quantity_used`, `cost_per_unit`).
* **Thống kê SLA Kỹ thuật (`fetchSlaStats`):**
  * Truy vấn bảng `issue_reports` theo `building_id`.
  * Tính toán thời gian xử lý: Sự cố hoàn thành đúng hạn (thời gian từ `created_at` đến `resolved_at` nhỏ hơn SLA định mức 2h/24h/48h theo độ ưu tiên).
  * Trả về `IssueSlaStatsModel` thực tế, không dùng dữ liệu cứng 12 sự cố và 91.7%.

### 3.3. Lễ tân, Khách thăm & Bưu kiện (`FrontDeskRepository`)
* **Vé khách ra vào:**
  * `fetchVisitorPasses`: Đọc từ bảng `visitor_access_passes`.
  * `createVisitorPass`: Thêm bản ghi mới với mã `VP-...` và mã QR ký số HMAC SHA-256 (`VisitorPassTokenService`).
  * `checkInVisitor`: Gọi RPC bảo mật `check_in_visitor_pass(p_pass_code)` -> Kiểm tra tính hợp lệ và cập nhật `actual_arrival = now()`, `status = 'checked_in'`.
  * `checkOutVisitor`: Gọi RPC `check_out_visitor_pass(p_pass_code)` -> Cập nhật `actual_departure = now()`, `status = 'completed'`.
* **Quản lý bưu kiện:**
  * `fetchParcels`: Đọc từ bảng `parcels`.
  * `receiveParcel`: Thêm bản ghi bưu kiện mới, tự động sinh mã bưu phẩm `PCL-...` và mã PIN nhận hàng 6 số bảo mật.
  * `collectParcel`: Gọi RPC `collect_parcel(p_parcel_id, p_pickup_pin)` -> Kiểm tra mã PIN 6 số, đối soát và cập nhật `collected_at = now()`, `status = 'collected'`.
* **Thống kê Lễ tân:** Gọi RPC `get_front_desk_stats(p_building_id)` trả về số lượng khách đang trong tòa nhà, kiện hàng chờ nhận, kiện hàng quá hạn lưu kho.

### 3.4. Biểu quyết số & Kiến nghị Cư dân (`CommunityRepository`)
* **Khảo sát / Biểu quyết số:**
  * `fetchPolls`: Đọc từ bảng `polls` kèm `poll_options` (tùy chọn).
  * `submitPollVote`: Gọi RPC `submit_poll_vote(p_poll_id, p_option_id, p_apartment_id)` -> Kiểm tra quyền sở hữu căn hộ theo Điều 102 Luật Nhà ở 2023, chặn bỏ phiếu lặp lại bằng ràng buộc duy nhất trong CSDL.
* **Kiến nghị Cư dân:**
  * `fetchPetitions` & `createPetition`: Đọc và thêm bản ghi vào `resident_petitions`.
  * `endorsePetition`: Gọi RPC `endorse_petition(p_petition_id, p_apartment_id)` -> Tự động tăng số lượt đồng thuận và chặn 1 căn hộ ký nhiều lần.

### 3.5. Radar Dự báo Rủi ro Công nợ (`DebtPredictionRepository`)
* **Lấy Radar rủi ro tòa nhà (`getBuildingDebtRadar`):**
  * Gọi RPC `get_building_debt_radar(p_building_id)` trả về các xô tuổi nợ (0-30 ngày, 31-60 ngày, 61-90 ngày, >90 ngày) và điểm rủi ro.
* **Tính điểm rủi ro từng căn hộ (`calculateApartmentDebtRisk`):**
  * Gọi RPC `calculate_apartment_debt_risk(p_building_id, p_apartment_id)` với thuật toán phân tích hành vi thanh toán trễ hạn, tỉ lệ nợ trên phí quản lý bình quân.
* **Ghi nhận hành động đôn đốc nợ (`executeDunningAction`):**
  * Gọi RPC `execute_dunning_action(...)` lưu lịch sử gọi điện, gửi SMS, gửi giấy thông báo vào bảng `dunning_actions`.

---

## 4. Kế hoạch Kiểm thử & Tiêu chí Nghiệm thu (Verification & Acceptance Criteria)

1. **Kiểm thử Đơn vị & Tích hợp (TDD):**
   * Tất cả unit test của các Repository đều pass 100% với kịch bản Supabase client hoạt động và kịch bản `FailClosedGuard`.
2. **Phân tích Tĩnh (Static Analysis):**
   * Lệnh `dart analyze lib test` đạt 0 issues.
3. **Tính Toàn vẹn Dữ liệu (Cloud Verification):**
   * Chạy kịch bản kiểm tra đọc/ghi thử nghiệm trên 5 bảng CSDL để xác thực RLS và ràng buộc toàn vẹn.
