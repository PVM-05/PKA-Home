# Kế Hoạch Triển Khai: Hóa Đơn Điện Tử, Biên Lai PDF & Tra Cứu Mã QR (C4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng bộ máy sinh chứng từ PDF vector chuẩn hóa (Hóa đơn dịch vụ A4, Biên lai thu tiền điện tử A4 có dấu mộc số BQL, Phiếu in nhiệt 80mm), tiện ích đọc số tiền thành chữ tiếng Việt, cơ chế sinh mã tra cứu bảo mật (`lookup_code`) và màn hình tra cứu đối soát chứng từ trực tuyến.

**Architecture:** Sử dụng Migration PostgreSQL Supabase để quản lý `lookup_code` và RPC tra cứu an toàn `verify_document_lookup`; phía Flutter sử dụng bộ đôi `pdf` + `printing`, nhúng font Unicode tiếng Việt, tạo `DocumentPdfBuilder` để render vector sắc nét, hỗ trợ xem trước, in trực tiếp (Wifi/Bluetooth/AirPrint), tải file và chia sẻ qua Zalo/Email.

**Tech Stack:** Flutter 3.x, Dart 3.x, Supabase (PostgreSQL, RLS, RPC), `pdf: ^3.10.8`, `printing: ^5.13.2`, `qr_flutter: ^4.1.0`, `share_plus: ^10.1.4`, `flutter_riverpod`, `intl`.

## Global Constraints
- Toàn bộ commit trực tiếp vào nhánh `main` (không tạo branch phụ/worktree).
- Tuân thủ nghiêm ngặt quy trình TDD (viết test -> xác nhận fail -> triển khai -> xác nhận pass -> commit).
- Định dạng mã căn hộ chuẩn: `A0110` / `a0110`.
- Ngôn ngữ UI: 100% tiếng Việt chuẩn mực theo `design-rules.md`.
- Định dạng thời gian: `dd/MM/yyyy` cho ngày, `dd/MM/yyyy HH:mm` cho thời gian chi tiết.
- Định dạng tiền tệ: `#,##0 đ` (VD: `1.250.000 đ`).

---

### Task 1: Migration Cơ Sở Dữ Liệu & RPC Tra Cứu (Supabase/PostgreSQL)

**Files:**
- Create: `supabase/migrations/20261029_05_electronic_invoice_and_lookup_engine.sql`
- Test: `test/integration/electronic_invoice_migration_test.dart`

**Interfaces:**
- Consumes: `invoices(id)`, `apartments(id, code)`, `buildings(name, code)`
- Produces:
  - Cột `public.invoices.lookup_code` (VARCHAR(32) UNIQUE)
  - Trigger `trg_ensure_invoice_lookup_code`: Tự động sinh mã `INV-YYYYMM-XXXXX` khi thêm hóa đơn nếu rỗng
  - RPC `verify_document_lookup(p_lookup_code TEXT)`: Trả về JSONB thông tin xác thực hóa đơn / biên lai

- [ ] **Step 1: Viết integration test cho migration**
Viết `test/integration/electronic_invoice_migration_test.dart` kiểm tra file migration tồn tại, chứa lệnh `ADD COLUMN lookup_code`, định nghĩa trigger tự sinh mã và RPC `verify_document_lookup`.

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Chạy `flutter test test/integration/electronic_invoice_migration_test.dart` xác nhận FAIL.

- [ ] **Step 3: Viết migration SQL**
Tạo `supabase/migrations/20261029_05_electronic_invoice_and_lookup_engine.sql` định nghĩa đầy đủ schema, backfill mã tra cứu cho các hóa đơn hiện hữu và RPC `verify_document_lookup`.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Chạy lại test, đảm bảo PASS 100%.

- [ ] **Step 5: Commit vào git**
```bash
git add supabase/migrations/20261029_05_electronic_invoice_and_lookup_engine.sql test/integration/electronic_invoice_migration_test.dart
git commit -m "feat(db): migration lookup_code va rpc tra cuu hoa don bien lai C4"
```

---

### Task 2: Cài Đặt Dependencies, Model Tra Cứu & Tiện Ích Đọc Tiền Bằng Chữ (Dart)

**Files:**
- Modify: `pubspec.yaml`
- Create:
  - `lib/data/models/document_lookup_result_model.dart`
  - `lib/core/utils/vietnamese_currency_text_formatter.dart`
- Test:
  - `test/data/models/document_lookup_result_model_test.dart`
  - `test/core/utils/vietnamese_currency_text_formatter_test.dart`

**Interfaces:**
- Consumes: Số tiền `num amount`
- Produces:
  - `DocumentLookupResultModel`: Ánh xạ kết quả JSON từ RPC `verify_document_lookup`
  - `VietnameseCurrencyTextFormatter.toWords(num amount)`: Trả về chuỗi tiếng Việt chuẩn mực (VD: `1250000` -> `"Một triệu hai trăm năm mươi nghìn đồng"`)

- [x] **Step 1: Thêm dependencies vào pubspec.yaml & chạy flutter pub get**
Bổ sung `pdf: ^3.10.8` và `printing: ^5.13.2` vào `pubspec.yaml`. Chạy `flutter pub get`.

- [x] **Step 2: Viết unit tests cho Model & Tiện ích đọc tiền bằng chữ**
Tạo các test case bao quát: 0 đ, hàng chục, trăm, nghìn, triệu, tỷ, các trường hợp đặc biệt ("linh", "mốt", "lăm", "mười").

- [x] **Step 3: Chạy test để xác nhận FAIL**
Chạy `flutter test test/data/models/document_lookup_result_model_test.dart test/core/utils/vietnamese_currency_text_formatter_test.dart` xác nhận FAIL.

- [x] **Step 4: Triển khai Model & Tiện ích đọc tiền**
Viết `DocumentLookupResultModel` và thuật toán đọc tiền `VietnameseCurrencyTextFormatter`.

- [x] **Step 5: Chạy test để xác nhận PASS**
Chạy test, đảm bảo PASS 100%.

- [x] **Step 6: Commit vào git**
```bash
git add pubspec.yaml pubspec.lock lib/data/models/document_lookup_result_model.dart lib/core/utils/vietnamese_currency_text_formatter.dart test/data/models/document_lookup_result_model_test.dart test/core/utils/vietnamese_currency_text_formatter_test.dart
git commit -m "feat(core): them tien ich doc tien bang chu va model tra cuu C4"
```

---

### Task 3: Document PDF Builder Engine (A4 Hóa Đơn, A4 Biên Lai & 80mm In Nhiệt)

**Files:**
- Create: `lib/core/utils/document_pdf_builder.dart`
- Test: `test/core/utils/document_pdf_builder_test.dart`

**Interfaces:**
- Consumes: `InvoiceModel`, `List<Map<String, dynamic>> items`, `VietnameseCurrencyTextFormatter`
- Produces:
  - `DocumentPdfBuilder.buildInvoicePdfA4(...)`: Trả về `Future<Uint8List>` của Hóa đơn phí dịch vụ A4 (bảng phí, số tiền bằng chữ, mã VietQR hoặc QR tra cứu).
  - `DocumentPdfBuilder.buildReceiptPdfA4(...)`: Trả về `Future<Uint8List>` của Biên lai thu tiền A4 (mã biên lai, thông tin đối soát, con dấu mộc số điện tử "ĐÃ THU TIỀN", chữ ký).
  - `DocumentPdfBuilder.buildReceiptPdf80mm(...)`: Trả về `Future<Uint8List>` của Phiếu in nhiệt cuộn 80mm POS.

- [x] **Step 1: Viết unit tests cho `DocumentPdfBuilder`**
Kiểm thử tạo byte PDF hợp lệ (%PDF-1.), kích thước trang chuẩn A4 và Roll 80mm, không bị lỗi font hoặc null exceptions.

- [x] **Step 2: Chạy test để xác nhận FAIL**
Chạy `flutter test test/core/utils/document_pdf_builder_test.dart` xác nhận FAIL.

- [x] **Step 3: Triển khai `DocumentPdfBuilder`**
Dựng layout PDF vector bằng thư viện `pdf/widgets.dart`, sử dụng font Unicode tiếng Việt, vẽ vector con dấu điện tử BQL.

- [x] **Step 4: Chạy test để xác nhận PASS**
Chạy test, đảm bảo PASS 100%.

- [x] **Step 5: Commit vào git**
```bash
git add lib/core/utils/document_pdf_builder.dart test/core/utils/document_pdf_builder_test.dart
git commit -m "feat(pdf): engine sinh pdf hoa don a4 bien lai dien tu va phieu nhiet 80mm C4"
```

---

### Task 4: Repository, Riverpod Providers & Màn Hình Tra Cứu Chứng Từ

**Files:**
- Create:
  - `lib/data/repositories/document_repository.dart`
  - `lib/data/providers/document_providers.dart`
  - `lib/features/document/screens/document_lookup_screen.dart`
- Test:
  - `test/data/repositories/document_repository_test.dart`
  - `test/features/document/screens/document_lookup_screen_test.dart`

**Interfaces:**
- Consumes: `SupabaseClient`, `DocumentLookupResultModel`
- Produces:
  - `DocumentRepository.verifyLookupCode(String lookupCode)`
  - Providers: `documentRepositoryProvider`, `documentLookupProvider`
  - `DocumentLookupScreen`: Màn hình tra cứu chứng từ (nhập mã, hiển thị trạng thái hợp lệ, thông tin đối soát hoặc báo lỗi).

- [x] **Step 1: Viết test cho Repository & `DocumentLookupScreen`**
Kiểm thử gọi RPC tra cứu và hiển thị kết quả xác thực trên UI.

- [x] **Step 2: Chạy test để xác nhận FAIL**
Chạy test, xác nhận FAIL.

- [x] **Step 3: Triển khai Repository, Providers & Screen**
Viết `DocumentRepository`, `document_providers.dart` và `DocumentLookupScreen`.

- [x] **Step 4: Chạy test để xác nhận PASS**
Chạy test, đảm bảo PASS 100%.

- [x] **Step 5: Commit vào git**
```bash
git add lib/data/repositories/document_repository.dart lib/data/providers/document_providers.dart lib/features/document/screens/document_lookup_screen.dart test/data/repositories/document_repository_test.dart test/features/document/screens/document_lookup_screen_test.dart
git commit -m "feat(lookup): them repository provider va man hinh tra cuu chung tu C4"
```

---

### Task 5: Document Preview Screen & Tích Hợp Xuất PDF Trên Màn Hình Hóa Đơn

**Files:**
- Create: `lib/features/document/screens/document_preview_screen.dart`
- Modify:
  - `lib/features/resident/screens/resident_invoice_detail_screen.dart`
  - `lib/features/management/screens/management_invoice_detail_screen.dart`
- Test:
  - `test/features/document/screens/document_preview_screen_test.dart`
  - `test/features/resident/resident_invoice_pdf_export_ui_test.dart`

**Interfaces:**
- Consumes: `DocumentPdfBuilder`, `PdfPreview` từ `printing`
- Produces:
  - `DocumentPreviewScreen`: Màn hình xem trước toàn trang, In trực tiếp, Tải xuống và Chia sẻ file PDF.
  - Tích hợp nút "Xuất PDF / Biên lai" trên AppBar và action buttons của `ResidentInvoiceDetailScreen` và `ManagementInvoiceDetailScreen`.

- [ ] **Step 1: Viết widget test cho `DocumentPreviewScreen` & tích hợp nút xuất PDF**
Kiểm thử nút xuất PDF mở màn hình preview và cho phép chọn định dạng (A4 Hóa đơn, A4 Biên lai, Phiếu nhiệt 80mm).

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Chạy test, xác nhận FAIL.

- [ ] **Step 3: Triển khai Screen Preview & Cập nhật màn hình chi tiết**
Viết `DocumentPreviewScreen` và cập nhật 2 màn hình hóa đơn cư dân và BQL.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Chạy test, đảm bảo PASS 100%.

- [ ] **Step 5: Commit vào git**
```bash
git add lib/features/document/screens/document_preview_screen.dart lib/features/resident/screens/resident_invoice_detail_screen.dart lib/features/management/screens/management_invoice_detail_screen.dart test/features/document/screens/document_preview_screen_test.dart test/features/resident/resident_invoice_pdf_export_ui_test.dart
git commit -m "feat(ui): man hinh xem truoc in an chia se pdf va tich hop nut xuat hoa don C4"
```

---

### Task 6: Toàn Bộ Verification, Static Analysis & Cập Nhật Lộ Trình Thương Mại

**Files:**
- Modify: `docs/COMMERCIAL_PRODUCT_ROADMAP.md`
- Test: Toàn bộ test suite `flutter test`, `flutter analyze`

- [ ] **Step 1: Chạy toàn bộ test suite**
Chạy `flutter test` đảm bảo 100% tests vượt qua không có lỗi hay hồi quy.

- [ ] **Step 2: Chạy static analysis**
Chạy `flutter analyze` đảm bảo 0 cảnh báo, 0 lỗi.

- [ ] **Step 3: Cập nhật lộ trình thương mại**
Đánh dấu `[x] C4. Hóa đơn điện tử & Chứng từ` trong `docs/COMMERCIAL_PRODUCT_ROADMAP.md`.

- [ ] **Step 4: Commit hoàn tất**
```bash
git add docs/COMMERCIAL_PRODUCT_ROADMAP.md docs/superpowers/plans/2026-10-29-electronic-invoice-pdf-and-receipt-engine.md
git commit -m "docs: hoan thanh C4 hoa don dien tu bien lai pdf va tra cuu ma qr trong lo trinh thuong mai"
```

