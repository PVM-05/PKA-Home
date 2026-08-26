# Quy định Bắt buộc cho Agent

## 1. Tuân thủ Quy tắc Dự Án
Agent phải luôn đọc và tuân thủ chặt chẽ các bộ quy tắc trong hệ thống trước khi bắt đầu công việc:
- **`coding-rules.md`**: Quy tắc viết mã Flutter, cấu trúc thư mục (Feature-first), đặt tên biến, git workflow và Riverpod.
- **`database-rules.md`**: Quy tắc thiết kế Supabase, Naming convention, Schema chuẩn, RLS policies và Storage.
- **`design-rules.md`**: Tiêu chuẩn UI/UX, 100% tiếng Việt, quản lý Font/Icon/Màu sắc.
- **`document-plan.md`**: Quy trình chuẩn bị tài liệu báo cáo đồ án.

## 2. Ép buộc Kích hoạt Kỹ năng (Skills & Workflows Enforcement)
Agent **BẮT BUỘC** nhận diện ngữ cảnh và áp dụng ngay lập tức TẤT CẢ các kỹ năng (skills) có trong `.agents/skills/` theo đúng quy trình (workflow). Không chờ người dùng nhắc.

**A. Quy trình Kế hoạch & Thiết kế (Planning)**
- **`brainstorming`**: Bắt buộc khởi chạy hỏi đáp, lập 2-3 phương án và chốt thiết kế trước khi code.
- **`writing-plans` / `executing-plans`**: Bắt buộc viết tài liệu kế hoạch (plan) chi tiết và bám sát thực thi từng bước.
- **`using-superpowers` / `writing-skills`**: Bắt buộc đọc và sử dụng các năng lực hệ thống, quản lý quy trình đúng chuẩn.

**B. Quy trình Code & Quản lý Nhánh (Git/Code Workflow)**
- **`requesting-code-review` / `receiving-code-review`**: Tự động đánh giá, rà soát code trước khi hoàn thành task.
- **`using-git-worktrees` / `finishing-a-development-branch`**: Tự động quản lý branch an toàn khi phát triển và merge tính năng.

**C. Quy trình Debug & Kiểm thử (Testing)**
- **`test-driven-development`**: Bắt buộc viết kịch bản test trước, code sau.
- **`systematic-debugging`**: Phải debug có hệ thống, không đoán mò khi gặp lỗi.
- **`verification-before-completion`**: Phải tự chạy code xác minh thành công trước khi báo hoàn tất.

**D. Phân Việc & Tối ưu Bối cảnh (Delegation & Caveman)**
- **`caveman` (và họ caveman-*)**: Mặc định giao tiếp siêu ngắn gọn để tối ưu token. Tự động nén file, đo đếm cost và review.
- **`cavecrew` / `dispatching-parallel-agents` / `subagent-driven-development`**: Tự động phân rã task lớn thành nhiều subagent để chạy song song.

> **Lưu ý Cốt Lõi:** Agent phải điền ĐẦY ĐỦ checklist của từng skill tương ứng trước khi chuyển trạng thái. Việc bỏ qua bất kỳ quy trình nào (đặc biệt là planning & verification) bị xem là vi phạm nghiêm trọng.
