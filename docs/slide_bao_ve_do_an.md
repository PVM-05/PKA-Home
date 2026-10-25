# BỘ SLIDE THUYẾT TRÌNH BẢO VỆ ĐỒ ÁN LIÊN NGÀNH
## ĐỀ TÀI: ỨNG DỤNG QUẢN LÝ CHUNG CƯ (PKA-HOME)

* **Sinh viên báo cáo:** Phạm Văn Minh (MSV: 23010350)
* **Giảng viên hướng dẫn:** Tiến sĩ Nguyễn Thị Vân
* **Đơn vị đào tạo:** Trường Công nghệ Thông tin – Trường Đại học Phenikaa
* **Thời gian thực hiện:** Tháng 10 năm 2026

---

## SLIDE 1: TRANG TIÊU ĐỀ
* **Tiêu đề lớn:** BÁO CÁO ĐỒ ÁN LIÊN NGÀNH: ỨNG DỤNG QUẢN LÝ CHUNG CƯ (PKA-HOME)
* **Thông tin tác giả:** Sinh viên Phạm Văn Minh – Mã sinh viên: 23010350
* **Giảng viên hướng dẫn:** Tiến sĩ Nguyễn Thị Vân
* **Đơn vị:** Trường Công nghệ Thông tin – Trường Đại học Phenikaa
* **Bố cục trình bày:** Logo Đại học Phenikaa, biểu trưng ứng dụng PKA-Home, các thông tin định danh đề tài.

> **Lời thoại thuyết trình:**
> "Kính thưa quý thầy cô trong Hội đồng đánh giá đồ án liên ngành! Em tên là Phạm Văn Minh, sinh viên khóa 2023 ngành Công nghệ Thông tin. Hôm nay, em xin phép được báo cáo kết quả nghiên cứu và hiện thực hóa đề tài: 'Ứng dụng Quản lý Chung cư PKA-Home' dưới sự hướng dẫn khoa học của Tiến sĩ Nguyễn Thị Vân. Kính mời quý thầy cô cùng theo dõi nội dung báo cáo."

---

## SLIDE 2: NỘI DUNG TRÌNH BÀY (AGENDA)
1. **Đặt vấn đề & Mục tiêu đề tài**
2. **Khảo sát nghiệp vụ & Giải pháp đề xuất**
3. **Phân tích yêu cầu & Thiết kế hệ thống**
4. **Kiến trúc phần mềm & Cơ sở dữ liệu**
5. **Các điểm sáng kỹ thuật & Toàn vẹn dữ liệu**
6. **Kết quả triển khai & Minh chứng thực tế**
7. **Đánh giá kiểm thử & Nghiệm thu**
8. **Kết luận & Hướng phát triển**

> **Lời thoại thuyết trình:**
> "Nội dung báo cáo của em ngày hôm nay gồm tám phần trọng tâm, đi từ bài toán thực tế, phân tích thiết kế, các giải pháp kỹ thuật bảo đảm an toàn dữ liệu, đến kết quả nghiệm thu kiểm thử tự động trên hệ thống và kế hoạch mở rộng trong tương lai."

---

## SLIDE 3: ĐẶT VẤN ĐỀ & THỰC TRẠNG QUẢN TRỊ TÒA NHÀ
* **Thực trạng**: Các khu đô thị hiện đại phát sinh khối lượng công việc quản lý rất lớn (hồ sơ căn hộ, chỉ số điện nước, hóa đơn, thẻ xe, phản ánh kỹ thuật, tiện ích).
* **Những điểm nghẽn của phương pháp truyền thống**:
  * *Dữ liệu phân tán*: Ghi chép sổ sách và bảng tính rải rác, thông báo dễ bị trôi.
  * *Nguy cơ sai lệch tài chính*: Nhập chỉ số và tính tiền thủ công tiềm ẩn nhầm lẫn.
  * *Thiếu tính tức thời*: Cư dân khó theo dõi tiến độ xử lý sự cố kỹ thuật.
  * *Rủi ro an toàn thông tin*: Thiếu phân quyền sâu, dễ lộ lọt thông tin cá nhân cư dân.

> **Lời thoại thuyết trình:**
> "Hiện nay, việc quản trị chung cư thường gặp khó khăn do dữ liệu phân tán trên nhiều kênh như sổ sách, bảng tính và nhóm mạng xã hội. Điều này dẫn đến nguy cơ sai lệch số liệu tài chính khi chốt chỉ số điện nước, cư dân không theo dõi được tiến độ sửa chữa hạ tầng, và thông tin cư trú chưa được bảo vệ an toàn."

---

## SLIDE 4: MỤC TIÊU VÀ PHẠM VI NGHIÊN CỨU
* **Mục tiêu chính**:
  * Xây dựng ứng dụng di động hoàn chỉnh bằng Flutter với 100% giao diện tiếng Việt.
  * Quản trị dữ liệu tập trung trên nền tảng Supabase / PostgreSQL.
  * Đặt quy tắc bảo mật và tính toán tài chính an toàn ngay từ cấp máy chủ.
  * Xây dựng quy trình tự động hóa: lập hóa đơn hàng loạt, duyệt chỉ số, kiểm soát sức chứa tiện ích.
* **Phạm vi đồ án**:
  * Tối ưu hóa trải nghiệm trên nền tảng Android.
  * Quy trình thanh toán mang tính chất mô phỏng khép kín phục vụ đào tạo và nghiên cứu.
  * Dữ liệu mẫu kiểm thử được chuẩn hóa an toàn.

> **Lời thoại thuyết trình:**
> "Mục tiêu trọng tâm của đề tài là xây dựng một nền tảng chuyển đổi số toàn diện, kết nối cư dân với ban quản lý, đồng thời giải quyết triệt để vấn đề toàn vẹn dữ liệu tài chính bằng cách chuyển toàn bộ tính toán nhạy cảm về phía máy chủ thay vì tin cậy ứng dụng khách."

---

## SLIDE 5: ĐỐI TƯỢNG SỬ DỤNG & PHÂN QUYỀN VAI TRÒ
* **Mô hình phân quyền đa vai trò (Enterprise RBAC)**:
  * **Cư dân**: Theo dõi hóa đơn, thanh toán mô phỏng, báo sự cố, đặt tiện ích, đăng ký xe.
  * **Ban Quản Lý**: Quản lý căn hộ, duyệt liên kết, điều phối sự cố, duyệt xe, phát thông báo.
  * **Kế toán**: Thẩm định chỉ số điện nước, phát hành hóa đơn hàng loạt, ghi nhận thanh toán tại quầy.
  * **Kỹ thuật viên**: Tiếp nhận sự cố, cập nhật tiến độ và biên bản sửa chữa.
  * **Quản trị viên**: Cấu hình toàn hệ thống, phân quyền vai trò và giám sát nhật ký kiểm toán.
* **Giao diện điều hướng động**: Thanh công cụ và các chức năng tự động thích ứng theo vai trò sau khi đăng nhập.

> **Lời thoại thuyết trình:**
> "Hệ thống PKA-Home phân định năm nhóm vai trò độc lập. Tùy thuộc vào tài khoản đăng nhập, thanh điều hướng sẽ thay đổi động: Quản trị viên có đủ năm phân hệ, Kế toán tập trung vào tài chính và hóa đơn, trong khi Kỹ thuật viên chỉ thao tác trên phiếu sửa chữa sự cố."

---

## SLIDE 6: SƠ ĐỒ NGỮ CẢNH & PHẠM VI HỆ THỐNG
* **Trung tâm**: Ứng dụng PKA-Home (Căn hộ, Tài chính, Tiện ích, Phương tiện, Phản ánh).
* **Các tác nhân tương tác**: Cư dân, Ban Quản Lý, Kế toán, Kỹ thuật viên, Quản trị viên.
* **Hệ thống liên kết**:
  * Dịch vụ Email: Cung cấp mã OTP xác thực khôi phục mật khẩu.
  * Dịch vụ Firebase: Hỗ trợ gửi thông báo đẩy đến thiết bị di động.
  * Vùng lưu trữ tệp tin an toàn: Quản lý hình ảnh sự cố và ủy nhiệm chi riêng tư.

```
[CHÚ THÍCH HÌNH VẼ]: Sơ đồ ngữ cảnh hệ thống (Hình 2.1 trong Báo cáo)
```

> **Lời thoại thuyết trình:**
> "Trên sơ đồ ngữ cảnh, PKA-Home đóng vai trò hạt nhân tiếp nhận và điều phối mọi luồng thông tin giữa cư dân và bộ phận vận hành, đồng thời kết nối với các dịch vụ máy chủ như xác thực, lưu trữ và thông báo đẩy."

---

## SLIDE 7: SƠ ĐỒ CA SỬ DỤNG TỔNG QUAN
* **Phân hệ Cư dân**: 11 nhóm ca sử dụng phục vụ đầy đủ nhu cầu sinh hoạt hàng ngày.
* **Phân hệ Vận hành**: 12 nhóm ca sử dụng chuyên biệt cho công tác quản trị, kế toán và kỹ thuật.
* **Các ca sử dụng trọng tâm**:
  * Đặt tiện ích kèm kiểm soát sức chứa và danh sách chờ.
  * Thẩm định chỉ số điện nước kèm tự động xuất hóa đơn.
  * Lập hóa đơn hàng loạt an toàn theo diện tích và số lượng phương tiện.

```
[CHÚ THÍCH HÌNH VẼ]: Sơ đồ ca sử dụng tổng quan và phân hệ (Hình 2.2a và Hình 2.2b)
```

> **Lời thoại thuyết trình:**
> "Hệ thống được thiết kế với 23 ca sử dụng chính, bao phủ từ các thao tác đơn giản như xem thông báo đến các nghiệp vụ phức tạp như điều phối danh sách chờ tiện ích và lập hóa đơn hàng loạt."

---

## SLIDE 8: KIẾN TRÚC PHẦN MỀM PHÂN TẦNG (FEATURE-FIRST)
* **Tầng Trình diễn (Presentation Layer)**: Giao diện Flutter, Widget dùng chung, hỗ trợ co giãn tự động không tràn màn hình.
* **Tầng Trạng thái (State Management)**: Quản lý phiên bằng `go_router`, đồng bộ dữ liệu phản ứng bằng `flutter_riverpod`.
* **Tầng Truy cập Dữ liệu (Data Access Layer)**: Lớp kho lưu trữ (Repositories) và Mô hình dữ liệu (Models) đóng gói toàn bộ lời gọi mạng.
* **Tầng Nền tảng Máy chủ (Supabase Backend)**: PostgreSQL 15, chính sách phân quyền cấp dòng (RLS), trigger kiểm soát và kênh đồng bộ thời gian thực (Realtime).

```
[CHÚ THÍCH HÌNH VẼ]: Sơ đồ kiến trúc phân tầng (Hình 2.3 trong Báo cáo)
```

> **Lời thoại thuyết trình:**
> "Về mặt kiến trúc, em áp dụng mô hình Feature-first kết hợp Riverpod. Toàn bộ logic giao diện được tách biệt tuyệt đối khỏi các thao tác gọi dữ liệu, giúp mã nguồn mạch lạc, dễ mở rộng và thuận tiện cho việc kiểm thử tự động."

---

## SLIDE 9: THIẾT KẾ CƠ SỞ DỮ LIỆU CHI TIẾT (ERD)
* **Chuẩn hóa mã căn hộ**: Định dạng chuẩn `A0110` (Block A, Tầng 01, Phòng 10).
* **Các thực thể nòng cốt**: `users`, `apartments`, `residents_apartments`, `invoices`, `invoice_items`, `meter_reading_submissions`, `vehicles`, `building_amenities`, `amenity_bookings`, `issue_reports`, `issue_images`, `issue_comments`, `issue_ratings`.
* **Tính toàn vẹn quan hệ**: Sử dụng khóa ngoại ràng buộc chặt chẽ (`ON DELETE CASCADE` hoặc `RESTRICT` ngăn xóa căn hộ đang có cư dân ở).

```
[CHÚ THÍCH HÌNH VẼ]: Sơ đồ quan hệ thực thể ERD chi tiết (Hình 2.6 trong Báo cáo)
```

> **Lời thoại thuyết trình:**
> "Mô hình dữ liệu quan hệ gồm 16 bảng được chuẩn hóa, bảo đảm tính liên kết toàn vẹn từ người dùng, căn hộ đến từng hạng mục chi phí và lịch sử phản ánh sự cố."

---

## SLIDE 10: ĐIỂM SÁNG KỸ THUẬT 1: PHÒNG THỦ 3 LỚP CHỐNG LEO THANG ĐẶC QUYỀN
* **Bài toán đặt ra**: Ngăn chặn người dùng cố tình can thiệp gói tin để đổi vai trò thành Quản trị viên (`role = 'admin'`).
* **Giải pháp 3 lớp khép kín (Defense-in-Depth)**:
  1. *Lớp 1 (Trigger CSDL)*: `trg_prevent_role_self_escalation` ném ngoại lệ nếu người sửa không phải Quản trị viên.
  2. *Lớp 2 (Chính sách RLS)*: Mệnh đề `WITH CHECK (role = (SELECT role FROM users WHERE id = auth.uid()))` từ chối gói tin nếu vai trò bị đổi.
  3. *Lớp 3 (Hàm thủ tục lưu trữ an toàn)*: Hàm `update_own_profile` chỉ nhận họ tên và số điện thoại, loại bỏ hoàn toàn thuộc tính vai trò khỏi tham số.

> **Lời thoại thuyết trình:**
> "Điểm sáng bảo mật đầu tiên là cơ chế phòng thủ ba lớp chống leo thang đặc quyền. Kể cả khi kẻ tấn công can thiệp vào mã nguồn ứng dụng di động để gửi yêu cầu cập nhật quyền quản trị viên, tầng cơ sở dữ liệu sẽ lập tức phát hiện và hủy giao dịch."

---

## SLIDE 11: ĐIỂM SÁNG KỸ THUẬT 2: TOÀN VẸN DỮ LIỆU TÀI CHÍNH CẤP MÁY CHỦ
* **Nguyên tắc cốt lõi**: Không tin tưởng bất kỳ phép tính nào gửi từ ứng dụng khách.
* **Cơ chế triển khai**:
  * Cột `subtotal` trong bảng `invoice_items` sử dụng cột tính toán sẵn của PostgreSQL (`GENERATED ALWAYS AS (unit_price * quantity) STORED`).
  * Hàm trigger `trg_recalc_invoice_total` tự động cộng dồn các khoản chi tiết vào `total_amount` của bảng hóa đơn mẹ.
  * Lập hóa đơn hàng loạt qua hàm thủ tục lưu trữ `generate_valid_bulk_invoices`: tự động đếm số lượng xe máy và ô tô đã duyệt của từng căn hộ để tính phí gửi xe chính xác 100%.

> **Lời thoại thuyết trình:**
> "Về mặt tài chính, em loại bỏ hoàn toàn việc tính tiền từ ứng dụng di động. Toàn bộ tiền thành phần và tổng tiền hóa đơn đều do chính hệ quản trị cơ sở dữ liệu tính toán tự động qua cột Generated Column và Trigger máy chủ."

---

## SLIDE 12: ĐIỂM SÁNG KỸ THUẬT 3: KIỂM SOÁT SỨC CHỨA & DANH SÁCH CHỜ TIỆN ÍCH
* **Xử lý đồng thời (Concurrency Control)**: Khóa tài nguyên tiện ích theo ngày và khung giờ bằng lệnh `FOR UPDATE`.
* **Cơ chế điều phối thông minh**:
  * Kiểm tra số lượng khách thực tế (`guests_count`) so với sức chứa tối đa (`max_capacity`).
  * Nếu còn chỗ: Xác nhận đặt chỗ thành công.
  * Nếu kín lịch: Tự động ghi nhận vào danh sách chờ (`WAITLIST`). Khi có người hủy lịch, hệ thống hỗ trợ đôn lượt ưu tiên tiếp theo.

> **Lời thoại thuyết trình:**
> "Khi đặt các tiện ích có sức chứa giới hạn như bể bơi hay phòng tập thể thao, hệ thống áp dụng khóa giao dịch để giải quyết bài toán đặt chỗ đồng thời tại cùng một thời điểm, tránh tình trạng vượt quá sức chứa cho phép."

---

## SLIDE 13: LUỒNG NGHIỆP VỤ THỰC TẾ: ĐIỆN NƯỚC & THANH TOÁN MÔ PHỎNG
* **Chu trình khép kín của chỉ số điện nước**:
  1. Cư dân chụp ảnh công tơ và nhập số đo mới.
  2. Kế toán thẩm định ảnh đối chiếu: Kiểm tra quy tắc số mới bắt buộc $\ge$ số cũ.
  3. Duyệt chỉ số: Hệ thống tự động tính lượng tiêu thụ và xuất hóa đơn tiền điện nước.
* **Cổng thanh toán mô phỏng đồng nhất (Unified Payment)**:
  * Quét mã VietQR mô phỏng tự động điền nội dung.
  * Nộp ủy nhiệm chi chuyển khoản xác nhận hai bước (`PENDING` $\rightarrow$ Kế toán duyệt $\rightarrow$ `PAID`).
  * Ghi nhận nộp tiền mặt trực tiếp tại quầy Ban Quản Lý.

> **Lời thoại thuyết trình:**
> "Quy trình khai báo chỉ số điện nước kết nối trực tiếp với khâu thanh toán. Kế toán sau khi duyệt ảnh công tơ có thể kích hoạt tạo hóa đơn tự động; cư dân sau đó thanh toán ngay qua cổng VietQR mô phỏng hoặc chuyển khoản hai bước."

---

## SLIDE 14: KẾT QUẢ KIỂM THỬ TỰ ĐỘNG & NGHIỆM THU CHẤT LƯỢNG
* **Phân tích tĩnh mã nguồn (`dart analyze`)**: Đạt **0 Cảnh báo / 0 Lỗi**.
* **Quy mô bộ kiểm thử tự động**:
  * **131 tệp kiểm thử** trải dài từ tầng cơ sở đến tầng màn hình.
  * **395 bài kiểm thử** tự động được thực thi thành công (**Tỷ lệ đạt: 100%**).
  * Kiểm chứng đầy đủ: Kiểm thử đơn vị, kiểm thử giao diện co giãn trên màn hình 360 điểm ảnh, kiểm thử bảo mật RLS và kiểm thử hàm lưu trữ RPC.

```
[CHÚ THÍCH HÌNH VẼ]: Bảng số liệu kiểm thử tự động (Bảng 2.10 trong Báo cáo)
```

> **Lời thoại thuyết trình:**
> "Để bảo đảm phần mềm vận hành ổn định và không phát sinh lỗi tiềm ẩn, em đã xây dựng một bộ test suite gồm 131 tệp với 395 ca kiểm thử tự động. Toàn bộ các ca test đều vượt qua 100%, bảo đảm từ phân tích tĩnh đến kiểm thử bảo mật RLS."

---

## SLIDE 15: MINH CHỨNG GIAO DIỆN PHÂN HỆ CƯ DÂN

```
+---------------------------------------------------------------------------------------------------+
| [CHÚ THÍCH ẢNH CHỤP THỰC TẾ]: GHÉP 3 MÀN HÌNH CƯ DÂN TRÊN THIẾT BỊ DI ĐỘNG                         |
| 1. Trang chủ cư dân (Smart Dashboard): Thẻ tổng nợ đỏ, mã phòng A0110, widget sự cố khẩn cấp.       |
| 2. Chi tiết hóa đơn: Phân rã từng khoản phí kèm biểu tượng trực quan và cổng thanh toán mô phỏng. |
| 3. Khai báo chỉ số & Đặt tiện ích: Giao diện nhập số công tơ điện nước và đặt lịch tiện ích.      |
+---------------------------------------------------------------------------------------------------+
```

> **Lời thoại thuyết trình:**
> "Kính mời quý thầy cô quan sát giao diện thực tế của phân hệ Cư dân. Trang chủ được thiết kế theo xu hướng Smart Dashboard với tông màu trực quan, hiển thị công nợ tức thì và hỗ trợ các thao tác thanh toán, báo sự cố chỉ với một chạm."

---

## SLIDE 16: MINH CHỨNG GIAO DIỆN PHÂN HỆ BAN QUẢN LÝ

```
+---------------------------------------------------------------------------------------------------+
| [CHÚ THÍCH ẢNH CHỤP THỰC TẾ]: GHÉP 3 MÀN HÌNH QUẢN TRỊ TRÊN THIẾT BỊ DI ĐỘNG                      |
| 1. Bảng điều khiển BQL: Huy hiệu đếm số việc chờ duyệt (liên kết, hóa đơn, sự cố, xe) và biểu đồ. |
| 2. Lập hóa đơn hàng loạt: Hộp thoại tự động tính tiền xe máy, ô tô theo từng căn hộ.              |
| 3. Xử lý phản ánh & Đánh giá dịch vụ: Nhật ký bình luận thời gian thực và biểu đồ KPI dịch vụ.     |
+---------------------------------------------------------------------------------------------------+
```

> **Lời thoại thuyết trình:**
> "Đối với phân hệ Ban Quản Lý, bảng điều khiển tập trung toàn bộ các đầu việc tồn đọng dưới dạng thẻ có huy hiệu thông báo số lượng, hỗ trợ lập hóa đơn tự động cho hàng trăm căn hộ và theo dõi điểm đánh giá dịch vụ của từng kỹ thuật viên."

---

## SLIDE 17: KẾT LUẬN & ĐÓNG GÓP CỦA ĐỒ ÁN
* **Các kết quả đạt được**:
  * Xây dựng thành công nguyên mẫu ứng dụng quản lý chung cư hoàn chỉnh, đáp ứng 24 yêu cầu chức năng.
  * Hiện thực hóa thành công kiến trúc bảo mật ba lớp chống leo thang đặc quyền và toàn vẹn dữ liệu tài chính tại cơ sở dữ liệu.
  * Ứng dụng hoạt động mượt mà, giao diện 100% tiếng Việt, vượt qua toàn bộ 395 bài kiểm thử tự động.
* **Giá trị thực tiễn**:
  * Đóng góp một giải pháp tham khảo chất lượng cao cho bài toán số hóa công tác quản trị chung cư và tòa nhà thông minh.

> **Lời thoại thuyết trình:**
> "Đồ án đã hoàn thành toàn bộ các mục tiêu đặt ra, cung cấp một sản phẩm có tính hoàn thiện cao, vừa đáp ứng tốt nghiệp vụ quản lý chung cư, vừa bảo đảm nghiêm ngặt các tiêu chuẩn an toàn thông tin của một hệ thống phần mềm hiện đại."

---

## SLIDE 18: HƯỚNG PHÁT TRIỂN TRONG TƯƠNG LAI
1. **Kết nối cổng thanh toán trực tiếp**: Tích hợp giao diện lập trình mở của ngân hàng thương mại để tự động gạch nợ hóa đơn thời gian thực.
2. **Nhận diện biển số và công tơ bằng trí tuệ nhân tạo**: Tích hợp mô hình thị giác máy tính cục bộ trên thiết bị di động hỗ trợ nhận diện tự động số công tơ và biển số xe.
3. **Mở rộng đa nền tảng**: Tối ưu hóa và phát hành phiên bản dành cho iOS và bảng điều khiển quản trị trên nền tảng Web.

> **Lời thoại thuyết trình:**
> "Trong giai đoạn tiếp theo, hệ thống có thể mở rộng kết nối với cổng thanh toán ngân hàng mở, đồng thời tích hợp mô hình thị giác máy tính để tự động nhận diện chỉ số công tơ từ ảnh chụp của cư dân."

---

## SLIDE 19: LỜI CẢM ƠN & PHẦN HỎI ĐÁP (Q&A)
* **Tiêu đề**: XIN CHÂN THÀNH CẢM ƠN QUÝ THẦY CÔ VÀ HỘI ĐỒNG ĐÁNH GIÁ!
* **Thông tin liên hệ**:
  * Sinh viên thực hiện: Phạm Văn Minh
  * Email: 23010350@st.phenikaa-uni.edu.vn
  * Trường Đại học Phenikaa
* **Phần giải đáp câu hỏi của Hội đồng (Q&A)**

> **Lời thoại thuyết trình:**
> "Em xin chân thành cảm ơn quý thầy cô trong Hội đồng đã chú ý lắng nghe bài báo cáo của em. Em rất mong nhận được những ý kiến đóng góp, nhận xét và câu hỏi của quý thầy cô để sản phẩm được hoàn thiện hơn nữa. Em xin trân trọng cảm ơn!"
