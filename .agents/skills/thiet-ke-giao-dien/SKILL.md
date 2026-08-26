---
name: thiet-ke-giao-dien
description: Kích hoạt khi phát triển, chỉnh sửa hoặc kiểm thử giao diện người dùng cho ứng dụng Quản lý Chung cư (PKA-Home).
---

# Quy trình Thiết kế và Phát triển Giao diện

## 1. Nguyên tắc Cốt lõi
- **Ngôn ngữ**: 100% Tiếng Việt chuẩn mực. Không kèm từ tiếng Anh trong ngoặc đơn.
- **Biểu tượng**: Sử dụng thống nhất bộ biểu tượng Fluent Icons (hoặc Material/Lucide nếu đã chốt). Không dùng biểu tượng cảm xúc (emoji).
- **Phông chữ**: Segoe UI (hoặc Google Fonts) sắc nét, phối màu hiện đại và đồng nhất theo `theme_spec.md`.

## 2. Quy trình Thực hiện Workflow
1. **Phân chia Thẻ Chức năng Rõ ràng**:
   - Giao diện Cư dân: Tổng quan, Hóa đơn, Phản ánh, Tài khoản.
   - Giao diện Ban Quản lý: Tổng quan, Cư dân, Hóa đơn, Phản ánh.
2. **Cấu hình Trải nghiệm Người dùng**:
   - Tất cả các thẻ nội dung (Card) và thông báo phải tự động xuống dòng (word-wrap) và co giãn chiều cao theo độ dài văn bản. Không sử dụng chiều cao cứng (fixed height).
   - Đảm bảo hiển thị tốt trên cả màn hình điện thoại nhỏ và máy tính bảng.
   - Nút thao tác phải tự động vô hiệu hóa nếu dữ liệu chưa hợp lệ và mở khóa khi đã điền đầy đủ.

## 3. Danh sách Kiểm tra trước khi Nghiệm thu
- [ ] Tất cả nhãn, tiêu đề, nút bấm và văn bản là tiếng Việt chuẩn.
- [ ] Không có từ tiếng Anh trong ngoặc đơn.
- [ ] Không chứa biểu tượng cảm xúc.
- [ ] Giao diện tự co giãn (wrap), văn bản dài không bị che khuất.
- [ ] Màu sắc và Font chữ tuân thủ tuyệt đối theo `theme_spec.md`.
