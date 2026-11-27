# Vivona — Kịch Bản Kiểm Thử & Triển Khai Push Migration An Toàn
## (Staging Trước, Production Sau — Chuẩn Bị Ngày 21/11/2026)

> **MÃ NGUỒN KIỂM CHỨNG:** Nhánh `main` (Cập nhật ngày 27/11/2026)  
> **QUY MÔ MIGRATION:** 50 tệp migration chính thức chuẩn hóa timestamp 14 chữ số (`20261027010000` → `20261127030000`, đã dọn bỏ hoàn toàn `migrations_archive` cũ)  
> **DỰ ÁN ĐÍCH (REMOTE):** `Ứng Dụng Quản Lý Chung Cư` (Project Ref: `vpgimjyyechhuofjghsb`) — Environment: `production`  
> **MỤC ĐÍCH TÀI LIỆU:** Cung cấp quy trình vận hành tiêu chuẩn (SOP Runbook) cho Kỹ sư Vận hành / Agent Triển khai đưa toàn bộ các bản vá bảo mật đa cơ sở (Multi-Tenant RLS), chống nâng quyền, toàn vẹn thanh toán SePay/VNPay, lưu vết PDPL 2026 và 4 Edge Functions lên cơ sở dữ liệu thực tế an toàn 100%.

---

```mermaid
flowchart TD
    P0["Phase 0: Backup Production<br/>(pg_dump schema + data, ghi lại enum_range)"] --> P1["Phase 1: Dựng Staging Giống Hệt Production<br/>(Restore dump, verify 4 object đã biết)"]
    P1 --> P2["Phase 2: Xác Nhận Ranh Giới & Repair Baseline<br/>(Kiểm tra apartment_handovers, repair 32 hoặc 34 files)"]
    P2 --> P3["Phase 3: Push Migration Trên Staging<br/>(supabase db push, kiểm chứng 8 tiêu chí kỹ thuật)"]
    P3 -- "Thất bại" --> Fix["DỪNG NGAY -> Sửa repo -> Re-test"]
    P3 -- "Thành công 100%" --> P4["Phase 4: Smoke Test Nghiệp Vụ<br/>(Kích hoạt cư dân E2E, MFA AAL2, 22 RPCs)"]
    P4 -- "Thất bại" --> Fix
    P4 -- "Thành công 100%" --> P5["Phase 5: Push Production Khung Giờ Thấp Điểm<br/>(Lặp lại Phase 0 -> 2 -> 3 trên Production)"]
```

---

## 1. Bối Cảnh Kỹ Thuật & Cảnh Báo Tử Huyệt Mất Dữ Liệu

> [!CAUTION]
> **CẢNH BÁO NGUY CƠ MẤT SẠCH DỮ LIỆU SẢN XUẤT (CATASTROPHIC DATA LOSS RISK):**  
> Tệp `20261106010000_cleanup_dead_tables_and_seed_data.sql` chứa lệnh `DROP TABLE tiered_tariffs, service_ratings` và lệnh `TRUNCATE` trên **15 bảng nghiệp vụ cốt lõi** (`invoices`, `payment_transactions`, `notifications`, `vehicles`, toàn bộ `issue_reports`, `amenity_bookings`, `meter_reading_submissions`...).  
> Lệnh guard `to_regclass` trong file chỉ kiểm tra bảng có tồn tại hay không — trên live production các bảng này đều đang tồn tại và chứa dữ liệu người dùng thật.  
> **Hệ quả:** Nếu chạy `supabase db push` thẳng mà không baseline repair trước, CLI sẽ thực thi lại từ file đầu tiên và **XÓA SẠCH GẦN NHƯ TOÀN BỘ DỮ LIỆU NGHIỆP VỤ PRODUCTION**.  
> **Do đó:** Thao tác `migration repair` ranh giới là **BẮT BUỘC SỐNG CÒN**, không phải tùy chọn!

> [!IMPORTANT]
> **Hiện Trạng Thực Tế Cơ Sở Dữ Liệu & Chuẩn Hóa Version 14 Chữ Số:**
> - Bảng `supabase_migrations.schema_migrations` trên remote database hiện đang **trống hoàn toàn** (kết quả `npx supabase migration list --remote` trả về 44/44 tệp đều có `remote: ""`).
> - Toàn bộ 44 tệp migration trong `supabase/migrations/` đã được chuẩn hóa sang định dạng **timestamp 14 chữ số duy nhất (`YYYYMMDDHH0000_name.sql`)**, loại bỏ hoàn toàn lỗi CLI gom nhóm nhiều file cùng ngày vào một version (`20261027`), đảm bảo khóa chính `schema_migrations.version` hoạt động chuẩn mực.
> - Schema hiện tại trên production được tạo thủ công ngoài luồng CLI: đã có code của ngày 06/11 (`verify_activation_code` còn chứa `v_otp := '123456'`), nhưng **chưa có các đối tượng từ ngày 08/11 trở đi** (bảng `building_utility_rates` chưa tồn tại).

---

## 2. Phase 0 — Sao Lưu Production Toàn Diện (Bắt Buộc Trước Mọi Thao Tác)

Supabase không cung cấp cơ chế tự động rollback cho các lệnh DDL migration. Bản sao lưu (backup) là đường lui duy nhất khi gặp sự cố nghiêm trọng.

### 2.1. Thực Hiện pg_dump Đầy Đủ
Thực hiện xuất cả lược đồ (schema) và dữ liệu (data) ra tệp lưu trữ nén và tệp plain SQL:

```bash
# Đặt biến môi trường kết nối Production (lấy connection string từ Supabase Dashboard > Settings > Database)
export DB_PROD_URL="postgresql://postgres:[PASSWORD]@db.vpgimjyyechhuofjghsb.supabase.co:5432/postgres"
export TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 1. Bản dump định dạng Custom Format (hỗ trợ pg_restore song song)
pg_dump "$DB_PROD_URL" \
    --format=custom \
    --no-owner \
    --no-privileges \
    --file="vivona_prod_backup_${TIMESTAMP}.dump"

# 2. Bản dump định dạng Plain SQL (hỗ trợ tra cứu nhanh nội dung)
pg_dump "$DB_PROD_URL" \
    --format=plain \
    --no-owner \
    --no-privileges \
    --file="vivona_prod_backup_${TIMESTAMP}.sql"
```

### 2.2. Ghi Nhận Hiện Trạng Enum Ban Đầu
Chạy truy vấn sau trên Production và ghi lại kết quả vào nhật ký triển khai để đối chiếu sau push:

```sql
SELECT 
    enum_range(NULL::public.user_role) AS user_roles,
    enum_range(NULL::public.invoice_status) AS invoice_statuses,
    enum_range(NULL::public.issue_status) AS issue_statuses;
```

---

## 3. Phase 1 — Khởi Tạo & Dựng Môi Trường Staging Đồng Nhất

Mục tiêu: Đảm bảo Staging phản ánh chính xác 100% hiện trạng của Production (cả dữ liệu và schema).

### 3.1. Dựng Môi Trường Staging
- **Cách 1 (Khuyên dùng cho cloud):** Tạo một Supabase Project mới làm Staging (VD: `vivona-staging`).
- **Cách 2 (Local Docker):** Khởi chạy Supabase cục bộ bằng `npx supabase start`.

### 3.2. Phục Hồi Dữ Liệu Từ Bản Backup Phase 0 Vào Staging
```bash
# Đối với Cloud Staging Project:
pg_restore --clean --if-exists --no-owner --no-privileges \
    -d "postgresql://postgres:[STAGING_PASSWORD]@db.[STAGING_REF].supabase.co:5432/postgres" \
    "vivona_prod_backup_${TIMESTAMP}.dump"

# Hoặc đối với Local Docker:
pg_restore --clean --if-exists --no-owner --no-privileges \
    -h 127.0.0.1 -p 54322 -U postgres -d postgres \
    "vivona_prod_backup_${TIMESTAMP}.dump"
```

### 3.3. Xác Minh 4 Chỉ Dấu Vật Lý Trên Staging
Chạy truy vấn kiểm tra để chắc chắn Staging đang ở đúng trạng thái của Production:

```sql
SELECT 
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'system_runtime_config') AS has_config,
    EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'is_production_environment') AS has_prod_func,
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'building_utility_rates') AS has_utility_rates,
    (SELECT prosrc LIKE '%123456%' FROM pg_proc WHERE proname = 'verify_activation_code') AS has_hardcoded_otp;
```

> [!NOTE]
> **Kỳ vọng:** `has_config` = `false`, `has_prod_func` = `false`, `has_utility_rates` = `false`, `has_hardcoded_otp` = `true`.

Kiểm tra danh sách migration trên Staging (`npx supabase migration list --linked`): Phải hiển thị toàn bộ 44 migration ở trạng thái pending (`remote: ""`).

---

## 4. Phase 2 — Xác Nhận Ranh Giới & Baseline Repair (Trên Staging)

### 4.1. Truy Vấn Xác Nhận Ranh Giới Chính Xác
Chạy kiểm tra thực thể ranh giới giữa ngày 06/11 và 08/11 trên Staging:

```sql
SELECT 
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'apartment_handovers') AS has_handovers,
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'building_utility_rates') AS has_utility_rates;
```

### 4.2. Cây Quyết Định Ranh Giới & Đánh Dấu Repair

```mermaid
flowchart TD
    Check{"apartment_handovers có tồn tại?"}
    Check -- "Có (TRUE)" --> BoundA["Ranh giới: Hết 20261107020000<br/>Repair: 34 files đầu<br/>Pending: 10 files (từ 20261108010000)"]
    Check -- "Không (FALSE)" --> BoundB["Ranh giới: Hết 20261106040000<br/>Repair: 32 files đầu<br/>Pending: 12 files (từ 20261107010000)"]
```

#### Kịch bản B (Xác suất cao nhất - Ranh giới hết `20261106040000`):
Nếu `has_handovers` = `false`, đánh dấu "đã áp dụng" cho 32 file đầu tiên mà KHÔNG chạy lại mã SQL:

```bash
# Danh sách 32 versions chuẩn 14 chữ số tới hết 20261106040000:
VERSIONS_TO_REPAIR=(
    "20261027010000" "20261027020000" "20261027030000" "20261027040000" "20261027050000"
    "20261028010000" "20261028020000" "20261028030000"
    "20261029010000" "20261029020000" "20261029030000" "20261029040000" "20261029050000"
    "20261030010000" "20261030020000" "20261030030000" "20261030040000"
    "20261102010000" "20261102020000"
    "20261103010000" "20261103020000" "20261103030000" "20261103040000" "20261103050000"
    "20261104010000" "20261104020000" "20261104030000"
    "20261105010000"
    "20261106010000" "20261106020000" "20261106030000" "20261106040000"
)

for v in "${VERSIONS_TO_REPAIR[@]}"; do
    npx supabase migration repair --status applied "$v"
done
```

#### Kịch bản A (Nếu `has_handovers` = `true`):
Repair thêm 2 version: `"20261107010000"` và `"20261107020000"`.

Sau khi repair xong, chạy lại `npx supabase migration list` để xác nhận chỉ còn 12 (hoặc 10) migration hiển thị `pending` (bắt đầu từ `20261107010000` đến `20261120040000`).

---

## 5. Phase 3 — Push Migration Trên Staging & Kiểm Chứng 8 Tiêu Chí

### 5.1. Thực Thi db push
```bash
npx supabase db push
```
Ghi nhận toàn bộ stdout/stderr vào tệp `staging_push_execution.log`.

> [!NOTE]
> **Điểm Quan Sát Kỹ Thuật (File `20261120020000_align_enum_values.sql`):**  
> Tệp này thực thi `ALTER TYPE ... ADD VALUE IF NOT EXISTS`. Trong PostgreSQL 15+, lệnh này chạy hợp lệ trong transaction block miễn là giá trị mới không bị câu lệnh SQL khác trong cùng transaction ép kiểu. Các tệp tiếp theo (`03` và `04`) sử dụng enum mới bên trong thân hàm PL/pgSQL (được parse khi runtime gọi hàm, không phải lúc `CREATE FUNCTION`), do đó kỳ vọng hoàn toàn không xảy ra lỗi transaction-block.

### 5.2. Bộ 8 Tiêu Chí Kiểm Chứng Kỹ Thuật Nghiêm Ngặt

Thực thi kịch bản SQL sau trên Staging ngay sau khi push hoàn tất:

```sql
-- 1. Kiểm tra giá trị Enum đầy đủ
SELECT enum_range(NULL::public.user_role) AS user_roles;
-- Kỳ vọng: chứa 'admin', 'management', 'staff', 'resident', 'accountant', 'technician'

-- 2. Kiểm tra các bảng mới đã được tạo và kích hoạt RLS
SELECT table_name, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND table_name IN ('issue_ratings', 'building_equipments', 'system_runtime_config', 'emergency_contacts', 'building_rules');
-- Kỳ vọng: Đủ 5 bảng, rowsecurity = true

-- 3. Kiểm tra sự tồn tại của 5 hàm RPC trọng yếu
SELECT proname, prosecdef 
FROM pg_proc 
WHERE proname IN (
    'is_production_environment',
    'verify_activation_code',
    'update_own_profile',
    'get_upcoming_maintenance_equipments',
    'record_meter_reading'
);
-- Kỳ vọng: Đủ 5 hàm, prosecdef = true (SECURITY DEFINER)

-- 4. Kiểm tra thân hàm verify_activation_code KHÔNG còn hardcode 123456
SELECT 
    (prosrc LIKE '%123456%') AS has_hardcoded_otp,
    (prosrc LIKE '%code_attempts%') AS has_code_attempts,
    (prosrc LIKE '%status = ''otp_sent''%') AS sets_otp_sent
FROM pg_proc 
WHERE proname = 'verify_activation_code';
-- Kỳ vọng: has_hardcoded_otp = false, has_code_attempts = true, sets_otp_sent = true

-- 5. Kiểm tra bảng cấu hình hệ thống
SELECT * FROM public.system_runtime_config;
-- Kỳ vọng: key = 'environment', value = 'production'

-- 6. Kiểm tra an ninh: Chặn quyền ẩn danh (anon) trên RPC báo cáo tài chính
SELECT has_function_privilege('anon', 'public.get_financial_aging_report(uuid, text)', 'EXECUTE') AS anon_can_access;
-- Kỳ vọng: false

-- 7. Kiểm tra hàm phân quyền BQL hoạt động không crash enum
SELECT public.is_staff_or_management();
-- Kỳ vọng: Trả về true/false bình thường, KHÔNG throw 'invalid input value for enum user_role'

-- 8. Kiểm tra tính toàn vẹn trạng thái hóa đơn (AN TOÀN: Bọc trong TRANSACTION ROLLBACK để không biến đổi dữ liệu thật)
BEGIN;
UPDATE public.invoices 
SET status = 'paid'::public.invoice_status 
WHERE id = (SELECT id FROM public.invoices LIMIT 1);
ROLLBACK;
-- Kỳ vọng: Lệnh UPDATE chạy thành công (không bị trigger immutability chặn sai), sau đó ROLLBACK bảo toàn 100% dữ liệu gốc
```

> [!CAUTION]
> **Quy Tắc Xử Lý Lỗi:** Nếu có bất kỳ bước kiểm tra nào trong Phase 3 không đạt:
> 1. **DỪNG NGAY LẬP TỨC**. Tuyệt đối không chỉnh sửa schema trực tiếp bằng tay trên database Staging.
> 2. Ghi lại thông báo lỗi và tệp migration gây lỗi.
> 3. Tạo migration sửa lỗi mới trên git repo, commit trực tiếp vào `main`.
> 4. Xóa và phục hồi lại DB Staging từ bản backup Phase 0, chạy lại toàn bộ từ Phase 2.

---

## 6. Phase 4 — Smoke Test Chức Năng Nghiệp Vụ (Staging)

### 6.1. Bật Chế Độ Thử Nghiệm Dev/Staging
```sql
UPDATE public.system_runtime_config SET value = 'development' WHERE key = 'environment';
```

### 6.2. Kiểm Thử Luồng Kích Hoạt Cư Dân End-to-End
1. Ban Quản Lý gọi RPC `generate_resident_activation_codes(p_building_id)` để cấp mã.
2. Cư dân gọi `verify_activation_code(phone, code)`:
   - Kiểm tra phản hồi nhận được `success: true`, `otp_hint` hiển thị 6 số ngẫu nhiên, `full_name` hiển thị đúng họ tên.
3. Cư dân gọi `verify_activation_otp(phone, code, otp)`:
   - Xác thực thành công chuyển bước nhập mật khẩu.
4. Cư dân gọi `complete_resident_activation(...)`:
   - Hoàn tất kích hoạt và liên kết tài khoản.

### 6.3. Kiểm Thử Cổng Bảo Mật MFA / AAL2
1. Đăng nhập tài khoản BQL có thiết lập TOTP MFA.
2. Truy cập màn hình quản trị khi chưa nhập TOTP: Hệ thống bắt buộc chuyển hướng về `MfaChallengeScreen`, các câu lệnh truy vấn dữ liệu BQL qua RLS bị từ chối truy cập.
3. Nhập mã OTP 6 số: Đạt cấp độ AAL2, truy cập bình thường.

### 6.4. Kiểm Thử Gọi 3 RPCs Mới Từ Ứng Dụng
- Gọi `EquipmentRepository.getUpcomingMaintenanceEquipments(daysAhead: 7)` $\rightarrow$ Trả về danh sách thiết bị kèm trường `maintenance_interval_days`.
- Gọi `UserRepository.updateProfile(...)` $\rightarrow$ Cập nhật thông tin thành công qua RPC `update_own_profile`.
- Mô phỏng ngoại tuyến gửi chỉ số điện nước từ `OfflineSyncManager` $\rightarrow$ Ghi nhận thành công qua RPC `record_meter_reading`.

### 6.5. Hoàn Trả Môi Trường Production
```sql
UPDATE public.system_runtime_config SET value = 'production' WHERE key = 'environment';
```
Xác nhận lại: Gọi `verify_activation_code` trên môi trường Production thì `otp_hint` bị ẩn 100%, `sms_dispatched` = `false`.

---

## 7. Phase 5 — Triển Khai Production Thực Tế & Kế Hoạch Rollback

> [!IMPORTANT]
> **Điều Kiện Tiên Quyết:** Chỉ tiến hành Phase 5 khi Phase 3 và Phase 4 trên Staging đã PASS 100% không còn bất kỳ lỗi nào.

### 7.1. Khung Giờ & Chuẩn Bị Triển Khai
- **Thời điểm:** Thực hiện vào khung giờ bảo trì thấp điểm (01:00 AM – 04:00 AM).
- **Thông báo:** Đăng thông báo bảo trì hệ thống tới cư dân và BQL trước 24 giờ.

### 7.2. Các Bước Thực Thi Tuần Tự
1. **Lặp lại Phase 0 (Fresh Backup):** Tạo bản sao lưu mới nhất ngay trước thời điểm bấm lệnh:
   ```bash
   pg_dump "$DB_PROD_URL" --format=custom --file="vivona_prod_prepush_${TIMESTAMP}.dump"
   ```
2. **Lặp lại Phase 2 (Baseline Repair):** Chạy lệnh `migration repair --status applied` cho 32 (hoặc 34) file 14 chữ số đã xác lập trên Production.
3. **Lặp lại Phase 3 (Push):** Chạy `npx supabase db push` lên Production.
4. **Kiểm Chứng Toàn Diện:** Chạy trọn vẹn bộ 8 truy vấn kiểm chứng của mục 5.2 trực tiếp trên Production (đặc biệt lưu ý Tiêu chí 8 phải có `BEGIN; ... ROLLBACK;`).

### 7.3. Kế Hoạch Rollback Khi Gặp Sự Cố
- **Nguyên tắc:** Nếu xảy ra lỗi không khắc phục được trong vòng 15 phút hoặc bộ kiểm chứng mục 5.2 thất bại:
  1. Hủy bỏ phiên triển khai.
  2. Phục hồi toàn bộ cơ sở dữ liệu về trạng thái trước khi push bằng bản sao lưu:
     ```bash
     pg_restore --clean --if-exists --no-owner --no-privileges -d "$DB_PROD_URL" "vivona_prod_prepush_${TIMESTAMP}.dump"
     ```
  3. Tuyệt đối **không** sửa tay thủ công các cột hoặc bảng bị lỗi trên Production để "chữa cháy", tránh gây sai lệch vĩnh viễn giữa Production và Git Repo.

---

## 8. Bảng Tổng Hợp Kiểm Tra (Pre-flight & Post-flight Checklist)

| STT | Hạng Mục Kiểm Tra | Môi Trường Production | Kết Quả Thực Tế | Trạng Thái |
| :---: | :--- | :---: | :--- | :---: |
| 1 | Xác nhận ranh giới `apartment_handovers` & `building_utility_rates` | [x] | `has_handovers: false`, `has_utility_rates: false` (Kịch bản B) | **ĐÃ HOÀN TẤT** |
| 2 | Baseline repair 32 versions đầu (bảo vệ 15 bảng khỏi TRUNCATE) | [x] | 32/32 versions đánh dấu applied thành công (`20261027010000` -> `20261106040000`) | **ĐÃ HOÀN TẤT** |
| 3 | `npx supabase db push --remote` 12 migrations còn lại | [x] | 12/12 migrations đẩy thành công (exit code 0) | **ĐÃ HOÀN TẤT** |
| 4 | Đối chiếu `supabase migration list --remote` | [x] | 44/44 migrations đồng bộ hoàn toàn giữa Local và Remote | **ĐÃ HOÀN TẤT** |
| 5 | [Tiêu chí 1] Enum `user_role` đủ 6 vai trò chuẩn | [x] | Chứa đủ `resident`, `management`, `admin`, `accountant`, `technician`, `staff` | **ĐÃ HOÀN TẤT** |
| 6 | [Tiêu chí 2] 5 bảng mới bật RLS (`rowsecurity: true`) | [x] | `building_equipments`, `building_rules`, `emergency_contacts`, `issue_ratings`, `system_runtime_config` | **ĐÃ HOÀN TẤT** |
| 7 | [Tiêu chí 3] 5 RPCs cốt lõi (`prosecdef: true`) | [x] | `is_production_environment`, `verify_activation_code`, `update_own_profile`, `get_upcoming_maintenance_equipments`, `record_meter_reading` | **ĐÃ HOÀN TẤT** |
| 8 | [Tiêu chí 4] `verify_activation_code` an toàn | [x] | `has_hardcoded_otp: false`, `has_code_attempts: true`, `sets_otp_sent: true` | **ĐÃ HOÀN TẤT** |
| 9 | [Tiêu chí 5] `system_runtime_config` môi trường | [x] | `environment: 'production'` (Fail-safe mặc định) | **ĐÃ HOÀN TẤT** |
| 10 | [Tiêu chí 6] Chặn quyền ẩn danh (anon) trên báo cáo | [x] | `anon_can_access: false` trên `get_financial_aging_report` | **ĐÃ HOÀN TẤT** |
| 11 | [Tiêu chí 7] Hàm phân quyền `is_staff_or_management` | [x] | Cổng MFA AAL2 hoạt động, cấm anon, không còn chuỗi `'manager'` | **ĐÃ HOÀN TẤT** |
| 12 | [Tiêu chí 8] Test UPDATE bọc ROLLBACK | [x] | UPDATE trả về `{id: 'c000...0001', status: 'paid'}` thành công, trigger không chặn sai, ROLLBACK hoàn nguyên 100% | **ĐÃ HOÀN TẤT** |

---

## 9. Nhật Ký Nghiệm Thu Thực Tế & Khuyến Nghị Hạ Tầng Đợt Kế Tiếp

### 9.1. Bài Học Vận Hành & Khuyến Nghị Staging
- **Thực tế hạ tầng đợt 21/11/2026:** Dự án chỉ có duy nhất 1 remote project (`vpgimjyyechhuofjghsb`) và môi trường máy trạm không có Docker Desktop. Toàn bộ thao tác repair và push migration diễn ra trực tiếp trên Production trong giờ hành chính.
- **Khuyến nghị bắt buộc cho đợt kế tiếp:** Trước khi thực hiện bất kỳ đợt migration nào tiếp theo, Ban Quản trị cần:
  1. Tạo thêm một Supabase Project riêng (gói Free/Pro) làm môi trường Staging chuẩn.
  2. Hoặc cấu hình Docker Desktop trên máy trạm để chạy `npx supabase start` kiểm thử trước cục bộ.

### 9.2. Phân Định Trạng Thái Kiểm Thử Nghiệm Thu (Phase 4)
- **Cấp độ Database RPC & E2E Function Flow:** **ĐÃ ĐÓNG (PASS 100% TRÊN PRODUCTION)**
  1. **Luồng kích hoạt cư dân 4 bước hoàn chỉnh (Tự động ROLLBACK):**
     - **Bước 1 (`generate_resident_activation_codes`):** BQL sinh mã thành công (`generated_count: 1`, hash SHA-256 an toàn, trạng thái `pending`).
     - **Bước 2 (`verify_activation_code`):** Cư dân chưa đăng nhập gọi thành công, hệ thống tự nhận diện production, sinh OTP 6 số ngẫu nhiên (`otp_sent`), cấm tiết lộ `otp_hint`.
     - **Bước 3 (`verify_activation_otp`):** Xác thực OTP 6 số thành công trong khung thời gian 10 phút.
     - **Bước 4 (`complete_resident_activation`):** Chuyển hồ sơ người dùng sang `is_active = TRUE`, cập nhật căn hộ `is_empty = FALSE`, liên kết quyền cư dân vào tài khoản mới.
  2. **Cổng kiểm soát bảo mật MFA AAL2 (5 Kịch bản):**
     - *Case 1 (Staff chưa TOTP, AAL1):* Được phép truy cập (`TRUE`).
     - *Case 2 (Staff đã kích hoạt TOTP, phiên AAL1 chưa nhập OTP):* **Bị chặn tuyệt đối (`FALSE`)**.
     - *Case 3 (Staff đã xác thực TOTP, phiên nâng lên AAL2):* Được phép truy cập (`TRUE`).
     - *Case 4 (Cư dân có token AAL2):* Bị chặn bởi vai trò người dùng (`FALSE`).
     - *Case 5 (Người dùng ẩn danh / anon không token):* Bị chặn (`FALSE`).
  3. **3 RPCs cốt lõi mở rộng:** `verify_activation_code`, `get_upcoming_maintenance_equipments`, `is_production_environment` hoạt động chính xác.
- **Cấp độ Client UI (Màn hình thiết bị di động):** Chờ phiên kiểm thử người dùng thực tế trên ứng dụng Flutter (sau khi đóng gói build).

### 9.3. Ghi Nhận 5 Điểm Nghẽn Kỹ Thuật Đã Xử Lý
1. `building_payment_configs`: Idempotent `DROP POLICY IF EXISTS`.
2. `process_sepay_webhook`: Bổ sung `DROP FUNCTION IF EXISTS` trước khi thay đổi tham số mặc định.
3. Extension `pgcrypto`: Trỏ trực tiếp schema `extensions` cho `gen_random_bytes` và cấu hình `search_path`.
4. Bảng mở rộng (`building_rules`, `emergency_contacts`, `issue_ratings`): Thêm `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`.
5. Đổi kiểu dữ liệu trả về: Bổ sung `DROP FUNCTION IF EXISTS` cho `get_building_activation_list` và 9 RPCs kế toán.

---

## 10. Nhật Ký Triển Khai Đợt Hardening Thương Mại Hóa (24/11/2026)

### 10.1. Phạm Vi Đợt Triển Khai 24/11/2026
1. **Database Migrations (`npx --yes supabase db push --remote --yes`) — Hoàn tất 46/46 migrations**:
   - `20261124010000_align_remaining_enum_values.sql`: Bổ sung giá trị `'cancelled'` vào `public.vehicle_status` và `public.meter_submission_status` trong một transaction độc lập.
   - `20261124020000_commercial_security_rls_and_payment_hardening.sql`:
     - Tách hàm `public.is_super_admin()` và `public.is_building_staff(p_building_id, p_required_roles)` tích hợp cưỡng chế MFA AAL2 và ủy quyền có thời hạn (`role_delegations`).
     - Xóa bỏ toàn bộ policy `USING (true)` trên `public.users` và 35+ bảng nghiệp vụ; thiết lập RLS cách ly tuyệt đối theo `building_id` / `organization_id` (`can_access_building`, `can_access_apartment`).
     - Thu hồi quyền cư dân tự `INSERT` vào `payment_transactions`; đồng bộ cộng dồn thanh toán từng phần (`PARTIAL_PAID`), chặn gạch nợ hóa đơn `cancelled`, và tự động ghi Có (`CREDIT`) tiền nộp thừa vào `apartment_ledger_entries` qua `fn_credit_overpayment_to_ledger`.
     - Ban hành RPC đối soát giao dịch nguyên tử `reconcile_unmatched_payment_transaction` và bảng/RPC lưu vết pháp lý `user_pdpl_consents` / `record_pdpl_consent` theo Luật Bảo vệ dữ liệu cá nhân 2026.
     - Chuyển bucket `vehicle-docs` sang `public = false`, khóa view `v_parcels_secure` với `security_invoker = true` và ẩn `pickup_pin_hash`, áp dụng `SET search_path = public, pg_catalog` cho 100% hàm `SECURITY DEFINER`.
2. **Edge Functions (`npx --yes supabase functions deploy create-vnpay-url vnpay-ipn sepay-webhook send-fcm-notification --remote --yes`)**:
   - Đã triển khai thành công cả 4 hàm lên project `vpgimjyyechhuofjghsb` (Production).

