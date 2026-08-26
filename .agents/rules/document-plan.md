---
trigger: always_on
---

# Kế Hoạch Tài Liệu Dự Án (Đồ án liên ngành)

Dự án này yêu cầu chuẩn bị đầy đủ bộ tài liệu quản lý và kỹ thuật phục vụ việc bảo vệ đồ án. Dưới đây là danh sách tài liệu và mốc thời gian thực hiện:

| STT | Tên Tài Liệu | Nội Dung Chính | Thời Điểm Thực Hiện |
| :--- | :--- | :--- | :--- |
| 1 | **Đặc tả yêu cầu (SRS)** | Mục tiêu, phạm vi, yêu cầu chức năng/phi chức năng, danh sách actor (cư dân, ban quản lý), use case list. | Trước khi code |
| 2 | **Thiết kế hệ thống** | Kiến trúc tổng thể (Flutter-Supabase), sơ đồ ERD, sơ đồ luồng dữ liệu, wireframe/mockup màn hình chính. | Trước khi code |
| 3 | **Tài liệu CSDL & API** | Chi tiết từng bảng, kiểu dữ liệu, ràng buộc, RLS policy, danh sách Supabase query/RPC dùng. | Song song lúc code backend |
| 4 | **Kế hoạch dự án (WBS)** | Chia công việc theo tuần/sprint, phân công, mốc bàn giao, rủi ro dự kiến. | Đầu dự án, cập nhật định kỳ |
| 5 | **Tài liệu kiểm thử** | Danh sách test case theo chức năng, kịch bản test RLS (đảm bảo bảo mật truy cập). | Sau khi hoàn thành từng module |
| 6 | **Hướng dẫn sử dụng** | Hướng dẫn thao tác cho cư dân và ban quản lý, kèm ảnh chụp màn hình. | Gần cuối, khi UI ổn định |
| 7 | **Báo cáo đồ án cuối kỳ** | Tổng hợp: mục tiêu, quá trình, kết quả, khó khăn/giải pháp, hướng phát triển. | Cuối dự án |
| 8 | **Slide bảo vệ đồ án** | Tóm tắt trực quan từ báo cáo, demo flow chính. | Cuối dự án |

**Gợi ý Công Cụ:**
- ERD: `dbdiagram.io` hoặc `draw.io`
- Wireframe/Mockup: `Figma`
- WBS (Kế hoạch): Bảng `Excel` hoặc `Notion`
