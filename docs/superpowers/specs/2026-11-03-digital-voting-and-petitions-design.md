# Đặc Tả Thiết Kế: Biểu Quyết Điện Tử & Kiến Nghị Cộng Đồng Cư Dân (D7)

> **Mục tiêu:** Xây dựng hệ thống Biểu Quyết Điện Tử (Digital AGM & Online Polling) tuân thủ quy chuẩn **Điều 102 Luật Nhà ở 2023** và **Thông tư 05/2024/TT-BXD**, cùng Hệ thống Kiến Nghị Cộng Đồng (Resident Petitions) minh bạch, thúc đẩy sự gắn kết và văn minh trong không gian sống chung cư.

---

## 1. Cơ Sở Pháp Lý & Yêu Cầu Nghiệp Vụ

### 1.1. Biểu Quyết Điện Tử (Digital Voting & AGM)
- **Quy định tính quyền biểu quyết**:
  - `per_apartment`: Mỗi căn hộ = 1 lá phiếu (Áp dụng cho khảo sát dân cư, tiện ích, nội quy sinh hoạt thường nhật).
  - `by_area`: Quyền biểu quyết tính theo diện tích sàn sở hữu riêng ($m^2$) ghi trên sổ hồng / hợp đồng mua bán của căn hộ (Áp dụng cho Hội nghị nhà chung cư, lựa chọn đơn vị quản lý vận hành, thông qua báo cáo thu chi quỹ bảo trì 2%, điều chỉnh đơn giá dịch vụ).
- **Ngưỡng thông qua (Approval Threshold)**:
  - Thông thường: Đạt trên 50% tổng quyền biểu quyết của các đại biểu tham dự.
  - Các vấn đề trọng yếu (thay đổi đơn vị vận hành, sửa đổi quy chế tòa nhà): Đạt từ 70% đến 75% theo quy định.
- **Tính toàn vẹn & Chống gian lận**:
  - Mỗi căn hộ chỉ được bỏ phiếu **1 lần duy nhất** cho mỗi đợt biểu quyết (`UNIQUE(poll_id, apartment_id)`).
  - Ghi nhận `voter_user_id` (chủ hộ hoặc đại diện hợp pháp), `apartment_id`, `vote_weight_area` ($m^2$ tại thời điểm bỏ phiếu).
  - Phiếu bầu là **bất biến (Immutable)**: Khi cuộc biểu quyết kết thúc (`status = 'closed'` hoặc thời gian `now() > end_time`), chặn toàn bộ hành vi sửa/xóa phiếu qua trigger cơ sở dữ liệu.
  - Hỗ trợ lựa chọn đơn (`single_choice`), chọn nhiều (`multiple_choice`) và dạng chuẩn biểu quyết quốc hội / đại hội (`yes_no_abstain`: Tán thành / Không tán thành / Không có ý kiến).

### 1.2. Kiến Nghị Cộng Đồng (Resident Petitions)
- Cư dân có thể tạo kiến nghị về các vấn đề chung (an ninh, vệ sinh, cây xanh, tiện ích, tiếng ồn...).
- Cơ chế **Đồng thuận (Endorse / Ủng hộ)**: Các căn hộ khác có thể bấm nút "Đồng thuận" để BQL nhận biết mức độ quan tâm của cộng đồng (mỗi căn hộ chỉ được bấm 1 lần).
- Vòng đời xử lý của BQL:
  - `pending` (Chờ tiếp nhận) -> `acknowledged` (Đã tiếp nhận) -> `in_progress` (Đang giải quyết) -> `resolved` (Đã giải quyết) hoặc `rejected` (Không phù hợp / từ chối kèm lý do).
- BQL có mục **Phản hồi chính thức (Official Response)** hiển thị nổi bật kèm thời gian và tên cán bộ BQL xử lý.

---

## 2. Kiến Trúc Dữ Liệu (PostgreSQL & Supabase)

### 2.1. Bảng `polls` (Đợt biểu quyết / Khảo sát)
- `id` (UUID, PK)
- `poll_code` (VARCHAR, UNIQUE, định dạng `POLL-YYYYMM-XXXXX`)
- `building_id` (UUID, FK `buildings.id`, nullable)
- `title` (TEXT, NOT NULL)
- `description` (TEXT)
- `category` (VARCHAR, NOT NULL, default `'general'`: `'general'`, `'agm'`, `'finance'`, `'maintenance'`, `'rule'`)
- `vote_weight_type` (VARCHAR, NOT NULL, default `'per_apartment'`: `'per_apartment'`, `'by_area'`)
- `choice_type` (VARCHAR, NOT NULL, default `'single_choice'`: `'single_choice'`, `'multiple_choice'`, `'yes_no_abstain'`)
- `min_participation_rate` (NUMERIC(5,2), default 50.0) — Tỷ lệ tham gia tối thiểu để cuộc biểu quyết hợp lệ (%)
- `required_approval_rate` (NUMERIC(5,2), default 50.0) — Tỷ lệ tán thành để được thông qua (%)
- `start_time` (TIMESTAMPTZ, NOT NULL)
- `end_time` (TIMESTAMPTZ, NOT NULL)
- `status` (VARCHAR, NOT NULL, default `'active'`: `'draft'`, `'active'`, `'closed'`, `'cancelled'`)
- `created_by` (UUID, FK `users.id`)
- `created_at`, `updated_at` (TIMESTAMPTZ)

### 2.2. Bảng `poll_options` (Các phương án lựa chọn)
- `id` (UUID, PK)
- `poll_id` (UUID, FK `polls.id` ON DELETE CASCADE)
- `option_text` (TEXT, NOT NULL)
- `option_order` (INT, default 0)
- `created_at` (TIMESTAMPTZ)

### 2.3. Bảng `poll_votes` (Phiếu bầu của căn hộ)
- `id` (UUID, PK)
- `poll_id` (UUID, FK `polls.id` ON DELETE CASCADE)
- `apartment_id` (UUID, FK `apartments.id`)
- `voter_user_id` (UUID, FK `users.id`)
- `selected_option_ids` (UUID[], danh sách option đã chọn)
- `vote_weight` (NUMERIC(10,2), diện tích $m^2$ căn hộ nếu `by_area`, hoặc 1.0 nếu `per_apartment`)
- `voted_at` (TIMESTAMPTZ, default `now()`)
- Ràng buộc: `UNIQUE(poll_id, apartment_id)` (Mỗi căn hộ 1 lá phiếu duy nhất).

### 2.4. Bảng `resident_petitions` (Kiến nghị cư dân)
- `id` (UUID, PK)
- `petition_code` (VARCHAR, UNIQUE, định dạng `PET-YYYYMM-XXXXX`)
- `apartment_id` (UUID, FK `apartments.id`)
- `author_user_id` (UUID, FK `users.id`)
- `title` (TEXT, NOT NULL)
- `content` (TEXT, NOT NULL)
- `category` (VARCHAR, default `'general'`: `'security'`, `'hygiene'`, `'amenity'`, `'noise'`, `'other'`)
- `image_urls` (TEXT[], đính kèm ảnh bằng chứng nếu có)
- `endorsement_count` (INT, default 0)
- `status` (VARCHAR, default `'pending'`: `'pending'`, `'acknowledged'`, `'in_progress'`, `'resolved'`, `'rejected'`)
- `official_response` (TEXT, phản hồi chính thức của BQL)
- `responded_by_staff_id` (UUID, FK `users.id`)
- `responded_at` (TIMESTAMPTZ)
- `created_at`, `updated_at` (TIMESTAMPTZ)

### 2.5. Bảng `petition_endorsements` (Lượt đồng thuận kiến nghị)
- `id` (UUID, PK)
- `petition_id` (UUID, FK `resident_petitions.id` ON DELETE CASCADE)
- `apartment_id` (UUID, FK `apartments.id`)
- `user_id` (UUID, FK `users.id`)
- `created_at` (TIMESTAMPTZ)
- Ràng buộc: `UNIQUE(petition_id, apartment_id)`.

---

## 3. Các RPCs PostgreSQL Thiết Yếu

1. `submit_poll_vote(p_poll_id, p_apartment_id, p_voter_user_id, p_option_ids UUID[])`:
   - Kiểm tra poll có đang `active` và `now() BETWEEN start_time AND end_time`.
   - Lấy diện tích căn hộ `apartments.area`.
   - Ghi nhận phiếu bầu với trọng số phù hợp.
2. `get_poll_results(p_poll_id)`:
   - Tính toán tổng số căn hộ tham gia biểu quyết / tổng số căn hộ trong tòa.
   - Tính tổng diện tích đã biểu quyết / tổng diện tích toàn tòa.
   - Tính số phiếu và tổng diện tích tán thành cho từng option.
   - Kết luận tỷ lệ % đạt được và trạng thái thông qua (`is_approved`).
3. `endorse_petition(p_petition_id, p_apartment_id, p_user_id)`:
   - Cho phép căn hộ bấm ủng hộ kiến nghị (chỉ 1 lần), tự động tăng `endorsement_count`.
4. `update_petition_response(p_petition_id, p_status, p_response, p_staff_id)`:
   - BQL phản hồi chính thức kiến nghị và cập nhật trạng thái.

---

## 4. Thiết Kế Giao Diện Người Dùng (UI/UX)

### 4.1. Màn hình Cư Dân (`ResidentCommunityScreen`):
- Gồm 2 tab:
  - **Tab 1: Biểu quyết & Khảo sát**:
    - Danh sách các cuộc biểu quyết đang diễn ra (`active`) và đã kết thúc (`closed`).
    - Thẻ biểu quyết hiển thị: Tiêu đề, hạn chót, loại quyền biểu quyết (Huy hiệu: "1 Căn hộ = 1 Phiếu" hoặc "Theo diện tích sở hữu $m^2$").
    - Trạng thái căn hộ: "Chưa bỏ phiếu" hoặc "Đã biểu quyết".
    - Khi bấm vào: Mở Hộp thoại biểu quyết (`VotePollSheet`), hiển thị chi tiết nội dung, các phương án chọn, nút "Xác nhận gửi phiếu". Sau khi gửi hiện kết quả phân bổ % trực quan.
  - **Tab 2: Kiến nghị & Đóng góp**:
    - Danh sách kiến nghị của cư dân tòa nhà.
    - Nút bấm hình ngón tay cái / bàn tay "Đồng thuận" hiển thị số lượng (VD: `👍 34 căn hộ đồng thuận`).
    - Nút "Tạo kiến nghị mới" (`CreatePetitionSheet`): Tiêu đề, danh mục, nội dung chi tiết.
    - Hộp thoại xem chi tiết kiến nghị: Toàn văn nội dung, phản hồi chính thức của Ban Quản Lý kèm con dấu màu xanh lá `"Đã giải quyết"` hoặc màu cam `"Đang xử lý"`.

### 4.2. Màn hình Ban Quản Lý (`CommunityManagementScreen`):
- Dải KPI cộng đồng: Cuộc biểu quyết đang mở, Tỷ lệ tham gia trung bình, Kiến nghị chờ xử lý, Kiến nghị đã giải quyết.
- Tab 1 - Quản lý Biểu Quyết:
  - Nút "Tạo cuộc biểu quyết mới" (`CreatePollSheet`): Chọn loại biểu quyết (Theo căn hộ / Theo diện tích m²), danh sách các phương án, thời hạn.
  - Xem báo cáo kết quả chi tiết từng cuộc biểu quyết: Biểu đồ thanh tỷ lệ %, thống kê theo số lượng căn và theo $m^2$, kết luận tỷ lệ thông qua theo Luật Nhà ở.
- Tab 2 - Tiếp nhận & Trả lời Kiến Nghị:
  - Lọc kiến nghị theo trạng thái (`Chờ tiếp nhận`, `Đang xử lý`, `Đã giải quyết`).
  - Nút "Xử lý & Phản hồi" (`RespondPetitionDialog`): Nhập nội dung giải trình, đổi trạng thái, gửi thông báo đến cư dân.

