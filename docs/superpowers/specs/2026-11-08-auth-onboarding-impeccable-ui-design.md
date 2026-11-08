# Đặc Tả Thiết Kế: Cải Tiến Giao Diện Cổng Đăng Nhập & Kích Hoạt Onboarding (Impeccable & Anti-RenderFlex)

- **Mục tiêu:** Chuẩn hóa toàn bộ trải nghiệm giao diện người dùng (UI/UX) cho phân hệ Xác thực & Kích hoạt Onboarding (`LoginScreen`, `ResidentActivationScreen`, `ForgotPasswordScreen`, `OtpInputBoxes`) theo tiêu chuẩn **`pbakaus/impeccable`**, loại bỏ hoàn toàn lỗi tràn layout 44px trên mobile hẹp 320dp và tối ưu hóa trải nghiệm thương mại B2B SaaS trên Web Desktop ($\ge 900$dp, maxWidth: 1400dp).
- **Phạm vi tác động:**
  - `lib/features/auth/widgets/otp_input_boxes.dart`
  - `lib/features/auth/screens/resident_activation_screen.dart`
  - `lib/features/auth/screens/login_screen.dart`
  - `lib/features/auth/screens/forgot_password_screen.dart`
- **Tuân thủ quy chuẩn:** Clean Architecture, Feature-First, Riverpod Reactive State, 100% tiếng Việt chuẩn mực SaaS B2B, commit trực tiếp trên nhánh `main`.

---

## 1. Phân Tích Kỹ Thuật & Giải Pháp Triệt Tiêu Lỗi RenderFlex

### 1.1. `OtpInputBoxes` — Tự Động Co Giãn Tỷ Lệ (Fluid Box Scaling)
- **Nguyên nhân lỗi 44px:** Cấu hình 6 ô nhập cứng `width: 46` với khoảng cách 5 khoảng $\approx 8$dp $\to$ tổng chiều rộng yêu cầu là 316dp. Trong khi đó trên mobile 320dp với padding của thẻ `AppCard` (24dp mỗi bên), bề rộng khả dụng chỉ còn 272dp, gây lỗi tràn 44px (`A RenderFlex overflowed by 44 pixels on the right`).
- **Giải pháp Impeccable:**
  - Sử dụng `LayoutBuilder` để đo kích thước khả dụng thực tế:
    ```dart
    final availableWidth = constraints.maxWidth;
    final spacing = (availableWidth < 300) ? 4.0 : 8.0;
    final boxWidth = ((availableWidth - (widget.length - 1) * spacing) / widget.length)
        .clamp(34.0, 48.0);
    ```
  - Thay vì `SizedBox(width: 46)`, mỗi ô sử dụng `SizedBox(width: boxWidth, height: boxWidth * 1.18)`.
  - Giữ nguyên toàn bộ logic clipboard paste, tự động chuyển ô (focus navigation) và xử lý phím backspace.

### 1.2. `ResidentActivationScreen` — Thanh Tiến Trình 4 Bước & Bố Cục Đa Nền Tảng
- **Thanh tiến trình (`_buildStepIndicator`):**
  - Trên Mobile (< 600dp): Các nhãn text bước ('Mã mời', 'Xác thực', 'Mật khẩu', 'Hoàn tất') được bọc trong `Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(...)))` để không bị đè lên nhau khi zoom chữ 1.3x.
  - Trên Mobile hẹp (< 360dp): Padding hai bên giảm từ 24dp xuống 16dp để tăng không gian hiển thị.
- **Desktop Enterprise ($\ge 900$dp, `maxWidth: 1200`):**
  - Chuyển sang bố cục 2 cột:
    - **Cột trái (Hero Brand):** Card giới thiệu đặc quyền cư dân số PKA-Home (Quản lý căn hộ, thanh toán VietQR Napas 247, mở cửa đón khách & gửi phản ánh kỹ thuật 24/7).
    - **Cột phải (Form Kích Hoạt):** Thanh tiến trình 4 bước + Các trường nhập thông tin sắc nét trong `AppCard`.

### 1.3. `LoginScreen` — An Toàn Cuộn Dọc & Nút Kích Hoạt Thích Ứng
- **Cột Hero Desktop:**
  - Bọc trong `SingleChildScrollView(child: ConstrainedBox(constraints: BoxConstraints(minHeight: constraints.maxHeight), child: IntrinsicHeight(...)))` để chống tràn dọc trên các màn hình laptop có chiều cao hạn chế (< 768px).
- **Form Mobile:**
  - Nút "Kích hoạt tài khoản lần đầu" bọc nhãn trong `FittedBox` để nhãn không bị tràn khi font phóng to 1.3x trên 320dp.

### 1.4. `ForgotPasswordScreen` — Chuẩn Hóa Khôi Phục Mật Khẩu
- Bọc toàn bộ nội dung trong `Center(ConstrainedBox(maxWidth: 440))`.
- Icon khôi phục mật khẩu và các thông báo trung tính chống tấn công dò quét tài khoản (Anti-account enumeration) được trình bày sắc nét, tương thích hoàn toàn cả Light và Dark Mode.

---

## 2. Bảng Cam Đoan Chống Tràn Bố Cục (Anti-RenderFlex Checklist)

| Thành phần | Cơ chế chống tràn | Kích thước kiểm thử |
| :--- | :--- | :--- |
| **`OtpInputBoxes`** | Tính toán động `boxWidth` từ 34dp đến 48dp qua `LayoutBuilder`. | Mobile 320dp, Card padding 24dp $\to$ 0 overflow. |
| **`ResidentActivationScreen`** | Bọc nhãn bước trong `Flexible` & `FittedBox`, padding co giãn. | Mobile 320dp, Text zoom 1.3x $\to$ 0 overflow. |
| **`LoginScreen`** | `SingleChildScrollView` cho Cột Hero trên Desktop, `FittedBox` cho nút bấm. | Desktop chiều cao 600px & Mobile 320dp $\to$ 0 overflow. |
| **`ForgotPasswordScreen`** | `ConstrainedBox(maxWidth: 440)` bọc trong `SingleChildScrollView`. | Mọi kích thước màn hình $\to$ 0 overflow. |

---

## 3. Kịch Bản Kiểm Thử (Verification Plan)

1. **`auth_onboarding_responsive_test.dart`**:
   - Test 1: `OtpInputBoxes` render trên bề rộng cực hẹp 260dp — không có ngoại lệ RenderFlex nào xảy ra.
   - Test 2: `ResidentActivationScreen` render trên Mobile 320dp với font scale 1.3x — vượt qua toàn bộ 4 bước.
   - Test 3: `ResidentActivationScreen` render trên Desktop Web 1200dp — hiển thị bố cục 2 cột hoàn chỉnh.
   - Test 4: `LoginScreen` render trên Desktop chiều cao 600px — không có lỗi tràn dọc.
   - Test 5: `LoginScreen` render trên Mobile 320dp với font scale 1.3x — không có lỗi tràn ngang.
   - Test 6: `ForgotPasswordScreen` render an toàn trên 320dp với font scale 1.3x.
2. **Static Analysis Quality Gate:**
   - Chạy `dart analyze lib test` đạt 0 warning, 0 error.
