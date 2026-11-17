# Kế Hoạch Triển Khai: Ngôn Ngữ Thị Giác 2026 (Giai Đoạn 1 - Visual Language 2026)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hiện đại hóa toàn diện giao diện Vivona theo xu hướng thiết kế 2026: kiến trúc Bento Grid cho Trang chủ cư dân & Dashboard BQL, hệ thống chuyển động lò xo (Spring Motion) & micro-feedback (Bounceable), động cơ phản hồi xúc giác (`AppHaptics`), hiệu ứng kính tiết chế (`AppGlassCard`), và biểu đồ tiêu thụ điện nước cư dân (`fl_chart`). Toàn bộ thay đổi phải đạt 0 lỗi phân tích tĩnh (`dart analyze`) và 100% tests pass.

**Tech Stack:** Flutter 3.44+ / SDK ^3.12.0, `flutter_animate: ^4.5.2`, `fl_chart: ^1.2.0`, `google_fonts: ^8.2.1`, `flutter_riverpod: ^2.6.1`.

## Global Constraints
- Tuân thủ nghiêm ngặt quy định thương mại B2B SaaS Vivona (`AGENTS.md`, `coding-rules.md`, `design-rules.md`).
- Toàn bộ commit thực hiện trực tiếp trên nhánh `main`.
- Không sử dụng package cộng đồng trôi nổi không được xác thực; tận dụng `flutter_animate`, `fl_chart` đã cài sẵn.
- Mọi widget mới tạo phải tuân thủ tokens `AppSpacing`, `AppRadius`, `AppTheme` và được đưa vào whitelist của `test/core/theme_and_color_guard_test.dart`.

---

## Danh Sách Công Việc (Task Breakdown)

### Task 1: Xây Dựng Hệ Thống Phản Hồi Xúc Giác `AppHaptics` & Micro-Interaction `Bounceable`
**Files:**
- Create: `lib/core/utils/app_haptics.dart`
- Create: `lib/core/widgets/bounceable.dart`
- Create: `test/core/utils/app_haptics_test.dart`
- Create: `test/core/widgets/bounceable_test.dart`

- [x] **Step 1: Viết test cho `AppHaptics` & `Bounceable`**
  - Test `AppHaptics` gọi đúng platform haptic channel tương ứng (`lightImpact`, `mediumImpact`, `heavyImpact`, `selectionClick`).
  - Test `Bounceable` render con đúng, khi tap xuống scale nhỏ lại, khi thả trở về 1.0 và kích hoạt callback `onTap`.
- [x] **Step 2: Triển khai `AppHaptics`**
  - Cung cấp các static methods: `light()`, `medium()`, `heavy()`, `selection()`, `success()`, `error()`.
- [x] **Step 3: Triển khai widget `Bounceable`**
  - Sử dụng `GestureDetector` / `Listener` kết hợp `AnimatedScale` hoặc `TweenAnimationBuilder` với spring curve (`Curves.easeOutCubic`).
  - Tích hợp gọi `AppHaptics.light()` mặc định khi nhấn.
- [x] **Step 4: Chạy test xác nhận pass**
  - Chạy `flutter test test/core/utils/app_haptics_test.dart test/core/widgets/bounceable_test.dart`.
- [x] **Step 5: Commit code**
  - Commit message: `feat(core): xay dung dong co phan hoi xuc giac app_haptics va widget bounceable`

---

### Task 2: Xây Dựng Thư Viện Chuyển Động Lò Xo `AppSpringMotion` & Staggered Animations
**Files:**
- Create: `lib/core/motion/app_spring_motion.dart`
- Create: `test/core/motion/app_spring_motion_test.dart`

- [x] **Step 1: Viết test cho `AppSpringMotion`**
  - Kiểm tra các extension animations (`animateSpringEntry`, `animateStaggeredItem`, `animatePulseHighlight`) trả về Widget hợp lệ có bọc `Animate`.
- [x] **Step 2: Triển khai `AppSpringMotion`**
  - Tạo các extension methods trên `Widget` sử dụng `flutter_animate`:
    - `animateSpringEntry({Duration delay = Duration.zero, Duration duration = const Duration(milliseconds: 500)})`: Fade-in + Slide-up (offset 0, 0.08) với lò xo nhẹ.
    - `animateStaggeredItem({required int index, Duration baseDelay = const Duration(milliseconds: 40)})`: Xuất hiện so le tự nhiên trong danh sách hoặc lưới.
    - `animatePulseHighlight()`: Nhấp nháy nhẹ cho badge cảnh báo hoặc nút thanh toán khẩn cấp.
- [x] **Step 3: Chạy test xác nhận pass**
  - Chạy `flutter test test/core/motion/app_spring_motion_test.dart`.
- [x] **Step 4: Commit code**
  - Commit message: `feat(core): xay dung thu vien chuyen dong lo xo app_spring_motion`

---

### Task 3: Triển Khai Hiệu Ứng Kính Tiết Chế `AppGlassCard` & `FrostedAppBar`
**Files:**
- Create: `lib/core/widgets/app_glass.dart`
- Create: `test/core/widgets/app_glass_test.dart`

- [x] **Step 1: Viết test cho `AppGlassCard`**
  - Kiểm tra cấu trúc phân cấp: có chứa `ClipRRect`, `BackdropFilter` với blur sigma hợp lệ, và màu nền thích ứng theo Brightness (Light vs Dark).
- [x] **Step 2: Triển khai `AppGlassCard`**
  - Widget hỗ trợ blur sigma tùy chỉnh (mặc định 10), bán kính bo góc tùy chỉnh (mặc định `AppRadius.rLg`), viền kính mỏng tinh tế, và tối ưu hóa hiệu năng để không drop FPS.
- [x] **Step 3: Chạy test xác nhận pass**
  - Chạy `flutter test test/core/widgets/app_glass_test.dart`.
- [x] **Step 4: Commit code**
  - Commit message: `feat(core): trien khai component hieu ung kinh tiet che app_glass`

---

### Task 4: Xây Dựng Thẻ Biểu Đồ Tiêu Thụ Điện Nước Cư Dân (`ResidentUtilityConsumptionChartCard`)
**Files:**
- Create: `lib/features/resident/widgets/home/resident_utility_consumption_chart_card.dart`
- Create: `test/features/resident/widgets/resident_utility_consumption_chart_card_test.dart`

- [x] **Step 1: Viết test cho Thẻ biểu đồ tiêu thụ điện nước**
  - Kiểm tra render tiêu đề "Mức tiêu thụ điện & nước", thanh chuyển đổi tab Điện/Nước, biểu đồ `BarChart` hoặc `LineChart`, và thống kê so sánh tháng trước.
- [x] **Step 2: Triển khai `ResidentUtilityConsumptionChartCard`**
  - Sử dụng thư viện `fl_chart` đã có trong dự án.
  - Tích hợp dữ liệu biểu đồ mẫu/từ invoice items (điện, nước 6 tháng gần nhất).
  - Có nút chuyển đổi tab xem "Điện (kWh)" và "Nước (m³)" mượt mà kèm `AppHaptics.selection()`.
  - Thiết kế theo chuẩn Bento Grid card với bo góc `AppRadius.rLg` và spacing `AppSpacing`.
- [x] **Step 3: Chạy test xác nhận pass**
  - Chạy `flutter test test/features/resident/widgets/resident_utility_consumption_chart_card_test.dart`.
- [x] **Step 4: Commit code**
  - Commit message: `feat(resident): xay dung the bento bieu do tieu thu dien nuoc cu dan`

---

### Task 5: Tái Cấu Trúc Toàn Diện Trang Chủ Cư Dân Sang Bento Grid 2026
**Files:**
- Modify: `lib/features/resident/screens/resident_home_screen.dart`
- Modify: `lib/features/resident/widgets/home/resident_home_header_widget.dart`
- Modify: `lib/features/resident/widgets/home/resident_home_quick_actions_grid.dart`
- Modify: `lib/features/resident/widgets/home/resident_home_upcoming_invoice_card.dart`
- Modify: `test/features/resident/resident_home_hierarchy_test.dart`

- [x] **Step 1: Nâng cấp `resident_home_header_widget.dart`**
  - Thêm hiệu ứng kính nhẹ, hiển thị badge thông báo mới kèm pulse animation, bọc avatar/nút với `Bounceable`.
- [x] **Step 2: Nâng cấp `resident_home_quick_actions_grid.dart`**
  - Thiết kế 4 ô vuông Bento với bo góc lớn (`AppRadius.rXl`), icon gradient hiện đại, bọc `Bounceable` có phản hồi xúc giác `AppHaptics.light()`, hiệu ứng xuất hiện so le `animateStaggeredItem`.
- [x] **Step 3: Nâng cấp `resident_home_upcoming_invoice_card.dart`**
  - Chuyển thành Hero Bento Card: hiển thị số tiền nổi bật, hạn thanh toán rõ nét, nút "Thanh toán ngay" gradient nổi bật với `Bounceable`.
- [x] **Step 4: Tích hợp Bento Layout vào `resident_home_screen.dart`**
  - Sắp xếp phân tầng: Header $\rightarrow$ Hero Invoice $\rightarrow$ Utility Consumption Mini Chart $\rightarrow$ Bento Quick Actions $\rightarrow$ Hoạt động & Sự cố gần đây.
  - Áp dụng hiệu ứng `animateSpringEntry` toàn màn hình.
- [x] **Step 5: Cập nhật & chạy test màn hình Trang chủ cư dân**
  - Chạy `flutter test test/features/resident/resident_home_hierarchy_test.dart test/core/theme_and_color_guard_test.dart`.
- [x] **Step 6: Commit code**
  - Commit message: `feat(resident): tai cau truc trang chu cu dan thanh bento grid 2026 voi spring motion`

---

### Task 6: Tối Ưu Bento Dashboard Cho Ban Quản Lý (`ManagementHomeScreen`)
**Files:**
- Modify: `lib/features/management/screens/management_home_screen.dart`
- Modify: `lib/features/management/widgets/home/management_financial_progress_card.dart`
- Modify: `lib/features/management/widgets/home/management_recent_transactions_card.dart`
- Modify: `test/features/management/management_home_wireframe_test.dart`

- [x] **Step 1: Tối ưu các thẻ KPI và biểu đồ BQL thành hệ thống Bento**
  - Bổ sung hiệu ứng xuất hiện lò xo `animateSpringEntry`.
  - Thêm `Bounceable` và `AppHaptics` vào các nút duyệt nhanh, lọc và chuyển đổi kỳ báo cáo.
- [x] **Step 2: Tối ưu khả năng hiển thị responsive thích ứng**
  - Trên màn rộng (desktop/tablet): sắp xếp Bento 2-3 cột cân đối.
  - Trên màn hẹp (mobile): bố cục Bento dọc tối ưu hóa không gian hiển thị thông số trọng yếu.
- [x] **Step 3: Chạy test xác nhận pass**
  - Chạy `flutter test test/features/management/management_home_wireframe_test.dart`.
- [x] **Step 4: Commit code**
  - Commit message: `feat(management): toi uu dashboard bql theo kien truc bento kpi 2026`

---

### Task 7: Kiểm Thử Toàn Diện, Guardrails & Cập Nhật Tri Thức AST
- [x] **Step 1: Mở rộng Whitelist cho Guard Test**
  - Thêm các widgets mới (`app_glass.dart`, `bounceable.dart`, `resident_utility_consumption_chart_card.dart`, `resident_home_upcoming_invoice_card.dart`, `resident_home_quick_actions_row.dart`) vào `targetModulesWhitelist`.
- [x] **Step 2: Chạy kiểm tra phân tích tĩnh toàn bộ dự án**
  - Chạy `dart analyze lib test`. Đảm bảo `No issues found!`.
- [x] **Step 3: Chạy toàn bộ test suites**
  - Chạy `flutter test`. Đảm bảo 100% tests passed.
- [x] **Step 4: Cập nhật tri thức codebase qua Graphify**
  - Chạy `graphify update .`.
- [x] **Step 5: Báo cáo hoàn thành Giai đoạn 1**

