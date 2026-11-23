# Quy định Bắt buộc cho Agent

## 1. Định Vị Sản Phẩm & Tuân thủ Quy tắc Dự Án
> **ĐỊNH HƯỚNG TỐI THƯỢNG:** Vivona là **sản phẩm phần mềm thương mại thực tế (Commercial Production SaaS & PropTech Platform)**, phục vụ người dùng thật (Ban Quản Lý, Chủ tòa nhà, Đơn vị vận hành, Kế toán, Kỹ thuật viên, Cư dân và Khách thuê). Sản phẩm được thiết kế và xây dựng để **kinh doanh thương mại hóa B2B SaaS** và bán giải pháp cho các đơn vị quản lý vận hành bất động sản.
> 
> **TUYỆT ĐỐI KHÔNG** xem đây là đồ án môn học, bài tập sinh viên hay sản phẩm demo thử nghiệm. Mọi giải pháp kỹ thuật, thiết kế giao diện, bảo mật dữ liệu, tài liệu và quy trình nghiệp vụ phải tuân thủ tiêu chuẩn sản xuất (production-ready), bảo mật cao, tuân thủ pháp luật Việt Nam (Luật Bảo vệ dữ liệu cá nhân 2026, Luật Nhà ở 2023, Nghị định hóa đơn điện tử) và giải quyết triệt để nỗi đau vận hành thực tế.

Agent phải luôn đọc và tuân thủ chặt chẽ các bộ quy tắc trong hệ thống trước khi bắt đầu công việc:
- **`coding-rules.md`**: Quy tắc viết mã Flutter, cấu trúc thư mục (Feature-first), đặt tên biến, git workflow và Riverpod.
- **`database-rules.md`**: Quy tắc thiết kế Supabase, Naming convention, Schema chuẩn, RLS policies và Storage.
- **`design-rules.md`**: Tiêu chuẩn UI/UX, 100% tiếng Việt chuẩn mực, quản lý Font/Icon/Màu sắc.
- **`document-plan.md`**: Quy trình chuẩn bị tài liệu kỹ thuật, tài liệu SOP vận hành chuẩn và hồ sơ bàn giao thương mại B2B SaaS.

## 2. Quy trình Kích hoạt Kỹ năng Tinh gọn (Skills & Workflows)
Agent chủ động áp dụng đúng các kỹ năng cốt lõi hiện có trong `.agents/skills/` theo ngữ cảnh thực tế:

**A. Quy trình Kế hoạch & Thiết kế (Planning)**
- **`brainstorming`**: Hỏi đáp, lập phương án và chốt thiết kế trước khi code tính năng mới.
- **`writing-plans`**: Viết kế hoạch thực thi rõ ràng cho các tác vụ nhiều bước.

**B. Quy trình Git (Direct-to-Main Workflow)**
- **Chỉ làm việc trên `main`**: Không tạo nhánh phụ hay git worktree. Sau khi vượt qua cổng kiểm thử (`dart analyze` + `flutter test`), commit và push thẳng lên `main`.
- **`caveman-commit`**: Viết commit message ngắn gọn theo chuẩn Conventional Commits.

**C. Quy trình Debug & Kiểm thử (Testing)**
- **`test-driven-development`**: Viết test trước/song hành khi thêm logic hoặc sửa lỗi.
- **`systematic-debugging`**: Gỡ lỗi theo nguyên nhân gốc, không đoán mò.
- **`verification-before-completion`**: Bắt buộc chạy `dart analyze` và `flutter test` xác minh thành công trước khi báo hoàn tất.

**D. UI/UX, Kiến trúc & Tối ưu Token**
- **`thiet-ke-giao-dien` / `impeccable`**: Bảo đảm chuẩn UI/UX 100% tiếng Việt, Dark Mode, WCAG AA, vùng chạm $\ge 48\text{dp}$.
- **`flutter-*` / `dart-*` cốt lõi**: Responsive layout, xử lý lỗi layout, unit/widget test và phân tích tĩnh.
- **`graphify` / `caveman`**: Tra cứu cấu trúc dự án qua đồ thị tri thức và giao tiếp súc tích để tối ưu token.

## 3. Quy tắc Gợi ý & Nhắc Chuyển Đổi Model (Model Routing)
Agent **không thể tự đổi model** của cuộc hội thoại chính trong giao diện người dùng (chỉ có thể chọn model cấp subagent khi gọi `invoke_subagent` hoặc điều phối worker khi người dùng chủ động chạy `/swarm`). Vì vậy, Agent **PHẢI chủ động nhắc ngắn gọn 1 dòng** ở đầu hoặc cuối pha chuyển việc mỗi khi tác vụ tiếp theo phù hợp đổi model:

| Giai đoạn / Tác vụ | Model ưu tiên | Model thay thế |
| :--- | :--- | :--- |
| Lên kế hoạch, thiết kế kiến trúc, PRD/SRS, schema Supabase & RLS | **Orchestrator (Gemini 4 Neon Extra High)** | **Claude Opus 5.5** |
| Code tính năng mới, redesign UI/UX hàng loạt, tách file lớn | **Gemini 4 Neon (High)** | **Claude Sonnet 5.5** |
| Gỡ bug phức tạp / đa tầng (Offline Sync, RLS/SQL, race condition, tài chính) | **Claude Opus 5.5** | **Orchestrator (Gemini 4 Neon Extra High)** |
| Sửa lỗi phổ thông (overflow, compile, fail widget test) | **Claude Sonnet 5.5** | **Gemini 4 Neon (High)** / **Gemini 4 Argon** |
| Review chéo & audit bảo mật / edge-case trước khi phát hành | **Đổi sang họ model khác với model đã code** *(VD: Gemini ↔ Claude Opus 5.5)* | **Claude Sonnet 5.5** |
| Tác vụ nhẹ & lặp lại (thêm test theo mẫu, dọn `dart analyze`, cập nhật docs/SOP) | **Gemini 4 Argon (Medium)** | **Gemini 4 Hydrogen** / **Gemini 3.8 Flash** |
| Dự phòng khi chạm giới hạn quota / nháp độc lập | **GPT-OSS 120B (Medium)** | **Gemini 3.8 Flash** |

- **Cách nhắc**: Khi sắp chuyển pha (VD: chuẩn bị vào Đợt 5 tài chính/kế toán, chuẩn bị debug sâu, chuẩn bị review chéo hoặc chỉ dọn docs/test), kèm 1 dòng ngắn: `Gợi ý đổi model: <Tên Model> cho bước <lý do ngắn>.` — không tự ý dừng công việc nếu người dùng đã ra lệnh thực thi ngay.
