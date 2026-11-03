# Kế Hoạch Thực Thi: E1 - OCR Đồng Hồ Điện / Nước & Cảnh Báo Tiêu Thụ Bất Thường

**Mã kế hoạch:** `PLAN-E1-METER-OCR-ANOMALY`  
**Tài liệu thiết kế:** [`docs/superpowers/specs/2026-11-03-meter-reading-ocr-and-anomaly-detection-design.md`](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/superpowers/specs/2026-11-03-meter-reading-ocr-and-anomaly-detection-design.md)  
**Quy tắc Git:** Commit trực tiếp vào `main`.

---

## Danh Sách Các Bước Thực Thi (Tasks)

- [x] **Task 1: Engine Thuật Toán Phân Tích & OCR Parser (`UtilityMeterOcrEngine` & `UtilityAnomalyDetector`)**
  - Viết test: `test/core/utils/utility_meter_ocr_engine_test.dart`
  - Viết test: `test/core/utils/utility_anomaly_detector_test.dart`
  - Cài đặt: `lib/core/utils/utility_meter_ocr_engine.dart`
  - Cài đặt: `lib/core/utils/utility_anomaly_detector.dart`
  - Chạy test pass 10/10 tests
  - Commit trực tiếp vào `main`: `51c54df`

- [x] **Task 2: Migration CSDL & RPC Phát Hiện Bất Thường trên PostgreSQL**
  - Viết migration: `supabase/migrations/20261103_03_meter_ocr_and_anomaly.sql`
  - Bổ sung các cột: `ocr_confidence`, `is_anomaly`, `anomaly_severity`, `anomaly_reason`, `previous_electric_reading`, `previous_water_reading`, `avg_electric_usage`, `avg_water_usage` vào `meter_reading_submissions`
  - Viết RPC: `detect_meter_reading_anomaly`
  - Viết Trigger: `trg_check_meter_reading_anomaly` tự động phân tích khi ghi/cập nhật chỉ số
  - Viết test migration SQL: `test/database/meter_ocr_anomaly_migration_test.dart`
  - Chạy test pass 4/4 tests
  - Commit trực tiếp vào `main`: `f71da6d`

- [x] **Task 3: Cập Nhật Data Models & Repository Layer**
  - Cập nhật: `lib/data/models/meter_reading_submission_model.dart`
  - Cập nhật: `lib/data/repositories/meter_reading_repository.dart` (thêm phương thức `detectAnomaly`, mở rộng `submitReading`, `getAllSubmissions(isAnomaly)`)
  - Cập nhật: `lib/data/providers/meter_reading_provider.dart` (`anomalyMeterReadingsProvider`, `pendingAnomalyCountProvider`)
  - Viết test: `test/data/models/meter_reading_submission_model_test.dart`
  - Viết test: `test/data/repositories/meter_reading_repository_test.dart`
  - Chạy test pass 6/6 tests
  - Commit trực tiếp vào `main`: `e8fa7d8`

- [x] **Task 4: Nâng Cấp Giao Diện Cư Dân & Ban Quản Lý với Trí Tuệ Phân Tích**
  - Nâng cấp `ResidentMeterReadingScreen`: Hiển thị banner cảnh báo bất thường thời gian thực khi gõ/quét chỉ số, hộp thoại xác nhận khi phát hiện tăng cao đột biến, badge OCR confidence score.
  - Nâng cấp `ManagementMeterReadingScreen`: Thêm tab "Bất thường" lọc nhanh các bản ghi có cờ cảnh báo, thẻ hiển thị chỉ số kèm viền màu ngữ nghĩa và lý do chi tiết từ AI/OCR, cảnh báo trong hộp thoại duyệt.
  - Viết widget test: `test/features/meter_reading/meter_reading_anomaly_ui_test.dart`
  - Chạy test pass 100%
  - Commit trực tiếp vào `main`: `571302a` & `a5ccaf9`

- [x] **Task 5: Nghiệm Thu, Cập Nhật Roadmap & Quality Gate**
  - Kiểm tra toàn bộ mã nguồn: `dart analyze` (0 lỗi, 0 cảnh báo, 0 info).
  - Chạy toàn bộ 26/26 tests cho E1 pass 100%.
  - Cập nhật Knowledge Graph: `python -m graphify update .` (9.258 nodes, 13.075 edges, 550 communities).
  - Đánh dấu hoàn tất E1 trong `COMMERCIAL_PRODUCT_ROADMAP.md`.
  - Commit nghiệm thu vào `main`.
