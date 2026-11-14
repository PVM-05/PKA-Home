# Đặc Tả Thiết Kế: Dọn Sạch Mock Fallback & Chuẩn Bị Nghiệm Thu Thực Tế (PKA-Home Production UAT Readiness)

## 1. Bối Cảnh & Vấn Đề (Context & Problem Statement)
PKA-Home được định vị là phần mềm thương mại thực tế (B2B SaaS PropTech Platform) phục vụ Ban Quản Lý, Chủ tòa nhà, Kế toán, Kỹ thuật và Cư dân theo chuẩn năm 2026.
Tuy nhiên, qua rà soát chi tiết mã nguồn, tồn tại 4 lỗ hổng cản trở việc nghiệm thu và vận hành thực tế:
1. **Mock Data Fallback ngầm trong Repositories:** Có 9 repository vẫn sử dụng cơ chế `mockFallback: () { ... }` hoặc lưu dữ liệu vào mảng in-memory (`_mockPolls`, `_mockHandovers`, `_inMemoryTickets`, `_inMemoryVisitors`, `_inMemoryParcels`, `_getFallbackContracts`, cư dân nợ mẫu hardcode). Khi mất mạng hoặc DB lỗi, app không báo lỗi mà âm thầm trả dữ liệu ảo khiến người dùng nhầm lẫn là dữ liệu thật.
2. **Lệch phiên bản phát hành:** `pubspec.yaml` vẫn ở mức `1.0.0+1` trong khi tài liệu bàn giao ghi `v2.1`. Chưa có `CHANGELOG.md` theo chuẩn SemVer.
3. **Thiếu hồ sơ pháp lý số 2026:** Thiếu `docs/PRIVACY_POLICY.md` tuân thủ Luật Bảo vệ dữ liệu cá nhân 91/2025/QH15 & Nghị định 356/2025/NĐ-CP và thiếu `docs/TERMS_OF_SERVICE.md` quy định trách nhiệm B2B SaaS.
4. **Tài liệu bàn giao thiếu kịch bản UAT nghiệm thu thật:** `docs/BAN_GIAO_VAN_HANH.md` và `docs/BAN_GIAO_PHONG_TRO.md` chưa có ma trận kiểm thử nghiệm thu chi tiết từng bước để BQL và Chủ đầu tư chạy kiểm tra thực tế trên môi trường live.

---

## 2. Mục Tiêu Thiết Kế (Design Goals)
- **100% Fail-Closed:** Khi không có mạng hoặc DB lỗi, repositories ném ngoại lệ rõ ràng (`AppException`, `PostgrestException`), tầng UI hiển thị Offline Banner hoặc Error State. Tuyệt đối không sinh dữ liệu giả mạo.
- **Dọn sạch 9 Repositories:** Gỡ bỏ toàn bộ danh sách in-memory mock và các khối `mockFallback`.
- **Đồng bộ phiên bản v2.1.0+1:** Cập nhật `pubspec.yaml` và phát hành `CHANGELOG.md` đầy đủ từ v1.0.0 đến v2.1.0.
- **Tuân thủ pháp lý 2026:** Ban hành Chính sách Quyền riêng tư theo Luật 91/2025/QH15 và Điều khoản dịch vụ B2B SaaS.
- **Bộ kịch bản nghiệm thu UAT 8 module:** Cung cấp ma trận checklist chi tiết từng bước có thể tick và ký biên bản nghiệm thu.

---

## 3. Kiến Trúc Chi Tiết (Detailed Architecture)

### 3.1. Dọn Dẹp Repositories & Chuẩn Hóa Lỗi (Fail-Closed Pattern)
Mỗi repository chuyển từ mô hình "thử DB -> lỗi thì trả mock" sang mô hình "gọi DB -> lỗi thì log và ném ngoại lệ có ngữ nghĩa":

| STT | Repository | Dữ liệu Mock Cần Xóa | Thay thế bằng Xử lý Chuẩn |
| :--- | :--- | :--- | :--- |
| 1 | `community_repository.dart` | `_mockPolls`, `_mockPetitions`, `_mockVotedApartments`, `_mockEndorsedApartments`, `mockFallback:` | Query bảng `polls`, `poll_options`, `poll_votes`, `petitions`, `petition_endorsements`. Lỗi thì rethrow hoặc trả empty list nếu DB trống. |
| 2 | `front_desk_repository.dart` | `_inMemoryVisitors`, `_inMemoryParcels`, mock check-in/out mutate | Query bảng `front_desk_logs`, `visitor_passes`. Khi offline/lỗi thì ném `AppException('Không thể kết nối đến máy chủ lễ tân')`. |
| 3 | `parking_repository.dart` | `_inMemoryTickets`, `tkt-mock-01`, `tkt-mock-02` | Gọi RPC hoặc query bảng `visitor_parking_tickets`. Thất bại ném `AppException`. |
| 4 | `material_repository.dart` | `mockFallback:` SLA stats và danh sách vật tư ảo | Đọc trực tiếp `materials`, `issue_materials`, ném lỗi nếu không lấy được dữ liệu. |
| 5 | `handover_repository.dart` | `_mockHandovers`, `mockFallback:`, mock photos | Đọc bảng `handover_records`, `handover_items`, ném ngoại lệ khi thao tác thất bại. |
| 6 | `resident_lifecycle_repository.dart` | `_getFallbackContracts`, `mockFallback:` | Đọc `rental_contracts`, `resident_move_logs`, trả danh sách thật từ DB. |
| 7 | `batch_import_repository.dart` | Các thông báo `'offline mock'` | Gọi RPC import hàng loạt, thất bại trả `BatchImportResult.failed(error)`. |
| 8 | `debt_prediction_repository.dart` | Cư dân mẫu hardcode `"Nguyễn Văn An A0110 nợ 7.850.000đ"` | Gọi RPC / view `v_apartment_debt_aging`, tính toán từ hóa đơn thật. |
| 9 | `resident_activation_repository.dart` | `act-mock-1`, `user-mock-1` fallback | Gọi RPC kích hoạt cư dân thật trên Supabase Auth. |

### 3.2. Cập Nhật Version & CHANGELOG.md
- File: `pubspec.yaml`
  - Đổi `version: 1.0.0+1` thành `version: 2.1.0+1`.
- File: `CHANGELOG.md`
  - Chuẩn hóa theo tiêu chuẩn [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) và Semantic Versioning:
    - **v2.1.0 (2026-11-15):** Xóa bỏ 100% mock data, fail-closed error handling, hồ sơ pháp lý PDPL 91/2025, kịch bản UAT nghiệm thu thực tế, RBAC 22 quyền, bảo mật webhook ngân hàng.
    - **v2.0.0 (2026-11-08):** Động cơ SePay Webhook, VietQR động theo giao dịch, kiểm soát biên bản bàn giao số, chống tràn Layout UI.
    - **v1.5.0 (2026-11-04):** Offline Sync Queue, Quỹ bảo trì 2% tách sổ cái, chống thất thoát tài chính.
    - **v1.0.0 (2026-10-24):** Nền tảng cốt lõi Quản lý Chung cư PKA-Home B2B SaaS.

### 3.3. Hồ Sơ Pháp Lý Chuẩn Quốc Gia 2026
1. **`docs/PRIVACY_POLICY.md` (Chính Sách Bảo Vệ Dữ Liệu Cá Nhân):**
   - Căn cứ pháp lý: Luật Bảo vệ dữ liệu cá nhân số 91/2025/QH15 và Nghị định số 356/2025/NĐ-CP.
   - Các điều khoản bắt buộc:
     - Danh mục dữ liệu thu thập (Họ tên, SĐT, CCCD/Hộ chiếu, email, biển số xe, căn hộ sở hữu/thuê, ảnh công tơ điện nước).
     - Mục đích xử lý: Quản lý vận hành tòa nhà, xuất hóa đơn dịch vụ, cấp phát thẻ xe, kiểm soát an ninh ra vào.
     - Quyền của chủ thể dữ liệu: Quyền được biết, Quyền đồng ý, Quyền truy cập, Quyền chỉnh sửa, Quyền rút lại sự đồng ý, Quyền yêu cầu xóa dữ liệu (Right to Erasure).
     - Cam kết bảo mật: Phân quyền truy cập đa tầng RLS, mã hóa dữ liệu đường truyền (TLS 1.3) và lưu trữ (AES-256).
2. **`docs/TERMS_OF_SERVICE.md` (Điều Khoản Sử Dụng Dịch Vụ SaaS):**
   - Quy định quyền và nghĩa vụ của Ban Quản Lý, Đơn vị vận hành, Cư dân và Khách thuê.
   - Thỏa thuận mức dịch vụ (SLA) và giới hạn trách nhiệm bồi thường.

### 3.4. Ma Trận Nghiệm Thu UAT Thực Tế (UAT Acceptance Matrix)
Cập nhật `docs/BAN_GIAO_VAN_HANH.md` và `docs/BAN_GIAO_PHONG_TRO.md` với 8 kịch bản chạy thật:
- **Kịch bản UAT-01:** Xác thực & Phân quyền 5 vai trò (Admin, Kế toán, Kỹ thuật, Lễ tân/Bảo vệ, Cư dân).
- **Kịch bản UAT-02:** Liên kết Căn hộ chuẩn `A0110` (Gửi yêu cầu -> BQL duyệt/từ chối kèm lý do).
- **Kịch bản UAT-03:** Lập hóa đơn lũy tiến EVN & Phí dịch vụ, tạo mã VietQR động đúng số tiền.
- **Kịch bản UAT-04:** Kiểm tra an toàn RLS (Cư dân phòng A0110 không được xem dữ liệu phòng B0202).
- **Kịch bản UAT-05:** Báo số công tơ điện nước kèm ảnh chụp, Kế toán duyệt và chốt số.
- **Kịch bản UAT-06:** Đăng ký phương tiện, kiểm soát hạn mức xe, cấp vé QR khách vãng lai.
- **Kịch bản UAT-07:** Quỹ bảo trì 2%: Chi tiền gắn phiếu duy nhất, kiểm tra số dư sổ cái bất biến.
- **Kịch bản UAT-08:** Biên bản bàn giao nhận nhà: Kiểm kê tài sản, ký 2 bên, khóa bất biến.

---

## 4. Kiểm Thử & Xác Minh (Testing & Verification)
- Chạy `dart analyze lib test` đảm bảo 0 warning, 0 error.
- Cập nhật các test file trong `test/data/repositories/` để phản ánh đúng hành vi Fail-Closed.
- Kiểm tra toàn bộ git diff đảm bảo không còn dữ liệu mock hardcode.

