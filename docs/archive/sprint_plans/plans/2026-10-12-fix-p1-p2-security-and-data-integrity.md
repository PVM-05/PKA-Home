# Kế Hoạch Triển Khai: Khắc Phục Lỗ Hổng Bảo Mật, Đồng Bộ RPC Và Toàn Vẹn Dữ Liệu (P1 & P2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khắc phục triệt để 6 lỗ hổng bảo mật, lỗi lệch chữ ký RPC, nguy cơ giao dịch trùng, tranh chấp đặt tiện ích vượt sức chứa, hết hạn giao thức FCM và sự cố hiển thị ảnh minh chứng private bucket tại commit `a9d3186`.

**Architecture:** 
- Phía Cơ sở dữ liệu (PostgreSQL/Supabase): Tạo migration mới `20261012_01_fix_p1_p2_security_rpcs_and_storage.sql` chuẩn hóa chữ ký `approve_meter_reading`, thắt chặt xác minh quyền sở hữu căn hộ trong `book_amenity_slot`, cơ chế khóa đồng bộ `pg_advisory_xact_lock` chống vượt sức chứa, cơ chế idempotent và ràng buộc partial unique index chống trùng giao dịch trong `record_manual_amenity_payment`.
- Phía Flutter: Cập nhật `management_repository.dart` và `issue_repository.dart` sinh Signed URL cho bucket `issue-images`, kiểm tra tương thích kiểu dữ liệu `meter_reading_repository.dart`.
- Phía Edge Function: Chuyển đổi `send-fcm-notification/index.ts` từ FCM Legacy sang Firebase Cloud Messaging HTTP v1 chuẩn OAuth 2.0 service account qua Web Crypto API.

**Tech Stack:** Flutter / Dart, PostgreSQL 17 / Supabase PL/pgSQL, Supabase Storage, Deno / TypeScript (Supabase Edge Functions), Web Crypto API.

## Global Constraints

- Tuân thủ quy định branch: Toàn bộ thay đổi thực hiện và commit trực tiếp trên nhánh `main`.
- Tuân thủ quy tắc database: Không sửa đè các file migration cũ đã tồn tại; tạo migration mới `20261012_01_fix_p1_p2_security_rpcs_and_storage.sql`.
- Tuân thủ quy tắc coding: Đặt tên `snake_case` cho DB, `lowerCamelCase` cho Dart, mã căn hộ chuẩn định dạng `a0110` / `A0110`.
- 100% tiếng Việt cho giao diện người dùng và thông báo lỗi hiển thị cho cư dân / ban quản lý.
- Kiểm thử đầy đủ: `flutter test` và kiểm thử trực tiếp RPC / RLS trên Supabase trước khi hoàn tất.

---

### Task 1: Tạo Migration SQL Sửa Phân Quyền Căn Hộ và Khóa Đồng Bộ Chống Vượt Sức Chứa trong `book_amenity_slot` (Lỗi 2 & Lỗi 5)

**Files:**
- Create: `supabase/migrations/20261012_01_fix_p1_p2_security_rpcs_and_storage.sql` (bước khởi tạo phần 1)
- Test: `test/features/resident/amenity_booking_security_test.dart`

**Interfaces:**
- Consumes: Bảng `residents_apartments`, `building_amenities`, `amenity_bookings`.
- Produces: RPC `public.book_amenity_slot(p_amenity_id UUID, p_booking_date DATE, p_time_slot VARCHAR, p_guests_count INT, p_apartment_id UUID, p_allow_waitlist BOOLEAN, p_notes TEXT) RETURNS JSONB`.

- [ ] **Step 1: Viết test kiểm tra phân quyền và bắt lỗi căn hộ không hợp lệ trong Dart**

Tạo file `test/features/resident/amenity_booking_security_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/network_error_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Kiểm thử bảo mật RPC book_amenity_slot', () {
    test('Xử lý lỗi từ chối căn hộ không thuộc quyền sở hữu', () {
      final exception = PostgrestException(
        message: 'Bạn không có quyền đặt tiện ích cho căn hộ này',
        code: 'P0001',
      );
      final msg = NetworkErrorHandler.getMessage(exception);
      expect(msg, contains('Bạn không có quyền'));
    });

    test('Xử lý lỗi vượt sức chứa tối đa', () {
      final exception = PostgrestException(
        message: 'Khung giờ này đã đủ số lượng đặt tối đa (Hết chỗ)',
        code: 'P0001',
      );
      final msg = NetworkErrorHandler.getMessage(exception);
      expect(msg, contains('Hết chỗ'));
    });
  });
}
```

- [ ] **Step 2: Chạy test để xác nhận test chạy được**

Run: `flutter test test/features/resident/amenity_booking_security_test.dart`
Expected: PASS

- [ ] **Step 3: Khởi tạo migration SQL cập nhật RPC `book_amenity_slot` với xác minh căn hộ và advisory lock**

Viết phần đầu của file `supabase/migrations/20261012_01_fix_p1_p2_security_rpcs_and_storage.sql`:
- Thu hồi và drop các overload cũ.
- Kiểm tra `auth.uid() IS NOT NULL`.
- Nếu có `p_apartment_id`: Nếu không phải Staff/Admin, kiểm tra bắt buộc `EXISTS (SELECT 1 FROM residents_apartments WHERE user_id = auth.uid() AND apartment_id = p_apartment_id)`. Nếu không thuộc quyền -> `RAISE EXCEPTION 'Bạn không có quyền đặt tiện ích cho căn hộ này'`.
- Nếu không có `p_apartment_id`: Truy vấn danh sách căn hộ của user. Nếu = 1 thì lấy; nếu = 0 báo chưa liên kết; nếu > 1 yêu cầu chọn cụ thể.
- Lấy khóa nguyên tử `PERFORM pg_advisory_xact_lock(hashtext(p_amenity_id::text || '_' || p_booking_date::text || '_' || p_time_slot));` để ngăn race condition vượt sức chứa.
- Đếm `v_total_bookings` các booking có status `confirmed`, `completed`, `pending_payment`. Nếu `>= max_capacity` và không cho phép waitlist thì từ chối.

- [ ] **Step 4: Chạy kiểm thử SQL trên Supabase bằng `execute_sql`**

Thực thi phần SQL này lên Supabase và kiểm tra RPC đã được cập nhật thành công.

- [ ] **Step 5: Commit bước 1**

```bash
git add supabase/migrations/20261012_01_fix_p1_p2_security_rpcs_and_storage.sql test/features/resident/amenity_booking_security_test.dart
git commit -m "feat(amenity): xác minh quyền căn hộ và khóa đồng bộ chống vượt sức chứa trong book_amenity_slot"
```

---

### Task 2: Chống Ghi Nhận Trùng Giao Dịch Thu Phí Tiện Ích trong `record_manual_amenity_payment` (Lỗi 3)

**Files:**
- Modify: `supabase/migrations/20261012_01_fix_p1_p2_security_rpcs_and_storage.sql` (bổ sung phần 2)
- Test: `test/features/management/amenity_payment_idempotency_test.dart`

**Interfaces:**
- Consumes: Bảng `amenity_bookings`, `payment_transactions`.
- Produces: Partial unique index `uq_payment_transactions_booking_success` & RPC `public.record_manual_amenity_payment(p_booking_id UUID, p_payment_method VARCHAR, p_notes TEXT) RETURNS JSONB`.

- [ ] **Step 1: Viết test cho kiểm thử idempotent thanh toán thủ công**

Tạo file `test/features/management/amenity_payment_idempotency_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kiểm thử tính Idempotent của RPC record_manual_amenity_payment', () {
    test('Xử lý phản hồi khi booking đã được xác nhận thanh toán trước đó', () {
      final mockResponse = {
        'success': true,
        'message': 'Giao dịch cho lịch đặt tiện ích này đã được xác nhận thanh toán trước đó',
        'already_paid': true,
        'booking_id': '00000000-0000-0000-0000-000000000001',
        'transaction_id': '00000000-0000-0000-0000-000000000002',
        'transaction_code': 'MANUAL-SRV-20261012-001',
      };

      expect(mockResponse['success'], isTrue);
      expect(mockResponse['already_paid'], isTrue);
      expect(mockResponse['transaction_code'], isNotNull);
    });
  });
}
```

- [ ] **Step 2: Chạy test kiểm tra**

Run: `flutter test test/features/management/amenity_payment_idempotency_test.dart`
Expected: PASS

- [ ] **Step 3: Bổ sung logic RPC `record_manual_amenity_payment` và Unique Index vào Migration**

Thêm vào `supabase/migrations/20261012_01_fix_p1_p2_security_rpcs_and_storage.sql`:
1. Ràng buộc partial unique index:
   ```sql
   CREATE UNIQUE INDEX IF NOT EXISTS uq_payment_transactions_booking_success
   ON public.payment_transactions (booking_id)
   WHERE booking_id IS NOT NULL AND status = 'SUCCESS' AND type = 'SERVICE';
   ```
2. Trong hàm `record_manual_amenity_payment`:
   - Khóa booking `FOR UPDATE`.
   - Tìm giao dịch `status = 'SUCCESS'`. Nếu tìm thấy: trả về ngay kết quả idempotent với `already_paid: true`, không tạo giao dịch mới!
   - Nếu chưa có `SUCCESS`, tìm `PENDING` -> chuyển thành `SUCCESS`.
   - Nếu không có cả hai: chèn `SUCCESS` mới.
   - Cập nhật booking `status = 'confirmed'`, `deposit_status = 'received'`.

- [ ] **Step 4: Chạy kiểm thử SQL trên Supabase bằng `execute_sql`**

Kiểm tra tạo index và thay thế hàm `record_manual_amenity_payment` thành công trên DB.

- [ ] **Step 5: Commit bước 2**

```bash
git add supabase/migrations/20261012_01_fix_p1_p2_security_rpcs_and_storage.sql test/features/management/amenity_payment_idempotency_test.dart
git commit -m "feat(payment): chống ghi nhận giao dịch trùng và bảo đảm tính idempotent cho record_manual_amenity_payment"
```

---

### Task 3: Đồng Bộ Chữ Ký RPC `approve_meter_reading` Giữa Dart và SQL (Lỗi 1)

**Files:**
- Modify: `supabase/migrations/20261012_01_fix_p1_p2_security_rpcs_and_storage.sql` (bổ sung phần 3)
- Modify: `lib/data/repositories/meter_reading_repository.dart:70-86`
- Test: `test/features/management/meter_reading_approval_signature_test.dart`

**Interfaces:**
- Consumes: Bảng `meter_reading_submissions`, `apartments`, `invoices`, `invoice_items`.
- Produces: RPC `public.approve_meter_reading(p_submission_id UUID, p_generate_invoice BOOLEAN, p_due_date DATE) RETURNS JSONB`.

- [ ] **Step 1: Viết test kiểm tra lời gọi repository duyệt chỉ số**

Tạo file `test/features/management/meter_reading_approval_signature_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kiểm thử hợp đồng tham số approve_meter_reading', () {
    test('Format đúng định dạng tham số truyền vào RPC', () {
      final dueDate = DateTime(2026, 11, 15);
      final dueStr = "${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}";
      
      final params = {
        'p_submission_id': 'test-submission-id',
        'p_generate_invoice': true,
        'p_due_date': dueStr,
      };

      expect(params['p_submission_id'], 'test-submission-id');
      expect(params['p_generate_invoice'], isTrue);
      expect(params['p_due_date'], '2026-11-15');
    });
  });
}
```

- [ ] **Step 2: Chạy test kiểm tra**

Run: `flutter test test/features/management/meter_reading_approval_signature_test.dart`
Expected: PASS

- [ ] **Step 3: Bổ sung RPC `approve_meter_reading` vào Migration**

Trong `supabase/migrations/20261012_01_fix_p1_p2_security_rpcs_and_storage.sql`:
1. `DROP FUNCTION IF EXISTS public.approve_meter_reading(UUID);`
2. `DROP FUNCTION IF EXISTS public.approve_meter_reading(UUID, BOOLEAN, DATE);`
3. Định nghĩa:
   ```sql
   CREATE OR REPLACE FUNCTION public.approve_meter_reading(
       p_submission_id UUID,
       p_generate_invoice BOOLEAN DEFAULT FALSE,
       p_due_date DATE DEFAULT NULL
   )
   RETURNS JSONB ...
   ```
4. Logic xử lý:
   - Cập nhật chỉ số điện nước vào `apartments` và set `status = 'approved'` trên `meter_reading_submissions`.
   - **Chỉ khi `p_generate_invoice = TRUE`** mới kiểm tra và tạo hóa đơn:
     - Nếu chưa có hóa đơn cho kỳ: Tạo hóa đơn với `due_date = COALESCE(p_due_date, CURRENT_DATE + INTERVAL '10 days')`. Thêm các mục phí tương ứng.
     - Nếu đã có hóa đơn: Không tạo trùng.
   - Nếu `p_generate_invoice = FALSE`: Hoàn tất duyệt mà không tạo hóa đơn.
5. Cấp quyền: `REVOKE ALL ... FROM anon, PUBLIC; GRANT EXECUTE ... TO authenticated;`

- [ ] **Step 4: Cập nhật `lib/data/repositories/meter_reading_repository.dart`**

Bảo đảm `p_due_date` chỉ được gửi khi `generateInvoice == true` và xử lý an toàn:
```dart
    final dueStr = (generateInvoice && dueDate != null)
        ? "${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}"
        : null;

    final response = await _client.rpc('approve_meter_reading', params: {
      'p_submission_id': submissionId,
      'p_generate_invoice': generateInvoice,
      'p_due_date': dueStr,
    });
```

- [ ] **Step 5: Chạy `execute_sql` cập nhật DB và kiểm thử**

- [ ] **Step 6: Commit bước 3**

```bash
git add supabase/migrations/20261012_01_fix_p1_p2_security_rpcs_and_storage.sql lib/data/repositories/meter_reading_repository.dart test/features/management/meter_reading_approval_signature_test.dart
git commit -m "fix(meter): đồng bộ chữ ký RPC approve_meter_reading và tùy chọn tạo hóa đơn"
```

---

### Task 4: Chuyển Đổi Quản Lý Ảnh Minh Chứng Nghiệm Thu Sang Signed URL (Lỗi 6)

**Files:**
- Modify: `lib/data/repositories/management_repository.dart:212-234`
- Modify: `lib/data/repositories/issue_repository.dart`
- Test: `test/features/management/issue_proof_storage_test.dart`

**Interfaces:**
- Consumes: Supabase Storage bucket `issue-images`.
- Produces: `resolveIssueWithProof` lưu Signed URL và hỗ trợ hàm `getSignedImageUrl` để làm mới link ảnh hết hạn.

- [ ] **Step 1: Viết test cho logic xử lý URL ảnh minh chứng**

Tạo file `test/features/management/issue_proof_storage_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kiểm thử xử lý đường dẫn ảnh minh chứng sự cố', () {
    test('Trích xuất đường dẫn object từ URL Supabase Storage', () {
      final sampleUrl = 'https://abc.supabase.co/storage/v1/object/public/issue-images/staff1/issue1/proof_123.jpg';
      final uri = Uri.parse(sampleUrl);
      final segments = uri.pathSegments;
      final bucketIndex = segments.indexOf('issue-images');
      final path = segments.sublist(bucketIndex + 1).join('/');

      expect(path, 'staff1/issue1/proof_123.jpg');
    });
  });
}
```

- [ ] **Step 2: Chạy test kiểm tra**

Run: `flutter test test/features/management/issue_proof_storage_test.dart`
Expected: PASS

- [ ] **Step 3: Cập nhật `resolveIssueWithProof` trong `management_repository.dart`**

Cập nhật phương thức `resolveIssueWithProof`:
```dart
      await _client.storage.from('issue-images').upload(fileName, file);
      
      String imageUrl;
      try {
        // Ưu tiên tạo signed URL có thời hạn cho private bucket bảo mật
        imageUrl = await _client.storage
            .from('issue-images')
            .createSignedUrl(fileName, 60 * 60 * 24 * 365); // 1 năm
      } catch (_) {
        // Fallback getPublicUrl nếu bucket công khai
        imageUrl = _client.storage.from('issue-images').getPublicUrl(fileName);
      }

      await _client.from('issue_images').insert({
        'issue_report_id': issueId,
        'image_url': imageUrl,
        'image_role': 'resolution_proof',
      });
```
Đồng thời thêm hàm tiện ích `Future<String> getSignedImageUrl(String urlOrPath)` trong `ManagementRepository` và `IssueRepository` để sinh Signed URL on-the-fly khi URL cũ hết hạn hoặc truyền object path.

- [ ] **Step 4: Chạy `flutter test` kiểm tra tính toàn vẹn**

- [ ] **Step 5: Commit bước 4**

```bash
git add lib/data/repositories/management_repository.dart lib/data/repositories/issue_repository.dart test/features/management/issue_proof_storage_test.dart
git commit -m "fix(storage): hỗ trợ signed URL cho ảnh minh chứng nghiệm thu trong bucket private"
```

---

### Task 5: Chuyển Đổi Edge Function Sang Firebase Cloud Messaging HTTP v1 API (Lỗi 4)

**Files:**
- Modify: `supabase/functions/send-fcm-notification/index.ts`
- Create: `supabase/functions/send-fcm-notification/test_payload.json`

**Interfaces:**
- Consumes: Webhook payload từ bảng `notifications`, biến môi trường `FIREBASE_SERVICE_ACCOUNT` (hoặc `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`).
- Produces: Gọi `https://fcm.googleapis.com/v1/projects/{projectId}/messages:send` bằng Bearer Token OAuth 2.0.

- [ ] **Step 1: Viết module sinh Google OAuth 2.0 Access Token bằng Web Crypto API trong Deno**

Trong `supabase/functions/send-fcm-notification/index.ts`:
- Hàm `getAccessToken(serviceAccount)`:
  - Tạo JWT Header: `{"alg": "RS256", "typ": "JWT"}`
  - Tạo JWT Claims: `iss`, `scope`: `https://www.googleapis.com/auth/firebase.messaging`, `aud`: `https://oauth2.googleapis.com/token`, `exp`, `iat`.
  - Parse PEM RSA private key -> Web Crypto API `crypto.subtle.importKey(...)`.
  - Ký RSA-SHA256 bằng `crypto.subtle.sign(...)`.
  - POST đến `https://oauth2.googleapis.com/token` nhận `access_token`.

- [ ] **Step 2: Cập nhật hàm gửi thông báo sang FCM HTTP v1**

- Thay endpoint `https://fcm.googleapis.com/fcm/send` bằng:
  `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
- Cấu trúc message HTTP v1:
  ```json
  {
    "message": {
      "token": token,
      "notification": {
        "title": notification.title,
        "body": notification.body || notification.content || ""
      },
      "data": {
        "notification_id": String(notification.id),
        "type": String(notification.type || "general")
      }
    }
  }
  ```
- Kiểm tra xử lý token hết hạn (404 / `UNREGISTERED`) và xóa token chết khỏi `user_fcm_tokens`.
- Xử lý fallback an toàn: Nếu chưa cấu hình Service Account secrets thì trả về `inAppOnly: true`, không crash và không lộ private key ra log.

- [ ] **Step 3: Kiểm thử biên dịch Typescript / Deno check file**

- [ ] **Step 4: Commit bước 5**

```bash
git add supabase/functions/send-fcm-notification/index.ts
git commit -m "feat(fcm): chuyển đổi gửi thông báo đẩy từ FCM Legacy sang HTTP v1 API"
```

---

### Task 6: Kiểm Thử Toàn Diện và Nghiệm Thu (Regression & Verification)

**Files:**
- Toàn bộ repo

- [ ] **Step 1: Chạy `flutter pub get`**
- [ ] **Step 2: Chạy `flutter analyze` bảo đảm 0 warnings / 0 errors**
- [ ] **Step 3: Chạy toàn bộ test suite `flutter test`**
- [ ] **Step 4: Thực thi và xác minh trực tiếp migration trên Supabase qua `execute_sql`**
- [ ] **Step 5: Kiểm tra git log và git status sạch sẽ**
