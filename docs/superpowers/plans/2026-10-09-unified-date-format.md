# Kế Hoạch Triển Khai: Chuẩn Hóa Toàn Diện Định Dạng Ngày Tháng (AppDateFormatter)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chuẩn hóa toàn bộ ngày tháng trên giao diện hiển thị sang chuẩn Việt Nam `dd/MM/yyyy` (và `dd/MM/yyyy HH:mm` khi có thời gian) thông qua lớp tiện ích tập trung `AppDateFormatter`.

**Architecture:** Tạo lớp `AppDateFormatter` tại `lib/core/utils/app_date_formatter.dart` có khả năng null-safe và tự động chuyển đổi múi giờ `toLocal()`. Rà soát và thay thế toàn bộ các khai báo `DateFormat` phân tán, lệch chuẩn ở phân hệ Cư dân, Ban quản lý và Core.

**Tech Stack:** Dart 3.x, Flutter 3.x, intl package, flutter_test.

## Global Constraints
- Tuân thủ quy định `coding-rules.md`, `design-rules.md`.
- 100% tiếng Việt chuẩn mực.
- Tuyệt đối không thay đổi các định dạng kỹ thuật backend (`yyyy-MM-dd` gửi lên API/Supabase và `yyyyMMdd_HHmmss` cho tên file export).
- Duy trì 100% pass toàn bộ test suite (269+ tests).

---

### Task 1: Xây Dựng Tiện Ích `AppDateFormatter` & Bộ Unit Test (TDD)

**Files:**
- Create: `lib/core/utils/app_date_formatter.dart`
- Create: `test/core/utils/app_date_formatter_test.dart`

**Interfaces:**
- Produces:
  - `AppDateFormatter.formatDate(DateTime? date, {String fallback = '-'}) -> String`
  - `AppDateFormatter.formatDateTime(DateTime? dateTime, {String fallback = '-'}) -> String`
  - `AppDateFormatter.formatDateTimeWithSeconds(DateTime? dateTime, {String fallback = '-'}) -> String`
  - `AppDateFormatter.formatPeriod(DateTime? date, {String fallback = '-'}) -> String`
  - `AppDateFormatter.formatDayMonth(DateTime? date, {String fallback = '-'}) -> String`
  - `AppDateFormatter.formatTime(DateTime? date, {String fallback = '-'}) -> String`

- [ ] **Step 1: Viết failing test cho `AppDateFormatter`**

```dart
// test/core/utils/app_date_formatter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pka_home/core/utils/app_date_formatter.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi', null);
  });

  group('AppDateFormatter Tests', () {
    final testDate = DateTime(2026, 10, 9, 14, 30, 45);

    test('formatDate trả về dd/MM/yyyy', () {
      expect(AppDateFormatter.formatDate(testDate), equals('09/10/2026'));
      expect(AppDateFormatter.formatDate(null), equals('-'));
      expect(AppDateFormatter.formatDate(null, fallback: 'N/A'), equals('N/A'));
    });

    test('formatDateTime trả về dd/MM/yyyy HH:mm', () {
      expect(AppDateFormatter.formatDateTime(testDate), equals('09/10/2026 14:30'));
      expect(AppDateFormatter.formatDateTime(null), equals('-'));
    });

    test('formatDateTimeWithSeconds trả về dd/MM/yyyy HH:mm:ss', () {
      expect(AppDateFormatter.formatDateTimeWithSeconds(testDate), equals('09/10/2026 14:30:45'));
      expect(AppDateFormatter.formatDateTimeWithSeconds(null), equals('-'));
    });

    test('formatPeriod trả về MM/yyyy', () {
      expect(AppDateFormatter.formatPeriod(testDate), equals('10/2026'));
      expect(AppDateFormatter.formatPeriod(null), equals('-'));
    });

    test('formatDayMonth trả về dd/MM', () {
      expect(AppDateFormatter.formatDayMonth(testDate), equals('09/10'));
      expect(AppDateFormatter.formatDayMonth(null), equals('-'));
    });

    test('formatTime trả về HH:mm', () {
      expect(AppDateFormatter.formatTime(testDate), equals('14:30'));
      expect(AppDateFormatter.formatTime(null), equals('-'));
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận FAIL**

Run: `flutter test test/core/utils/app_date_formatter_test.dart`
Expected: FAIL vì file `app_date_formatter.dart` chưa tồn tại.

- [ ] **Step 3: Cài đặt `AppDateFormatter`**

```dart
// lib/core/utils/app_date_formatter.dart
import 'package:intl/intl.dart';

/// Bộ tiện ích chuẩn hóa định dạng ngày tháng toàn ứng dụng PKA-Home
class AppDateFormatter {
  AppDateFormatter._();

  static final DateFormat _dateOnlyFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _dateTimeSecondsFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
  static final DateFormat _periodFormat = DateFormat('MM/yyyy');
  static final DateFormat _dayMonthFormat = DateFormat('dd/MM');
  static final DateFormat _timeOnlyFormat = DateFormat('HH:mm');

  /// Định dạng ngày: dd/MM/yyyy (VD: 09/10/2026)
  static String formatDate(DateTime? date, {String fallback = '-'}) {
    if (date == null) return fallback;
    return _dateOnlyFormat.format(date.toLocal());
  }

  /// Định dạng ngày giờ: dd/MM/yyyy HH:mm (VD: 09/10/2026 14:30)
  static String formatDateTime(DateTime? dateTime, {String fallback = '-'}) {
    if (dateTime == null) return fallback;
    return _dateTimeFormat.format(dateTime.toLocal());
  }

  /// Định dạng ngày giờ chi tiết có giây: dd/MM/yyyy HH:mm:ss
  static String formatDateTimeWithSeconds(DateTime? dateTime, {String fallback = '-'}) {
    if (dateTime == null) return fallback;
    return _dateTimeSecondsFormat.format(dateTime.toLocal());
  }

  /// Định dạng kỳ: MM/yyyy (VD: 10/2026)
  static String formatPeriod(DateTime? date, {String fallback = '-'}) {
    if (date == null) return fallback;
    return _periodFormat.format(date.toLocal());
  }

  /// Định dạng ngày tháng ngắn: dd/MM (VD: 09/10)
  static String formatDayMonth(DateTime? date, {String fallback = '-'}) {
    if (date == null) return fallback;
    return _dayMonthFormat.format(date.toLocal());
  }

  /// Định dạng giờ: HH:mm (VD: 14:30)
  static String formatTime(DateTime? date, {String fallback = '-'}) {
    if (date == null) return fallback;
    return _timeOnlyFormat.format(date.toLocal());
  }
}
```

- [ ] **Step 4: Chạy test để xác nhận PASS**

Run: `flutter test test/core/utils/app_date_formatter_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/app_date_formatter.dart test/core/utils/app_date_formatter_test.dart
git commit -m "feat(core): thêm tiện ích AppDateFormatter chuẩn hóa ngày tháng"
```

---

### Task 2: Chuẩn Hóa Phân Hệ Cư Dân (`lib/features/resident/`)

**Files:**
- Modify: `lib/features/resident/screens/resident_invoice_screen.dart`
- Modify: `lib/features/resident/screens/resident_invoice_detail_screen.dart`
- Modify: `lib/features/resident/screens/resident_issue_screen.dart`
- Modify: `lib/features/resident/screens/issue_detail_screen.dart`
- Modify: `lib/features/resident/screens/resident_home_screen.dart`
- Modify: `lib/features/resident/screens/resident_announcement_detail_screen.dart`
- Modify: `lib/features/resident/screens/resident_meter_reading_screen.dart`
- Modify: `lib/features/resident/screens/vehicle_management_screen.dart`
- Modify: `lib/features/resident/screens/payment_history_screen.dart`
- Modify: `lib/features/resident/screens/amenity_booking_screen.dart`
- Modify: `lib/features/resident/widgets/equipment_interruption_banner.dart`

**Interfaces:**
- Consumes: `AppDateFormatter.formatDate`, `AppDateFormatter.formatDateTime`, `AppDateFormatter.formatDayMonth`.

- [ ] **Step 1: Cập nhật các màn hình hóa đơn cư dân**
  - Trong `resident_invoice_screen.dart`: Thay thế `formatDate.format(invoice.dueDate)` bằng `AppDateFormatter.formatDate(invoice.dueDate)`.
  - Trong `resident_invoice_detail_screen.dart`: Dùng `AppDateFormatter.formatDate(_invoice.dueDate)` cho hạn thanh toán và `AppDateFormatter.formatDateTime((_invoice.updatedAt ?? _invoice.createdAt))` cho thời gian thanh toán.

- [ ] **Step 2: Cập nhật các màn hình phản ánh sự cố & trang chủ cư dân**
  - Trong `resident_issue_screen.dart`: Dùng `AppDateFormatter.formatDateTime(issue.createdAt)`.
  - Trong `issue_detail_screen.dart`: Dùng `AppDateFormatter.formatDateTime(issue.createdAt)` và `AppDateFormatter.formatDateTime(step.date)`.
  - Trong `resident_home_screen.dart`: Thẻ thông báo `date: AppDateFormatter.formatDate(announcement.createdAt)`.
  - Trong `resident_announcement_detail_screen.dart`: `AppDateFormatter.formatDateTime(announcement.createdAt)`.

- [ ] **Step 3: Cập nhật xe cộ, chỉ số, tiện ích, thanh toán & bảo trì cư dân**
  - Trong `vehicle_management_screen.dart`: `AppDateFormatter.formatDateTime(vehicle.createdAt)`.
  - Trong `resident_meter_reading_screen.dart`: `AppDateFormatter.formatDateTime(item.createdAt)`.
  - Trong `payment_history_screen.dart`: `AppDateFormatter.formatDateTime(tx.createdAt)`.
  - Trong `amenity_booking_screen.dart`: `AppDateFormatter.formatDate(bookingDate)`, chip ngày dùng `AppDateFormatter.formatDayMonth(date)`.
  - Trong `equipment_interruption_banner.dart`: `${AppDateFormatter.formatDateTime(task.scheduledStart)} - ${AppDateFormatter.formatDateTime(task.scheduledEnd)}`.

- [ ] **Step 4: Chạy test các màn hình cư dân**

Run: `flutter test test/features/resident/`
Expected: PASS toàn bộ.

- [ ] **Step 5: Commit**

```bash
git add lib/features/resident/
git commit -m "refactor(resident): áp dụng AppDateFormatter chuẩn hóa ngày tháng phân hệ cư dân"
```

---

### Task 3: Chuẩn Hóa Phân Hệ Ban Quản Lý (`lib/features/management/`)

**Files:**
- Modify: `lib/features/management/screens/management_home_screen.dart`
- Modify: `lib/features/management/screens/equipment_management_screen.dart`
- Modify: `lib/features/management/screens/equipment_detail_screen.dart`
- Modify: `lib/features/management/screens/management_payment_transactions_screen.dart`
- Modify: `lib/features/management/screens/management_meter_reading_screen.dart`
- Modify: `lib/features/management/screens/management_invoice_detail_screen.dart`
- Modify: `lib/features/management/screens/create_invoice_screen.dart`
- Modify: `lib/features/management/screens/edit_invoice_screen.dart`
- Modify: `lib/features/management/screens/vehicle_approval_screen.dart`
- Modify: `lib/features/management/screens/service_rating_overview_screen.dart`
- Modify: `lib/features/management/screens/issue_management_screen.dart`
- Modify: `lib/features/management/screens/announcement_management_screen.dart`
- Modify: `lib/features/management/screens/amenity_management_screen.dart`
- Modify: `lib/features/management/screens/role_delegation_screen.dart`
- Modify: `lib/features/management/widgets/maintenance_task_form_dialog.dart`
- Modify: `lib/features/management/widgets/bulk_invoice_dialog.dart`

**Interfaces:**
- Consumes: `AppDateFormatter.formatDate`, `AppDateFormatter.formatDateTime`, `AppDateFormatter.formatDateTimeWithSeconds`.

- [ ] **Step 1: Chuẩn hóa trang chủ BQL, thiết bị và bảo trì**
  - `management_home_screen.dart`: Thay thế `DateFormat('dd/MM HH:mm')` bằng `AppDateFormatter.formatDateTime(tx.createdAt)`.
  - `equipment_management_screen.dart`: Thay thế `DateFormat('HH:mm dd/MM')` bằng `AppDateFormatter.formatDateTime(task.scheduledStart)`.
  - `equipment_detail_screen.dart`: Dùng `AppDateFormatter.formatDate`.
  - `maintenance_task_form_dialog.dart`: Thay thế `DateFormat('HH:mm dd/MM/yyyy')` bằng `AppDateFormatter.formatDateTime(...)`.

- [ ] **Step 2: Chuẩn hóa quản lý hóa đơn, thanh toán và chỉ số**
  - `management_payment_transactions_screen.dart`: Dùng `AppDateFormatter.formatDateTime` cho danh sách và `AppDateFormatter.formatDateTimeWithSeconds` cho chi tiết giao dịch.
  - `management_meter_reading_screen.dart`: Dùng `AppDateFormatter.formatDateTime(item.createdAt)`.
  - `management_invoice_detail_screen.dart`, `create_invoice_screen.dart`, `edit_invoice_screen.dart`, `bulk_invoice_dialog.dart`: Dùng `AppDateFormatter.formatDate`.

- [ ] **Step 3: Chuẩn hóa xe cộ, phản ánh, tiện ích, ủy quyền, đánh giá & thông báo**
  - `vehicle_approval_screen.dart`: `AppDateFormatter.formatDateTime(v.createdAt)`.
  - `service_rating_overview_screen.dart`: `AppDateFormatter.formatDateTime(rating.createdAt)`.
  - `issue_management_screen.dart`: `AppDateFormatter.formatDateTime(issue.createdAt)`.
  - `announcement_management_screen.dart`: `AppDateFormatter.formatDateTime(announcement.createdAt)`.
  - `amenity_management_screen.dart`: `AppDateFormatter.formatDate`.
  - `role_delegation_screen.dart`: `AppDateFormatter.formatDate` và `AppDateFormatter.formatDateTime`.

- [ ] **Step 4: Chạy test các màn hình ban quản lý**

Run: `flutter test test/features/management/`
Expected: PASS toàn bộ.

- [ ] **Step 5: Commit**

```bash
git add lib/features/management/
git commit -m "refactor(management): áp dụng AppDateFormatter chuẩn hóa ngày tháng phân hệ BQL"
```

---

### Task 4: Chuẩn Hóa Core Widgets, Export Helper & Kiểm Thử Toàn Diện Hệ Thống

**Files:**
- Modify: `lib/core/widgets/unified_payment_sheet.dart`
- Modify: `lib/core/utils/excel_export_helper.dart`
- Run: Toàn bộ suite `test/`
- Run: `flutter analyze`

- [ ] **Step 1: Cập nhật Core Widgets & Excel Export Helper**
  - Trong `unified_payment_sheet.dart`: Thay thế `_dateFormat.format(item['created_at'])` bằng `AppDateFormatter.formatDateTime(...)`.
  - Trong `excel_export_helper.dart`: Thay thế `dateFormat` bằng `AppDateFormatter.formatDate` và `AppDateFormatter.formatDateTime`. Giữ nguyên `yyyyMMdd_HHmmss` cho tên file.

- [ ] **Step 2: Commit các thay đổi Core**

```bash
git add lib/core/widgets/unified_payment_sheet.dart lib/core/utils/excel_export_helper.dart
git commit -m "refactor(core): áp dụng AppDateFormatter cho payment sheet và excel export"
```

- [ ] **Step 3: Chạy toàn bộ test suite dự án**

Run: `flutter test`
Expected: 100% test cases (270+ tests bao gồm test mới) PASS, 0 thất bại.

- [ ] **Step 4: Phân tích cảnh báo tĩnh & linter**

Run: `flutter analyze`
Expected: `No issues found!`.
