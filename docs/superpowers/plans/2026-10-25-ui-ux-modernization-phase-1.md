# Kế Hoạch Triển Khai: Cải Tiến Giao Diện & Trải Nghiệm Người Dùng (Đợt 1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hiện đại hóa cấu trúc và khả năng sử dụng của phân hệ Ban quản lý và Cư dân (Đợt 1: A1, A2, A5, A6, U1, B1), xóa bỏ cuộn ngang thừa, phân tầng thị giác khoa học, tối ưu bộ lọc tìm kiếm và đảm bảo hiển thị hoàn hảo trên màn hình hẹp (từ 360dp).

**Architecture:** Áp dụng kiến trúc Feature-first trong Flutter. Giữ nguyên 100% logic dữ liệu, Riverpod providers và phân quyền RBAC. Sử dụng Modal Bottom Sheet cho thao tác mở rộng và bộ lọc, tái cấu trúc Dashboard/Home theo mức độ ưu tiên thông tin, bảo đảm tính tương thích responsive.

**Tech Stack:** Flutter 3.x, Flutter Riverpod, GoRouter, Material Design 3.

## Global Constraints
- 100% tiếng Việt chuẩn mực, thuật ngữ tự nhiên theo `design-rules.md`.
- Giữ nguyên toàn bộ logic dữ liệu và phân quyền RBAC (Role-based Access Control).
- Không để xảy ra lỗi RenderFlex overflow hoặc cắt chữ ở chiều rộng 360dp trở lên.
- Commit trực tiếp vào nhánh `main` với Conventional Commits theo quy định dự án.
- Tất cả các kiểm thử `flutter test` và `flutter analyze` phải đạt 100% trước khi kết thúc.

---

### Task 1: A1 - Tái cấu trúc Thao tác nhanh Dashboard & Modal Bottom Sheet phân nhóm

**Files:**
- Modify: `lib/features/management/screens/management_home_screen.dart`
- Test: `test/features/management/dashboard_quick_actions_test.dart`

**Interfaces:**
- Consumes: `currentUser.isAdmin`, `canManageInvoices`, `canManageIssues`, `canManageMeterReadings`, `canManageHandbook`, `canManageAmenities`, `canManageEquipment`, `canApproveVehicles`, `canViewPaymentTransactions`
- Produces: `_buildQuickActionsGrid(BuildContext context, ...)`, `_showAllQuickActionsSheet(BuildContext context, ...)`

- [ ] **Step 1: Viết test kiểm tra Thao tác nhanh dạng Lưới và Modal Bottom Sheet**
Tạo file `test/features/management/dashboard_quick_actions_test.dart` kiểm tra hiển thị 5 lối tắt chính, nút "Xem tất cả", và khi chạm "Xem tất cả" mở Bottom Sheet có đầy đủ 3 nhóm (Cư dân, Tài chính, Vận hành).

- [ ] **Step 2: Chạy test để xác nhận test fail**
Chạy `flutter test test/features/management/dashboard_quick_actions_test.dart`.

- [ ] **Step 3: Cập nhật `management_home_screen.dart` cho A1**
Thay thế `SingleChildScrollView(scrollDirection: Axis.horizontal)` của Thao tác nhanh bằng:
1. Lưới 2 cột hoặc hàng thẻ 5 lối tắt chính thường dùng:
   - Duyệt liên kết (nếu có quyền, có badge `pendingLinkRequestsCountProvider`).
   - Xử lý sự cố (nếu có quyền, có badge `pendingIssuesCountProvider`).
   - Lập hóa đơn (nếu có quyền).
   - Duyệt điện nước (nếu có quyền, có badge `pendingMeterReadingsCountProvider`).
   - Duyệt xe (nếu có quyền).
   - Thẻ thứ 6: "Xem tất cả" (`Icons.apps_rounded`) mở Modal Bottom Sheet.
2. Hàm `_showAllQuickActionsSheet()`: Nhóm theo Cư dân & Căn hộ, Tài chính & Thu phí, Vận hành & Kỹ thuật, tôn trọng quyền RBAC.

- [ ] **Step 4: Chạy lại test để xác nhận pass**
Chạy `flutter test test/features/management/dashboard_quick_actions_test.dart`.

- [ ] **Step 5: Commit task A1**
`git add lib/features/management/screens/management_home_screen.dart test/features/management/dashboard_quick_actions_test.dart`
`git commit -m "feat(dashboard): tái cấu trúc thao tác nhanh và modal bottom sheet nhóm quyền A1"`

---

### Task 2: A2 - Phân tầng Thông tin Dashboard Admin theo mức độ khẩn cấp

**Files:**
- Modify: `lib/features/management/screens/management_home_screen.dart`
- Test: `test/features/management/dashboard_hierarchy_test.dart`

**Interfaces:**
- Consumes: `allIssuesAsync`, `pendingConfirmationInvoicesProvider`, `pendingLinkRequestsCountProvider`, `financialStatsProvider`
- Produces: `_buildActionableSection(...)`, `_buildResidentStatsSection(...)`, `_buildFinanceSection(...)`, `_buildOperationsSection(...)`

- [ ] **Step 1: Viết test kiểm tra phân tầng thông tin Dashboard**
Tạo file `test/features/management/dashboard_hierarchy_test.dart` xác minh thứ tự hiển thị: Công việc cần xử lý ngay ở trên đầu, tiếp theo là Cư dân, Tài chính và Vận hành.

- [ ] **Step 2: Chạy test để xác nhận test fail**
Chạy `flutter test test/features/management/dashboard_hierarchy_test.dart`.

- [ ] **Step 3: Triển khai phân tầng trong `management_home_screen.dart`**
1. **Tầng 1 - Công việc cần xử lý ngay:**
   - Đặt ngay dưới Thao tác nhanh.
   - Thống kê & hiển thị các mục: Phản ánh sự cố khẩn cấp (`priority: high/urgent`), Hóa đơn chờ xác nhận (`pending_confirmation`), Yêu cầu liên kết căn hộ chờ duyệt.
   - Thêm nút tắt "Xem ngay" dẫn thẳng đến danh sách chi tiết của nghiệp vụ đó.
2. **Tầng 2 - Cư dân & Căn hộ:** Thống kê Căn hộ, Cư dân, Tỷ lệ lấp đầy.
3. **Tầng 3 - Tài chính & Thu phí:** Tiến độ thu phí, Biểu đồ doanh thu, Quỹ bảo trì, Giao dịch gần đây.
4. **Tầng 4 - Vận hành & Kỹ thuật:** Sự cố đang giải quyết, bảo trì thiết bị.

- [ ] **Step 4: Chạy test xác nhận pass**
Chạy `flutter test test/features/management/dashboard_hierarchy_test.dart`.

- [ ] **Step 5: Commit task A2**
`git add lib/features/management/screens/management_home_screen.dart test/features/management/dashboard_hierarchy_test.dart`
`git commit -m "feat(dashboard): phân tầng thông tin nghiệp vụ và ưu tiên việc cần xử lý A2"`

---

### Task 3: A5 - Tối ưu Bộ lọc Quản lý Cư dân

**Files:**
- Modify: `lib/features/management/screens/resident_management_screen.dart`
- Test: `test/features/management/resident_management_filter_test.dart`

**Interfaces:**
- Consumes: `_selectedRoleFilter`, `_selectedStatusFilter`, `_searchQuery`, `residentsAsync`
- Produces: `_showResidentFilterSheet(BuildContext context)`, `_buildActiveFilterChips()`

- [ ] **Step 1: Viết test cho bộ lọc quản lý cư dân**
Tạo file `test/features/management/resident_management_filter_test.dart` kiểm tra:
- Nút "Bộ lọc" mở Bottom Sheet có lưu trạng thái tạm thời, có nút "Đặt lại" và "Áp dụng".
- Hiển thị dòng kết quả: "Hiển thị X/Y người dùng".
- Hiển thị active filter chips khi áp dụng bộ lọc và có thể xóa nhanh từng tiêu chí.

- [ ] **Step 2: Chạy test để xác nhận test fail**
Chạy `flutter test test/features/management/resident_management_filter_test.dart`.

- [ ] **Step 3: Cập nhật `resident_management_screen.dart` cho A5**
1. Thay 2 hàng chip cuộn ngang dài bằng 1 hàng công cụ tinh gọn:
   - Nút `OutlinedButton.icon` "Bộ lọc" (có badge đếm số bộ lọc đang chọn).
   - Dòng văn bản đếm số lượng: `Hiển thị ${filteredResidents.length}/${allResidents.length} người dùng`.
2. Hàng Active Chips hiển thị các điều kiện đang áp dụng (Vai trò / Trạng thái) với nút `x` xóa trực tiếp.
3. Hàm `_showResidentFilterSheet`: Modal Bottom Sheet lưu trạng thái tạm thời trong `StatefulBuilder`, nút "Đặt lại" đưa về `all`, nút "Áp dụng" cập nhật state màn hình.

- [ ] **Step 4: Chạy test xác nhận pass**
Chạy `flutter test test/features/management/resident_management_filter_test.dart`.

- [ ] **Step 5: Commit task A5**
`git add lib/features/management/screens/resident_management_screen.dart test/features/management/resident_management_filter_test.dart`
`git commit -m "feat(resident): tối ưu bộ lọc cư dân với bottom sheet và active chips A5"`

---

### Task 4: A6 - Tối ưu Bộ lọc và Thẻ Hóa đơn Admin

**Files:**
- Modify: `lib/features/management/screens/invoice_management_screen.dart`
- Test: `test/features/management/invoice_management_filter_test.dart`

**Interfaces:**
- Consumes: `invoicesAsync`, `_statusFilter`, `_searchQuery`
- Produces: Bộ đếm số lượng trên từng chip lọc, highlight chờ xác nhận, menu thao tác phụ AppBar.

- [ ] **Step 1: Viết test cho bộ đếm và trạng thái lọc hóa đơn**
Tạo file `test/features/management/invoice_management_filter_test.dart` kiểm tra nhãn bộ lọc hiển thị đúng số lượng hóa đơn theo từng trạng thái: `Tất cả (N)`, `Chờ xác nhận (N)`, `Đang nợ (N)`, `Đã thanh toán (N)`.

- [ ] **Step 2: Chạy test để xác nhận test fail**
Chạy `flutter test test/features/management/invoice_management_filter_test.dart`.

- [ ] **Step 3: Cập nhật `invoice_management_screen.dart` cho A6**
1. Tính số lượng hóa đơn theo từng trạng thái từ danh sách gốc.
2. Hiển thị nhãn bộ lọc có đếm số:
   - `Tất cả (${invoices.length})`
   - `Chờ xác nhận (${countPending})` với màu hổ phách `AppStatusColors.pendingConfirmation`.
   - `Đang nợ (${countUnpaid})` với màu đỏ cam.
   - `Đã thanh toán (${countPaid})` với màu xanh lá.
3. Chuyển các nút phụ trên AppBar (Tạo HĐ hàng loạt, Xuất Excel) sang `PopupMenuButton` trên màn hình nhỏ hoặc nhóm thao tác gọn gàng.
4. Làm nổi bật các thẻ hóa đơn có trạng thái `pending_confirmation` để phục vụ đối soát nhanh chóng.

- [ ] **Step 4: Chạy test xác nhận pass**
Chạy `flutter test test/features/management/invoice_management_filter_test.dart`.

- [ ] **Step 5: Commit task A6**
`git add lib/features/management/screens/invoice_management_screen.dart test/features/management/invoice_management_filter_test.dart`
`git commit -m "feat(invoice): tối ưu bộ lọc đếm số lượng và highlight đối soát hóa đơn A6"`

---

### Task 5: U1 - Tái cấu trúc Bố cục Trang chủ Cư dân (`resident_home_screen.dart`)

**Files:**
- Modify: `lib/features/resident/screens/resident_home_screen.dart`
- Test: `test/features/resident/resident_home_hierarchy_test.dart`

**Interfaces:**
- Consumes: `residentInvoiceProvider`, `residentAnnouncementsProvider`, `residentIssueProvider`, `unreadNotificationsCountProvider`
- Produces: Cấu trúc hiển thị theo mức độ ưu tiên 5 cấp.

- [ ] **Step 1: Viết test cho cấu trúc trang chủ cư dân**
Tạo file `test/features/resident/resident_home_hierarchy_test.dart` kiểm tra thứ tự hiển thị:
1. Đầu trang (Chào, căn hộ, thông báo).
2. Ưu tiên Hóa đơn (Tổng quan hóa đơn nằm ngay sau đầu trang).
3. Cảnh báo gián đoạn & Thông báo.
4. Thao tác nhanh (Lưới 4 ô đồng đều).
5. Dịch vụ & Tiện ích.

- [ ] **Step 2: Chạy test để xác nhận test fail**
Chạy `flutter test test/features/resident/resident_home_hierarchy_test.dart`.

- [ ] **Step 3: Cập nhật `resident_home_screen.dart` cho U1**
1. Đưa nút đăng xuất ra khỏi AppBar đầu trang (chuyển vào menu trang Tài khoản `resident_profile_screen.dart`) để giải phóng không gian.
2. Đẩy thẻ **Tổng quan hóa đơn** lên ngay sau SliverAppBar để cư dân nhìn thấy việc cần làm đầu tiên.
3. Tiếp theo là **Cảnh báo gián đoạn dịch vụ** (`EquipmentInterruptionBanner`) và thông báo khẩn cấp.
4. Gom 4 thao tác nhanh thành **Lưới đồng đều** (Thanh toán, Báo sự cố, Hotline, Cẩm nang).
5. Cuối cùng là khu vực **Dịch vụ & Tiện ích**.

- [ ] **Step 4: Chạy test xác nhận pass**
Chạy `flutter test test/features/resident/resident_home_hierarchy_test.dart`.

- [ ] **Step 5: Commit task U1**
`git add lib/features/resident/screens/resident_home_screen.dart test/features/resident/resident_home_hierarchy_test.dart`
`git commit -m "feat(resident): tái cấu trúc trang chủ cư dân ưu tiên hóa đơn và lưới thao tác U1"`

---

### Task 6: B1 - Đảm bảo Responsive Toàn Diện & Kiểm thử Hồi quy

**Files:**
- Modify: Các file điều chỉnh giao diện nếu phát hiện tràn.
- Test: `test/integration/ui_responsive_and_accessibility_test.dart`

- [ ] **Step 1: Viết test responsive trên kích thước 360dp width**
Tạo file `test/integration/ui_responsive_and_accessibility_test.dart` kiểm tra cả `ManagementHomeScreen` và `ResidentHomeScreen` ở kích cỡ 360x640:
- Không ném bất kỳ ngoại lệ `RenderFlex overflow` nào.
- Toàn bộ các thẻ và tiêu đề hiển thị ổn định.

- [ ] **Step 2: Chạy kiểm thử responsive và khắc phục nếu có lỗi**
Chạy `flutter test test/integration/ui_responsive_and_accessibility_test.dart`.

- [ ] **Step 3: Chạy toàn bộ test suite và phân tích tĩnh**
- `flutter analyze` bảo đảm 0 issues.
- `flutter test` bảo đảm toàn bộ test suite vượt qua 100%.

- [ ] **Step 4: Commit task B1**
`git add .`
`git commit -m "test(ui): hoàn tất kiểm thử responsive 360dp và không có renderflex overflow B1"`
`git push origin main`
