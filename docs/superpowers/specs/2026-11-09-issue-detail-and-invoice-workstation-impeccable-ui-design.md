# Đặc Tả Kỹ Thuật UI/UX: Nâng Cấp Chi Tiết Sự Cố & Chi Tiết Hóa Đơn BQL (Impeccable Taste)

- **Mục tiêu:** Tái thiết kế toàn diện 3 màn hình nghiệp vụ trọng yếu (`IssueDetailScreen`, `EditIssueScreen`, `ManagementInvoiceDetailScreen`) đạt tiêu chuẩn thẩm mỹ thương mại B2B SaaS cao cấp (Impeccable Taste), loại bỏ triệt để lỗi RenderFlex overflow trên mobile hẹp (320dp x 600dp, Text Zoom 1.3x) và hỗ trợ bố cục Split-Screen Enterprise Workstation trên Web/Desktop ($\ge 900$dp).
- **Phạm vi màn hình:**
  1. `lib/features/resident/screens/issue_detail_screen.dart`
  2. `lib/features/resident/screens/edit_issue_screen.dart`
  3. `lib/features/management/screens/management_invoice_detail_screen.dart`
- **Tiêu chuẩn thiết kế:** Tuân thủ chặt chẽ `DESIGN.md`, `PRODUCT.md`, `coding-rules.md`, `design-rules.md`. 100% tiếng Việt chuẩn mực SaaS, không emoji.

---

## 1. Yêu Cầu Thiết Kế Chi Tiết

### 1.1. `IssueDetailScreen` (Chi Tiết Phản Ánh & Xử Lý Hiện Trường)
- **Vấn đề hiện tại:**
  - Danh sách cuộn đơn kéo dãn hết chiều rộng trên Desktop/Web 1200dp - 1400dp, làm các thẻ quá dài và input bar chat bị kéo dãn toàn màn hình.
  - Các hàng thông tin và chips (SLA countdown, chuyên môn, phòng) dễ có nguy cơ tràn hàng ngang trên màn hình hẹp 320dp khi phóng to chữ 1.3x.
- **Giải pháp Impeccable Taste:**
  - **Bố cục Desktop ($\ge 900$dp, `maxWidth: 1200`):**
    - Chia 2 cột tỷ lệ tối ưu (Split-Screen):
      - **Cột Trái (Width ~520dp):**
        - Thẻ Header chi tiết sự cố (`AppCard` viền mờ `AppTheme.outlineLight`), hiển thị badges trạng thái, SLA countdown, chuyên môn, thông tin người báo & kỹ thuật viên phụ trách.
        - Thư viện ảnh phản ánh và ảnh nghiệm thu (bo góc 12px, xem ảnh full qua `PhotoViewerScreen`).
        - Tiến trình xử lý (Status Timeline thanh lịch, kết nối mượt mà).
        - Thẻ vật tư kỹ thuật đã sử dụng (`issueMaterialsProvider`), phân loại rõ ràng vật tư tính phí căn hộ và miễn phí.
        - Đánh giá chất lượng dịch vụ (5 sao, tiêu chí tốc độ/thái độ/kỹ thuật).
      - **Cột Phải (Flexible):**
        - Hộp trao đổi trực tiếp (`issueCommentsProvider`), avatar người dùng/BQL, huy hiệu BQL chính thức (`AppTheme.primary`).
        - Khung nhập tin nhắn tích hợp dưới chân cột phải, không bị kéo dãn toàn màn hình.
  - **Bố cục Mobile (< 900dp, `maxWidth: 600`):**
    - Danh sách cuộn mượt mà có padding an toàn.
    - Toàn bộ chips, badges và nhãn thông tin bọc trong `Wrap` và `FittedBox` với `overflow: TextOverflow.ellipsis`.
    - Input bar ở chân màn hình có padding an toàn `MediaQuery.padding.bottom` và giới hạn độ cao.

### 1.2. `EditIssueScreen` (Chỉnh Sửa Phản Ánh & Quản Lý Ảnh Hiện Trường)
- **Vấn đề hiện tại:**
  - Form căn giữa nhưng chưa giới hạn độ rộng tối đa trên desktop làm các trường nhập liệu kéo bè.
  - Nút xóa ảnh hình tròn màu đỏ cơ bản, chưa đạt nét tinh tế của `DESIGN.md`.
- **Giải pháp Impeccable Taste:**
  - Bọc toàn bộ nội dung trong `Center(ConstrainedBox(maxWidth: 720, ...))`.
  - Sử dụng thẻ `AppCard` cho khối thông tin phản ánh và khối hình ảnh đính kèm.
  - Lưới ảnh hiện có và ảnh mới: bo góc 12px, nút xóa ảnh dạng huy hiệu mờ tinh tế, viền siêu mỏng.
  - Nút thêm ảnh có hiệu ứng hover/focus và icon viền tinh tế.
  - Nút lưu thay đổi có trạng thái loading indicator và vô hiệu hóa khi đang xử lý.

### 1.3. `ManagementInvoiceDetailScreen` (Workstation Chi Tiết Hóa Đơn & Thu Phí BQL)
- **Vấn đề hiện tại:**
  - Chưa tối ưu cho màn hình lớn của Ban Quản Lý (kế toán viên thường dùng Web Desktop $\ge 1200$dp).
  - Thanh hành động đáy (`_buildBottomAction`) cần đảm bảo có `heightFactor: 1.0` để không chiếm trọn màn hình làm che khuất các nút AppBar như bài học ở resident invoice.
  - Các hàng thông tin tóm tắt `_buildInfoRow` cần chống tràn tuyệt đối khi font zoom 1.3x trên màn hình hẹp 320dp.
- **Giải pháp Impeccable Taste:**
  - **Bố cục Desktop ($\ge 900$dp, `maxWidth: 1300`):**
    - Chia 2 cột chuyên nghiệp:
      - **Cột Trái (Width ~440dp):**
        - Thẻ Tóm tắt hóa đơn (`AppCard`): Căn hộ, Kỳ phí, Hạn thanh toán, Tổng tiền với typography đậm nét rõ ràng theo màu trạng thái (`AppStatusColors`).
        - Khối hành động nghiệp vụ (Action Hub): Xem biên lai điện tử, Xác nhận đã thu tiền (tiền mặt / chuyển khoản), In ấn & Xuất PDF 3 định dạng (Hóa đơn A4, Biên lai A4, Phiếu nhiệt 80mm), Sửa hóa đơn, Xóa hóa đơn.
      - **Cột Phải (Flexible):**
        - Danh mục chi tiết các khoản phí (`invoice_items`): hiển thị rõ đơn giá, định mức số lượng, thành tiền từng khoản (Điện, Nước, Phí quản lý, Gửi xe, Rác, Thẻ thang máy...).
  - **Bố cục Mobile (< 900dp, `maxWidth: 600`):**
    - Cuộn dọc tự nhiên, thanh đáy `_buildBottomAction` có `Center(heightFactor: 1.0, child: ConstrainedBox(maxWidth: 600, ...))`.
    - `_buildInfoRow` sử dụng `Expanded(flex: 5)` cho nhãn và `Expanded(flex: 6)` cho giá trị kèm `overflow: TextOverflow.ellipsis`.

---

## 2. Tiêu Chí Nghiệm Thu (Quality Gate)
1. **Anti-RenderFlex Guarantee 100%:**
   - Kiểm thử tự động trên Mobile hẹp 320dp x 600dp với Text Scale 1.3x: 0 overflow error.
   - Kiểm thử tự động trên Desktop 1200dp x 900dp: giao diện cân đối, không kéo dãn, 0 overflow error.
2. **Tuân thủ quy chuẩn thiết kế:**
   - 100% Tiếng Việt chuẩn mực SaaS B2B, không emoji.
   - Bảng màu semantic từ `AppTheme` và `AppStatusColors`.
3. **Chất lượng mã nguồn:**
   - `dart analyze lib test` đạt 0 issues (0 warning, 0 error).
   - Kiểm thử hồi quy toàn bộ phân hệ pass 100%.

