# Đặc Tả Kỹ Thuật: Khắc Phục Toàn Diện 5 Điểm Nghẽn UX & Chức Năng (P1 Hardening)

> **Mục tiêu:** Xử lý triệt để 5 vấn đề cốt lõi về trải nghiệm người dùng và an toàn dữ liệu: sửa khớp icon/nhãn điều hướng, hoàn thiện Dark Mode cho tra cứu tài liệu, chuẩn hóa Inline Validation tại chỗ, bảo vệ dữ liệu chưa lưu bằng `PopScope`, và thiết lập cơ chế phân trang (Pagination) cuộn vô tận cho các danh sách lớn.
> 
> **Tuân thủ:** `AGENTS.md`, `coding-rules.md`, `design-rules.md`. Commit trực tiếp vào nhánh `main`.

---

## 1. Bối Cảnh & Vấn Đề Cần Khắc Phục (Problem Statement)

1. **Sai lệch Icon & Hành động Nút Trang Chủ:** Nút "Thanh toán" tại thanh tác vụ nhanh trang chủ cư dân sử dụng `Icons.qr_code_scanner` nhưng khi chạm vào lại điều hướng sang Tab Hóa đơn, gây hiểu nhầm về tính năng quét VietQR.
2. **Lỗi Dark Mode Chói Lòa tại Tra Cứu Tài Liệu:** Màn hình `document_lookup_screen.dart` hardcode nền xanh nhạt `Color(0xFFF0FDF4)` (Green 50) và chữ `Color(0xFF15803D)` cố định, không thích ứng chế độ tối, gây chói mắt nghiêm trọng khi người dùng bật Dark Mode.
3. **Thiếu Inline Validation Tại Chỗ:** Màn hình tạo phản ánh `create_issue_screen.dart` sử dụng `TextField` thô và chỉ thông báo lỗi rỗng qua `SnackBar` chung khi người dùng bấm gửi, không có chỉ báo lỗi màu đỏ tại chân ô nhập.
4. **Mất Dữ Liệu Chưa Lưu (0 PopScope Guard):** Toàn bộ các biểu mẫu dài trong ứng dụng (tạo phản ánh đính kèm 3 ảnh, sửa sự cố) hoàn toàn không có `PopScope`. Khi vô tình vuốt mép màn hình (predictive back) hoặc nhấn nút back, toàn bộ dữ liệu đang nhập biến mất ngay lập tức.
5. **Thiếu Phân Trang (0 Pagination):** Toàn bộ danh sách hóa đơn, phản ánh sự cố tải 100% dữ liệu từ Supabase về client rồi mới lọc local, tiềm ẩn nguy cơ giật lag và nghẽn băng thông khi quy mô căn hộ và lịch sử dữ liệu tăng trưởng.

---

## 2. Giải Pháp Kỹ Thuật (Technical Design)

### 2.1. Task 1: Đồng Bộ Icon Điều Hướng & Hoàn Thiện Dark Mode
- **Quick Actions Row (`resident_home_quick_actions_row.dart`):**
  - Đổi `Icons.qr_code_scanner` $\rightarrow$ `Icons.receipt_long_rounded`.
  - Đổi nhãn `Thanh toán` $\rightarrow$ `Hóa đơn` (hoặc `Đóng phí`).
- **Màn hình Tra cứu Tài liệu (`document_lookup_screen.dart`):**
  - Rà soát toàn bộ các màu `Color(0xFF...)` hardcode.
  - Thiết lập bảng màu thích ứng:
    - Thành công: Light dùng `Color(0xFFF0FDF4)` viền `Color(0xFFBBF7D0)`, Dark dùng `colorScheme.surfaceContainer` với viền `AppStatusColors.getPaid(context).withValues(alpha: 0.3)`.
    - Chữ và tiêu đề lấy từ `theme.textTheme` và `AppStatusColors.getPaid(context)` / `AppStatusColors.getUnpaid(context)`.

### 2.2. Task 2: Chuẩn Hóa Inline Form Validation
- **Màn hình Tạo Phản Ánh (`create_issue_screen.dart`):**
  - Bọc phần form trong `Form` với `_formKey = GlobalKey<FormState>()`.
  - Thay thế `TextField` mô tả bằng `TextFormField`:
    - `validator: (value) => (value == null || value.trim().isEmpty) ? 'Vui lòng nhập chi tiết mô tả sự cố' : null`.
    - Thiết lập `autovalidateMode: AutovalidateMode.onUserInteraction` khi đã bấm Gửi lần đầu.
  - Khi bấm Gửi: Gọi `if (!_formKey.currentState!.validate()) return;`.

### 2.3. Task 3: Bảo Vệ Dữ Liệu Chưa Lưu Với `AppUnsavedChangesGuard` (`PopScope`)
- Tạo widget dùng chung: `lib/core/widgets/app_unsaved_changes_guard.dart`.
  - Tham số: `bool hasUnsavedChanges`, `Widget child`, `String? title`, `String? message`.
  - Sử dụng widget chuẩn Flutter 3.44+: `PopScope`:
    ```dart
    PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(...);
        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: child,
    )
    ```
  - Hộp thoại xác nhận tiếng Việt chuẩn mực:
    - Tiêu đề: *"Rời khỏi biểu mẫu?"*
    - Nội dung: *"Những thông tin bạn vừa nhập chưa được lưu và sẽ bị mất nếu rời khỏi."*
    - Nút phụ: *"Tiếp tục nhập"* (hủy pop).
    - Nút chính (Cảnh báo): *"Rời khỏi"* (cho phép pop).
  - Tích hợp vào:
    - `create_issue_screen.dart`: `hasUnsavedChanges = _descriptionController.text.isNotEmpty || _selectedImages.isNotEmpty`.
    - `edit_issue_screen.dart`: `hasUnsavedChanges = _hasModifiedData()`.

### 2.4. Task 4: Kiến Trúc Phân Trang Cuộn Vô Tận (Pagination Architecture)
- Thiết lập hợp đồng phân trang `PaginatedList<T>`:
  - `items`: Danh sách phần tử hiện tại.
  - `page`: Trang hiện tại.
  - `pageSize`: Kích thước trang (mặc định 20).
  - `hasMore`: Cờ báo còn dữ liệu ở các trang tiếp theo hay không.
  - `isLoadingMore`: Cờ báo đang tải thêm trang mới ở footer.
- Cập nhật tầng Repository Supabase:
  - `IssueRepository.fetchResidentIssues`: Thêm `limit` và `offset` (dùng `.range(offset, offset + limit - 1)`).
  - `InvoiceRepository.fetchResidentInvoices`: Thêm `limit` và `offset`.
- Tích hợp Infinite Scroll vào màn hình hiển thị:
  - Lắng nghe `ScrollController` khi `scrollPosition >= maxScrollExtent - 200` để kích hoạt `loadMore()`.
  - Hiển thị footer spinner hoặc shimmer nhỏ ở cuối danh sách khi đang tải tiếp.

---

## 3. Tiêu Chí Nghiệm Thu (Acceptance Criteria)
1. Quick actions hiển thị đúng `Icons.receipt_long_rounded` và nhãn `Hóa đơn`.
2. Màn hình tra cứu tài liệu hiển thị dịu mắt, tương phản chuẩn WCAG AA trên cả Light Theme và Dark Theme.
3. Form tạo phản ánh báo lỗi đỏ trực tiếp tại chân ô nhập khi mô tả trống.
4. Vuốt back hoặc bấm nút quay lại khi đang điền form hiển thị hộp thoại xác nhận hủy bỏ, không bị mất dữ liệu bất ngờ.
5. Danh sách sự cố hỗ trợ tải từng trang `limit: 20` kèm cuộn tải tiếp mượt mà.
6. `dart analyze lib test` 0 lỗi. Toàn bộ tests pass 100%.

