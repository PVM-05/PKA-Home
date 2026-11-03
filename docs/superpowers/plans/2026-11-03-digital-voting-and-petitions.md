# Kế Hoạch Thực Thi: Biểu Quyết Điện Tử & Kiến Nghị Cộng Đồng (D7)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng hệ thống Biểu Quyết Điện Tử (Digital Voting / Online Polling theo Điều 102 Luật Nhà ở 2023 tính theo căn hộ hoặc theo $m^2$ diện tích sở hữu) và Kiến Nghị Cộng Đồng có cơ chế đồng thuận (Resident Petitions & Endorsements) cho Ban Quản Lý và Cư Dân.

**Architecture:** Bảng CSDL PostgreSQL `polls`, `poll_options`, `poll_votes`, `resident_petitions`, `petition_endorsements`; DB triggers sinh mã tự động; 4 RPCs tính toán kết quả và ghi nhận tương tác; Data Models Dart strongly-typed; `CommunityRepository` với Offline Fallback Engine; Màn hình Quản trị BQL (`CommunityManagementScreen`); Màn hình Cư dân tham gia biểu quyết và gửi kiến nghị (`ResidentCommunityScreen`).

**Tech Stack:** Flutter 3.x, Dart 3.x, Supabase (PostgreSQL 15), Riverpod 2.x, TDD.

## Global Constraints
- Commit trực tiếp trên nhánh `main` (không tạo branch phụ/worktree).
- Giao diện 100% tiếng Việt chuẩn mực, không hardcode màu sắc, không giới hạn chiều cao cứng (tránh RenderFlex overflow).
- Tuân thủ nghiêm ngặt quy trình TDD: Viết test trước -> Test fail -> Viết code tối thiểu -> Test pass -> Commit.
- Đảm bảo 0 issue static analysis (`dart analyze`) và 100% tests pass.

---

## Danh Sách Tasks

### Task 1: Migration SQL & Schema Tests (D7)
- **Mục tiêu:** Tạo migration PostgreSQL định nghĩa 5 bảng: `polls`, `poll_options`, `poll_votes`, `resident_petitions`, `petition_endorsements`; triggers sinh mã tự động; và 4 RPCs (`submit_poll_vote`, `get_poll_results`, `endorse_petition`, `update_petition_response`).
- **Files:**
  - Create: `supabase/migrations/20261103_02_digital_voting_and_petitions.sql`
  - Test: `test/integration/digital_voting_and_petitions_migration_test.dart`
- **Interfaces:**
  - Produces: Migration SQL hợp lệ và các RPCs phục vụ kiểm toán biểu quyết & kiến nghị cộng đồng.
- [ ] **Step 1:** Viết failing test `test/integration/digital_voting_and_petitions_migration_test.dart`.
- [ ] **Step 2:** Chạy test để xác nhận test fail.
- [ ] **Step 3:** Tạo migration `supabase/migrations/20261103_02_digital_voting_and_petitions.sql`.
- [ ] **Step 4:** Chạy test xác minh 100% test pass.
- [ ] **Step 5:** Commit: `feat(db): migration sql bieu quyet dien tu va kien nghi cong dong D7`.

---

### Task 2: Data Models Biểu Quyết & Kiến Nghị (D7)
- **Mục tiêu:** Xây dựng các models strongly-typed cho đợt biểu quyết, phương án chọn, kết quả tính toán và kiến nghị cộng đồng.
- **Files:**
  - Create: `lib/data/models/poll_model.dart`
  - Create: `lib/data/models/poll_result_model.dart`
  - Create: `lib/data/models/petition_model.dart`
  - Test: `test/data/models/poll_model_test.dart`
  - Test: `test/data/models/petition_model_test.dart`
- **Interfaces:**
  - Consumes: JSON từ Supabase tables `polls`, `poll_votes`, `resident_petitions`.
  - Produces: `PollModel`, `PollResultModel`, `PetitionModel` với đầy đủ getters logic hiển thị tiếng Việt.
- [ ] **Step 1:** Viết failing unit tests cho các models.
- [ ] **Step 2:** Chạy tests để xác nhận fail.
- [ ] **Step 3:** Cài đặt các models.
- [ ] **Step 4:** Chạy unit tests xác minh 100% pass.
- [ ] **Step 5:** Commit: `feat(data): them models bieu quyet va kien nghi cong dong D7`.

---

### Task 3: Repository & Provider Quản Lý Cộng Đồng (D7)
- **Mục tiêu:** Xây dựng `CommunityRepository` và các Riverpod providers với cơ chế Offline Fallback Engine phong phú.
- **Files:**
  - Create: `lib/data/repositories/community_repository.dart`
  - Create: `lib/data/providers/community_provider.dart`
  - Test: `test/data/repositories/community_repository_test.dart`
- **Interfaces:**
  - Consumes: Models từ Task 2.
  - Produces: `CommunityRepository` với các hàm lấy danh sách polls, bỏ phiếu, tính kết quả, lấy kiến nghị, bấm đồng thuận, phản hồi BQL.
- [ ] **Step 1:** Viết failing test `community_repository_test.dart`.
- [ ] **Step 2:** Chạy test để xác nhận fail.
- [ ] **Step 3:** Cài đặt `community_repository.dart` và `community_provider.dart`.
- [ ] **Step 4:** Chạy test xác minh 100% pass.
- [ ] **Step 5:** Commit: `feat(data): them repository va provider quan ly cong dong D7`.

---

### Task 4: Giao Diện Ban Quản Lý - Quản Trị Biểu Quyết & Kiến Nghị (D7)
- **Mục tiêu:** Xây dựng màn hình `CommunityManagementScreen` với 2 tab lớn (Quản trị Biểu Quyết & Xử lý Kiến Nghị), hộp thoại tạo biểu quyết (`CreatePollSheet`) và hộp thoại phản hồi chính thức kiến nghị (`RespondPetitionDialog`).
- **Files:**
  - Create: `lib/features/management/screens/community_management_screen.dart`
  - Create: `lib/features/management/widgets/create_poll_sheet.dart`
  - Create: `lib/features/management/widgets/respond_petition_dialog.dart`
  - Test: `test/features/management/screens/community_management_screen_test.dart`
- **Interfaces:**
  - Consumes: `CommunityRepository`, `community_provider.dart`.
  - Produces: Màn hình trạm làm việc BQL giám sát biểu quyết và xử lý kiến nghị.
- [ ] **Step 1:** Viết widget test `community_management_screen_test.dart`.
- [ ] **Step 2:** Chạy test để xác nhận fail.
- [ ] **Step 3:** Cài đặt các màn hình và widgets BQL.
- [ ] **Step 4:** Chạy widget test xác minh pass.
- [ ] **Step 5:** Commit: `feat(ui): man hinh quan ly bieu quyet va kien nghi cu dan D7`.

---

### Task 5: Giao Diện Cư Dân & Tích Hợp Luồng Nghiệp Vụ Toàn App (D7)
- **Mục tiêu:** Xây dựng màn hình cư dân `ResidentCommunityScreen`, tạo phiếu bỏ phiếu trực tuyến (`VotePollSheet`), gửi kiến nghị mới (`CreatePetitionSheet`), đăng ký router và thêm lối tắt điều hướng tại Dashboard BQL và Cư dân.
- **Files:**
  - Create: `lib/features/resident/screens/resident_community_screen.dart`
  - Create: `lib/features/resident/widgets/vote_poll_sheet.dart`
  - Create: `lib/features/resident/widgets/create_petition_sheet.dart`
  - Modify: `lib/core/router/route_names.dart`
  - Modify: `lib/core/router/app_router.dart`
  - Modify: `lib/features/management/screens/management_home_screen.dart`
  - Modify: `lib/features/resident/screens/resident_home_screen.dart`
  - Test: `test/features/resident/screens/resident_community_screen_test.dart`
  - Test: `test/integration/digital_voting_and_petitions_workflow_integration_test.dart`
- **Interfaces:**
  - Consumes: Mọi tính năng từ Task 1-4.
  - Produces: Luồng khép kín từ BQL tạo biểu quyết -> Cư dân bỏ phiếu -> BQL xem kết quả; Cư dân gửi kiến nghị -> Cư dân khác đồng thuận -> BQL phản hồi chính thức.
- [ ] **Step 1:** Cài đặt màn hình cư dân, routes và lối tắt Dashboard.
- [ ] **Step 2:** Viết integration test luồng toàn diện.
- [ ] **Step 3:** Chạy test xác minh 100% pass.
- [ ] **Step 4:** Commit: `feat(management): tich hop bieu quyet va kien nghi vao ung dung D7`.

---

### Task 6: Verification, Roadmap & Quality Gate (D7)
- **Mục tiêu:** Kiểm tra static analysis toàn dự án, chạy test suite, cập nhật Knowledge Graph và Roadmap.
- **Files:**
  - Modify: `docs/COMMERCIAL_PRODUCT_ROADMAP.md`
  - Modify: `docs/superpowers/plans/2026-11-03-digital-voting-and-petitions.md`
- [ ] **Step 1:** Chạy `dart analyze` toàn dự án (đạt 0 issue).
- [ ] **Step 2:** Chạy toàn bộ test suite D7 (100% pass).
- [ ] **Step 3:** Chạy `python -m graphify update .` đồng bộ Knowledge Graph.
- [ ] **Step 4:** Cập nhật `COMMERCIAL_PRODUCT_ROADMAP.md` đánh dấu `[x] D7`.
- [ ] **Step 5:** Commit: `feat: hoan tat D7 bieu quyet dien tu va kien nghi cong dong`.
