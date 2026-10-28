# Tài Liệu Thiết Kế: Cải Tiến Giao Diện Trang Chủ Cư Dân Theo Chuẩn Wireframe

- **Ngày tạo:** 2026-09-30
- **Trạng thái:** Chờ phê duyệt (Pending Approval)
- **Tác giả:** Antigravity Agent & Developer

---

## 1. Mục Tiêu & Bối Cảnh

Tài liệu [`docs/wireframes.md`](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/wireframes.md) mục 2 định nghĩa rõ ràng cấu trúc Trang chủ Cư dân gồm:
1. Header chào mừng với tên cư dân và **Nút Đăng xuất nhanh (Icon Logout)**.
2. Thẻ **TỔNG QUAN HÓA ĐƠN** với:
   - Tổng tiền cần đóng (VNĐ).
   - Số lượng hóa đơn chưa thanh toán: `( X hóa đơn chưa thanh toán )` hoặc `( Đã hoàn tất đóng phí các kỳ )`.
   - Nút hành động trực quan: `[ THANH TOÁN NGAY ]` khi có nợ phí, chuyển trực tiếp sang tab Hóa đơn.
3. Đồng bộ thẻ phản ánh và hóa đơn sang widget [`AppCard`](file:///c:/Users/ADMIN/StudioProjects/pka_home/lib/core/widgets/app_card.dart) nhằm hỗ trợ toàn diện Chế độ tối (Dark Mode) và Chế độ sáng (Light Mode), loại bỏ màu hardcode.

---

## 2. Ràng Buộc Kỹ Thuật (Constraints)

- **Ngôn ngữ**: 100% Tiếng Việt chuẩn mực ("TỔNG QUAN HÓA ĐƠN", "THANH TOÁN NGAY", "Đăng xuất", "Bạn có chắc chắn muốn đăng xuất?").
- **Biểu tượng**: Sử dụng biểu tượng Material Icons chuẩn (`Icons.payment`, `Icons.receipt_long`, `Icons.logout_outlined`).
- **Màu sắc & Giao diện**: Sử dụng `AppCard` và `Theme.of(context)`, không hardcode `Colors.white` hay `Colors.orange.shade50`.
- **Tương tác**: Nút `THANH TOÁN NGAY` kích hoạt chuyển `_selectedIndex = 1` để cư dân xem chi tiết các khoản phí và quét mã VietQR.

---

## 3. Thiết Kế Chi Tiết

### 3.1. Thẻ "Tổng quan hóa đơn" (`ResidentHomeScreen`)
- Thay thế `Card` dùng màu gradient hardcode bằng `AppCard`.
- Tiêu đề khối: **"Tổng quan hóa đơn"** (kiểu chữ `titleMedium`, in hoa nhẹ, màu nhấn `AppTheme.primary`).
- Bố cục bên trong `AppCard`:
  - Dòng 1: Nhãn "Tổng tiền cần đóng" kèm biểu tượng trạng thái (`Icons.warning_amber_rounded` màu đỏ/cam khi có nợ, `Icons.check_circle_outline` màu xanh khi đã thanh toán hết).
  - Dòng 2: Giá trị số tiền lớn, đậm (Ví dụ: `1.500.000 đ`).
  - Dòng 3: Dòng phụ chú thích số lượng hóa đơn:
    - Nếu `totalUnpaid > 0`: `( ${unpaidInvoices.length} hóa đơn chưa thanh toán )` với màu chữ cảnh báo hoặc `AppTheme.textSecondary`.
    - Nếu `totalUnpaid == 0`: `( Đã thanh toán đầy đủ các kỳ phí )` với màu xanh lá thành công.
  - Dòng 4: Nút hành động:
    - Nếu `totalUnpaid > 0`: `ElevatedButton.icon` với nhãn **"THANH TOÁN NGAY"**, icon `Icons.payment`, `backgroundColor: AppTheme.primary`, kích hoạt `_onItemTapped(1)`.
    - Nếu `totalUnpaid == 0`: `OutlinedButton.icon` với nhãn **"XEM HÓA ĐƠN"**, icon `Icons.receipt_long`, kích hoạt `_onItemTapped(1)`.

### 3.2. Nút Đăng xuất nhanh trên Header (`SliverAppBar`)
- Bổ sung nút `IconButton(icon: Icon(Icons.logout_outlined, color: Colors.white), tooltip: 'Đăng xuất')` trên thanh Header của Cư dân.
- Khi bấm: Hiển thị `AlertDialog` xác nhận:
  - Tiêu đề: "Đăng xuất"
  - Nội dung: "Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng không?"
  - Nút Hủy và Nút "Đăng xuất" (`AppTheme.error`) gọi `ref.read(authProvider.notifier).logout()`.

### 3.3. Chuẩn hóa Dark Mode cho các thẻ phụ
- Chuyển `Card` trong phần "Tiến độ phản ánh" sang `AppCard`.
- Giữ vững tương thích layout responsive, co giãn font chữ theo hệ số `fontScale`.

---

## 4. Kế Hoạch Kiểm Thử (Test Plan)

1. **Widget Test (`test/features/resident/resident_home_wireframe_test.dart`)**:
   - Kiểm tra hiển thị tổng tiền cần đóng và dòng `( 1 hóa đơn chưa thanh toán )`.
   - Kiểm tra nút "THANH TOÁN NGAY" xuất hiện khi có hóa đơn chưa đóng và khi nhấn thì chuyển sang tab Hóa đơn.
   - Kiểm tra nút Đăng xuất trên AppBar hiển thị hộp thoại xác nhận khi được nhấn.
2. **Kiểm thử Linter (`dart analyze`)**: Đạt 0 cảnh báo, 0 lỗi.
3. **Chạy toàn bộ Test Suite (`flutter test`)**: Toàn bộ unit và widget tests tiếp tục passed.
