# Kế Hoạch Triển Khai: Cập Nhật Toàn Bộ Sơ Đồ Thiết Kế & Hệ Thống Tài Liệu Dự Án (PKA-Home)

> **Mục tiêu:** Cập nhật đồng bộ và toàn diện toàn bộ sơ đồ thiết kế (ERD, Use Case, Sequence, State Machine, Kiến trúc 3 Tab, Kết quả kiểm thử), tài liệu đặc tả yêu cầu (SRS), danh mục tính năng, báo cáo đồ án chính thức (.md, .docx) và slide bảo vệ đồ án (.md, .pptx) theo các nâng cấp mới nhất của hệ thống PKA-Home (Hệ thống tiện ích 3 Tab & Sức chứa động, Hủy lịch an toàn, Thông báo phân nhóm đích, Hóa đơn hàng loạt, An toàn bảo mật RLS/RPC).

---

## Danh Sách Nhiệm Vụ Chi Tiết

- [x] **Nhiệm vụ 1: Cập nhật sơ đồ quan hệ thực thể cơ sở dữ liệu (`docs/ERD.dbml`)**
  - Cập nhật bảng `announcements` với 4 trường phân nhóm (`target_type`, `target_building`, `target_floor`, `target_apartment_id`) và khóa ngoại tới `apartments.id`.
  - Cập nhật bảng `building_amenities` với thuộc tính sức chứa động (`booking_type`, `max_capacity`, `slot_duration_minutes`, `fee_amount`, `deposit_amount`, `requires_deposit`).
  - Cập nhật bảng `amenity_bookings` với các trạng thái (`confirmed`, `pending_payment`, `waitlist`, `cancelled`, `completed`, `no_show`) và trường kiểm soát phí/cọc.
  - Cập nhật bảng `vehicles` với trạng thái `cancelled`.
  - Cập nhật ghi chú kiến trúc về RPC nguyên tử và chính sách RLS bảo mật.

- [x] **Nhiệm vụ 2: Nâng cấp script sinh sơ đồ tự động (`docs/generate_all_diagrams.py`) & Sinh ảnh đồ họa (`docs/report_assets/`)**
  - Cập nhật Use Case Cư dân (`hinh2_2a_use_case_cu_dan.png`): bổ sung tự hủy lịch, quản lý danh sách chờ, số lượng người đặt.
  - Cập nhật Use Case Ban Quản Lý (`hinh2_2b_use_case_ban_quan_ly.png`): bổ sung phân hệ Quản trị tiện ích 3 Tab, thông báo theo phân nhóm đối tượng, lập hóa đơn hàng loạt an toàn.
  - Cập nhật Sequence Diagram Thanh toán (`hinh2_13a_tuan_tu_thanh_toan.png`): đồng bộ tham số chuẩn hóa RPC.
  - Cập nhật Sequence Diagram Đặt tiện ích & Hủy lịch (`hinh2_13b_tuan_tu_dat_tien_ich.png`): bổ sung luồng kiểm tra sức chứa theo số lượng người, đẩy Waitlist và hủy lịch an toàn.
  - Cập nhật State Diagram Vòng đời (`hinh2_14a_trang_thai_hoa_don.png`): cập nhật 3 nhánh trạng thái rõ ràng (Hóa đơn, Tiện ích, Sự cố).
  - Cập nhật Biểu đồ Kiểm thử (`hinh_kiem_thu_tong_hop.png`): cập nhật số liệu mới nhất 408 bài test tự động (405 passed, 100% logic test đạt, 0 lỗi tràn viền).
  - Bổ sung Sơ đồ Kiến trúc Quản trị Tiện ích 3 Tab & Thông báo phân nhóm (`hinh2_15_kien_truc_tien_ich_va_thong_bao.png`).
  - Chạy script tạo lại toàn bộ ảnh với độ phân giải cao (220 DPI).

- [x] **Nhiệm vụ 3: Cập nhật tài liệu đặc tả SRS, Tính năng & Wireframes**
  - Cập nhật `docs/SRS.md` bổ sung use case tiện ích 3 Tab, thông báo phân nhóm, hủy lịch.
  - Cập nhật `docs/feature-list.md` đồng bộ ma trận tính năng thực tế.
  - Cập nhật `docs/system_features_overview.md` và `docs/wireframes.md`.

- [x] **Nhiệm vụ 4: Đồng bộ Báo cáo đồ án chính thức (`docs/bao_cao_do_an_chinh_thuc.md`) & Slide (`docs/slide_bao_ve_do_an.md`)**
  - Cập nhật phần phân tích kiến trúc CSDL, các sơ đồ hình vẽ mới và bảng số liệu kiểm thử mới nhất.
  - Cập nhật nội dung slide thuyết trình bảo vệ đồ án chuẩn bị cho hội đồng đánh giá.

- [x] **Nhiệm vụ 5: Tái tạo tài liệu đóng gói (.docx & .pptx), Kiểm tra toàn vẹn & Push `main`**
  - Chạy `python docs/build_docx_report.py` để sinh file `Bao_Cao_Do_An_Lien_Nganh_PKA_Home.docx`.
  - Chạy `python docs/build_pptx_slides.py` để sinh file `Slide_Thuyet_Trinh_Bao_Ve_PKA_Home.pptx`.
  - Xác minh toàn bộ file không có lỗi.
  - Commit trực tiếp lên nhánh `main` và push lên GitHub.
