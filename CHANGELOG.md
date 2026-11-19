# Nhật Ký Thay Đổi (Changelog)

Tất cả các thay đổi đáng chú ý của dự án **Vivona - Nền Tảng Quản Lý Vận Hành Bất Động Sản & Chung Cư Thương Mại (Commercial PropTech SaaS)** sẽ được ghi chép tại tài liệu này.

Định dạng tuân thủ tiêu chuẩn [Keep a Changelog](https://keepachangelog.com/vi/1.0.0/) và quy tắc đánh số phiên bản [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.2.0] - 2026-11-18

### Đã thêm (Added) - Hiện Đại Hóa Giao Diện UI 2026 & Cá Nhân Hóa Theo Ngữ Cảnh
- **Bento Grid & Motion Hiện Đại Cho Trang Chủ Cư Dân (`ResidentHomeScreen`)**: Bố cục thẻ trực quan theo phong cách Bento Grid hiện đại (Upcoming Invoice, Quick Actions, Announcements, Utility Chart, Services Section), tích hợp hiệu ứng chuyển cảnh mềm (`flutter_animate`), phản hồi xúc giác (`AppHaptics`) và co giãn responsive linh hoạt (< 380px tự động xếp dọc).
- **Hệ Thống Token Thiết Kế & Hiệu Ứng Kính Kỷ Nguyên Mới**: Bổ sung `AppSpacing`, `AppRadius`, hệ màu nhận diện phong phú (`sapphire`, `emerald`, `amethyst`, `coral`) và thành phần hiệu ứng kính cao cấp `AppGlassCard` tích hợp trên thanh khẩn cấp nổi (`StickyEmergencyBar`) và bộ chuyển căn hộ (`ApartmentSwitcherChip`).
- **Động Cơ Cá Nhân Hóa Ngữ Cảnh (`HomePersonalizationProvider`)**: Tự động nhận diện trạng thái căn hộ theo thời gian thực (hóa đơn sắp đến hạn/quá hạn, tiến độ phản ánh sự cố đang mở, cửa sổ khai báo chỉ số điện nước cuối chu kỳ) để ưu tiên thông tin cấp thiết nhất lên đầu màn hình.
- **Adaptive Master-Detail Layout Cho Tablet & Web**: Triển khai bố cục 2 cột thích ứng (`AdaptiveMasterDetailLayout`) trên màn hình Danh sách Hóa đơn (`ResidentInvoiceScreen`) và Danh sách Phản ánh (`ResidentIssueScreen`), giúp tối ưu không gian hiển thị trên màn hình lớn.
- **Hướng Dẫn Cư Dân Mới Lần Đầu (`ResidentOnboardingDialog`)**: Hộp thoại chào mừng và giới thiệu trực quan 4 trụ cột tiện ích số (Hóa đơn & VietQR, Báo cáo sự cố 24/7, Chỉ số điện nước AI, Cẩm nang & Tiện ích tòa nhà), lưu cờ SharedPreferences và tự động kích hoạt một lần duy nhất trên `ResidentHomeScreen`.
- **Hệ Thống Phản Hồi Chuẩn Hóa (`AppSnackBar`)**: Xây dựng thành phần `AppSnackBar` (`lib/core/widgets/app_snack_bar.dart`) đạt chuẩn Design System với giao diện floating, bo góc `AppRadius.shapeMd`, biểu tượng trực quan, haptics rung xúc giác tương ứng (`AppHaptics.light()`, `AppHaptics.medium()`), tự động xóa thông báo chồng chéo và tích hợp trực tiếp vào tiện ích chạy tác vụ an toàn `runAction`.
- **Bộ Kiểm Thử Toàn Diện UI 2026**: Bổ sung kiểm thử tự động, golden tests (`resident_home_screen_golden_test.dart`, `app_glass_card_test.dart`) và ghim phiên bản Flutter SDK CI 3.44.0 đảm bảo tính ổn định tuyệt đối của quy trình tích hợp liên tục.

### Đã sửa (Fixed) - Khắc Phục Triệt Để 5 Vấn Đề P1 UX & Toàn Bộ Hạng Mục Kiểm Toán (A1 - A7, A9) & Gói 1 Hardening
- **P0 Dữ Liệu Biểu Đồ Tiêu Thụ Điện Nước Thật**: Xóa bỏ toàn bộ mảng số liệu hardcode tĩnh; chuyển sang truy vấn chỉ số đo lường thực tế từ `meter_reading_submissions` theo từng căn hộ (`residentUtilityConsumptionHistoryProvider`), tự động tính toán chênh lệch % và ẩn thẻ an toàn khi dữ liệu chưa đủ 2 kỳ đo.
- **P1.1 Cơ Chế Phân Trang Cuộn Vô Hạn (Infinite Pagination)**: Triển khai phân trang `residentInvoicePaginatedProvider` và `residentIssuePaginatedProvider` theo kích thước 20 bản ghi/trang kèm trạng thái `loadMore` và `hasMore`, loại bỏ tải toàn bộ dữ liệu cục bộ gây nghẽn bộ nhớ.
- **P1.2 Bảo Vệ Dữ Liệu Chưa Lưu (Unsaved Changes Guard)**: Tích hợp `AppUnsavedChangesGuard` / `PopScope` trên màn hình tạo phản ánh sự cố (`CreateIssueScreen`), cảnh báo xác nhận khi người dùng vuốt back hoặc đóng màn hình lúc đã điền mô tả, đính kèm ảnh hoặc đổi danh mục/ưu tiên.
- **P1.3 / A1 Chuẩn Hóa Điều Hướng & Biểu Tượng Hóa Đơn**: Đổi biểu tượng nút thanh toán từ `Icons.qr_code_scanner` gây hiểu lầm sang `Icons.receipt_long_rounded` trên thẻ hóa đơn sắp tới, thể hiện chính xác hành động chuyển tab hóa đơn.
- **P1.4 / A2 Cuộn Tự Động Đến Trường Lỗi (Auto-Scroll Form Validation)**: Tích hợp `Scrollable.ensureVisible` tự động cuộn màn hình đến ô mô tả sự cố bị bỏ trống khi người dùng bấm nút gửi ở cuối form.
- **P1.5 Khắc Phục Chói Dark Mode Màn Hình Tra Cứu Tài Liệu (`DocumentLookupScreen`)**: Loại bỏ mã màu cứng nền xanh sáng (`Green 50`), đồng bộ bảng màu ngữ nghĩa `AppStatusColors` và `colorScheme` tương thích hoàn hảo chế độ sáng/tối theo tiêu chuẩn WCAG AA.
- **A3 Cập Nhật Launcher Icons Android**: Sinh mới bộ icon launcher qua `flutter_launcher_icons`, đồng bộ toàn bộ thư mục mật độ `android/app/src/main/res/mipmap-*` (`ic_launcher.png`, `launcher_icon.png`); giữ nguyên asset catalog hiện hữu cho iOS (`ios/Runner/Assets.xcassets/AppIcon.appiconset`).
- **A4 URL Ảnh Đồng Hồ Tương Thích Máy Chủ**: Sửa đổi `MeterReadingRepository.uploadMeterImage` để luôn sinh URL công khai từ Supabase Client đang cấu hình (`_client.storage.getPublicUrl`), xóa bỏ URL hardcode trỏ domain chưa đăng ký.
- **A7.1 Khử Trùng Callback & Haptic Kép**: Tách biệt luồng nhận sự kiện giữa `Bounceable` và `ElevatedButton` tại thẻ hóa đơn sắp tới qua `IgnorePointer`.
- **A7.2 Trạng Thái Lỗi Biểu Đồ Thân Thiện**: Bổ sung thẻ thông báo lỗi thu gọn kèm nút "Thử lại" khi gặp sự cố mạng, chấm dứt hiện tượng biểu đồ biến mất không lý do.
- **A7.4 Đồng Bộ Đặt Lại Phân Trang Khi Kéo Tải Lại (Pull-to-Refresh)**: Làm mới đồng thời cả danh sách phân trang và luồng stream tại màn hình Hóa đơn, Phản ánh và Trang chủ, đưa trạng thái về trang 1 nguyên bản.
- **A7.5 Hằng Số Hóa Cửa Sổ Khai Báo Chỉ Số**: Chuẩn hóa ngày mở cổng định kỳ vào `AppConstants.kMeterReadingWindowStartDay` (ngày 20) và chuỗi hướng dẫn dùng chung `kMeterReadingWindowScheduleDescription`.
- **A9 Phục Hồi Kiến Trúc Phân Trang Sự Cố Cư Dân (`residentIssueProvider`)**: Khắc phục lỗi hồi quy tải toàn bộ dữ liệu unpaginated; kết nối `residentIssueProvider` dẫn xuất trực tiếp từ `residentIssuePaginatedProvider` (20 bản ghi/trang), đồng bộ trạng thái khi gọi `loadMore()` cuộn vô hạn hoặc khi nhận dữ liệu từ Realtime Stream.
- **Gói 1.1 Cấu Hình Động Môi Trường Thanh Toán VNPay (Dynamic Sandbox)**: Loại bỏ hardcode `isSandbox: true` tại `UnifiedPaymentSheet`, tự động nhận diện `!AppEnvironment.current.isProduction` chuyển đổi máy chủ VNPay Production (`pay.vnpayment.vn`) và Sandbox (`sandbox.vnpayment.vn`).
- **Gói 1.2 Tối Ưu Bộ Đệm Ảnh & Shimmer Placeholder (`AppStorageImage`)**: Thay thế hoàn toàn spinner đơn điệu bằng `AppSkeletonShimmer.rectangular`, thêm bộ nhớ đệm URL và kích thước giải mã `cacheWidth`/`cacheHeight` tiết kiệm RAM khi duyệt ảnh chụp thực tế.
- **Gói 1.3 Phủ Skeleton Loader Toàn Diện Thay Thế Spinner Danh Sách**: Chuyển đổi các `CircularProgressIndicator` sang `AppSkeletonShimmer.cardList` tại các màn hình Ghi số điện nước (`ResidentMeterReadingScreen`), Quản lý xe cư dân (`VehicleManagementScreen`), Duyệt xe BQL (`VehicleApprovalScreen`), Quản lý căn hộ (`ApartmentManagementScreen`) và Quản lý thông báo (`AnnouncementManagementScreen`).
- **Gói 2.1 Chuẩn Hóa Typography Module Thông Báo & Loại Bỏ 54 Điểm `fontSize:` Cứng**:
  - `ResidentAnnouncementDetailScreen`: Xóa sạch 100% 16/16 điểm `fontSize:` cứng, chuyển đổi hoàn toàn sang `context.titleLarge`, `context.bodyMedium`, `context.labelSmall`, `context.bodySmall`...
  - `AnnouncementManagementScreen`: Xóa sạch 100% 38/38 điểm `fontSize:` cứng và chuyển đổi toàn bộ 6 lệnh gọi `ScaffoldMessenger.showSnackBar` phân tán sang `AppSnackBar.showSuccess` và `AppSnackBar.showError`.
  - Mở rộng Whitelist của Guardrail CI (`test/core/theme_and_color_guard_test.dart`) bảo vệ 3 file: `app_snack_bar.dart`, `announcement_management_screen.dart`, `resident_announcement_detail_screen.dart`. Đảm bảo 100% không tái xuất hiện `fontSize:` và `Color(0x...)` cứng.
- **Gói 2.2 Chuẩn Hóa Typography & Tokens Cụm Tiện Ích Đặt Chỗ (Amenity Module)**:
  - `AmenityManagementScreen`: Xóa sạch 100% 26/26 điểm `fontSize:` cứng và chuyển đổi toàn bộ 4 lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar.showSuccess` và `AppSnackBar.showError`.
  - `AmenityBookingScreen`: Xóa sạch 100% 26/26 điểm `fontSize:` cứng và chuyển đổi toàn bộ 6 lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar`.
  - `ResidentAmenityBookingsTab`: Xóa sạch 100% 12/12 điểm `fontSize:` cứng và 3 lệnh gọi `ScaffoldMessenger.showSnackBar`.
  - Mở rộng Whitelist của Guardrail CI (`test/core/theme_and_color_guard_test.dart`) bảo vệ thêm 3 file: `amenity_management_screen.dart`, `amenity_booking_screen.dart`, `resident_amenity_bookings_tab.dart`. Đảm bảo 100% không tái xuất hiện `fontSize:` và `Color(0x...)` cứng.
- **Gói 2.3 Chuẩn Hóa Typography & Tokens Phân Hệ Sự Cố & Bãi Xe (Issue & Parking System)**:
  - `CreateIssueScreen`: Xóa sạch 100% 20/20 điểm `fontSize:` cứng và thay thế 7 lệnh gọi `ScaffoldMessenger.showSnackBar` bằng `AppSnackBar` (Success, Error, Warning, Info).
  - `VehicleApprovalScreen`: Xóa sạch 100% 20/20 điểm `fontSize:` cứng và thay thế 4 lệnh gọi `ScaffoldMessenger.showSnackBar` bằng `AppSnackBar.showSuccess` và `AppSnackBar.showError`.
  - `ParkingManagementScreen`: Xóa sạch 100% 22/22 điểm `fontSize:` cứng và thay thế toàn bộ lệnh gọi `ScaffoldMessenger.showSnackBar` bằng `AppSnackBar.showError`.
  - Bổ sung phương thức `AppSnackBar.showWarning` đạt chuẩn Design System với biểu tượng cảnh báo và màu sắc `AppTheme.warning`.
  - Mở rộng Whitelist của Guardrail CI (`test/core/theme_and_color_guard_test.dart`) bảo vệ thêm 3 file: `create_issue_screen.dart`, `vehicle_approval_screen.dart`, `parking_management_screen.dart`.
  - Giảm thêm 62 điểm nợ `fontSize:` cứng toàn bộ phân hệ features (từ 818 xuống 756). Toàn bộ 4 guardrail tests và 11 widget tests tính năng đều vượt qua 100%.
- **Gói 2.4 Chuẩn Hóa Typography & Tokens Phân Hệ Tài Chính, Lập Hóa Đơn & Báo Cáo (Invoicing, Fee Policy & Financial Reports)**:
  - `CreateInvoiceScreen`: Xóa sạch 100% 21/21 điểm `fontSize:` cứng và chuyển đổi toàn bộ 5 lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar` (Success, Error, Warning).
  - `FeePolicyManagementScreen`: Xóa sạch 100% 22/22 điểm `fontSize:` cứng, chuyển đổi biểu giá 6 bậc EVN, định mức nước và pro-rata sang Design Tokens ngữ nghĩa.
  - `FinancialReportScreen`: Xóa sạch 100% 20/20 điểm `fontSize:` cứng và chuyển đổi toàn bộ 3 lệnh gọi `ScaffoldMessenger.showSnackBar` xuất Excel sang `AppSnackBar.showSuccess` và `AppSnackBar.showError`.
  - Mở rộng Whitelist của Guardrail CI (`test/core/theme_and_color_guard_test.dart`) bảo vệ thêm 3 file: `create_invoice_screen.dart`, `fee_policy_management_screen.dart`, `financial_report_screen.dart`.
  - Giảm thêm 63 điểm nợ `fontSize:` cứng toàn bộ phân hệ features (từ 756 xuống 693). Đưa tổng số điểm nợ typography được xóa bỏ lên 243 điểm qua 4 gói dọn dẹp. Toàn bộ 4 guardrail tests và 3 widget tests tính năng đều vượt qua 100%.
- **Gói 2.5 Chuẩn Hóa Typography & Tokens Phân Hệ Tiền Sảnh, Khách Thăm & Bàn Giao (Front Desk, Visitor Pass & Handover)**:
  - `FrontDeskWorkstationScreen`: Xóa sạch 100% 20/20 điểm `fontSize:` cứng và thay thế toàn bộ 3 lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar` (Success, Error).
  - `ResidentVisitorParcelScreen`: Xóa sạch 100% 20/20 điểm `fontSize:` cứng và thay thế lệnh gọi `ScaffoldMessenger.showSnackBar` sao chép PIN sang `AppSnackBar.showSuccess`.
  - `ResidentHandoverDetailScreen`: Xóa sạch 100% 20/20 điểm `fontSize:` cứng và thay thế toàn bộ 5 lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar` (Success, Error, Warning).
  - Mở rộng Whitelist của Guardrail CI (`test/core/theme_and_color_guard_test.dart`) bảo vệ thêm 3 file: `front_desk_workstation_screen.dart`, `resident_visitor_parcel_screen.dart`, `resident_handover_detail_screen.dart`.
  - Giảm thêm 60 điểm nợ `fontSize:` cứng toàn bộ phân hệ features (từ 690 xuống 630). Đưa tổng số điểm nợ typography được dọn sạch lên 306 điểm qua 5 gói dọn dẹp liên hoàn. Toàn bộ 4 guardrail tests và 4 screen widget tests đều vượt qua 100%.
- **Gói 2.6 Chuẩn Hóa Typography & Tokens Phân Hệ Kỹ Thuật, Thiết Bị & Bảo Trì (Equipment & Maintenance System)**:
  - `EquipmentDetailScreen`: Xóa sạch 100% 21/21 điểm `fontSize:` cứng, khắc phục triệt để nguy cơ RenderFlex overflow bằng `Expanded` responsive, và chuyển đổi toàn bộ 6 lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar` (Success, Error, Warning).
  - `EquipmentManagementScreen`: Xóa sạch 100% 16/16 điểm `fontSize:` cứng tại KPI cards, bộ lọc thiết bị, danh sách phiếu bảo trì và chuyển đổi 2 lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar.showSuccess` và `AppSnackBar.showError`.
  - `MaintenanceMaterialsScreen`: Xóa sạch 100% 15/15 điểm `fontSize:` cứng tại hộp thoại điều chỉnh kho, thẻ cảnh báo sắp hết và danh mục vật tư phụ tùng.
  - Mở rộng Whitelist của Guardrail CI (`test/core/theme_and_color_guard_test.dart`) bảo vệ thêm 3 file: `equipment_detail_screen.dart`, `equipment_management_screen.dart`, `maintenance_materials_screen.dart`.
  - Giảm thêm 52 điểm nợ `fontSize:` cứng toàn bộ phân hệ features (từ 630 xuống 578). Đưa tổng số điểm nợ typography được xóa bỏ lên 358 điểm qua 6 gói dọn dẹp liên hoàn. Toàn bộ 4 guardrail tests và 9 screen widget tests đều vượt qua 100%.
- **Gói 2.7 Chuẩn Hóa Typography & Tokens Phân Hệ Bảng Tin Cộng Đồng & Sổ Tay Cư Dân (Community & Handbook System)**:
  - `CommunityManagementScreen`: Xóa sạch 100% 19/19 điểm `fontSize:` cứng tại TabBar, KPI stats, thẻ khảo sát biểu quyết và thẻ kiến nghị cư dân.
  - `ResidentCommunityScreen`: Xóa sạch 100% 17/17 điểm `fontSize:` cứng và chuyển đổi toàn bộ 4 lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar.showSuccess` và `AppSnackBar.showError`.
  - `ResidentHandbookScreen`: Xóa sạch 100% 15/15 điểm `fontSize:` cứng tại thanh tìm kiếm, danh mục hotline khẩn cấp, quy chế tòa nhà, đặt lịch tiện ích và câu hỏi thường gặp FAQ, đồng thời chuyển đổi 2 lệnh gọi `ScaffoldMessenger` sang `AppSnackBar.showError`.
  - Mở rộng Whitelist của Guardrail CI (`test/core/theme_and_color_guard_test.dart`) bảo vệ thêm 3 file: `community_management_screen.dart`, `resident_community_screen.dart`, `resident_handbook_screen.dart`.
  - Giảm thêm 51 điểm nợ `fontSize:` cứng toàn bộ phân hệ features (từ 578 xuống 527). Đưa tổng số điểm nợ typography được xóa bỏ lên 409 điểm qua 7 gói dọn dẹp liên hoàn. Toàn bộ 4 guardrail tests và 10 screen widget tests đều vượt qua 100%.
- **Gói 2.8 Chuẩn Hóa Typography & Tokens Phân Hệ Nhập Liệu Hàng Loạt, Gói Thuê Bao B2B SaaS & Đánh Giá Dịch Vụ (Batch Import, SaaS Subscription & Service Rating)**:
  - `BatchImportCenterScreen`: Xóa sạch 100% 19/19 điểm `fontSize:` cứng tại các bước wizard import Excel, bảng preview dữ liệu căn hộ & cư dân, KPI số lượng dòng nạp; chuyển đổi toàn bộ 6 lệnh gọi `ScaffoldMessenger.showSnackBar` phân tán sang `AppSnackBar.showSuccess` và `AppSnackBar.showError`.
  - `SubscriptionManagementScreen`: Xóa sạch 100% 18/18 điểm `fontSize:` cứng tại thẻ gói dịch vụ SaaS hiện tại, bảng giá gói cước mở rộng, thước đo hạn mức quota; chuyển đổi toàn bộ 2 lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar`.
  - `ServiceRatingOverviewScreen`: Xóa sạch 100% 14/14 điểm `fontSize:` cứng tại điểm số CSAT trung bình, phân bổ đánh giá 1-5 sao và danh sách ý kiến phản hồi cư dân.
  - Mở rộng Whitelist của Guardrail CI (`test/core/theme_and_color_guard_test.dart`) bảo vệ thêm 3 file: `batch_import_center_screen.dart`, `subscription_management_screen.dart`, `service_rating_overview_screen.dart` (Module 16).
  - Giảm thêm 51 điểm nợ `fontSize:` cứng toàn bộ phân hệ features (từ 527 xuống 476, chính thức phá vỡ mốc 500 nợ). Đưa tổng số điểm nợ typography được xóa bỏ lên 460 điểm qua 8 gói dọn dẹp liên hoàn. Toàn bộ 4 guardrail tests và 8 screen widget tests đều vượt qua 100%.
- **Gói 2.9 Chuẩn Hóa Typography & Tokens Phân Hệ Kế Toán B2B Web, Sổ Cái Căn Hộ & Quỹ Bảo Trì 2% (Accounting Workstation, Apartment Ledger, Maintenance Fund Ledger & Edit Invoice)**:
  - `AccountingWebWorkstationScreen`: Xóa sạch 100% 14/14 điểm `fontSize:` cứng tại bàn làm việc kế toán, KPI dải thống kê, đối soát tự động SePay; chuyển đổi lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar.showSuccess`.
  - `ApartmentLedgerScreen`: Xóa sạch 100% 13/13 điểm `fontSize:` cứng tại thẻ tổng quan số dư công nợ căn hộ, danh sách bút toán Append-Only và thông tin trạng thái.
  - `MaintenanceFundLedgerScreen`: Xóa sạch 100% 12/12 điểm `fontSize:` cứng tại thẻ số dư quỹ khả dụng 2%, dải lãi suất tiền gửi ngân hàng, lịch sử giải ngân và chuyển đổi toàn bộ 5 lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar.showSuccess` và `AppSnackBar.showError`.
  - `EditInvoiceScreen`: Xóa sạch 100% 11/11 điểm `fontSize:` cứng tại hộp thoại điều chỉnh chi tiết khoản phí, tổng cộng mới, nút lưu thay đổi và chuyển đổi toàn bộ 6 lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar` (Success, Error, Warning).
  - Mở rộng Whitelist của Guardrail CI (`test/core/theme_and_color_guard_test.dart`) bảo vệ thêm 4 file: `accounting_web_workstation_screen.dart`, `apartment_ledger_screen.dart`, `maintenance_fund_ledger_screen.dart`, `edit_invoice_screen.dart` (Module 17).
  - Giảm thêm 50 điểm nợ `fontSize:` cứng toàn bộ phân hệ features (từ 479 xuống 429). Đưa tổng số điểm nợ typography được dọn sạch lên 507 điểm qua 9 gói dọn dẹp liên hoàn (xóa sạch 54.2% nợ). Toàn bộ 4 guardrail tests và 6 screen widget tests đều vượt qua 100%.
- **Gói 2.10 Chuẩn Hóa Typography & Tokens Phân Hệ Cẩm Nang Tòa Nhà, Tuần Tra Giám Sát, Duyệt Liên Kết Cư Dân & Bàn Giao Căn Hộ (Handbook Management, Inspection Workstation, Link Request & Handover Management)**:
  - `HandbookManagementScreen`: Xóa sạch 100% 12/12 điểm `fontSize:` cứng tại 3 tab (Đường dây nóng khẩn cấp, Nội quy tòa nhà, Tiện ích tòa nhà); chuyển đổi toàn bộ 8 lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar.showSuccess` và `AppSnackBar.showError`.
  - `InspectionWorkstationScreen`: Xóa sạch 100% 12/12 điểm `fontSize:` cứng tại trạm kiểm kê hiện trường, chốt chỉ số công tơ điện/nước, chiết tính hoàn tiền đặt cọc và khu vực chữ ký BQL/cư dân; chuyển đổi toàn bộ 5 lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar` (Success, Error, Warning).
  - `LinkRequestManagementScreen`: Xóa sạch 100% 10/10 điểm `fontSize:` cứng tại danh sách yêu cầu liên kết căn hộ, huy hiệu vai trò chủ hộ/thành viên, hộp thoại phê duyệt và hộp thoại từ chối liên kết kèm lý do chuẩn hóa.
  - `HandoverManagementScreen`: Xóa sạch 100% 8/8 điểm `fontSize:` cứng tại dải KPI quản lý biên bản bàn giao, thẻ biên bản nhận/trả nhà, chi tiết hoàn trả cọc và chuyển đổi lệnh gọi `ScaffoldMessenger.showSnackBar` xuất PDF sang `AppSnackBar.showError`.
  - Mở rộng Whitelist của Guardrail CI (`test/core/theme_and_color_guard_test.dart`) bảo vệ thêm 4 file: `handbook_management_screen.dart`, `inspection_workstation_screen.dart`, `link_request_management_screen.dart`, `handover_management_screen.dart` (Module 18).
  - Giảm thêm 42 điểm nợ `fontSize:` cứng toàn bộ phân hệ features (từ 429 xuống 387). Đưa tổng số điểm nợ typography được dọn sạch lên 549 điểm qua 10 gói dọn dẹp liên hoàn (xóa sạch 58.7% nợ). Toàn bộ 4 guardrail tests và 14 screen widget/responsive tests đều vượt qua 100%.
- **Gói 2.11 Chuẩn Hóa Typography & Tokens Toàn Diện Phân Hệ Quản Trị BQL: Giao Dịch Đối Soát, Ủy Quyền Vai Trò, Ma Trận Phân Quyền & Nhật Ký Kiểm Toán (Cán Mốc 100% Zero Debt Phân Hệ Management Screens)**:
  - `ManagementPaymentTransactionsScreen`: Xóa sạch 100% 7/7 điểm `fontSize:` cứng tại hộp thoại chi tiết giao dịch, dải trạng thái đối soát thành công/thất bại và danh sách đối soát thanh toán.
  - `RoleDelegationScreen`: Xóa sạch 100% 6/6 điểm `fontSize:` cứng tại huy hiệu vai trò ủy quyền, thời hạn hiệu lực, ghi chú lý do và chuyển đổi lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar.showWarning`.
  - `PermissionMatrixScreen`: Xóa sạch 100% 5/5 điểm `fontSize:` cứng tại banner kiến trúc bảo mật 2 lớp (Defense-in-Depth), danh sách đặc quyền ma trận RBAC và ghi chú nghiệp vụ.
  - `AuditTrailScreen`: Xóa sạch 100% 4/4 điểm `fontSize:` cứng tại chip bộ lọc danh mục kiểm toán, thẻ nhật ký thao tác và thời gian tương đối.
  - Mở rộng Whitelist của Guardrail CI (`test/core/theme_and_color_guard_test.dart`) bảo vệ thêm 4 file: `management_payment_transactions_screen.dart`, `role_delegation_screen.dart`, `permission_matrix_screen.dart`, `audit_trail_screen.dart` (Module 19).
  - **Cán Mốc Lịch Sử**: 100% toàn bộ màn hình thuộc `lib/features/management/screens/` đạt trạng thái sạch hoàn toàn (0 điểm nợ `fontSize:` cứng).
  - Giảm thêm 22 điểm nợ `fontSize:` cứng toàn bộ phân hệ features (từ 387 xuống 365). Đưa tổng số điểm nợ typography được xóa bỏ lên 571 điểm qua 11 gói dọn dẹp liên hoàn (xóa sạch 61.0% nợ). Toàn bộ 4 guardrail tests và 10 screen widget tests đều vượt qua 100%.
- **Gói 2.12 Chuẩn Hóa Typography & Tokens Toàn Diện 5 Màn Hình Cư Dân Cuối Cùng: Trung Tâm Thông Báo, Lịch Sử Thanh Toán, Sửa Phản Ánh Sự Cố, Biên Bản Bàn Giao Cư Dân & Yêu Cầu Liên Kết Căn Hộ (Cán Mốc 100% Zero Debt Phân Hệ Resident Screens)**:
  - `NotificationCenterScreen`: Xóa sạch 100% 9/9 điểm `fontSize:` cứng, thay thế 3 mã màu cứng bằng token `AppTheme.warning` & `AppTheme.secondary`, chuẩn hóa lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar.showSuccess`.
  - `PaymentHistoryScreen`: Xóa sạch 100% 8/8 điểm `fontSize:` cứng, thay thế mã màu nền cứng `Color(0xFF1E293B)` bằng `Theme.of(context).cardColor` thích ứng hoàn hảo chế độ sáng/tối.
  - `EditIssueScreen`: Xóa sạch 100% 8/8 điểm `fontSize:` cứng, chuẩn hóa toàn bộ 4 lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar` (Success, Error, Info).
  - `ResidentHandoverScreen`: Xóa sạch 100% 6/6 điểm `fontSize:` cứng tại danh sách biên bản nhận/trả nhà, huy hiệu trạng thái và chi tiết biên bản.
  - `LinkRequestScreen`: Xóa sạch 100% 6/6 điểm `fontSize:` cứng, chuẩn hóa toàn bộ 5 lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar` (Success, Error, Warning).
  - Mở rộng Whitelist của Guardrail CI (`test/core/theme_and_color_guard_test.dart`) bảo vệ thêm 5 file: `notification_center_screen.dart`, `payment_history_screen.dart`, `edit_issue_screen.dart`, `resident_handover_screen.dart`, `link_request_screen.dart` (Module 20).
  - **Cán Mốc Kép Lịch Sử**: 100% toàn bộ màn hình thuộc cả 2 phân hệ cốt lõi `lib/features/resident/screens/` và `lib/features/management/screens/` đạt trạng thái sạch hoàn toàn (0 điểm nợ `fontSize:` cứng, 0 mã màu cứng).
  - Giảm thêm 37 điểm nợ `fontSize:` cứng toàn bộ phân hệ features (từ 365 xuống 328). Đưa tổng số điểm nợ typography được xóa bỏ lên 608 điểm qua 12 gói dọn dẹp liên hoàn (xóa sạch 65.0% nợ). Toàn bộ 4 guardrail tests và 13 resident screen widget/responsive tests đều vượt qua 100%.
- **Gói 2.13 Chuẩn Hóa Typography & Tokens Toàn Diện 4 Màn Hình Cuối Cùng Toàn Ứng Dụng: Đổi Mật Khẩu, Xác Thực OTP, Tra Cứu Chứng Từ Điện Tử & Xem Trước Chứng Từ (Cán Mốc 100% Toàn Bộ Screens Ứng Dụng Đạt Zero Debt Typography & Zero Hardcoded Color)**:
  - `ChangePasswordScreen`: Xóa sạch 100% 2/2 điểm `fontSize:` cứng, chuyển đổi toàn bộ 2 lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar.showSuccess` và `AppSnackBar.showError`.
  - `VerifyOtpScreen`: Xóa sạch 100% 2/2 điểm `fontSize:` cứng, chuyển đổi lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar.showSuccess`.
  - `DocumentLookupScreen`: Xóa sạch 100% 7/7 điểm `fontSize:` cứng và 11 điểm mã màu cứng, thay thế bằng `AppStatusColors`, `AppTheme.success`, `AppTheme.error`, `AppTheme.textPrimary`, `AppTheme.textSecondary`.
  - `DocumentPreviewScreen`: Xóa sạch 100% 1/1 điểm `fontSize:` cứng tại AppBar tiêu đề tệp đính kèm sang `context.titleLarge`.
  - Mở rộng Whitelist của Guardrail CI (`test/core/theme_and_color_guard_test.dart`) bảo vệ thêm 4 file: `change_password_screen.dart`, `verify_otp_screen.dart`, `document_lookup_screen.dart`, `document_preview_screen.dart` (Module 21).
  - **Cán Mốc Toàn Thắng Lịch Sử**: 100% toàn bộ tất cả màn hình giao diện (`*/screens/*.dart`) trong toàn bộ ứng dụng Vivona đạt trạng thái sạch hoàn toàn (0 điểm nợ `fontSize:` cứng, 0 mã màu cứng).
  - Giảm thêm 12 điểm nợ `fontSize:` cứng toàn bộ phân hệ features (từ 328 xuống 316). Đưa tổng số điểm nợ typography được xóa bỏ lên 620 điểm qua 13 gói dọn dẹp liên hoàn (xóa sạch 66.2% nợ). Toàn bộ 4 guardrail tests và 22 widget tests đều vượt qua 100%.
- **Gói 2.14 Chuẩn Hóa Typography & Tokens Cụm Auth Widgets & Resident Identity/Safety Widgets (Cán Mốc 100% Zero Debt Toàn Bộ Phân Hệ Auth)**:
  - `MfaSetupDialog`: Xóa sạch 100% 6/6 điểm `fontSize:` cứng, thay `Colors.red` bằng `AppTheme.error`, chuẩn hóa lệnh gọi `ScaffoldMessenger.showSnackBar` sang `AppSnackBar.showSuccess`.
  - `MfaVerificationDialog`: Xóa sạch 100% 4/4 điểm `fontSize:` cứng và 2 điểm `Colors.red` sang `AppTheme.error`.
  - `OtpInputBoxes`: Kết nối kiểu chữ `context.titleLarge` chuẩn Design System cho các ô nhập mã xác thực OTP.
  - `AcceptInvitationDialog`: Xóa sạch 100% 4/4 điểm `fontSize:` cứng tại tiêu đề, hướng dẫn và thông báo kích hoạt.
  - `ApartmentSwitcherChip`: Xóa sạch 100% 6/6 điểm `fontSize:` cứng tại bottom sheet chọn căn hộ, chip hiển thị mã phòng và nút liên kết.
  - `StickyEmergencyBar`: Xóa sạch 100% 4/4 điểm `fontSize:` cứng tại banner cảnh báo khẩn cấp, nhãn phân loại và nút chi tiết.
  - `EquipmentInterruptionBanner`: Xóa sạch 100% 6/6 điểm `fontSize:` cứng và 14 điểm mã màu cứng, thay thế bằng `AppTheme.warningBackground`, `AppTheme.warningText`, `AppTheme.warningBorder`, `AppTheme.error`.
  - Mở rộng Whitelist của Guardrail CI (`test/core/theme_and_color_guard_test.dart`) bảo vệ thêm 7 file: `mfa_setup_dialog.dart`, `mfa_verification_dialog.dart`, `otp_input_boxes.dart`, `accept_invitation_dialog.dart`, `apartment_switcher_chip.dart`, `sticky_emergency_bar.dart`, `equipment_interruption_banner.dart` (Module 22).
  - **Cán Mốc Kỷ Lục Mới**: 100% toàn bộ phân hệ Xác thực (`lib/features/auth/`) bao gồm cả screens và widgets đạt trạng thái Zero Debt Typography & Zero Hardcoded Color.
  - Giảm thêm 30 điểm nợ `fontSize:` cứng toàn bộ phân hệ features (từ 316 xuống 286). Đưa tổng số điểm nợ typography được xóa bỏ lên 650 điểm qua 14 gói dọn dẹp liên hoàn (xóa sạch 69.4% nợ). Toàn bộ 4 guardrail tests và 7 widget tests đều vượt qua 100%.

### Đã thay đổi (Changed) - Tái Định Vị Thương Hiệu Toàn Diện Sang Vivona (Cấp Độ 3 Full Codebase Refactor)
- **Tên Thương Hiệu & Tên Package**: Tái định vị thương hiệu toàn diện từ PKA-Home sang **Vivona** (Latin: *vivo* - sống động, tagline: *"Nơi chung cư sống động hơn"* | *"Quản lý tòa nhà, chạm là xong"*). Đổi tên package Dart `pka_home` $\rightarrow$ `vivona` trên toàn bộ 335+ tệp mã nguồn và kiểm thử.
- **Định Danh Nền Tảng Di Động (Native Identifiers)**:
  - **Android**: Chuyển đổi `applicationId` và `namespace` sang `vn.vivona.app`. Di chuyển `MainActivity.kt` sang package `vn.vivona.app`, đổi Notification Channel sang `vivona_high_importance_channel` ("Thông báo Vivona").
  - **iOS**: Chuyển đổi `PRODUCT_BUNDLE_IDENTIFIER` sang `vn.vivona.app`, cập nhật `CFBundleDisplayName` thành `Vivona` và bổ sung URL Scheme `vivona://`.
  - **Web**: Cập nhật tiêu đề web và Web App Manifest sang `Vivona - Nền Tảng Quản Lý Chung Cư`.
- **Đồng Bộ Chuỗi Nhãn & Hằng Số Bảo Mật**: Cập nhật toàn bộ nhãn hiển thị trong ứng dụng (100% tiếng Việt chuẩn mực), muối băm thẻ khách thăm `Vivona@SecurityPassSignaturePepper#2026`, khóa Offline Storage `vivona_offline_sync_queue`, domain `vivona.vn`, email tiếp nhận `security@vivona.vn` và thông báo nhật ký vận hành `[VIVONA]`.
- **Đồng Bộ Toàn Diện Hồ Sơ Pháp Lý & Tài Liệu**: Cập nhật `README.md`, `CHANGELOG.md`, `DESIGN.md`, `PRODUCT.md` và các tài liệu kỹ thuật liên quan.

---

## [2.1.3] - 2026-11-17

### Đã sửa (Fixed) - Khắc Phục Triệt Để P0 VNPay & Xử Lý Hồi Quy Tiện Ích
- **Chuyển Toàn Bộ Ký Số VNPay Sang Server-Authoritative (`create-vnpay-url`)**: Triển khai Deno Edge Function khởi tạo link thanh toán VNPay 2.1.0 phía máy chủ. Thẩm định JWT, kiểm soát RBAC kết hợp ủy quyền vai trò động (`get_effective_user_role`), đọc số tiền và `payment_code` trực tiếp từ database (zero-trust client), tra cứu khóa bí mật 2 bước độc lập từ `building_payment_secrets`.
- **Khắc phục Lỗi Hồi quy Tiện ích (`PaymentType.service`)**: Giới hạn cổng VNPay chỉ kích hoạt đối với hóa đơn căn hộ (`PaymentType.invoice`), ngăn chặn hoàn toàn lỗi 404 khi đặt tiện ích thể thao/phòng họp.
- **Hỗ trợ Thanh toán Từng phần & Khấu trừ Toàn diện**: Tự động khấu trừ các khoản giao dịch thành công hoặc nộp thiếu (`status IN ('SUCCESS', 'PARTIAL_PAID')`) từ `payment_transactions`, từ chối tạo URL nếu `payment_code` chưa hợp lệ hoặc hóa đơn đã trả hết nợ.
- **Khắc phục Lỗi PGRST200 tại `vnpay-ipn`**: Tra cứu cấu hình và khóa bí mật theo 2 truy vấn nối tiếp độc lập qua `building_id`, loại bỏ sự phụ thuộc vào Foreign Key trực tiếp giữa 2 bảng.
- **Dọn dẹp Dead Code**: Xóa bỏ `VnpayService` (logic băm client-side) và 2 trường nhạy cảm `sepayApiKey`, `vnpayHashSecret` khỏi `BuildingPaymentConfigModel`.

### Đã thêm (Added) - Hệ Thống Design System Toolkit, CI Guardrail & Trợ Năng (A11y)
- **Design System Typography Extension**: Cung cấp `AppTypographyExtension` trên `BuildContext` (`context.titleLarge`, `context.bodyMedium`, `context.labelSmall`,...) giúp loại bỏ hardcode `fontSize`.
- **Thích ứng Dark Mode Chuẩn WCAG AA**: Nâng cấp `AppStatusColors` với các getters tự động thích ứng chế độ sáng/tối (`getPaid(context)`, `getUnpaid(context)`, `getPriorityHigh(context)`,...), bảo toàn 100% mã màu Light hiện tại (zero-regression).
- **Chốt chặn CI Guardrail (`theme_and_color_guard_test.dart`)**: Tự động quét regex cấm tuyệt đối `Color(0x...)` và `fontSize:` trên danh sách màn hình đã chuẩn hóa.
- **Chuẩn hóa Cuốn chiếu 7 Màn hình (Tài chính & Sự cố)**:
  - Loại bỏ hoàn toàn spinner thô (`CircularProgressIndicator`), thay thế bằng `AppSkeletonShimmer.cardList()` và `AppEmptyState`.
  - Bổ sung `Semantics` đọc số tiền tự nhiên thành chữ tiếng Việt (`VietnameseCurrencyWords.toVietnameseWords`) và nhãn phân loại sự cố cho VoiceOver / TalkBack trên cả màn hình cư dân và ban quản lý (`resident_issue_screen`, `issue_management_screen`, `resident_invoice_screen`, `invoice_management_screen`).
  - Bổ sung bộ test a11y & shimmer tự động cho toàn bộ các màn hình trên.

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

