# Kế Hoạch Triển Khai: Thích Ứng & Cá Nhân Hóa (Giai Đoạn 2 - Adaptive & Personalization)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hiện thực hóa kiến trúc Adaptive Master-Detail (2 cột danh sách + chi tiết trên màn hình rộng $\ge 900$dp) cho phân hệ Hóa đơn và Phản ánh cư dân; xây dựng cơ chế cá nhân hóa màn hình chính theo hành vi (Behavioral Personalization); và phủ toàn diện trợ năng Semantics chuẩn WCAG AA cho các thành phần UI.

**Tech Stack:** Flutter 3.44+ / SDK ^3.12.0, Flutter Riverpod 2.6.1, Flutter Test / Mocktail.

## Global Constraints
- Tuân thủ quy định thương mại B2B SaaS Vivona (`AGENTS.md`, `coding-rules.md`, `design-rules.md`).
- Toàn bộ commit thực hiện trực tiếp trên nhánh `main`.
- Duy trì 100% backward-compatibility với luồng điều hướng di động hiện tại.
- Mọi file tạo mới hoặc refactor đều phải sạch 100% mã màu cứng và fontSize cứng, tuân thủ tokens `AppSpacing` và `AppRadius`.

---

## Danh Sách Công Việc (Task Breakdown)

### Task 1: Xây Dựng Khung Điều Hướng Thích Ứng `AdaptiveMasterDetailLayout`
**Files:**
- Create: `lib/core/widgets/adaptive_master_detail_layout.dart`
- Create: `test/core/widgets/adaptive_master_detail_layout_test.dart`

- [x] **Step 1: Viết test cho `AdaptiveMasterDetailLayout`**
  - Test render 1 cột khi chiều rộng màn hình $< 900$dp (Mobile mode).
  - Test render 2 cột (Master và Detail) khi chiều rộng $\ge 900$dp (Desktop/Tablet mode).
  - Test hiển thị empty placeholder khi `selectedItem == null` trên desktop.
- [x] **Step 2: Triển khai widget `AdaptiveMasterDetailLayout<T>`**
  - Bố cục responsive sử dụng `LayoutBuilder`, `Row`, `Expanded` và `Divider`.
  - Phân chia tỉ lệ linh hoạt (cột Master 380-420px cố định hoặc flex 4, cột Detail flex 6).
- [x] **Step 3: Chạy test xác nhận pass**
  - Chạy `flutter test test/core/widgets/adaptive_master_detail_layout_test.dart`.
- [x] **Step 4: Commit code**
  - Commit message: `feat(core): xay dung widget adaptive_master_detail_layout cho man hinh lon` (Commit `ea921cf`)

---

### Task 2: Ứng Dụng Adaptive Master-Detail Vào Màn Hình Hóa Đơn Cư Dân (`ResidentInvoiceScreen`)
**Files:**
- Modify: `lib/features/resident/screens/resident_invoice_screen.dart`
- Modify: `lib/features/resident/screens/resident_invoice_detail_screen.dart`
- Create: `test/features/resident/screens/resident_invoice_adaptive_test.dart`

- [x] **Step 1: Trích xuất nội dung chi tiết hóa đơn thành reusable widget**
  - Hỗ trợ chế độ nhúng `isEmbedded` vào `ResidentInvoiceDetailScreen` để hiển thị trong cột Detail bên phải mà không có AppBar/back button dư thừa.
- [x] **Step 2: Viết test cho `ResidentInvoiceScreen` ở cả 2 viewport**
  - Test tại 390dp: chạm vào hóa đơn gọi navigation sang trang chi tiết.
  - Test tại 1200dp: chạm vào hóa đơn trong danh sách bên trái sẽ cập nhật ngay cột bên phải.
- [x] **Step 3: Tích hợp `AdaptiveMasterDetailLayout` vào `ResidentInvoiceScreen`**
  - Lưu trạng thái `_selectedInvoice` nội bộ trong screen.
  - Màn hình rộng hiển thị 2 cột, màn hình nhỏ duy trì trải nghiệm push route như cũ.
- [x] **Step 4: Chạy test xác nhận pass**
  - Chạy `flutter test test/features/resident/screens/resident_invoice_adaptive_test.dart`.
- [x] **Step 5: Commit code**
  - Commit message: `feat(resident): tich hop adaptive master-detail vao man hinh hoa don cu dan` (Commit `deb908a`)

---

### Task 3: Ứng Dụng Adaptive Master-Detail Vào Màn Hình Phản Ánh Cư Dân (`ResidentIssueScreen`)
**Files:**
- Modify: `lib/features/resident/screens/resident_issue_screen.dart`
- Modify: `lib/features/resident/screens/issue_detail_screen.dart`
- Create: `test/features/resident/screens/resident_issue_adaptive_test.dart`

- [x] **Step 1: Hỗ trợ chế độ nhúng cho chi tiết sự cố**
  - Thêm cờ `isEmbedded` cho `IssueDetailScreen`, điều chỉnh layout cuộn phẳng không chia 2 cột thừa khi nhúng.
- [x] **Step 2: Viết test cho `ResidentIssueScreen` adaptive layout**
  - Test responsive hiển thị 2 cột trên desktop và 1 cột trên mobile.
- [x] **Step 3: Tích hợp `AdaptiveMasterDetailLayout` vào `ResidentIssueScreen`**
  - Lưu trạng thái `_selectedIssue` và đồng bộ realtime khi có sự cố được chọn.
- [x] **Step 4: Chạy test xác nhận pass**
  - Chạy `flutter test test/features/resident/screens/resident_issue_adaptive_test.dart`.
- [x] **Step 5: Commit code**
  - Commit message: `feat(resident): tich hop adaptive master-detail vao man hinh phan anh cu dan` (Commit `a40cb12`)

---

### Task 4: Xây Dựng Động Cơ Cá Nhân Hóa Hành Vi (`HomePersonalizationProvider`)
**Files:**
- Create: `lib/features/resident/providers/home_personalization_provider.dart`
- Create: `lib/features/resident/widgets/home/meter_reading_reminder_banner.dart`
- Create: `test/features/resident/providers/home_personalization_provider_test.dart`
- Create: `test/features/resident/widgets/meter_reading_reminder_banner_test.dart`

- [x] **Step 1: Viết test cho logic cá nhân hóa**
  - Test nhận diện khi có hóa đơn quá hạn hoặc chưa thanh toán $\rightarrow$ trạng thái `urgentInvoice`.
  - Test nhận diện khi hóa đơn đã trả hết nhưng có sự cố chưa đóng $\rightarrow$ trạng thái `activeIssueTracking`.
  - Test nhận diện cửa sổ ghi chỉ số từ ngày 20 đến 31 $\rightarrow$ trạng thái `meterReadingWindow`.
- [x] **Step 2: Triển khai `homePersonalizationProvider`**
  - Kết hợp dữ liệu từ `residentInvoiceProvider`, `residentIssueProvider`, `DateTime.now()`.
- [x] **Step 3: Triển khai widget banner nhắc ghi chỉ số `MeterReadingReminderBanner`**
  - Thẻ thông báo nhắc nhở kèm nút "Khai báo ngay" có phản hồi xúc giác `AppHaptics`.
- [x] **Step 4: Chạy test xác nhận pass**
  - Chạy `flutter test test/features/resident/providers/home_personalization_provider_test.dart`.
- [x] **Step 5: Commit code**
  - Commit message: `feat(resident): xay dung dong co ca nhan hoa man hinh chinh theo hanh vi` (Commit `d36579a`)

---

### Task 5: Tích Hợp Cá Nhân Hóa Động Vào Trang Chủ Cư Dân (`ResidentHomeScreen`)
**Files:**
- Modify: `lib/features/resident/screens/resident_home_screen.dart`
- Modify: `lib/features/resident/widgets/home/resident_utility_consumption_chart_card.dart`
- Modify: `test/features/resident/resident_home_hierarchy_test.dart`

- [x] **Step 1: Kết nối `homePersonalizationProvider` vào `ResidentHomeScreen`**
  - Động thái sắp xếp:
    - Nếu trong cửa sổ ghi chỉ số (ngày 20-31): Banner nhắc nhở ghi chỉ số được hiển thị nổi bật.
    - Nếu sự cố đang sửa chữa được ưu tiên: Đưa thẻ Sự cố lên trên phân vùng dịch vụ.
- [x] **Step 2: Chạy kiểm thử hồi quy phân tầng trang chủ**
  - Chạy `flutter test test/features/resident/resident_home_hierarchy_test.dart`.
- [x] **Step 3: Commit code**
  - Commit message: `feat(resident): tich hop sap xep dong giao dien trang chu theo hanh vi thuc te` (Commit `639c8cb`)

---

### Task 6: Chuẩn Hóa Trợ Năng `Semantics` & Đảm Bảo Chuẩn WCAG AA
**Files:**
- Create: `lib/core/widgets/app_semantic_badge.dart`
- Modify: `lib/core/widgets/bounceable.dart`
- Modify: `lib/features/resident/widgets/home/resident_utility_consumption_chart_card.dart`
- Create: `test/core/widgets/app_accessibility_semantics_test.dart`

- [x] **Step 1: Viết test kiểm tra trợ năng `Semantics`**
  - Kiểm tra `AppSemanticBadge` có nhãn giọng nói rõ ràng.
  - Kiểm tra `Bounceable` có `semanticLabel` và cờ button.
  - Kiểm tra thẻ biểu đồ điện nước có tóm tắt dữ liệu qua `Semantics`.
- [x] **Step 2: Triển khai `AppSemanticBadge` & cập nhật các widget cốt lõi**
  - Bổ sung `semanticLabel` vào `Bounceable`.
  - Bọc nhãn giọng nói cho biểu đồ `fl_chart`.
- [x] **Step 3: Chạy test xác nhận pass**
  - Chạy `flutter test test/core/widgets/app_accessibility_semantics_test.dart`.
- [x] **Step 4: Commit code**
  - Commit message: `feat(core): chuan hoa tro nang semantics va tieu chuan wcag aa` (Commit `e642872`)

---

### Task 7: Nghiệm Thu Toàn Diện, Guardrails & Đồng Bộ Tri Thức
- [x] **Step 1: Cập nhật Whitelist trong `test/core/theme_and_color_guard_test.dart`**
- [x] **Step 2: Chạy kiểm tra phân tích tĩnh toàn bộ dự án (`dart analyze lib test`)**
- [x] **Step 3: Chạy toàn bộ test suites (`flutter test`)**
- [x] **Step 4: Đồng bộ tri thức kiến trúc qua `graphify update .`**
- [x] **Step 5: Báo cáo tổng kết Giai đoạn 2**
