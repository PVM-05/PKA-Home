# Kế Hoạch Triển Khai: Khắc Phục Toàn Diện 5 Điểm Nghẽn UX & Chức Năng (P1 Hardening)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Giải quyết dứt điểm 5 vấn đề cốt lõi về trải nghiệm người dùng và an toàn dữ liệu đã được rà soát: sửa khớp icon/nhãn điều hướng, khắc phục Dark Mode cho tra cứu tài liệu, chuẩn hóa Inline Validation tại chỗ, bảo vệ dữ liệu chưa lưu bằng `PopScope`, và thiết lập cơ chế phân trang (Pagination) cuộn vô tận cho các danh sách lớn.

**Tech Stack:** Flutter 3.44.0 / SDK ^3.12.0, Flutter Riverpod 2.6.1, Flutter Test.

## Global Constraints
- Tuân thủ quy định thương mại B2B SaaS Vivona (`AGENTS.md`, `coding-rules.md`, `design-rules.md`).
- Toàn bộ commit thực hiện trực tiếp trên nhánh `main`.
- Duy trì 100% zero-regression trên toàn bộ test suites hiện hữu.

---

## Danh Sách Công Việc (Task Breakdown)

### Task 1: Sửa Khớp Icon/Nhãn Quick Actions & Dark Mode Tra Cứu Tài Liệu
**Files:**
- Modify: `lib/features/resident/widgets/home/resident_home_quick_actions_row.dart`
- Modify: `lib/features/document/screens/document_lookup_screen.dart`
- Modify: `test/features/resident/resident_home_hierarchy_test.dart`
- Modify: `test/features/document/screens/document_lookup_screen_test.dart`

- [x] **Step 1: Cập nhật icon và nhãn tại `resident_home_quick_actions_row.dart`**
  - Đổi `Icons.qr_code_scanner` $\rightarrow$ `Icons.receipt_long_rounded`.
  - Đổi nhãn `'Thanh toán'` $\rightarrow$ `'Hóa đơn'`.
- [x] **Step 2: Cập nhật Dark Mode thích ứng tại `document_lookup_screen.dart`**
  - Loại bỏ các mã màu hardcode `0xFFF0FDF4` (Green 50), `0xFF15803D`...
  - Sử dụng `colorScheme.surfaceContainer` và `AppStatusColors.getPaid(context)` / `getUnpaid(context)`.
- [x] **Step 3: Chạy test xác nhận pass**
  - Chạy `flutter test test/features/document/ test/features/resident/resident_home_hierarchy_test.dart`.
- [x] **Step 4: Commit code**
  - Commit message: `fix(ux): dong bo icon hoa don trang chu va hoan thien dark mode tra cuu tai lieu` (Commit `cdfb678`)

---

### Task 2: Chuẩn Hóa Inline Form Validation Cho Màn Hình Tạo Sự Cố
**Files:**
- Modify: `lib/features/resident/screens/create_issue_screen.dart`
- Create: `test/features/resident/screens/create_issue_validation_test.dart`

- [x] **Step 1: Viết test cho inline validation trong `create_issue_screen.dart`**
  - Test khi bấm gửi với ô mô tả trống $\rightarrow$ hiển thị chữ báo lỗi inline dưới ô mô tả ("Vui lòng nhập chi tiết mô tả sự cố").
  - Test khi đã nhập mô tả $\rightarrow$ không còn hiển thị lỗi inline.
- [x] **Step 2: Triển khai `Form` và `TextFormField` trong `create_issue_screen.dart`**
  - Khai báo `_formKey = GlobalKey<FormState>()`.
  - Thay `TextField` mô tả bằng `TextFormField` kèm `validator`.
  - Kiểm tra `_formKey.currentState!.validate()` khi submit.
- [x] **Step 3: Chạy test xác nhận pass**
  - Chạy `flutter test test/features/resident/screens/create_issue_validation_test.dart`.
- [x] **Step 4: Commit code**
  - Đã commit trong commit `92f6878`.

---

### Task 3: Xây Dựng `AppUnsavedChangesGuard` (`PopScope`) Bảo Vệ Dữ Liệu Biểu Mẫu
**Files:**
- Create: `lib/core/widgets/app_unsaved_changes_guard.dart`
- Modify: `lib/features/resident/screens/create_issue_screen.dart`
- Modify: `lib/features/resident/screens/edit_issue_screen.dart`
- Create: `test/core/widgets/app_unsaved_changes_guard_test.dart`

- [x] **Step 1: Viết test cho `AppUnsavedChangesGuard`**
  - Test khi `hasUnsavedChanges == false`: Cho phép pop bình thường không hiển thị dialog.
  - Test khi `hasUnsavedChanges == true`: Chặn pop và hiển thị dialog xác nhận. Bấm "Tiếp tục nhập" giữ nguyên trang, bấm "Rời khỏi" cho phép pop.
- [x] **Step 2: Triển khai `AppUnsavedChangesGuard`**
  - Sử dụng `PopScope` chuẩn Flutter 3.44+ với `canPop: !hasUnsavedChanges`.
  - Hộp thoại giao diện tiếng Việt chuẩn mực, hỗ trợ Dark Mode.
- [x] **Step 3: Tích hợp `AppUnsavedChangesGuard` vào `create_issue_screen` và `edit_issue_screen`**
  - Xác định trạng thái đã thay đổi dựa trên text mô tả hoặc ảnh đính kèm.
- [x] **Step 4: Chạy test xác nhận pass**
  - Chạy `flutter test test/core/widgets/app_unsaved_changes_guard_test.dart`.
- [x] **Step 5: Commit code**
  - Commit message: `feat(resident): chuan hoa inline validation va bao ve du lieu form bang popscope` (Commit `92f6878`)

---

### Task 4: Triển Khai Kiến Trúc Phân Trang (Pagination) Cho Hóa Đơn & Phản Ánh Sự Cố
**Files:**
- Create: `lib/core/models/paginated_list.dart`
- Modify: `lib/data/repositories/issue_repository.dart`
- Modify: `lib/data/providers/resident_issue_provider.dart`
- Modify: `lib/data/providers/resident_invoice_provider.dart`
- Modify: `lib/features/resident/screens/resident_issue_screen.dart`
- Modify: `lib/features/resident/screens/resident_invoice_screen.dart`
- Create: `test/core/models/paginated_list_test.dart`

- [x] **Step 1: Tạo model `PaginatedList<T>`**
  - Thuộc tính: `items`, `page`, `pageSize`, `hasMore`, `isLoadingMore`.
  - Viết unit test cho `PaginatedList`.
- [x] **Step 2: Bổ sung phân trang `limit` & `offset` vào `IssueRepository.fetchIssues`**
  - Sử dụng `.range(offset, offset + limit - 1)` của Supabase PostgREST client.
- [x] **Step 3: Cập nhật `residentIssuePaginatedProvider` và `residentInvoicePaginatedProvider` hỗ trợ phân trang & loadMore**
  - Cung cấp phương thức `loadMore()` tải trang tiếp theo (20 items/page).
  - Duy trì `residentIssueProvider` và `residentInvoiceProvider` tương thích ngược 100%.
- [x] **Step 4: Tích hợp Infinite Scroll vào `ResidentIssueScreen` và `ResidentInvoiceScreen`**
  - Lắng nghe `NotificationListener<ScrollNotification>` và kích hoạt `loadMore()` khi cuộn xuống gần đáy.
- [x] **Step 5: Chạy test xác nhận pass**
  - Chạy `flutter test test/core/models/paginated_list_test.dart test/features/resident/screens/resident_issue_adaptive_test.dart test/features/resident/screens/resident_invoice_adaptive_test.dart`.
- [x] **Step 6: Commit code**
  - Commit message: `feat(pagination): trien khai kien truc phan trang cuon vo tan cho hoa don va su co`

---

### Task 5: Nghiệm Thu Toàn Diện & Đồng Bộ Kiến Trúc
- [x] **Step 1: Chạy kiểm tra phân tích tĩnh toàn bộ dự án (`dart analyze lib test`)** (0 issues)
- [x] **Step 2: Chạy toàn bộ test suites (`flutter test`)** (100% Passed)
- [x] **Step 3: Đồng bộ tri thức kiến trúc qua `graphify update .`** (15.571 nodes)
- [x] **Step 4: Báo cáo kết quả tổng kết**
