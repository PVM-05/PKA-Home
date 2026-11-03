# Kế Hoạch Thực Thi: E2 - AI Phân Loại Sự Cố & Tự Động Gán Kỹ Thuật Viên

**Mã kế hoạch:** `PLAN-E2-ISSUE-SMART-TRIAGE`  
**Tài liệu thiết kế:** [`docs/superpowers/specs/2026-11-03-issue-smart-triage-and-auto-assign-design.md`](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/superpowers/specs/2026-11-03-issue-smart-triage-and-auto-assign-design.md)  
**Quy tắc Git:** Commit trực tiếp vào `main`.

---

## Danh Sách Các Bước Thực Thi (Tasks)

- [ ] **Task 1: Engine Phân Tích & Phân Loại Sự Cố Tiếng Việt (`IssueSmartTriageEngine`)**
  - Viết unit test: `test/core/utils/issue_smart_triage_engine_test.dart`
  - Cài đặt: `lib/core/utils/issue_smart_triage_engine.dart`
  - Kiểm thử phát hiện chuyên môn (Điện, Nước, Thang máy, PCCC, Xây dựng, Khác)
  - Kiểm thử phát hiện mức độ ưu tiên & cảnh báo nguy hiểm (Cháy, nổ, kẹt thang, rò gas)
  - Chạy test pass 100%
  - Commit trực tiếp vào `main`

- [ ] **Task 2: Migration CSDL & RPC Auto-Assignment PostgreSQL**
  - Viết migration: `supabase/migrations/20261103_04_issue_smart_triage_and_auto_assign.sql`
  - Bổ sung các cột AI Triage vào `issue_reports`: `ai_category_confidence`, `ai_suggested_category`, `ai_suggested_priority`, `ai_triage_reason`, `is_hazardous`, `auto_assigned`
  - Viết RPC: `triage_and_auto_assign_issue(p_issue_id UUID)`
  - Viết test migration SQL: `test/database/issue_smart_triage_migration_test.dart`
  - Chạy test pass 100%
  - Commit trực tiếp vào `main`

- [ ] **Task 3: Cập Nhật Data Models & Repository Layer**
  - Cập nhật `IssueModel`: bổ sung các trường AI Triage, `isHazardous`, `autoAssigned`
  - Cập nhật `IssueRepository`: hỗ trợ lưu AI Triage metadata và gọi RPC tự động phân công
  - Viết unit test: `test/data/models/issue_model_smart_triage_test.dart`
  - Viết unit test: `test/data/repositories/issue_smart_triage_repository_test.dart`
  - Chạy test pass 100%
  - Commit trực tiếp vào `main`

- [ ] **Task 4: Nâng Cấp Giao Diện Cư Dân & Ban Quản Lý với AI Triage**
  - Nâng cấp `CreateIssueScreen`: Gợi ý chuyên môn & mức ưu tiên 1 chạm thời gian thực, banner cảnh báo hotline khẩn cấp khi phát hiện sự cố nguy hiểm
  - Nâng cấp `IssueManagementScreen`: Hiển thị badge AI Triage trên thẻ sự cố, hiển thị gợi ý phân công kỹ thuật viên
  - Viết widget test: `test/features/issue/issue_smart_triage_ui_test.dart`
  - Chạy test pass 100%
  - Commit trực tiếp vào `main`

- [ ] **Task 5: Nghiệm Thu, Cập Nhật Roadmap & Quality Gate**
  - Kiểm tra toàn bộ mã nguồn: `dart analyze` (0 lỗi, 0 cảnh báo, 0 info)
  - Chạy toàn bộ test suite
  - Cập nhật Knowledge Graph: `python -m graphify update .`
  - Đánh dấu hoàn tất E2 trong `COMMERCIAL_PRODUCT_ROADMAP.md`
  - Commit nghiệm thu vào `main`
