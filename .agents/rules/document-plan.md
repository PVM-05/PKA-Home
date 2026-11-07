---
trigger: always_on
---

# Kế Hoạch Tài Liệu Kỹ Thuật & Vận Hành Chuẩn (Production Commercial SaaS)

PKA-Home là sản phẩm thương mại B2B SaaS phục vụ vận hành thực tế tại các tòa nhà/chuỗi căn hộ với người dùng thật và hướng tới bán thương mại. Toàn bộ tài liệu kỹ thuật, vận hành và triển khai phải được chuẩn hóa theo tiêu chuẩn công nghiệp:

| STT | Tên Tài Liệu | Nội Dung Chính | Thời Điểm Thực Hiện |
| :--- | :--- | :--- | :--- |
| 1 | **Đặc Tả Sản Phẩm & Nghiệp Vụ (PRD & SRS)** | Mục tiêu thương mại, phạm vi B2B SaaS đa cơ sở, phân loại đối tượng (BQL, Chủ nhà, Kế toán, Kỹ thuật, Cư dân, Khách thuê), use cases chi tiết. | Trước khi triển khai tính năng |
| 2 | **Kiến Trúc Kỹ Thuật & An Ninh (Architecture & Security Spec)** | Kiến trúc Clean Architecture, Feature-First, Riverpod Reactive State, Supabase Realtime CDC, Tenant Isolation, tuân thủ Luật Bảo vệ dữ liệu cá nhân & Luật Nhà ở. | Trước khi code |
| 3 | **Đặc Tả Cơ Sở Dữ Liệu & Hợp Đồng API/RPC** | Chi tiết bảng, quan hệ ERD, RLS Policies đa tầng, danh mục 10+ ACID RPCs, strongly-typed DTO contracts và audit logs. | Song song lúc code backend |
| 4 | **Quy Trình Vận Hành Chuẩn (SOP)** | Bộ quy chuẩn thao tác cho Ban Quản Lý (thu phí VietQR, cấp quyền xe, điều phối sự cố, quản lý quỹ bảo trì) và cẩm nang cư dân. | Khi hoàn thiện module |
| 5 | **Bộ Kịch Bản Kiểm Thử & Đảm Bảo Chất Lượng (QA & Audit)** | Danh mục test case tự động (Unit, Widget, Contract, Security RLS), kịch bản UAT nghiệm thu thực tế, CI/CD pipeline quality gate. | TDD: viết test song hành |
| 6 | **Sổ Tay Triển Khai & Onboarding Khách Hàng (Deployment Playbook)** | Hướng dẫn khởi tạo tổ chức/tòa nhà mới, bộ template Excel import dữ liệu căn hộ & cư dân, quy trình bàn giao tài khoản. | Khi đóng gói phiên bản bàn giao |
| 7 | **Hồ Sơ Đề Xuất Giải Pháp & Pitch Deck Thương Mại** | Bản giới thiệu giải pháp PropTech, ma trận tính năng so sánh thị trường, bảng giá SaaS theo quy mô căn hộ, phân tích ROI cho BQL. | Phục vụ kinh doanh & bán hàng |

**Công Cụ Chuẩn Hóa:**
- Sơ đồ Kiến trúc & Luồng dữ liệu: `Mermaid`, `draw.io`, `PlantUML`
- Wireframe / UI Design: `Figma`
- Cơ sở dữ liệu: `dbdiagram.io` (DBML) & Supabase Migrations
- Quản lý chất lượng & Test Suite: `Flutter Test`, `Mocktail`, `GitHub Actions CI`
