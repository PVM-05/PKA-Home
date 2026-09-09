# Architecture and Resilience Refinements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triển khai 4 cải tiến kiến trúc cốt lõi: Ràng buộc tính `subtotal` bằng generated column cấp PostgreSQL, cơ chế xử lý lỗi tải ảnh sự cố bền bỉ (resilience), lộ trình mở rộng phân trang dữ liệu, và quy chuẩn chính sách khôi phục mật khẩu.

**Architecture:** 
- PostgreSQL Generated Column (`STORED`) tính toán `subtotal` tự động trên DB, loại bỏ rủi ro tính toán sai lệch từ phía client.
- Xử lý phân tách lỗi (isolated error handling) khi upload ảnh sự cố, trả về kết quả `CreateIssueResult` rõ ràng để thông báo cho người dùng mà không làm mất bản ghi sự cố.
- Cập nhật tài liệu SRS, ERD và Báo cáo tiến độ chuẩn hóa quyết định thiết kế.

**Tech Stack:** PostgreSQL (Supabase Migration), Dart / Flutter, Flutter Riverpod, Mocktail.

## Global Constraints
- Tuân thủ 100% tiếng Việt cho giao diện người dùng và thông báo lỗi/thành công.
- Không hardcode màu sắc, dùng palette từ `AppTheme`.
- Giữ nguyên toàn bộ test case hiện hữu, kiểm thử xác minh trước khi hoàn thành.

---

### Task 1: Chuyển đổi `invoice_items.subtotal` sang Generated Column & Cập nhật Client

**Files:**
- Create: `supabase/migrations/20260909_01_invoice_subtotal_generated_column.sql`
- Modify: `lib/data/repositories/management_repository.dart:132-141`
- Modify: `docs/ERD.dbml:55-65`

**Interfaces:**
- Consumes: `items` trong `ManagementRepository.createInvoice(String apartmentId, String period, DateTime dueDate, List<Map<String, dynamic>> items)`
- Produces: `insertItems` không chứa khóa `'subtotal'`. DB tự động sinh `subtotal` khi INSERT/UPDATE.

- [ ] **Step 1: Tạo tệp SQL migration**
Tạo file `supabase/migrations/20260909_01_invoice_subtotal_generated_column.sql`:
```sql
-- Migration: Chuyển đổi invoice_items.subtotal sang GENERATED ALWAYS AS STORED
-- Đảm bảo toàn vẹn dữ liệu tài chính, không phụ thuộc vào tính toán từ client

ALTER TABLE public.invoice_items DROP COLUMN IF EXISTS subtotal;
ALTER TABLE public.invoice_items 
  ADD COLUMN subtotal DECIMAL GENERATED ALWAYS AS (unit_price * quantity) STORED;
```

- [ ] **Step 2: Cập nhật `createInvoice` trong `management_repository.dart`**
Loại bỏ việc tính `'subtotal'` ở Flutter:
```dart
    final List<Map<String, dynamic>> insertItems = items.map((item) => {
      'invoice_id': invoiceId,
      'fee_type': item['fee_type'],
      'unit_price': item['unit_price'],
      'quantity': item['quantity'],
    }).toList();
```

- [ ] **Step 3: Cập nhật tài liệu `docs/ERD.dbml`**
Cập nhật bảng `invoice_items` trong `docs/ERD.dbml`:
```dbml
  subtotal decimal [note: 'GENERATED ALWAYS AS (unit_price * quantity) STORED']
```

- [ ] **Step 4: Chạy kiểm tra code analysis và test**
Chạy: `dart analyze` và `flutter test`
Kỳ vọng: Không có lỗi phân tích cú pháp, toàn bộ test pass.

- [ ] **Step 5: Commit**
```bash
git add supabase/migrations/20260909_01_invoice_subtotal_generated_column.sql lib/data/repositories/management_repository.dart docs/ERD.dbml
git commit -m "feat(invoice): chuyển subtotal sang generated column trên postgres và bỏ tính client-side"
```

---

### Task 2: Cơ chế Xử Lý Lỗi Tải Ảnh Sự Cố Bền Bỉ (Resilient Issue Creation)

**Files:**
- Modify: `lib/data/repositories/issue_repository.dart`
- Modify: `lib/features/resident/screens/create_issue_screen.dart:120-145`
- Create: `test/data/repositories/issue_repository_test.dart`

**Interfaces:**
- Consumes: `File? imageFile`, `List<File>? imageFiles`
- Produces: `Future<CreateIssueResult> createIssue(...)` với `CreateIssueResult(issueId, {imageUploadFailed})`

- [ ] **Step 1: Viết test cho `CreateIssueResult` và logic repository**
Tạo file `test/data/repositories/issue_repository_test.dart`:
Kiểm tra cấu trúc `CreateIssueResult` và đảm bảo constructor gán đúng thuộc tính mặc định `imageUploadFailed = false`.

- [ ] **Step 2: Chạy test để xác nhận fail**
Chạy: `flutter test test/data/repositories/issue_repository_test.dart`
Kỳ vọng: FAIL vì chưa định nghĩa `CreateIssueResult`.

- [ ] **Step 3: Cập nhật `IssueRepository` với `CreateIssueResult` và try/catch quanh upload ảnh**
Trong `lib/data/repositories/issue_repository.dart`:
```dart
class CreateIssueResult {
  final String issueId;
  final bool imageUploadFailed;

  const CreateIssueResult({
    required this.issueId,
    this.imageUploadFailed = false,
  });
}
```
Và trong `createIssue()`:
- Hỗ trợ dependency injection: `IssueRepository([SupabaseClient? client]) : _client = client ?? SupabaseConfig.client;`
- Bọc khối upload ảnh trong `try ... catch`:
```dart
    bool imageUploadFailed = false;
    for (int i = 0; i < filesToUpload.length; i++) {
      try {
        final file = filesToUpload[i];
        final fileExt = file.path.split('.').last;
        final fileName = '$issueId/${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';
        
        await _client.storage
            .from('issue-images')
            .upload(fileName, file);
            
        final imageUrl = _client.storage
            .from('issue-images')
            .getPublicUrl(fileName);

        await _client.from('issue_images').insert({
          'issue_report_id': issueId,
          'image_url': imageUrl,
        });
      } catch (e) {
        imageUploadFailed = true;
      }
    }

    return CreateIssueResult(
      issueId: issueId,
      imageUploadFailed: imageUploadFailed,
    );
```

- [ ] **Step 4: Cập nhật `create_issue_screen.dart` xử lý `result.imageUploadFailed`**
Trong `_submitIssue()`:
```dart
      final result = await issueRepo.createIssue(
        reporterId: user.id,
        description: description,
        imageFiles: _imageFiles,
      );

      ref.invalidate(residentIssueProvider);

      if (mounted) {
        if (result.imageUploadFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã gửi phản ánh nhưng ảnh tải lên thất bại, vui lòng thử đính kèm lại sau'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gửi phản ánh thành công!'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
        Navigator.pop(context);
      }
```

- [ ] **Step 5: Chạy test kiểm chứng**
Chạy: `flutter test`
Kỳ vọng: Toàn bộ test pass 100%.

- [ ] **Step 6: Commit**
```bash
git add lib/data/repositories/issue_repository.dart lib/features/resident/screens/create_issue_screen.dart test/data/repositories/issue_repository_test.dart
git commit -m "fix(issue): xử lý lỗi tải ảnh bền bỉ, thông báo chi tiết và bảo toàn phản ánh"
```

---

### Task 3: Bổ Sung Định Hướng Phân Trang & Quyết Định Quên Mật Khẩu Vào Tài Liệu

**Files:**
- Modify: `docs/bao-cao-tien-do-tuan 1.md`
- Modify: `docs/SRS.md`

**Interfaces:**
- Cung cấp luận điểm bảo vệ đồ án về khả năng mở rộng (Scalability) và quyết định bảo mật (Security by design).

- [ ] **Step 1: Cập nhật `docs/bao-cao-tien-do-tuan 1.md`**
Bổ sung:
1. Mục Khó khăn & Giải pháp:
   - Cơ chế bảo toàn phản ánh khi upload ảnh gián đoạn.
   - Toàn vẹn dữ liệu tài chính cấp CSDL với Generated Column `subtotal`.
2. Mục Hướng phát triển:
   - Tối ưu hóa tải dữ liệu và Phân trang (Pagination / Infinite Scroll) với Supabase `.range(from, to)`.

- [ ] **Step 2: Cập nhật `docs/SRS.md`**
Tại mục 4. Yêu cầu Phi chức năng:
- Bổ sung yêu cầu về Khả năng mở rộng (Scalability / Pagination Roadmap).
- Bổ sung yêu cầu về Quy trình Đặt lại mật khẩu có chủ đích (Internal Admin-managed Password Reset).

- [ ] **Step 3: Commit**
```bash
git add "docs/bao-cao-tien-do-tuan 1.md" docs/SRS.md
git commit -m "docs: bổ sung định hướng phân trang và quy chuẩn đặt lại mật khẩu vào SRS và báo cáo"
```

---

### Task 4: Bổ Sung Hướng Dẫn "Quên Mật Khẩu?" Trên Giao Diện Đăng Nhập

**Files:**
- Modify: `lib/features/auth/screens/login_screen.dart`

**Interfaces:**
- Giao diện người dùng: Nút "Quên mật khẩu?" mở AlertDialog hướng dẫn liên hệ Ban quản lý tòa nhà.

- [ ] **Step 1: Thêm phương thức hiển thị Dialog hỗ trợ quên mật khẩu**
Trong `_LoginScreenState`:
```dart
  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Quên mật khẩu?'),
          ],
        ),
        content: const Text(
          'Để bảo mật dữ liệu căn hộ, hệ thống quản lý nội bộ yêu cầu xác minh trực tiếp. Vui lòng liên hệ Văn phòng Ban Quản lý hoặc Hotline tòa nhà để được hỗ trợ cấp lại mật khẩu.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 2: Thêm nút liên kết "Quên mật khẩu?" vào dưới trường mật khẩu**
Ngay dưới `TextField` mật khẩu hoặc phía trên nút Đăng nhập:
```dart
  Align(
    alignment: Alignment.centerRight,
    child: TextButton(
      onPressed: _showForgotPasswordDialog,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        'Quên mật khẩu?',
        style: TextStyle(
          fontSize: 13,
          color: AppTheme.textSecondary,
        ),
      ),
    ),
  ),
```

- [ ] **Step 3: Chạy phân tích cú pháp và kiểm thử**
Chạy: `dart analyze` và `flutter test`
Kỳ vọng: Không có lỗi hoặc cảnh báo, tất cả test pass.

- [ ] **Step 4: Commit**
```bash
git add lib/features/auth/screens/login_screen.dart
git commit -m "feat(auth): thêm liên kết và hộp thoại hướng dẫn quên mật khẩu qua ban quản lý"
```
