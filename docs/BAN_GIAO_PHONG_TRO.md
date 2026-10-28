# Tài Liệu Bàn Giao Hệ Thống PKA-Home Cho Đơn Vị Quản Lý Phòng Trọ

> **Phiên bản áp dụng:** PKA-Home v2.1 (Hỗ trợ cấu hình song song Chung cư và Phòng trọ)  
> **Ngày chuẩn bị:** 28/10/2026  
> **Mô hình triển khai khuyến nghị:** Phương án A (Managed SaaS - Đội ngũ kỹ thuật vận hành hạ tầng Supabase, Đơn vị sử dụng app quản lý)

---

## 1. Tổng Quan Sự Khác Biệt & Cơ Chế Hoạt Động

PKA-Home hỗ trợ linh hoạt 2 chế độ tài sản thông qua trường `property_type` trong bảng `buildings`:
1. **`apartment` (Chung cư tiêu chuẩn):** Mã căn chuẩn `A0110`, phí quản lý tính theo diện tích `m²`, hiển thị Quỹ bảo trì 2% theo Điều 108 Luật Nhà ở, tiện ích hồ bơi/BBQ.
2. **`boarding_house` (Phòng trọ / Nhà trọ):** 
   - Mã phòng linh hoạt: Chấp nhận `P101`, `101`, `Phòng 3`, `P.201`, `T2-05`.
   - Tính phí: Tiền phòng cố định theo tháng (`rent_price`), không bắt buộc diện tích `m²`.
   - Tự động ẩn: Thẻ Quỹ bảo trì 2%, các sổ quỹ chung cư không liên quan.
   - Biểu phí cơ sở: Điện, nước (theo đồng hồ hoặc khoán đầu người), rác, wifi, gửi xe máy.

---

## 2. Đặc Tả 6 Sheet File Excel Thu Thập Dữ Liệu Ban Đầu

Gửi file Excel mẫu có 6 sheet sau cho chủ trọ/đơn vị quản lý điền trước ngày bàn giao:

### Sheet 1: `CoSo_DayNha` (Danh sách cơ sở / dãy trọ)
*Tương ứng bảng `buildings`*
| Tên Cột | Kiểu Dữ Liệu | Bắt Buộc | Quy Tắc Kiểm Tra | Ví Dụ Mẫu |
| :--- | :--- | :---: | :--- | :--- |
| `ma_co_so` | Chữ/Số | Có | Viết liền, không dấu, duy nhất | `CS01`, `TRO_KIMMA` |
| `ten_co_so` | Chữ | Có | Tên cơ sở trọ hiển thị | `Nhà trọ Kim Mã Cơ sở 1` |
| `dia_chi` | Chữ | Có | Địa chỉ thực tế dãy trọ | `Số 12 ngõ 45 Kim Mã, Ba Đình, Hà Nội` |
| `so_tang` | Số nguyên | Có | Số nguyên > 0 (1-50) | `4` |
| `so_phong` | Số nguyên | Có | Tổng số lượng phòng | `16` |
| `ghi_chu` | Chữ | Không | Ghi chú thêm | `Cổng vân tay, giờ giấc tự do` |

### Sheet 2: `DanhSach_Phong` (Danh mục phòng trọ)
*Tương ứng bảng `apartments`*
| Tên Cột | Kiểu Dữ Liệu | Bắt Buộc | Quy Tắc Kiểm Tra | Ví Dụ Mẫu |
| :--- | :--- | :---: | :--- | :--- |
| `ma_phong` | Chữ/Số | Có | 1–15 ký tự, duy nhất trong cơ sở | `P101`, `P102`, `101`, `Phòng 3` |
| `ma_co_so` | Chữ/Số | Có | Khớp với `ma_co_so` ở Sheet 1 | `CS01` |
| `tang` | Số nguyên | Có | Tầng phòng trọ (≥ 1) | `1` |
| `dien_tich_m2` | Số thực | Không | Diện tích phòng m² (nếu có) | `22.5` |
| `gia_thue_thang` | Số nguyên | Có | Tiền phòng cố định/tháng (VNĐ) | `3500000` |
| `tien_coc` | Số nguyên | Có | Tiền đặt cọc quy định (VNĐ) | `3500000` |
| `so_nguoi_toi_da` | Số nguyên | Có | Số người ở tối đa cho phép | `3` |
| `tinh_trang` | Chữ | Có | `Đang thuê` hoặc `Trống` | `Đang thuê` |
| `dong_ho_dien` | Chữ | Có | `Riêng` hoặc `Chung` | `Riêng` |
| `dong_ho_nuoc` | Chữ | Có | `Riêng` hoặc `Theo đầu người` | `Theo đầu người` |

### Sheet 3: `Khach_Thue` (Thông tin người thuê phòng)
*Tương ứng bảng `users` và `residents_apartments`*
| Tên Cột | Kiểu Dữ Liệu | Bắt Buộc | Quy Tắc Kiểm Tra | Ví Dụ Mẫu |
| :--- | :--- | :---: | :--- | :--- |
| `ho_ten` | Chữ | Có | Họ tên khách thuê | `Nguyễn Văn An` |
| `so_dien_thoai` | Số | Có | 10 số (dùng làm tài khoản đăng nhập) | `0912345678` |
| `cccd` | Số | Có | 12 số (dùng khai báo tạm trú) | `001201012345` |
| `email` | Email | Không | Gửi biên lai/thông báo điện tử | `an.nguyen@gmail.com` |
| `ma_phong` | Chữ/Số | Có | Khớp `ma_phong` ở Sheet 2 | `P101` |
| `la_dai_dien` | Chữ | Có | `Đúng` (chịu trách nhiệm nhận bill) / `Sai` | `Đúng` |
| `ngay_vao_o` | Ngày | Có | Định dạng `YYYY-MM-DD` | `2026-09-01` |
| `ngay_het_han_hd`| Ngày | Có | Định dạng `YYYY-MM-DD` | `2027-08-31` |
| `tien_coc_da_thu`| Số nguyên | Có | Tiền cọc thực tế đã nhận (VNĐ) | `3500000` |
| `bien_so_xe` | Chữ | Không | Biển số xe máy gửi tại nhà xe | `29B1-567.89` |

### Sheet 4: `ChiSo_CongTo_DauKy` (Chỉ số công tơ lúc bàn giao)
*Tương ứng bảng `meter_readings`*
| Tên Cột | Kiểu Dữ Liệu | Bắt Buộc | Quy Tắc Kiểm Tra | Ví Dụ Mẫu |
| :--- | :--- | :---: | :--- | :--- |
| `ma_phong` | Chữ/Số | Có | Khớp mã phòng ở Sheet 2 | `P101` |
| `chi_so_dien_dau`| Số thực | Có | Số kWh chốt ban đầu trên đồng hồ | `1450.5` |
| `chi_so_nuoc_dau`| Số thực | Không | Số m³ chốt ban đầu (nếu có công tơ riêng) | `82.0` |
| `ngay_chot_so` | Ngày | Có | Định dạng `YYYY-MM-DD` | `2026-10-31` |
| `ghi_chu` | Chữ | Không | Tình trạng kẹp chì, niêm phong | `Đồng hồ mới kiểm định` |

### Sheet 5: `BieuGia_DichVu` (Cấu hình giá thu dịch vụ)
*Tương ứng bảng `fee_schedules` và `fee_items`*
| Loại Phí | Mã Phí | Đơn Giá (VNĐ) | Đơn Vị Tính | Cách Tính |
| :--- | :--- | :---: | :--- | :--- |
| Tiền điện sinh hoạt | `electricity` | 3.800 | đ/kWh | Theo công tơ |
| Tiền nước sinh hoạt | `water` | 30.000 | đ/người/tháng | Theo đầu người |
| Rác sinh hoạt & vệ sinh | `trash` | 30.000 | đ/phòng/tháng | Cố định theo phòng |
| Mạng Internet / Wifi | `internet` | 100.000 | đ/phòng/tháng | Cố định theo phòng |
| Phí giữ xe máy | `parking_motorcycle`| 80.000 | đ/xe/tháng | Theo số lượng xe đăng ký |

### Sheet 6: `CongNo_DauKy` (Công nợ tồn trước khi bàn giao)
*Tương ứng bảng `invoices` kỳ khởi tạo*
| Tên Cột | Kiểu Dữ Liệu | Bắt Buộc | Quy Tắc Kiểm Tra | Ví Dụ Mẫu |
| :--- | :--- | :---: | :--- | :--- |
| `ma_phong` | Chữ/Số | Có | Khớp mã phòng ở Sheet 2 | `P102` |
| `so_tien_no_ton` | Số nguyên | Có | > 0: Khách còn nợ, < 0: Khách đóng dư | `1250000` |
| `noi_dung_no` | Chữ | Có | Giải thích kỳ nợ cũ | `Tiền điện nước tháng 09/2026 chưa nộp` |

---

## 3. Quy Trình Kỹ Thuật Nạp Dữ Liệu

1. **Khởi tạo môi trường Supabase**:
   - Chạy tuần tự các migration từ Baseline:
     - `20261027_01_baseline_schema.sql`
     - `20261027_02_dynamic_fees_and_maintenance_fund.sql`
     - `20261027_03_multi_tenancy_organizations_and_buildings.sql`
     - `20261028_01_notifications_and_reminders.sql`
     - `20261028_02_boarding_house_extension.sql`
2. **Nạp dữ liệu từ 6 Sheet**:
   - Sử dụng kịch bản SQL Transaction (xem mẫu trong migration `20261028_02_boarding_house_extension.sql`).
   - Thứ tự insert: `organizations` -> `buildings` -> `apartments` -> `users` -> `residents_apartments` -> `fee_schedules` -> `meter_readings` -> `invoices (công nợ đầu kỳ)`.
3. **Kiểm tra chéo (Data Sanity Check)**:
   - Tổng số phòng trong DB = Số phòng trên Sheet 2.
   - Không có phòng nào "Trống" nhưng lại có người ở trên Sheet 3.
   - Các phòng có người ở đều có chỉ số công tơ chốt ban đầu.

---

## 4. Danh Sách Kiểm Tra Khi Nghiệm Thu (UAT Checklist)

- [ ] **Tạo và sửa phòng trọ:** Admin nhập được mã phòng tự do như `P101`, `101`, `Phòng 3` thành công.
- [ ] **Lập hóa đơn tiền phòng:**
  - Chọn phòng có tiền thuê cài đặt sẵn -> Hệ thống tự động kích hoạt chế độ "Tiền thuê phòng cố định".
  - Hóa đơn lưu đúng loại phí `"Tiền thuê phòng"`, số lượng 1 phòng.
- [ ] **Ẩn module không liên quan:** Màn hình chính của cơ sở phòng trọ không hiển thị thẻ Quỹ bảo trì 2%.
- [ ] **Thông báo hướng đích:** Admin gửi thông báo đến đích danh phòng `P101` hoặc `101` không bị báo lỗi định dạng.
- [ ] **Biên lai thu tiền điện tử:** Chia sẻ biên lai hiển thị đúng mã phòng của khách thuê, không có fallback lỗi.

---

## 5. Hướng Dẫn Vận Hành Song Song (Parallel Run)

- **Tháng thứ 1:** Chủ trọ tiếp tục ghi sổ tay / file Excel cũ song song với việc thao tác trên app (nhập chỉ số, phát hành hóa đơn, bấm gạch nợ khi nhận chuyển khoản).
- **Cuối tháng thứ 1:** So khớp số tiền thu được giữa sổ cũ và báo cáo trên app. Nếu khớp 100%, chuyển hoàn toàn sang vận hành trên PKA-Home từ tháng thứ 2.
