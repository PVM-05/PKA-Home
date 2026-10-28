# Danh Sách Tài Khoản Demo & Kịch Bản Thuyết Trình (PKA-Home)

Tài liệu này tổng hợp toàn bộ thông tin đăng nhập và các kịch bản demo tiêu biểu phục vụ việc kiểm thử hệ thống và thuyết trình bảo vệ đồ án tốt nghiệp ứng dụng **PKA-Home - Hệ thống Quản trị & Tiện ích Chung cư Thông minh**.

---

## 1. Thông Tin Đăng Nhập Chung

> [!IMPORTANT]
> **Mật khẩu dùng chung cho tất cả tài khoản:** `PkaHome@2026`  
> Toàn bộ tài khoản đều sử dụng định dạng email `@gmail.com` chuẩn để đảm bảo tính thực tế và chuyên nghiệp.

---

## 2. Tài Khoản Ban Quản Lý & Vận Hành (Management)

| Vai trò | Email | Mật khẩu | Họ và tên | Số điện thoại | Chức năng nổi bật |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Quản trị viên (Admin)** | `pkahome.admin@gmail.com` | `PkaHome@2026` | Nguyễn Văn An | `0901234567` | Toàn quyền quản trị hệ thống, Dashboard tổng quan, Quản lý tòa nhà & căn hộ, Duyệt thẻ xe, Đăng thông báo khẩn |
| **Kế toán (Accountant)** | `pkahome.ketoan@gmail.com` | `PkaHome@2026` | Trần Thị Mai | `0902345678` | Quản lý hóa đơn dịch vụ hàng loạt, Đối soát thanh toán, Duyệt chỉ số điện nước cư dân gửi |
| **Kỹ thuật viên (Technician)** | `pkahome.kythuat@gmail.com` | `PkaHome@2026` | Lê Hoàng Long | `0903456789` | Tiếp nhận & xử lý phản ánh sự cố, Tải ảnh nghiệm thu sau xử lý, Theo dõi lịch bảo trì 5 thiết bị tòa nhà |

---

## 3. Danh Sách Tài Khoản Cư Dân Đại Diện (Residents)

Hệ thống đã nạp sẵn 25 căn hộ có cư dân sinh sống trên cả 3 Tòa (Block A, Block B, Block C). Dưới đây là các tài khoản tiêu biểu được cấu hình sẵn dữ liệu phong phú:

### Tòa A (Block A)
| Căn hộ | Email | Họ và tên | Vai trò | Phương tiện (Thẻ xe) | Kịch bản demo phù hợp |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **A0101** | `cudan.a0101@gmail.com` | Phạm Minh Đức | Chủ hộ | 2 Xe máy (`29A1-123.45`, `29B1-678.90`) - Đã duyệt | Demo căn hộ đầy đủ tiện nghi, lịch sử hóa đơn 3 tháng, phản ánh sự cố thang máy đã giải quyết & đánh giá 5 sao |
| **A0101 (Người thân)** | `nguoithan.a0101@gmail.com` | Nguyễn Thị Lan | Thành viên | Cùng căn hộ A0101 | Demo chức năng nhiều thành viên cùng quản lý căn hộ |
| **A0102** | `cudan.a0102@gmail.com` | Vũ Tuấn Anh | Chủ hộ | 1 Xe máy (`29C1-111.22`) + 1 Ô tô (`30H-888.88`) | Demo căn hộ sở hữu đồng thời cả ô tô và xe máy |
| **A0301** | `cudan.a0301@gmail.com` | Lê Quang Huy | Chủ hộ | 1 Xe máy (Đã duyệt) + **1 Ô tô (`30H-991.23` - Chờ duyệt)** | **Kịch bản Demo Duyệt Thẻ Xe:** Cư dân thấy thẻ xe đang chờ duyệt -> Admin mở app phê duyệt |
| **A0501** | `cudan.a0501@gmail.com` | Trần Bảo Nam | Chủ hộ | 1 Ô tô (Đã duyệt) + **1 Xe máy (`29M1-999.99` - Bị từ chối)** | **Kịch bản Demo Xử lý Xe Từ chối:** Cư dân xem lý do từ chối -> Bấm Xóa -> Nộp lại hồ sơ xe hợp lệ |

### Tòa B (Block B)
| Căn hộ | Email | Họ và tên | Vai trò | Phương tiện (Thẻ xe) | Kịch bản demo phù hợp |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **B0101** | `cudan.b0101@gmail.com` | Hoàng Ngọc Tuấn | Chủ hộ | 1 Xe máy (Đã duyệt) + **1 Xe máy (`59X1-999.88` - Chờ duyệt)** | Thử nghiệm duyệt nhanh xe máy |
| **B0202** | `cudan.b0202@gmail.com` | Hoàng Thùy Linh | **Khách thuê** | 1 Ô tô (`30H-234.56`) - Đã duyệt | Demo vai trò Khách thuê (`tenant`) với các quyền hạn tương ứng |
| **B0401** | `cudan.b0401@gmail.com` | Ngô Thành Đạt | Chủ hộ | 1 Ô tô (Đã duyệt) + **1 Xe máy (`29T1-888.77` - Bị từ chối)** | Lý do: Vượt quá hạn mức số lượng xe máy quy định |

### Tòa C (Block C)
| Căn hộ | Email | Họ và tên | Vai trò | Phương tiện (Thẻ xe) | Kịch bản demo phù hợp |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **C0101** | `cudan.c0101@gmail.com` | Đinh Trọng Nghĩa | Chủ hộ | 1 Xe máy (`29V1-567.89`) - Đã duyệt | Có sự cố điện đang được kỹ thuật viên tiếp nhận xử lý |
| **C0301** | `cudan.c0301@gmail.com` | Đỗ Quang Hải | Chủ hộ | 2 Xe máy (`29AA-111.22`, `29AA-333.44`) - Đã duyệt | Có lịch đặt trước Sân Tennis và sự cố chuông PCCC đã nghiệm thu |
| **C0401** | `cudan.c0401@gmail.com` | Quách Ánh Tuyết | Chủ hộ | 1 Xe máy (Chờ duyệt) + **1 Ô tô (`30K-999.88` - Bị từ chối)** | Lý do: Thiếu ảnh chụp giấy đăng ký xe chính chủ |

---

## 4. Dữ Liệu Vận Hành Sẵn Có Trong Cơ Sở Dữ Liệu

1. **Tổng số căn hộ**: 150 căn (Tòa A, B, C; tầng 1 đến tầng 10).
2. **Căn hộ đã có cư dân**: 25 căn với hợp đồng và thông tin chủ hộ/khách thuê đầy đủ.
3. **Thẻ xe (Phương tiện)**: 40 xe (28 xe máy, 12 ô tô):
   - **32 thẻ Đã duyệt (`approved`)**
   - **5 thẻ Chờ duyệt (`pending`)**
   - **3 thẻ Bị từ chối (`rejected`)** kèm lý do cụ thể từ Ban Quản Lý.
4. **Hóa đơn dịch vụ & Tiền tệ**:
   - 75 hóa đơn (3 chu kỳ: 08/2026, 09/2026, 10/2026).
   - Chi tiết cấu thành từng khoản: Phí quản lý (tính theo diện tích căn hộ x 16.500đ/m²), Điện, Nước, Phí gửi xe (100.000đ/xe máy, 1.200.000đ/ô tô).
   - 20 giao dịch thanh toán thành công qua mô phỏng Cổng thanh toán **Demo Payment**.
5. **Khai báo chỉ số điện nước**:
   - 10 lượt cư dân chụp ảnh công tơ gửi lên (7 lượt đã duyệt, 3 lượt chờ kế toán thẩm định).
6. **Thiết bị tòa nhà & Kế hoạch bảo trì định kỳ**:
   - 5 thiết bị trọng yếu: Thang máy Schindler A1, Thang máy Mitsubishi B1, Hệ thống PCCC Hochiki, Máy bơm Grundfos, Máy phát Cummins 750kVA.
   - 5 phiếu bảo trì định kỳ đã lên lịch cho đội ngũ kỹ thuật.
7. **Tiện ích & Đặt chỗ (Amenities & Bookings)**:
   - 5 khu tiện ích: Hồ bơi bốn mùa, Phòng Gym & Yoga, Phòng sinh hoạt cộng đồng, Sân Tennis, Khu BBQ ngoài trời.
   - 10 lượt đặt lịch không trùng khung giờ của cư dân.
8. **Phản ánh sự cố & Đánh giá**:
   - 10 sự cố thực tế kèm phân loại mức độ ưu tiên (Thang máy, điện, nước, PCCC).
   - Có đầy đủ ảnh hiện trường (trước) và ảnh biên bản nghiệm thu (sau).
   - 4 đánh giá 5 sao kèm lời khen ngợi cho kỹ thuật viên.
9. **Bảng tin & Thông báo**:
   - 10 bản tin tòa nhà (trong đó có 2 thông báo khẩn cấp màu đỏ nổi bật về diễn tập PCCC và bảo trì thang máy).

---

## 5. Hướng Dẫn Các Luồng Trình Diễn (Demo Flows)

### Kịch bản 1: Cư Dân Thanh Toán Hóa Đơn Bằng Cổng Thanh Toán Demo
1. Đăng nhập tài khoản cư dân `cudan.a0101@gmail.com` / `PkaHome@2026`.
2. Vào tab **Hóa đơn & Thanh toán**.
3. Chọn hóa đơn tháng **10/2026** (trạng thái Chưa thanh toán).
4. Xem chi tiết bảng phân bổ chi phí (quản lý, điện, nước, gửi xe).
5. Bấm **Thanh toán ngay** -> Hệ thống hiển thị Cổng thanh toán Demo Payment hỗ trợ thanh toán 1 chạm.
6. Xác nhận thanh toán thành công -> Trạng thái hóa đơn chuyển sang Đã thanh toán và lưu lịch sử giao dịch.

### Kịch bản 2: Vòng Đời Thẻ Xe (Đăng Ký - Từ Chối - Đăng Ký Lại - Phê Duyệt)
1. Đăng nhập tài khoản `cudan.a0501@gmail.com`.
2. Vào mục **Phương tiện** -> Thấy xe `29M1-999.99` màu đỏ với nhãn **Bị từ chối** và lý do.
3. Bấm **Xóa yêu cầu** để giải phóng bản ghi.
4. Bấm **Đăng ký xe mới** với biển số hợp lệ.
5. Đăng xuất và đăng nhập `pkahome.admin@gmail.com` (Ban Quản Lý).
6. Mở **Quản lý Phương tiện** -> Tab **Chờ duyệt** -> Bấm **Phê duyệt** xe mới đăng ký.

### Kịch bản 3: Kỹ Thuật Viên Tiếp Nhận & Nghiệm Thu Sự Cố
1. Đăng nhập `pkahome.kythuat@gmail.com`.
2. Mở danh sách **Sự cố & Phản ánh** -> Xem các sự cố đang xử lý.
3. Chọn sự cố, cập nhật tiến độ, đính kèm ảnh nghiệm thu hoàn thành.
4. Chuyển trạng thái sang **Đã giải quyết**.

### Kịch bản 4: Ban Quản Lý Đăng Thông Báo Khẩn Cấp
1. Đăng nhập `pkahome.admin@gmail.com`.
2. Vào **Bảng tin thông báo** -> Bấm **Tạo thông báo mới**.
3. Bật tùy chọn **Khẩn cấp** và chọn phạm vi toàn khu dân cư.
4. Đăng thông báo -> Đăng nhập lại app cư dân để thấy thông báo gắn cờ đỏ ưu tiên ở đầu Trang chủ.
