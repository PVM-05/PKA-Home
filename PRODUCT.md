# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Stack

Flutter 3.x, Dart 3.x, Riverpod 2.6, Supabase, PostgreSQL RLS, Printing / PDF

## Users

1. **Ban Quản Lý & Điều Hành Tòa Nhà (Property Managers & Operators)**: Giám sát tổng thể hoạt động tòa nhà, duyệt thành viên căn hộ, điều phối sự cố, quản lý bãi đỗ xe và truyền thông nội khu trên màn hình Web Desktop & Tablet.
2. **Kế Toán & Thu Ngân (Accountants & Finance Staff)**: Lập biểu phí, phát hành hóa đơn tự động, kiểm soát dòng tiền, xuất hóa đơn điện tử, đối soát thanh toán VietQR động và quản lý quỹ bảo trì 2%.
3. **Kỹ Thuật Viên Hiện Trường (On-site Technicians & Inspectors)**: Sử dụng thiết bị di động chốt chỉ số công tơ điện nước định kỳ, kiểm kê tài sản bàn giao căn hộ (move-in / move-out), tiếp nhận và xử lý sự cố cư dân.
4. **Cư Dân & Chủ Căn Hộ (Apartment Owners & Residents)**: Tiếp cận dịch vụ số, thanh toán phí sinh hoạt không tiền mặt một chạm qua VietQR, gửi phản ánh sự cố kèm hình ảnh, đăng ký vé xe và thẻ khách.
5. **Khách Thuê & Khách Thăm (Tenants & Visitors)**: Ký biên bản bàn giao kiểm kê kỹ thuật số, nhận thông tin vận hành từ BQL.

## Product Purpose

PKA-Home là nền tảng thương mại **B2B SaaS & PropTech Platform** toàn diện phục vụ quản lý, vận hành và số hóa trải nghiệm cư dân tại các chung cư, cụm nhà cao tầng và khu đô thị thông minh tại Việt Nam. Sản phẩm giải quyết triệt để các bài toán thực tế: thất thoát chỉ số điện nước, chậm trễ thu phí quản lý, tắc nghẽn xử lý phản ánh sự cố và rủi ro tranh chấp tài sản bàn giao.

## Positioning

Sản phẩm thương mại PropTech thế hệ mới tuân thủ nghiêm ngặt khung pháp lý Việt Nam (Luật Bảo vệ Dữ liệu Cá nhân 2026, Luật Nhà ở 2023, Nghị định Hóa đơn Điện tử), trang bị cơ chế bảo mật đa tầng Tenant Isolation qua PostgreSQL Row Level Security (RLS) bất biến, hỗ trợ đồng bộ thời gian thực (Supabase CDC Realtime) và tự động hóa toàn trình thu phí VietQR chuẩn NAPAS 24/7.

## Operating Context

- **Hiện trường di động (Field Mobile)**: Kỹ thuật viên di chuyển giữa các tầng và căn hộ ghi chỉ số, chụp ảnh tài sản trên thiết bị màn hình nhỏ, cần giao diện co giãn an toàn tuyệt đối (Anti-RenderFlex Guarantee).
- **Trạm làm việc Ban Quản Lý (Enterprise Web Workstation)**: Lễ tân, BQL và Kế toán làm việc trên màn hình lớn ($\ge 900$dp đến 1920dp) cần bố cục Split-Screen đa cột, Executive KPI Bar tổng quan, bảng dữ liệu mật độ cao.
- **Ứng dụng cư dân gia đình (Resident App)**: Giao diện trực quan, thân thiện, rõ ràng, 100% tiếng Việt chuẩn mực, hỗ trợ người cao tuổi với khả năng co giãn cỡ chữ tự do (Text Scale 1.3x - 1.5x).

## Capabilities and Constraints

- **Chuẩn hóa ngôn ngữ**: 100% Tiếng Việt chuẩn mực SaaS B2B. Cho phép các thuật ngữ kỹ thuật/quốc tế thông dụng (Hotline, Email, VietQR, App, Wifi). Tuyệt đối không dùng từ tiếng Anh trong ngoặc đơn để giải nghĩa.
- **Quy tắc hiển thị**: Tuyệt đối không sử dụng biểu tượng cảm xúc (emoji) trong giao diện nghiệp vụ.
- **Định dạng căn hộ chuẩn**: Cấu trúc chuẩn `A0110` (Block + Tầng 2 số + Phòng 2 số) trên toàn bộ hệ thống.
- **Cam kết Anti-RenderFlex**: Không bao giờ xảy ra lỗi tràn viền (RenderFlex overflow) trên bất kỳ kích thước màn hình nào từ 320dp x 600dp (kèm text scale 1.3x) đến 1920dp x 1080dp.
- **Git Workflow**: Toàn bộ thay đổi commit trực tiếp vào nhánh `main`.

## Brand Commitments

- **Thương hiệu**: PKA-Home - Vận hành Thông minh, An cư Thịnh vượng.
- **Hình ảnh**: Chuyên nghiệp, tin cậy, sắc nét, hiện đại, mang đẳng cấp quốc tế nhưng gắn chặt với chuẩn mực văn hóa và nghiệp vụ Việt Nam.

## Product Principles

1. **Impeccable Visual Hierarchy**: Không AI-slop, phân cấp thị giác sắc nét, sử dụng bảng màu thương hiệu có chủ đích (`AppTheme.sapphire`, `AppTheme.slate900`), viền thẻ mỏng mờ tinh tế (`AppCard`).
2. **Absolute Responsive Guarantee**: Mọi màn hình co giãn mượt mà theo `LayoutBuilder`, `Wrap`, `Expanded`/`Flexible`, tự động chuyển đổi giữa Mobile Single-Column và Web Desktop Multi-Column Workstation.
3. **Data Integrity & Security**: Bảo mật RLS cấp cơ sở dữ liệu, phân quyền vai trò (BQL, Kế toán, Kỹ thuật, Cư dân) triệt để và minh bạch nhật ký kiểm toán (Audit Trail).
4. **Frictionless Operations**: Tối ưu từng cú chạm của người dùng thật, thao tác ký điện tử tại chỗ, xuất PDF biên bản tức thì.

