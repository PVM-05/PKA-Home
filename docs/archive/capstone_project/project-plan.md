# Kế Hoạch Thực Hiện Chi Tiết
**Ứng dụng Quản lý Chung cư (Flutter + Supabase)**

Kế hoạch chia theo 8 giai đoạn (Phase), tổng cộng đề xuất 10–12 tuần — điều chỉnh theo thời lượng học kỳ thực tế. Mỗi giai đoạn có: mục tiêu, các bước cụ thể, đầu ra (deliverable), và tiêu chí hoàn thành (Definition of Done).

## GIAI ĐOẠN 0: Chuẩn bị (Tuần 1)
**Mục tiêu**: Sẵn sàng môi trường và thống nhất phạm vi.

**Các bước**:
1. Tạo repo Git (đặt cấu trúc thư mục theo Phần 1 của tài liệu quy tắc), thiết lập branch protection cho `main`.
2. Tạo project Supabase, ghi lại `SUPABASE_URL` và `ANON_KEY` vào file `.env` (không commit).
3. Cài Flutter SDK, tạo project Flutter mới, thêm các package: `supabase_flutter`, `flutter_riverpod`, `google_fonts`, `image_picker`.
4. Họp/tự thống nhất phạm vi cuối cùng: xác nhận danh sách tính năng ở Mục 4 (tài liệu thiết kế trước) là bản chốt, đánh dấu tính năng nào là "phải có" (must-have) và "có thể bỏ nếu thiếu thời gian" (nice-to-have).

**Đầu ra**: Repo khởi tạo, Supabase project rỗng, danh sách tính năng đã chốt mức ưu tiên.

## GIAI ĐOẠN 1: Phân tích & Thiết kế (Tuần 1–2)
**Mục tiêu**: Có bộ tài liệu thiết kế làm nền cho toàn bộ code phía sau.

**Các bước**:
1. Viết tài liệu **SRS**: liệt kê actor (Cư dân, Ban quản lý), use case cho từng actor, yêu cầu phi chức năng (hiệu năng, bảo mật RLS, ngôn ngữ tiếng Việt).
2. Vẽ **ERD** chi tiết cho schema đã chốt (`users`, `apartments`, `residents_apartments`, `invoices`, `invoice_items`, `issue_reports`, `issue_images`, `announcements`) — dùng `dbdiagram.io`.
3. Vẽ **wireframe** cho các màn hình chính (đăng nhập, trang chủ cư dân, chi tiết hóa đơn, gửi phản ánh, danh sách căn hộ, lập hóa đơn, xử lý phản ánh) — dùng Figma hoặc giấy/PowerPoint.
4. Thiết kế bộ **RLS policy** trên giấy trước khi code: liệt kê từng bảng, ai được SELECT/INSERT/UPDATE/DELETE và điều kiện.
5. Thiết kế palette màu, font, khoảng cách (spacing scale) — lưu thành file `theme_spec.md` để tham chiếu khi code `core/theme/`.

**Đầu ra**: SRS, ERD, wireframe, bảng RLS policy dự kiến, theme spec.
**Definition of Done**: Có thể đưa ERD + wireframe cho người khác đọc và họ hiểu được toàn bộ luồng nghiệp vụ mà không cần hỏi thêm.

## GIAI ĐOẠN 2: Dựng nền Backend (Tuần 2–3)
**Mục tiêu**: CSDL và xác thực sẵn sàng để frontend gọi vào.

**Các bước**:
1. Tạo bảng trong Supabase theo đúng ERD (SQL migration, không tạo tay qua UI để có lịch sử version).
2. Bật RLS cho toàn bộ bảng, viết policy theo bảng đã thiết kế ở Giai đoạn 1.
3. Cấu hình Supabase Auth (email/password), tạo bảng `users` liên kết với `auth.users` qua trigger tự động khi đăng ký.
4. Tạo Storage bucket `issue-images` với policy chỉ cho phép người dùng upload vào thư mục gắn với chính họ.
5. Viết seed data mẫu (vài căn hộ, vài user, vài hóa đơn) để test.
6. Test thủ công từng policy bằng Supabase SQL editor hoặc Postman: đăng nhập bằng 1 tài khoản cư dân, thử SELECT dữ liệu của căn hộ khác → phải bị chặn.

**Đầu ra**: Schema đã tạo trên Supabase, RLS hoạt động đúng, seed data.
**Definition of Done**: Test thủ công xác nhận cư dân A không đọc/sửa được dữ liệu của cư dân B; ban quản lý có full quyền.

## GIAI ĐOẠN 3: Auth & Khung sườn Frontend (Tuần 3–4)
**Mục tiêu**: Có luồng đăng nhập hoạt động và điều hướng đúng theo vai trò.

**Các bước**:
1. Xây màn hình đăng nhập (email/password), gọi `supabase.auth.signInWithPassword`.
2. Viết `authStateProvider` (Riverpod) theo dõi trạng thái đăng nhập.
3. Sau đăng nhập, đọc role từ bảng `users`, điều hướng: role == 'resident' → vào shell cư dân, role == 'management' → vào shell ban quản lý.
4. Dựng khung điều hướng riêng cho từng vai trò (bottom navigation hoặc drawer) theo wireframe.
5. Áp dụng theme (màu, font Segoe UI/Google Fonts) vào MaterialApp.

**Đầu ra**: App chạy được, đăng nhập phân luồng đúng vai trò, giao diện khung đã theo đúng theme spec.

## GIAI ĐOẠN 4: Tính năng Cư dân (Tuần 4–6)
**Mục tiêu**: Hoàn thiện toàn bộ luồng cư dân.

**Các bước (theo thứ tự ưu tiên)**:
1. **Trang chủ**: hiển thị thông báo mới nhất (query `announcements` mới nhất) và hóa đơn sắp đến hạn (query `invoices` theo `apartment_id` của user, lọc `due_date` gần nhất).
2. **Màn hình danh sách/chi tiết hóa đơn**: join `invoices` + `invoice_items`, hiển thị breakdown từng loại phí.
3. **Luồng "báo đã thanh toán"**: cư dân chỉ được đổi trạng thái sang `pending_confirmation` (không được set thẳng paid — theo nguyên tắc RLS đã thiết kế).
4. **Màn hình gửi phản ánh**: form mô tả + chọn ảnh (`image_picker`) → upload Storage → tạo record `issue_reports` + `issue_images`.
5. **Màn hình theo dõi tiến độ phản ánh**: danh sách phản ánh đã gửi kèm trạng thái, có thể dùng Supabase Realtime để tự cập nhật khi ban quản lý đổi trạng thái.

**Đầu ra**: Toàn bộ 4 tính năng cư dân hoạt động end-to-end với dữ liệu thật từ Supabase.

## GIAI ĐOẠN 5: Tính năng Ban quản lý (Tuần 6–8)
**Mục tiêu**: Hoàn thiện toàn bộ luồng quản trị.

**Các bước**:
1. **Danh sách căn hộ**: hiển thị `apartments` kèm trạng thái trống/đã ở, thêm/sửa thông tin căn hộ và cư dân liên kết (`residents_apartments`).
2. **Lập hóa đơn hàng tháng**: form tạo `invoices` + `invoice_items` cho từng căn hộ.
3. **Xác nhận thanh toán**: danh sách hóa đơn ở trạng thái `pending_confirmation`, nút xác nhận chuyển sang paid.
4. **Thống kê nợ đọng**: query tổng hợp số căn hộ chưa thanh toán, tổng số tiền nợ.
5. **Xử lý phản ánh**: danh sách `issue_reports` theo trạng thái, gán `assigned_staff_id`, đổi trạng thái (chờ tiếp nhận → đang xử lý → đã hoàn thành).
6. **Soạn & gửi thông báo**: form tạo `announcements`, đánh dấu khẩn cấp nếu cần.

**Đầu ra**: Toàn bộ 5 tính năng ban quản lý hoạt động end-to-end.

## GIAI ĐOẠN 6: Kiểm thử & Sửa lỗi (Tuần 8–9)
**Mục tiêu**: Đảm bảo chất lượng trước khi hoàn thiện tài liệu.

**Các bước**:
1. Viết test case theo từng chức năng (dựa trên use case ở SRS), thực hiện test thủ công, ghi lại kết quả vào tài liệu Test Plan.
2. Test riêng các kịch bản bảo mật: cư dân cố truy cập dữ liệu căn hộ khác qua API trực tiếp (không qua UI) — xác nhận RLS chặn đúng.
3. Test luồng end-to-end: một cư dân gửi phản ánh → ban quản lý nhận, xử lý, đổi trạng thái → cư dân thấy cập nhật.
4. Test trên nhiều kích thước màn hình (điện thoại nhỏ, tablet) để kiểm tra layout wrap tự động.
5. Sửa lỗi phát sinh, ưu tiên lỗi ảnh hưởng luồng chính trước, lỗi UI nhỏ sau.

**Đầu ra**: Test Plan/Test Case hoàn chỉnh có kết quả, danh sách lỗi đã sửa.

## GIAI ĐOẠN 7: Hoàn thiện Tài liệu & Báo cáo (Tuần 9–10)
**Mục tiêu**: Có bộ hồ sơ đầy đủ nộp đồ án.

**Các bước**:
1. Cập nhật lại tài liệu thiết kế theo đúng những gì đã code thực tế (schema, RLS có thể đã thay đổi so với bản đầu).
2. Viết Hướng dẫn sử dụng kèm ảnh chụp màn hình thật.
3. Viết Báo cáo cuối kỳ: mục tiêu, quá trình, khó khăn gặp phải, kết quả đạt được, hướng phát triển tiếp theo.
4. Chuẩn bị slide bảo vệ: tóm tắt kiến trúc, demo flow chính (không nhồi quá nhiều chữ).

**Đầu ra**: Bộ hồ sơ đầy đủ (SRS, thiết kế, test plan, user manual, báo cáo, slide).

## GIAI ĐOẠN 8: Diễn tập & Bảo vệ (Tuần 10–11, hoặc theo lịch của trường)
**Các bước**:
1. Diễn tập demo trực tiếp trên thiết bị thật (tránh lỗi bất ngờ khi trình bày).
2. Chuẩn bị sẵn dữ liệu demo đẹp (seed data thực tế, không để trống hoặc lỗi rác).
3. Chuẩn bị câu trả lời cho các câu hỏi thường gặp: vì sao chọn Supabase, RLS hoạt động thế nào, vì sao tách `invoice_items` riêng...
