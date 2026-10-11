# Vá Các Lỗ Hổng Bảo Mật & Toàn Vẹn Dữ Liệu Nghiệp Vụ (P0/P1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khắc phục triệt để lỗ hổng phân quyền RPC thanh toán, lỗi bỏ qua RLS test, lỗi thụt lùi chỉ số đồng hồ điện nước, rủi ro crash cấu hình `.env` cho clone mới, và cập nhật kết quả phân tích mã nguồn.

**Architecture:** Sử dụng PostgreSQL security checks trong RPC `simulate_unified_payment` và `approve_meter_reading` với cơ chế khóa hàng `FOR UPDATE`, siết chặt xác thực `auth.uid()`, kiểm tra phân quyền RBAC và trạng thái trước khi thay đổi. Tầng Dart/Flutter tối ưu nạp biến môi trường đồng bộ và xử lý fallback an toàn. Toàn bộ thay đổi commit trực tiếp vào `main`.

**Tech Stack:** PostgreSQL (Supabase Pl/pgSQL), Flutter / Dart, `flutter_dotenv`, `supabase_flutter`.

## Global Constraints
- Commit trực tiếp trên nhánh `main`, không tạo branch hay worktree phụ.
- Tên hàm và tham số RPC giữ nguyên chữ ký để đảm bảo tương thích ngược với Flutter frontend.
- Mã nguồn và thông báo lỗi 100% tiếng Việt chuẩn mực.

---

### Task 1: Siết Chặt Bảo Mật & Phân Quyền Trong RPC `simulate_unified_payment` (P0)

**Files:**
- Modify: `supabase/migrations/20261010_01_comprehensive_database_and_security_patches.sql` (hàm `simulate_unified_payment`)
- Test: `test/data/migrations/p0_security_migration_content_test.dart`
- DB: Thực thi trực tiếp qua MCP `execute_sql` lên Supabase

**Interfaces:**
- Consumes: RPC `public.simulate_unified_payment(p_type VARCHAR, p_reference_id UUID, p_payment_method VARCHAR, p_outcome VARCHAR, p_failure_reason TEXT)`
- Produces: Hàm Pl/pgSQL đã được bọc kiểm tra `auth.uid() IS NOT NULL`, phân quyền căn hộ (`residents_apartments`) / booking, chặn thanh toán trùng, chặn giá trị outcome không hợp lệ.

- [ ] **Step 1: Viết test kiểm tra các điều kiện an toàn mới trong file migration test**

Thêm assertions vào `test/data/migrations/p0_security_migration_content_test.dart`:
```dart
test('Migration 20261010_01 siết chặt quyền và trạng thái trong simulate_unified_payment', () {
  final file = File('supabase/migrations/20261010_01_comprehensive_database_and_security_patches.sql');
  final content = file.readAsStringSync();
  expect(content.contains("v_user_id IS NULL THEN"), isTrue, reason: 'Phải bắt buộc đăng nhập');
  expect(content.contains("residents_apartments"), isTrue, reason: 'Phải kiểm tra quyền cư dân căn hộ');
  expect(content.contains("v_inv_status = 'paid'"), isTrue, reason: 'Phải chặn thanh toán trùng hóa đơn');
  expect(content.contains("v_booking_status = 'confirmed'"), isTrue, reason: 'Phải chặn thanh toán trùng tiện ích');
  expect(content.contains("NOT IN ('SUCCESS', 'FAILED')"), isTrue, reason: 'Phải kiểm tra outcome hợp lệ');
});
```

- [ ] **Step 2: Chạy test để xác nhận test ban đầu fail**

Chạy: `flutter test test/data/migrations/p0_security_migration_content_test.dart`
Kỳ vọng: FAIL vì migration chưa có các điều kiện kiểm tra mới.

- [ ] **Step 3: Cập nhật hàm `simulate_unified_payment` trong file migration 20261010**

Cập nhật thân hàm `simulate_unified_payment` với đầy đủ:
1. `IF v_user_id IS NULL THEN RAISE EXCEPTION 'Yêu cầu đăng nhập...'; END IF;`
2. `IF v_clean_outcome NOT IN ('SUCCESS', 'FAILED') THEN RAISE EXCEPTION 'Kết quả thanh toán không hợp lệ...'; END IF;`
3. Nhánh `INVOICE`: `SELECT apartment_id, total_amount, status INTO v_apt_id, v_amount, v_inv_status FROM public.invoices WHERE id = p_reference_id FOR UPDATE;`
   - Kiểm tra `v_inv_status` ('paid', 'cancelled').
   - Kiểm tra `residents_apartments` cho cư dân.
4. Nhánh `SERVICE`: `SELECT b.apartment_id, b.user_id, b.status, b.fee_amount, a.name INTO ... FROM public.amenity_bookings b ... WHERE b.id = p_reference_id FOR UPDATE;`
   - Kiểm tra `v_booking_status` ('confirmed', 'cancelled', 'rejected').
   - Kiểm tra `b.user_id = v_user_id` hoặc cùng `residents_apartments`.

- [ ] **Step 4: Chạy test kiểm tra file migration**

Chạy: `flutter test test/data/migrations/p0_security_migration_content_test.dart`
Kỳ vọng: PASS

- [ ] **Step 5: Thực thi DDL cập nhật hàm `simulate_unified_payment` lên database Supabase trực tiếp qua MCP tool**

Gọi `execute_sql` cập nhật hàm vào cơ sở dữ liệu Supabase đang kết nối.

- [ ] **Step 6: Commit lên `main`**

```bash
git add supabase/migrations/20261010_01_comprehensive_database_and_security_patches.sql test/data/migrations/p0_security_migration_content_test.dart
git commit -m "fix(security): siết quyền sở hữu và trạng thái trong RPC simulate_unified_payment"
```

---

### Task 2: Khắc Phục Điều Kiện Bỏ Qua Test RLS Trong `rls_security_test.dart` (P0)

**Files:**
- Modify: `test/integration/rls_security_test.dart`

**Interfaces:**
- Consumes: Biến môi trường hệ thống (`Platform.environment`) và file `.env`
- Produces: Test runner đánh giá `skipReason` đồng bộ trước khi đăng ký group test, giúp test RLS thực sự chạy khi có biến môi trường.

- [ ] **Step 1: Cập nhật `test/integration/rls_security_test.dart` nạp env đồng bộ**

Đọc `.env` và `Platform.environment` đồng bộ trong `main()`:
```dart
void main() {
  if (File('.env').existsSync()) {
    try {
      dotenv.testLoad(fileString: File('.env').readAsStringSync());
    } catch (_) {}
  }

  final testResidentEmail = Platform.environment['TEST_RESIDENT_EMAIL'] ?? 
      dotenv.env['TEST_RESIDENT_EMAIL'] ?? 'resident101@test.com';
  final testResidentPassword = Platform.environment['TEST_RESIDENT_PASSWORD'] ?? 
      dotenv.env['TEST_RESIDENT_PASSWORD'] ?? 'password123';
  final testResidentApartmentId = Platform.environment['TEST_RESIDENT_APARTMENT_ID'] ?? 
      dotenv.env['TEST_RESIDENT_APARTMENT_ID'];

  final supabaseUrl = Platform.environment['SUPABASE_URL'] ?? dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = Platform.environment['SUPABASE_ANON_KEY'] ?? dotenv.env['SUPABASE_ANON_KEY'];

  final bool isConfigured = supabaseUrl != null &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey != null &&
      supabaseAnonKey.isNotEmpty &&
      testResidentApartmentId != null &&
      testResidentApartmentId.isNotEmpty &&
      testResidentApartmentId != 'FILL_UUID_HERE';

  final skipReason = isConfigured ? null : 'Chưa cấu hình tài khoản test thực tế trong .env';
```

- [ ] **Step 2: Chạy kiểm tra test `test/integration/rls_security_test.dart`**

Chạy: `flutter test test/integration/rls_security_test.dart`
Kỳ vọng: Test runner đăng ký chính xác với `skipReason`, không bị race condition giữa `setUpAll` và tham số `skip:`.

- [ ] **Step 3: Commit lên `main`**

```bash
git add test/integration/rls_security_test.dart
git commit -m "fix(test): sửa điều kiện skip đồng bộ cho rls_security_test"
```

---

### Task 3: Bảo Vệ Dữ Liệu Chỉ Số Đồng Hồ Trong `approve_meter_reading` (P1)

**Files:**
- Modify: `supabase/migrations/20261010_01_comprehensive_database_and_security_patches.sql` (hàm `approve_meter_reading`)
- Test: `test/data/migrations/p0_security_migration_content_test.dart`
- DB: Thực thi trực tiếp qua MCP `execute_sql` lên Supabase

**Interfaces:**
- Consumes: RPC `public.approve_meter_reading(p_submission_id UUID)`
- Produces: Hàm Pl/pgSQL khóa hàng `apartments FOR UPDATE`, ném ngoại lệ nếu chỉ số điện mới hoặc nước mới nhỏ hơn chỉ số cũ hiện tại.

- [ ] **Step 1: Thêm test kiểm tra logic chống giảm chỉ số vào file migration test**

```dart
test('approve_meter_reading khóa FOR UPDATE và từ chối chỉ số mới nhỏ hơn chỉ số cũ', () {
  final file = File('supabase/migrations/20261010_01_comprehensive_database_and_security_patches.sql');
  final content = file.readAsStringSync();
  expect(content.contains("FROM public.apartments\n    WHERE id = v_sub.apartment_id FOR UPDATE;"), isTrue);
  expect(content.contains("v_sub.electric_reading < v_old_elec"), isTrue);
  expect(content.contains("v_sub.water_reading < v_old_water"), isTrue);
});
```

- [ ] **Step 2: Cập nhật hàm `approve_meter_reading` trong file migration 20261010**

Khóa bản ghi `apartments FOR UPDATE` và thêm validation:
```sql
SELECT area, COALESCE(electric_reading, 0), COALESCE(water_reading, 0)
INTO v_area, v_old_elec, v_old_water
FROM public.apartments
WHERE id = v_sub.apartment_id FOR UPDATE;

IF v_sub.electric_reading < v_old_elec THEN
    RAISE EXCEPTION 'Chỉ số điện mới (%) không được nhỏ hơn chỉ số cũ (%) của căn hộ', v_sub.electric_reading, v_old_elec;
END IF;

IF v_sub.water_reading < v_old_water THEN
    RAISE EXCEPTION 'Chỉ số nước mới (%) không được nhỏ hơn chỉ số cũ (%) của căn hộ', v_sub.water_reading, v_old_water;
END IF;

v_elec_diff := v_sub.electric_reading - v_old_elec;
v_water_diff := v_sub.water_reading - v_old_water;
```

- [ ] **Step 3: Chạy test xác nhận**

Chạy: `flutter test test/data/migrations/p0_security_migration_content_test.dart`
Kỳ vọng: PASS

- [ ] **Step 4: Thực thi DDL cập nhật hàm `approve_meter_reading` lên database Supabase trực tiếp qua MCP tool**

Gọi `execute_sql` cập nhật hàm vào cơ sở dữ liệu Supabase.

- [ ] **Step 5: Commit lên `main`**

```bash
git add supabase/migrations/20261010_01_comprehensive_database_and_security_patches.sql test/data/migrations/p0_security_migration_content_test.dart
git commit -m "fix(db): ngăn thụt lùi chỉ số đồng hồ điện nước và thêm khóa hàng FOR UPDATE trong approve_meter_reading"
```

---

### Task 4: Nâng Cấp Quản Lý Cấu Hình `.env` An Toàn Khi Khởi Chạy (P1)

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`
- Modify: `lib/core/supabase_config.dart`

**Interfaces:**
- Consumes: Assets bundle và file `.env` / `.env.example`
- Produces: Ứng dụng khởi chạy mượt mà ngay cả trên clone mới chưa có file `.env`.

- [ ] **Step 1: Khai báo `.env.example` trong `pubspec.yaml`**

Thêm `- .env.example` vào mục assets bên cạnh `- .env`.

- [ ] **Step 2: Cập nhật fallback an toàn trong `lib/main.dart`**

Bọc `dotenv.load` trong try-catch, tự động thử `.env.example` nếu `.env` không tồn tại.

- [ ] **Step 3: Cập nhật kiểm tra cấu hình thân thiện trong `lib/core/supabase_config.dart`**

Kiểm tra `supabaseUrl` và `supabaseAnonKey`, in log cảnh báo rõ ràng nếu thiếu cấu hình thay vì gây lỗi mơ hồ.

- [ ] **Step 4: Chạy test xác nhận ứng dụng không bị ảnh hưởng**

Chạy: `flutter test test/core/`
Kỳ vọng: PASS

- [ ] **Step 5: Commit lên `main`**

```bash
git add pubspec.yaml lib/main.dart lib/core/supabase_config.dart
git commit -m "fix(config): bổ sung fallback nạp .env.example và kiểm tra an toàn SupabaseConfig"
```

---

### Task 5: Cập Nhật Báo Cáo Phân Tích Mã Nguồn & Xác Minh Toàn Diện Hệ Thống (P1)

**Files:**
- Modify: `analyze_output.txt`

- [ ] **Step 1: Cập nhật nội dung `analyze_output.txt`**

Ghi kết quả `flutter analyze` hiện tại (0 issues).

- [ ] **Step 2: Chạy `flutter analyze` để xác minh**

Chạy: `flutter analyze`
Kỳ vọng: `No issues found!`

- [ ] **Step 3: Chạy toàn bộ test suite `flutter test`**

Chạy: `flutter test`
Kỳ vọng: Toàn bộ tests (> 270) PASS.

- [ ] **Step 4: Commit và push lên `main`**

```bash
git add analyze_output.txt
git commit -m "docs: cập nhật analyze_output.txt sạch lỗi và hoàn tất xác minh"
git push origin main
```
