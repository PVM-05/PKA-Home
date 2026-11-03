# Đặc Tả Thiết Kế: Hạ Tầng CI/CD & Tách Dữ Liệu Demo Khỏi Production (INF-01, INF-02)

**Mã tài liệu:** `SPEC-INFRA-CLEAN-SEED-01`  
**Thuộc lộ trình:** `GIAI ĐOẠN 0: Product Hardening & Real Commercial SaaS`  
**Ngày lập:** 04/11/2026  
**Trạng thái:** Đã phê duyệt  
**Căn cứ kỹ thuật:**
- Khuyến nghị kiểm toán mã nguồn & sản phẩm thực tế P0/P1.
- Tiêu chuẩn CI/CD GitHub Actions hiện đại cho Flutter/Dart.
- Nguyên tắc an toàn dữ liệu: Tách biệt hoàn toàn DDL cấu trúc CSDL production khỏi Mock Seed Data demo.

---

## 1. Bối Cảnh & Vấn Đề Cần Khắc Phục

### 1.1. Vấn đề 1: Thiếu quy trình kiểm thử và tích hợp liên tục tự động (CI/CD)
- **Hiện trạng:** Repository chưa có thư mục `.github/workflows` và chưa có workflow tự động chạy kiểm thử trên GitHub Actions khi đẩy mã lên `main`.
- **Rủi ro:** Khi nhiều nhà phát triển hoặc subagents commit mã nguồn, không có Quality Gate độc lập trên đám mây để ngăn chặn lỗi hồi quy (regression) hoặc vi phạm linter.
- **Giải pháp:** Xây dựng `.github/workflows/ci.yml` tự động chạy `flutter pub get`, `dart analyze --fatal-infos` và `flutter test` trên mọi lần `push` hoặc `pull_request` vào `main`.

### 1.2. Vấn đề 2: Tồn tại dữ liệu demo nhạy cảm trong Core Migration CSDL
- **Hiện trạng:**
  - `20261027_02_dynamic_fees_and_maintenance_fund.sql` hardcode giá trị số dư quỹ bảo trì `2.450.000.000 đ`, lãi ngân hàng `127.400.000 đ`, tài khoản BIDV `1234567890`.
  - `20261027_04_commercial_banking_and_receipts.sql` đặt giá trị mặc định cho cột `bank_account_number DEFAULT '1234567890'` và tự động update tòa nhà về STK này.
- **Rủi ro:** Khi đưa phần mềm vào triển khai cho chung cư thật, tòa nhà mới onboarding có nguy cơ bị gán số dư quỹ ảo hoặc tài khoản nhận tiền demo BIDV, gây rủi ro thất thoát tài chính và vi phạm kiểm toán kế toán.
- **Giải pháp:**
  - Tạo migration `20261104_02_production_clean_seed_separation.sql`:
    - Xóa bỏ toàn bộ các giá trị mặc định hardcode demo (`DEFAULT '1234567890'`, `DEFAULT '970418'`, v.v.) trên `buildings` và `maintenance_funds`.
    - Thiết lập số dư mặc định của Quỹ bảo trì cho tòa nhà mới là `0.00 đ`. Cấu hình ngân hàng ban đầu là `NULL`.
    - Xây dựng RPC `onboard_building_commercial_config`: Khi BQL onboarding tòa nhà mới, bắt buộc nhập thông tin ngân hàng thực tế và số dư đầu kỳ có xác nhận, đồng thời tự động ghi nhận nhật ký kiểm toán bất biến `audit_logs` (lưu vết `user_id`, thời điểm, IP/metadata).
  - Tách toàn bộ dữ liệu mẫu ra file độc lập [`supabase/seed.sql`](file:///c:/Users/ADMIN/StudioProjects/pka_home/supabase/seed.sql) chỉ dùng cho môi trường Local Development, Test và Staging Demo.

---

## 2. Thiết Kế Chi Tiết

### 2.1. Quy Trình CI/CD GitHub Actions (`.github/workflows/ci.yml`)

```yaml
name: CI Quality Gate

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  analyze-and-test:
    name: Flutter Analyze & Test
    runs-on: ubuntu-latest
    timeout-minutes: 20

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Run Static Analysis (0 issues policy)
        run: dart analyze --fatal-infos

      - name: Run Automated Test Suite
        run: flutter test --reporter expanded
```

### 2.2. Migration Làm Sạch Dữ Liệu Production (`20261104_02_production_clean_seed_separation.sql`)
1. Gỡ bỏ `DEFAULT` demo trên `public.buildings`:
   ```sql
   ALTER TABLE public.buildings ALTER COLUMN bank_bin DROP DEFAULT;
   ALTER TABLE public.buildings ALTER COLUMN bank_name DROP DEFAULT;
   ALTER TABLE public.buildings ALTER COLUMN bank_account_number DROP DEFAULT;
   ALTER TABLE public.buildings ALTER COLUMN bank_account_name DROP DEFAULT;
   ```
2. Gỡ bỏ `DEFAULT` demo trên `public.maintenance_funds`:
   ```sql
   ALTER TABLE public.maintenance_funds ALTER COLUMN bank_name DROP DEFAULT;
   ALTER TABLE public.maintenance_funds ALTER COLUMN bank_account_number DROP DEFAULT;
   ALTER TABLE public.maintenance_funds ALTER COLUMN total_balance SET DEFAULT 0.00;
   ```
3. Tạo RPC onboarding an toàn có kiểm toán:
   ```sql
   CREATE OR REPLACE FUNCTION public.onboard_building_commercial_config(
       p_building_id UUID,
       p_bank_bin VARCHAR(10),
       p_bank_name TEXT,
       p_bank_account_number TEXT,
       p_bank_account_name TEXT,
       p_initial_maintenance_balance NUMERIC(15,2) DEFAULT 0.00
   )
   RETURNS JSONB
   LANGUAGE plpgsql
   SECURITY DEFINER;
   ```

### 2.3. Tách Mock Seed Data ra `supabase/seed.sql`
- Chứa các căn hộ mẫu: `a0110`, `a0201`, `a0305`, `a0412`.
- Cấu hình ngân hàng sandbox minh họa dành cho môi trường dev.
- Kịch bản quỹ bảo trì mẫu 2.45 tỷ đồng dành cho demo pitch deck / thuyết trình hội đồng đánh giá.

---

## 3. Kế Hoạch Kiểm Thử

1. **Test CI/CD:** `test/ci/github_actions_workflow_test.dart` kiểm tra file `.github/workflows/ci.yml` tồn tại, đúng cú pháp YAML, có bước `dart analyze --fatal-infos` và `flutter test`.
2. **Test CSDL Clean Seed:** `test/database/seed_separation_migration_test.dart` kiểm tra:
   - File migration `20261104_02_production_clean_seed_separation.sql` gỡ bỏ default mock data.
   - Có RPC `onboard_building_commercial_config` và ghi log vào `audit_logs`.
   - File `supabase/seed.sql` độc lập tồn tại.
3. **Phân tích tĩnh:** `dart analyze lib test` đạt 0 issues.
