# Đặc Tả Thiết Kế: Dashboard Web Quản Trị & Trạm Làm Việc Kế Toán Màn Hình Lớn (Web Admin Workstation & Large Screen Optimization)

- **Mã giai đoạn:** B4 (trong `COMMERCIAL_PRODUCT_ROADMAP.md`)
- **Ngày lập:** 30/10/2026
- **Trạng thái:** Đã phê duyệt (Approved)
- **Tác giả:** Antigravity Agent & Ban Quản Trị Hệ Thống PKA-Home

---

## 1. Mục Tiêu & Bối Cảnh Nghiệp Vụ

### 1.1. Bối cảnh
Trong vận hành thương mại tòa nhà chung cư và khu nhà trọ cao cấp:
- Nhân viên kỹ thuật và bảo vệ xử lý nhanh sự cố trên điện thoại di động.
- Tuy nhiên, **Kế toán trưởng và Trưởng Ban Quản Lý (BQL)** làm việc hàng ngày trên máy tính để bàn (Desktop) hoặc trình duyệt Web (Laptop/PC màn hình lớn). Các thao tác chủ yếu gồm:
  1. Đối soát hàng trăm hóa đơn thanh toán từ ngân hàng (VietQR Napas 247).
  2. Phát hành hóa đơn hàng loạt đầu tháng.
  3. Gửi nhắc nợ hàng loạt cho các căn hộ quá hạn.
  4. Xuất sổ sách báo cáo kế toán ra file Excel để lưu trữ và báo cáo Ban Quản Trị.
- Giao diện mobile hẹp với thanh BottomNavigationBar ở đáy và thẻ dạng dọc không tận dụng được không gian ngang của màn hình máy tính ($1024\text{dp} - 1920\text{dp}$), gây chậm trễ thao tác cho kế toán.

### 1.2. Mục tiêu cụ thể
1. **Kiến trúc thích ứng (Adaptive Layout)**:
   - Tự động nhận diện breakpoint độ rộng màn hình ($900\text{dp}$):
     * **Màn hình lớn ($\ge 900\text{dp}$)**: Tự động chuyển sang **Sidebar điều hướng cố định bên trái (Navigation Sidebar)** chuyên nghiệp, chứa đầy đủ các phân hệ quản lý và thông tin tòa nhà/gói dịch vụ.
     * **Màn hình di động ($< 900\text{dp}$)**: Giữ nguyên bố cục mobile chuẩn với BottomNavigationBar.
2. **Trạm làm việc Kế toán & Đối soát bảng lớn (Accounting Web Workstation)**:
   - **Bảng dữ liệu nhiều cột (`PaginatedDataTable`)**: Hiển thị chi tiết từng căn hộ, chủ hộ, kỳ thu, các khoản phí thành phần (phí dịch vụ, điện, nước, gửi xe), tổng tiền, mã giao dịch VietQR, trạng thái thanh toán và ngày thu.
   - **Thao tác hàng loạt (Bulk Operations Toolbar)**:
     * Checkbox chọn nhiều dòng hoặc chọn toàn bộ trang.
     * Nút "Phát hành hóa đơn đã chọn".
     * Nút "Gửi thông báo nhắc nợ nhóm".
     * Nút "Xuất file Excel đối soát ngân hàng".
   - **Thanh tóm tắt KPI tài chính tức thời (Top KPI Strip)**: Tổng phải thu, Thực thu, Nợ đọng quá hạn, Tỷ lệ thu hồi nợ (%).
   - **Bộ lọc đa tiêu chí linh hoạt**: Tìm kiếm theo mã căn / tên cư dân, lọc theo kỳ thu, lọc theo trạng thái thanh toán.

---

## 2. Kiến Trúc Giao Diện & Bố Cục Thích Ứng

### 2.1. Breakpoints
- **Mobile / Phone**: Width $< 900\text{dp}$ $\rightarrow$ Mobile Layout (AppBar + IndexedStack + NavigationBar ở đáy).
- **Tablet Ngang / Desktop / Web**: Width $\ge 900\text{dp}$ $\rightarrow$ Workstation Layout (Sidebar bên trái cố định $240\text{dp} - 260\text{dp}$, Top Header Bar và khu vực nội dung chính co giãn linh hoạt).

### 2.2. Thành phần Sidebar (Trình duyệt Web/Desktop)
- **Header Sidebar**: Logo PKA-Home, Tên tòa nhà hiện hành (`BuildingSwitcherDropdown`), Badge trạng thái gói SaaS (`Gói Nâng Cao`, số ngày còn lại).
- **Danh mục chức năng chính (Menu Tree)**:
  1. 📊 **Tổng quan**: KPI vận hành & biểu đồ.
  2. 📑 **Bàn làm việc Kế toán (Workstation)**: Bảng dữ liệu lớn, đối soát VietQR & phát hành hàng loạt.
  3. 📈 **Báo cáo tài chính & Tuổi nợ**: 4 xô nợ và sổ cái quỹ bảo trì.
  4. 🏢 **Căn hộ & Cư dân**: Danh sách, hồ sơ 360, nhập Excel hàng loạt (B2).
  5. ⚡ **Chỉ số điện nước**: Danh sách công tơ, duyệt chỉ số.
  6. 🛠️ **Sự cố & Thiết bị**: Xử lý phản ánh và kế hoạch bảo trì.
  7. 💳 **Gói dịch vụ SaaS (B3)**: Hạn mức tòa nhà và nâng cấp.
- **Footer Sidebar**: Thông tin tài khoản đăng nhập, nút Đổi cỡ chữ, Giao diện và Đăng xuất.

### 2.3. Bàn Làm Việc Kế Toán (`AccountingWebWorkstationScreen`)
- **Top KPI Strip (4 thẻ)**:
  - Tổng số hóa đơn kỳ này.
  - Tổng tiền phải thu (VNĐ).
  - Đã thu thực tế (VNĐ).
  - Nợ đọng quá hạn (VNĐ) kèm Tỷ lệ thu hồi (%).
- **Hàng công cụ bộ lọc (Filter & Search Bar)**:
  - Ô tìm kiếm tức thời (mã căn, tên người nộp, mã VietQR).
  - Dropdown chọn kỳ thu (`YYYY-MM`).
  - Dropdown lọc trạng thái (`Tất cả`, `Đã thanh toán`, `Chưa thanh toán`, `Quá hạn`).
- **Thanh hành động hàng loạt (Bulk Actions Bar)**:
  - Hiện ra khi người dùng chọn $\ge 1$ dòng.
  - Hiển thị số dòng đang chọn: *"Đã chọn $K$ hóa đơn"*.
  - Các nút hành động: (1) Phát hành hàng loạt, (2) Nhắc nợ hàng loạt, (3) Xuất Excel.
- **Bảng dữ liệu nhiều cột (`PaginatedDataTable`)**:
  - Hỗ trợ sắp xếp theo cột (mã căn, số tiền, ngày).
  - Phân trang 10 / 25 / 50 dòng mỗi trang.

---

## 3. Kiến Trúc Dữ Liệu & State Management

### 3.1. Models (`lib/data/models/`)
- `accounting_workstation_model.dart`:
  - `AccountingWorkstationFilter`: Quản lý tiêu chí lọc (kỳ thu, trạng thái, chuỗi tìm kiếm, tòa nhà).
  - `AccountingWorkstationSummary`: Thống kê tổng quan KPI phục vụ thanh Strip trên đầu trang.
  - `InvoiceTableRowItem`: Ánh xạ dữ liệu dòng bảng tính cho kế toán (mã căn, người nộp, kỳ thu, tiền phòng, điện nước, tổng cộng, trạng thái, mã tra cứu/VietQR, ngày thanh toán).

### 3.2. Providers (`lib/data/providers/`)
- `accounting_workstation_provider.dart`:
  - `accountingWorkstationFilterProvider`: Quản lý bộ lọc hiện tại.
  - `accountingWorkstationDataProvider`: `FutureProvider` tổng hợp danh sách hóa đơn theo bộ lọc từ `InvoiceRepository` và tính toán `AccountingWorkstationSummary`.
  - `selectedInvoiceIdsProvider`: `StateProvider<Set<String>>` quản lý danh sách các ID hóa đơn đang được chọn trong bảng.

---

## 4. Kế Hoạch Kiểm Thử & Tiêu Chí Nghiệm Thu

1. **Unit Test Models & Calculations**:
   - `test/data/models/accounting_workstation_model_test.dart`: Thẩm định tính toán tỷ lệ thu hồi nợ, lọc chuỗi tìm kiếm và chuyển đổi dữ liệu dòng bảng.
2. **Widget Test Adaptive Layout**:
   - `test/features/management/widgets/adaptive_management_scaffold_test.dart`:
     * Kiểm tra hiển thị `NavigationBar` đáy trên màn hình mobile ($400\text{dp}$).
     * Kiểm tra hiển thị `NavigationRail` / Sidebar cố định bên trái trên màn hình desktop ($1200\text{dp}$).
3. **Widget Test Accounting Web Workstation**:
   - `test/features/management/screens/accounting_web_workstation_screen_test.dart`:
     * Kiểm tra render các thẻ KPI, ô tìm kiếm và bảng dữ liệu nhiều cột.
     * Kiểm tra chọn checkbox hàng loạt và hiển thị thanh Bulk Actions Bar.
     * Kiểm tra nút xuất file Excel.
4. **Tiêu chuẩn chất lượng**:
   - `dart analyze`: 0 issues.
   - `flutter test`: 100% tests pass.
