# Kế Hoạch Thực Thi: Giai Đoạn C - Chuẩn Hoá Nghiệp Vụ Thương Mại (VietQR Napas 247, Biên Lai Điện Tử & Đối Soát Kế Toán)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chuyển đổi toàn diện phương thức thanh toán sang VietQR thật chuẩn Napas 247 (EMVCo) sinh trực tiếp ngoại tuyến, cung cấp biên lai thu tiền điện tử (E-Receipt) kèm mã tra cứu và số tiền đọc bằng chữ tiếng Việt, cùng dịch vụ xuất báo cáo kế toán đối soát ra file Excel (.xlsx).

**Architecture:**
- Database: Migration `20261027_04_commercial_banking_and_receipts.sql` bổ sung thông tin ngân hàng thụ hưởng vào `buildings`, trường chứng từ (`receipt_number`, `einvoice_lookup_code`, `paid_amount`) vào `invoices`/`payment_transactions` và RPC `generate_receipt_number`.
- Utilities: `VietQrGenerator` (chuẩn EMVCo TLV Napas 247 + CRC16-CCITT) và `VietnameseCurrencyWords` (chuyển đổi số tiền thành chữ tiếng Việt chuẩn ngữ pháp).
- Flutter UI: `UnifiedPaymentSheet` hiển thị mã VietQR thật theo tài khoản ngân hàng của tòa nhà (loại bỏ hoàn toàn watermark `DEMO ONLY`); `ElectronicReceiptSheet` hiển thị phiếu thu điện tử; Nút "Xuất báo cáo Excel" trên `InvoiceManagementScreen`.
- Data Services: `AccountingExportService` sử dụng package `excel` để kết xuất bảng kê đối soát thu phí và công nợ.

**Tech Stack:** Flutter, Dart, Riverpod, PostgreSQL 15+, Supabase, Excel (.xlsx), QR Flutter.

## Global Constraints

- Tuân thủ 100% tiếng Việt chuẩn trong nhãn UI theo `design-rules.md`.
- Toàn bộ commit thực hiện trực tiếp trên nhánh `main` theo quy định `AGENTS.md`.
- Đảm bảo 444+ tests hiện có tiếp tục vượt qua 100%.
- TDD: Viết test trước, xác nhận fail, viết code, xác nhận pass.

---

### Task 1: Database Migration Thông Tin Ngân Hàng Tòa Nhà & Chứng Từ Kế Toán

**Files:**
- Create: `supabase/migrations/20261027_04_commercial_banking_and_receipts.sql`
- Test: `test/integration/commercial_banking_and_receipts_migration_test.dart`

**Interfaces:**
- Consumes: Bảng `buildings`, `invoices`, `payment_transactions`.
- Produces: 
  - Cột `bank_bin`, `bank_name`, `bank_account_number`, `bank_account_name` trên bảng `buildings`.
  - Cột `receipt_number`, `einvoice_lookup_code`, `paid_amount` trên `invoices` và `payment_transactions`.
  - RPC `public.generate_receipt_number(p_invoice_id UUID)`.

- [ ] **Step 1: Viết test kiểm tra migration**
Tạo file `test/integration/commercial_banking_and_receipts_migration_test.dart`.

- [ ] **Step 2: Chạy test để xác nhận FAIL (TDD)**
Chạy: `flutter test test/integration/commercial_banking_and_receipts_migration_test.dart`

- [ ] **Step 3: Viết migration `20261027_04_commercial_banking_and_receipts.sql`**
Viết DDL thêm cột vào các bảng và tạo hàm `generate_receipt_number`.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Chạy: `flutter test test/integration/commercial_banking_and_receipts_migration_test.dart`

- [ ] **Step 5: Commit migration**
```bash
git add supabase/migrations/20261027_04_commercial_banking_and_receipts.sql test/integration/commercial_banking_and_receipts_migration_test.dart ; git commit -m "feat(db): migration ngan hang toa nha va chung tu bien lai dien tu"
```

---

### Task 2: VietQR EMVCo Generator & Tiện Ích Đọc Số Tiền Tiếng Việt

**Files:**
- Create: `lib/core/utils/vietqr_generator.dart`
- Create: `lib/core/utils/vietnamese_currency_words.dart`
- Test: `test/core/utils/vietqr_generator_test.dart`
- Test: `test/core/utils/vietnamese_currency_words_test.dart`

**Interfaces:**
- Produces:
  - `VietQrGenerator.generate({required String bankBin, required String bankAccount, required double amount, required String memo, String? accountName})`: trả về chuỗi EMVCo Napas 247 hợp lệ có CRC16.
  - `VietnameseCurrencyWords.toVietnameseWords(double amount)`: trả về chuỗi đọc tiền chuẩn tiếng Việt.

- [ ] **Step 1: Viết test cho VietQrGenerator và VietnameseCurrencyWords**
Tạo `test/core/utils/vietqr_generator_test.dart` và `test/core/utils/vietnamese_currency_words_test.dart`.

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Chạy: `flutter test test/core/utils/vietqr_generator_test.dart test/core/utils/vietnamese_currency_words_test.dart`

- [ ] **Step 3: Triển khai `vietqr_generator.dart` và `vietnamese_currency_words.dart`**
Viết thuật toán đóng gói chuỗi TLV EMVCo kèm CRC16-CCITT và thuật toán đọc số tiền tiếng Việt.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Chạy: `flutter test test/core/utils/vietqr_generator_test.dart test/core/utils/vietnamese_currency_words_test.dart`

- [ ] **Step 5: Commit Utilities**
```bash
git add lib/core/utils/vietqr_generator.dart lib/core/utils/vietnamese_currency_words.dart test/core/utils/vietqr_generator_test.dart test/core/utils/vietnamese_currency_words_test.dart ; git commit -m "feat(utils): them vietqr emvco generator va tien ich doc so tien tieng viet"
```

---

### Task 3: Tích Hợp VietQR Thật vào UnifiedPaymentSheet

**Files:**
- Modify: `lib/data/models/building_model.dart`
- Modify: `lib/core/widgets/unified_payment_sheet.dart`
- Test: `test/core/widgets/unified_payment_sheet_vietqr_test.dart`

**Interfaces:**
- Consumes: `activeBuildingProvider`, `VietQrGenerator`.
- Produces: `UnifiedPaymentSheet` hiển thị mã VietQR thật (không có watermark DEMO ONLY, dùng tên ngân hàng và số tài khoản của tòa nhà).

- [ ] **Step 1: Viết test cho UnifiedPaymentSheet hiển thị VietQR thật**
Tạo file `test/core/widgets/unified_payment_sheet_vietqr_test.dart`.

- [ ] **Step 2: Cập nhật `building_model.dart` và `unified_payment_sheet.dart`**
Bổ sung trường ngân hàng vào `BuildingModel` và cập nhật giao diện chọn chuyển khoản VietQR trong `UnifiedPaymentSheet`.

- [ ] **Step 3: Chạy test để xác nhận PASS**
Chạy: `flutter test test/core/widgets/unified_payment_sheet_vietqr_test.dart`

- [ ] **Step 4: Commit VietQR Sheet**
```bash
git add lib/data/models/building_model.dart lib/core/widgets/unified_payment_sheet.dart test/core/widgets/unified_payment_sheet_vietqr_test.dart ; git commit -m "feat(payment): tich hop vietqr emvco that vao unified payment sheet"
```

---

### Task 4: Giao Diện Biên Lai Điện Tử (ElectronicReceiptSheet)

**Files:**
- Create: `lib/core/widgets/electronic_receipt_sheet.dart`
- Modify: `lib/features/management/screens/management_invoice_detail_screen.dart`
- Test: `test/core/widgets/electronic_receipt_sheet_test.dart`

**Interfaces:**
- Consumes: `InvoiceModel`, `VietnameseCurrencyWords`.
- Produces: Modal Sheet hiển thị mẫu phiếu thu chuẩn mực có số phiếu thu `PT-...`, mã tra cứu, danh mục phí, số tiền bằng số và bằng chữ, nút chia sẻ.

- [ ] **Step 1: Viết test cho `ElectronicReceiptSheet`**
Tạo file `test/core/widgets/electronic_receipt_sheet_test.dart`.

- [ ] **Step 2: Tạo `electronic_receipt_sheet.dart` và tích hợp nút xem biên lai**
Xây dựng widget phiếu thu điện tử và gắn nút "Xem biên lai thu tiền" trong màn hình chi tiết hóa đơn đã thanh toán.

- [ ] **Step 3: Chạy test để xác nhận PASS**
Chạy: `flutter test test/core/widgets/electronic_receipt_sheet_test.dart`

- [ ] **Step 4: Commit Biên lai điện tử**
```bash
git add lib/core/widgets/electronic_receipt_sheet.dart lib/features/management/screens/management_invoice_detail_screen.dart test/core/widgets/electronic_receipt_sheet_test.dart ; git commit -m "feat(finance): them giao dien bien lai thu tien dien tu electronic receipt sheet"
```

---

### Task 5: Dịch Vụ Xuất Báo Cáo Đối Soát Kế Toán Ra File Excel

**Files:**
- Create: `lib/data/services/accounting_export_service.dart`
- Modify: `lib/features/management/screens/invoice_management_screen.dart`
- Test: `test/data/services/accounting_export_service_test.dart`

**Interfaces:**
- Consumes: Package `excel`, `InvoiceModel`, `ApartmentModel`.
- Produces: `AccountingExportService.exportInvoicesToExcel(List<InvoiceModel>, String buildingName, String period)` tạo file `.xlsx` và kích hoạt chia sẻ / lưu trữ.

- [ ] **Step 1: Viết test cho `AccountingExportService`**
Tạo file `test/data/services/accounting_export_service_test.dart`.

- [ ] **Step 2: Triển khai `accounting_export_service.dart` và nút bấm trên màn hình**
Xây dựng logic tạo workbook Excel với các cột dữ liệu đối soát và gắn nút "Xuất Excel" trên AppBar của `InvoiceManagementScreen`.

- [ ] **Step 3: Chạy test để xác nhận PASS**
Chạy: `flutter test test/data/services/accounting_export_service_test.dart`

- [ ] **Step 4: Commit Dịch vụ Xuất Báo Cáo Kế Toán**
```bash
git add lib/data/services/accounting_export_service.dart lib/features/management/screens/invoice_management_screen.dart test/data/services/accounting_export_service_test.dart ; git commit -m "feat(accounting): them dich vu xuat bao cao doi soat ke toan excel"
```

---

### Task 6: Rà Soát Toàn Diện & Verification Hồi Quy

**Files:** Toàn bộ dự án

- [ ] **Step 1: Chạy `flutter analyze`**
Đảm bảo 0 errors, 0 warnings.

- [ ] **Step 2: Chạy toàn bộ test suite `flutter test`**
Đảm bảo 100% tests PASS (bao gồm 444 tests cũ + toàn bộ tests mới của Phase C).

- [ ] **Step 3: Commit hoàn tất Giai đoạn C**
```bash
git commit --allow-empty -m "chore: hoan thanh xac minh giai doan C vietqr, bien lai va ke toan"
```
