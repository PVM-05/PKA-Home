# Kế Hoạch Thực Thi: E1 - OCR Đồng Hồ Điện / Nước & Cảnh Báo Tiêu Thụ Bất Thường

**Mã kế hoạch:** `PLAN-E1-METER-OCR-ANOMALY`  
**Tài liệu thiết kế:** [`docs/superpowers/specs/2026-11-03-meter-reading-ocr-and-anomaly-detection-design.md`](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/superpowers/specs/2026-11-03-meter-reading-ocr-and-anomaly-detection-design.md)  
**Quy tắc Git:** Commit trực tiếp vào `main`.

---

## Danh Sách Các Bước Thực Thi (Tasks)

- [ ] **Task 1: Engine Thuật Toán Phân Tích & OCR Parser (`UtilityMeterOcrEngine` & `UtilityAnomalyDetector`)**
  - Viết test: `test/core/utils/utility_meter_ocr_engine_test.dart`
  - Viết test: `test/core/utils/utility_anomaly_detector_test.dart`
  - Cài đặt: `lib/core/utils/utility_meter_ocr_engine.dart`
  - Cài đặt: `lib/core/utils/utility_anomaly_detector.dart`
  - Chạy test pass 100%
  - Commit trực tiếp vào `main`

- [ ] **Task 2: Migration CSDL & RPC Phát Hiện Bất Thường trên PostgreSQL**
  - Viết migration: `supabase/migrations/20261103_03_meter_ocr_and_anomaly.sql`
  - Bổ sung các cột: `ocr_confidence`, `is_anomaly`, `anomaly_severity`, `anomaly_reason`, `previous_reading_val`, `average_usage` vào `meter_reading_submissions`
  - Viết RPC: `detect_meter_reading_anomaly`
  - Viết test migration SQL: `test/database/meter_ocr_anomaly_migration_test.dart`
  - Chạy test pass 100%
  - Commit trực tiếp vào `main`

- [ ] **Task 3: Cập Nhật Data Models & Repository Layer**
  - Cập nhật: `lib/data/models/meter_reading_submission_model.dart`
  - Cập nhật: `lib/data/repositories/meter_reading_repository.dart` (thêm phương thức `detectAnomaly`, mở rộng `submitReading`)
  - Cập nhật: `lib/data/providers/meter_reading_provider.dart`
  - Viết test repository: `test/data/repositories/meter_reading_repository_test.dart`
  - Chạy test pass 100%
  - Commit trực tiếp vào `main`

- [ ] **Task 4: Nâng Cấp Giao Diện Cư Dân & Ban Quản Lý với Trí Tuệ Phân Tích**
  - Nâng cấp `ResidentMeterReadingScreen`: Hiển thị thanh độ tin cậy OCR và banner cảnh báo bất thường trực quan với mức độ cảnh báo (vàng/cam/đỏ).
  - Nâng cấp `ManagementMeterReadingScreen`: Thêm tab lọc bản ghi bất thường, badge cảnh báo và ghi chú kiểm tra kỹ thuật.
  - Viết widget test: `test/features/meter_reading/meter_reading_anomaly_ui_test.dart`
  - Chạy test pass 100%
  - Commit trực tiếp vào `main`

- [ ] **Task 5: Nghiệm Thu, Cập Nhật Roadmap & Quality Gate**
  - Kiểm tra toàn bộ mã nguồn: `dart analyze` (0 lỗi, 0 cảnh báo).
  - Chạy toàn bộ test suite.
  - Cập nhật Knowledge Graph: `python -m graphify update .`
  - Đánh dấu hoàn tất E1 trong `COMMERCIAL_PRODUCT_ROADMAP.md`
  - Commit nghiệm thu vào `main`
