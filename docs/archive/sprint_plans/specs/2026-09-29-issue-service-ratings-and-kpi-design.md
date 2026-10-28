# Đặc Tả Thiết Kế: Hệ Thống Đánh Giá Dịch Vụ Sự Cố Đa Tiêu Chí & Giám Sát KPI Kỹ Thuật (PKA-Home)

- **Ngày lập**: 2026-09-29
- **Tác giả**: Antigravity & PVM-05
- **Trạng thái**: Đã phê duyệt (Approved)
- **Tài liệu tham chiếu**: [`docs/feature-list.md`](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/feature-list.md) (Phần 3.1: Đánh giá sao sau khi xử lý sự cố), [`docs/superpowers/specs/2026-09-19-comprehensive-rbac-enhancement-design.md`](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/superpowers/specs/2026-09-19-comprehensive-rbac-enhancement-design.md)

---

## 1. Mục Tiêu & Bối Cảnh Nghiệp Vụ

Sau khi kỹ thuật viên hoặc Ban Quản Lý giải quyết xong sự cố kỹ thuật trong căn hộ hoặc khu vực chung (trạng thái `resolved`), hệ thống cần có cơ chế thu thập phản hồi khách quan từ phía Cư dân:
1. **Khảo sát mức độ hài lòng**: Cung cấp công cụ đánh giá đa tiêu chí chuyên nghiệp:
   - **Tốc độ xử lý** (Response Speed): 1–5 sao.
   - **Thái độ phục vụ** (Service Attitude): 1–5 sao.
   - **Chất lượng kỹ thuật** (Technical Quality): 1–5 sao.
2. **Toàn vẹn số liệu**: Điểm tổng thể (`overall_rating`) được tính toán tự động bằng PostgreSQL Generated Column (`STORED`) ở cấp độ CSDL, ngăn ngừa tình trạng can thiệp hoặc sai lệch tính toán từ phía client.
3. **Bảo mật phân quyền (RLS)**: Cư dân chỉ có thể đánh giá sự cố của chính mình khi sự cố đã được đánh dấu hoàn thành (`resolved`).
4. **Giám sát KPI cho BQL**: Thống kê số sao trung bình trên từng kỹ thuật viên trong thẻ hiệu suất, đồng thời cung cấp màn hình tổng quan để BQL theo dõi các phản hồi khen ngợi cũng như các phản ánh chưa hài lòng nhằm nâng cao chất lượng dịch vụ tòa nhà.

---

## 2. Kiến Trúc Cơ Sở Dữ Liệu (Database Layer)

### 2.1. Bảng `public.issue_ratings`
Tạo bảng mới liên kết 1-1 với `issue_reports`:

```sql
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

-- Trigger cập nhật updated_at
CREATE TRIGGER update_issue_ratings_modtime 
BEFORE UPDATE ON public.issue_ratings 
FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- Bật Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.issue_ratings;
```

### 2.2. Chính Sách Bảo Mật Cấp Hàng (Row Level Security - RLS)

```sql
ALTER TABLE public.issue_ratings ENABLE ROW LEVEL SECURITY;

-- 1. SELECT: Ban quản lý / Nhân viên xem toàn bộ; Cư dân xem đánh giá sự cố của chính mình
CREATE POLICY "Nhân viên xem toàn bộ đánh giá dịch vụ"
ON public.issue_ratings FOR SELECT
TO authenticated
USING (public.is_staff());

CREATE POLICY "Cư dân xem đánh giá sự cố của chính mình"
ON public.issue_ratings FOR SELECT
TO authenticated
USING (auth.uid() = reporter_id);

-- 2. INSERT: Cư dân chỉ được thêm khi sự cố thuộc về mình và đã hoàn thành (status = 'resolved')
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

-- 3. UPDATE: Cư dân được cập nhật lại đánh giá của chính mình
CREATE POLICY "Cư dân cập nhật đánh giá của chính mình"
ON public.issue_ratings FOR UPDATE
TO authenticated
USING (auth.uid() = reporter_id)
WITH CHECK (auth.uid() = reporter_id);

-- 4. DELETE: Admin hoặc người đánh giá có quyền xóa
CREATE POLICY "Admin hoặc người đánh giá có quyền xóa đánh giá"
ON public.issue_ratings FOR DELETE
TO authenticated
USING (public.is_admin() OR auth.uid() = reporter_id);
```

---

## 3. Tầng Dữ Liệu & Logic Ứng Dụng (Data Layer)

### 3.1. Model `IssueRatingModel`
File: `lib/data/models/issue_rating_model.dart`
- Thuộc tính:
  - `String id`
  - `String issueReportId`
  - `String reporterId`
  - `int speedRating` (1-5)
  - `int attitudeRating` (1-5)
  - `int qualityRating` (1-5)
  - `double overallRating` (1.0 - 5.0)
  - `String? comment`
  - `DateTime createdAt`
  - `DateTime? updatedAt`
  - `ResidentModel? reporter` (optional)
- Phương thức: `fromJson`, `toJson`, `copyWith`.

### 3.2. Cập Nhật `IssueRepository` & `ManagementRepository`
- `IssueRepository`:
  - `Future<IssueRatingModel?> fetchRatingForIssue(String issueId)`
  - `Future<IssueRatingModel> submitRating({required String issueReportId, required String reporterId, required int speedRating, required int attitudeRating, required int qualityRating, String? comment})`
  - `Future<IssueRatingModel> updateRating({required String ratingId, required int speedRating, required int attitudeRating, required int qualityRating, String? comment})`
- `ManagementRepository`:
  - `Future<List<IssueRatingModel>> fetchAllRatings()`

### 3.3. Tầng State Management (Riverpod)
File: `lib/data/providers/issue_rating_provider.dart`
- `issueRatingProvider(String issueId)`: `FutureProvider.family` cung cấp thông tin đánh giá của sự cố.
- `allIssueRatingsProvider`: `FutureProvider` cung cấp toàn bộ đánh giá cho BQL, lắng nghe Supabase Realtime channel `issue_ratings` để tự động cập nhật.
- Cập nhật `TechnicianStatItem` trong `lib/features/management/widgets/technician_performance_card.dart`:
  - Thêm trường `avgRating` (double) và `ratingCount` (int).

---

## 4. Trải Nghiệm Giao Diện Người Dùng (UI/UX)

### 4.1. Màn Hình Chi Tiết Sự Cố Cư Dân (`IssueDetailScreen`)
- Vị trí: Hiển thị ngay phía trên khu vực Bình luận / Trao đổi khi `issue.status == 'resolved'`.
- Khi chưa đánh giá:
  - Thẻ `Card` trang nhã với biểu tượng ngôi sao màu hổ phách (`Icons.star_rate_rounded`).
  - Tiêu đề: "Đánh giá chất lượng dịch vụ".
  - Mô tả: "Sự cố đã được hoàn thành. Hãy chia sẻ cảm nhận của bạn để BQL nâng cao chất lượng phục vụ."
  - Nút bấm `ElevatedButton`: "Đánh giá ngay".
- Khi bấm "Đánh giá ngay":
  - Mở `ModalBottomSheet` (hoặc Dialog trên màn hình lớn):
    - Tiêu chí 1: **Tốc độ xử lý** (Hàng 5 sao bấm chọn)
    - Tiêu chí 2: **Thái độ phục vụ** (Hàng 5 sao bấm chọn)
    - Tiêu chí 3: **Chất lượng kỹ thuật** (Hàng 5 sao bấm chọn)
    - Thẻ tóm tắt điểm: "⭐ X.X / 5.0 - [Nhãn cảm nghĩ: Rất hài lòng / Hài lòng / Bình thường / Chưa đạt]"
    - `TextFormField`: "Ý kiến đóng góp hoặc nhận xét thêm (không bắt buộc)"
    - Nút bấm: "Gửi đánh giá" với HapticFeedback.
- Khi đã đánh giá:
  - Thẻ hiển thị điểm số tổng thể to rõ với màu vàng sao.
  - Phân tích chi tiết 3 tiêu chí kèm nhận xét của cư dân.
  - Nút icon chỉnh sửa (`Icons.edit_outlined`) cho phép cập nhật lại đánh giá.

### 4.2. Thẻ Hiệu Suất Kỹ Thuật Viên (`TechnicianPerformanceCard`)
- Hiển thị thêm chỉ số sao ⭐ cho từng kỹ thuật viên:
  - Ví dụ: `⭐ 4.9 (12 đánh giá)`.
  - Hiển thị badge màu sắc tương ứng:
    - `>= 4.5`: Xanh lục (Xuất sắc)
    - `3.5 - 4.4`: Xanh dương / Vàng (Tốt)
    - `< 3.5`: Cam (Cần cải thiện)

### 4.3. Màn Hình Báo Cáo & Đánh Giá Dịch Vụ BQL (`ServiceRatingOverviewScreen`)
- Đường dẫn: `/management/service-ratings` (hoặc mở từ Popup menu / Quick Actions BQL).
- AppBar: "Khảo sát & Đánh giá dịch vụ".
- Thẻ thống kê đầu trang:
  - Điểm sao trung bình toàn khu chung cư (VD: `⭐ 4.8 / 5.0`).
  - Tỷ lệ hài lòng (Tỷ lệ đánh giá 4★ và 5★).
  - Tổng số lượt đánh giá đã nhận.
- Thanh lọc `FilterChips`: "Tất cả", "5 sao ⭐", "4 sao ⭐", "Dưới 3 sao ⚠️".
- Danh sách từng thẻ phản hồi của cư dân:
  - Mã căn hộ, tên cư dân, KTV phụ trách xử lý, thời gian đánh giá.
  - Điểm chi tiết: Tốc độ, Thái độ, Kỹ thuật.
  - Lời nhận xét cụ thể.

---

## 5. Quy Chuẩn & Ràng Buộc Kiểm Thử (Testing & Quality Assurance)

1. **Unit Tests**:
   - `test/data/models/issue_rating_model_test.dart`: Kiểm tra `fromJson`, `toJson`, tính toán điểm `overallRating`.
   - `test/data/repositories/issue_repository_rating_test.dart`: Kiểm tra gọi Supabase query đánh giá, mock HTTP response.
2. **Widget Tests**:
   - `test/features/resident/issue_rating_widget_test.dart`: Kiểm tra tương tác chạm chọn sao, gửi form, hiển thị điểm trung bình động.
3. **Static Analysis**:
   - Chạy `flutter analyze` xác nhận 0 lỗi, 0 cảnh báo.
4. **Quy tắc ngôn ngữ & UI**:
   - 100% tiếng Việt chuẩn mực, không dùng từ lóng, không dùng emoji.
   - Màu sắc từ `AppTheme`, Material Design icons (`Icons.*`).
