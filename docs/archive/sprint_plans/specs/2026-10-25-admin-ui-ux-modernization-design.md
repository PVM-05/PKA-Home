# Thiết Kế Cải Tiến Giao Diện Admin / Ban Quản Lý (A1 - A6)

- **Mục tiêu:** Tối ưu hóa trải nghiệm người dùng (UX) và tính thẩm mỹ (UI) cho toàn bộ phân hệ Quản trị viên & Ban quản lý (A1-A6), loại bỏ thao tác cuộn ngang thừa thãi, phân cấp luồng thông tin rõ ràng, chuẩn hóa thẻ thống kê, tối ưu bộ lọc và quản lý hóa đơn đối soát.
- **Nguyên tắc cốt lõi:**
  - 100% tiếng Việt chuẩn mực, thuật ngữ tự nhiên theo `design-rules.md`.
  - Giữ nguyên toàn bộ logic dữ liệu, Riverpod providers và phân quyền RBAC hiện hành.
  - Tương thích hoàn hảo với màn hình hẹp (từ 360dp width) không gây lỗi RenderFlex overflow.
  - Tuân thủ cấu trúc Feature-first Flutter, không can thiệp CSDL backend.

---

## 1. Thiết Kế Chi Tiết Từng Hạng Mục (A1 - A6)

### A1. Tái cấu trúc Thao tác nhanh Dashboard (`management_home_screen.dart`)
- **Vấn đề hiện tại:** Danh sách thao tác nhanh dài đặt trong một hàng cuộn ngang (`SingleChildScrollView(scrollDirection: Axis.horizontal)`), người dùng khó phát hiện các tính năng ở cuối.
- **Giải pháp:**
  - **Lối tắt chính (4–6 mục thường dùng nhất):** Bố trí dạng lưới 2 cột hoặc hàng thẻ trực quan ngay trên Dashboard:
    1. *Duyệt liên kết* (kèm badge yêu cầu chờ).
    2. *Xử lý sự cố* (kèm badge phản ánh mới).
    3. *Lập hóa đơn* (truy cập nhanh kế toán).
    4. *Duyệt điện nước* (kèm badge chỉ số chờ duyệt).
    5. *Duyệt xe* (kèm badge xe chờ duyệt).
    6. *Nút "Xem tất cả thao tác"* (mở Modal Bottom Sheet).
  - **Modal Bottom Sheet ("Tất cả thao tác quản trị"):** Phân nhóm rành mạch theo 3 phân hệ chính:
    - **Cư dân & Căn hộ:** Duyệt liên kết, Danh sách căn hộ, Cẩm nang tòa nhà.
    - **Tài chính & Thu phí:** Lập hóa đơn, Giao dịch thanh toán, Duyệt số điện nước.
    - **Vận hành & Kỹ thuật:** Xử lý sự cố, Đặt chỗ tiện ích, Bảo trì thiết bị, Duyệt phương tiện, Đánh giá dịch vụ, Ủy quyền vai trò.
    - Giữ nguyên quyền hạn RBAC: Chỉ hiển thị các mục mà vai trò hiện tại có quyền truy cập.

---

### A2. Phân cấp Thông tin Dashboard Admin (`management_home_screen.dart`)
- **Vấn đề hiện tại:** Các khối nội dung phân tán, chưa có thứ tự ưu tiên thị giác rõ ràng.
- **Cấu trúc phân tầng đề xuất:**
  1. **Tầng 1 - Công việc cần xử lý ngay (Actionable Priority):**
     - Đặt ngay sau Thao tác nhanh.
     - Hiển thị danh sách phản ánh khẩn cấp (`priority: high/urgent`), thông báo hóa đơn chờ BQL xác nhận, yêu cầu liên kết căn hộ.
     - Nếu không có việc gấp: Hiển thị thẻ xanh nhẹ nhàng "Không có sự cố khẩn cấp nào cần xử lý".
  2. **Tầng 2 - Cư dân & Căn hộ:**
     - Các thẻ thống kê số căn hộ, số cư dân, tỷ lệ lấp đầy.
  3. **Tầng 3 - Tài chính & Dòng tiền:**
     - Tiến độ thu phí kỳ hiện tại (`_buildFinancialProgressCard`).
     - Biểu đồ xu hướng thu (`RevenueTrendChart`).
     - Quỹ bảo trì (`MaintenanceFundCard`).
     - Lịch sử giao dịch gần đây.
  4. **Tầng 4 - Vận hành & Kỹ thuật:**
     - Thống kê sự cố đang xử lý, bảo trì thiết bị và kiểm toán.

---

### A3. Chuẩn hóa Thẻ Thống kê (`stat_card.dart`)
- **Vấn đề hiện tại:** Tiêu đề bị cắt cụt do `maxLines: 1`, chiều cao các thẻ chưa đồng đều.
- **Giải pháp:**
  - Nâng `maxLines: 2` cho tiêu đề, đặt trong container có chiều cao cố định (`SizedBox(height: 32)`) để đảm bảo các thẻ trong lưới `GridView` luôn có cùng chiều cao và thẳng hàng tuyệt đối.
  - Bố cục thẳng hàng theo thứ tự: `[Icon container] -> SizedBox(8) -> [Tiêu đề 2 dòng] -> SizedBox(4) -> [Số liệu FittedBox scaleDown]`.
  - Giữ kích thước số liệu tối thiểu rõ ràng, không để chữ số bị teo quá nhỏ trên màn hình 360dp.

---

### A4. Tinh gọn Thanh điều hướng & Nhãn hiển thị (`management_home_screen.dart`)
- **Vấn đề hiện tại:** Một số nhãn viết tắt ("Bảo trì TB", "Đánh giá DV"), thanh điều hướng cần rõ ràng và không bị che bởi badge.
- **Giải pháp:**
  - Thanh điều hướng dưới (`NavigationBar`) duy trì tối đa 5 tab chính cốt lõi: *Tổng quan, Cư dân, Hóa đơn, Phản ánh, Thông báo*.
  - Nhãn hiển thị đầy đủ, tiếng Việt tự nhiên và không viết tắt.
  - Vị trí `Badge` hiển thị số lượng được tinh chỉnh với `offset` hợp lý, không che mất icon điều hướng.

---

### A5. Tối ưu Bộ lọc Quản lý Cư dân (`resident_management_screen.dart`)
- **Vấn đề hiện tại:** 2 hàng chip lọc (Vai trò và Trạng thái) chiếm diện tích dọc lớn, đẩy danh sách cư dân xuống dưới.
- **Giải pháp:**
  - Giữ thanh tìm kiếm tiện ích ở trên cùng.
  - Thay 2 hàng chip bằng một **Hàng công cụ tinh gọn**:
    - Nút **"Bộ lọc"** (Icon `Icons.filter_list`, có badge đếm số lượng bộ lọc đang kích hoạt).
    - Dòng đếm kết quả: **"Hiển thị X/Y người dùng"** (tự động cập nhật theo tìm kiếm và bộ lọc).
  - Khi có bộ lọc đang chọn khác mặc định: Hiển thị một hàng **Active Filter Chips** nhỏ gọn với nút `x` để người dùng có thể xóa nhanh từng tiêu chí chỉ với 1 chạm.
  - Nhấn nút "Bộ lọc" sẽ mở **Filter Bottom Sheet**:
    - Chọn Vai trò (Tất cả, Cư dân, Quản trị viên, Kế toán, Kỹ thuật viên).
    - Chọn Trạng thái tài khoản (Tất cả, Đang hoạt động, Đã khóa, Đã vô hiệu hóa).
    - Nút "Đặt lại" và "Áp dụng".

---

### A6. Tối ưu Tìm kiếm & Đối soát Hóa đơn (`invoice_management_screen.dart`)
- **Vấn đề hiện tại:** AppBar chật chội khi có nhiều nút, chưa hiển thị số lượng trên từng trạng thái hóa đơn để phục vụ đối soát.
- **Giải pháp:**
  - Đưa số lượng hóa đơn trực tiếp lên nhãn của Filter Chips:
    - *Tất cả (N)*
    - *Chờ xác nhận (N)* — Làm nổi bật với màu vàng hổ phách (`AppStatusColors.pendingConfirmation`).
    - *Đang nợ (N)* — Màu cam đỏ (`AppStatusColors.unpaid`).
    - *Đã thanh toán (N)* — Màu xanh lục (`AppStatusColors.paid`).
  - Gom các thao tác phụ (Tạo HĐ hàng loạt, Xuất file Excel) vào menu tùy chọn hoặc bố trí khoa học, tránh chen chúc trên AppBar màn hình nhỏ.
  - Chuẩn hóa bố cục thẻ hóa đơn: Mã căn hộ & Kỳ thanh toán to rõ, hạn nộp và tổng tiền hiển thị nhất quán, đối soát dễ dàng.

---

## 2. Kế hoạch Kiểm thử & Xác minh (Verification Plan)
1. **Kiểm thử Unit & Widget Tests:**
   - Cập nhật và bổ sung widget tests cho `stat_card_test.dart` (kiểm tra co giãn 2 dòng tiêu đề).
   - Bổ sung test cho bộ lọc `resident_management_screen_filter_test.dart`.
   - Bổ sung test cho nhãn bộ lọc và đếm số lượng hóa đơn trong `invoice_management_screen_test.dart`.
2. **Kiểm tra Phân tích mã nguồn:**
   - Chạy `flutter analyze` bảo đảm 0 warning, 0 error.
   - Chạy toàn bộ test suite `flutter test` đảm bảo 100% passing.
