# Kế Hoạch Triển Khai: Nâng Cấp Giao Diện Impeccable Craft UI

- **File đặc tả:** `docs/superpowers/specs/2026-11-15-impeccable-ui-craft-design.md`
- **Mục tiêu:** Nâng cấp trải nghiệm người dùng, hệ thống trạng thái tải/rỗng và 2 trang chủ cốt lõi (Cư dân + Ban Quản Lý) đạt chuẩn Impeccable Craft SaaS B2B 2026.
- **Ràng buộc Git:** Commit trực tiếp vào nhánh `main`.

---

## Danh Sách Nhiệm Vụ (Task Breakdown)

### Task 1: Bộ thành phần Trạng thái Vi mô (Micro-States Design System)
1. Tạo test `test/core/widgets/app_skeleton_shimmer_test.dart`:
   - Test render khối rectangular, circular, textLine, cardList.
2. Tạo test `test/core/widgets/app_empty_state_test.dart`:
   - Test render icon, tiêu đề, mô tả, nút action callback.
3. Tạo `lib/core/widgets/app_skeleton_shimmer.dart`:
   - Animation shimmer mượt mà chu kỳ 1200ms, hỗ trợ Dark/Light theme, factory constructors tiện ích.
4. Tạo `lib/core/widgets/app_empty_state.dart`:
   - Thiết kế chuẩn Material 3, màu mờ nền icon, typography rõ ràng, không emoji.
5. Chạy test `flutter test test/core/widgets/app_skeleton_shimmer_test.dart test/core/widgets/app_empty_state_test.dart`.
6. Commit: `feat(ui): them bo widget app skeleton shimmer va app empty state chuan impeccable`.

---

### Task 2: Nâng cấp Giao diện Trang Chủ Cư Dân (`ResidentHomeScreen`)
1. Đọc và phân tích `lib/features/resident/screens/resident_home_screen.dart` cùng các widget liên quan.
2. Nâng cấp Thẻ căn hộ Hero Card:
   - Nền `AppGradients.heroDark`, viền mỏng tinh tế, hiển thị mã căn chuẩn `A0110`, tên cư dân, trạng thái công nợ và nút thanh toán nhanh VietQR một chạm.
3. Nâng cấp Dải Phím Tắt Thao Tác Nhanh (Quick Actions Grid):
   - Diện tích chạm $\ge 48\times 48\text{dp}$, Material Icons đồng nhất, 100% tiếng Việt chuẩn mực, không dùng emoji.
4. Tích hợp `AppSkeletonShimmer` khi tải dữ liệu và `AppEmptyState` khi không có hóa đơn/sự cố.
5. Chạy các test màn hình cư dân liên quan và sửa đổi nếu cần.
6. Commit: `feat(resident): nang cap trang chu cu dan chuan impeccable craft`.

---

### Task 3: Nâng cấp Giao diện Điều Hành Ban Quản Lý (`ManagementDashboardScreen`)
1. Đọc và phân tích `lib/features/management/screens/management_dashboard_screen.dart`.
2. Nâng cấp Executive KPI Bar:
   - 4 chỉ số cấp cao (Doanh thu kỳ này, Tỷ lệ lấp đầy, Sự cố khẩn cấp, Chốt số điện nước) với typographic scale tương phản cao, không lạm dụng thẻ lồng thẻ (no nested cards).
3. Nâng cấp Bố cục Thao tác Nhanh & Responsive:
   - Phân nhóm rõ ràng Kế toán / Kỹ thuật / Lễ tân, tự động thích ứng giữa Mobile Single-Column và Desktop Multi-Column.
4. Chạy các test BQL liên quan và đảm bảo xanh 100%.
5. Commit: `feat(management): nang cap dashboard dieu hanh bql chuan executive proptech`.

---

### Task 4: Kiểm tra Toàn diện & Bàn giao (Verification Before Completion)
1. Chạy `dart analyze lib test` đảm bảo 0 issues.
2. Chạy toàn bộ các test UI liên quan.
3. Đẩy thay đổi lên `origin/main`.
4. Báo cáo hoàn thành cho người dùng.
