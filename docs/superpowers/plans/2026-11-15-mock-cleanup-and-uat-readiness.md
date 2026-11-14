# Mock Cleanup & Production UAT Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Loại bỏ hoàn toàn mock fallback trong 9 repositories chuyển sang kiến trúc Fail-Closed, nâng version `pubspec.yaml` lên `2.1.0+1`, ban hành `CHANGELOG.md`, soạn thảo hồ sơ pháp lý chuẩn PDPL `docs/PRIVACY_POLICY.md` và `docs/TERMS_OF_SERVICE.md`, và cập nhật ma trận nghiệm thu thực tế 8 module trong `docs/BAN_GIAO_VAN_HANH.md` và `docs/BAN_GIAO_PHONG_TRO.md`.

**Architecture:** 
- Repositories loại bỏ mọi in-memory mock lists (`_mockPolls`, `_mockHandovers`, `_inMemoryTickets`, `_inMemoryVisitors`, `_inMemoryParcels`, `_getFallbackContracts`, cư dân nợ hardcode). Mọi lỗi kết nối mạng hoặc CSDL trả về ngoại lệ rõ ràng (`AppException`), không âm thầm sinh data ảo.
- Quản lý phiên bản SemVer 2.1.0 và ghi nhận nhật ký phát hành `CHANGELOG.md`.
- Hồ sơ bảo mật dữ liệu tuân thủ Luật Bảo vệ dữ liệu cá nhân 91/2025/QH15 và NĐ 356/2025/NĐ-CP.
- Ma trận nghiệm thu UAT chi tiết từng bước cho 5 vai trò trên môi trường vận hành thật.

**Tech Stack:** Flutter 3.x, Dart 3.x, Supabase / PostgreSQL 15, Riverpod, Mocktail.

---

## Danh Sách File Tác Động

### Repositories & Data Layer:
- Modify: `lib/data/repositories/community_repository.dart`
- Modify: `lib/data/repositories/front_desk_repository.dart`
- Modify: `lib/data/repositories/parking_repository.dart`
- Modify: `lib/data/repositories/material_repository.dart`
- Modify: `lib/data/repositories/handover_repository.dart`
- Modify: `lib/data/repositories/resident_lifecycle_repository.dart`
- Modify: `lib/data/repositories/batch_import_repository.dart`
- Modify: `lib/data/repositories/debt_prediction_repository.dart`
- Modify: `lib/data/repositories/resident_activation_repository.dart`

### Tests:
- Modify: `test/data/repositories/community_repository_test.dart` (nếu có)
- Modify: `test/data/repositories/handover_repository_test.dart`
- Modify: `test/data/repositories/parking_repository_test.dart` (nếu có)

### Phiên bản & Hồ sơ Pháp lý:
- Modify: `pubspec.yaml`
- Create: `CHANGELOG.md`
- Create: `docs/PRIVACY_POLICY.md`
- Create: `docs/TERMS_OF_SERVICE.md`

### Nghiệm thu Bàn giao:
- Modify: `docs/BAN_GIAO_VAN_HANH.md`
- Modify: `docs/BAN_GIAO_PHONG_TRO.md`

---

## Chi Tiết Kế Hoạch Thực Thi (Tasks)

### Task 1: Dọn Sạch Mock Fallback Trong 9 Repositories (Fail-Closed)
- [ ] **Step 1.1:** Dọn dẹp `lib/data/repositories/community_repository.dart`: Gỡ bỏ `_mockPolls`, `_mockPetitions`, `_mockVotedApartments`, `_mockEndorsedApartments` và các khối `mockFallback:`. Trả về truy vấn DB thật hoặc ném `AppException`.
- [ ] **Step 1.2:** Dọn dẹp `lib/data/repositories/front_desk_repository.dart`: Gỡ bỏ `_inMemoryVisitors`, `_inMemoryParcels`, chuyển sang gọi trực tiếp bảng `front_desk_logs` / `visitor_passes`.
- [ ] **Step 1.3:** Dọn dẹp `lib/data/repositories/parking_repository.dart`: Gỡ bỏ `_inMemoryTickets` và các đoạn sinh vé ảo `tkt-mock-01`, `tkt-mock-02`.
- [ ] **Step 1.4:** Dọn dẹp `lib/data/repositories/material_repository.dart`: Gỡ bỏ các khối `mockFallback:` trả stats và vật tư giả.
- [ ] **Step 1.5:** Dọn dẹp `lib/data/repositories/handover_repository.dart`: Gỡ bỏ `_mockHandovers` và mảng ảnh mock.
- [ ] **Step 1.6:** Dọn dẹp `lib/data/repositories/resident_lifecycle_repository.dart`: Gỡ bỏ `_getFallbackContracts`.
- [ ] **Step 1.7:** Dọn dẹp `lib/data/repositories/batch_import_repository.dart`: Gỡ bỏ thông báo `offline mock`, trả kết quả lỗi rõ ràng khi không ghi được vào DB.
- [ ] **Step 1.8:** Dọn dẹp `lib/data/repositories/debt_prediction_repository.dart`: Gỡ bỏ hardcoded cư dân nợ mẫu.
- [ ] **Step 1.9:** Dọn dẹp `lib/data/repositories/resident_activation_repository.dart`: Gỡ bỏ `act-mock-1`, `user-mock-1`.
- [ ] **Step 1.10:** Chạy `dart analyze lib/data/repositories` để đảm bảo không còn lỗi biên dịch.
- [ ] **Step 1.11:** Commit: `refactor(data): don sach 100% mock fallback chuyen sang fail-closed chuan enterprise`.

---

### Task 2: Cập Nhật & Xác Minh Bộ Unit Test
- [ ] **Step 2.1:** Rà soát và cập nhật `test/data/repositories/handover_repository_test.dart` để không phụ thuộc vào mock in-memory fallback.
- [ ] **Step 2.2:** Chạy test các repository liên quan: `flutter test test/data/repositories/`.
- [ ] **Step 2.3:** Commit: `test(repo): cap nhat unit test sau khi go bo in-memory mock fallback`.

---

### Task 3: Nâng Version & Phát Hành CHANGELOG.md
- [ ] **Step 3.1:** Cập nhật `pubspec.yaml` lên `version: 2.1.0+1`.
- [ ] **Step 3.2:** Soạn thảo `CHANGELOG.md` chuẩn Keep a Changelog từ v1.0.0 đến v2.1.0.
- [ ] **Step 3.3:** Commit: `chore(release): nang version len 2.1.0 va ban hanh changelog`.

---

### Task 4: Soạn Thảo Bộ Hồ Sơ Pháp Lý Chuẩn Quốc Gia 2026
- [ ] **Step 4.1:** Tạo `docs/PRIVACY_POLICY.md` tuân thủ Luật Bảo vệ dữ liệu cá nhân 91/2025/QH15 và Nghị định 356/2025/NĐ-CP (quy định rõ danh mục dữ liệu, mục đích, quyền của chủ thể dữ liệu, quyền yêu cầu xóa dữ liệu, mã hóa RLS).
- [ ] **Step 4.2:** Tạo `docs/TERMS_OF_SERVICE.md` (Điều khoản Dịch vụ Nền tảng PKA-Home B2B SaaS).
- [ ] **Step 4.3:** Commit: `docs(legal): ban hanh chinh sach quyen rieng tu pdpl 91-2025 va dieu khoan dich vu saas`.

---

### Task 5: Soạn Bộ Kịch Bản Nghiệm Thu UAT Thực Tế (8 Module)
- [ ] **Step 5.1:** Cập nhật `docs/BAN_GIAO_VAN_HANH.md`: Bổ sung Ma trận Nghiệm thu UAT 8 module (Xác thực 5 vai trò, Liên kết căn hộ A0110, Hóa đơn lũy tiến & VietQR, An toàn RLS, Báo số công tơ, Bãi xe & Khách thăm, Quỹ bảo trì 2%, Bàn giao nhà bất biến).
- [ ] **Step 5.2:** Cập nhật `docs/BAN_GIAO_PHONG_TRO.md`: Bổ sung checklist nghiệm thu module phòng trọ/cho thuê căn hộ.
- [ ] **Step 5.3:** Commit: `docs(uat): bo sung ma tran nghiem thu uat thuc te 8 module vao ho so ban giao`.

---

### Task 6: Kiểm Tra Toàn Diện & Push Lên Main
- [ ] **Step 6.1:** Chạy `dart analyze lib test` đảm bảo 0 lỗi.
- [ ] **Step 6.2:** Chạy `flutter test` đảm bảo toàn bộ test pass.
- [ ] **Step 6.3:** Push commit lên nhánh `main`.

