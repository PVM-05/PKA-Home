# Kế Hoạch Triển Khai: Hệ Thống Đánh Giá Dịch Vụ Sự Cố Đa Tiêu Chí & Giám Sát KPI Kỹ Thuật

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng hệ thống đánh giá chất lượng dịch vụ sự cố đa tiêu chí (Tốc độ xử lý, Thái độ phục vụ, Chất lượng kỹ thuật) với điểm tổng thể tính tự động bằng PostgreSQL Generated Column, giao diện BottomSheet tương tác mượt mà cho Cư dân, và bảng giám sát KPI/thống kê phản hồi toàn diện cho Ban Quản Lý.

**Architecture:** Bảng `public.issue_ratings` chuẩn hóa với quan hệ 1-1 với `issue_reports`; RLS Least Privilege ngăn ngừa gian lận dữ liệu; tầng repository chuyên biệt cho rating; Riverpod AsyncNotifier & StreamProvider với Supabase Realtime; UI Material 3 tiếng Việt chuẩn mực với micro-animations và feedback xúc giác (Haptic).

**Tech Stack:** Flutter 3.x, Dart, Supabase PostgreSQL & RLS, Flutter Riverpod 2.6, GoRouter, Mocktail.

## Global Constraints
- 100% Tiếng Việt chuẩn mực cho giao diện, nhãn dán, thông báo lỗi/thành công; tuyệt đối không dùng tiếng Anh trong ngoặc đơn hay emoji.
- Màu sắc tuân thủ palette từ `AppTheme` (`AppTheme.primary`, `AppTheme.warning`, `AppTheme.success`, `AppTheme.error`).
- Icons sử dụng Material Design `Icons.*` chuẩn mực.
- Tự động co giãn nội dung thẻ (Card), bọc text hoặc dùng `FittedBox` tránh RenderFlex overflow.
- Mọi bảng Supabase đều phải bật RLS. Cư dân chỉ có quyền thao tác trên sự cố hoàn thành của chính mình.

---

### Task 1: Thiết Lập CSDL & Migration RLS Toàn Diện (Database Layer)

**Files:**
- Create: `supabase/migrations/20260929_01_issue_ratings_and_kpi.sql`

**Interfaces:**
- Produces: Bảng `public.issue_ratings` với `overall_rating` generated stored, RLS policies, trigger `update_modified_column`, và publication Realtime.

- [x] **Step 1: Viết migration SQL tạo bảng `issue_ratings` và các ràng buộc**
Tạo file `supabase/migrations/20260929_01_issue_ratings_and_kpi.sql`:
```sql
-- Migration: Tạo bảng issue_ratings và thiết lập chính sách RLS
CREATE TABLE IF NOT EXISTS public.issue_ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    issue_report_id UUID NOT NULL UNIQUE REFERENCES public.issue_reports(id) ON DELETE CASCADE,
    reporter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    speed_rating INT NOT NULL CHECK (speed_rating BETWEEN 1 AND 5),
    attitude_rating INT NOT NULL CHECK (attitude_rating BETWEEN 1 AND 5),
    quality_rating INT NOT NULL CHECK (quality_rating BETWEEN 1 AND 5),
    overall_rating DECIMAL GENERATED ALWAYS AS (
        ROUND((speed_rating + attitude_rating + quality_rating)::numeric / 3.0, 1)
    ) STORED,
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Trigger cập nhật thời gian sửa đổi
DROP TRIGGER IF EXISTS update_issue_ratings_modtime ON public.issue_ratings;
CREATE TRIGGER update_issue_ratings_modtime 
BEFORE UPDATE ON public.issue_ratings 
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- Bật Row Level Security (RLS)
ALTER TABLE public.issue_ratings ENABLE ROW LEVEL SECURITY;

-- 1. Policy SELECT
DROP POLICY IF EXISTS "Nhân viên xem toàn bộ đánh giá dịch vụ" ON public.issue_ratings;
CREATE POLICY "Nhân viên xem toàn bộ đánh giá dịch vụ"
ON public.issue_ratings FOR SELECT
TO authenticated
USING (public.is_staff());

DROP POLICY IF EXISTS "Cư dân xem đánh giá sự cố của chính mình" ON public.issue_ratings;
CREATE POLICY "Cư dân xem đánh giá sự cố của chính mình"
ON public.issue_ratings FOR SELECT
TO authenticated
USING (auth.uid() = reporter_id);

-- 2. Policy INSERT: Chỉ cư dân là người báo cáo sự cố đã hoàn thành (resolved) mới được gửi đánh giá
DROP POLICY IF EXISTS "Cư dân gửi đánh giá cho sự cố đã hoàn thành" ON public.issue_ratings;
CREATE POLICY "Cư dân gửi đánh giá cho sự cố đã hoàn thành"
ON public.issue_ratings FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = reporter_id AND
    EXISTS (
        SELECT 1 FROM public.issue_reports
        WHERE id = issue_report_id 
          AND reporter_id = auth.uid() 
          AND status = 'resolved'
    )
);

-- 3. Policy UPDATE: Cư dân cập nhật lại đánh giá của chính mình
DROP POLICY IF EXISTS "Cư dân cập nhật đánh giá của chính mình" ON public.issue_ratings;
CREATE POLICY "Cư dân cập nhật đánh giá của chính mình"
ON public.issue_ratings FOR UPDATE
TO authenticated
USING (auth.uid() = reporter_id)
WITH CHECK (auth.uid() = reporter_id);

-- 4. Policy DELETE: Admin hoặc người đánh giá
DROP POLICY IF EXISTS "Admin hoặc người đánh giá có quyền xóa đánh giá" ON public.issue_ratings;
CREATE POLICY "Admin hoặc người đánh giá có quyền xóa đánh giá"
ON public.issue_ratings FOR DELETE
TO authenticated
USING (public.is_admin() OR auth.uid() = reporter_id);

-- Thêm vào realtime publication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'issue_ratings'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.issue_ratings;
    END IF;
END $$;
```

- [x] **Step 2: Cập nhật tài liệu thiết kế ERD trong `docs/ERD.dbml`**
Bổ sung bảng `issue_ratings` vào `docs/ERD.dbml` để lưu trữ tài liệu chuẩn xác.

---

### Task 2: Data Model & Unit Test TDD (`IssueRatingModel`)

**Files:**
- Create: `test/data/models/issue_rating_model_test.dart`
- Create: `lib/data/models/issue_rating_model.dart`
- Modify: `lib/data/models/issue_model.dart`

**Interfaces:**
- Produces: `IssueRatingModel` class với `fromJson`, `toJson`, `copyWith`, kiểm tra tính toàn vẹn `overallRating`.

- [x] **Step 1: Viết test failing cho `IssueRatingModel`**
Tạo file `test/data/models/issue_rating_model_test.dart` kiểm tra parse đúng các trường JSON từ Supabase, tính toán và format điểm trung bình.

- [x] **Step 2: Chạy test để xác nhận fail (Red)**
Chạy: `flutter test test/data/models/issue_rating_model_test.dart`
Kỳ vọng: Thất bại do chưa tồn tại class `IssueRatingModel`.

- [x] **Step 3: Triển khai class `IssueRatingModel`**
Tạo file `lib/data/models/issue_rating_model.dart`:
```dart
class IssueRatingModel {
  final String id;
  final String issueReportId;
  final String reporterId;
  final int speedRating;
  final int attitudeRating;
  final int qualityRating;
  final double overallRating;
  final String? comment;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? reporterName;
  final String? apartmentCode;

  const IssueRatingModel({
    required this.id,
    required this.issueReportId,
    required this.reporterId,
    required this.speedRating,
    required this.attitudeRating,
    required this.qualityRating,
    required this.overallRating,
    this.comment,
    required this.createdAt,
    this.updatedAt,
    this.reporterName,
    this.apartmentCode,
  });

  factory IssueRatingModel.fromJson(Map<String, dynamic> json) {
    ...
  }

  Map<String, dynamic> toJson() {
    ...
  }
}
```

- [x] **Step 4: Chạy test xác nhận pass (Green)**
Chạy: `flutter test test/data/models/issue_rating_model_test.dart`
Kỳ vọng: 100% tests pass.

---

### Task 3: Tầng Repository (CRUD Đánh Giá Dịch Vụ)

**Files:**
- Modify: `lib/data/repositories/issue_repository.dart`
- Modify: `lib/data/repositories/management_repository.dart`
- Create: `test/data/repositories/issue_rating_repository_test.dart`

**Interfaces:**
- Consumes: `SupabaseClient`
- Produces:
  - `IssueRepository.fetchRatingForIssue(String issueId)`
  - `IssueRepository.submitRating(...)`
  - `IssueRepository.updateRating(...)`
  - `ManagementRepository.fetchAllRatings()`

- [x] **Step 1: Viết test mock cho `IssueRepository` rating methods**
Tạo file `test/data/repositories/issue_rating_repository_test.dart`.

- [x] **Step 2: Bổ sung các phương thức vào `IssueRepository`**
Cài đặt `fetchRatingForIssue`, `submitRating`, `updateRating`.

- [x] **Step 3: Bổ sung `fetchAllRatings()` vào `ManagementRepository`**
Cài đặt truy vấn danh sách toàn bộ đánh giá kèm join thông tin người gửi và căn hộ.

- [x] **Step 4: Chạy test repository xác nhận pass**
Chạy: `flutter test test/data/repositories/issue_rating_repository_test.dart`

---

### Task 4: Tầng State Management (Riverpod Providers & Realtime)

**Files:**
- Create: `lib/data/providers/issue_rating_provider.dart`
- Modify: `lib/features/management/widgets/technician_performance_card.dart`
- Create: `test/data/providers/issue_rating_provider_test.dart`

**Interfaces:**
- Produces:
  - `issueRatingProvider(String issueId)`: Lấy đánh giá của 1 sự cố cụ thể.
  - `allIssueRatingsProvider`: Lấy danh sách toàn bộ đánh giá kèm Realtime stream.
  - Cập nhật `TechnicianStatItem`: Bổ sung `avgRating` và `ratingCount`.

- [x] **Step 1: Viết unit test cho `issue_rating_provider`**
Kiểm tra provider phát ra trạng thái `AsyncData(IssueRatingModel)` và tính toán trung bình sao.

- [x] **Step 2: Tạo `lib/data/providers/issue_rating_provider.dart`**
Triển khai các provider với hỗ trợ Realtime Supabase channel `issue_ratings`.

- [x] **Step 3: Cập nhật `TechnicianPerformanceCard`**
Tính toán chỉ số sao trung bình của từng kỹ thuật viên và hiển thị huy hiệu ⭐ đẹp mắt trên từng thẻ.

---

### Task 5: Giao Diện Cư Dân: BottomSheet Đánh Giá Đa Tiêu Chí & Thẻ Hiển Thị

**Files:**
- Create: `lib/features/resident/widgets/issue_rating_bottom_sheet.dart`
- Modify: `lib/features/resident/screens/issue_detail_screen.dart`
- Create: `test/features/resident/issue_rating_widget_test.dart`

**Interfaces:**
- Consumes: `issueRatingProvider`, `IssueRatingModel`
- Produces: Giao diện chấm sao 3 tiêu chí tương tác, gửi đánh giá, hiển thị thẻ đánh giá khi đã hoàn tất.

- [x] **Step 1: Tạo Widget `IssueRatingBottomSheet`**
Xây dựng giao diện chọn sao mượt mà với 3 tiêu chí:
  - Tốc độ xử lý (1-5 sao)
  - Thái độ phục vụ (1-5 sao)
  - Chất lượng kỹ thuật (1-5 sao)
  - Thẻ tóm tắt cảm nghĩ tự động theo số sao (VD: "⭐ 5.0 - Rất hài lòng")
  - TextFormField nhập góp ý và nút bấm Gửi với loading/haptic feedback.

- [x] **Step 2: Tích hợp vào `IssueDetailScreen`**
Khi sự cố `status == 'resolved'`:
  - Nếu chưa đánh giá: Hiển thị Banner kêu gọi đánh giá.
  - Nếu đã đánh giá: Hiển thị Thẻ đánh giá chi tiết với điểm tổng quan, 3 tiêu chí và nhận xét, kèm nút chỉnh sửa.

- [x] **Step 3: Viết widget test cho tương tác đánh giá**
Tạo `test/features/resident/issue_rating_widget_test.dart` xác minh người dùng có thể chạm đổi số sao và form hiển thị đúng.

- [x] **Step 4: Chạy test widget xác nhận pass**
Chạy: `flutter test test/features/resident/issue_rating_widget_test.dart`

---

### Task 6: Giao Diện Ban Quản Lý: Màn Hình Tổng Hợp & Phân Tích Đánh Giá

**Files:**
- Create: `lib/features/management/screens/service_rating_overview_screen.dart`
- Modify: `lib/features/management/screens/management_home_screen.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/core/router/route_names.dart`

**Interfaces:**
- Produces: Màn hình `ServiceRatingOverviewScreen` cho BQL theo dõi chất lượng dịch vụ, bộ lọc theo số sao, tỷ lệ hài lòng toàn khu.

- [x] **Step 1: Định nghĩa route trong `route_names.dart` và `app_router.dart`**
Thêm route `AppRoutes.managementServiceRatings` (bọc `RoleGuard` kiểm tra quyền nhân viên).

- [x] **Step 2: Tạo màn hình `ServiceRatingOverviewScreen`**
  - Thẻ thống kê đầu trang: Điểm trung bình toàn tòa nhà, Tỷ lệ hài lòng (đánh giá 4-5 sao), Tổng số lượt đánh giá.
  - Bộ lọc FilterChips: Tất cả, 5 sao, 4 sao, Dưới 3 sao (cần cải thiện).
  - Danh sách thẻ nhận xét của cư dân kèm tên phòng, tên KTV phụ trách và thời gian.

- [x] **Step 3: Thêm nút lối tắt mở màn hình Đánh giá dịch vụ trong `ManagementHomeScreen`**
Gắn vào mục Quick Actions hoặc Thẻ hiệu suất KTV để BQL dễ dàng truy cập chỉ với 1 chạm.

---

### Task 7: Kiểm Thử Toàn Diện & Xác Minh (Verification)

**Files:**
- Test toàn bộ project

- [x] **Step 1: Chạy `flutter analyze` xác nhận 0 errors, 0 warnings**
- [x] **Step 2: Chạy `flutter test` xác nhận toàn bộ unit tests và widget tests pass 100%**
- [x] **Step 3: Cập nhật tài liệu kiểm thử `docs/test-plan.md` với kịch bản test mới**
- [x] **Step 4: Commit git theo định dạng chuẩn Conventional Commits**
