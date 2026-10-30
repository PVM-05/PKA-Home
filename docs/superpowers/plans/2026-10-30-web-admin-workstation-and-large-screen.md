# Kế Hoạch Thực Thi: Dashboard Web Quản Trị & Trạm Làm Việc Kế Toán Màn Hình Lớn (B4)

- **Giai đoạn:** B4 (trong `COMMERCIAL_PRODUCT_ROADMAP.md`)
- **Tài liệu đặc tả:** [docs/superpowers/specs/2026-10-30-web-admin-workstation-and-large-screen-design.md](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/superpowers/specs/2026-10-30-web-admin-workstation-and-large-screen-design.md)
- **Quy chuẩn thực thi:** TDD (Test-Driven Development), cam kết commit trực tiếp vào `main`.

---

## Danh Sách Tasks

### [x] Task 1: Adaptive Navigation Layout Widget & Test
- **Mục tiêu:** Tạo widget `AdaptiveManagementScaffold` tự động phân tách breakpoint $900\text{dp}$. Khi width $\ge 900\text{dp}$, hiển thị Sidebar cố định chuyên nghiệp bên trái; khi $< 900\text{dp}$, hiển thị giao diện Mobile chuẩn.
- **Files:**
  - `test/core/widgets/adaptive_management_scaffold_test.dart`
  - `lib/core/widgets/adaptive_management_scaffold.dart`
- **Các bước:**
  1. Viết failing widget test `test/core/widgets/adaptive_management_scaffold_test.dart`.
  2. Tạo `lib/core/widgets/adaptive_management_scaffold.dart`.
  3. Chạy `flutter test test/core/widgets/adaptive_management_scaffold_test.dart` -> PASS.
  4. Commit: `feat(widgets): adaptive management scaffold tu dong phan tach sidebar web va mobile B4`.

### [x] Task 2: Data Models & Providers Cho Kế Toán Bàn Làm Việc
- **Mục tiêu:** Xây dựng các model và provider phục vụ trạm làm việc kế toán: `AccountingWorkstationFilter`, `AccountingWorkstationSummary`, `InvoiceTableRowItem` và `accounting_workstation_provider.dart`.
- **Files:**
  - `test/data/models/accounting_workstation_model_test.dart`
  - `lib/data/models/accounting_workstation_model.dart`
  - `lib/data/providers/accounting_workstation_provider.dart`
- **Các bước:**
  1. Viết failing test `test/data/models/accounting_workstation_model_test.dart`.
  2. Tạo `lib/data/models/accounting_workstation_model.dart` và `lib/data/providers/accounting_workstation_provider.dart`.
  3. Chạy `flutter test test/data/models/accounting_workstation_model_test.dart` -> PASS.
  4. Commit: `feat(data): them accounting workstation models va providers B4`.

### [x] Task 3: Giao Diện Bàn Làm Việc Kế Toán & Bảng Đối Soát Lớn
- **Mục tiêu:** Xây dựng màn hình `AccountingWebWorkstationScreen` tối ưu cho máy tính/web:
  - Thanh KPI Strip tài chính trên đầu.
  - Bộ lọc đa tiêu chí tức thời (tìm kiếm, kỳ thu, trạng thái).
  - Bảng dữ liệu nhiều cột `DataTable` có cuộn 2 chiều, sắp xếp và phân trang.
  - Thanh thao tác hàng loạt (Bulk Actions Bar): Gửi nhắc nợ hàng loạt, xuất file Excel đối soát.
- **Files:**
  - `test/features/management/screens/accounting_web_workstation_screen_test.dart`
  - `lib/features/management/screens/accounting_web_workstation_screen.dart`
- **Các bước:**
  1. Viết failing widget test `test/features/management/screens/accounting_web_workstation_screen_test.dart`.
  2. Tạo `lib/features/management/screens/accounting_web_workstation_screen.dart`.
  3. Chạy test `test/features/management/screens/accounting_web_workstation_screen_test.dart` -> PASS.
  4. Commit: `feat(ui): man hinh tram lam viec ke toan bang doi soat lon B4`.

### [x] Task 4: Tích Hợp Vào ManagementHomeScreen & Đăng Ký Route
- **Mục tiêu:** Kết nối `AdaptiveManagementScaffold` vào `ManagementHomeScreen`, tích hợp tab Bàn làm việc Kế toán trên Sidebar Desktop/Web và đăng ký route `AppRoutes.managementAccountingWorkstation`.
- **Files:**
  - `lib/core/router/route_names.dart`
  - `lib/core/router/app_router.dart`
  - `lib/features/management/screens/management_home_screen.dart`
- **Các bước:**
  1. Đăng ký route trong `route_names.dart` và `app_router.dart`.
  2. Cập nhật `management_home_screen.dart` hỗ trợ Sidebar trên màn hình rộng $\ge 900\text{dp}$.
  3. Commit: `feat(management): tich hop sidebar web va tram lam viec ke toan vao dashboard B4`.

### [x] Task 5: Integration & Responsive Verification Test
- **Mục tiêu:** Kiểm tra tích hợp toàn diện trên màn hình di động $400\text{dp}$ và màn hình máy tính $1280\text{dp}$.
- **Files:**
  - `test/integration/web_workstation_responsive_test.dart`
- **Các bước:**
  1. Viết và chạy test `test/integration/web_workstation_responsive_test.dart` -> PASS.
  2. Commit: `test(integration): kiem thu responsive web workstation tren desktop va mobile B4`.

### [x] Task 6: Verification & Quality Gate
- **Mục tiêu:** Đảm bảo toàn bộ hệ thống đạt 0 issue static analysis, 100% tests pass, cập nhật Graphify Knowledge Graph và roadmap thương mại.
- **Các bước:**
  1. Chạy `dart analyze` (đạt 0 issue - No issues found!).
  2. Chạy `flutter test` (đảm bảo 100% tests pass).
  3. Chạy `python -m graphify update .` để đồng bộ Knowledge Graph.
  4. Cập nhật `docs/COMMERCIAL_PRODUCT_ROADMAP.md` đánh dấu `[x] B4. Dashboard Web Quản Trị`.
  5. Commit hoàn tất Giai đoạn B4 vào `main`.
