# Kế Hoạch Triển Khai E3: Dự Báo Nợ Xấu & Nhắc Nợ Thông Minh (Smart Debt Prediction & Multi-Tier Dunning Strategy)

## Mục tiêu
Triển khai toàn bộ tính năng **E3: Dự báo nợ xấu & Nhắc nợ thông minh** theo tiêu chuẩn Commercial SaaS:
- CSDL: Bảng `debt_risk_scores`, `dunning_actions`, 3 RPCs PostgreSQL định lượng rủi ro nợ xấu và đôn đốc đa tầng.
- Tầng Dữ Liệu: Models strongly-typed, `DebtPredictionEngine` tính toán offline, `DebtPredictionRepository` tích hợp Riverpod.
- Tầng UI: Tích hợp tab/màn hình "Radar Rủi Ro Nợ Xấu" (`DebtRiskRadarTab` / `DebtRiskRadarWorkstationScreen`) và Hộp thoại đôn đốc đa tầng (`ExecuteDunningDialog`).
- Kiểm thử: Đầy đủ unit, integration & widget tests, 100% pass, 0 issues `dart analyze`.

---

## Chi Tiết Các Task Triển Khai

### Task 1: Cơ Sở Dữ Liệu & RPC PostgreSQL (CSDL & Test)
- **Tập tin:**
  - `supabase/migrations/20261104_03_debt_prediction_and_dunning.sql`
  - `test/database/debt_prediction_migration_test.dart`
- **Nội dung:**
  - Tạo bảng `debt_risk_scores` và `dunning_actions`.
  - Tạo RPC `calculate_apartment_debt_risk(p_building_id, p_apartment_id)`.
  - Tạo RPC `get_building_debt_radar(p_building_id)`.
  - Tạo RPC `execute_dunning_action(p_building_id, p_apartment_id, p_tier, p_title, p_content)`.
  - RLS Policies với tenant isolation theo `building_memberships`.
  - Viết test kiểm thử migration.
- **Cam kết:** Commit vào `main` với message `feat(db): tạo migration dự báo nợ xấu và đôn đốc đa tầng E3`.

### Task 2: Models & Repository Layer (Data & Fallback Engine)
- **Tập tin:**
  - `lib/data/models/debt_risk_score_model.dart`
  - `lib/data/models/dunning_action_model.dart`
  - `lib/data/services/debt_prediction_engine.dart`
  - `lib/data/repositories/debt_prediction_repository.dart`
  - `lib/data/providers/debt_prediction_provider.dart`
  - `test/data/repositories/debt_prediction_repository_test.dart`
- **Nội dung:**
  - Tạo models `DebtRiskScoreModel`, `DunningActionModel` kèm `fromJson` và `toJson`.
  - Tạo `DebtPredictionEngine` chứa thuật toán 3 thành phần (Overdue, Ratio, History) hỗ trợ offline.
  - Tạo `DebtPredictionRepository` gọi Supabase RPC và fallback khi offline.
  - Viết test cho models, engine và repository.
- **Cam kết:** Commit vào `main` với message `feat(data): triển khai models, engine và repository dự báo nợ xấu E3`.

### Task 3: Tích Hợp Giao Diện Quản Trị (UI/UX)
- **Tập tin:**
  - `lib/features/management/widgets/debt_risk_radar_tab.dart`
  - `lib/features/management/widgets/execute_dunning_dialog.dart`
  - Tích hợp vào `lib/features/management/screens/financial_report_screen.dart` hoặc `lib/features/management/screens/accounting_web_workstation_screen.dart`.
  - `test/features/management/debt_risk_radar_test.dart`
- **Nội dung:**
  - Dải thẻ KPI rủi ro nợ xấu thời gian thực.
  - Bảng radar phân loại căn hộ, điểm rủi ro, số ngày quá hạn và đề xuất tầng đôn đốc.
  - Hộp thoại thực thi đôn đốc nợ đa tầng với các mẫu thông báo tiếng Việt chuẩn mực.
  - Viết widget test kiểm tra giao diện.
- **Cam kết:** Commit vào `main` với message `feat(ui): tích hợp tab radar rủi ro nợ xấu và hộp thoại đôn đốc đa tầng`.

### Task 4: Nghiệm Thu, Kiểm Thử Toàn Diện & Cập Nhật Tài Liệu
- **Nội dung:**
  - Chạy toàn bộ test suite.
  - Chạy `dart analyze lib test` (0 issues).
  - Đánh dấu hoàn thành E3 trong `docs/COMMERCIAL_PRODUCT_ROADMAP.md`.
  - Cập nhật Knowledge Graph `python -m graphify update .`.
- **Cam kết:** Commit vào `main` với message `feat(e3): hoàn tất nghiệm thu tính năng dự báo nợ xấu và cập nhật roadmap`.
