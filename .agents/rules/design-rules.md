---
trigger: always_on
---

# Quy Tắc Thiết Kế Giao Diện (UI/UX)

## 1. Ngôn ngữ và Trình bày
- Sử dụng hoàn toàn tiếng Việt chuẩn mực trong giao diện, nhãn dán, và nút bấm. 
- Ngoại lệ: Được phép giữ nguyên các thuật ngữ tiếng Anh đã quá phổ biến và khó dịch sát nghĩa (VD: Email, App, Internet, Wifi).
- Tuyệt đối không dùng từ tiếng Anh đặt trong ngoặc đơn để giải nghĩa kiểu (Password) hoặc viết lẫn lộn Anh-Việt không cần thiết.
- Câu từ phải ngắn gọn, rõ nghĩa, chuẩn xác ngữ pháp tiếng Việt.

## 2. Quy tắc Kiến trúc và Phân chia Chức năng Màn hình
- Mỗi màn hình giao diện chỉ đảm nhận một nhóm nhiệm vụ chuyên biệt:
  - **Màn hình Trang chủ**: Chỉ hiển thị tổng quan thông báo mới và hóa đơn đến hạn.
  - **Màn hình Hóa đơn & Thanh toán**: Chỉ tập trung vào chi tiết các khoản phí và thao tác thanh toán.
  - **Màn hình Phản ánh**: Chỉ dành riêng cho việc gửi yêu cầu sự cố và theo dõi tiến độ xử lý.
  - **Màn hình Quản trị (Ban quản lý)**: Dành riêng cho thao tác quản lý căn hộ, lập hóa đơn và gửi thông báo.

## 3. Quy tắc Giao diện và Font chữ
- **Font chữ**: Sử dụng package `google_fonts` (hoặc bundle file `.ttf`) để đảm bảo Segoe UI/Google Fonts hiển thị nhất quán trên cả iOS và Android.
- **Icon**: Ưu tiên sử dụng thư viện Icon mặc định của Flutter (`Icons.*` thuộc Material Design) để giảm thiểu phụ thuộc package ngoài. Đảm bảo sự nhất quán trên toàn ứng dụng. Không sử dụng Emoji.
- **Màu sắc**: Định nghĩa bảng màu (palette) trong `core/theme/`. Tuyệt đối không hardcode mã màu rời rạc trong từng widget.
- **Bố cục (Layout)**: 
  - Các thẻ nội dung (Card) phải được thiết lập để tự động xuống dòng (Word-wrap) khi văn bản dài.
  - Không giới hạn chiều cao cứng (Sử dụng `Wrap`, `ConstrainedBox` thay vì `SizedBox` với height cố định).
  - Cửa sổ ứng dụng (nếu có bản web/desktop) phải linh hoạt co giãn.
