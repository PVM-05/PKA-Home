# Vivona — Kịch Bản Kiểm Thử & Triển Khai Push Migration An Toàn
## (Staging Trước, Production Sau — Chuẩn Bị Ngày 21/11/2026)

> **MÃ NGUỒN KIỂM CHỨNG:** Git commit `7fe3b01` (Nhánh `main`)  
> **QUY MÔ MIGRATION:** 44 tệp migration (`supabase/migrations/`)  
> **DỰ ÁN ĐÍCH (REMOTE):** `Ứng Dụng Quản Lý Chung Cư` (Project Ref: `vpgimjyyechhuofjghsb`) — Environment: `production`  
> **MỤC ĐÍCH TÀI LIỆU:** Cung cấp quy trình vận hành tiêu chuẩn (SOP Runbook) cho Kỹ sư Vận hành / Agent Triển khai đưa toàn bộ các bản vá bảo mật (C1–C5), 22 RPCs cốt lõi (§0) và cấu trúc dữ liệu mới lên cơ sở dữ liệu thực tế mà không gây gián đoạn dịch vụ hoặc xung đột dữ liệu.

---

```mermaid
flowchart TD
    P0["Phase 0: Backup Production<br/>(pg_dump schema + data, ghi lại enum_range)"] --> P1["Phase 1: Dựng Staging Giống Hệt Production<br/>(Restore dump, verify 4 object đã biết)"]
    P1 --> P2["Phase 2: Xác Nhận Ranh Giới & Repair<br/>(Kiểm tra apartment_handovers, repair baseline)"]
    P2 --> P3["Phase 3: Push Migration Trên Staging<br/>(supabase db push, kiểm chứng 8 tiêu chí kỹ thuật)"]
    P3 -- "Thất bại" --> Fix["DỪNG NGAY -> Sửa repo -> Re-test"]
    P3 -- "Thành công 100%" --> P4["Phase 4: Smoke Test Nghiệp Vụ<br/>(Kích hoạt cư dân E2E, MFA AAL2, 22 RPCs)"]
    P4 -- "Thất bại" --> Fix
    P4 -- "Thành công 100%" --> P5["Phase 5: Push Production Khung Giờ Thấp Điểm<br/>(Lặp lại Phase 0 -> 2 -> 3 trên Production)"]
```

---

## 1. Bối Cảnh Kỹ Thuật & Bằng Chứng Đã Xác Lập

> [!IMPORTANT]
> **Hiện Trạng Thực Tế Cơ Sở Dữ Liệu:**
> - Bảng `supabase_migrations.schema_migrations` trên remote database hiện đang **trống hoàn toàn** (kết quả `npx supabase migration list --remote` trả về 44/44 tệp đều có `remote: ""`).
> - Schema hiện tại trên production được tạo thủ công ngoài luồng CLI (qua SQL Editor / psql): đã có code của ngày 06/11 (`verify_activation_code` còn chứa `v_otp := '123456'`), nhưng **chưa có các đối tượng từ ngày 08/11 trở đi** (bảng `building_utility_rates` chưa tồn tại).
> - **Nguyên tắc sống còn:** Tuyệt đối **KHÔNG** chạy `supabase db push` trực tiếp lên Production khi chưa baseline/repair. Làm như vậy sẽ ép chạy lại từ migration đầu tiên (`20261027_01`), tiềm ẩn nguy cơ xung đột khóa ngoại hoặc mất dữ liệu hiện hữu.

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

Kiểm tra danh sách migration trên Staging (`npx supabase migration list --linked`): Phải hiển thị toàn bộ migration ở trạng thái pending (`remote: ""`).

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
    Check -- "Có (TRUE)" --> BoundA["Ranh giới: Hết 20261107_02<br/>Repair: 34 files đầu<br/>Pending: 10 files (từ 20261108_01)"]
    Check -- "Không (FALSE)" --> BoundB["Ranh giới: Hết 20261106_04<br/>Repair: 32 files đầu<br/>Pending: 12 files (từ 20261107_01)"]
```

#### Kịch bản B (Xác suất cao nhất - Ranh giới hết `20261106_04`):
Nếu `has_handovers` = `false`, đánh dấu "đã áp dụng" cho 32 file đầu tiên mà KHÔNG chạy lại mã SQL:

```bash
# Danh sách 32 versions tới hết 20261106_04:
VERSIONS_TO_REPAIR=(
    "20261027_01" "20261027_02" "20261027_03" "20261027_04" "20261027_05"
    "20261028_01" "20261028_02" "20261028_03"
    "20261029_01" "20261029_02" "20261029_03" "20261029_04" "20261029_05"
    "20261030_01" "20261030_02" "20261030_03" "20261030_04"
    "20261102_01" "20261102_02"
    "20261103_01" "20261103_02" "20261103_03" "20261103_04" "20261103_05"
    "20261104_01" "20261104_02" "20261104_03"
    "20261105_01"
    "20261106_01" "20261106_02" "20261106_03" "20261106_04"
)

for v in "${VERSIONS_TO_REPAIR[@]}"; do
    npx supabase migration repair --status applied "$v"
done
```

> [!TIP]
> *Lưu ý định dạng version:* Chạy `npx supabase migration list` trước để đối chiếu định dạng version CLI nhận diện (VD: chuỗi số ngày tháng hoặc tên tệp). Sau khi repair xong, chạy lại `npx supabase migration list` để xác nhận chỉ còn 12 migration hiển thị `pending` (từ `20261107_01` đến `20261120_04`).

---

## 5. Phase 3 — Push Migration Trên Staging & Kiểm Chứng 8 Tiêu Chí

### 5.1. Thực Thi db push
```bash
npx supabase db push
```
Ghi nhận toàn bộ stdout/stderr vào tệp `staging_push_execution.log`.

> [!NOTE]
> **Điểm Quan Sát Kỹ Thuật (File `20261120_02_align_enum_values.sql`):**  
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

-- 8. Kiểm tra tính toàn vẹn trạng thái hóa đơn
UPDATE public.invoices 
SET status = 'paid'::public.invoice_status 
WHERE id = (SELECT id FROM public.invoices LIMIT 1);
-- Kỳ vọng: UPDATE thành công, không bị trigger immutability chặn sai
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
2. **Lặp lại Phase 2 (Baseline Repair):** Chạy lệnh `migration repair --status applied` cho 32 file đã xác lập trên Production.
3. **Lặp lại Phase 3 (Push):** Chạy `npx supabase db push` lên Production.
4. **Kiểm Chứng Toàn Diện:** Chạy trọn vẹn bộ 8 truy vấn kiểm chứng của mục 5.2 trực tiếp trên Production.

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

| STT | Hạng Mục Kiểm Tra | Môi Trường Staging | Môi Trường Production | Trạng Thái |
| :---: | :--- | :---: | :---: | :---: |
| 1 | Sao lưu đầy đủ `pg_dump` (schema + data) | [ ] | [ ] | Chờ thực thi |
| 2 | Ghi nhận `enum_range` ban đầu | [ ] | [ ] | Chờ thực thi |
| 3 | Xác nhận ranh giới `apartment_handovers` / `building_utility_rates` | [ ] | [ ] | Chờ thực thi |
| 4 | Thực hiện `migration repair --status applied` đến ranh giới | [ ] | [ ] | Chờ thực thi |
| 5 | `npx supabase db push` hoàn tất exit code 0 | [ ] | [ ] | Chờ thực thi |
| 6 | Kiểm tra Enum `user_role` không còn 'manager', có đủ 6 roles | [ ] | [ ] | Chờ thực thi |
| 7 | Kiểm tra 5 bảng mới (`issue_ratings`, `building_equipments`...) bật RLS | [ ] | [ ] | Chờ thực thi |
| 8 | Kiểm tra 5 RPCs cốt lõi (`verify_activation_code`, `record_meter_reading`...) | [ ] | [ ] | Chờ thực thi |
| 9 | Kiểm tra `verify_activation_code` dùng `code_attempts`, set `otp_sent` | [ ] | [ ] | Chờ thực thi |
| 10 | Kiểm tra `get_financial_aging_report` chặn ẩn danh (anon: false) | [ ] | [ ] | Chờ thực thi |
| 11 | Khởi tạo cấu hình `system_runtime_config` an toàn (`production`) | [ ] | [ ] | Chờ thực thi |
| 12 | Smoke test kích hoạt cư dân E2E & MFA AAL2 Gate | [ ] | Không chạy (chỉ test staging) | Chờ thực thi |
