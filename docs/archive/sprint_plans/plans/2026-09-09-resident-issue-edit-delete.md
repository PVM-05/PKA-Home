# Resident Issue Edit and Delete Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng tính năng cho phép cư dân chỉnh sửa mô tả & quản lý ảnh của phản ánh sự cố, và xóa phản ánh sự cố khi đang ở trạng thái `pending` (Chờ tiếp nhận).

**Architecture:**
- Bổ sung RLS Policies trên Supabase cho `UPDATE` và `DELETE` trên bảng `issue_reports` và `issue_images`, có ràng buộc `status = 'pending' AND reporter_id = auth.uid()`.
- Tầng Repository: Bổ sung `deleteIssue()` và `updateIssue()` trong `IssueRepository`, xử lý dọn dẹp và cập nhật ảnh trên Storage.
- Tầng UI: Thêm menu thao tác (Sửa/Xóa) trên thẻ phản ánh trong `ResidentIssueScreen` và màn hình chỉnh sửa `EditIssueScreen`.

**Tech Stack:** Flutter, Flutter Riverpod, Supabase (PostgreSQL, Storage, RLS), ImagePicker.

## Global Constraints
- Chỉ cho phép sửa/xóa khi trạng thái là `pending`. Khi `in_progress` hoặc `resolved` thì không hiển thị nút thao tác.
- Sử dụng bảng màu chuẩn từ `AppTheme`, 100% tiếng Việt cho giao diện và thông báo.
- Bảo đảm 100% test hiện hữu tiếp tục pass.

---

### Task 1: Supabase RLS Migration Cho Sửa & Xóa Phản Ánh

**Files:**
- Create: `supabase/migrations/20260909_03_issue_update_delete_policies.sql`

**Interfaces:**
- Produces: RLS policies cho phép Resident `UPDATE` và `DELETE` `issue_reports` và `issue_images` với điều kiện `reporter_id = auth.uid() AND status = 'pending'`.

- [ ] **Step 1: Tạo file migration**
Tạo file `supabase/migrations/20260909_03_issue_update_delete_policies.sql`:
```sql
-- Migration: Cho phép Resident sửa và xóa issue_reports và issue_images khi status = 'pending'

-- 1. Policies trên issue_reports
DROP POLICY IF EXISTS "Resident sửa issue_reports khi pending" ON public.issue_reports;
CREATE POLICY "Resident sửa issue_reports khi pending"
ON public.issue_reports FOR UPDATE
USING (reporter_id = auth.uid() AND status = 'pending')
WITH CHECK (reporter_id = auth.uid() AND status = 'pending');

DROP POLICY IF EXISTS "Resident xóa issue_reports khi pending" ON public.issue_reports;
CREATE POLICY "Resident xóa issue_reports khi pending"
ON public.issue_reports FOR DELETE
USING (reporter_id = auth.uid() AND status = 'pending');

-- 2. Policies trên issue_images
DROP POLICY IF EXISTS "Resident xóa issue_images khi pending" ON public.issue_images;
CREATE POLICY "Resident xóa issue_images khi pending"
ON public.issue_images FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM public.issue_reports ir
    WHERE ir.id = issue_images.issue_report_id
    AND ir.reporter_id = auth.uid()
    AND ir.status = 'pending'
  )
);

DROP POLICY IF EXISTS "Resident thêm issue_images khi pending" ON public.issue_images;
CREATE POLICY "Resident thêm issue_images khi pending"
ON public.issue_images FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.issue_reports ir
    WHERE ir.id = issue_images.issue_report_id
    AND ir.reporter_id = auth.uid()
    AND ir.status = 'pending'
  )
);
```

- [ ] **Step 2: Thực thi migration lên Supabase database qua execute_sql**
Chạy câu lệnh SQL trên project `vpgimjyyechhuofjghsb`.

- [ ] **Step 3: Commit**
```bash
git add supabase/migrations/20260909_03_issue_update_delete_policies.sql
git commit -m "feat(db): thêm RLS policies cho phép cư dân sửa và xóa phản ánh khi pending"
```

---

### Task 2: Cập Nhật IssueRepository (Xóa & Chỉnh Sửa Phản Ánh) & Unit Tests

**Files:**
- Modify: `lib/data/repositories/issue_repository.dart`
- Modify: `test/data/repositories/issue_repository_test.dart`

**Interfaces:**
- `Future<void> deleteIssue({required String issueId, List<String>? imageUrls})`
- `Future<void> updateIssue({required String issueId, required String reporterId, required String description, List<String>? removedImageUrls, List<File>? newImageFiles})`

- [ ] **Step 1: Viết test cho `deleteIssue` và `updateIssue` signature**
Cập nhật `test/data/repositories/issue_repository_test.dart` kiểm tra các phương thức tồn tại và xử lý tham số hợp lệ.

- [ ] **Step 2: Chạy test để xác nhận fail**
Chạy: `flutter test test/data/repositories/issue_repository_test.dart`

- [ ] **Step 3: Cài đặt `deleteIssue` và `updateIssue` trong `IssueRepository`**
Trong `lib/data/repositories/issue_repository.dart`:
- `deleteIssue`:
  - Gọi `_client.from('issue_reports').delete().eq('id', issueId)`.
  - Nếu `imageUrls != null`, trích xuất tên file và xóa khỏi storage `_client.storage.from('issue-images').remove(paths)`.
- `updateIssue`:
  - Cập nhật `description`: `_client.from('issue_reports').update({'description': description}).eq('id', issueId)`.
  - Nếu có `removedImageUrls`: xóa khỏi bảng `issue_images` và storage.
  - Nếu có `newImageFiles`: upload lên storage `issue-images` theo đường dẫn `$reporterId/$issueId/<timestamp>_$i.$ext` và insert vào bảng `issue_images`.

- [ ] **Step 4: Chạy test để xác nhận pass**
Chạy: `flutter test test/data/repositories/issue_repository_test.dart`

- [ ] **Step 5: Commit**
```bash
git add lib/data/repositories/issue_repository.dart test/data/repositories/issue_repository_test.dart
git commit -m "feat(issue): thêm phương thức deleteIssue và updateIssue trong IssueRepository"
```

---

### Task 3: Xây Dựng Màn Hình Chỉnh Sửa Phản Ánh (`EditIssueScreen`)

**Files:**
- Create: `lib/features/resident/screens/edit_issue_screen.dart`

**Interfaces:**
- Widget: `EditIssueScreen({required IssueModel issue})`

- [ ] **Step 1: Tạo tệp `edit_issue_screen.dart`**
- Xây dựng form chỉnh sửa:
  - Khởi tạo controller với `widget.issue.description`.
  - Quản lý danh sách ảnh hiện tại (`_existingImages`), cho phép đánh dấu xóa vào `_removedImageUrls`.
  - Quản lý danh sách ảnh mới (`_newImageFiles`), cho phép thêm qua `ImagePicker` và xóa khỏi danh sách chuẩn bị tải lên.
  - Nút "Lưu thay đổi": gọi `issueRepo.updateIssue()`, invalidate `residentIssueProvider`, hiển thị SnackBar thành công và đóng màn hình.

- [ ] **Step 2: Phân tích cú pháp**
Chạy: `dart analyze lib/features/resident/screens/edit_issue_screen.dart`
Kỳ vọng: 0 issues found.

- [ ] **Step 3: Commit**
```bash
git add lib/features/resident/screens/edit_issue_screen.dart
git commit -m "feat(issue): xây dựng màn hình chỉnh sửa phản ánh sự cố EditIssueScreen"
```

---

### Task 4: Tích Hợp Menu Thao Tác (Sửa/Xóa) Trên Thẻ Phản Ánh & Xác Nhận Xóa

**Files:**
- Modify: `lib/features/resident/screens/resident_issue_screen.dart`

**Interfaces:**
- UI: Thêm `PopupMenuButton` vào `_buildIssueCard()` khi `issue.status == 'pending'`.
- Dialog: `AlertDialog` xác nhận xóa phản ánh.

- [ ] **Step 1: Thêm phương thức `_confirmDeleteIssue` và `_editIssue` trong `resident_issue_screen.dart`**
- Khi chọn "Chỉnh sửa": `Navigator.push(context, MaterialPageRoute(builder: (_) => EditIssueScreen(issue: issue)))`.
- Khi chọn "Xóa": Hiển thị `showDialog` xác nhận. Nếu đồng ý, gọi `issueRepo.deleteIssue()`, hiển thị SnackBar thành công và invalidate provider.

- [ ] **Step 2: Thêm PopupMenuButton vào góc thẻ phản ánh**
Chỉ hiển thị khi `issue.status == 'pending'`.

- [ ] **Step 3: Chạy kiểm thử toàn bộ và phân tích cú pháp**
Chạy: `dart analyze` và `flutter test`
Kỳ vọng: 0 lỗi, 100% tests pass.

- [ ] **Step 4: Commit**
```bash
git add lib/features/resident/screens/resident_issue_screen.dart
git commit -m "feat(issue): tích hợp menu sửa và xóa phản ánh sự cố trên resident_issue_screen"
```
