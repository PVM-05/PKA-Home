# Quy Trình Xoay Khóa Supabase Không Gián Đoạn (Supabase Key Rotation - Zero Downtime)

## 1. Mục Đích & Nguyên Tắc Bảo Mật

Trong hệ thống SaaS Quản lý Tòa nhà Thương Mại (PKA-Home), việc định kỳ xoay khóa (Key Rotation) hoặc xử lý khẩn cấp khi nghi ngờ rò rỉ khóa là bắt buộc theo tiêu chuẩn an toàn thông tin và Luật Bảo vệ Dữ liệu Cá nhân (Luật 91/2025/QH15).

### Các loại khóa trong hệ thống:
1. **Anon Key / Publishable Key:** Được nhúng vào ứng dụng client (Flutter Mobile/Web), chỉ có quyền truy cập dữ liệu được cho phép bởi các chính sách RLS (Row Level Security).
2. **Service Role Key:** Khóa có quyền quản trị tối cao (Bypass RLS), **tuyệt đối không bao giờ được đưa vào mã nguồn client hoặc repository**. Chỉ lưu trên máy chủ backend bảo mật hoặc GitHub Actions Secrets.
3. **JWT Secret:** Chuỗi bí mật ký các JWT token cấp cho người dùng khi đăng nhập.

---

## 2. Quy Trình 5 Bước Xoay Khóa 0-Downtime

### Bước 1: Khảo Sát & Chuẩn Bị (Audit & Assessment)
- Xác định nguyên nhân xoay key (Định kỳ 90 ngày hoặc Xử lý sự cố khẩn cấp).
- Kiểm tra toàn bộ các nơi đang lưu trữ key:
  - Repository CI/CD Secrets (`SUPABASE_URL`, `SUPABASE_ANON_KEY`).
  - File `.env` cục bộ trên môi trường phát triển nội bộ.
  - Cấu hình server staging / production.

### Bước 2: Sinh Khóa Mới Trên Supabase Console
1. Truy cập **Project Settings** > **API**.
2. Tại mục **Project API keys**, tiến hành tạo hoặc kích hoạt cơ chế xoay khóa:
   - Với JWT Secret: Supabase cung cấp cơ chế hỗ trợ 2 khóa JWT đồng thời trong giai đoạn chuyển tiếp (Dual-Signing Window).
   - Nhận giá trị `anon_key` mới và `service_role_key` mới.

### Bước 3: Cập Nhật Biến Môi Trường Máy Chủ & CI/CD
1. Cập nhật GitHub Repository Secrets:
   - `SUPABASE_ANON_KEY`: Điền giá trị khóa mới.
   - `SUPABASE_SERVICE_ROLE_KEY`: Cập nhật khóa mới cho các tác vụ backend/migration.
2. Cập nhật biến môi trường trên máy chủ lưu trữ (Docker / Cloud Host / Supabase Edge Functions).

### Bước 4: Triển Khai Bản Cập Nhật Ứng Dụng (Rolling Deployment)
1. Kích hoạt GitHub Actions Workflow để build ứng dụng Flutter với tham số `--dart-define=SUPABASE_ANON_KEY=...` mới.
2. Xuất bản phiên bản Web App và đẩy bản cập nhật ứng dụng di động lên cửa hàng (Google Play / App Store).
3. Duy trì cửa sổ chuyển tiếp (ít nhất 48–72 giờ) để người dùng cập nhật phiên bản ứng dụng mới.

### Bước 5: Thu Hồi & Vô Hiệu Hóa Khóa Cũ (Revocation)
1. Sau khi tỷ lệ người dùng ứng dụng chuyển sang phiên bản mới đạt trên 95% hoặc kết thúc cửa sổ bảo trì:
2. Truy cập Supabase Dashboard > **API Keys** > Thu hồi (Revoke) khóa cũ hoàn toàn.
3. Theo dõi log giám sát trên Supabase Logs để đảm bảo không còn request hợp lệ nào bị chặn.

---

## 3. Quy Trình Xử Lý Khẩn Cấp (Emergency Incident Response)

Nếu phát hiện khóa bị lộ trên internet (ví dụ: vô tình commit lên public repo):
1. **Ngay lập tức (Trong vòng 5 phút):**
   - Đăng nhập Supabase Dashboard > **Project Settings** > **API** > Nhấn **Revoke Key ngay lập tức**.
   - Điều này sẽ ngay lập tức vô hiệu hóa kẻ tấn công, chấp nhận ứng dụng client sẽ tạm ngắt kết nối trong thời gian phát hành bản vá.
2. **Kích hoạt CI/CD phát hành khẩn cấp (Hotfix Release):**
   - Thay thế key mới trong GitHub Secrets.
   - Trigger build và deploy khẩn cấp bản vá web/mobile.
3. **Kiểm tra nhật ký kiểm toán (Audit Log Inspection):**
   - Truy cập bảng `public.audit_logs` để rà soát toàn bộ các thay đổi dữ liệu bất thường trong khoảng thời gian nghi ngờ lộ lọt.

---

## 4. Danh Mục Kiểm Tra Định Kỳ (90-Day Security Checklist)

- [ ] Toàn bộ nhân sự dev đã cập nhật file `.env` nội bộ từ bản phân phối an toàn.
- [ ] Không có commit nào chứa `SUPABASE_SERVICE_ROLE_KEY` trong lịch sử git (`git log -S ...`).
- [ ] RLS Policies được bật 100% trên toàn bộ các bảng trong CSDL.
- [ ] Private Storage Buckets không có bucket nào chuyển sang trạng thái Public vô ý.

