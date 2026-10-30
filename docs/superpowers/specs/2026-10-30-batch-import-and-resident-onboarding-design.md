# Tài Liệu Thiết Kế Kỹ Thuật: Bộ Công Cụ Onboarding & Nhập Liệu Hàng Loạt Từ Excel (B2)

> **Mục tiêu:** Xây dựng giải pháp Onboarding dữ liệu thương mại toàn diện cho Ban Quản Lý tòa nhà: Nhập hàng loạt Căn hộ, Cư dân và Chỉ số điện nước từ Excel (.xlsx) với cơ chế kiểm duyệt (validation) từng dòng, báo lỗi chi tiết, tải file mẫu, và quản lý lịch sử liên kết cư dân chuẩn mực (không xóa mất dữ liệu).
> **Ngày lập:** 30/10/2026
> **Trạng thái:** Đã phê duyệt kiến trúc (Approved)

---

## 1. Bối Cảnh & Đột Phá Kiến Trúc Thương Mại

Dựa trên phân tích 3 tầng quản trị thực tế của sản phẩm SaaS Quản lý Tòa nhà:
1. **Nỗi đau lớn nhất khi bán phần mềm cho BQL mới:** Khi nhận một tòa nhà 300 - 1.000 căn, BQL không thể ngồi nhập tay từng căn hộ, từng cư dân trên điện thoại. Họ cần import toàn bộ dữ liệu từ các file Excel có sẵn chỉ trong 1 phút.
2. **Xử lý liên kết cư dân - căn hộ chuẩn mực (Audit & Retention):**
   - Loại bỏ hoàn toàn thao tác `DELETE` thô bạo làm mất lịch sử.
   - Bảng `residents_apartments` được bổ sung `start_date` (ngày nhận nhà/hiệu lực), `end_date` (ngày chuyển đi), và `status` (`active` / `ended`).
   - Cư dân chuyển đi chỉ kết thúc quan hệ (`end_date = CURRENT_TIMESTAMP`), toàn bộ hóa đơn, biên lai, sự cố và chỉ số công tơ trong quá khứ vẫn được bảo toàn nguyên vẹn phục vụ kế toán và kiểm toán.
3. **Cơ chế kích hoạt tài khoản an toàn:**
   - Cư dân được import vào hệ thống kèm số điện thoại và vai trò.
   - Tài khoản được đánh dấu `is_active = TRUE`, mật khẩu khởi tạo ngẫu nhiên an toàn hoặc cấp mã kích hoạt OTP để cư dân tự đặt mật khẩu lần đầu (loại bỏ lỗ hổng mật khẩu mặc định cố định).
4. **Phạm vi quản lý theo tòa nhà (`building_id` Scoping):**
   - Mọi thao tác import đều gắn liền với `building_id` cụ thể của BQL, đảm bảo dữ liệu không bị lẫn lộn giữa các tòa nhà trong mô hình đa tenant (Multi-tenant).

---

## 2. Thiết Kế Cơ Sở Dữ Liệu & Migration

### 2.1. Migration SQL: `20261030_02_residents_apartments_lifecycle_and_batch_import.sql`
1. **Nâng cấp bảng `residents_apartments`:**
   ```sql
   ALTER TABLE public.residents_apartments 
   ADD COLUMN IF NOT EXISTS start_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
   ADD COLUMN IF NOT EXISTS end_date TIMESTAMPTZ DEFAULT NULL,
   ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active' CHECK (status IN ('active', 'ended'));

   CREATE INDEX IF NOT EXISTS idx_residents_apartments_status ON public.residents_apartments(apartment_id, status);
   ```

2. **RPC PostgreSQL Transactional: `batch_import_apartments`:**
   - Đầu vào: `p_building_id UUID`, `p_apartments JSONB` (mảng các object: `code`, `area`, `is_empty`, `floor`, `block`).
   - Xử lý: Insert hoặc Update (Upsert) theo `(building_id, code)` đảm bảo không tạo trùng mã căn.
   - Trả về: `{"success_count": N, "imported_codes": [...]}`.

3. **RPC PostgreSQL Transactional: `batch_import_residents`:**
   - Đầu vào: `p_building_id UUID`, `p_residents JSONB` (mảng các object: `apartment_code`, `full_name`, `phone`, `relation_role`, `start_date`).
   - Xử lý:
     * Tìm `apartment_id` tương ứng trong tòa nhà `p_building_id`.
     * Tìm hoặc tạo bản ghi trong `public.users` theo số điện thoại `phone` (vai trò mặc định `resident`).
     * Thêm liên kết vào `public.residents_apartments` với `status = 'active'`, `start_date = COALESCE(start_date, CURRENT_TIMESTAMP)`.
     * Nếu căn hộ đã có chủ hộ (`owner`) và dòng import mới cũng là `owner`, tự động chuyển chủ hộ cũ sang trạng thái `ended` và ghi nhận lịch sử chuyển nhượng!

4. **RPC PostgreSQL Transactional: `batch_import_meter_readings`:**
   - Đầu vào: `p_building_id UUID`, `p_period TEXT`, `p_readings JSONB` (mảng các object: `apartment_code`, `electric_reading`, `water_reading`).
   - Xử lý: Tìm căn hộ và lưu chỉ số điện nước vào bảng `meter_reading_submissions` với trạng thái `approved` (do BQL trực tiếp nạp số liệu chốt kỳ).

---

## 3. Quy Chuẩn Thẩm Định Từng Dòng (Strict Validation Rules)

### 3.1. Danh mục Căn hộ (Apartments Sheet)
| Cột | Tiêu đề cột | Bắt buộc | Định dạng & Quy tắc |
| :--- | :--- | :--- | :--- |
| A | `Mã Căn Hộ` | Có | Chuẩn `<Block><Tầng 2 số><Phòng 2 số>` (VD: `A0110`, `B0205`). Không chứa khoảng trắng, viết hoa. |
| B | `Diện Tích (m2)` | Có | Số thực dương $> 0$ (VD: `68.5`, `102.0`). |
| C | `Tầng` | Không | Số nguyên $> 0$. Nếu trống, tự động tách từ 2 chữ số tầng trong mã căn. |
| D | `Block/Tòa` | Không | Ký tự chữ cái. Nếu trống, tự động tách từ phần chữ cái đầu mã căn. |
| E | `Đang Trống` | Không | `Có` / `Không` hoặc `TRUE` / `FALSE` (mặc định: `Có` nếu chưa có cư dân). |

### 3.2. Danh mục Cư dân (Residents Sheet)
| Cột | Tiêu đề cột | Bắt buộc | Định dạng & Quy tắc |
| :--- | :--- | :--- | :--- |
| A | `Mã Căn Hộ` | Có | Bắt buộc phải tồn tại trong tòa nhà được chọn. |
| B | `Họ Và Tên` | Có | Chuỗi ký tự, tối thiểu 2 từ, không chứa ký tự đặc biệt. |
| C | `Số Điện Thoại` | Có | 10 chữ số chuẩn Việt Nam (`03x`, `05x`, `07x`, `08x`, `09x`). |
| D | `Vai Trò` | Có | `Chủ hộ` (owner), `Khách thuê` (tenant), `Thành viên` (member). |
| E | `Ngày Nhận Nhà` | Không | Định dạng `dd/MM/yyyy` (mặc định: ngày hiện tại). |

### 3.3. Danh mục Chỉ số Điện Nước (Meter Readings Sheet)
| Cột | Tiêu đề cột | Bắt buộc | Định dạng & Quy tắc |
| :--- | :--- | :--- | :--- |
| A | `Mã Căn Hộ` | Có | Bắt buộc phải tồn tại trong tòa nhà. |
| B | `Kỳ Thu` | Có | Định dạng `MM/yyyy` (VD: `10/2026`). |
| C | `Chỉ Số Điện Mới (kWh)` | Có | Số thực $\ge 0$. Cảnh báo nếu $< 0$. |
| D | `Chỉ Số Nước Mới (m3)` | Có | Số thực $\ge 0$. Cảnh báo nếu $< 0$. |

---

## 4. Tầng Dữ Liệu & Tiện Ích Client (Engine)

### 4.1. Models
Tạo file `lib/data/models/batch_import_model.dart`:
- `BatchImportType`: `enum BatchImportType { apartments, residents, meterReadings }`
- `BatchRowErrorModel`:
  - `int rowNumber`: Vị trí dòng thực tế trong file Excel (bắt đầu từ dòng 2 sau tiêu đề).
  - `String columnName`: Tên cột bị lỗi (VD: `Số Điện Thoại`).
  - `dynamic invalidValue`: Giá trị lỗi người dùng đã nhập.
  - `String errorMessage`: Nguyên nhân chi tiết (VD: `Số điện thoại phải gồm 10 chữ số hợp lệ`).
- `BatchImportResultModel<T>`:
  - `int totalRows`: Tổng số dòng dữ liệu.
  - `List<T> validItems`: Danh sách các bản ghi hợp lệ sẵn sàng nạp.
  - `List<BatchRowErrorModel> rowErrors`: Danh sách các lỗi phát hiện được.
  - `bool get hasErrors => rowErrors.isNotEmpty;`
  - `bool get hasValidItems => validItems.isNotEmpty;`

### 4.2. Bộ Công Cụ Excel Engine (`ExcelImportHelper`)
Tạo file `lib/core/utils/excel_import_helper.dart`:
1. **Sinh File Excel Mẫu (Templates):**
   - `generateTemplate(BatchImportType type)`: Tạo file `.xlsx` định dạng chuyên nghiệp:
     * Dòng 1: Tiêu đề in đậm, nền xanh biển thương hiệu PKA (`#1E88E5`), chữ trắng.
     * Dòng 2 & 3: Dữ liệu mẫu chuẩn mực kèm ghi chú hướng dẫn (VD: `A0110`, `68.5`, `Nguyễn Văn A`, `0901234567`).
2. **Phân Tích & Xác Thực (Parser & Validator):**
   - `parseApartments(List<int> bytes)`: Trả về `BatchImportResultModel<ApartmentImportItem>`.
   - `parseResidents(List<int> bytes, {Set<String>? existingApartmentCodes})`: Trả về `BatchImportResultModel<ResidentImportItem>`.
   - `parseMeterReadings(List<int> bytes, {Set<String>? existingApartmentCodes})`: Trả về `BatchImportResultModel<MeterReadingImportItem>`.
3. **Xuất File Báo Cáo Lỗi (Error Export):**
   - `exportErrorRows(List<BatchRowErrorModel> errors, String originalFileName)`: Tạo file Excel chứa riêng các dòng bị lỗi kèm cột "Nguyên Nhân Lỗi" để BQL mở lên sửa lại ngay và upload lại.

### 4.3. Quản Lý File Native & Mockable (`FilePickerService`)
- Tích hợp `file_picker` (hoặc interface trừu tượng) để người dùng chọn file `.xlsx` trên mọi nền tảng (Android, iOS, Web, Desktop), có mock provider phục vụ kiểm thử Widget test tự động.

---

## 5. Tầng Giao Diện Người Dùng (UI/UX)

### 5.1. Màn hình Trung Tâm: `BatchImportCenterScreen`
Vị trí: `lib/features/management/screens/batch_import_center_screen.dart`
Bao gồm:
1. **Thanh Tab:**
   - 🏢 `Căn hộ`
   - 👥 `Cư dân`
   - ⚡ `Điện nước`
2. **Khu vực 1: Hướng dẫn & Tải mẫu:**
   - Thẻ thông tin trực quan: Mô tả định dạng, các cột bắt buộc.
   - Nút **"Tải file Excel mẫu"**: Nhấn để tải và mở file mẫu ngay.
3. **Khu vực 2: Tải lên File:**
   - Hộp "Chọn file từ thiết bị" với viền nét đứt (Dashed border).
   - Khi đã chọn file: Hiển thị tên file, dung lượng, và nút "Chọn file khác".
4. **Khu vực 3: Bảng Thẩm Định & Xem Trước (Preview & Errors):**
   - 2 Thẻ đếm nổi bật:
     - 🟢 **Hợp lệ: X dòng**
     - 🔴 **Lỗi: Y dòng** (nếu Y > 0)
   - Nếu có lỗi:
     - Danh sách cuộn chi tiết từng dòng lỗi kèm Badge màu đỏ: `Dòng 4 | Cột: Số Điện Thoại | Giá trị: 09123 | Lý do: SĐT không hợp lệ`.
     - Nút **"Xuất file lỗi để sửa (.xlsx)"**.
   - Nếu có dòng hợp lệ:
     - Bảng xem trước 5 dòng dữ liệu đầu tiên.
5. **Thanh Thao Tác Dưới Cùng (Bottom Sticky Bar):**
   - Nút chính **"Xác nhận nhập N dòng hợp lệ"**:
     - Có hộp thoại cảnh báo nếu có một số dòng bị bỏ qua do lỗi.
     - Hiển thị thanh tiến trình khi đang thực hiện import.
     - Sau khi hoàn thành: Hiển thị thông báo thành công và tự động làm mới danh sách dữ liệu trong app.

### 5.2. Lối Tắt Từ Các Màn Hình Chuyên Biệt
- Thêm nút hành động "Nhập Excel" vào AppBar hoặc Floating Action Button của:
  - `ApartmentManagementScreen`: Mở trực tiếp Tab 1 của Batch Import Center.
  - `ResidentManagementScreen`: Mở trực tiếp Tab 2.
  - `ManagementMeterReadingScreen`: Mở trực tiếp Tab 3.

---

## 6. Kế Hoạch Kiểm Thử TDD & Verification

1. **Unit Test Excel Parser & Validation Engine:**
   - `test/core/utils/excel_import_helper_test.dart`:
     * Kiểm tra sinh template chuẩn cho cả 3 danh mục.
     * Kiểm tra validation căn hộ: Chấp nhận `A0110`, từ chối `A101` hoặc `XYZ`.
     * Kiểm tra validation cư dân: Chấp nhận SĐT 10 số, từ chối số ngắn/chứa chữ.
     * Kiểm tra validation điện nước: Chấp nhận số $\ge 0$, định dạng kỳ hợp lệ.
     * Kiểm tra xuất file báo cáo lỗi.
2. **Integration Test Database RPC:**
   - `test/integration/batch_import_migration_test.dart`:
     * Kiểm tra migration vòng đời cư dân `start_date`, `end_date`, `status`.
     * Kiểm tra các RPC batch import với kiểm tra quyền hạn.
3. **Widget Test Giao Diện:**
   - `test/features/management/screens/batch_import_center_screen_test.dart`:
     * Kiểm tra chuyển đổi 3 tabs.
     * Kiểm tra hiển thị bảng đếm hợp lệ / lỗi và nút bấm nhập liệu.
4. **Quality Gate:**
   - `dart analyze`: 0 issues.
   - `flutter test`: 100% tests pass.
