# Thiết Kế Tính Năng Chỉnh Sửa & Xóa Phản Ánh Sự Cố (Edit & Delete Issue Reports)
**Ngày:** 09/09/2026  
**Dự án:** Ứng dụng Quản lý Chung cư (PKA-Home)  
**Trạng thái:** Đã phê duyệt thiết kế  

---

## 1. Mục tiêu & Nghiệp vụ
Cho phép cư dân chủ động quản lý các phản ánh sự cố do chính mình gửi lên:
- **Chỉnh sửa phản ánh:** Cập nhật nội dung mô tả, xóa ảnh cũ hoặc bổ sung ảnh mới khi cần cung cấp thêm bằng chứng.
- **Xóa phản ánh:** Xóa phản ánh nếu gửi nhầm hoặc sự cố đã tự được khắc phục.
- **Ràng buộc an toàn:** Cư dân **chỉ được phép sửa hoặc xóa khi phản ánh ở trạng thái `pending` (Chờ tiếp nhận)**. Khi Ban Quản lý đã tiếp nhận sang `in_progress` hoặc `resolved`, quyền sửa/xóa sẽ bị khóa để bảo toàn tính minh bạch và lịch sử vận hành.

---

## 2. Thiết Kế Chi Tiết

### 2.1. Phân Quyền CSDL (Supabase RLS)
Tệp migration: `supabase/migrations/20260909_03_issue_update_delete_policies.sql`
- **Chính sách trên bảng `public.issue_reports`:**
  - `UPDATE Policy`:
    ```sql
    CREATE POLICY "Resident sửa issue_reports khi pending"
    ON public.issue_reports FOR UPDATE
    USING (reporter_id = auth.uid() AND status = 'pending')
    WITH CHECK (reporter_id = auth.uid() AND status = 'pending');
    ```
  - `DELETE Policy`:
    ```sql
    CREATE POLICY "Resident xóa issue_reports khi pending"
    ON public.issue_reports FOR DELETE
    USING (reporter_id = auth.uid() AND status = 'pending');
    ```
- **Chính sách trên bảng `public.issue_images`:**
  - `DELETE Policy`:
    ```sql
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
    ```
  - `INSERT Policy`:
    ```sql
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

---

### 2.2. Tầng Repository (`IssueRepository`)
Tệp: `lib/data/repositories/issue_repository.dart`
Bổ sung 2 phương thức:
1. `Future<void> deleteIssue({required String issueId, List<String>? imageUrls})`:
   - Xóa bản ghi trong bảng `issue_reports`. Bảng `issue_images` tự động xóa các liên kết theo CASCADE.
   - Thử dọn dẹp các tệp ảnh khỏi bucket Storage `issue-images`.
2. `Future<void> updateIssue({required String issueId, required String reporterId, required String description, List<String>? removedImageUrls, List<File>? newImageFiles})`:
   - Cập nhật trường `description` trên bảng `issue_reports`. Database trigger `trigger_classify_issue_priority` sẽ tự động cập nhật lại `priority`.
   - Xóa các ảnh trong `removedImageUrls` khỏi bảng `issue_images` và Storage.
   - Tải các ảnh trong `newImageFiles` lên Storage (đường dẫn `$reporterId/$issueId/<timestamp>_$i.$ext`) và chèn vào `issue_images`.

---

### 2.3. Tầng Giao Diện Người Dùng (UI/UX)
1. **Thẻ Phản Ánh (`lib/features/resident/screens/resident_issue_screen.dart`):**
   - Nếu `issue.status == 'pending'`: Hiển thị `PopupMenuButton` chứa 2 tùy chọn:
     - "Chỉnh sửa" (Icon: `Icons.edit_outlined`) -> Điều hướng sang `EditIssueScreen(issue: issue)`.
     - "Xóa phản ánh" (Icon: `Icons.delete_outline`, màu `AppTheme.error`) -> Mở `AlertDialog` xác nhận.
   - Khi xác nhận xóa: Gọi `issueRepo.deleteIssue(...)`, hiển thị SnackBar thông báo thành công và làm mới `residentIssueProvider`.
2. **Màn hình Chỉnh Sửa Phản Ánh (`lib/features/resident/screens/edit_issue_screen.dart`):**
   - Giao diện form độc lập:
     - Ô nhập mô tả sự cố (khởi tạo với `issue.description`).
     - Danh sách ảnh hiện có: hiển thị thumbnail, góc trên có nút xóa màu đỏ `(X)` để đánh dấu xóa.
     - Danh sách ảnh mới thêm từ thư viện kèm nút `(X)` gỡ bỏ.
     - Nút "Thêm ảnh" (`ImagePicker`).
     - Nút ElevatedButton "Lưu thay đổi".
   - Tự động gọi `issueRepo.updateIssue(...)`, thông báo thành công và đóng màn hình.

---

## 3. Kế Hoạch Kiểm Thử
1. **Kiểm thử CSDL:**
   - Thực thi migration trên Supabase qua MCP tool.
   - Kiểm tra các policy `UPDATE`, `DELETE` bằng SQL query.
2. **Kiểm thử TDD / Unit Test:**
   - Viết unit test cho các phương thức `deleteIssue` và `updateIssue` trong `issue_repository_test.dart`.
3. **Kiểm thử Tích Hợp & Giao Diện:**
   - Chạy `dart analyze` và `flutter test`.
   - Xác minh luồng giao diện: nút menu chỉ hiện khi `pending`, xóa có hộp thoại xác nhận, sửa mô tả và ảnh thành công.
