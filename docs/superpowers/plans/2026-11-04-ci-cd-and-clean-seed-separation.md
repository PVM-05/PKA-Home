# Kế Hoạch Thực Thi: Gói 3 - Hạ Tầng CI/CD & Làm Sạch Dữ Liệu Demo (INF-01, INF-02)

> **Mã kế hoạch:** `PLAN-HARDENING-03`  
> **Tài liệu đặc tả:** [`docs/superpowers/specs/2026-11-04-ci-cd-and-clean-seed-separation-design.md`](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/superpowers/specs/2026-11-04-ci-cd-and-clean-seed-separation-design.md)  
> **Quy tắc Git:** Toàn bộ công việc commit trực tiếp vào `main`, không tạo branch/worktree phụ.

**Mục tiêu:** Thiết lập workflow tự động hóa CI/CD GitHub Actions và tách bạch triệt để dữ liệu mẫu demo ra khỏi Core Production Migration của Supabase.

---

## Danh Sách Các Bước Thực Thi (Tasks)

### Task 1: Xây Dựng Tự Động Hóa CI/CD GitHub Actions (`.github/workflows/ci.yml`)

**Files:**
- Create: `.github/workflows/ci.yml`
- Test: `test/ci/github_actions_workflow_test.dart`

**Interfaces:**
- Produces: GitHub Actions Workflow với các bước `actions/checkout@v4`, `actions/setup-java@v4`, `subosito/flutter-action@v2`, `flutter pub get`, `dart analyze --fatal-infos`, `flutter test`.

- [ ] **Step 1: Viết test kiểm tra workflow CI/CD** (`test/ci/github_actions_workflow_test.dart`)
- [ ] **Step 2: Tạo `.github/workflows/ci.yml`**
- [ ] **Step 3: Chạy test xác minh**
- [ ] **Step 4: Commit trực tiếp vào `main`**

---

### Task 2: Migration CSDL Làm Sạch Dữ Liệu Production & Tách Seed Data Ra `supabase/seed.sql`

**Files:**
- Create: `supabase/migrations/20261104_02_production_clean_seed_separation.sql`
- Create: `supabase/seed.sql`
- Test: `test/database/seed_separation_migration_test.dart`

**Interfaces:**
- Produces: 
  - Migration gỡ bỏ default mock data (`DEFAULT '1234567890'`) trên `buildings` và `maintenance_funds`.
  - RPC `onboard_building_commercial_config` ghi log vào `audit_logs`.
  - File `supabase/seed.sql` độc lập phục vụ local dev / demo.

- [ ] **Step 1: Viết test kiểm tra migration clean seed và file seed.sql** (`test/database/seed_separation_migration_test.dart`)
- [ ] **Step 2: Viết migration `20261104_02_production_clean_seed_separation.sql`**
- [ ] **Step 3: Tạo file `supabase/seed.sql` độc lập**
- [ ] **Step 4: Chạy test xác minh**
- [ ] **Step 5: Commit trực tiếp vào `main`**

---

### Task 3: Nghiệm Thu Gói 3, Phân Tích Tĩnh Toàn Dự Án, Cập Nhật Roadmap & Hoàn Tất Giai Đoạn 0

**Files:**
- Modify: `docs/COMMERCIAL_PRODUCT_ROADMAP.md`
- Knowledge Graph: `graphify-out/`

- [ ] **Step 1: Chạy toàn bộ test suite Gói 3**
- [ ] **Step 2: Chạy `dart analyze lib test` (0 lỗi, 0 cảnh báo, 0 info)**
- [ ] **Step 3: Cập nhật `COMMERCIAL_PRODUCT_ROADMAP.md` đánh dấu hoàn tất Gói 3 và Giai đoạn 0**
- [ ] **Step 4: Cập nhật Knowledge Graph `python -m graphify update .`**
- [ ] **Step 5: Commit nghiệm thu vào `main`**
