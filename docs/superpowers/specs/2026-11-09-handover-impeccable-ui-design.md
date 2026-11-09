# Đặc Tả Thiết Kế: Nâng Cấp Giao Diện Phân Hệ Bàn Giao & Kiểm Kê Căn Hộ (Impeccable & Anti-RenderFlex)

**Mục tiêu:** Nâng cấp toàn diện giao diện và trải nghiệm phân hệ Bàn Giao Căn Hộ & Kiểm Kê Tài Sản Số Hóa (`ResidentHandoverScreen`, `ResidentHandoverDetailScreen`, `HandoverManagementScreen`, `InspectionWorkstationScreen`) theo triết lý thiết kế **Impeccable Taste** và cam kết **Anti-RenderFlex Guarantee** 100% (Mobile 320dp x 600dp kèm Text Zoom 1.3x, Web Enterprise Desktop $\ge 900$dp, `maxWidth: 1400`).

---

## 1. Phân Tích Thực Trạng & Điểm Nghẽn UI Hiện Tại

### 1.1 Phía Cư Dân
- **`ResidentHandoverScreen`:**
  - Còn sử dụng mã màu hardcode rời rạc (`Color(0xFF1E3A8A)`).
  - Sử dụng widget `Card` nguyên bản có bóng đổ thô thay vì `AppCard` viền siêu mỏng chuẩn B2B SaaS.
  - Hàng tiêu đề dùng `Spacer()` và không bọc flex factor, có nguy cơ tràn `RenderFlex` khi mã biên bản hoặc trạng thái dài.
  - Trên Web Desktop $\ge 900$dp, danh sách thẻ bị kéo dãn 100% chiều ngang màn hình.
- **`ResidentHandoverDetailScreen`:**
  - Cấu trúc đơn cột dọc kéo dài, trên Desktop phải cuộn trang liên tục để đối soát giữa bảng tính tiền cọc và từng hạng mục tài sản.
  - Trên Mobile 320dp kèm Text Zoom 1.3x: Các hàng hiển thị chỉ số điện nước, bảng chiết tính tiền cọc và dải nút tác vụ (Khiếu nại / Ký tên) dễ bị tràn cạnh phải.

### 1.2 Phía Ban Quản Lý
- **`HandoverManagementScreen`:**
  - Dòng KPI Header (4 thẻ chỉ số) đặt trong `Row` cứng, không bọc `LayoutBuilder` hay cuộn ngang -> chắc chắn tràn hơn 80px trên màn hình 320dp khi Text Zoom 1.3x.
  - Thẻ danh sách biên bản chưa có chế độ xem bảng dữ liệu chuyên nghiệp (Data Table) cho Web Workstation BQL.
- **`InspectionWorkstationScreen`:**
  - Trạm kiểm kê tài sản hiện trường chứa nhiều trường nhập liệu (chỉ số điện, nước, tiền cọc, phân loại phòng, tình trạng đồ đạc, giá thay thế, ảnh minh chứng).
  - Trên Mobile 320dp, các cụm chip chọn tình trạng ('Tốt', 'Cũ', 'Hư hỏng', 'Mất') và trường nhập giá sửa chữa bị ép dẹp, dễ gây overflow.
  - Trên Desktop chưa tận dụng không gian 2 cột để kỹ thuật viên BQL vừa quan sát thông tin chung vừa chấm điểm kiểm kê tài sản.

---

## 2. Kiến Trúc & Thiết Kế Giao Diện Mới

### 2.1 Chuẩn Hóa Màu Sắc & Ngôn Ngữ
- 100% tiếng Việt chuẩn mực SaaS B2B theo `.agents/rules/design-rules.md`.
- Sử dụng màu từ `AppTheme` (`AppTheme.primary`, `AppTheme.textPrimary`, `AppTheme.textSecondary`, `AppStatusColors.paid`, `AppTheme.error`, `AppTheme.warning`).
- Định dạng mã căn hộ chuẩn `A0110` / `a0110`.

### 2.2 Phía Cư Dân
1. **`ResidentHandoverScreen`:**
   - Bọc toàn bộ body trong `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 1000), ...))`.
   - Sử dụng thẻ `AppCard` viền siêu mỏng, bo góc 12px.
   - Header thẻ: Icon loại biên bản (Move-in / Move-out) 40x40 bo tròn, mã biên bản bọc `Expanded` + `ellipsis`, badge trạng thái bọc `ConstrainedBox(maxWidth: 105)` + `FittedBox`.
   - Hàng thông tin căn hộ và BQL bọc `Wrap` linh hoạt.

2. **`ResidentHandoverDetailScreen`:**
   - **Mobile (< 900dp):** Bố cục 1 cột cuộn mượt mà.
     - Khối thông tin chung & chỉ số điện nước bàn giao: Card tổng hợp với icon trực quan.
     - Khối chiết tính tiền cọc & cấn trừ hư hại: Dạng hóa đơn đối soát rõ ràng, số tiền bọc `FittedBox`.
     - Danh sách tài sản kiểm kê: Nhóm theo khu vực phòng (Phòng khách, Bếp, Phòng ngủ, WC), hiển thị ảnh minh chứng hư hỏng (nếu có) và ghi chú.
     - Thanh tác vụ cố định ở đáy: Nút "Gửi khiếu nại" (Outlined) và "Ký tên xác nhận" (Elevated) bọc `FittedBox` chống tràn.
   - **Desktop Web ($\ge 900$dp, `maxWidth: 1200`):** Split-Screen 2 cột:
     - **Cột Trái (Flex 5):** Thẻ biên bản, Chỉ số điện nước, Bảng chiết tính cọc & Trạng thái chữ ký hai bên.
     - **Cột Phải (Flex 7):** Toàn bộ danh mục kiểm kê tài sản theo từng phòng kèm ảnh hiện trường và các nút hành động.

### 2.3 Phía Ban Quản Lý
1. **`HandoverManagementScreen`:**
   - **Executive Handover KPI Dashboard:** Bọc `LayoutBuilder`:
     - Nếu width $< 420$dp: Cuộn ngang mượt mà `SingleChildScrollView(scrollDirection: Axis.horizontal)`.
     - Nếu width $\ge 420$dp: Chia đều các cột với khoảng cách 10px.
   - **Danh sách biên bản đa nền tảng:**
     - Mobile (< 900dp): Danh sách thẻ `AppCard` gọn gàng, nút hành động bọc `FittedBox`.
     - Desktop ($\ge 900$dp, `maxWidth: 1400`): Chế độ Workstation với Data Table hoặc lưới 2 cột tùy biến, hiển thị mã biên bản, loại, căn hộ, đại diện BQL, tình trạng cọc và thao tác nhanh (Mở trạm kiểm kê / Xuất PDF / Ký số).

2. **`InspectionWorkstationScreen`:**
   - **Mobile (< 900dp):**
     - Các trường chỉ số điện nước, tiền cọc bọc `Expanded` hoặc `Column` co giãn.
     - Cụm chọn tình trạng tài sản dùng `Wrap(spacing: 6, runSpacing: 6)` thay vì ép hàng cứng.
     - Trường nhập chi phí sửa chữa và nút chụp ảnh bọc `Row` với `Expanded` co giãn linh hoạt.
   - **Desktop Web ($\ge 900$dp, `maxWidth: 1400`):** Split-Screen Workstation 2 cột:
     - **Cột Trái (Flex 5):** Bảng tổng hợp căn hộ, Loại biên bản, Đồng hồ điện nước đầu vào, Tiền cọc bảo chứng, Ghi chú BQL và Khung chữ ký nhân viên BQL.
     - **Cột Phải (Flex 7):** Trạm kiểm kê tài sản chi tiết từng phòng, bộ lọc phòng, thao tác thêm/sửa tình trạng tài sản, ghi nhận chi phí hư hại và tải ảnh hiện trường.

---

## 3. Kế Hoạch Kiểm Thử Tự Động (TDD & Anti-RenderFlex)
- Tạo mới 2 test suite responsive chuyên biệt:
  - `test/features/resident/resident_handover_responsive_test.dart`
  - `test/features/management/handover_management_responsive_test.dart`
- Điều kiện kiểm thử ngặt nghèo:
  - Mobile cực hẹp: `Size(320, 600)` kèm Text Scale `1.3x`.
  - Desktop Enterprise: `Size(1200, 900)` và `Size(1400, 900)`.
  - Yêu cầu: `tester.takeException()` luôn là `isNull`, không có bất kỳ ngoại lệ `RenderFlex overflowed` nào.
