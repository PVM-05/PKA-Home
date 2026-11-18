# Đặc Tả Kỹ Thuật: Thích Ứng & Cá Nhân Hóa (Giai Đoạn 2 - Adaptive & Personalization)

## 1. Bối Cảnh & Mục Tiêu
Sau khi hoàn thiện nền tảng Design Tokens ở **Giai đoạn 0** và ngôn ngữ thị giác Bento Grid, Spring Motion, Glassmorphism ở **Giai đoạn 1**, **Giai đoạn 2** tập trung vào 3 trụ cột nâng tầm trải nghiệm của sản phẩm B2B SaaS Vivona:
1. **Kiến Trúc Thích Ứng Màn Hình Lớn (Adaptive Master-Detail)**: Tối ưu hóa trải nghiệm trên Desktop, Web và Máy tính bảng ($\ge 900$dp) cho Cư dân. Áp dụng bố cục 2 cột (Danh sách bên trái + Chi tiết bên phải) cho 2 phân hệ trọng yếu: **Hóa đơn & Thanh toán** và **Phản ánh Sự cố**.
2. **Cá Nhân Hóa Màn Hình Chính Theo Hành Vi (Behavioral Personalization)**: Trang chủ tự động sắp xếp lại vị trí các module và nội dung CTA dựa theo tình trạng thực tế của căn hộ (hóa đơn đến hạn, sự cố đang xử lý, cửa sổ mở cổng ghi chỉ số điện nước cuối chu kỳ).
3. **Chuẩn Hóa Trợ Năng Đạt Chuẩn WCAG AA (European Accessibility Act & Universal Design)**:
   - Bao phủ nhãn ngữ nghĩa `Semantics` cho toàn bộ các icon buttons, trạng thái huy hiệu (badges), thẻ chỉ số và biểu đồ `fl_chart`.
   - Đảm bảo độ tương phản màu sắc $\ge 4.5:1$ theo tiêu chuẩn WCAG AA cho cả Light và Dark Mode.

---

## 2. Kiến Trúc Kỹ Thuật (Architecture & Components)

### 2.1. Thành Phần Adaptive Master-Detail (`lib/core/widgets/adaptive_master_detail_layout.dart`)
- Widget `AdaptiveMasterDetailLayout<T>`:
  - Nhận `masterBuilder`: builder danh sách các phần tử.
  - Nhận `detailBuilder`: builder hiển thị chi tiết khi có phần tử được chọn (`selectedItem != null`).
  - Nhận `emptyDetailBuilder`: giao diện placeholder khi chưa có phần tử nào được chọn trên màn hình lớn.
  - Ngưỡng phân tách breakpoint: `breakpoint = 900.0`.
  - Trên màn hình hẹp ($< 900$dp): Chỉ render Master; khi người dùng tap vào 1 mục, gọi router đẩy sang màn hình Detail độc lập (bảo tồn nguyên vẹn trải nghiệm mobile).
  - Trên màn hình rộng ($\ge 900$dp):
    - Chia tỉ lệ 4:6 hoặc 3.5:6.5 (Cột trái danh sách có thanh cuộn riêng, cột phải chi tiết hiển thị trực tiếp).
    - Cập nhật chi tiết tức thì khi chọn mục khác mà không làm mất vị trí cuộn của danh sách bên trái.

### 2.2. Động Cơ Cá Nhân Hóa Hành Vi (`lib/features/resident/providers/home_personalization_provider.dart`)
Tạo `homePersonalizationProvider` (StateNotifier/Provider) tổng hợp dữ liệu từ:
- `residentInvoiceProvider`: kiểm tra hóa đơn chưa thanh toán hoặc cận hạn ($\le 3$ ngày).
- `residentIssueProvider`: kiểm tra có sự cố đang `in_progress` hoặc `pending`.
- `DateTime.now()`: kiểm tra chu kỳ ghi chỉ số (ngày 20 đến hết tháng).
- Output `HomePriorityState`:
  - `urgentInvoice`: Có hóa đơn quá hạn hoặc sát hạn $\rightarrow$ Hero Banner hóa đơn ghim trên cùng kèm nút thanh toán có xung nhịp (pulse).
  - `activeIssueTracking`: Đã đóng tiền xong nhưng có sự cố đang sửa $\rightarrow$ Đưa thẻ Theo dõi tiến độ sự cố lên trước.
  - `meterReadingWindow`: Đến chu kỳ ghi chỉ số (ngày 20-30 hàng tháng) $\rightarrow$ Xuất hiện banner nhắc nhở ghi chỉ số.
  - `allPeaceful`: Căn hộ hoàn tất nghĩa vụ và không có sự cố $\rightarrow$ Thẻ an tâm sinh hoạt.

### 2.3. Chuẩn Hóa Trợ Năng `Semantics` & WCAG AA
- `lib/core/widgets/app_semantic_badge.dart`: Bọc các badge trạng thái (Đã đóng tiền, Chưa đóng tiền, Sự cố khẩn cấp) với `Semantics(label: ..., readOnly: true)`.
- `lib/core/widgets/bounceable.dart`: Tích hợp sẵn `Semantics(button: true, label: semanticLabel)`.
- Biểu đồ tiêu thụ điện nước `resident_utility_consumption_chart_card.dart`: Bọc `Semantics(container: true, label: 'Thống kê tiêu thụ điện và nước:...')` để trình đọc màn hình (TalkBack/VoiceOver) diễn giải chính xác dữ liệu biểu đồ.

---

## 3. Danh Mục Kịch Bản Kiểm Thử
1. **Adaptive Master-Detail Tests**:
   - Kiểm tra tại `width = 1200dp`: hiển thị song song 2 cột; khi bấm vào item danh sách bên trái, cột bên phải cập nhật dữ liệu tương ứng.
   - Kiểm tra tại `width = 390dp`: chỉ hiển thị 1 cột duy nhất.
2. **Behavioral Personalization Tests**:
   - Test ưu tiên hóa đơn khi có hóa đơn chưa thanh toán.
   - Test ưu tiên sự cố khi đã thanh toán hết và có sự cố đang xử lý.
   - Test hiển thị banner ghi chỉ số trong cửa sổ ngày 20-30.
3. **Accessibility & Guardrail Tests**:
   - Kiểm tra các `Semantics` tồn tại trong widget tree.
   - `test/core/theme_and_color_guard_test.dart` tiếp tục giám sát 0 mã màu cứng và 0 fontSize cứng.
   - `dart analyze lib test`: 0 errors, 0 warnings.

