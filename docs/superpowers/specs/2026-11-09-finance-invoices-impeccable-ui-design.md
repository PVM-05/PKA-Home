# Đặc Tả Thiết Kế UI/UX: Phân Hệ Tài Chính, Hóa Đơn & Thu Phí VietQR Chuẩn Impeccable

> **Mục tiêu:** Tái thiết và nâng cấp toàn diện các màn hình thuộc Phân hệ Tài Chính, Hóa Đơn và Thu Phí VietQR (`InvoiceManagementScreen`, `CreateInvoiceScreen`, `EditInvoiceScreen`, `ManagementInvoiceDetailScreen`, `ResidentInvoiceScreen`, `ResidentInvoiceDetailScreen`, `PaymentHistoryScreen`, `FinancialReportScreen`, `MaintenanceFundLedgerScreen`) theo triết lý thiết kế **`pbakaus/impeccable`**, đồng bộ với `PRODUCT.md` và `DESIGN.md`.

---

## 1. Bối Cảnh Người Dùng & Triết Lý Thiết Kế (Operating Context)

Phân hệ Tài chính là huyết mạch thương mại của nền tảng B2B SaaS PropTech PKA-Home:
1. **Kế toán & Ban Quản Lý (Operate Mode)**:
   - Làm việc trên máy tính bàn hoặc laptop ($\ge 900$dp đến 1920dp).
   - Đòi hỏi mật độ thông tin cao, dễ đối soát, kiểm tra nhanh trạng thái thanh toán, lọc theo kỳ và xuất hóa đơn điện tử / Excel tức thì.
   - Tránh tuyệt đối "AI slop": Không dùng gradient lòe loẹt, không lồng card trong card, sử dụng viền mỏng mờ (`alpha: 0.08`) và phân tầng màu nền (Tonal Layering).
2. **Cư Dân (Operate & Persuade Mode)**:
   - Thao tác trên thiết bị di động (320dp đến 430dp).
   - Cần nhìn thấy ngay số tiền cần đóng, ngày hết hạn và mã QR VietQR động NAPAS 24/7 để chuyển khoản một chạm.
   - Trực quan hóa cách tính lũy tiến (bậc thang điện nước, phí gửi xe) minh bạch để xóa bỏ hoàn toàn nghi ngờ khiếu nại.

---

## 2. Cam Kết Anti-RenderFlex Guarantee 100%

Mọi màn hình và thành phần giao diện trong phân hệ phải vượt qua bài kiểm tra co giãn:
- **Mobile Cực Hẹp**: `Size(320, 600)` kèm Text Scale `1.3x`.
  - Các khối tiền tệ, mã căn hộ, huy hiệu trạng thái và nút bấm không bao giờ bị cắt chữ hay gây ra sọc vàng đen `RenderFlex overflowed`.
  - Bộ lọc FilterChip luôn nằm trong `SingleChildScrollView(scrollDirection: Axis.horizontal)`.
  - Các trường nhập liệu số tiền và số lượng luôn có flex constraints hoặc `LayoutBuilder`.
- **Web Enterprise Desktop**: `Size(1200, 900)` và `Size(1400, 900)`.
  - Toàn bộ nội dung căn giữa với `maxWidth: 1400`.
  - Bố cục Workstation 2 cột bất đối xứng (5 : 7) tối ưu không gian rộng.

---

## 3. Kiến Trúc Màn Hình & Trải Nghiệm Chi Tiết

### A. Quản Lý Hóa Đơn & Báo Cáo Tài Chính (Ban Quản Lý)
1. **`InvoiceManagementScreen`**:
   - Executive Toolbar: Thanh tìm kiếm căn hộ, bộ lọc trạng thái (Chờ duyệt, Chưa thu, Đã thu) và bộ nút thao tác nhanh (Tạo hàng loạt, Xuất Excel).
   - Desktop: Bảng dữ liệu Workstation mật độ cao, phân cột rõ ràng, nút xem chi tiết và duyệt thanh toán tức thì.
   - Mobile: Danh sách thẻ `AppCard` co giãn, hiển thị mã phòng `A0110`, số tiền in đậm và badge trạng thái `FittedBox`.
2. **`FinancialReportScreen`**:
   - Khung bao tổng thể `maxWidth: 1400` căn giữa.
   - Dải KPI 4 chỉ số (Tổng phát hành, Đã thu, Tồn đọng, Tỷ lệ thu hồi): Tự động chuyển 4 cột trên Desktop và lưới 2 cột co giãn linh hoạt trên Mobile.
   - Phân tích 4 xô tuổi nợ (Aging Buckets: 0-30 ngày, 31-60 ngày, 61-90 ngày, >90 ngày) trực quan.
3. **`MaintenanceFundLedgerScreen` (Sổ Quỹ Bảo Trì 2%)**:
   - Bố cục Split-Screen trên Desktop: Cột trái (Số dư quỹ khả dụng, lãi suất ngân hàng, nút lập phiếu); Cột phải (Sổ nhật ký chứng từ thu chi).
   - Bộ lọc chứng từ bọc `SingleChildScrollView(scrollDirection: Axis.horizontal)`.

### B. Biểu Mẫu Lập & Chỉnh Sửa Hóa Đơn
1. **`CreateInvoiceScreen` & `EditInvoiceScreen`**:
   - Desktop Web ($\ge 900$dp, `maxWidth: 1400`): Bố cục Split-Screen 2 cột.
     - Cột trái (flex 5): Chọn căn hộ, kỳ hóa đơn, hạn thanh toán, ghi chú và bảng tóm tắt tổng tiền.
     - Cột phải (flex 7): Các trường nhập chi tiết biểu phí (Phí quản lý, Điện, Nước, Xe máy, Ô tô, Khác) với tính toán tự động realtime.
   - Mobile (< 900dp): Cuộn dọc 1 cột an toàn, các hàng nhập đơn giá và số lượng bọc `LayoutBuilder` tự động chuyển sang cột khi chiều rộng $< 280$dp.

### C. Trải Nghiệm Thanh Toán Cư Dân
1. **`ResidentInvoiceScreen`**:
   - 2 Tab: "Cần thanh toán" và "Lịch sử đã đóng".
   - Thẻ hóa đơn `AppCard` viền cảnh báo khi quá hạn, hiển thị rõ ràng số ngày quá hạn hoặc đến hạn hôm nay.
2. **`ResidentInvoiceDetailScreen`**:
   - Bố cục Split-Screen Desktop $\ge 900$dp: Cột trái (Thẻ tổng tiền lớn, Mã QR VietQR động kèm cú pháp chuyển khoản, nút xác nhận thanh toán); Cột phải (Bảng phân tích chi tiết từng khoản phí và bảng tính lũy tiến).
   - Mobile: Trực quan hóa từng dòng mục phí kèm nút xem cách tính bậc thang.

---

## 4. Danh Mục Tokens & Chuẩn Hóa Mã Nguồn

- Tuân thủ 100% token định nghĩa trong `DESIGN.md`.
- Sử dụng màu semantic từ `AppTheme` và `AppStatusColors` (`AppStatusColors.paid`, `AppStatusColors.unpaid`, `AppStatusColors.pendingConfirmation`).
- Tuyệt đối không hardcode mã màu hex rời rạc trong các file màn hình.
- 100% Tiếng Việt chuẩn mực SaaS, không emoji.

