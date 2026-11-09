# Đặc Tả Kỹ Thuật UI/UX: Nâng Cấp Phân Hệ Truyền Thông Tòa Nhà & Cẩm Nang Cư Dân (Impeccable Taste)

- **Mục tiêu:** Nâng cấp toàn diện 4 màn hình truyền thông và cẩm nang tòa nhà đạt chuẩn B2B SaaS Impeccable Taste, loại bỏ hoàn toàn nguy cơ RenderFlex overflow trên màn hình mobile 320dp x 600dp (Text Zoom 1.3x) và tối ưu bố cục dạng lưới / Split-Screen trên Web Desktop $\ge 900$dp.
- **Phạm vi màn hình:**
  1. `lib/features/management/screens/announcement_management_screen.dart`
  2. `lib/features/resident/screens/resident_announcement_detail_screen.dart`
  3. `lib/features/management/screens/handbook_management_screen.dart`
  4. `lib/features/resident/screens/resident_handbook_screen.dart`
- **Tiêu chuẩn thiết kế:** Tuân thủ chặt chẽ `DESIGN.md`, `PRODUCT.md`, `coding-rules.md`, `design-rules.md`. 100% tiếng Việt chuẩn mực SaaS, không emoji.

---

## 1. Yêu Cầu Thiết Kế Chi Tiết

### 1.1. `AnnouncementManagementScreen` (Quản Lý & Phát Thông Báo BQL)
- **Vấn đề hiện tại:**
  - Danh sách thẻ Card cuộn đơn kéo dãn hết chiều rộng trên Desktop 1200dp - 1400dp, làm các thẻ quá dài và mất cân đối thị giác.
  - Hàng chứa dải chip (Danh mục, Ghim, Đối tượng, Thời gian) và nhóm 3 nút icon (Broadcast, Edit, Delete) có nguy cơ xung đột chiều ngang và tràn dòng trên mobile 320dp khi phóng to chữ 1.3x.
- **Giải pháp Impeccable Taste:**
  - **Bố cục Desktop ($\ge 900$dp, `maxWidth: 1300`):**
    - Sử dụng bố cục lưới 2 cột (`GridView.builder` hoặc `Wrap`) với thẻ `AppCard` viền siêu mỏng mờ theo `DESIGN.md`.
    - Thẻ thông báo hiển thị chuyên nghiệp: Badge ghim vàng ấm, Badge danh mục tương phản cao, Badge đối tượng (Toàn bộ / Tòa / Tầng), Thanh tiến trình tỷ lệ đọc (`readRatio`).
  - **Bố cục Mobile (< 900dp, `maxWidth: 600`):**
    - Thẻ `AppCard` với cấu trúc linh hoạt: Hàng trên cùng tách biệt giữa dải Badge và nhóm nút thao tác bằng `Expanded` và `ConstrainedBox`.
    - Tất cả các nhãn text đều bọc trong `Flexible` / `Expanded` với `overflow: TextOverflow.ellipsis` chống tràn 100%.

### 1.2. `ResidentAnnouncementDetailScreen` (Chi Tiết Thông Báo Cư Dân)
- **Vấn đề hiện tại:**
  - Giao diện căn giữa nhưng chưa giới hạn độ rộng tối đa trên desktop, gây bè ngang.
  - Dùng thẻ Container có viền tự chế thay vì hệ thống `AppCard` chuẩn hóa.
- **Giải pháp Impeccable Taste:**
  - Bọc toàn bộ nội dung trong `Center(ConstrainedBox(maxWidth: 800, ...))`.
  - Sử dụng thẻ `AppCard` cho:
    - Thẻ tiêu đề & phân loại (Danh mục, Đã ghim, Đang diễn ra, Ngày tạo, BQL).
    - Thẻ khung thời gian sự kiện / bảo trì (nếu có `eventStartAt` và `eventEndAt`).
    - Thẻ Hotline kỹ thuật viên / liên hệ khẩn cấp (nếu có `hotlineContact`).
    - Thẻ nội dung thông báo chính (`AppCard`), typography dễ đọc, ngắt dòng tự nhiên.
  - Mobile: chống tràn 100% trên 320dp x 600dp (Zoom 1.3x).

### 1.3. `HandbookManagementScreen` (Quản Trị Cẩm Nang Tòa Nhà)
- **Vấn đề hiện tại:**
  - Danh sách thẻ đơn điệu trên màn hình lớn.
  - Các nút hành động và thông tin SĐT, nội quy dễ tràn khi chữ phóng to trên mobile.
- **Giải pháp Impeccable Taste:**
  - **Desktop ($\ge 900$dp, `maxWidth: 1200`):**
    - Bố cục lưới 2 cột cho các Tab (Đường dây nóng, Nội quy, Tiện ích). Dùng `AppCard`.
  - **Mobile (< 900dp, `maxWidth: 600`):**
    - Danh sách thẻ `AppCard` viền mỏng mờ, các hàng thông tin bọc `Expanded` chống tràn 100% trên 320dp (Zoom 1.3x).

### 1.4. `ResidentHandbookScreen` (Cẩm Nang Cư Dân & Hotline Khẩn Cấp)
- **Vấn đề hiện tại:**
  - TabBar cuộn ngang cần kiểm soát hiển thị đẹp mắt.
  - Màn hình hiển thị danh bạ hotline và nội quy cần responsive linh hoạt từ điện thoại nhỏ đến tablet/desktop.
- **Giải pháp Impeccable Taste:**
  - **Desktop ($\ge 900$dp, `maxWidth: 1200`):**
    - Bố cục lưới 2 cột cho Tab Hotline, Nội quy và Tiện ích.
    - Card hotline có nút gọi điện nhanh nổi bật với icon `Icons.phone_forwarded`.
  - **Mobile (< 900dp, `maxWidth: 600`):**
    - Chống tràn 100% trên 320dp x 600dp (Zoom 1.3x).
    - Thẻ `AppCard` thanh lịch, đồng bộ Dark/Light mode.

---

## 2. Tiêu Chí Nghiệm Thu (Quality Gate)
1. **Anti-RenderFlex Guarantee 100%:**
   - 0 lỗi overflow trên Mobile 320dp x 600dp với Text Scale 1.3x.
   - 0 lỗi overflow trên Desktop 1200dp x 900dp.
2. **Tuân thủ quy chuẩn thiết kế:**
   - 100% Tiếng Việt chuẩn mực SaaS B2B, không emoji.
   - Thẻ `AppCard` viền mỏng mờ, màu semantic chuẩn `AppTheme`.
3. **Chất lượng mã nguồn:**
   - `dart analyze lib test` đạt 0 issues (0 warning, 0 error).
   - Kiểm thử toàn bộ pass 100%.

