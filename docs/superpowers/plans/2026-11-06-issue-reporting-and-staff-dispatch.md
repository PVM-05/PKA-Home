# Kế Hoạch Triển Khai: Quản Lý Phản Ánh Sự Cố & Điều Phối Kỹ Thuật Viên

> **Dành cho kỹ sư/agent thực thi:** BẮT BUỘC tuân thủ TDD, viết kiểm thử trước, triển khai mã nguồn tối thiểu, chạy test xác nhận PASS trước khi commit trực tiếp vào nhánh `main`. Các bước sử dụng cú pháp checkbox (`- [ ]`) để theo dõi.

**Mục tiêu:** Hoàn thiện module Quản lý Phản ánh Sự cố & Điều phối Kỹ thuật viên (FEAT-ISSUE-DISPATCH-2026), giải quyết triệt để vi phạm gọi trực tiếp Supabase từ Widget, bổ sung bộ lọc "Được giao cho tôi" cho kỹ thuật viên và bảo đảm trải nghiệm phân công - nghiệm thu minh bạch.

**Kiến trúc:** 
- Tầng Repository: `ManagementRepository.fetchAssignableStaff()` đóng gói truy vấn danh sách nhân viên kỹ thuật và BQL.
- Tầng Quản lý trạng thái: Riverpod `managementRepositoryProvider` & `authStateProvider`.
- Tầng Giao diện: `issue_management_screen.dart` hỗ trợ lọc "Được giao cho tôi" (Assigned to Me), phân công qua Repository, hiển thị ảnh nghiệm thu và thẻ đánh giá CSAT.

**Tech Stack:** Flutter, Dart, Riverpod, Supabase Flutter, Flutter Test, Mocktail.

## Quy Tắc Toàn Cục (Global Constraints)
- 100% Tiếng Việt chuẩn mực trên giao diện, thông báo lỗi và nhãn nút bấm.
- Sử dụng Material Icons mặc định (`Icons.*`), tuyệt đối không dùng Emoji.
- Không gọi trực tiếp `SupabaseConfig.client` trong Widget, luôn qua Repository.
- Commit trực tiếp vào nhánh `main`, không tạo branch/worktree phụ.

---

### Nhiệm Vụ 1: Bổ Sung `fetchAssignableStaff()` Vào `ManagementRepository`

**Tập tin tác động:**
- Chỉnh sửa: `lib/data/repositories/management_repository.dart`
- Kiểm thử: `test/data/repositories/management_repository_test.dart`

**Giao diện:**
- Cung cấp: `Future<List<Map<String, dynamic>>> fetchAssignableStaff()`
  - Trả về danh sách gồm các trường: `{'id': String, 'name': String, 'role': String?}`
  - Lọc theo `role IN ('technician', 'admin', 'management')`
  - Sắp xếp tăng dần theo `full_name`

- [ ] **Bước 1: Viết test cho `fetchAssignableStaff()`**
  Tạo hoặc cập nhật file `test/data/repositories/management_repository_test.dart` kiểm tra `fetchAssignableStaff()` gọi đúng query và ánh xạ tên vai trò tiếng Việt chuẩn xác.

- [ ] **Bước 2: Chạy test để xác nhận FAIL**
  Chạy: `flutter test test/data/repositories/management_repository_test.dart`
  Kết quả dự kiến: Lỗi biên dịch hoặc FAIL do phương thức chưa tồn tại.

- [ ] **Bước 3: Viết mã triển khai `fetchAssignableStaff()` trong `ManagementRepository`**
  Thêm phương thức vào `lib/data/repositories/management_repository.dart`.

- [ ] **Bước 4: Chạy lại test để xác nhận PASS**
  Chạy: `flutter test test/data/repositories/management_repository_test.dart`
  Kết quả dự kiến: PASS 100%.

- [ ] **Bước 5: Commit vào `main`**
  ```bash
  git add lib/data/repositories/management_repository.dart test/data/repositories/management_repository_test.dart
  git commit -m "feat: bổ sung fetchAssignableStaff vào ManagementRepository"
  ```

---

### Nhiệm Vụ 2: Refactor Phân Công Nhân Sự & Bổ Sung Bộ Lọc "Được Giao Cho Tôi" Trên `issue_management_screen.dart`

**Tập tin tác động:**
- Chỉnh sửa: `lib/features/management/screens/issue_management_screen.dart`

**Giao diện:**
- Tiêu thụ: `ref.read(managementRepositoryProvider).fetchAssignableStaff()`
- Tiêu thụ: `ref.watch(authStateProvider).value?.user?.id` hoặc `SupabaseConfig.client.auth.currentUser?.id` để xác định `currentUserId`
- Bổ sung biến trạng thái: `bool _onlyAssignedToMe = false;`
- Bổ sung logic lọc trong `_filterIssues`: Nếu `_onlyAssignedToMe == true`, chỉ giữ các sự cố có `issue.assignedStaffId == currentUserId`.
- Thêm FilterChip hoặc Filter Switch trên thanh lọc sự cố: "Được giao cho tôi".
- Thay thế hoàn toàn `SupabaseConfig.client.from('users')` trong `_showAssignStaffDialog` bằng Repository call.

- [ ] **Bước 1: Cập nhật `issue_management_screen.dart`**
  Loại bỏ truy cập trực tiếp Supabase, tích hợp `fetchAssignableStaff()` và thêm bộ lọc "Được giao cho tôi".

- [ ] **Bước 2: Kiểm tra tĩnh bằng `dart analyze`**
  Chạy: `dart analyze lib/features/management/screens/issue_management_screen.dart`
  Kết quả dự kiến: 0 issues.

---

### Nhiệm Vụ 3: Viết Widget Tests Cho Giao Diện Điều Phối Sự Cố

**Tập tin tác động:**
- Tạo mới: `test/features/management/issue_staff_dispatch_test.dart`

**Yêu cầu:**
- [ ] **Bước 1: Viết kịch bản test kiểm tra bộ lọc "Được giao cho tôi"**
  Mô phỏng danh sách gồm 2 sự cố (1 sự cố được gán cho user hiện tại, 1 sự cố gán cho người khác hoặc chưa gán). Kiểm tra khi chọn bộ lọc "Được giao cho tôi", danh sách chỉ hiển thị đúng 1 sự cố của user.

- [ ] **Bước 2: Viết kịch bản test kiểm tra dialog phân công KTV**
  Kiểm tra dialog hiển thị đúng danh sách nhân viên từ `fetchAssignableStaff()`.

- [ ] **Bước 3: Chạy test để xác nhận PASS**
  Chạy: `flutter test test/features/management/issue_staff_dispatch_test.dart`
  Kết quả dự kiến: PASS.

- [ ] **Bước 4: Commit vào `main`**
  ```bash
  git add lib/features/management/screens/issue_management_screen.dart test/features/management/issue_staff_dispatch_test.dart
  git commit -m "feat: bổ sung bộ lọc sự cố giao cho tôi và refactor dialog phân công KTV"
  ```

---

### Nhiệm Vụ 4: Xác Minh Toàn Diện & Cập Nhật Graphify

**Tập tin tác động:**
- Toàn bộ codebase & test suite liên quan đến Issue và Management.

- [ ] **Bước 1: Chạy kiểm tra tĩnh toàn bộ dự án**
  Chạy: `dart analyze lib test`
  Kết quả dự kiến: 0 issues.

- [ ] **Bước 2: Chạy kiểm thử toàn bộ module Issue và Management**
  Chạy: `flutter test test/features/management/ test/features/issue/ test/data/repositories/management_repository_test.dart`
  Kết quả dự kiến: PASS 100%.

- [ ] **Bước 3: Cập nhật knowledge graph**
  Chạy: `graphify update .`

- [ ] **Bước 4: Kiểm tra trạng thái git**
  Chạy: `git status` đảm bảo working tree sạch trên nhánh `main`.
