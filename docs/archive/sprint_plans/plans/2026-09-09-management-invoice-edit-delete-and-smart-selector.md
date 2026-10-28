# Management Invoice Edit/Delete and Smart Selector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Thêm tính năng sửa và xóa hóa đơn cho Ban Quản Lý và tích hợp bộ chọn căn hộ thông minh (chỉ hiển thị căn có người ở và gom nhóm theo Tòa).

**Architecture:**
- Bổ sung `deleteInvoice` và `updateInvoice` trong `ManagementRepository`.
- Xây dựng bộ lọc căn hộ thông minh theo 2 cấp: Chọn Tòa nhà -> Chọn Căn hộ có người ở (`!isEmpty`).
- Xây dựng màn hình `EditInvoiceScreen` và gắn menu thao tác Sửa/Xóa trên `InvoiceManagementScreen` và `ManagementInvoiceDetailScreen`.

**Tech Stack:** Flutter, Flutter Riverpod, Supabase (PostgreSQL, Triggers).

---

### Task 1: Cập Nhật ManagementRepository (Xóa & Sửa Hóa Đơn) & Unit Test

**Files:**
- Modify: `lib/data/repositories/management_repository.dart`

**Interfaces:**
- `Future<void> deleteInvoice(String invoiceId)`
- `Future<void> updateInvoice({required String invoiceId, required String period, required DateTime dueDate, required List<Map<String, dynamic>> items, String? apartmentId})`

- [ ] **Step 1: Cài đặt `deleteInvoice` và `updateInvoice` trong `ManagementRepository`**
- `deleteInvoice`: Xóa hóa đơn bằng ID, Postgres CASCADE tự xóa `invoice_items`.
- `updateInvoice`: Cập nhật `invoices`, xóa `invoice_items` cũ và chèn `invoice_items` mới. Trigger Postgres tự tính lại `total_amount`.

- [ ] **Step 2: Chạy kiểm tra code analysis**
Chạy: `dart analyze lib/data/repositories/management_repository.dart`

- [ ] **Step 3: Commit**
```bash
git add lib/data/repositories/management_repository.dart
git commit -m "feat(invoice): thêm deleteInvoice và updateInvoice trong ManagementRepository"
```

---

### Task 2: Tích Hợp Bộ Chọn Căn Hộ Thông Minh Vào `CreateInvoiceScreen`

**Files:**
- Modify: `lib/features/management/screens/create_invoice_screen.dart`

**Interfaces:**
- UI: Bộ chọn 2 cấp: Hàng FilterChip chọn Tòa nhà (Tòa A, Tòa B...) + Dropdown chỉ hiện các căn hộ có người ở thuộc tòa đã chọn.

- [ ] **Step 1: Lọc căn hộ có người ở và gom nhóm theo Tòa trong `create_invoice_screen.dart`**
- Lọc `apartments.where((a) => !a.isEmpty).toList()`.
- Tạo state `String? _selectedBuilding`.
- Hiển thị danh sách FilterChip tòa nhà.
- Dropdown chỉ hiển thị các căn thuộc `_selectedBuilding`.

- [ ] **Step 2: Phân tích cú pháp**
Chạy: `dart analyze lib/features/management/screens/create_invoice_screen.dart`

- [ ] **Step 3: Commit**
```bash
git add lib/features/management/screens/create_invoice_screen.dart
git commit -m "feat(invoice): tích hợp bộ chọn căn hộ thông minh chỉ lọc căn có người ở theo tòa"
```

---

### Task 3: Xây Dựng Màn Hình Chỉnh Sửa Hóa Đơn (`EditInvoiceScreen`)

**Files:**
- Create: `lib/features/management/screens/edit_invoice_screen.dart`

**Interfaces:**
- Widget: `EditInvoiceScreen({required InvoiceModel invoice})`

- [ ] **Step 1: Tạo `edit_invoice_screen.dart`**
- Nạp sẵn chi tiết hóa đơn (lấy từ `invoiceDetailProvider(invoice.id)`).
- Cho phép chỉnh sửa Kỳ thanh toán, Hạn nộp, các chỉ số Điện, Nước, Xe máy, Ô tô, Phí quản lý.
- Tự động tính toán tổng tiền dự kiến theo thời gian thực.
- Nút "Lưu thay đổi": Gọi `managementRepo.updateInvoice(...)`, invalidate `invoicesProvider` và `invoiceDetailProvider`.

- [ ] **Step 2: Phân tích cú pháp**
Chạy: `dart analyze lib/features/management/screens/edit_invoice_screen.dart`

- [ ] **Step 3: Commit**
```bash
git add lib/features/management/screens/edit_invoice_screen.dart
git commit -m "feat(invoice): xây dựng màn hình chỉnh sửa hóa đơn EditInvoiceScreen"
```

---

### Task 4: Tích Hợp Thao Tác Sửa/Xóa Trên Danh Sách & Chi Tiết Hóa Đơn

**Files:**
- Modify: `lib/features/management/screens/invoice_management_screen.dart`
- Modify: `lib/features/management/screens/management_invoice_detail_screen.dart`

**Interfaces:**
- UI: `PopupMenuButton` [Sửa, Xóa] trên thẻ hóa đơn trong `InvoiceManagementScreen`.
- UI: AppBar Action icons [Sửa, Xóa] trong `ManagementInvoiceDetailScreen`.
- Dialog: `AlertDialog` xác nhận xóa hóa đơn an toàn.

- [ ] **Step 1: Thêm PopupMenuButton và Dialog xác nhận xóa trong `invoice_management_screen.dart`**
- [ ] **Step 2: Thêm Actions sửa/xóa trên AppBar trong `management_invoice_detail_screen.dart`**
- [ ] **Step 3: Chạy kiểm thử toàn bộ dự án**
Chạy: `dart analyze` và `flutter test`
Kỳ vọng: 0 lỗi, 100% tests pass.

- [ ] **Step 4: Commit**
```bash
git add lib/features/management/screens/invoice_management_screen.dart lib/features/management/screens/management_invoice_detail_screen.dart
git commit -m "feat(invoice): tích hợp menu thao tác sửa xóa trên danh sách và chi tiết hóa đơn bql"
```
