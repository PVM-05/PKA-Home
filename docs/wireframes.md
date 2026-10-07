# Mô Phỏng Thiết Kế Giao Diện (Wireframe) - Ứng Dụng Quản Lý Chung Cư PKA-Home

Tài liệu này mô tả chi tiết sơ đồ khối giao diện (Wireframe) của 10 màn hình cốt lõi trong hệ thống PKA-Home, tuân thủ các nguyên tắc thiết kế theo tài liệu `theme_spec.md`, kỹ năng `thiet-ke-giao-dien` và quy chuẩn thiết kế `design-rules.md`.

---

## I. Nguyên Tắc Thiết Kế Cốt Lõi (UI/UX Guidelines)

1. **Ngôn ngữ chuẩn mực**: 100% Tiếng Việt chuẩn mực, tôn trọng thuật ngữ quốc tế phổ thông (Hotline, Email, QR, App, Wifi). Tuyệt đối không dùng tiếng Anh giải nghĩa trong ngoặc đơn.
2. **Hệ thống Icon**: Đồng nhất bộ biểu tượng Material Design Icons (`Icons.*`), tuyệt đối không sử dụng Emoji.
3. **Màu sắc & Thẻ giao diện (AppCard)**: Sử dụng các biến màu chủ đạo (`AppTheme.primary`, `AppTheme.secondary`, `AppStatusColors`), toàn bộ khối nội dung sử dụng `AppCard` tự thích ứng Chế độ sáng (Light Mode) và Chế độ tối (Dark Mode).
4. **Bố cục co giãn (Responsive & Accessibility)**:
   - Tất cả khối văn bản tự động xuống dòng (Word-wrap).
   - Chiều cao tự động (Auto-height), không gán cứng `SizedBox(height: ...)` gây lỗi tràn màn hình khi phóng to cỡ chữ.
   - Hỗ trợ thanh điều chỉnh tỷ lệ cỡ chữ (`fontSizeScaleProvider`) phục vụ cư dân lớn tuổi và người khiếm thị.

---

## II. Danh Mục 10 Sơ Đồ Khối Giao Diện Cốt Lõi

---

### 1. Màn hình Đăng nhập (Chung) & Quên mật khẩu
- **Mục đích**: Xác thực người dùng, định tuyến tự động theo vai trò (Cư dân / Ban quản lý).
```text
+-------------------------------------------------+
|                                                 |
|                 [ Logo Tòa Nhà ]                |
|                    PKA Home                     |
|           Ứng Dụng Quản Lý Chung Cư             |
|                                                 |
| +---------------------------------------------+ |
| | [Email]   Thư điện tử                       | |
| | [Lock]    Mật khẩu              [Eye Hide]  | |
| |                                             | |
| | [=========================================] | |
| | [               ĐĂNG NHẬP                 ] | |
| | [=========================================] | |
| |                                             | |
| |   Quên mật khẩu? Vui lòng liên hệ BQL       | |
| +---------------------------------------------+ |
|                                                 |
|        Chưa có tài khoản? Đăng ký ngay          |
|                                                 |
+-------------------------------------------------+
```
- **Hành động & Phản hồi**:
  - Nhấn "Quên mật khẩu": Hiển thị hộp thoại hướng dẫn liên hệ văn phòng Ban Quản lý hoặc gọi Hotline để đảm bảo an toàn định danh căn hộ.
  - Hỗ trợ phím Enter để kích hoạt đăng nhập trực tiếp.

---

### 2. Trang chủ Cư dân (Resident Dashboard)
- **Mục đích**: Tổng hợp thông tin tài chính, tiện ích, tiến độ phản ánh và thông báo mới nhất.
```text
+-------------------------------------------------+
| [Avatar] Xin chào, Nguyễn Văn A   [!] [Apt] [X] |
|-------------------------------------------------|
| THAO TÁC NHANH                                  |
| [$$] Thanh toán  [!] Báo sự cố  [Tel] Hotline   |
| [Book] Cẩm nang  [Swim] Tiện ích  [Car] Thẻ xe  |
|                                                 |
| TỔNG QUAN HÓA ĐƠN                               |
| +---------------------------------------------+ |
| | Tổng tiền cần đóng:         1.500.000 VNĐ   | |
| | [!] ( 1 hóa đơn chưa thanh toán )           | |
| |                                             | |
| | [=========================================] | |
| | [           THANH TOÁN NGAY               ] | |
| | [=========================================] | |
| +---------------------------------------------+ |
|                                                 |
| QUỸ BẢO TRÌ TÒA NHÀ                             |
| +---------------------------------------------+ |
| | Số dư quỹ minh bạch: 450.000.000 đ          | |
| +---------------------------------------------+ |
|                                                 |
| TIẾN ĐỘ PHẢN ÁNH                                |
| +---------------------------------------------+ |
| | [Eng] Rò rỉ nước hộp kỹ thuật - Đang xử lý >| |
| +---------------------------------------------+ |
|                                                 |
| THÔNG BÁO MỚI NHẤT               [Xem tất cả]   |
| +---------------------------------------------+ |
| | [!] Bảo trì hệ thống điện toàn tòa nhà      | |
| | Ban quản lý xin thông báo thời gian cắt...  | |
| | 30/09/2026                                  | |
| +---------------------------------------------+ |
|-------------------------------------------------|
| [Trang chủ]   [Hóa đơn]   [Phản ánh]   [Tài khoản]
+-------------------------------------------------+
```
- **Hành động & Phản hồi**:
  - Nhấn `[Apt]`: Mở thanh chọn căn hộ (Apartment Switcher) cho cư dân sở hữu nhiều căn hộ.
  - Nhấn `[X]`: Mở hộp thoại xác nhận Đăng xuất nhanh.
  - Nhấn `THANH TOÁN NGAY`: Chuyển sang Tab Hóa đơn để xem bảng kê chi tiết và mở Demo Payment Sheet.

---

### 3. Màn hình Chi tiết Hóa đơn & Thanh toán Trực tuyến (Demo Payment Sheet)
- **Mục đích**: Minh bạch các khoản phí và hỗ trợ thanh toán trực tuyến mô phỏng tự động, đối soát tức thì.
```text
+-------------------------------------------------+
| [ < Trở lại ]     Chi Tiết Hóa Đơn              |
|-------------------------------------------------|
| Mã Hóa Đơn: INV-202609-A0110                    |
| Căn hộ: A0110 (Block A, Tầng 01)                |
| Kỳ phí: Tháng 09/2026       [CHƯA THANH TOÁN]   |
| Hạn đóng: 25/09/2026                            |
|-------------------------------------------------|
| CHI TIẾT CÁC KHOẢN PHÍ                          |
| 1. Phí quản lý (75m² x 16.500đ)    1.237.500 đ  |
| 2. Tiền nước sinh hoạt (12m³)        150.000 đ  |
| 3. Phí gửi 2 xe máy (2 x 100.000đ)   200.000 đ  |
|-------------------------------------------------|
| TỔNG TIỀN PHẢI NỘP:                1.587.500 đ  |
|                                                 |
| [=============================================] |
| [         THANH TOÁN TRỰC TUYẾN (DEMO)        ] |
| [=============================================] |
|                                                 |
| + - - - - - - - - - - - - - - - - - - - - - - + |
| |        MODAL UNIFIED PAYMENT SHEET          | |
| |                                             | |
| | Số tiền:   1.587.500 đ                      | |
| | Nội dung:  Hóa đơn kỳ 09/2026 - A0110       | |
| |                                             | |
| | [(*) Mô phỏng Thành công]                   | |
| | [( ) Mô phỏng Thất bại]                     | |
| | [( ) Mô phỏng Hủy giao dịch]                | |
| |                                             | |
| | [ Nút: XÁC NHẬN THANH TOÁN (DEMO) ]         | |
| + - - - - - - - - - - - - - - - - - - - - - - + |
+-------------------------------------------------+
```
- **Hành động & Phản hồi**:
  - Tích hợp RPC nguyên tử `simulate_unified_payment` đảm bảo tính toàn vẹn (ACID), khóa hàng `FOR UPDATE`.
  - Tự động sinh mã giao dịch duy nhất `TXN-INVOICE-...` và ghi nhận bản ghi đối soát vào bảng `payment_transactions`.
  - Cập nhật trạng thái tức thì sang `paid`, phát sinh thông báo thành công và làm mới dashboard realtime.

---

### 4. Màn hình Gửi Phản Ánh Sự Cố (Cư dân)
- **Mục đích**: Cư dân báo cáo hư hỏng hạ tầng, điện nước kèm hình ảnh trực tiếp.
```text
+-------------------------------------------------+
| [ < Trở lại ]     Gửi Phản Ánh                  |
|-------------------------------------------------|
| Căn hộ phản ánh: A0110                          |
|                                                 |
| Vui lòng mô tả sự cố hoặc yêu cầu hỗ trợ:       |
| +---------------------------------------------+ |
| | Ví dụ: Bóng đèn hành lang tầng 5 bị cháy... | |
| |                                             | |
| |                                             | |
| +---------------------------------------------+ |
|                                                 |
| Đính kèm hình ảnh (Tối đa 3 ảnh):          0/3  |
| +---------------------------------------------+ |
| |                [ Camera Icon ]              | |
| |              + Chọn ảnh từ máy              | |
| |   (Chụp ảnh hoặc chọn từ thư viện ảnh)      | |
| +---------------------------------------------+ |
|                                                 |
| [=============================================] |
| [               GỬI YÊU CẦU                   ] |
| [=============================================] |
+-------------------------------------------------+
```
- **Hành động & Phản hồi**:
  - Cho phép tải tối đa 3 ảnh với nút xóa `[X]` trên từng ảnh thu nhỏ.
  - Phân loại thông minh bằng trigger DB tự động nhận diện mức độ ưu tiên.

---

### 5. Màn hình Cẩm nang Tòa nhà & Hotline Khẩn cấp
- **Mục đích**: Tra cứu danh bạ cứu nạn, quy định sinh hoạt, biểu phí dịch vụ chung cư.
```text
+-------------------------------------------------+
| [ < Trở lại ]     Cẩm Nang & Danh Bạ            |
|-------------------------------------------------|
| [ TAB: GỌI KHẨN CẤP ]    [ TAB: BIỂU PHÍ & FAQ ]|
|-------------------------------------------------|
| DANH BẠ HỖ TRỢ 24/7                             |
| +---------------------------------------------+ |
| | [Shield] Ban Quản Lý (08:00 - 17:30)        | |
| | Hotline: 024.3999.8888          [ GỌI NGAY ]| |
| +---------------------------------------------+ |
| +---------------------------------------------+ |
| | [Wrench] Đội Kỹ Thuật & Sự Cố Điện Nước     | |
| | Hotline: 0988.111.222           [ GỌI NGAY ]| |
| +---------------------------------------------+ |
| +---------------------------------------------+ |
| | [Fire]   Cứu Hỏa & Phòng Cháy Chữa Cháy     | |
| | Đầu số: 114                     [ GỌI NGAY ]| |
| +---------------------------------------------+ |
| +---------------------------------------------+ |
| | [Plus]   Cấp Cứu Y Tế                      | |
| | Đầu số: 115                     [ GỌI NGAY ]| |
| +---------------------------------------------+ |
+-------------------------------------------------+
```
- **Hành động & Phản hồi**:
  - Nhấn `[ GỌI NGAY ]`: Tự động kích hoạt trình gọi điện thoại của hệ điều hành thông qua giao thức `tel:`.
  - Tab Biểu phí & FAQ hiển thị giá điện nước EVN, phí gửi xe, quy chuẩn đổ rác và bảo trì.

---

### 6. Màn hình Đặt lịch Tiện ích Chung cư (Amenity Booking)
- **Mục đích**: Cư dân đăng ký sử dụng hồ bơi, sân BBQ, phòng gym tránh quá tải.
```text
+-------------------------------------------------+
| [ < Trở lại ]     Đặt Lịch Tiện Ích             |
|-------------------------------------------------|
| DANH SÁCH TIỆN ÍCH                              |
| ( ) Bể bơi vô cực (Tầng 5)    - Miễn phí        |
| (*) Vườn nướng BBQ ngoài trời - 100.000 đ/lượt  |
| ( ) Phòng tập Gym & Yoga      - Miễn phí        |
|                                                 |
| CHỌN NGÀY SỬ DỤNG                               |
| [ Thứ Bảy, 03/10/2026                 ] [Lịch]  |
|                                                 |
| KHUNG GIỜ HOẠT ĐỘNG (SLOT)                      |
| [ 08:00 - 10:00 ] [ 10:00 - 12:00 (Hết chỗ) ]   |
| [ 14:00 - 16:00 ] [*16:00 - 18:00 (Đang chọn)*] |
| [ 18:00 - 20:00 ]                               |
|                                                 |
| Quy định: Mỗi căn hộ được đặt tối đa 2 slot/tuần|
|                                                 |
| [=============================================] |
| [             XÁC NHẬN ĐẶT LỊCH               ] |
| [=============================================] |
+-------------------------------------------------+
```
- **Hành động & Phản hồi**:
  - Tự động khóa các slot giờ đã qua trong ngày hoặc đã đủ số lượng người đăng ký tối đa.

---

### 7. Màn hình Đăng ký Phương tiện (Thẻ Xe)
- **Mục đích**: Khai báo biển số và làm thẻ ra vào hầm gửi xe.
```text
+-------------------------------------------------+
| [ < Trở lại ]     Thẻ Xe Căn Hộ                 |
|-------------------------------------------------|
| PHƯƠNG TIỆN ĐÃ ĐĂNG KÝ                          |
| +---------------------------------------------+ |
| | [Moto] 29-B1 123.45 - Honda AirBlade        | |
| | Trạng thái: [ĐÃ PHÊ DUYỆT]  - 100.000 đ/tháng| |
| +---------------------------------------------+ |
| +---------------------------------------------+ |
| | [Auto] 30H-999.88   - Mazda CX-5            | |
| | Trạng thái: [CHỜ DUYỆT]     - 1.200.000 đ/th | |
| +---------------------------------------------+ |
|                                                 |
| [ + Đăng ký thêm phương tiện mới ]              |
|                                                 |
| BIỂU MẪU ĐĂNG KÝ                                |
| - Loại xe: (*) Xe máy  ( ) Ô tô  ( ) Xe đạp điện|
| - Biển số xe: [ 29-D2 678.90                ]   |
| - Tên chủ xe: [ Nguyễn Văn A                ]   |
| - Đính kèm ảnh Cavet/Đăng ký xe:                |
|   [ + Tải ảnh giấy đăng ký xe ]                 |
|                                                 |
| [=============================================] |
| [               GỬI ĐĂNG KÝ                   ] |
| [=============================================] |
+-------------------------------------------------+
```

---

### 8. Màn hình Hồ sơ Cư dân & Cài đặt Trợ năng
- **Mục đích**: Quản lý căn hộ, đổi mật khẩu, tăng giảm cỡ chữ và chuyển đổi giao diện sáng/tối.
```text
+-------------------------------------------------+
| [ Menu ]          Tài Khoản                     |
|-------------------------------------------------|
| [ AVATAR ]  Nguyễn Văn A                        |
| SĐT: 0901.234.567      [ Chỉnh sửa ]            |
| Căn hộ: A0110 (Chủ hộ) [ Đổi căn hộ ]           |
|-------------------------------------------------|
| THÀNH VIÊN ĐỒNG CƯ DÂN                          |
| - Trần Thị B (Vợ)        - 0912.345.678         |
| - Nguyễn Văn C (Con)     - Chưa có SĐT          |
| [ + Thêm thành viên đồng cư dân ]               |
|-------------------------------------------------|
| CÀI ĐẶT ỨNG DỤNG & TRỢ NĂNG                     |
|                                                 |
| [Aa] Cỡ chữ hiển thị:          [ Nhỏ  Vừa  Lớn ]|
|      (Phóng to giao diện cho người lớn tuổi)    |
|                                                 |
| [Sun] Giao diện hệ thống:      [ Sáng / (*)Tối ]|
|                                                 |
| [Lock] Đổi mật khẩu tài khoản                   |
|                                                 |
| [Log]  Đăng xuất khỏi thiết bị                  |
+-------------------------------------------------+
```
- **Hành động & Phản hồi**:
  - Bộ điều khiển `fontSizeScaleProvider` nhân tỷ lệ chữ với scale hệ thống `(systemScale * fontScale)`.
  - Hộp thoại đổi mật khẩu an toàn qua Supabase Auth.

---

### 9. Trang chủ Ban Quản Lý (Management Dashboard)
- **Mục đích**: Trung tâm điều hành giám sát căn hộ, tài chính và phản ánh sự cố.
```text
+-------------------------------------------------+
| [ Menu ] Ban Quản Lý Tòa Nhà      [Theme] [Exit]|
|-------------------------------------------------|
| THAO TÁC NHANH                                  |
| [User+] Duyệt căn hộ (3)   [Key] Phân quyền     |
| [Bill+] Lập hóa đơn        [Wrench] Xử lý sự cố |
|                                                 |
| PHẢN ÁNH CẦN XỬ LÝ GẤP                          |
| +---------------------------------------------+ |
| | [!] Căn A0501: Rò rỉ nước hộp gen [Xem ngay]| |
| | [!] Căn B1204: Chập điện atomat   [Xem ngay]| |
| +---------------------------------------------+ |
|                                                 |
| TIẾN ĐỘ THU PHÍ THÁNG 09/2026                   |
| [========================......] Đạt 82%        |
| - Đã thu: 285.000.000 đ | Còn nợ: 58.000.000 đ  |
| - Căn hộ đã hoàn tất: 123/150 căn hộ            |
|                                                 |
| BIỂU ĐỒ DOANH THU 6 THÁNG GẦN NHẤT              |
| [ T4: 310Tr | T5: 325Tr | T6: 340Tr | T9: 343Tr]|
|                                                 |
| TỔNG QUAN TRẠNG THÁI                            |
| +----------------------+ +--------------------+ |
| | [!] Phản ánh mới     | | [$$] Tổng nợ phí   | |
| |        4             | |      58 Tr         | |
| +----------------------+ +--------------------+ |
| +----------------------+ +--------------------+ |
| | [#] Tổng số căn hộ   | | [Home] Căn hộ trống| |
| |       150            | |         8          | |
| +----------------------+ +--------------------+ |
|-------------------------------------------------|
| [Tổng quan]   [Cư dân]   [Hóa đơn]   [Phản ánh] 
+-------------------------------------------------+
```
- **Hành động & Phản hồi**:
  - Tự động hiển thị Badge số lượng yêu cầu liên kết căn hộ đang chờ duyệt trên tab Cư dân.
  - Phân quyền theo vai trò (Admin, Kế toán, Kỹ thuật viên) và ủy quyền (Delegation).

---

### 10. Màn hình Quản lý & Nghiệm thu Sự cố (BQL)
- **Mục đích**: Tiếp nhận phản ánh, phân công kỹ thuật viên và tải ảnh nghiệm thu thực tế.
```text
+-------------------------------------------------+
| [ < Trở lại ]     Chi Tiết Sự Cố #REP-102       |
|-------------------------------------------------|
| Căn hộ: A0501 (Block A - Tầng 5)                |
| Người báo: Nguyễn Văn A (0901.234.567)          |
| Mức độ ưu tiên: [ KHẨN CẤP (HIGH) ]             |
| Thời gian gửi:  10:30 - 30/09/2026              |
| Mô tả: "Ống nước bồn rửa bát bị nứt vỡ rò nước" |
|                                                 |
| HÌNH ẢNH HIỆN TRƯỜNG TỪ CƯ DÂN                  |
| [ Ảnh 1 ]  [ Ảnh 2 ]                            |
|-------------------------------------------------|
| TIẾN ĐỘ XỬ LÝ                                   |
| Nhân viên phụ trách: [ Nguyễn Kỹ Thuật 1   ▼ ]  |
| Trạng thái hiện tại: [ Đang xử lý          ▼ ]  |
|                                                 |
| HÌNH ẢNH NGHIỆM THU HOÀN TẤT                    |
| +---------------------------------------------+ |
| |            [ Camera Check Icon ]            | |
| |      + Chụp ảnh nghiệm thu sau sửa chữa     | |
| +---------------------------------------------+ |
| Ghi chú sửa chữa: [ Đã thay thế van khóa mới ]  |
|                                                 |
| [=============================================] |
| [        HOÀN TẤT NGHIỆM THU & ĐÓNG SỰ CỐ     ] |
| [=============================================] |
+-------------------------------------------------+
```
- **Hành động & Phản hồi**:
  - Lưu ảnh nghiệm thu hoàn tất vào Supabase Storage bucket `issue-images/proof/`.
  - Cư dân nhận được thông báo thời gian thực và xuất hiện màn hình Đánh giá dịch vụ 5 sao.

---

## III. Kết Luận & Quy Chuẩn Áp Dụng
Bộ wireframe trên phản ánh chính xác 100% các màn hình đang hoạt động trong mã nguồn Flutter của dự án PKA-Home, phục vụ trọn vẹn yêu cầu tài liệu đồ án tốt nghiệp và mang lại trải nghiệm tiện nghi, chuyên nghiệp cho người dùng.
