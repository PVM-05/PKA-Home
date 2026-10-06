# Kế Hoạch Triển Khai: Seed Dữ Liệu Demo Toàn Diện & Sống Động (PKA-Home)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng và thực thi bộ dữ liệu demo sống động, đầy đủ mọi module (3 tòa nhà, 25 căn hộ, 38 cư dân, 40 xe, 3 tháng hóa đơn, 20 giao dịch, 10 sự cố, 10 tiện ích, 10 thông báo, 5 thiết bị) với 100% email `@gmail.com` và mật khẩu `PkaHome@2026`, phục vụ thuyết trình bảo vệ đồ án.

**Architecture:** Đồng bộ các DDL migrations còn thiếu lên Supabase -> Xây dựng script `supabase/seed.sql` toàn diện, idempotent -> Thực thi seed dữ liệu qua MCP `execute_sql` -> Xác minh số lượng bản ghi -> Soạn tài liệu tra cứu tài khoản demo `docs/demo_accounts.md`.

**Tech Stack:** Supabase (PostgreSQL 15, Auth schema, pgcrypto), Flutter 3.x, Riverpod.

## Global Constraints
- 100% email người dùng kết thúc bằng `@gmail.com`.
- Mật khẩu đăng nhập thống nhất: `PkaHome@2026` (sử dụng `crypt('PkaHome@2026', gen_salt('bf'))`).
- Mã căn hộ chuẩn định dạng `A0101` - `C0305`.
- Script seed phải mang tính Idempotent (`ON CONFLICT DO NOTHING` hoặc `ON CONFLICT DO UPDATE`) để có thể chạy nhiều lần mà không sinh lỗi trùng lặp.
- 100% text giao diện và mô tả tiếng Việt chuẩn mực, không emoji.

---

### Task 1: Đồng bộ các DDL Migration còn thiếu lên Supabase

**Files:**
- Nguồn DDL:
  - `supabase/migrations/20261004_02_building_equipment_maintenance.sql`
  - `supabase/migrations/20261005_03_unified_payment_simulation.sql`
  - `supabase/migrations/20261005_05_meter_reading_submissions.sql`
  - `supabase/migrations/20260929_01_issue_ratings_and_kpi.sql`
  - `supabase/migrations/20261004_01_advanced_amenity_management.sql`
- Test / Verify: MCP tool `execute_sql`

- [ ] **Step 1: Thực thi DDL tạo bảng `equipment` và nhật ký bảo trì**
- [ ] **Step 2: Thực thi DDL tạo bảng `payment_transactions` và RPC `simulate_unified_payment`**
- [ ] **Step 3: Thực thi DDL tạo bảng `meter_reading_submissions` và RPC duyệt chỉ số**
- [ ] **Step 4: Thực thi DDL tạo bảng `issue_ratings` và hàm tính rating**
- [ ] **Step 5: Kiểm tra và đảm bảo bảng `amenities` / `building_amenities` và `amenity_bookings` đồng bộ**
- [ ] **Step 6: Kiểm tra `to_regclass` xác minh 100% bảng đã tồn tại trên Supabase**

---

### Task 2: Xây dựng Kịch bản Seed Dữ Liệu `supabase/seed.sql`

**Files:**
- Modify: `supabase/seed.sql`
- Tham chiếu: `docs/superpowers/specs/2026-10-06-rich-demo-data-seed-design.md`

- [ ] **Step 1: Viết khối tạo người dùng (38 users: 1 admin, 1 kế toán, 1 kỹ thuật, 35 cư dân) trong `auth.users` và `public.users`**
- [ ] **Step 2: Viết khối cập nhật 25 căn hộ (`is_empty = false`) và liên kết cư dân `residents_apartments` (chủ hộ, người thuê, người thân)**
- [ ] **Step 3: Viết khối 40 phương tiện (28 xe máy, 12 ô tô; 32 approved, 5 pending, 3 rejected)**
- [ ] **Step 4: Viết khối 5 trang thiết bị vận hành tòa nhà (`equipment`)**
- [ ] **Step 5: Viết khối 10 lượt đặt tiện ích (`amenity_bookings`)**
- [ ] **Step 6: Viết khối hóa đơn 3 tháng (08, 09, 10/2026) kèm chi tiết `invoice_items`**
- [ ] **Step 7: Viết khối 20 giao dịch thanh toán VietQR (`payment_transactions`)**
- [ ] **Step 8: Viết khối chỉ số điện nước (`meter_reading_submissions`)**
- [ ] **Step 9: Viết khối 10 phản ánh sự cố (`issue_reports`, `issue_images`, `issue_ratings`)**
- [ ] **Step 10: Viết khối 10 thông báo tòa nhà (`announcements`)**

---

### Task 3: Thực thi Kịch bản Seed Dữ Liệu lên Supabase & Kiểm thử Ràng Buộc

**Files:**
- Execute: `supabase/seed.sql`
- Verify: MCP `execute_sql`

- [ ] **Step 1: Chạy khối Users & Apartments**
- [ ] **Step 2: Chạy khối Vehicles & Equipment & Amenities**
- [ ] **Step 3: Chạy khối Invoices, Items & Payment Transactions**
- [ ] **Step 4: Chạy khối Issues, Meter Readings & Announcements**
- [ ] **Step 5: Chạy câu lệnh COUNT(*) xác minh số lượng bản ghi của toàn bộ 15 bảng**

---

### Task 4: Soạn Tài Liệu Tra Cứu Tài Khoản Demo Phục Vụ Thuyết Trình

**Files:**
- Create: `docs/demo_accounts.md`

- [ ] **Step 1: Soạn bảng tổng hợp tài khoản BQL (Admin, Kế toán, Kỹ thuật) kèm kịch bản demo**
- [ ] **Step 2: Soạn bảng tài khoản Cư dân tiêu biểu (Block A, B, C) kèm kịch bản demo từng căn hộ**
- [ ] **Step 3: Cam kết commit tài liệu vào git**

---

### Task 5: Kiểm thử Tích hợp & Xác minh Hệ thống Toàn Diện

**Files:**
- Test: `test/`
- Tool: `flutter test`, `dart analyze`

- [ ] **Step 1: Chạy `dart analyze` đảm bảo 0 lỗi, 0 cảnh báo**
- [ ] **Step 2: Chạy toàn bộ test suites `flutter test` đảm bảo 100% tests vượt qua**
- [ ] **Step 3: Kết thúc nhánh và báo cáo kết quả hoàn thành**
