# Vivona — Hệ Thống Tài Liệu Kỹ Thuật, Vận Hành & Thương Mại Hóa (Commercial B2B SaaS)

> **Vivona** là nền tảng phần mềm thương mại quản trị & vận hành bất động sản thế hệ mới (**Commercial Production PropTech B2B SaaS**), phục vụ Ban Quản Lý tòa nhà, Chủ đầu tư, Đơn vị vận hành, Kế toán, Kỹ thuật viên, Lễ tân/An ninh, Cư dân và Khách thuê trên quy mô đa cơ sở (Multi-Tenant).

---

## 1. Danh Mục Tài Liệu Chuẩn Công Nghiệp (Production Documentation Suite)

Toàn bộ tài liệu dự án được quy hoạch tinh gọn theo 7 nhóm chuẩn B2B SaaS (không lưu trữ tài liệu nháp hay báo cáo học thuật cũ):

| STT | Phân nhóm | Tài liệu | Nội dung cốt lõi |
| :---: | :--- | :--- | :--- |
| 1 | **Sản phẩm & Nghiệp vụ** | [PRODUCT_SPECIFICATION.md](file:///c:/Users/ADMIN/StudioProjects/Vivona/docs/PRODUCT_SPECIFICATION.md) | Đặc tả PRD & SRS thương mại cho 7 vai trò người dùng trên Mobile & Web Workstation. |
| 2 | **Lộ trình & Thương mại** | [COMMERCIAL_PRODUCT_ROADMAP.md](file:///c:/Users/ADMIN/StudioProjects/Vivona/docs/COMMERCIAL_PRODUCT_ROADMAP.md) | Lộ trình phát triển sản phẩm thương mại hóa B2B SaaS. |
| 3 | **Hồ sơ Đề xuất B2B** | [PITCH_DECK_PROPOSAL.md](file:///c:/Users/ADMIN/StudioProjects/Vivona/docs/PITCH_DECK_PROPOSAL.md) | Hồ sơ giới thiệu giải pháp PropTech, ma trận tính năng, bảng giá SaaS & phân tích ROI. |
| 4 | **Kiến trúc & Bảo mật** | [ARCHITECTURE.md](file:///c:/Users/ADMIN/StudioProjects/Vivona/docs/ARCHITECTURE.md) | Clean Architecture, Feature-First, Riverpod Reactive State, Offline Sync, Multi-Tenant Security. |
| 5 | **Cơ sở dữ liệu & ERD** | [DATABASE_SCHEMA.md](file:///c:/Users/ADMIN/StudioProjects/Vivona/docs/DATABASE_SCHEMA.md) / [ERD.dbml](file:///c:/Users/ADMIN/StudioProjects/Vivona/docs/ERD.dbml) | Đặc tả lược đồ PostgreSQL đa cơ sở (`organizations` -> `buildings` -> `apartments`), Indexes & Triggers. |
| 6 | **Hợp đồng API & RPC** | [API_AND_RPC.md](file:///c:/Users/ADMIN/StudioProjects/Vivona/docs/API_AND_RPC.md) | Danh mục 25+ Stored Procedures (ACID RPCs) và 4 Supabase Edge Functions (`create-vnpay-url`, `vnpay-ipn`, `sepay-webhook`, `send-fcm-notification`). |
| 7 | **Chính sách RLS Đa tầng** | [RLS-policy.md](file:///c:/Users/ADMIN/StudioProjects/Vivona/docs/RLS-policy.md) | Đặc tả Row Level Security cách ly theo `building_id`/`organization_id`, cổng MFA AAL2 (`is_super_admin`, `is_building_staff`). |
| 8 | **An ninh Khóa & Bí mật** | [security/SUPABASE_KEY_ROTATION.md](file:///c:/Users/ADMIN/StudioProjects/Vivona/docs/security/SUPABASE_KEY_ROTATION.md) | Quy trình bảo mật và xoay vòng khóa Supabase, `building_payment_secrets`, SePay & VNPay. |
| 9 | **SOP Vận hành Ban Quản Lý** | [QUY_TRINH_VAN_HANH_BQL_SOP.md](file:///c:/Users/ADMIN/StudioProjects/Vivona/docs/QUY_TRINH_VAN_HANH_BQL_SOP.md) | Quy trình thao tác chuẩn hàng ngày cho Ban Quản Lý, Kế toán, Kỹ thuật viên và Lễ tân. |
| 10 | **Bàn giao Vận hành Chung cư** | [BAN_GIAO_VAN_HANH.md](file:///c:/Users/ADMIN/StudioProjects/Vivona/docs/BAN_GIAO_VAN_HANH.md) | Hướng dẫn khởi tạo tòa nhà, cấu trúc Excel import hàng loạt và nghiệm thu vận hành. |
| 11 | **Vận hành Chuỗi Nhà trọ / CHDV** | [BAN_GIAO_PHONG_TRO.md](file:///c:/Users/ADMIN/StudioProjects/Vivona/docs/BAN_GIAO_PHONG_TRO.md) | Hướng dẫn cấu hình biểu giá điện nước, hợp đồng thuê và bàn giao tài sản cho mô hình căn hộ dịch vụ. |
| 12 | **Tích hợp Thanh toán SePay** | [SEPAY_INTEGRATION_GUIDE.md](file:///c:/Users/ADMIN/StudioProjects/Vivona/docs/SEPAY_INTEGRATION_GUIDE.md) | Hướng dẫn kết nối VietQR động Napas 247 & Webhook gạch nợ tự động 24/7 qua SePay. |
| 13 | **Sổ tay Triển khai (Playbook)** | [DEPLOYMENT_PLAYBOOK.md](file:///c:/Users/ADMIN/StudioProjects/Vivona/docs/DEPLOYMENT_PLAYBOOK.md) | Quy trình đóng gói, cấu hình biến môi trường (`--dart-define`) và triển khai đa nền tảng. |
| 14 | **Runbook Migration Production** | [MIGRATION_DEPLOYMENT_RUNBOOK.md](file:///c:/Users/ADMIN/StudioProjects/Vivona/docs/MIGRATION_DEPLOYMENT_RUNBOOK.md) | Quy trình chuẩn đẩy 50 SQL Migrations & 4 Edge Functions lên Supabase Production (`vpgimjyyechhuofjghsb`). |
| 15 | **Kiểm thử & Đảm bảo Chất lượng** | [TESTING_AND_QA.md](file:///c:/Users/ADMIN/StudioProjects/Vivona/docs/TESTING_AND_QA.md) | Chiến lược TDD, `1,372+` automated test cases (Unit, Widget, Integration, Security RLS) và CI Quality Gate. |
| 16 | **Masterplan Thiết kế UI/UX** | [plans/2026-11-21-mobbin-redesign-masterplan.md](file:///c:/Users/ADMIN/StudioProjects/Vivona/docs/plans/2026-11-21-mobbin-redesign-masterplan.md) | Kiến trúc hệ thống giao diện 65/65 màn hình chuẩn SaaS 2026 (Zero Hardcoded Colors/FontSizes, Dark Mode, WCAG AA). |
| 17 | **Pháp lý & Bảo vệ Dữ liệu (PDPL)** | [PRIVACY_POLICY.md](file:///c:/Users/ADMIN/StudioProjects/Vivona/docs/PRIVACY_POLICY.md) / [TERMS_OF_SERVICE.md](file:///c:/Users/ADMIN/StudioProjects/Vivona/docs/TERMS_OF_SERVICE.md) | Chính sách bảo vệ dữ liệu cá nhân theo Luật 91/2025/QH15 & Nghị định 356/2025/NĐ-CP và Điều khoản sử dụng. |

---

## 2. Cấu Trúc Thư Mục `supabase/` Chuẩn Hóa

- **`supabase/migrations/`**: Chứa **50 tệp migration chính thức** định dạng chuẩn 14 chữ số (`20261027010000_baseline_schema.sql` → `20261127030000_harden_security_definer_rpcs_and_storage_rls.sql`), đồng bộ 1:1 với bảng `supabase_migrations.schema_migrations` trên Production (`vpgimjyyechhuofjghsb`). Toàn bộ các bản nháp pre-baseline cũ (`migrations_archive`) đã được loại bỏ sau khi hợp nhất hoàn chỉnh vào baseline và các đợt hardening.
- **`supabase/functions/`**: Chứa 4 Deno Edge Functions đang vận hành trên Production:
  - `create-vnpay-url`: Khởi tạo URL thanh toán VNPay 2.1.0 phía máy chủ (Server-Authoritative, Tenant-Scoped).
  - `vnpay-ipn`: Xác thực chữ ký số HMAC-SHA512 hằng thời gian và gạch nợ tự động chống Cross-Tenant Spoofing.
  - `sepay-webhook`: Tiếp nhận biến động số dư ngân hàng 24/7, cộng dồn thanh toán từng phần và tự động ghi Có tiền nộp thừa vào sổ cái.
  - `send-fcm-notification`: Điều phối thông báo đẩy Firebase HTTP v1 từ bản ghi xác thực trong CSDL.
- **`supabase/seed.sql` & `supabase/clean_data.sql`**: Kịch bản khởi tạo dữ liệu mẫu kiểm thử và làm sạch dữ liệu môi trường staging.
