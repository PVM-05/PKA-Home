# Kế Hoạch Triển Khai: Nâng Cấp Chi Tiết Sự Cố & Chi Tiết Hóa Đơn BQL (Impeccable & Anti-RenderFlex)

- **Mục tiêu:** Nâng cấp toàn diện 3 màn hình nghiệp vụ trọng yếu (`IssueDetailScreen`, `EditIssueScreen`, `ManagementInvoiceDetailScreen`) theo triết lý Impeccable Taste và Anti-RenderFlex Guarantee 100%.
- **Nhánh thực hiện:** `main` (commit trực tiếp theo quy định dự án).
- **Tài liệu đặc tả:** `docs/superpowers/specs/2026-11-09-issue-detail-and-invoice-workstation-impeccable-ui-design.md`.

---

## Danh Sách Task Triển Khai

### Task 1: Nâng cấp `IssueDetailScreen` (Chi Tiết Sự Cố & Trao Đổi Cư Dân - BQL)
**Files:**
- Modify: `lib/features/resident/screens/issue_detail_screen.dart`
- Create/Update Test: `test/features/resident/issue_detail_responsive_test.dart`

**Yêu cầu kỹ thuật:**
- Hỗ trợ Desktop Split-Screen $\ge 900$dp (`maxWidth: 1200`):
  - Cột trái: Header thông tin, Thư viện ảnh phản ánh/nghiệm thu, Status timeline, Vật tư kỹ thuật, Đánh giá dịch vụ.
  - Cột phải: Khối tin nhắn trao đổi (`issueCommentsProvider`) và khung nhập liệu tích hợp chân cột phải.
- Mobile (< 900dp, `maxWidth: 600`):
  - Chống tràn 100% trên 320dp x 600dp kèm font scale 1.3x.
  - Sử dụng thẻ `AppCard` viền siêu mỏng mờ theo `DESIGN.md`.
- Viết test responsive kiểm tra ở 320dp (scale 1.3x) và 1200dp.

---

### Task 2: Nâng cấp `EditIssueScreen` (Chỉnh Sửa Phản Ánh & Quản Lý Ảnh)
**Files:**
- Modify: `lib/features/resident/screens/edit_issue_screen.dart`
- Create/Update Test: `test/features/resident/edit_issue_responsive_test.dart`

**Yêu cầu kỹ thuật:**
- Bọc toàn bộ nội dung trong `Center(ConstrainedBox(maxWidth: 720, ...))` chống bè ngang trên Desktop.
- Sử dụng thẻ `AppCard` cho form mô tả và khối thư viện ảnh đính kèm.
- Nút xóa ảnh dạng huy hiệu mờ tinh tế, viền siêu mỏng, bo góc ảnh 12px.
- Nút lưu thay đổi có loading indicator và disable khi đang gửi dữ liệu.
- Chống tràn trên 320dp x 600dp (Zoom 1.3x).

---

### Task 3: Nâng cấp `ManagementInvoiceDetailScreen` (Workstation Chi Tiết Hóa Đơn BQL)
**Files:**
- Modify: `lib/features/management/screens/management_invoice_detail_screen.dart`
- Create/Update Test: `test/features/management/management_invoice_detail_responsive_test.dart`

**Yêu cầu kỹ thuật:**
- Bố cục Split-Screen Desktop $\ge 900$dp (`maxWidth: 1300`):
  - Cột trái: Thẻ tóm tắt `AppCard` (Căn hộ, Kỳ phí, Hạn thanh toán, Tổng tiền to rõ) + Cụm nút hành động nghiệp vụ (Xem biên lai, Xác nhận thu tiền, In ấn/Xuất PDF 3 định dạng, Sửa, Xóa).
  - Cột phải: Danh mục chi tiết các khoản phí (`invoice_items`) với icon trực quan, đơn giá, số lượng, thành tiền.
- Mobile (< 900dp, `maxWidth: 600`):
  - Thanh đáy `_buildBottomAction` có `Center(heightFactor: 1.0, child: ConstrainedBox(maxWidth: 600, ...))` chống chiếm trọn màn hình.
  - `_buildInfoRow` bọc trong `Expanded(flex: 5)` và `Expanded(flex: 6)` chống tràn 100% trên 320dp (Zoom 1.3x).

---

### Task 4: Kiểm Thử Toàn Diện, Static Analysis & Cập Nhật Tri Thức Hệ Thống
**Files:**
- Verify: Toàn bộ suite test liên quan
- Update: Knowledge Graph qua `graphify update .`

**Yêu cầu kỹ thuật:**
- Chạy toàn bộ test suites của phân hệ sự cố và hóa đơn.
- Chạy `dart analyze lib test` đạt 0 issues.
- Chạy `impeccable detect` kiểm tra chất lượng giao diện.
- Cập nhật Knowledge Graph `graphify update .`.
- Commit hoàn thành phân hệ vào nhánh `main`.
