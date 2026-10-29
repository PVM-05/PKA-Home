# Kế Hoạch Triển Khai: Sổ Cái Công Nợ Căn Hộ, Phiếu Điều Chỉnh & Hóa Đơn Bất Biến (C1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng hệ thống sổ cái công nợ căn hộ Append-Only (`apartment_ledger_entries`), phiếu điều chỉnh công nợ (`credit_notes`), quản lý khóa sổ kỳ kế toán (`accounting_periods`), bảo vệ bất biến hóa đơn đã chốt và chuẩn hóa 100% hiển thị thời gian, tiền tệ theo phong cách người Việt.

**Architecture:** Sử dụng PostgreSQL Supabase với Migration 10, các trigger bảo vệ tính toàn vẹn và bất biến dữ liệu, RPCs ACID khóa hàng `FOR UPDATE`. Phía Flutter sử dụng kiến trúc Feature-first, Riverpod quản lý trạng thái, DateFormat chuẩn `dd/MM/yyyy HH:mm` và `Tháng MM/yyyy`.

**Tech Stack:** Flutter 3.x, Dart 3.x, Supabase (PostgreSQL, RLS, Triggers, RPCs), flutter_riverpod, intl.

## Global Constraints
- Commit trực tiếp vào nhánh `main` (không tạo branch phụ/worktree).
- Đặt tên file `snake_case`, class `UpperCamelCase`, provider `lowerCamelCase + Provider`.
- Định dạng mã căn hộ chuẩn `A0110` / `a0110`.
- Ngôn ngữ UI: 100% tiếng Việt chuẩn mực, không hardcode tiếng Anh lai tạp.
- Định dạng thời gian: `dd/MM/yyyy` cho ngày, `dd/MM/yyyy HH:mm` cho thời gian chi tiết, `Tháng MM/yyyy` cho kỳ kế toán.
- Định dạng tiền tệ: `#,##0 đ` (VD: `1.250.000 đ`).

---

### Task 1: Migration Cơ Sở Dữ Liệu (Bảng, Triggers, RLS & RPCs)

**Files:**
- Create: `supabase/migrations/20261029_03_apartment_ledger_and_credit_notes.sql`
- Test: `test/integration/apartment_ledger_migration_test.dart`

**Interfaces:**
- Consumes: `buildings(id)`, `apartments(id)`, `invoices(id)`, `users(id)`, `audit_logs`
- Produces:
  - Bảng: `public.accounting_periods`, `public.apartment_ledger_entries`, `public.credit_notes`
  - Trigger: `trg_enforce_invoice_immutability`, `trg_prevent_closed_period_mutation`, `trg_auto_post_ledger_on_invoice_paid`
  - RPCs: `record_apartment_ledger_entry`, `issue_credit_note`, `close_accounting_period`, `get_apartment_ledger_balance`

- [ ] **Step 1: Viết test kiểm tra migration**
Viết `test/integration/apartment_ledger_migration_test.dart` kiểm tra file migration tồn tại, chứa định nghĩa các bảng `accounting_periods`, `apartment_ledger_entries`, `credit_notes`, trigger `trg_enforce_invoice_immutability` và các RPCs cần thiết.

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Chạy `flutter test test/integration/apartment_ledger_migration_test.dart` và xác nhận thất bại do chưa có file migration.

- [ ] **Step 3: Viết migration SQL**
Tạo file `supabase/migrations/20261029_03_apartment_ledger_and_credit_notes.sql`:
- Tạo bảng `accounting_periods` (id, building_id, period, status, opened_at, closed_at, closed_by, notes, created_at, updated_at).
- Tạo bảng `apartment_ledger_entries` (id, building_id, apartment_id, entry_code, entry_type, amount, balance_after, period, reference_type, reference_id, description, created_by, created_at).
- Tạo bảng `credit_notes` (id, credit_note_code, building_id, apartment_id, invoice_id, note_type, amount, reason, status, approved_by, approved_at, created_at).
- Trigger bất biến `enforce_invoice_immutability`: Chặn `UPDATE total_amount, apartment_id, period` và chặn `DELETE` khi hóa đơn đã `paid` hoặc kỳ kế toán đã `CLOSED`.
- Trigger `prevent_closed_period_mutation` trên `apartment_ledger_entries`.
- Trigger tự động hạch toán `CREDIT` vào sổ cái khi hóa đơn chuyển sang `paid`.
- RPCs: `record_apartment_ledger_entry`, `issue_credit_note`, `close_accounting_period`, `get_apartment_ledger_balance`.
- RLS policies cho BQL và Cư dân.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Chạy `flutter test test/integration/apartment_ledger_migration_test.dart` đảm bảo pass 100%.

- [ ] **Step 5: Commit vào git**
```bash
git add supabase/migrations/20261029_03_apartment_ledger_and_credit_notes.sql test/integration/apartment_ledger_migration_test.dart
git commit -m "feat(db): migration so cai cong no can ho credit notes va hoa don bat bien C1"
```

---

### Task 2: Models & Serialization (Ledger Entry, Credit Note, Accounting Period)

**Files:**
- Create:
  - `lib/data/models/apartment_ledger_entry_model.dart`
  - `lib/data/models/credit_note_model.dart`
  - `lib/data/models/accounting_period_model.dart`
- Test:
  - `test/data/models/apartment_ledger_entry_model_test.dart`
  - `test/data/models/credit_note_model_test.dart`
  - `test/data/models/accounting_period_model_test.dart`

**Interfaces:**
- Consumes: JSON maps từ Supabase queries
- Produces:
  - `ApartmentLedgerEntryModel` (id, buildingId, apartmentId, entryCode, entryType, amount, balanceAfter, period, referenceType, referenceId, description, createdBy, createdAt, formattedCreatedAt, formattedAmount, formattedBalanceAfter, formattedPeriod)
  - `CreditNoteModel` (id, creditNoteCode, buildingId, apartmentId, invoiceId, noteType, amount, reason, status, approvedBy, approvedAt, createdAt, formattedCreatedAt, formattedAmount)
  - `AccountingPeriodModel` (id, buildingId, period, status, openedAt, closedAt, closedBy, notes, formattedPeriod, isClosed)

- [ ] **Step 1: Viết test cho các Models**
Viết unit test cho `fromJson`, `toJson`, các helper format tiếng Việt (`formattedCreatedAt` dạng `dd/MM/yyyy HH:mm`, `formattedPeriod` dạng `Tháng MM/yyyy`, tiền tệ `#,##0 đ`).

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Chạy `flutter test test/data/models/apartment_ledger_entry_model_test.dart` xác nhận FAIL.

- [ ] **Step 3: Triển khai các Model classes**
Tạo 3 file models tương ứng, triển khai đầy đủ các thuộc tính strongly-typed và helper format tiếng Việt với `intl`.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Chạy lại bộ test models, xác nhận PASS 100%.

- [ ] **Step 5: Commit vào git**
```bash
git add lib/data/models/ test/data/models/
git commit -m "feat(models): bo sung model so cai cong no phieu dieu chinh va ky ke toan"
```

---

### Task 3: Repository & Riverpod Providers (Accounting Subsystem)

**Files:**
- Create:
  - `lib/data/repositories/accounting_repository.dart`
  - `lib/data/providers/accounting_providers.dart`
- Test:
  - `test/data/repositories/accounting_repository_test.dart`
  - `test/data/providers/accounting_providers_test.dart`

**Interfaces:**
- Consumes: `SupabaseClient`, `ApartmentLedgerEntryModel`, `CreditNoteModel`, `AccountingPeriodModel`
- Produces:
  - `AccountingRepository`:
    - `fetchLedgerEntries({required String apartmentId, String? period})`
    - `fetchApartmentBalance(String apartmentId)`
    - `fetchCreditNotes({required String buildingId, String? apartmentId})`
    - `fetchAccountingPeriods(String buildingId)`
    - `recordLedgerEntry(...)`
    - `issueCreditNote(...)`
    - `closeAccountingPeriod(...)`
  - Providers:
    - `accountingRepositoryProvider`
    - `apartmentLedgerEntriesProvider(apartmentId)`
    - `apartmentBalanceProvider(apartmentId)`
    - `accountingPeriodsProvider(buildingId)`
    - `creditNotesProvider(buildingId)`

- [ ] **Step 1: Viết unit tests cho Repository & Providers**
Tạo mock client, kiểm thử gọi đúng RPCs và queries, xử lý mapping dữ liệu an toàn.

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Chạy `flutter test test/data/repositories/accounting_repository_test.dart` xác nhận FAIL.

- [ ] **Step 3: Triển khai Repository & Providers**
Viết `AccountingRepository` và `accounting_providers.dart` gọi Supabase an toàn, chuẩn hóa kiểu dữ liệu strongly-typed.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Chạy test repository và providers, xác nhận PASS 100%.

- [ ] **Step 5: Commit vào git**
```bash
git add lib/data/repositories/accounting_repository.dart lib/data/providers/accounting_providers.dart test/data/repositories/accounting_repository_test.dart test/data/providers/accounting_providers_test.dart
git commit -m "feat(repo): them accounting_repository va riverpod providers cho so cai cong no"
```

---

### Task 4: Giao Diện Ban Quản Lý - Sổ Cái Công Nợ & Lập Phiếu Điều Chỉnh

**Files:**
- Create:
  - `lib/features/management/screens/apartment_ledger_screen.dart`
  - `lib/features/management/widgets/create_credit_note_dialog.dart`
  - `lib/features/management/widgets/close_period_dialog.dart`
- Test:
  - `test/features/management/apartment_ledger_screen_test.dart`

**Interfaces:**
- Consumes: `accountingRepositoryProvider`, `apartmentLedgerEntriesProvider`, `apartmentBalanceProvider`, `accountingPeriodsProvider`
- Produces:
  - `ApartmentLedgerScreen`: Màn hình xem sổ cái công nợ căn hộ, thẻ số dư (Xanh/Đỏ/Xanh dương), danh sách bút toán dòng thời gian chuẩn `dd/MM/yyyy HH:mm`.
  - `CreateCreditNoteDialog`: Form lập phiếu điều chỉnh công nợ (chọn hóa đơn, nhập lý do, số tiền).
  - `ClosePeriodDialog`: Xác nhận khóa sổ kỳ kế toán tháng.

- [ ] **Step 1: Viết widget test cho `ApartmentLedgerScreen`**
Kiểm thử hiển thị thẻ số dư công nợ, danh sách bút toán (thời gian `dd/MM/yyyy HH:mm`, mã bút toán, diễn giải, số dư lũy kế), và sự hiện diện của nút "Lập phiếu điều chỉnh" & "Khóa sổ kỳ".

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Chạy `flutter test test/features/management/apartment_ledger_screen_test.dart` xác nhận FAIL.

- [ ] **Step 3: Triển khai UI Widgets & Screen**
Viết màn hình `ApartmentLedgerScreen` và 2 dialog, tuân thủ 100% `design-rules.md`, sử dụng Material Icons, màu sắc từ Theme, word-wrap an toàn chống tràn pixel.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Chạy widget test, xác nhận PASS 100%.

- [ ] **Step 5: Commit vào git**
```bash
git add lib/features/management/screens/apartment_ledger_screen.dart lib/features/management/widgets/ test/features/management/apartment_ledger_screen_test.dart
git commit -m "feat(ui): them man hinh so cai cong no can ho va dialog lap phieu dieu chinh cho BQL"
```

---

### Task 5: Giao Diện Cư Dân - Minh Bạch Nghĩa Vụ Hóa Đơn & Sổ Phụ Căn Hộ

**Files:**
- Modify:
  - `lib/features/resident/screens/resident_invoice_detail_screen.dart`
- Create:
  - `lib/features/resident/widgets/resident_ledger_history_sheet.dart`
- Test:
  - `test/features/resident/resident_invoice_ledger_summary_test.dart`

**Interfaces:**
- Consumes: `apartmentBalanceProvider`, `apartmentLedgerEntriesProvider`
- Produces:
  - Thẻ tóm tắt nghĩa vụ thanh toán trên `ResidentInvoiceDetailScreen`:
    - `Dư nợ kỳ trước mang sang`: `...,... đ`
    - `Phí phát sinh kỳ này`: `...,... đ`
    - `Cấn trừ / Phiếu giảm nợ`: `-...,... đ`
    - `Tổng tiền thanh toán`: `...,... đ`
  - Nút/Modal `ResidentLedgerHistorySheet` cho phép cư dân xem minh bạch lịch sử giao dịch và đối soát của căn hộ mình.

- [ ] **Step 1: Viết widget test cho chi tiết hóa đơn cư dân**
Kiểm thử hiển thị phân rã nghĩa vụ nợ cũ + phát sinh mới và mở modal lịch sử đối soát công nợ.

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Chạy `flutter test test/features/resident/resident_invoice_ledger_summary_test.dart` xác nhận FAIL.

- [ ] **Step 3: Cập nhật `ResidentInvoiceDetailScreen` & tạo Modal**
Bổ sung widget thẻ nghĩa vụ tài chính và bottom sheet xem lịch sử bút toán theo chuẩn `dd/MM/yyyy HH:mm`.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Chạy widget test, xác nhận PASS 100%.

- [ ] **Step 5: Commit vào git**
```bash
git add lib/features/resident/screens/resident_invoice_detail_screen.dart lib/features/resident/widgets/ test/features/resident/resident_invoice_ledger_summary_test.dart
git commit -m "feat(ui): hien thi minh bach no ky truoc va lich su doi soat tren hoa don cu dan"
```

---

### Task 6: Toàn Bộ Verification, Phân Tích Static Analysis & Cập Nhật Roadmap

**Files:**
- Modify: `docs/COMMERCIAL_PRODUCT_ROADMAP.md`
- Test: Toàn bộ test suite `flutter test`, `dart analyze`

- [ ] **Step 1: Chạy toàn bộ test suite**
Chạy `flutter test` đảm bảo 100% tests vượt qua không có lỗi.

- [ ] **Step 2: Chạy static analysis**
Chạy `dart analyze lib test` đảm bảo 0 cảnh báo, 0 lỗi.

- [ ] **Step 3: Cập nhật tiến độ roadmap**
Đánh dấu `[x] C1. Sổ cái kế toán thật (ledger_entries)` trong `docs/COMMERCIAL_PRODUCT_ROADMAP.md`.

- [ ] **Step 4: Commit hoàn tất**
```bash
git add docs/COMMERCIAL_PRODUCT_ROADMAP.md
git commit -m "docs: cap nhat tien do hoan thanh C1 so cai cong no trong lo trinh thuong mai"
```
