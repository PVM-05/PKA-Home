# Kế Hoạch Triển Khai: Chuẩn Bị Cho Tương Lai & CI Hardening (Giai Đoạn 3 - Future Proofing & CI Hardening)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ghim cố định phiên bản Flutter SDK `3.44.0` trong CI workflow; triển khai bộ kiểm thử hình ảnh Golden Tests cho các thành phần cốt lõi của Design System Vivona 2026; và thiết lập tài liệu kiến trúc theo dõi lộ trình `package:material_ui`.

**Tech Stack:** Flutter 3.44.0 / SDK ^3.12.0, Flutter Test (`matchesGoldenFile`), GitHub Actions CI.

## Global Constraints
- Tuân thủ quy định thương mại B2B SaaS Vivona (`AGENTS.md`, `coding-rules.md`, `design-rules.md`).
- Toàn bộ commit thực hiện trực tiếp trên nhánh `main`.
- Duy trì 100% zero-regression trên toàn bộ test suites hiện hữu.

---

## Danh Sách Công Việc (Task Breakdown)

### Task 1: Ghim Phiên Bản Flutter trong GitHub Actions CI Pipeline
**Files:**
- Modify: `.github/workflows/ci.yml`

- [x] **Step 1: Cập nhật cấu hình setup-flutter trong `.github/workflows/ci.yml`**
  - Thêm `flutter-version: '3.44.0'`.
  - Giữ `channel: 'stable'`.
- [x] **Step 2: Kiểm tra cú pháp YAML**
- [x] **Step 3: Commit code**
  - Commit message: `ci: ghim co dinh phien ban flutter 3.44.0 trong ci quality gate` (Commit `554faf2`)

---

### Task 2: Xây Dựng Hạ Tầng Golden Test Helper & Comparator Dung Sai
**Files:**
- Create: `test/goldens/golden_test_helper.dart`

- [x] **Step 1: Tạo hàm helper `pumpGoldenWidget`**
  - Khởi tạo `MaterialApp` với `AppTheme.lightTheme` hoặc `AppTheme.darkTheme`.
  - Cố định kích thước `tester.view.physicalSize` và `tester.view.devicePixelRatio = 1.0`.
  - Tắt tải font động từ mạng qua `GoogleFonts.config.allowRuntimeFetching = false`.
- [x] **Step 2: Phân tích cú pháp kiểm tra helper**
- [x] **Step 3: Commit code**
  - Commit message: `test(goldens): xay dung golden test helper cho he thong design system` (Commit `035802b`)

---

### Task 3: Triển Khai Bộ Golden Tests Cho Design System Cốt Lõi
**Files:**
- Create: `test/goldens/design_system_goldens_test.dart`
- Create: `test/goldens/meter_reading_reminder_banner_golden_test.dart`
- Create: `test/goldens/adaptive_master_detail_layout_golden_test.dart`
- Create: `test/goldens/goldens/*.png` (9 ảnh mẫu)

- [x] **Step 1: Viết Golden Test cho `AppCard` và `AppGlassCard` (Light & Dark)**
- [x] **Step 2: Viết Golden Test cho `MeterReadingReminderBanner`**
- [x] **Step 3: Viết Golden Test cho `AdaptiveMasterDetailLayout`**
- [x] **Step 4: Sinh ảnh mẫu chuẩn (Golden Master Images)**
  - Chạy `flutter test test/goldens/ --update-goldens`.
- [x] **Step 5: Chạy kiểm thử so sánh xác nhận pass**
  - Chạy `flutter test test/goldens/` $\rightarrow$ 9/9 tests pass 100%.
- [x] **Step 6: Commit code và golden assets**
  - Commit message: `test(goldens): bo sung bo golden tests bao ve design system va layout thich ung` (Commit `3ac989d`)

---

### Task 4: Lập Tài Liệu Lộ Trình Theo Dõi `package:material_ui` (Expressive)
**Files:**
- Create: `docs/architecture/material_ui_expressive_roadmap.md`

- [x] **Step 1: Soạn thảo tài liệu phân tích kỹ thuật và lộ trình tích hợp**
  - Đánh giá hiện trạng Flutter 3.44.0 và gói `material_ui: ^1.4.0`.
  - Lý do không sử dụng các gói Expressive bên thứ ba không chính thức.
  - Ma trận các component dự kiến và quy trình di chuyển an toàn khi `material_ui` đạt bản phát hành chính thức ổn định.
- [x] **Step 2: Commit tài liệu**
  - Commit message: `docs(architecture): thiet lap tai lieu lo trinh tich hop material ui expressive` (Commit `d15cdd7`)

---

### Task 5: Nghiệm Thu Toàn Diện Giai Đoạn 3 & Hoàn Tất Dự Án
- [x] **Step 1: Chạy kiểm tra phân tích tĩnh toàn bộ dự án (`dart analyze lib test`)** (0 issues)
- [x] **Step 2: Chạy toàn bộ test suites (`flutter test`)** (Pass)
- [x] **Step 3: Đồng bộ tri thức kiến trúc qua `graphify update .`** (Done)
- [x] **Step 4: Commit và tổng kết báo cáo toàn diện 4 giai đoạn**
