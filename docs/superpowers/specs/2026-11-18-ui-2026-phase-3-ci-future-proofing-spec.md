# Đặc Tả Kỹ Thuật: Chuẩn Bị Cho Tương Lai & CI Hardening (Giai Đoạn 3 - Future Proofing & CI Hardening)

> **Mục tiêu:** Ghim phiên bản Flutter SDK cố định trong CI pipeline để loại bỏ rủi ro breaking change từ upstream; xây dựng bộ Golden Tests nền tảng bảo vệ toàn diện ngôn ngữ thiết kế Vivona 2026; và thiết lập lộ trình theo dõi tích hợp `package:material_ui` Expressive chính thức.
> 
> **Tuân thủ:** `AGENTS.md`, `coding-rules.md`, `design-rules.md`. Toàn bộ commit trực tiếp vào nhánh `main`.

---

## 1. Bối Cảnh & Vấn Đề (Context & Problem Statement)

1. **Rủi ro CI trôi nổi (Unpinned Flutter SDK in CI):**
   - Hiện tại file `.github/workflows/ci.yml` sử dụng `channel: 'stable'` mà không chỉ định số phiên bản cố định (`flutter-version`). Khi Flutter SDK nâng cấp bản vá hoặc bản minor mới (ví dụ Flutter 3.45+), các thay đổi hành vi hoặc deprecation có thể khiến pipeline CI gãy bất ngờ.
   - Vivona phát triển trên nền tảng Flutter 3.44.0 (Dart 3.12.0) — phiên bản framework mà Material SDK nội bộ bắt đầu đóng băng công việc Expressive để chuyển giao sang package độc lập.

2. **Thiếu vắng Golden Tests bảo vệ giao diện (0 Golden Tests):**
   - Dự án hiện có hàng trăm unit & widget tests kiểm tra logic và cấu trúc widget tree, nhưng chưa có bất kỳ bài test nào kiểm tra độ trung thực về mặt hiển thị hình ảnh (pixel-perfect visual regression).
   - Mọi thay đổi trong theme, màu sắc, bo góc, bóng mờ, đổ bóng Glassmorphism hay layout Bento nếu bị lệch giao diện thì widget test thông thường không thể phát hiện.

3. **Lộ trình dài hạn với `package:material_ui`:**
   - Flutter đã phân tách Material 3 Expressive sang `package:material_ui` (bản 1.4.0 hiện tại mới chỉ có cờ `StyleVariant` thử nghiệm). Cần có tài liệu theo dõi kiến trúc chính thức để khi các component Expressive hoàn thiện (Buttons, Cards, Chips, Floating Action Buttons), đội ngũ có thể tích hợp an toàn mà không phải sử dụng các package cộng đồng trôi nổi rủi ro cao.

---

## 2. Giải Pháp Kỹ Thuật (Technical Design)

### 2.1. Ghim Phiên Bản Flutter trong GitHub Actions CI
- Cập nhật `.github/workflows/ci.yml`:
  ```yaml
  - name: Setup Flutter Environment
    uses: subosito/flutter-action@v2
    with:
      flutter-version: '3.44.0'
      channel: 'stable'
      cache: true
  ```
- Đảm bảo môi trường build của CI chạy chính xác trên phiên bản Flutter `3.44.0` tương thích tuyệt đối với máy phát triển cục bộ.

### 2.2. Kiến Trúc Bộ Golden Tests Nền Tảng
- Thư mục: `test/goldens/`
- Sử dụng cơ chế gốc `matchesGoldenFile` của `flutter_test`.
- Cung cấp test helper `test/goldens/golden_test_helper.dart`:
  - `pumpGoldenWidget(WidgetTester tester, Widget widget, {ThemeData? theme, Size surfaceSize})`: Chuẩn hóa kích thước khung hình, nạp theme Vivona (Light và Dark), thiết lập `textScaleFactor = 1.0` để ảnh render nhất quán.
  - Sử dụng comparator có cấu hình dung sai pixel hợp lý hoặc môi trường render đồng nhất nhằm đảm bảo golden test chạy ổn định cả trên Windows cục bộ và Linux CI runner.
- Danh mục Golden Tests:
  1. `app_card_golden_test.dart`: Thẻ `AppCard` ở cả 2 chế độ Light Theme và Dark Theme.
  2. `app_glass_card_golden_test.dart`: Thẻ kính mờ `AppGlassCard` với viền bán trong suốt.
  3. `meter_reading_reminder_banner_golden_test.dart`: Thẻ thông báo Bento nhắc ghi chỉ số điện nước cuối chu kỳ.
  4. `adaptive_master_detail_layout_golden_test.dart`: Layout Master-Detail ở viewport Tablet/Desktop (1024x768).

### 2.3. Lộ Trình Tích Hợp Material 3 Expressive
- Tài liệu hóa tại `docs/architecture/material_ui_expressive_roadmap.md`:
  - Hiện trạng: Flutter 3.44 Material SDK bị đóng băng, `package:material_ui` đang ở 1.4.0.
  - Tiêu chí đánh giá mức độ sẵn sàng: Package đạt $\ge 2.0.0$, cung cấp đầy đủ các component Expressive chính thức từ Flutter team (Google), có hỗ trợ theme đồng bộ.
  - Chiến lược chuyển đổi mượt mà: Tiếp tục sử dụng các tokens `AppSpacing`, `AppRadius`, `AppCard`, `AppGlassCard` làm facade layer để khi chuyển sang `package:material_ui` chỉ cần cập nhật bên trong facade mà không ảnh hưởng tới toàn bộ màn hình ứng dụng.

---

## 3. Tiêu Chí Nghiệm Thu (Acceptance Criteria)
1. CI Workflow ghim cứng `flutter-version: '3.44.0'`.
2. Toàn bộ các Golden tests được sinh ảnh mẫu (`test/goldens/goldens/*.png`) và so khớp thành công 100%.
3. `dart analyze lib test` đạt 0 issues (không có lỗi hay cảnh báo nào).
4. `flutter test` toàn bộ pass 100%.
5. Cập nhật sơ đồ tri thức qua `graphify update .`.

