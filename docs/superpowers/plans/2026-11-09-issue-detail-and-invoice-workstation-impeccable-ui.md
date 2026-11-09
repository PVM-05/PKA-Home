# Kế Hoạch Triển Khai: Nâng Cấp Chi Tiết Sự Cố & Chi Tiết Hóa Đơn BQL (Impeccable & Anti-RenderFlex)

- **Mục tiêu:** Nâng cấp toàn diện 3 màn hình nghiệp vụ trọng yếu (`IssueDetailScreen`, `EditIssueScreen`, `ManagementInvoiceDetailScreen`) theo triết lý Impeccable Taste và Anti-RenderFlex Guarantee 100%.
- **Nhánh thực hiện:** `main` (commit trực tiếp theo quy định dự án).
- **Tài liệu đặc tả:** `docs/superpowers/specs/2026-11-09-issue-detail-and-invoice-workstation-impeccable-ui-design.md`.
- **Trạng thái:** [x] HOÀN TẤT 100% (4/4 Tasks Đã Nghiệm Thu, 0 Warning, 0 RenderFlex Error).

---

## Danh Sách Task Triển Khai

### [x] Task 1: Nâng cấp `IssueDetailScreen` (Chi Tiết Sự Cố & Trao Đổi Cư Dân - BQL)
**Files:**
- Modify: `lib/features/resident/screens/issue_detail_screen.dart`
- Create/Update Test: `test/features/resident/issue_detail_responsive_test.dart`

**Kết quả:**
- Hỗ trợ Desktop Split-Screen $\ge 900$dp (`maxWidth: 1200`): Cột trái chứa thông tin chi tiết, timeline, vật tư và đánh giá dịch vụ; Cột phải là hộp trao đổi comment tương tác.
- Mobile (< 900dp, `maxWidth: 600`): Chống tràn 100% trên 320dp x 600dp kèm font scale 1.3x.
- Sử dụng thẻ `AppCard` viền siêu mỏng mờ theo `DESIGN.md`.
- Đã commit: `f170892` `feat(resident): nang cap giao dien chi tiet su co split-screen desktop va chong tran 100%`.

---

### [x] Task 2: Nâng cấp `EditIssueScreen` (Chỉnh Sửa Phản Ánh & Quản Lý Ảnh)
**Files:**
- Modify: `lib/features/resident/screens/edit_issue_screen.dart`
- Create/Update Test: `test/features/resident/edit_issue_responsive_test.dart`

**Kết quả:**
- Bọc toàn bộ nội dung trong `Center(ConstrainedBox(maxWidth: 720, ...))` chống bè ngang trên Desktop.
- Sử dụng thẻ `AppCard` cho form mô tả và khối thư viện ảnh đính kèm.
- Nút xóa ảnh dạng huy hiệu mờ tinh tế, viền siêu mỏng, bo góc ảnh 12px.
- Chống tràn 100% trên 320dp x 600dp (Zoom 1.3x).
- Đã commit: `2279e72` `feat(resident): nang cap bieu mau chinh sua su co can giua responsive va app card`.

---

### [x] Task 3: Nâng cấp `ManagementInvoiceDetailScreen` (Workstation Chi Tiết Hóa Đơn BQL)
**Files:**
- Modify: `lib/features/management/screens/management_invoice_detail_screen.dart`
- Create/Update Test: `test/features/management/management_invoice_detail_responsive_test.dart`

**Kết quả:**
- Bố cục Split-Screen Desktop $\ge 900$dp (`maxWidth: 1300`): Cột trái là thẻ tóm tắt tài chính và panel nút thao tác nghiệp vụ; Cột phải là danh mục chi tiết các khoản phí dịch vụ.
- Mobile (< 900dp, `maxWidth: 600`): Thanh đáy `_buildBottomAction` có `Center(heightFactor: 1.0, child: ConstrainedBox(maxWidth: 600, ...))` chống chiếm trọn màn hình.
- `_buildInfoRow` bọc trong `Expanded(flex: 5)` và `Expanded(flex: 6)` chống tràn 100% trên 320dp (Zoom 1.3x).
- Đã commit: `8611b16` `feat(management): nang cap workstation chi tiet hoa don split-screen va app card`.

---

### [x] Task 4: Kiểm Thử Toàn Diện, Static Analysis & Cập Nhật Tri Thức Hệ Thống
**Files:**
- Verify: Toàn bộ suite test liên quan
- Update: Knowledge Graph qua `graphify update .`

**Kết quả:**
- Toàn bộ 20 bài test responsive và logic pass 100%.
- `dart analyze lib test`: **0 issues found** (0 warning, 0 error).
- `impeccable detect`: 0 anti-pattern findings.
- Knowledge Graph đồng bộ cập nhật 14,250 nodes, 22,344 edges, 747 communities.
