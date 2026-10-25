# Kế Hoạch Thực Thi: Củng Cố Toàn Vẹn Giao Dịch Waitlist, Định Dạng Giờ Mở Cửa & Quyền Thực Thi RPC

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khắc phục triệt để 4 điểm quan ngại trong báo cáo kiểm toán P1: đồng bộ bản ghi giao dịch thanh toán khi đôn Waitlist, xác thực chặt chẽ regex 24h và giờ mở cửa, bổ sung phân quyền EXECUTE cho RPC đặc quyền, và cập nhật số liệu kiểm thử 365/365 vào README.

**Architecture:** CSDL PostgreSQL (Migration DDL, PL/pgSQL Atomic RPCs, Transaction Idempotency, RBAC Security Grants), Dart/Flutter Testing (Mocktail, Migration Integrity Tests).

**Tech Stack:** PostgreSQL (PL/pgSQL, Triggers, Advisory Locks, Security Definer), Flutter/Dart, Supabase SDK.

## Global Constraints
- Tuân thủ quy định dự án: Commit trực tiếp vào nhánh `main`, không tạo branch/worktree phụ.
- Đảm bảo 100% tiếng Việt trên giao diện người dùng theo `design-rules.md`.
- Bảo toàn tính toàn vẹn tài chính: Không để sót booking ở trạng thái `pending_payment` mà không có bản ghi `payment_transactions`.
- Không nuốt lỗi dữ liệu: Khi `open_hours` có dữ liệu sai định dạng phải ném ngoại lệ rõ ràng.

---

### Task 1: Nâng Cấp Migration & Củng Cố CSDL

**Files:**
- Modify: `supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql`

**Interfaces:**
- Consumes: Bảng `public.amenity_bookings`, `public.payment_transactions`, `public.building_amenities`.
- Produces: Hàm `reschedule_amenity_booking` tự động tạo/cập nhật `payment_transactions`, regex 24h chuẩn, xác thực `open_hours` nghiêm ngặt; trigger `handle_amenity_booking_cancellation` đồng bộ giao dịch; phân quyền `GRANT EXECUTE` đầy đủ cho `approve_link_request`.

- [x] **Step 1: Viết test kiểm tra các yêu cầu củng cố mới trong migration**
- [x] **Step 2: Chạy test để xác nhận test thất bại (Red)**
- [x] **Step 3: Cập nhật hàm `reschedule_amenity_booking` và trigger trong migration (Green)**
- [x] **Step 4: Bổ sung REVOKE và GRANT EXECUTE cho `approve_link_request`**
- [x] **Step 5: Chạy lại test migration để xác nhận pass**
- [x] **Step 6: Commit thay đổi Task 1**

---

### Task 2: Cập Nhật README.md & Đồng Bộ Số Liệu Kiểm Thử

**Files:**
- Modify: `README.md`

- [x] **Step 1: Cập nhật số lượng bài test trong README.md thành 368/368**
- [x] **Step 2: Bổ sung ghi chú giải thích về 3 integration test RLS skip có chủ đích khi thiếu remote credentials**
- [x] **Step 3: Commit thay đổi Task 2**

---

### Task 3: Xác Minh Toàn Hệ Thống & Đẩy Lên GitHub

**Files:**
- Toàn bộ codebase.

- [x] **Step 1: Chạy `dart analyze` để kiểm tra tĩnh toàn bộ mã nguồn**
- [x] **Step 2: Chạy toàn bộ bộ kiểm thử `flutter test`**
- [x] **Step 3: Thực hiện `git push origin main` và xác nhận đồng bộ**
