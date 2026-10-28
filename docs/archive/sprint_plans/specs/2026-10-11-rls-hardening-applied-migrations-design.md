# Thiết Kế Kỹ Thuật: Khắc Phục Cảnh Báo Bảo Mật RLS Bảng public._applied_migrations

- **Mã Tài Liệu**: SPEC-SEC-2026-10-11-01
- **Ngày lập**: 11/10/2026
- **Trạng thái**: Đã phê duyệt (Approved)
- **Tác nhân áp dụng**: Supabase PostgreSQL / PostgREST Security Linter

---

## 1. Bối Cảnh & Vấn Đề (Problem Statement)

### 1.1. Cảnh Báo An Ninh Từ Supabase Security Advisor
Supabase Linter phát hiện cảnh báo mức **Critical (Ưu tiên 1)**:
- **Entity**: `public._applied_migrations`
- **Issue**: `Table public._applied_migrations is public, but RLS has not been enabled.`
- **Description**: `Detects cases where row level security (RLS) has not been enabled on tables in schemas exposed to PostgREST`

### 1.2. Nguyên Nhân Gốc Rễ (Root Cause)
1. Bảng `_applied_migrations` được tạo trong schema `public` (có các cột: `id INT`, `name TEXT`, `applied_at TIMESTAMPTZ`) và hiện đang có **0 dòng dữ liệu** (`rows: 0`).
2. Trong Supabase, mọi bảng trong schema `public` mặc định được expose qua PostgREST REST API.
3. Khi Row Level Security (RLS) chưa được bật (`rls_enabled: false`), bất kỳ người dùng nào có `anon` key hoặc vai trò `authenticated` (Cư dân, người ngoài) đều có thể truy vấn `SELECT`, `INSERT`, `UPDATE`, `DELETE` trực tiếp vào bảng này thông qua SDK client (`supabase.from('_applied_migrations')`).
4. Theo quy chuẩn Supabase CLI, bảng theo dõi migration chính thức nằm ở `supabase_migrations.schema_migrations` (không nằm trong `public`).

---

## 2. Giải Pháp Kỹ Thuật (Architecture & Hardening Solution)

### 2.1. Chiến Lược Phòng Thủ Đa Tầng (Defense in Depth)
Theo phương án người dùng đã lựa chọn: **Bật RLS và thu hồi quyền từ API (`anon`, `authenticated`)**, bảo vệ bảng ở cấp độ CSDL PostgreSQL:

1. **Kích hoạt Row Level Security (RLS)**:
   ```sql
   ALTER TABLE public._applied_migrations ENABLE ROW LEVEL SECURITY;
   ```
   - Khi RLS được bật và không có policy công khai nào được gán, Postgres áp dụng cơ chế **Default Deny** (chặn tất cả truy cập đọc/ghi từ client).

2. **Ép buộc RLS (Force RLS)**:
   ```sql
   ALTER TABLE public._applied_migrations FORCE ROW LEVEL SECURITY;
   ```
   - Đảm bảo ngay cả vai trò sở hữu bảng (table owner) nếu không phải superuser cũng vẫn chịu sự kiểm soát của RLS.

3. **Thu hồi quyền truy cập API PostgREST (Revoke Permissions)**:
   ```sql
   REVOKE ALL ON TABLE public._applied_migrations FROM anon, authenticated;
   ```
   - Cắt đứt hoàn toàn quyền `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, `TRIGGER` đối với vai trò khách vãng lai (`anon`) và người dùng đã xác thực (`authenticated`).

4. **Giới hạn đặc quyền tối thiểu (Least Privilege Grant)**:
   ```sql
   GRANT ALL ON TABLE public._applied_migrations TO postgres, service_role;
   ```
   - Chỉ cho phép `postgres` (Superuser / Migration runner) và `service_role` (Backend bảo mật cao) có toàn quyền vận hành.

### 2.2. Tính Bền Vững & Tương Thích (Idempotency)
- Sử dụng khối lệnh PL/pgSQL ẩn danh `DO $$ BEGIN ... END $$;` kiểm tra `IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '_applied_migrations')`.
- Đảm bảo script có thể chạy nhiều lần mà không sinh lỗi (idempotent), an toàn khi áp dụng trên môi trường staging hoặc production.

---

## 3. Kế Hoạch Kiểm Thử (Testing & Verification Strategy)

1. **Unit Test kiểm tra nội dung Migration**:
   - Viết test trong `test/data/migrations/p0_security_migration_content_test.dart` (hoặc test file chuyên biệt) xác minh file migration `20261011_02_secure_applied_migrations.sql`:
     - Tồn tại trên đĩa.
     - Chứa lệnh `ALTER TABLE public._applied_migrations ENABLE ROW LEVEL SECURITY;`.
     - Chứa lệnh `REVOKE ALL ON TABLE public._applied_migrations FROM anon, authenticated;`.
     - Chứa lệnh `GRANT ALL ON TABLE public._applied_migrations TO postgres, service_role;`.
2. **Kiểm tra hồi quy toàn diện**:
   - `flutter analyze` $\rightarrow$ 0 lỗi (`No issues found!`).
   - `flutter test` $\rightarrow$ 100% tests pass.
3. **Cung cấp Script SQL thực thi cho người dùng**:
   - Cung cấp đoạn mã SQL hoàn chỉnh để chạy trực tiếp trên Supabase Dashboard SQL Editor nhằm dập tắt ngay lập tức cảnh báo của Linter trên Cloud.
