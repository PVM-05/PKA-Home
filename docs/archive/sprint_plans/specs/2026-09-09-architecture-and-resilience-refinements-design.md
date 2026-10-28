# Thiết Kế Cải Tiến Kiến Trúc & Xử Lý Ngoại Lệ (Architecture & Resilience Refinements)
**Ngày:** 09/09/2026  
**Dự án:** Ứng dụng Quản lý Chung cư (PKA-Home)  
**Trạng thái:** Đã thống nhất thiết kế  

---

## 1. Mục tiêu & Bối cảnh
Nhằm củng cố tính toàn vẹn dữ liệu, trải nghiệm người dùng khi gặp sự cố đường truyền, và hoàn thiện hồ sơ đồ án bảo vệ, tài liệu này đặc tả 4 hạng mục cải tiến kiến trúc:
1. **Toàn vẹn tài chính cấp Server:** Ngăn ngừa sai lệch dữ liệu tài chính bằng cách chuyển phép tính `subtotal` sang cột tự sinh (`GENERATED COLUMN`) của PostgreSQL, loại bỏ tính toán tin cậy từ phía Client.
2. **Khả năng phục hồi khi lỗi tải ảnh:** Tránh tạo bản ghi mồ côi hoặc văng ngoại lệ toàn phần khi upload ảnh sự cố gặp sự cố mạng, bảo toàn nội dung mô tả của cư dân và đưa ra thông báo phù hợp.
3. **Định hướng mở rộng (Scalability & Pagination):** Ghi nhận rõ ràng giới hạn hiện tại của các truy vấn danh sách và lập lộ trình phân trang trong tài liệu báo cáo.
4. **Quy chuẩn luồng khôi phục mật khẩu:** Xác định rõ quyết định thiết kế xác thực nội bộ qua Ban quản lý trong SRS và bổ sung hướng dẫn trực quan trên giao diện đăng nhập.

---

## 2. Chi tiết Thiết kế Kỹ thuật

### 2.1. Server-side Computation cho `invoice_items.subtotal`
- **Cơ sở dữ liệu (PostgreSQL/Supabase):**
  - Tạo file migration: `supabase/migrations/20260909_01_invoice_subtotal_generated_column.sql`.
  - Nội dung migration:
    ```sql
    ALTER TABLE public.invoice_items DROP COLUMN subtotal;
    ALTER TABLE public.invoice_items 
      ADD COLUMN subtotal DECIMAL GENERATED ALWAYS AS (unit_price * quantity) STORED;
    ```
  - Cột `subtotal` trở thành cột sinh tự động (`STORED`). Khi chèn hoặc cập nhật `unit_price` hoặc `quantity`, Postgres tự động tính toán chính xác giá trị `subtotal`.
  - Trigger `trg_recalc_invoice_total` (`AFTER INSERT OR UPDATE OR DELETE ON public.invoice_items`) tự động cộng tổng `subtotal` vào `invoices.total_amount`.
- **Mã nguồn ứng dụng (Flutter/Dart):**
  - Tệp: `lib/data/repositories/management_repository.dart`.
  - Phương thức: `createInvoice()`.
  - Loại bỏ hoàn toàn dòng tính toán và truyền trường `'subtotal'`:
    ```dart
    final List<Map<String, dynamic>> insertItems = items.map((item) => {
      'invoice_id': invoiceId,
      'fee_type': item['fee_type'],
      'unit_price': item['unit_price'],
      'quantity': item['quantity'],
    }).toList();
    ```
- **Tài liệu CSDL:**
  - Cập nhật [docs/ERD.dbml](file:///c:/Users/ADMIN/StudioProjects/pka_home/docs/ERD.dbml) ghi chú `subtotal` là cột sinh `GENERATED ALWAYS AS (unit_price * quantity)`.

---

### 2.2. Xử lý Lỗi Tải Ảnh Sự Cố (Resilient Issue Creation)
- **Mã nguồn Repository:**
  - Tệp: `lib/data/repositories/issue_repository.dart`.
  - Tạo class kết quả:
    ```dart
    class CreateIssueResult {
      final String issueId;
      final bool imageUploadFailed;
      const CreateIssueResult({
        required this.issueId,
        this.imageUploadFailed = false,
      });
    }
    ```
  - Phương thức `createIssue()` trả về `Future<CreateIssueResult>`.
  - Bọc khối lệnh upload ảnh và chèn vào `issue_images` trong `try ... catch (e)`:
    - Nếu xảy ra ngoại lệ khi upload ảnh: Đánh dấu `imageUploadFailed = true`, không throw exception ra ngoài.
    - Bản ghi `issue_reports` vẫn được bảo toàn với đầy đủ mô tả, thời gian, và thông tin người báo.
- **Mã nguồn Giao diện:**
  - Tệp: `lib/features/resident/screens/create_issue_screen.dart`.
  - Xử lý phản hồi từ `createIssue()`:
    - Nếu `result.imageUploadFailed`:
      - Hiển thị SnackBar cảnh báo màu cam (`Colors.orange.shade800` hoặc tương đương):
        *"Đã gửi phản ánh nhưng ảnh tải lên thất bại, vui lòng thử đính kèm lại sau"*
      - Vẫn kích hoạt reload danh sách (`ref.invalidate(residentIssueProvider)`) và đóng màn hình (`Navigator.pop(context)`).
    - Nếu thành công hoàn toàn: Hiển thị SnackBar thành công màu xanh (`AppTheme.success`) và đóng màn hình.

---

### 2.3. Lộ Trình Phân Trang (Pagination)
- **Tài liệu Báo cáo Tiến độ / Báo cáo Cuối kỳ:**
  - Tệp: `docs/bao-cao-tien-do-tuan 1.md`.
  - Thêm nội dung phân tích hiệu năng và lộ trình mở rộng tại mục *Khó khăn & Hướng phát triển*:
    - Giới hạn hiện tại: Các hàm `fetchInvoices()`, `fetchResidents()`, `fetchApartments()`, `fetchIssues()` truy vấn toàn bộ dữ liệu, phù hợp với quy mô thử nghiệm đồ án.
    - Phương án mở rộng (Scalability Solution): Khi số lượng căn hộ và lịch sử hóa đơn tăng lên hàng nghìn bản ghi, hệ thống sẽ chuyển sang sử dụng phân trang cuộn vô tận (Infinite Scroll) hoặc phân trang số trang (Offset-based / Cursor-based pagination) thông qua cú pháp `.range(from, to)` của Supabase PostgREST client kết hợp với `ScrollController` trong Flutter.
- **Tài liệu Đặc tả SRS:**
  - Tệp: `docs/SRS.md` tại mục *4. Yêu cầu Phi chức năng*: Bổ sung yêu cầu về khả năng mở rộng (Scalability) và phân trang.

---

### 2.4. Quyết Định Thiết Kế Luồng "Quên Mật Khẩu"
- **Tài liệu Đặc tả SRS:**
  - Tệp: `docs/SRS.md` tại mục *4. Yêu cầu Phi chức năng*:
    - Bổ sung quy định: Quản lý và khôi phục mật khẩu được thực hiện có chủ đích thông qua Ban quản lý tòa nhà (Internal Admin Verification) nhằm bảo đảm xác thực danh tính cư dân và tránh nguy cơ xâm nhập trái phép vào dữ liệu căn hộ.
- **Mã nguồn Giao diện:**
  - Tệp: `lib/features/auth/screens/login_screen.dart`.
  - Bổ sung liên kết nút bấm text "Quên mật khẩu?" phía dưới hoặc cạnh trường nhập mật khẩu.
  - Khi người dùng nhấn vào: Hiển thị Dialog thông báo:
    - Tiêu đề: "Quên mật khẩu"
    - Nội dung: "Để đảm bảo an toàn thông tin căn hộ, hệ thống quản lý nội bộ yêu cầu xác minh trực tiếp. Vui lòng liên hệ Văn phòng Ban quản lý tòa nhà hoặc Hotline hỗ trợ để được cấp lại mật khẩu."
    - Nút: "Đã hiểu".

---

## 3. Kế Hoạch Kiểm Thử & Xác Minh (Verification Strategy)
1. **Kiểm thử CSDL:**
   - Xác minh câu lệnh SQL migration hợp lệ theo chuẩn PostgreSQL.
2. **Kiểm thử Unit Test / Widget Test:**
   - Chạy `flutter test` đảm bảo toàn bộ bộ test hiện tại tiếp tục pass 100%.
   - Cập nhật / bổ sung test case cho `createIssue` với trường hợp upload ảnh lỗi và upload ảnh thành công.
3. **Kiểm thử Biên dịch:**
   - Chạy `flutter analyze` để đảm bảo không có cảnh báo hay lỗi cú pháp Dart nào phát sinh.
