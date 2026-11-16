# Nhật Ký Thay Đổi (Changelog)

Tất cả các thay đổi đáng chú ý của dự án **PKA-Home - Nền Tảng Quản Lý Vận Hành Bất Động Sản & Chung Cư Thương Mại (Commercial PropTech SaaS)** sẽ được ghi chép tại tài liệu này.

Định dạng tuân thủ tiêu chuẩn [Keep a Changelog](https://keepachangelog.com/vi/1.0.0/) và quy tắc đánh số phiên bản [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.1.2] - 2026-11-16

### Đã sửa (Fixed) - Cách ly Bí mật Thanh toán & Khắc phục Lỗ hổng Cross-Tenant Spoofing
- **Cách ly Khóa Bí mật Bảng riêng (`building_payment_secrets`)**: Tạo bảng riêng biệt có RLS khắt khe chỉ cho phép `service_role` và `admin` truy cập. Xóa bỏ vĩnh viễn cột `sepay_api_key` và `vnpay_hash_secret` khỏi bảng công khai `building_payment_configs`, ngăn chặn triệt để nguy cơ cư dân đọc trộm khóa qua API.
- **Xoay vòng Khóa Bí mật (Secret Rotation)**: Tự động đổi toàn bộ khóa API SePay cũ đã từng bị lộ sáng qua cơ chế băm ngẫu nhiên bảo mật (`sec_pka_*`).
- **Thẩm định Webhook Ràng buộc Tòa nhà (Tenant-Scoped Verification)**: Nâng cấp hàm RPC `process_sepay_webhook`, đối chiếu khóa API bắt buộc theo đúng tòa nhà của hóa đơn (`invoice_building_id`), loại bỏ hoàn toàn khả năng dùng khóa của tòa nhà A để gạch nợ hóa đơn tòa nhà B.
- **Thẩm định Tài khoản Ngân hàng Thụ hưởng**: Với giao dịch `UNMATCHED`, RPC tự động tra cứu số tài khoản nhận tiền và chỉ chấp nhận khi API Key khớp với đúng tòa nhà sở hữu tài khoản.

---

## [2.1.1] - 2026-11-16

### Đã thêm (Added) - Kích hoạt PDPL & Gia cố Bảo mật SePay Webhook
- **Kích hoạt Hộp thoại Chấp thuận PDPL (Consent Modal)**: Tự động kích hoạt `PdplConsentDialog` khi mở ứng dụng lần đầu tại `ResidentHomeScreen`, `ManagementHomeScreen` và shell điều hướng `_ResidentShellWrapper` theo Luật 91/2025/QH15 & NĐ 356/2025/NĐ-CP.
- **Minh bạch Quyền Chủ thể Dữ liệu**: Bổ sung mục "Thỏa thuận xử lý dữ liệu (Consent)" trong màn hình Hồ sơ cư dân (`ResidentProfileScreen`), cho phép xem lại toàn văn phạm vi thu thập và con dấu thời gian chấp thuận (`isReviewMode: true`), loại bỏ hoàn toàn import chết.
- **Bảo mật 2 Lớp SePay Webhook**:
  - Lớp vành đai Edge Function: Bắt buộc xác thực API key từ Authorization header hoặc query param, trả về `HTTP 401 Unauthorized` nếu không hợp lệ.
  - Lớp Database RPC: Hàm `process_sepay_webhook` đối chiếu bắt buộc `p_api_key` với `building_payment_configs.sepay_api_key`, ghi nhận audit log `SEPAY_WEBHOOK_UNAUTHORIZED` và từ chối giao dịch nếu vi phạm. Thu hồi quyền thực thi từ public/anon, chỉ cấp quyền cho `service_role`.
- **Chuẩn hóa Tài liệu B2B SaaS**: Viết lại toàn diện `README.md` theo chuẩn thương mại B2B SaaS PropTech Platform và công bố lộ trình phát triển mở rộng (Roadmap).

---

## [2.1.0] - 2026-11-15

### Đã thay đổi (Changed) - Kiên cố hóa Enterprise Fail-Closed
- **Loại bỏ 100% Mock Fallback ngầm**: Dọn sạch toàn bộ dữ liệu mẫu trong 9 Repositories (`community`, `front_desk`, `parking`, `material`, `handover`, `resident_lifecycle`, `batch_import`, `debt_prediction`, `resident_activation`). Mọi truy vấn khi mất kết nối máy chủ đều chuyển sang cơ chế **Fail-Closed** an toàn (`FailClosedGuard` / `AppException`), ngăn chặn triệt để tình trạng hiển thị nhầm dữ liệu giả lập cho người dùng thật.
- **Xóa bỏ vĩnh viễn dữ liệu giả định danh**: Loại bỏ các hồ sơ cư dân hardcode ("Nguyễn Văn An – 0901234567 – A0110 – nợ 7.850.000đ", vé xe `vp-mock-01`, bưu kiện `pcl-mock-01`).
- **Độc lập hóa Test Fakes**: Tách toàn bộ mock/fake phục vụ kiểm thử tích hợp luồng nghiệp vụ sang `test/helpers/test_workflow_fakes.dart`, giữ cho thư mục mã nguồn sản phẩm (`lib/`) hoàn toàn tinh sạch.

### Đã thêm (Added) - Pháp chế & Sẵn sàng Nghiệm thu Thương mại
- **Hồ sơ Pháp chế PDPL 2026**: Ban hành `docs/PRIVACY_POLICY.md` tuân thủ nghiêm ngặt Luật Bảo vệ dữ liệu cá nhân số 91/2025/QH15 và Nghị định số 356/2025/NĐ-CP. Quy định minh bạch cơ chế xử lý dữ liệu cư dân, dữ liệu xe, công tơ và biện pháp bảo mật đa tầng.
- **Điều khoản Dịch vụ SaaS**: Ban hành `docs/TERMS_OF_SERVICE.md` chuẩn hóa hợp đồng dịch vụ B2B SaaS giữa đơn vị vận hành PKA-Home và Ban Quản Lý/Chủ sở hữu tòa nhà.
- **Ma trận Kiểm thử Nghiệm thu Thực tế (UAT Matrix)**: Tích hợp 8 kịch bản nghiệm thu thực tế chi tiết từng bước (UAT-01 đến UAT-08) kèm tiêu chí chấp thuận (Acceptance Criteria) vào `docs/BAN_GIAO_VAN_HANH.md`.

---

## [2.0.0] - 2026-11-06

### Đã thêm (Added)
- **Kiến trúc Clean Architecture & Feature-First**: Tái cấu trúc toàn bộ dự án theo hướng module hóa nghiệp vụ cư dân (`features/resident`) và ban quản lý (`features/management`).
- **Kiểm soát Quyền Hạn Đa Tầng (RBAC UI + RLS)**: Triển khai widget bảo vệ `RoleGuard` ở tầng giao diện và kích hoạt Row Level Security (RLS) bảo vệ từng hàng dữ liệu ở tầng Supabase PostgreSQL.
- **Bảo mật Xác thực Cư dân Lần đầu**: Luồng kích hoạt tài khoản an toàn 4 bước (Nhập SĐT + Mã kích hoạt -> Nhận OTP -> Xác thực OTP -> Thiết lập mật khẩu và liên kết Auth).

---

## [1.5.0] - 2026-10-25

### Đã thêm (Added)
- **Kế toán & Sổ cái Kép (Double-Entry Ledger)**: Quản lý bút toán tài chính, hóa đơn điều chỉnh (Credit Note), báo cáo phân tích tuổi nợ (Aging Report 0-30-60-90+ ngày).
- **Quỹ Bảo Trì 2% Độc Lập**: Tách riêng sổ cái quỹ bảo trì theo quy định pháp luật; cơ chế duyệt chi đa cấp khi vượt hạn mức thẩm quyền.
- **Quản lý Vật tư & SLA Bảo trì**: Theo dõi nhập-xuất-tồn linh kiện sửa chữa, tự động trừ kho khi kỹ thuật viên hoàn thành phiếu xử lý sự cố.

---

## [1.2.0] - 2026-10-15

### Đã thêm (Added)
- **Biểu quyết Điện tử Chuẩn Luật Nhà ở 2023**: Cơ chế biểu quyết tính quyền biểu quyết theo diện tích sở hữu riêng ($m^2$) hoặc đầu căn hộ.
- **Trạm Lễ Tân Số Hóa (Front Desk Workstation)**:
  - Cấp mã khách thăm QR động kèm PIN bảo mật 6 số chống làm giả hoặc dùng lại.
  - Quản lý bưu kiện cư dân (nhận hàng, thông báo realtime, trả kiện đối soát bằng mã PIN).
- **Hệ thống Vé Xe Vãng Lai Thông Minh**: Quản lý ra vào bãi đỗ, tính cước lũy tiến theo khung giờ ban ngày/ban đêm.

---

## [1.0.0] - 2026-10-01

### Phiên bản Khởi tạo (Initial Release)
- Quản lý danh mục căn hộ (chuẩn mã định danh Block + Tầng 2 số + Phòng 2 số, VD: `A0110`).
- Quản lý hồ sơ cư dân và mối quan hệ lưu trú.
- Lập hóa đơn chi phí hàng tháng (điện, nước bậc thang EVN, phí quản lý, phí gửi xe).
- Tích hợp cổng thanh toán VietQR chuyển khoản tự động.
- Tiếp nhận và theo dõi tiến độ xử lý phản ánh kiến nghị của cư dân.

