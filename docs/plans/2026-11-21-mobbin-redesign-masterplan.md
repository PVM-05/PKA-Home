# Kế Hoạch Tổng Thể Nâng Cấp 65 Màn Hình Vivona (`impeccable` + `thiet-ke-giao-dien`)

> **Ngày lập:** 21/11/2026  
> **Định vị sản phẩm:** Vivona — Commercial Production B2B SaaS & PropTech Platform.  
> **Nguyên tắc tối thượng:** Nâng cấp toàn bộ 65 màn hình theo chuẩn **Design System của Vivona** (`AppTheme` WCAG AA Light/Dark, 30+ M3 ColorScheme roles, font Inter đóng gói offline, 100% tiếng Việt chuẩn mực, không Emoji, vùng chạm $\ge 48\text{dp}$), áp dụng bộ quy chuẩn **Impeccable** + **Thiết kế Giao diện Vivona**. Không cắt bỏ nghiệp vụ hiện có.

---

## Quy Chuẩn Bắt Buộc Cho Mọi Màn Hình

1. **Mỗi lượt xử lý đúng 1 màn hình** (tối đa 5 vấn đề ưu tiên/lượt).
2. **Preserve list cố định:** Giữ nguyên nghiệp vụ, phân quyền RBAC, trạng thái dữ liệu, tên trường tiếng Việt và toàn bộ kiểm thử đang pass.
3. **1 hướng kiến trúc thống nhất:** Tập trung vào phân cấp thị giác rõ ràng, độ tương phản WCAG AA, vùng chạm $\ge 48\text{dp}$ và khả năng co giãn 320dp–1440dp.
4. **Dọn nợ kỹ thuật song song:** Với file $>1.200$ dòng, tách widget con theo trách nhiệm; loại bỏ màu cứng phá vỡ Dark Mode; ưu tiên widget lõi (`AppCard`, `AppSearchField`, `AppTextField`, `AppFormScaffold`, `AppEmptyState`, `AppSkeletonShimmer`, `AppUnsavedChangesGuard`).
5. **Cổng nghiệm thu trước khi commit & push mỗi Đợt lên `main`:**
   - `dart analyze` = **0 lỗi, 0 cảnh báo**
   - `flutter test --no-pub` = **100% pass** (gồm responsive `320dp` @ zoom `1.3x`, desktop `1440dp`, Light & Dark Mode)
   - Chạy `graphify update .` sau khi chỉnh sửa code.

---

## Đợt 1 — Hành Trình Lõi Cư Dân (`feat/mobbin-wave-1-resident-core`)

*Ưu tiên số 1: Tác động trực tiếp đến 100% cư dân hàng ngày và tỷ lệ thu phí đúng hạn.*

- [x] **1.1** `lib/features/resident/screens/resident_home_screen.dart` *(Tier 1)* — Trang chủ Cư dân (phân cấp thẻ hóa đơn đến hạn, nhịp lưới dịch vụ, biểu đồ điện nước)
- [x] **1.2** `lib/features/resident/screens/resident_invoice_screen.dart` *(Tier 1)* — Danh sách Hóa đơn & Tab Giao dịch VietQR
- [x] **1.3** `lib/features/resident/screens/resident_invoice_detail_screen.dart` *(Tier 1)* — Chi tiết Hóa đơn & sao kê khoản phí *(+ tách widget bảng kê)*
- [x] **1.4** `lib/core/widgets/unified_payment_sheet.dart` *(Tier 1)* — Cổng thanh toán VietQR / VNPay *(+ dọn ~40 màu cứng & tách bước)*
- [x] **1.5** `lib/features/resident/screens/resident_issue_screen.dart` *(Tier 2)* — Danh sách Phản ánh & Sự cố
- [x] **1.6** `lib/features/resident/screens/create_issue_screen.dart` & `edit_issue_screen.dart` *(Tier 2)* — Biểu mẫu gửi/sửa sự cố (`AppFormScaffold` & `AppTextField`)
- [x] **1.7** `lib/features/resident/screens/issue_detail_screen.dart` *(Tier 2)* — Tiến độ xử lý & trao đổi BQL *(+ dọn 34 màu cứng & tách timeline/comment)*

---

## Đợt 2 — Xác Thực, Kích Hoạt & Hồ Sơ (`feat/mobbin-wave-2-auth-onboarding`)

*Ấn tượng đầu tiên khi onboarding tòa nhà mới và giảm tỷ lệ cư dân bỏ dở lúc kích hoạt.*

- [x] **2.1** `lib/features/auth/screens/login_screen.dart` *(Tier 1)* — Đăng nhập
- [x] **2.2** `lib/features/auth/screens/resident_activation_screen.dart` *(Tier 1)* — Kích hoạt tài khoản cư dân (Mã kích hoạt → OTP → Mật khẩu)
- [x] **2.3** `lib/features/auth/screens/register_screen.dart` & `lib/features/resident/screens/link_request_screen.dart` *(Tier 2)* — Đăng ký & Yêu cầu liên kết căn hộ (`A0110`)
- [x] **2.4** Cụm bảo mật OTP / MFA / Mật khẩu *(Tier 3 — đồng bộ 1 khung chuẩn)*:
  - [x] `lib/features/auth/screens/mfa_challenge_screen.dart`
  - [x] `lib/features/auth/screens/forgot_password_screen.dart`
  - [x] `lib/features/auth/screens/verify_otp_screen.dart`
  - [x] `lib/features/auth/screens/reset_password_screen.dart`
  - [x] `lib/features/auth/screens/change_password_screen.dart`
- [x] **2.5** `lib/features/resident/screens/resident_profile_screen.dart` *(Tier 2)* — Hồ sơ cá nhân, hiển thị & quyền riêng tư PDPL

---

## Đợt 3 — Dịch Vụ & Đời Sống Cư Dân (`main`)

- [x] **3.1** `lib/features/resident/screens/resident_meter_reading_screen.dart` *(Tier 2)* — Chốt chỉ số điện nước + OCR *(+ tách file con)*
- [x] **3.2** `lib/features/resident/screens/vehicle_management_screen.dart` *(Tier 2)* — Phương tiện & Gửi xe *(+ tách thẻ xe & modal đăng ký)*
- [x] **3.3** `lib/features/resident/screens/resident_visitor_parcel_screen.dart` *(Tier 2)* — Thẻ QR đón khách & Mã PIN nhận bưu kiện
- [x] **3.4** `lib/features/resident/screens/resident_amenities_screen.dart` & `amenity_booking_screen.dart` *(Tier 2)* — Danh mục & Đặt lịch tiện ích tòa nhà
- [x] **3.5** Nhóm tra cứu & cộng đồng *(Tier 3)*:
  - [x] `lib/features/resident/screens/notification_center_screen.dart`
  - [x] `lib/features/resident/screens/resident_handbook_screen.dart`
  - [x] `lib/features/resident/screens/resident_announcement_detail_screen.dart`
  - [x] `lib/features/resident/screens/resident_community_screen.dart`
  - [x] `lib/features/resident/screens/payment_history_screen.dart`
  - [x] `lib/features/resident/screens/resident_handover_screen.dart`
  - [x] `lib/features/resident/screens/resident_handover_detail_screen.dart`

---

## Đợt 4 — Điều Hành & Tác Nghiệp Ban Quản Lý (`main`)

- [x] **4.1** `lib/features/management/screens/management_home_screen.dart` *(Tier 1)* — Trạm điều hành BQL *(+ tách widget con)*
- [x] **4.2** `lib/features/management/screens/front_desk_workstation_screen.dart` *(Tier 1)* — Trạm Lễ tân / Bảo vệ (quét vé QR & bưu kiện tốc độ cao)
- [x] **4.3** `lib/features/management/screens/issue_management_screen.dart` *(Tier 1)* — Điều phối sự cố & cảnh báo SLA *(+ tách thẻ sự cố)*
- [x] **4.4** `lib/features/management/screens/resident_management_screen.dart` & `apartment_management_screen.dart` *(Tier 2)* — Quản lý cư dân & căn hộ *(+ tách file con)*
- [x] **4.5** Nhóm hàng chờ duyệt & vận hành *(Tier 2–3)*:
  - [x] `lib/features/management/screens/link_request_management_screen.dart`
  - [x] `lib/features/management/screens/management_meter_reading_screen.dart`
  - [x] `lib/features/management/screens/vehicle_approval_screen.dart`
  - [x] `lib/features/management/screens/parking_management_screen.dart`
  - [x] `lib/features/management/screens/amenity_management_screen.dart`

---

## Đợt 5 — Tài Chính, Hóa Đơn & Kế Toán BQL (`main`)

- [x] **5.1** `lib/features/management/screens/accounting_web_workstation_screen.dart` *(Tier 1)* — Trạm kế toán & đối soát SePay/VietQR
- [x] **5.2** `lib/features/management/screens/invoice_management_screen.dart` & `management_invoice_detail_screen.dart` *(Tier 1)* — Quản lý & chi tiết hóa đơn BQL
- [x] **5.3** `lib/features/management/screens/create_invoice_screen.dart` & `edit_invoice_screen.dart` *(Tier 2)* — Lập & chỉnh sửa hóa đơn
- [x] **5.4** Nhóm báo cáo, biểu phí & sổ quỹ *(Tier 3)*:
  - [x] `lib/features/management/screens/financial_report_screen.dart`
  - [x] `lib/features/management/screens/management_payment_transactions_screen.dart`
  - [x] `lib/features/management/screens/fee_policy_management_screen.dart`
  - [x] `lib/features/management/screens/maintenance_fund_ledger_screen.dart`
  - [x] `lib/features/management/screens/apartment_ledger_screen.dart`

---

## Đợt 6 — Kỹ Thuật, Bàn Giao, Truyền Thông, Quản Trị & Tài Liệu (`main`)

- [ ] **6.1** Kỹ thuật & Vật tư *(Tier 2–3)*:
  - [ ] `lib/features/management/screens/equipment_management_screen.dart`
  - [ ] `lib/features/management/screens/equipment_detail_screen.dart`
  - [ ] `lib/features/management/screens/maintenance_materials_screen.dart`
- [ ] **6.2** Bàn giao & Kiểm kê *(Tier 2)*:
  - [ ] `lib/features/management/screens/handover_management_screen.dart`
  - [ ] `lib/features/management/screens/inspection_workstation_screen.dart`
- [ ] **6.3** Truyền thông & Đánh giá *(Tier 2–3)*:
  - [ ] `lib/features/management/screens/announcement_management_screen.dart` *(+ dọn 31 màu cứng)*
  - [ ] `lib/features/management/screens/handbook_management_screen.dart`
  - [ ] `lib/features/management/screens/community_management_screen.dart`
  - [ ] `lib/features/management/screens/service_rating_overview_screen.dart`
- [ ] **6.4** Quản trị Hệ thống & SaaS *(Tier 3)*:
  - [ ] `lib/features/management/screens/audit_trail_screen.dart`
  - [ ] `lib/features/management/screens/role_delegation_screen.dart`
  - [ ] `lib/features/management/screens/permission_matrix_screen.dart`
  - [ ] `lib/features/management/screens/batch_import_center_screen.dart`
  - [ ] `lib/features/management/screens/subscription_management_screen.dart`
- [ ] **6.5** Tra cứu Tài liệu *(Tier 3)*:
  - [ ] `lib/features/document/screens/document_lookup_screen.dart`
  - [ ] `lib/features/document/screens/document_preview_screen.dart`
