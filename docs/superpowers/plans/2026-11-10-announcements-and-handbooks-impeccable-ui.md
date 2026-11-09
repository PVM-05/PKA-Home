# Kế Hoạch Triển Khai: Nâng Cấp Phân Hệ Truyền Thông & Cẩm Nang Tòa Nhà (Impeccable & Anti-RenderFlex)

- **Mục tiêu:** Nâng cấp toàn diện 4 màn hình truyền thông và cẩm nang tòa nhà (`AnnouncementManagementScreen`, `ResidentAnnouncementDetailScreen`, `HandbookManagementScreen`, `ResidentHandbookScreen`) theo triết lý Impeccable Taste và Anti-RenderFlex Guarantee 100%.
- **Nhánh thực hiện:** `main` (commit trực tiếp theo quy định dự án).
- **Tài liệu đặc tả:** `docs/superpowers/specs/2026-11-10-announcements-and-handbooks-impeccable-ui-design.md`.

---

## Danh Sách Task Triển Khai

### Task 1: Nâng cấp `AnnouncementManagementScreen` (Quản Lý & Phát Thông Báo BQL)
**Files:**
- Modify: `lib/features/management/screens/announcement_management_screen.dart`
- Create/Update Test: `test/features/management/announcement_management_responsive_test.dart`

**Yêu cầu kỹ thuật:**
- Hỗ trợ Desktop Grid $\ge 900$dp (`maxWidth: 1300`, 2 cột thẻ `AppCard`).
- Mobile (< 900dp, `maxWidth: 600`):
  - Thẻ `AppCard` viền siêu mỏng mờ theo `DESIGN.md`.
  - Hàng badge danh mục, đối tượng và nhóm nút thao tác bọc `Expanded` chống tràn 100% trên 320dp (Zoom 1.3x).
- Viết test responsive kiểm tra ở 320dp (scale 1.3x) và 1200dp.

---

### Task 2: Nâng cấp `ResidentAnnouncementDetailScreen` (Chi Tiết Thông Báo Cư Dân)
**Files:**
- Modify: `lib/features/resident/screens/resident_announcement_detail_screen.dart`
- Create/Update Test: `test/features/resident/resident_announcement_detail_responsive_test.dart`

**Yêu cầu kỹ thuật:**
- Bọc toàn bộ nội dung trong `Center(ConstrainedBox(maxWidth: 800, ...))` chống bè ngang trên Desktop.
- Sử dụng thẻ `AppCard` cho khối tiêu đề/danh mục, khung giờ sự kiện/bảo trì, khối hotline kỹ thuật và khối nội dung chi tiết.
- Chống tràn 100% trên 320dp x 600dp (Zoom 1.3x).

---

### Task 3: Nâng cấp `HandbookManagementScreen` & `ResidentHandbookScreen` (Cẩm Nang Tòa Nhà BQL & Cư Dân)
**Files:**
- Modify: `lib/features/management/screens/handbook_management_screen.dart`
- Modify: `lib/features/resident/screens/resident_handbook_screen.dart`
- Create/Update Test: `test/features/management/handbook_screens_responsive_test.dart`

**Yêu cầu kỹ thuật:**
- Desktop $\ge 900$dp (`maxWidth: 1200`): Bố cục lưới 2 cột cho các Tab (Hotline, Nội quy, Tiện ích). Dùng `AppCard`.
- Mobile (< 900dp, `maxWidth: 600`): Thẻ `AppCard`, ListTile và nhãn bọc `Expanded` chống tràn 100% trên 320dp (Zoom 1.3x).

---

### Task 4: Kiểm Thử Toàn Diện, Static Analysis & Cập Nhật Tri Thức Hệ Thống
**Files:**
- Verify: Toàn bộ suite test liên quan
- Update: Knowledge Graph qua `graphify update .`

**Yêu cầu kỹ thuật:**
- Chạy toàn bộ test suites của phân hệ thông báo và cẩm nang.
- Chạy `dart analyze lib test` đạt 0 issues.
- Chạy `impeccable detect` kiểm tra chất lượng giao diện.
- Cập nhật Knowledge Graph `graphify update .`.
- Commit hoàn thành phân hệ vào nhánh `main`.
