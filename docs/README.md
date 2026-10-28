# PKA-Home — Nền Tảng Quản Trị & Vận Hành Bất Động Sản Toàn Diện

> **PKA-Home** là giải pháp phần mềm quản lý bất động sản thế hệ mới (PropTech SaaS), được thiết kế tối ưu cho cả **Khu Căn Hộ / Chung Cư Cao Tầng** lẫn **Hệ Thống Nhà Trọ / Căn Hộ Dịch Vụ Cho Thuê Đa Cơ Sở**. Hệ thống kết nối trực tiếp Ban Quản Lý (hoặc Chủ nhà) với Cư Dân (hoặc Người thuê) với độ trễ tối thiểu, dữ liệu đồng bộ thời gian thực (Supabase Realtime CDC), bảo mật dữ liệu đa tầng (PostgreSQL RLS) và giao diện trực quan 100% tiếng Việt chuẩn mực.

---

## 📚 Danh Mục Tài Liệu Kỹ Thuật & Vận Hành Sản Phẩm

Hệ thống tài liệu chính thức của PKA-Home được chuẩn hóa theo chuẩn công nghiệp, chia thành các phần chuyên biệt:

| STT | Tài liệu | Mô tả nội dung | Đường dẫn |
| :--- | :--- | :--- | :--- |
| 1 | **Đặc Tả Tính Năng Sản Phẩm (Product Spec)** | Toàn bộ chức năng nghiệp vụ cho Cư Dân, Ban Quản Lý, Chủ Nhà Trọ, Kế Toán và Kỹ Thuật Viên. | [PRODUCT_SPECIFICATION.md](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/PRODUCT_SPECIFICATION.md) |
| 2 | **Kiến Trúc Kỹ Thuật (Architecture)** | Kiến trúc Clean Architecture, Feature-First, Riverpod Reactive State, Supabase Realtime CDC, Resilience & Error Handling. | [ARCHITECTURE.md](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/ARCHITECTURE.md) |
| 3 | **Đặc Tả Cơ Sở Dữ Liệu (Database Schema)** | 16 bảng CSDL, Mô hình Đa Cơ Sở (Multi-Tenancy), Quỹ Bảo Trì, RLS Policies, Indexes và Triggers Tự Động Hóa. | [DATABASE_SCHEMA.md](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/DATABASE_SCHEMA.md) |
| 4 | **Danh Mục API & RPC Stored Procedures** | Hợp đồng giao tiếp (Contract) giữa Client và Backend, 10 RPCs giao dịch nguyên tử (ACID), tham số vào/ra và rollback. | [API_AND_RPC.md](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/API_AND_RPC.md) |
| 5 | **Quy Trình Bàn Giao & Vận Hành** | Hướng dẫn Onboarding cơ sở mới, đặc tả 6 Sheet Excel import dữ liệu, quy trình nạp SQL, checklist nghiệm thu UAT. | [BAN_GIAO_VAN_HANH.md](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/BAN_GIAO_VAN_HANH.md) |
| 6 | **Kiểm Thử & Đảm Bảo Chất Lượng (QA & Testing)** | Chiến lược kiểm thử tự động (TDD), 489 test cases (Unit, Widget, Provider, Integration, RLS Security) và Linter Quality Gate. | [TESTING_AND_QA.md](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/TESTING_AND_QA.md) |

---

## 📂 Kho Lưu Trữ Lịch Sử (Archive)

Các tài liệu học thuật ban đầu phục vụ báo cáo đồ án tốt nghiệp và nhật ký các sprint trước đây đã được đóng gói và lưu trữ an toàn:
- **Tài liệu đồ án tốt nghiệp:** [`docs/archive/capstone_project/`](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/archive/capstone_project) (Bao gồm Báo cáo chính thức `.docx`, Slide `.pptx`, Diagram generator scripts, SRS và Wireframes ban đầu).
- **Kế hoạch Sprint lịch sử:** [`docs/archive/sprint_plans/`](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/archive/sprint_plans) (Hơn 90 file spec và plan của các giai đoạn phát triển từ Sprint 1 đến Phase E2).

---

## 🚀 Điểm Nhấn Công Nghệ Sản Phẩm

1. **Kiến Trúc Đa Cơ Sở (Multi-Tenancy by Design):** Cho phép một đơn vị vận hành quản lý đồng thời nhiều tòa nhà chung cư hoặc chuỗi nhiều dãy phòng trọ rải rác trên một nền tảng duy nhất, phân tách dữ liệu tuyệt đối theo `organization_id` và `building_id`.
2. **Đối Soát & Thanh Toán VietQR Tự Động:** Tích hợp sinh mã VietQR động theo chuẩn Napas 247, gán mã hóa đơn và định danh người nộp tiền, hỗ trợ đối soát kế toán và ghi sổ cái Quỹ Bảo Trì tự động.
3. **Cơ Chế Triggers & Realtime Dispatcher:** 4 Database Triggers tự động phát hành thông báo khi có hóa đơn, sự cố, duyệt phòng hoặc thanh toán. Supabase Realtime CDC bắt sự kiện tức thời và phát banner Heads-up rung/chuông ngay trên máy người dùng.
4. **Độ Bền Vững & Chịu Lỗi (Offline-First & Resilience):** Hỗ trợ cơ chế Fallback HTTP khi WebSocket Realtime chập chờn, tự động tái kết nối, bộ lọc trùng lặp thông báo (`_seenNotificationIds`), ngăn chặn rò rỉ bộ nhớ.
