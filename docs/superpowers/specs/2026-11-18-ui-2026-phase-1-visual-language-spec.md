# Đặc Tả Kỹ Thuật: Ngôn Ngữ Thị Giác 2026 (Giai Đoạn 1 - Visual Language 2026)

## 1. Bối Cảnh & Mục Tiêu
Tiếp nối thành công của **Giai đoạn 0 (Foundation Hardening)** — khi toàn bộ nền tảng Design Tokens (`AppSpacing`, `AppRadius`), `TextTheme` 15 styles, Component Themes và dọn dẹp các khối mã nguồn lớn đã hoàn tất với `dart analyze` 0 lỗi và 100% tests pass.

**Giai đoạn 1** tập trung vào bước chuyển mình trực quan mạnh mẽ nhất theo xu hướng giao diện Flutter 2026:
1. **Bento Grid Architecture**: Chuyển đổi màn hình Trang chủ Cư dân từ danh sách dọc truyền thống sang hệ thống lưới Bento mô-đun đa tầng linh hoạt (thẻ hóa đơn nổi bật kích thước lớn, biểu đồ mini tiêu thụ điện nước, lưới thao tác nhanh gọn, thông báo khẩn cấp/sự kiện).
2. **Spring Motion & Staggered Animation**: Xây dựng hệ thống chuyển động lò xo mượt mà (natural spring physics) dựa trên `flutter_animate`, danh sách xuất hiện so le (staggered entrance) và phản hồi chạm vi mô (tap-bounce scale feedback) trên các nút tương tác chính.
3. **Phủ Hệ Thống Rung Phản Hồi Xúc Giác (Haptic Engine)**: Tích hợp chuẩn hóa `AppHaptics` cho các hành vi quan trọng (xác nhận thanh toán, gửi sự cố, gạt switch, bấm quick action, chuyển tab).
4. **Hiệu Ứng Kính Tiết Chế (Glassmorphism 2.0 & Frosted Surfaces)**: Tạo component kính mờ cao cấp (`AppGlassCard`, `FrostedAppBar`, `GlassBottomSheet`) với `BackdropFilter`, viền gradient vi mô và độ mờ tương thích nền sáng/tối mà không gây suy giảm FPS.
5. **Đưa Biểu Đồ Điện Nước Đến Cư Dân**: Trực quan hóa dữ liệu tiêu thụ điện, nước và phí quản lý 6 tháng gần nhất bằng biểu đồ cột/đường tương tác (`fl_chart`) ngay tại màn hình cư dân.
6. **Tái cấu trúc Bento Dashboard cho Ban Quản Lý**: Tối ưu lưới KPI cards và biểu đồ doanh thu/thu phí theo dạng lưới Bento trực quan, rõ ràng trên cả mobile và desktop.

---

## 2. Kiến Trúc Kỹ Thuật (Architecture & Components)

### 2.1. Thư Viện Chuyển Động & Tương Tác Cốt Lõi (`lib/core/motion/` & `lib/core/utils/`)
- `lib/core/utils/app_haptics.dart`:
  - `light()`: Dành cho chuyển tab, lọc danh mục, bấm chip.
  - `medium()`: Dành cho bấm nút chính, mở modal, submit form.
  - `heavy()`: Dành cho xác nhận thao tác quan trọng (thanh toán hóa đơn, xóa, đóng sự cố).
  - `selection()`: Dành cho date/time picker, switch toggle, radio selection.
  - `success()`: Dành cho thông báo thành công (thanh toán hoàn tất, ghi chỉ số thành công).
  - `error()`: Dành cho rung báo lỗi validate, kết nối thất bại.
- `lib/core/motion/app_spring_motion.dart`:
  - Chuẩn hóa Curve: `Curves.easeOutBack`, `Curves.fastLinearToSlowEaseIn`, `SpringCurve`.
  - Extension `Widget.animateSpringEntry({int delayMs = 0})`: Fade + Slide + Slight Scale entry.
  - Extension `Widget.animateStaggeredList({required int index})`: So le 50ms cho các item trong danh sách/lưới.
- `lib/core/widgets/bounceable.dart`:
  - Component nút bấm vi mô: khi nhấn (pointer down) thu nhỏ tỉ lệ 0.96-0.98 với hiệu ứng lò xo mượt, tự động kích hoạt `AppHaptics.light()`.

### 2.2. Hiệu Ứng Kính Tiết Chế (`lib/core/widgets/app_glass.dart`)
- `AppGlassCard`:
  - Bọc `ClipRRect(borderRadius: AppRadius.rLg)`
  - `BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10))`
  - Nền mờ thích ứng:
    - Light Mode: `Colors.white.withValues(alpha: 0.72)` + viền `Colors.white.withValues(alpha: 0.35)`
    - Dark Mode: `Color(0xFF1E293B).withValues(alpha: 0.65)` + viền `Colors.white.withValues(alpha: 0.08)`
  - Tránh lạm dụng gây drop frame trên máy cấu hình thấp; chỉ dùng cho Thẻ nổi bật, Header trôi và Bottom Sheet.

### 2.3. Bento Grid Trang Chủ Cư Dân (`lib/features/resident/widgets/home/`)
Tái cấu trúc layout theo cấu trúc Bento Grid phân tầng:
1. **Bento Header**: Avatar, căn hộ hiện tại (`A0110`), chuông thông báo có badge rung nhẹ khi có tin mới.
2. **Bento Hero Widget (Thẻ Ưu Tiên Số 1)**:
   - Nếu có hóa đơn chưa đóng: Thẻ Hóa Đơn Lớn (Hero Banner) kèm nút "Thanh toán ngay" có hiệu ứng pulse nhẹ.
   - Nếu đã đóng hết tiền: Thẻ "An tâm sinh hoạt - Đã hoàn tất phí tháng" với minh họa tinh tế.
3. **Bento Metric Mini-Chart Card (Biểu Đồ Tiêu Thụ Điện Nước)**:
   - Biểu đồ cột mini (`fl_chart`) so sánh điện nước 3-6 tháng gần nhất với chỉ số biến động $\pm\%$.
4. **Bento 4-Grid Quick Actions**:
   - 4 ô vuông Bento với bo góc lớn (`AppRadius.rXl`), icon gradient và nhãn chữ rõ ràng (Đóng phí, Báo sự cố, Đăng ký xe, Ghi chỉ số).
5. **Bento Recent Activities / Announcements**:
   - Thẻ thông báo tòa nhà khẩn cấp (nếu có) hoặc danh sách sự cố đang xử lý.

### 2.4. Bento Dashboard Ban Quản Lý (`lib/features/management/widgets/home/`)
- Tái cấu trúc Dashboard BQL thành dạng Bento KPI đa tỉ lệ:
  - 1 ô lớn: Tiến độ tài chính & tổng thu/công nợ (Financial Overview).
  - 2 ô nhỏ cạnh nhau: Tỉ lệ căn hộ có cư dân (`92%`) & Sự cố cần xử lý gấp (`3`).
  - 1 ô dài: Biểu đồ thu phí 6 tháng gần nhất.
  - Lưới thao tác điều phối nhanh (Quick Dispatch).

---

## 3. Kế Hoạch Kiểm Thử & Chốt Chặn Chất Lượng
- Mở rộng unit tests cho `AppHaptics` (mock platform channel) và `AppSpringMotion`.
- Viết widget tests cho `ResidentBentoHomeScreen` và `AppGlassCard` để đảm bảo:
  - Render đúng trên cả light/dark theme.
  - Không overflow ở các kích cỡ màn hình (320px đến 1440px).
  - Hoạt động mượt mà khi dữ liệu loading, rỗng, có lỗi, hoặc có dữ liệu thực tế.
- Giữ vững chốt chặn:
  - `test/core/theme_and_color_guard_test.dart` tiếp tục giám sát không có màu hoặc fontSize cứng phát sinh.
  - `dart analyze lib test`: 0 errors, 0 warnings.

