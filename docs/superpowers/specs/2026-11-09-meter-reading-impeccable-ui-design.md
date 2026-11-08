# Đặc Tả Thiết Kế: Cải Tiến Giao Diện Phân Hệ Điện Nước & Chỉ Số Tiện Ích (Impeccable & Anti-RenderFlex)

- **Mục tiêu:** Nâng cấp toàn diện giao diện và trải nghiệm người dùng (UI/UX) cho phân hệ Quản lý & Khai báo Chỉ số Tiện ích (`ManagementMeterReadingScreen` & `ResidentMeterReadingScreen`) theo tiêu chuẩn **`pbakaus/impeccable`**, loại bỏ 100% rủi ro tràn layout (RenderFlex overflow) trên màn hình mobile cực hẹp (320dp x 600dp, Text Zoom 1.3x) và tối ưu hóa trạm làm việc chuyên nghiệp (Executive Utility Workstation) trên Web Desktop ($\ge 900$dp, `maxWidth: 1400dp`).
- **Phạm vi tác động:**
  - `lib/features/management/screens/management_meter_reading_screen.dart`
  - `lib/features/resident/screens/resident_meter_reading_screen.dart`
- **Quy chuẩn tuân thủ:** Clean Architecture, Feature-First, Riverpod Reactive State, 100% tiếng Việt B2B SaaS, commit trực tiếp trên nhánh `main`, 0 warning/0 error trên `dart analyze lib test`.

---

## 1. Phân Tích Kỹ Thuật & Giải Pháp Triệt Tiêu Lỗi RenderFlex

### 1.1. `ManagementMeterReadingScreen` (Ban Quản Lý & Kỹ Thuật Viên)
- **Hộp thoại Chốt số theo tầng (`_showBatchRecordDialog`):**
  - *Hiện trạng:* Cố định cứng `width: 600` và đặt 3 trường nhập (Căn hộ, Điện, Nước) trong cùng 1 `Row`. Gây vỡ nát layout trên Mobile 320dp.
  - *Giải pháp Impeccable:* Sử dụng `Dialog` thích ứng (`LayoutBuilder` / `MediaQuery`):
    - Khi chiều rộng $< 600$dp (Mobile): Mỗi căn hộ là 1 khối thẻ dọc (`Column`), các trường nhập căn hộ, điện, nước được xếp theo hàng dọc có icon nhận diện rõ ràng.
    - Khi chiều rộng $\ge 600$dp (Desktop): Hiển thị dạng bảng lưới ngang cân đối.
- **Thẻ Phiếu Chỉ Số (`_buildSubmissionCard`):**
  - Bọc huy hiệu trạng thái, huy hiệu "Đã xuất hóa đơn", và tiêu đề căn hộ trong `Flexible` / `TextOverflow.ellipsis`.
  - Khối chỉ số Điện & Nước: Tự động co giãn theo tỷ lệ khả dụng, cỡ chữ số và đơn vị đo (kWh, m³) tự co giãn thích ứng.
  - Bộ đôi nút hành động "Từ chối" & "Phê duyệt": Bọc nhãn văn bản trong `FittedBox(fit: BoxFit.scaleDown, child: Text(...))`.
- **Trạm Điều Hành Web Desktop ($\ge 900$dp, `maxWidth: 1400`):**
  - **Executive Utility KPI Bar:** 4 thẻ chỉ số nhanh ở đầu trang:
    1. *Chờ duyệt*: Tổng số phiếu cư dân nộp đang chờ xác thực.
    2. *Bất thường AI/OCR*: Số lượng căn hộ có mức biến động tiêu thụ vượt ngưỡng cần kiểm tra.
    3. *Đã duyệt kỳ này*: Tổng số căn đã hoàn tất chốt số và sinh hóa đơn.
    4. *Tỷ lệ hoàn thành*: Tỷ lệ % số căn hộ đã hoàn tất nộp chỉ số trong toàn tòa nhà.
  - **Bố cục lưới Responsive 2 cột**: Hiển thị danh sách phiếu chỉ số dạng thẻ 2 cột sắc nét, tối ưu không gian hiển thị rộng rãi của màn hình máy tính.

### 1.2. `ResidentMeterReadingScreen` (Cư Dân Khai Báo Số)
- **Bố cục Web Desktop ($\ge 900$dp, `maxWidth: 1200`):**
  - Chuyển sang bố cục **Split-Screen 2 cột**:
    - **Cột trái (45%):** Thẻ chỉ số kỳ trước + Lịch sử khai báo các kỳ & Trạng thái duyệt của Ban Quản Lý.
    - **Cột phải (55%):** Form khai báo chỉ số mới kèm bộ đôi nút chụp ảnh/tải ảnh công tơ OCR và Banner cảnh báo biến động tức thời.
- **Bố cục Mobile (< 900dp):**
  - Bỏ chiều cao cứng `height: 50` của nút gửi chỉ số, thay bằng `ConstrainedBox(constraints: BoxConstraints(minHeight: 48))` để tự động giãn chiều cao khi người dùng phóng to chữ 1.3x.
  - Thẻ đính kèm ảnh công tơ: Cắt ngắn tên file bằng `TextOverflow.ellipsis` kết hợp `Flexible`.
  - Hộp thoại sửa chỉ số (`_showEditSubmissionDialog`) và hủy phiếu (`_confirmCancelSubmission`): Tối ưu co giãn an toàn.

---

## 2. Bảng Cam Đoan Chống Tràn Bố Cục (Anti-RenderFlex Checklist)

| Thành phần | Cơ chế chống tràn | Kích thước kiểm thử |
| :--- | :--- | :--- |
| **`ManagementMeterReadingScreen` Cards** | Bọc nhãn nút trong `FittedBox`, tiêu đề bọc `Flexible`, chỉ số co giãn linh hoạt. | Mobile 320dp x 600dp, Text zoom 1.3x $\to$ 0 overflow. |
| **`BatchRecordDialog`** | Layout dọc trên Mobile (< 600dp), layout ngang trên Desktop. Bề rộng dialog thích ứng `maxWidth: 640`. | Mobile 320dp & Tablet 768dp $\to$ 0 overflow. |
| **Management Executive Web** | `GridView` 2 cột hoặc `Wrap` cho thẻ phiếu, KPI Bar 4 cột co giãn. | Desktop 1200dp - 1400dp $\to$ 0 overflow. |
| **`ResidentMeterReadingScreen` Form** | Nút gửi co giãn chiều cao động, thẻ đính kèm bọc `Flexible`, nhãn OCR thích ứng. | Mobile 320dp x 600dp, Text zoom 1.3x $\to$ 0 overflow. |
| **Resident Desktop Split-Screen** | Bố cục 2 cột (Chỉ số cũ & Lịch sử bên trái, Form nhập bên phải). | Desktop 1200dp $\to$ 0 overflow. |

---

## 3. Kịch Bản Kiểm Thử & Tiêu Chuẩn Nghiệm Thu

1. **`management_meter_reading_responsive_test.dart`**:
   - Test 1: Mobile 320dp x 600dp (Text Scale 1.3x) render an toàn cả 4 tabs (`pending`, `anomalies`, `approved`, `rejected`) không có lỗi RenderFlex.
   - Test 2: Desktop 1200dp render Executive KPI Bar và danh sách lưới 2 cột đầy đủ.
   - Test 3: Hộp thoại chốt số theo tầng mở an toàn trên Mobile 320dp không tràn ngang.
2. **`resident_meter_reading_responsive_test.dart`**:
   - Test 1: Mobile 320dp x 600dp (Text Scale 1.3x) render Form và Lịch sử không có lỗi RenderFlex.
   - Test 2: Desktop 1200dp render bố cục Split-Screen 2 cột hoàn chỉnh.
3. **Static Analysis Quality Gate:**
   - Chạy `dart analyze lib test` đạt 0 warning, 0 error.
