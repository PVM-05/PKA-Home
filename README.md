# PKA-Home — Hệ Thống Quản Lý Chung Cư Thông Minh

> **Đồ án Liên ngành Kỹ thuật Phần mềm**  
> Ứng dụng số hóa toàn diện quy trình vận hành chung cư, kết nối trực tiếp Ban Quản Lý (BQL) và Cư dân với độ an toàn cao, dữ liệu đồng bộ thời gian thực (Realtime) và giao diện trực quan 100% tiếng Việt.

---

## 🏢 1. Tổng Quan Dự Án

**PKA-Home** giải quyết triệt để các bài toán thường gặp trong quản trị và sinh hoạt tại chung cư hiện đại:
- **Minh bạch tài chính**: Hóa đơn phân rã từng loại phí (điện, nước, quản lý, gửi xe), Cổng thanh toán Demo mô phỏng tức thì, phòng chống gian lận dữ liệu cấp cơ sở dữ liệu.
- **Tương tác nhanh chóng**: Tiếp nhận phản ánh sự cố kèm hình ảnh, tự động phân loại mức độ khẩn cấp (Rule-based), phân công kỹ thuật viên và theo dõi tiến độ theo thời gian thực.
- **Tiện ích số hoá**: Đăng ký thẻ xe điện tử, đặt chỗ tiện ích nội khu (hồ bơi, BBQ, phòng sinh hoạt), tra cứu sổ tay cẩm nang tòa nhà và danh bạ khẩn cấp.
- **Bảo mật cấp độ cao (Security by Design)**: Tách quyền truy cập nghiêm ngặt với PostgreSQL Row Level Security (RLS) và xử lý giao dịch an toàn qua Remote Procedure Calls (RPC).

---

## 🛠️ 2. Công Nghệ & Thư Viện

| Thành phần | Công nghệ / Thư viện | Vai trò |
| :--- | :--- | :--- |
| **Framework** | [Flutter](https://flutter.dev) (SDK ^3.12.0) | Đa nền tảng (Android, iOS, Web, Windows/macOS) |
| **Quản lý trạng thái** | [Flutter Riverpod](https://riverpod.dev) (^2.5.1) | Quản lý state hướng dữ liệu (`AsyncNotifier`, `StreamProvider`) |
| **Backend & Database** | [Supabase](https://supabase.com) (PostgreSQL) | CSDL quan hệ, Auth, RLS Policies, Realtime Engine, Storage |
| **Điều hướng** | [GoRouter](https://pub.dev/packages/go_router) (^14.8.1) | Declarative Routing, quản lý URL và phân luồng Auth guard |
| **Kiểu chữ & Giao diện**| [Google Fonts](https://pub.dev/packages/google_fonts) | Đồng bộ font chữ chuẩn mực, nhất quán trên mọi nền tảng |
| **Biểu đồ & Thống kê** | [FL Chart](https://pub.dev/packages/fl_chart) (^1.2.0) | Biểu đồ doanh thu, cơ cấu thu nợ và tỷ lệ lấp đầy |
| **Báo cáo & Xuất file**| [Excel](https://pub.dev/packages/excel) (^4.0.6) | Xuất báo cáo danh sách hóa đơn theo kỳ định dạng Excel |
| **Bảo mật & Môi trường**| `flutter_dotenv` (^6.0.1) | Quản lý biến môi trường bảo mật |

---

## 📐 3. Kiến Trúc Mã Nguồn (Feature-First)

Dự án tuân thủ nghiêm ngặt mô hình cấu trúc phân theo tính năng kết hợp kiến trúc phân tầng (Clean Architecture principles):

```text
pka_home/
├── lib/
│   ├── core/                          # Tiện ích và cấu hình dùng chung toàn hệ thống
│   │   ├── constants/                 # Hằng số (màu sắc, trạng thái, định dạng)
│   │   ├── theme/                     # ThemeData, bảng màu chuẩn hóa (AppTheme, AppColors)
│   │   ├── utils/                     # Tiện ích format tiền tệ (VND), ngày tháng, chuỗi
│   │   └── widgets/                   # UI Components dùng chung (AppErrorCard, AppStateView...)
│   ├── data/                          # Tầng dữ liệu trung gian
│   │   ├── models/                    # Data classes ánh xạ CSDL (Apartment, Invoice, Issue...)
│   │   ├── repositories/              # Tương tác Supabase Client, truy vấn & RPC
│   │   └── providers/                 # Riverpod providers cho từng miền nghiệp vụ
│   ├── features/                      # Phân chia theo tác nhân và vai trò
│   │   ├── auth/                      # Đăng nhập, phân quyền và điều hướng vai trò
│   │   ├── resident/                  # Toàn bộ màn hình & widget dành cho Cư dân
│   │   │   ├── screens/               # Trang chủ, Hóa đơn, Phản ánh, Đặt tiện ích, Thẻ xe...
│   │   │   └── widgets/               # Các card, dialog con chuyên biệt của cư dân
│   │   └── management/                # Toàn bộ màn hình & widget dành cho Ban Quản Lý
│   │       ├── screens/               # Dashboard, Quản lý Căn hộ, Cư dân, Hóa đơn, Phân công...
│   │       └── widgets/               # Dialog thêm căn hộ, bộ lọc phân cấp, biểu đồ...
│   └── main.dart                      # Điểm khởi chạy ứng dụng & nạp biến môi trường
├── supabase/                          # Cấu hình CSDL & Backend
│   ├── migrations/                    # Toàn bộ kịch bản DDL, RLS, Triggers, RPC
│   └── seed.sql                       # Dữ liệu mẫu kiểm thử
├── test/                              # Bộ kiểm thử tự động (Unit, Widget, Hierarchy, RLS)
└── docs/                              # Tài liệu SRS, ERD, RLS Policy, Test Plan, Wireframes
```

---

## 🌟 4. Danh Sách Tính Năng Chi Tiết

### 4.1. Phân Hệ Cư Dân (Resident)
1. **Xác thực & Liên kết Căn hộ**:
   - Đăng ký/Đăng nhập an toàn.
   - Xin liên kết căn hộ theo cấu trúc phân cấp chuẩn: **Tòa nhà (Block) → Tầng → Căn hộ (`A0110`)**.
   - Theo dõi trạng thái yêu cầu liên kết (Chờ duyệt / Đã duyệt / Bị từ chối).
2. **Bảng tin & Trang chủ (Dashboard)**:
   - Lời chào cá nhân hóa, cập nhật thông báo quan trọng và hóa đơn cần thanh toán.
   - Huy hiệu (Badge) thông báo thời gian thực về trạng thái xử lý phản ánh và hóa đơn.
3. **Hóa đơn & Thanh toán**:
   - Xem chi tiết từng hạng mục chi phí (điện, nước, phí quản lý, rác thải, gửi xe).
   - Tích hợp **Cổng thanh toán Demo** (Demo Payment) hỗ trợ thanh toán 1 chạm tức thì, đối soát giao dịch tự động.
   - Cơ chế phòng ngừa bấm đúp (Debounce & Row Locking) an toàn tuyệt đối.
   - Tra cứu toàn bộ lịch sử thanh toán các kỳ trước.
4. **Phản ánh & Báo cáo Sự cố**:
   - Gửi yêu cầu bảo trì kèm hình ảnh trực tiếp từ camera/thư viện.
   - Cơ chế tự động nhận diện mức độ khẩn cấp (Cao / Trung bình / Thấp) dựa trên từ khóa.
   - Lắng nghe tiến độ xử lý trực tiếp qua **Supabase Realtime Stream**.
5. **Tiện ích Tòa nhà & Cuộc sống**:
   - **Cẩm nang tòa nhà**: Tra cứu nội quy, bảng giá dịch vụ và danh bạ khẩn cấp (gọi trực tiếp BQL/Cứu hỏa/Y tế qua một chạm).
   - **Đặt chỗ tiện ích nội khu**: Hồ bơi, sân Tennis, tiệc BBQ ngoài trời với thuật toán kiểm tra xung đột thời gian.
   - **Quản lý phương tiện**: Đăng ký thẻ xe máy, ô tô và quản lý trạng thái thẻ xe số hóa.

---

### 4.2. Phân Hệ Ban Quản Lý (Management)
1. **Smart Dashboard & Giám sát Vận hành**:
   - Tổng quan các chỉ số trọng yếu: Tỷ lệ lấp đầy tòa nhà, doanh thu thực tế, nợ đọng.
   - Hộp công việc khẩn cấp (Quick Actions & Priority Queue) làm nổi bật các phản ánh nguy cơ cao.
   - Dòng thời gian nhật ký hoạt động hệ thống (Audit Trail).
2. **Quản lý Căn hộ & Cư dân (Apartment & Resident Matrix)**:
   - Quản lý danh mục căn hộ theo chuẩn `A0110` (Block + Tầng 2 chữ số + Phòng 2 chữ số).
   - Tự động nhận diện Tòa/Tầng thông minh khi nhập mã phòng.
   - Quản lý hồ sơ cư dân sinh sống, trạng thái chủ hộ / khách thuê.
   - Phê duyệt / Từ chối yêu cầu liên kết căn hộ qua RPC an toàn.
3. **Quản lý Tài chính & Lập Hóa Đơn**:
   - Tạo hóa đơn linh hoạt theo từng phòng hoặc phát hành hàng loạt theo chu kỳ.
   - Cơ chế tính toán an toàn từ cơ sở dữ liệu (`Generated Columns` và `Database Triggers`).
   - Quản lý trạng thái: Chưa đóng (`unpaid`) → Chờ xác nhận (`pending_confirmation`) → Đã đóng (`paid`).
   - **Xuất dữ liệu hóa đơn ra định dạng file Excel (`.xlsx`)** phục vụ đối soát kế toán.
4. **Điều Phối & Xử Lý Sự Cố (UC-M7)**:
   - Tiếp nhận phản ánh, đánh giá mức độ khẩn cấp.
   - **Phân công trực tiếp cho kỹ thuật viên (`technician`)** phụ trách.
   - Cập nhật tiến độ xử lý và phản hồi cho cư dân.
5. **Truyền thông & Vận hành Tòa nhà**:
   - Soạn và phát thông báo diện rộng kèm đánh dấu mức độ khẩn cấp.
   - Quản trị động nội dung cẩm nang tòa nhà, quy định và danh bạ hỗ trợ khẩn cấp.

---

## 🔒 5. Bảo Mật & Toàn Vẹn Dữ Liệu (Security by Design)

- **Row Level Security (RLS)**: Mọi bảng CSDL đều bật RLS. Cư dân phòng A tuyệt đối không thể đọc hoặc can thiệp dữ liệu phòng B.
- **RPC Encapsulation**: Các thao tác nhạy cảm (duyệt cư dân, chuyển trạng thái hóa đơn, phân công kỹ thuật) chỉ được thực thi thông qua các hàm Database Stored Procedure (RPC) đã được kiểm soát quyền:
  - `confirm_payment(p_invoice_id)`: Xác nhận cư dân đã nộp tiền.
  - `approve_link_request(p_request_id)`: Thêm quyền và gắn căn hộ cho cư dân.
- **Data Integrity**: Trường `subtotal` trong `invoice_items` và `total_amount` trong `invoices` được tính toán tự động bằng PostgreSQL Trigger, không tin cậy dữ liệu tính toán gửi từ phía máy khách (Client-side).
- **Quy chuẩn mã căn hộ**: Định dạng chuẩn `A0110` đại diện cho `[Block A][Tầng 01][Phòng 10]`, loại bỏ nhập liệu lộn xộn.

---

## 🚀 6. Hướng Dẫn Cài Đặt & Chạy Ứng Dụng

### Yêu cầu tiên quyết
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (Khuyến nghị phiên bản `>= 3.12.0`)
- [Dart SDK](https://dart.dev/get-dart)
- Tài khoản [Supabase](https://supabase.com) (hoặc máy chủ Supabase cục bộ qua Docker)

### Các bước khởi chạy

1. **Clone repository về máy**:
   ```bash
   git clone https://github.com/PVM-05/PKA-Home.git
   cd pka_home
   ```

2. **Cài đặt các gói phụ thuộc (Dependencies)**:
   ```bash
   flutter pub get
   ```

3. **Cấu hình môi trường (`.env`)**:
   - Tạo file `.env` tại thư mục gốc dự án dựa trên `.env.example`:
   ```bash
   cp .env.example .env
   ```
   - Điền thông tin kết nối Supabase của bạn:
   ```env
   SUPABASE_URL=https://<your-project-id>.supabase.co
   SUPABASE_ANON_KEY=<your-anon-public-key>
   ```

4. **Thiết lập Cơ sở dữ liệu Supabase**:
   - Chạy tuần tự các file migration trong thư mục `supabase/migrations/` trên Supabase SQL Editor.
   - (Tùy chọn) Chạy file `supabase/seed.sql` để nạp dữ liệu mẫu ban đầu (danh sách căn hộ, BQL, hóa đơn, thông báo mẫu).

5. **Chạy ứng dụng**:
   ```bash
   # Chạy trên thiết bị giả lập hoặc máy thật (Android / iOS / Web / Desktop)
   flutter run
   ```

---

## 🧪 7. Kiểm Thử & Đảm Bảo Chất Lượng (Quality Assurance)

Dự án sở hữu bộ kiểm thử tự động với độ bao phủ cao (TDD & Automation Tests):

- **Kiểm tra cú pháp và chất lượng mã nguồn tĩnh**:
  ```bash
  flutter analyze
  ```
  *(Kết quả: `0 issues found`)*

- **Chạy toàn bộ bộ kiểm thử tự động (Unit, Widget, Hierarchy, Security Tests)**:
  ```bash
  flutter test
  ```
  *(Kết quả: `88/88 test suites passed` — 100% tỷ lệ vượt qua)*

---

## 📜 8. Quy Chuẩn Đóng Góp (Git & Coding Workflow)

- **Ngôn ngữ giao diện**: 100% tiếng Việt chuẩn mực theo [`design-rules.md`](file:///.agents/rules/design-rules.md).
- **Quy tắc phân nhánh**:
  - `feature/<ten-tinh-nang>`: Phát triển tính năng mới.
  - `fix/<ten-loi>`: Sửa chữa lỗi phát sinh.
  - `docs/<ten-tai-lieu>`: Bổ sung/cập nhật tài liệu báo cáo.
- **Quy tắc Commit Message**:
  - Dạng `<type>: <mô tả ngắn>` (Ví dụ: `feat: tích hợp đặt tiện ích nội khu`, `fix: bổ sung tòa nhà tầng cho căn hộ`).

---

## 👥 9. Đội Ngũ Phát Triển

Dự án được xây dựng và hoàn thiện bởi nhóm sinh viên thực hiện Đồ án Liên ngành Kỹ thuật Phần mềm.

---
*Bản quyền © 2026 PKA-Home Project. Phát triển bằng Flutter & Supabase.*
