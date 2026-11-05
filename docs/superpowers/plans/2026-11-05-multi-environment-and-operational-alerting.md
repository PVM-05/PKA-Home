# Kế Hoạch Triển Khai: Hạ Tầng Môi Trường Tách Bạch & Giám Sát Cảnh Báo Vận Hành (F1)

> **Dành cho kỹ sư & agent:** Bắt buộc tuân thủ TDD, viết kiểm thử trước, code sau. Từng bước sử dụng cú pháp checkbox (`- [ ]`). Toàn bộ commit trực tiếp vào `main`.

**Mục tiêu:** Xây dựng hệ thống cấu hình tách bạch 3 môi trường (Dev / Staging / Production) và dịch vụ giám sát sự cố vận hành thời gian thực tích hợp cảnh báo Telegram Bot, Slack Webhook và kiểm tra sức khỏe hệ thống (Uptime Health Check).

**Kiến trúc:** Cấu hình môi trường đa tầng theo 12-Factor App (`AppEnvironment`), dịch vụ cảnh báo hướng sự kiện (`OperationalAlertService`) với cơ chế Throttling/Debouncing chống bão thông báo, tích hợp Riverpod.

**Tech Stack:** Dart 3.x, Flutter, Riverpod, HTTP client, Supabase Flutter, flutter_test.

## Ràng Buộc Chung
- Tuân thủ 100% tiếng Việt chuẩn mực trong giao diện, mã lỗi và thông báo. Không sử dụng emoji.
- Commit trực tiếp trên `main`.
- Duy trì 0 warning, 0 error với `dart analyze lib test`.

---

## Danh Sách Task Triển Khai

### Task 1: Cấu Hình Đa Môi Trường (`AppEnvironment` & `.env.*.example`)
**Files:**
- Create: `lib/core/config/app_environment.dart`
- Create: `.env.development.example`
- Create: `.env.staging.example`
- Create: `.env.production.example`
- Test: `test/core/config/app_environment_test.dart`

- [ ] **Bước 1.1:** Viết test `test/core/config/app_environment_test.dart` kiểm tra parse kiểu môi trường, default fallback, kiểm tra logic cờ `isProduction`, `enableDebugLogging`.
- [ ] **Bước 1.2:** Chạy test để xác nhận test thất bại (Red).
- [ ] **Bước 1.3:** Tạo `lib/core/config/app_environment.dart` với enum `AppEnvironmentType`, class `AppEnvironment`, phương thức nạp từ biến môi trường / Map.
- [ ] **Bước 1.4:** Tạo 3 file mẫu: `.env.development.example`, `.env.staging.example`, `.env.production.example`.
- [ ] **Bước 1.5:** Chạy lại test để xác nhận test thành công 100% (Green).
- [ ] **Bước 1.6:** Commit Task 1 vào `main`: `feat(config): cau hinh tach bach da moi truong dev staging prod f1`.

---

### Task 2: Dịch Vụ Cảnh Báo Vận Hành & Giám Sát Uptime (`OperationalAlertService`)
**Files:**
- Create: `lib/core/services/operational_alert_service.dart`
- Modify: `pubspec.yaml` (đảm bảo package `http` được khai báo rõ ràng)
- Test: `test/core/services/operational_alert_service_test.dart`

- [ ] **Bước 2.1:** Thêm `http: ^1.2.0` vào `pubspec.yaml` (nếu cần) và chạy `flutter pub get`.
- [ ] **Bước 2.2:** Viết test `test/core/services/operational_alert_service_test.dart` kiểm tra:
  - Định dạng thông báo Telegram Bot HTML.
  - Định dạng payload Slack Webhook JSON.
  - Cơ chế Throttling/Debouncing: cảnh báo trùng lặp trong 60s bị chặn.
  - Kiểm tra sức khỏe kết nối (Health Check Ping).
- [ ] **Bước 2.3:** Chạy test để xác nhận test thất bại (Red).
- [ ] **Bước 2.4:** Tạo `lib/core/services/operational_alert_service.dart` cài đặt đầy đủ logic gửi cảnh báo, throttling map, ping health check và Riverpod provider `operationalAlertServiceProvider`.
- [ ] **Bước 2.5:** Chạy lại test để xác nhận test thành công 100% (Green).
- [ ] **Bước 2.6:** Commit Task 2 vào `main`: `feat(service): dich vu canh bao van hanh va giam sat uptime telegram slack f1`.

---

### Task 3: Nghiệm Thu Toàn Diện, Đóng Lộ Trình & Đẩy Lên GitHub
**Files:**
- Modify: `docs/COMMERCIAL_PRODUCT_ROADMAP.md`

- [ ] **Bước 3.1:** Chạy toàn bộ test suites mới (`flutter test test/core/config/ test/core/services/`).
- [ ] **Bước 3.2:** Chạy `dart analyze lib test` đảm bảo 0 issues trên toàn bộ repository.
- [ ] **Bước 3.3:** Cập nhật dòng 322 trong `docs/COMMERCIAL_PRODUCT_ROADMAP.md` thành `[x]`, hoàn tất 100% lộ trình thương mại hóa.
- [ ] **Bước 3.4:** Cập nhật đồ thị tri thức kiến trúc: `python -m graphify update .`.
- [ ] **Bước 3.5:** Commit và push toàn bộ thay đổi trực tiếp lên nhánh `main` của GitHub remote.
