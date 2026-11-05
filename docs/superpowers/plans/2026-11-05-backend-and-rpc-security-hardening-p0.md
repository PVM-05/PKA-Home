# Kế Hoạch Triển Khai: Chuẩn Hóa Production - Đợt 2 (P0/P1: Backend & RPC Security Hardening)

> **Dành cho kỹ sư & agent:** Bắt buộc tuân thủ TDD, fail-closed mặc định, server-authoritative identity, không để ID client tự khai hoặc PIN plaintext lọt vào production. Toàn bộ commit trực tiếp vào `main`.

**Mục tiêu:** Khắc phục triệt để các lỗ hổng bảo mật backend và nghiệp vụ pháp lý quan trọng:
1. Định danh do client tự khai trong các RPCs (`p_guard_id`, `p_staff_id`, `p_voter_user_id`, `p_user_id`).
2. Mã PIN bưu kiện lưu plaintext và lộ cho lễ tân; đối soát PIN vô nghĩa.
3. Mã QR vé khách viếng thăm không chữ ký số, nguy cơ giả mạo và quét lặp lại (replay attacks).
4. Biểu quyết điện tử vi phạm Điều 102 Luật Nhà ở 2023 khi cho phép khách thuê (tenant) biểu quyết nghị quyết Hội nghị nhà chung cư.
5. Bug giao diện đọc sai key căn hộ `list.first['id']` và fallback hardcode `'apt-01'`, `'usr-resident'`.

**Kiến trúc:** 
- Server-Authoritative Identity: Backend tự xác thực người dùng qua `auth.uid()`, client không gửi ID người dùng.
- Cryptographic Token & Replay Protection: Mã QR khách có chữ ký HMAC-SHA256, thời hạn và nonce; chống quét lặp lại bằng trạng thái giao dịch một lần.
- Zero-Knowledge Parcel PIN: Lưu hash SHA-256 trên CSDL, lễ tân không biết PIN trước, chỉ nhập để verify qua RPC.
- Housing Law 2023 Compliance: Phân định rõ cuộc biểu quyết chính thức (Hội nghị nhà chung cư, chỉ `owner`) và khảo sát cộng đồng (cả `tenant`).

**Tech Stack:** PostgreSQL / Supabase PL/pgSQL, Dart / Flutter, Crypto (HMAC-SHA256), Riverpod.

---

## Danh Sách Task Triển Khai

### Task 2.1: Migration Bảo Mật RPCs & Server-Authoritative Identity (`auth.uid()`)
**Files:**
- Create: `supabase/migrations/20261105_01_server_authoritative_identity_and_rpc_hardening.sql`

- [x] **Bước 2.1.1:** Tạo migration SQL bổ sung cột `poll_type` trong bảng `polls`, cột `pickup_pin_hash` trong bảng `parcels`.
- [x] **Bước 2.1.2:** Viết trigger tự động băm SHA-256 mã PIN `fn_generate_parcel_code_and_pin()`.
- [x] **Bước 2.1.3:** Cập nhật các hàm RPC để ưu tiên `auth.uid()` thay vì client ID:
  - `check_in_visitor_pass`: Kiểm tra trạng thái đã check-in / check-out / hết hạn chống replay attack, gán `check_in_guard_id = COALESCE(auth.uid(), p_guard_id)`.
  - `check_out_visitor_pass`: Gán `check_out_guard_id = COALESCE(auth.uid(), p_guard_id)`.
  - `collect_parcel`: So sánh hash `p_pickup_pin` với `pickup_pin_hash`, gán `handover_staff_id = COALESCE(auth.uid(), p_staff_id)`.
  - `submit_poll_vote`: Kiểm tra quyền biểu quyết theo Điều 102 Luật Nhà ở 2023 (chỉ `owner` cho `official_assembly`), tự động lấy voter từ `auth.uid()`.
  - `endorse_petition`: Tự động lấy user từ `auth.uid()`.
  - `update_petition_response`: Tự động lấy staff từ `auth.uid()`.
- [x] **Bước 2.1.4:** Commit migration SQL lên nhánh `main`.

---

### Task 2.2: Dịch Vụ Sinh & Ký Token QR Khách Viếng Thăm (`VisitorPassTokenService`)
**Files:**
- Create: `lib/core/security/visitor_pass_token_service.dart`
- Create: `test/core/security/visitor_pass_token_service_test.dart`

- [x] **Bước 2.2.1 (TDD):** Viết unit test cho `VisitorPassTokenService`:
  - Ký và xác thực token QR hợp lệ.
  - Từ chối token bị sửa đổi dữ liệu (tampered signature).
  - Từ chối token đã quá hạn sử dụng (`isExpired`).
  - Phân tích và tương thích an toàn với định dạng legacy `PKAPASS:pass_code:random`.
- [x] **Bước 2.2.2:** Cài đặt `VisitorPassTokenService` sử dụng HMAC-SHA256 với secret key của hệ thống.
- [x] **Bước 2.2.3:** Chạy test xác thực toàn bộ test cases pass.
- [x] **Bước 2.2.4:** Commit: `feat(security): them visitor pass token service voi hmac sha256 va chong replay p0`.

---

### Task 2.3: Chuẩn Hóa Tầng Repositories & Contracts (Loại Bỏ ID Client Tự Khai)
**Files:**
- Modify: `lib/data/contracts/operations_rpc_contracts.dart`
- Modify: `lib/data/contracts/community_rpc_contracts.dart`
- Modify: `lib/data/repositories/front_desk_repository.dart`
- Modify: `lib/data/repositories/community_repository.dart`
- Create: `test/data/repositories/front_desk_security_test.dart`

- [x] **Bước 2.3.1 (TDD):** Viết unit test kiểm tra contract RPC không còn bắt buộc `p_guard_id`, `p_staff_id`, `p_voter_user_id`, `p_user_id`.
- [x] **Bước 2.3.2:** Cập nhật `operations_rpc_contracts.dart` và `community_rpc_contracts.dart` loại bỏ các tham số client tự khai bắt buộc.
- [x] **Bước 2.3.3:** Cập nhật `FrontDeskRepository` và `CommunityRepository` gọi RPC server-authoritative.
- [x] **Bước 2.3.4:** Đảm bảo `fetchParcels` cho màn hình lễ tân không hiển thị trực tiếp `pickup_pin` của cư dân.
- [x] **Bước 2.3.5:** Commit: `fix(repo): loai bo tham so client tu khai tren rpc va an ma pin buu kien p0`.

---

### Task 2.4: Tuân Thủ Luật Nhà Ở 2023 & Loại Bỏ Fallback Mock Căn Hộ Cư Dân
**Files:**
- Modify: `lib/data/models/poll_model.dart`
- Modify: `lib/features/resident/screens/resident_visitor_parcel_screen.dart`
- Modify: `lib/features/resident/screens/resident_community_screen.dart`
- Modify: `lib/features/resident/widgets/vote_poll_sheet.dart`
- Modify: `lib/features/resident/widgets/create_petition_sheet.dart`
- Create: `test/features/resident/community_voting_law_test.dart`

- [x] **Bước 2.4.1 (TDD):** Viết test kiểm tra:
  - Căn hộ chưa chọn hoặc không có thì hiển thị empty state, không gửi fallback `'apt-01'` hay `'usr-resident'`.
  - Phân quyền biểu quyết: `tenant` bị vô hiệu hóa bỏ phiếu ở cuộc biểu quyết chính thức `official_assembly` kèm thông báo Luật Nhà ở 2023.
- [x] **Bước 2.4.2:** Cập nhật `PollModel` thêm `pollType` (`official_assembly` / `survey`).
- [x] **Bước 2.4.3:** Sửa `resident_visitor_parcel_screen.dart`:
  - Sửa lỗi truy vấn key căn hộ: Dùng `selectedApartmentIdProvider` hoặc `(list.first['apartment_id'] as String?)`.
  - Xóa bỏ fallback `'apt-01'` và `'usr-resident'`. Hiển thị màn hình thông báo khi chưa có căn hộ hoặc chưa đăng nhập.
- [x] **Bước 2.4.4:** Sửa `resident_community_screen.dart`:
  - Xóa bỏ fallback `'apt-01'` và `'usr-resident'`.
  - Hiển thị nhãn phân biệt rõ: "Nghị quyết chính thức (Hội nghị nhà chung cư)" vs "Khảo sát ý kiến".
  - Kiểm tra `relation_role` của cư dân trong căn hộ hiện tại: Nếu là `tenant` đối với cuộc họp chính thức, hiển thị cảnh báo không có quyền biểu quyết.
- [x] **Bước 2.4.5:** Commit: `feat(community): tuan thu bieu quyet luat nha o 2023 va loai bo fallback apt-01 p0`.

---

### Task 2.5: Nghiệm Thu Đợt 2, Kiểm Thử & Push Git Main
**Files:**
- Modify: `docs/COMMERCIAL_PRODUCT_ROADMAP.md`

- [x] **Bước 2.5.1:** Chạy `dart analyze lib test` đảm bảo 0 errors, 0 warnings.
- [x] **Bước 2.5.2:** Chạy toàn bộ test suite Đợt 1 và Đợt 2.
- [x] **Bước 2.5.3:** Cập nhật `docs/COMMERCIAL_PRODUCT_ROADMAP.md` đánh dấu các mục Đợt 2 hoàn tất.
- [x] **Bước 2.5.4:** Push toàn bộ commits trực tiếp lên `origin/main`.
