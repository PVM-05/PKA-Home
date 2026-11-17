# Kế Hoạch Triển Khai: Đổi Tên Toàn Bộ Dự Án Sang Vivona (Cấp Độ 3 - Full Codebase Refactor)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Chuyển đổi toàn diện 100% định danh và thương hiệu dự án từ **PKA-Home** sang **Vivona** (`vivona`) ở Cấp độ 3: từ package Dart, mã nguồn imports, cấu hình Native (Android, iOS, Web), Deep Link, tài liệu thương mại, đến hệ thống kiểm thử — bảo đảm `dart analyze` 0 lỗi và 100% test suites passed.

**Brand Identity:**
- **Tên Thương Mại:** `Vivona` (Nguồn gốc: Latin *vivo* - sống, sống động)
- **Tagline:** *"Nơi chung cư sống động hơn"* | *"Quản lý tòa nhà, chạm là xong"*
- **Dart Package Name:** `vivona`
- **Application ID / Bundle ID:** `vn.vivona.app`
- **Deep Link Scheme:** `vivona://`
- **Domain & Email thương hiệu:** `https://vivona.vn`, `security@vivona.vn`, `enterprise@vivona.vn`

---

## Danh Sách Công Việc (Task Breakdown)

### Task 1: Cập Nhật Package Name Gốc (`pubspec.yaml`) & Chạy Pub Get
**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Cập nhật `pubspec.yaml`**
  - Đổi `name: pka_home` $\rightarrow$ `name: vivona`.
  - Đổi description sang Vivona PropTech Platform.
- [ ] **Step 2: Chạy `flutter pub get`**
  - Khởi tạo lại `.dart_tool` và liên kết package `vivona`.

---

### Task 2: Thay Thế Hàng Loạt Imports Dart (`lib/`, `test/`, `bin/`, `tool/`)
**Scope:** 343+ files Dart đang sử dụng `package:pka_home/`.

- [ ] **Step 1: Viết script PowerShell thay thế tự động và an toàn**
  - Quét tất cả các file `.dart` trong `lib/`, `test/`, `bin/`, `tool/`.
  - Thay thế `package:pka_home/` thành `package:vivona/`.
- [ ] **Step 2: Thực thi thay thế imports**
- [ ] **Step 3: Kiểm tra grep xác nhận không còn bất kỳ `package:pka_home/` nào sót lại**

---

### Task 3: Cấu Hình Nền Tảng Native (Android, iOS, Web)

**Files:**
- Android: `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/...`
- iOS: `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info.plist`
- Web: `web/index.html`, `web/manifest.json`

- [ ] **Step 1: Cập nhật cấu hình Android**
  - Trong `android/app/build.gradle.kts`:
    - `namespace = "vn.vivona.app"`
    - `applicationId = "vn.vivona.app"`
  - Trong `android/app/src/main/AndroidManifest.xml`:
    - `android:label="Vivona"`
    - `android:value="vivona_high_importance_channel"`
    - Intent filter scheme: `vivona`
  - Di chuyển mã nguồn Kotlin:
    - Tạo thư mục `android/app/src/main/kotlin/vn/vivona/app/`.
    - Di chuyển `MainActivity.kt` sang thư mục mới, cập nhật `package vn.vivona.app`.
    - Xóa thư mục cũ `com/example/pka_home`.
- [ ] **Step 2: Cập nhật cấu hình iOS**
  - Trong `ios/Runner.xcodeproj/project.pbxproj`:
    - Đổi `PRODUCT_BUNDLE_IDENTIFIER = vn.pka.home;` $\rightarrow$ `vn.vivona.app;`
  - Trong `ios/Runner/Info.plist`:
    - `CFBundleDisplayName = Vivona`
    - `CFBundleName = vivona`
    - Các chuỗi xin quyền: "Vivona cần quyền truy cập..."
    - URL Schemes: `vivona`
- [ ] **Step 3: Cập nhật cấu hình Web**
  - `web/index.html`: `title` "Vivona - Nền Tảng Quản Lý Chung Cư", `apple-mobile-web-app-title` "Vivona".
  - `web/manifest.json`: `name` "Vivona - Nền Tảng Quản Lý Chung Cư", `short_name` "Vivona".

---

### Task 4: Cập Nhật Brand Constants, Deep Links & Chuỗi Nhận Diện trong Codebase
**Files:**
- `lib/core/services/push_notification_service.dart`
- `lib/core/security/visitor_pass_token_service.dart`
- `lib/core/security/mfa_service.dart`
- `lib/core/sync/offline_sync_queue_storage.dart`
- `lib/core/widgets/pdpl_consent_dialog.dart`
- `lib/data/models/apartment_invitation_model.dart`
- `lib/data/services/data_privacy_service.dart`
- `lib/data/services/payment_service.dart`
- `supabase/functions/create-vnpay-url/index.ts`
- `test/core/config/app_environment_test.dart`
- `test/data/models/apartment_invitation_model_test.dart`
- `test/data/models/sepay_models_test.dart`

- [ ] **Step 1: Cập nhật Services & Storage Keys**
  - Notification channel: `vivona_high_importance_channel`, tên `Thông báo Vivona`.
  - Pepper security: `Vivona@SecurityPassSignaturePepper#2026`.
  - Offline sync storage key: `vivona_offline_sync_queue`.
  - MFA issuer: `Vivona`.
  - PDPL & DPO Email: `security@vivona.vn`, đơn vị vận hành: `Ban Quản Trị & Giải Pháp PropTech Vivona`.
  - Invitation link: `https://vivona.vn/invite?code=...`.
  - Return URL & Deep links: `vivona://vnpay-callback`, `https://vivona.web.app/payment-result`.
- [ ] **Step 2: Cập nhật Edge Function URL fallbacks**
  - `create-vnpay-url/index.ts`: fallback URL sang `https://vivona.web.app/payment-result`.
- [ ] **Step 3: Cập nhật các Test Cases kiểm tra domain/thương hiệu**
  - Cập nhật các assertion trong `test/core/config/app_environment_test.dart`, `test/data/models/apartment_invitation_model_test.dart`.

---

### Task 5: Kiểm Thử Toàn Diện, Static Analysis & Cập Nhật AST Graph
- [ ] **Step 1: Chạy `flutter pub get`**
- [ ] **Step 2: Chạy `dart analyze lib test`**
  - Đảm bảo đạt tiêu chuẩn: `No issues found!` (0 error, 0 warning).
- [ ] **Step 3: Chạy toàn bộ các Test Suites cốt lõi**
  - Đảm bảo 100% tests passed.
- [ ] **Step 4: Chạy `graphify update .`**
  - Cập nhật lại toàn bộ tri thức đồ thị AST codebase theo package mới `vivona`.

---

### Task 6: Cập Nhật Tài Liệu & Commit
**Files:**
- `README.md`
- `CHANGELOG.md`
- `docs/*`

- [ ] **Step 1: Cập nhật tài liệu thương mại `README.md` & `CHANGELOG.md`**
  - Giới thiệu định vị mới: **Vivona — Nền Tảng Quản Lý Vận Hành Chung Cư & Bất Động Sản Thương Mại**.
  - Ghi nhận phiên bản tái định vị thương hiệu (Brand Rebirth) trong `CHANGELOG.md`.
- [ ] **Step 2: Commit và Push trực tiếp vào `main`**
  - Commit message: `refactor(branding): tai dinh vi toan dien thuong hieu du an sang Vivona`

