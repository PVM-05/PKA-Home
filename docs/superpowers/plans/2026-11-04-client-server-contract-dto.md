# Kế Hoạch Triển Khai: Hợp Đồng Client ↔ Server Chặt Chẽ (Strongly-Typed RPC DTOs & Contract Tests)

> **Dành cho kỹ sư & agent:** Bắt buộc tuân thủ TDD, viết kiểm thử trước, code sau. Từng bước sử dụng cú pháp checkbox (`- [ ]`). Toàn bộ commit trực tiếp vào `main`.

**Mục tiêu:** Xây dựng hệ thống Strongly-Typed DTOs cho các RPC quan trọng giữa Flutter và Supabase, thay thế `Map<String, dynamic>` lỏng lẻo, bọc ngoại lệ bằng `RpcContractClient` và viết bộ Contract Tests tự động đối soát chính xác 100% schema.

**Kiến trúc:** Phân nhóm theo domain (`finance`, `booking`, `operations`, `community`), cung cấp lớp client bao bọc `RpcContractClient`, mapping chính xác tiền tố `p_*` của PostgreSQL và parse response có kiểu an toàn.

**Tech Stack:** Dart 3.x, Flutter, Supabase Flutter, Riverpod, flutter_test.

## Ràng Buộc Chung
- Tuân thủ 100% tiếng Việt chuẩn mực trong thông điệp lỗi và nhãn hiển thị. Không sử dụng emoji.
- Commit trực tiếp trên `main`.
- Duy trì 0 warning, 0 error với `dart analyze lib test`.

---

## Danh Sách Task Triển Khai

### Task 1: Xây dựng `RpcContractClient` và các Hợp Đồng DTO Core
- [ ] Tạo `lib/data/contracts/rpc_contract_client.dart` với lớp `RpcContractClient`, `RpcContractException` và helper type-safe.
- [ ] Tạo `lib/data/contracts/finance_rpc_contracts.dart` chứa DTOs cho Quỹ bảo trì (`RecordMaintenanceTransactionDto`), Webhook gạch nợ (`ProcessBankPaymentWebhookDto`), Cấu hình thương mại (`OnboardBuildingConfigDto`), Dự báo nợ xấu & Đôn đốc (`PredictDebtRiskDto`, `ExecuteDunningDto`).
- [ ] Tạo `lib/data/contracts/booking_rpc_contracts.dart` chứa DTOs cho Đặt tiện ích (`BookAmenitySlotDto`), Hủy lịch fail-closed (`CancelAmenityBookingDto`), Check-in (`CheckInAmenityBookingDto`).
- [ ] Tạo `lib/data/contracts/operations_rpc_contracts.dart` chứa DTOs cho AI triage sự cố (`TriageIssueReportDto`), Ghi chỉ số (`RecordMeterReadingDto`), Khách ra vào & Bưu kiện (`VisitorPassActionDto`, `CollectParcelDto`).
- [ ] Tạo `lib/data/contracts/community_rpc_contracts.dart` chứa DTOs cho Biểu quyết điện tử (`SubmitPollVoteDto`) và Kiến nghị (`EndorsePetitionDto`).

### Task 2: Viết Bộ Kiểm Thử Hợp Đồng Tự Động (Contract Tests)
- [ ] Tạo `test/contracts/rpc_contracts_test.dart`.
- [ ] Viết test serialization: Xác thực mọi Request DTO sinh ra `Map<String, dynamic>` với đúng 100% tham số `p_*` khớp với PostgreSQL RPC signatures.
- [ ] Viết test deserialization: Xác thực parse thành công cho cả kết quả `success = true` và `success = false`, đảm bảo xử lý null an toàn.
- [ ] Viết test cho `RpcContractClient`: Mô phỏng gọi thành công và xử lý ngoại lệ `RpcContractException`.
- [ ] Chạy `flutter test test/contracts/rpc_contracts_test.dart` và đảm bảo 100% tests pass.

### Task 3: Tích Hợp DTO Contracts vào Các Repositories Trọng Yếu
- [ ] Cập nhật `lib/data/repositories/maintenance_fund_repository.dart` sử dụng `RecordMaintenanceTransactionRequestDto` và `RecordMaintenanceTransactionResponseDto`.
- [ ] Cập nhật `lib/data/repositories/amenity_booking_repository.dart` sử dụng `BookAmenitySlotRequestDto`, `CancelAmenityBookingRequestDto`.
- [ ] Cập nhật `lib/data/repositories/debt_prediction_repository.dart` sử dụng DTO contracts.
- [ ] Chạy toàn bộ test suites liên quan để đảm bảo không phát sinh hồi quy (regression).

### Task 4: Nghiệm Thu, Cập Nhật Roadmap & Tri Thức, Push Lên GitHub
- [ ] Chạy `dart analyze lib test` (yêu cầu 0 issues).
- [ ] Chạy toàn bộ test contracts và repository tests.
- [ ] Cập nhật mục A2 trong `docs/COMMERCIAL_PRODUCT_ROADMAP.md` sang trạng thái `[x]`.
- [ ] Cập nhật đồ thị tri thức `python -m graphify update .`.
- [ ] Commit trực tiếp trên `main` và push lên `origin/main`.
