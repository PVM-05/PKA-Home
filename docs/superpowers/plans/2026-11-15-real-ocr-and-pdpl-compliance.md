# Real Utility Meter OCR & PDPL Compliance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Thay thế hoàn toàn cơ chế giả lập simulator bằng Real On-Device OCR Service (`google_mlkit_text_recognition`) tự động nhận diện chỉ số công tơ điện nước; đồng thời triển khai đầy đủ quy trình tuân thủ Luật Bảo vệ dữ liệu cá nhân 91/2025/QH15 & Nghị định 356/2025/NĐ-CP (Hộp thoại chấp thuận PDPL, xuất dữ liệu cá nhân và yêu cầu đóng băng/xóa tài khoản).

**Architecture:** 
- Xây dựng `MeterOcrService` bóc tách văn bản qua `google_mlkit_text_recognition` kết hợp với thuật toán regex chuẩn hóa `UtilityMeterOcrEngine`, tự động điền số đo trên màn hình cư dân, xóa sạch `meter_ocr_simulator.dart`.
- Xây dựng `PdplConsentDialog` và `DataPrivacyService` quản lý chấp thuận xử lý dữ liệu, xuất dữ liệu cá nhân (Data Portability theo Điều 15) và tiếp nhận yêu cầu đóng băng danh tính PII (Right to be Forgotten theo Điều 16, 17) tích hợp trong `ResidentProfileScreen`.

**Tech Stack:** Flutter 3.x, Dart 3.12, Riverpod 2.6, `google_mlkit_text_recognition: ^1.0.3`, `shared_preferences`, `share_plus`, `path_provider`, Supabase Flutter.

## Global Constraints
- Commit trực tiếp vào nhánh `main`, không tạo branch/worktree phụ.
- 100% tiếng Việt chuẩn mực SaaS thương mại B2B, không emoji.
- 0 warning, 0 error trên `dart analyze lib test`.
- 100% test pass.

---

### Task 1: Thêm Thư Viện `google_mlkit_text_recognition` & Tải Dependencies

**Files:**
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: `google_mlkit_text_recognition: ^1.0.3` ready to import

- [ ] **Step 1: Cập nhật pubspec.yaml với dependency google_mlkit_text_recognition**
- [ ] **Step 2: Chạy `flutter pub get` để tải package**
- [ ] **Step 3: Chạy `dart analyze` để đảm bảo tương thích**
- [ ] **Step 4: Commit thay đổi dependencies**

---

### Task 2: Xây Dựng `MeterOcrService` & Xóa Hoàn Toàn `MeterOcrSimulator`

**Files:**
- Delete: `lib/core/utils/meter_ocr_simulator.dart`
- Delete: `test/core/utils/meter_ocr_simulator_test.dart`
- Create: `lib/data/services/meter_ocr_service.dart`
- Create: `test/data/services/meter_ocr_service_test.dart`

**Interfaces:**
- Consumes: `UtilityMeterOcrEngine.parseReadingFromOcrText`, `MeterType`
- Produces: `MeterOcrService.recognizeMeterReading({required String imagePath, required MeterType meterType}) -> Future<MeterOcrParsedResult>`

- [ ] **Step 1: Viết test cho `MeterOcrService` với Mock Recognizer**
- [ ] **Step 2: Triển khai `MeterOcrService` (kết hợp ML Kit Latin Text Recognizer và fallback text engine)**
- [ ] **Step 3: Xóa `meter_ocr_simulator.dart` và `meter_ocr_simulator_test.dart`**
- [ ] **Step 4: Chạy `flutter test test/data/services/meter_ocr_service_test.dart` và verify pass**
- [ ] **Step 5: Commit task**

---

### Task 3: Tích Hợp Real OCR Auto-fill Vào `ResidentMeterReadingScreen`

**Files:**
- Modify: `lib/features/resident/screens/resident_meter_reading_screen.dart`
- Modify: `test/features/resident/resident_meter_reading_screen_test.dart`

**Interfaces:**
- Consumes: `MeterOcrService`
- Produces: Auto-filling reading into `_electricController` & `_waterController` upon image selection, showing OCR status banner/snackbar.

- [ ] **Step 1: Viết/Cập nhật test mô phỏng quá trình quét OCR tự động điền giá trị**
- [ ] **Step 2: Cập nhật hàm `_pickMeterImage` trong `ResidentMeterReadingScreen` để gọi `MeterOcrService` và tự động cập nhật controller**
- [ ] **Step 3: Chạy `flutter test test/features/resident/resident_meter_reading_screen_test.dart`**
- [ ] **Step 4: Commit task**

---

### Task 4: Triển Khai Hộp Thoại Chấp Thuận Dữ Liệu Cá Nhân (`PdplConsentDialog`)

**Files:**
- Create: `lib/core/widgets/pdpl_consent_dialog.dart`
- Create: `test/core/widgets/pdpl_consent_dialog_test.dart`

**Interfaces:**
- Consumes: `SharedPreferences`, `AppTheme`
- Produces: `PdplConsentDialog`, `PdplConsentManager.checkAndPromptPdplConsent(BuildContext context)`

- [ ] **Step 1: Viết unit test cho `PdplConsentManager` và widget test cho `PdplConsentDialog`**
- [ ] **Step 2: Triển khai `PdplConsentDialog` với thông tin căn cứ Luật 91/2025/QH15, danh mục dữ liệu thu thập, checkbox đồng ý và lưu trạng thái vào `SharedPreferences`**
- [ ] **Step 3: Chạy test verify pass**
- [ ] **Step 4: Commit task**

---

### Task 5: Triển Khai `DataPrivacyService` (Xuất Dữ Liệu & Quyền Được Lãng Quên)

**Files:**
- Create: `lib/data/services/data_privacy_service.dart`
- Create: `test/data/services/data_privacy_service_test.dart`

**Interfaces:**
- Consumes: `SupabaseClient` / Repositories
- Produces: 
  - `DataPrivacyService.exportUserData(String userId) -> Future<Map<String, dynamic>>`
  - `DataPrivacyService.saveAndShareDataExport(...) -> Future<void>`
  - `DataPrivacyService.requestDataAnonymization({required String userId, required String reason}) -> Future<bool>`

- [ ] **Step 1: Viết test cho `DataPrivacyService`**
- [ ] **Step 2: Triển khai `DataPrivacyService` xuất dữ liệu JSON/PDF và ghi nhận yêu cầu đóng băng tài khoản**
- [ ] **Step 3: Chạy test verify pass**
- [ ] **Step 4: Commit task**

---

### Task 6: Tích Hợp Section "Quyền Riêng Tư & Dữ Liệu (PDPL)" Vào `ResidentProfileScreen`

**Files:**
- Modify: `lib/features/resident/screens/resident_profile_screen.dart`
- Create/Modify: `test/features/resident/resident_profile_pdpl_test.dart`

**Interfaces:**
- Consumes: `DataPrivacyService`, `PdplConsentDialog`, `PRIVACY_POLICY.md`
- Produces: Section "Quyền riêng tư & Dữ liệu (PDPL)" với 3 action: Đọc chính sách, Xuất dữ liệu cá nhân, Yêu cầu xóa/đóng băng dữ liệu.

- [ ] **Step 1: Viết test cho các action PDPL trên Profile Screen**
- [ ] **Step 2: Thêm Section PDPL vào giao diện `ResidentProfileScreen`**
- [ ] **Step 3: Chạy test verify pass**
- [ ] **Step 4: Commit task**

---

### Task 7: Nghiệm Thu Toàn Diện & Kiểm Tra Chất Lượng

**Files:**
- Verify: Toàn bộ project

- [ ] **Step 1: Chạy `dart analyze lib test` đạt 0 issues**
- [ ] **Step 2: Chạy toàn bộ test suites `flutter test`**
- [ ] **Step 3: Cập nhật tri thức `graphify update .`**
- [ ] **Step 4: Push commit lên `origin/main`**

