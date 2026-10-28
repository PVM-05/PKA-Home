# Kế Hoạch Triển Khai: Khắc Phục Cảnh Báo Bảo Mật RLS Bảng public._applied_migrations

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Khắc phục triệt để cảnh báo bảo mật Critical của Supabase Security Advisor về bảng `public._applied_migrations` chưa bật RLS, bảo vệ toàn vẹn hệ thống và giữ vững 100% test passing.

**Architecture:** Tạo migration SQL mới có tính lũy kế (idempotent), kích hoạt RLS, Force RLS, thu hồi quyền từ role `anon` & `authenticated`, giới hạn quyền cho `postgres` & `service_role`. Bổ sung unit test xác thực nội dung migration và chạy toàn bộ kiểm thử tĩnh/động.

**Tech Stack:** PostgreSQL 15, Supabase Row Level Security, Flutter / Dart test suite.

## Global Constraints
- Toàn bộ commit trực tiếp vào nhánh `main`, không tạo branch hay git worktree phụ.
- Đảm bảo `flutter analyze` 0 lỗi và toàn bộ kiểm thử `flutter test` vượt qua.
- Văn bản và tài liệu sử dụng 100% tiếng Việt chuẩn mực.

---

### Task 1: Tạo Migration và Unit Test Kiểm Tra Bảo Mật

**Files:**
- Create: `supabase/migrations/20261011_02_secure_applied_migrations.sql`
- Create / Modify: `test/data/migrations/applied_migrations_security_test.dart`

**Interfaces:**
- Consumes: CSDL PostgreSQL schema `public._applied_migrations`.
- Produces: Migration SQL kích hoạt RLS và thu hồi quyền API PostgREST.

- [ ] **Step 1: Viết test thất bại (Failing Test)**
  Tạo `test/data/migrations/applied_migrations_security_test.dart` kiểm tra file `20261011_02_secure_applied_migrations.sql` tồn tại và chứa các câu lệnh bảo mật chuẩn:
  - `ALTER TABLE public._applied_migrations ENABLE ROW LEVEL SECURITY;`
  - `REVOKE ALL ON TABLE public._applied_migrations FROM anon, authenticated;`
  - `GRANT ALL ON TABLE public._applied_migrations TO postgres, service_role;`

- [ ] **Step 2: Chạy test để xác nhận test thất bại**
  Chạy: `flutter test test/data/migrations/applied_migrations_security_test.dart`
  Kết quả kỳ vọng: FAIL vì file migration chưa tồn tại.

- [ ] **Step 3: Viết file migration tối ưu**
  Tạo `supabase/migrations/20261011_02_secure_applied_migrations.sql` với logic idempotent bọc trong block `DO $$ BEGIN ... END $$;`.

- [ ] **Step 4: Chạy test để xác nhận test thành công**
  Chạy: `flutter test test/data/migrations/applied_migrations_security_test.dart`
  Kết quả kỳ vọng: PASS.

- [ ] **Step 5: Chạy toàn bộ test hồi quy & flutter analyze**
  Chạy `flutter analyze` và `flutter test`.

- [ ] **Step 6: Commit trực tiếp vào main và push lên remote**
  ```bash
  git add supabase/migrations/20261011_02_secure_applied_migrations.sql test/data/migrations/applied_migrations_security_test.dart docs/
  git commit -m "fix(db): kích hoạt RLS và thu hồi quyền API trên bảng _applied_migrations"
  git push origin main
  ```
