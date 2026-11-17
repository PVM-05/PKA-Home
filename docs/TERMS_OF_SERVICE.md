# Điều Khoản Dịch Vụ Nền Tảng (Terms of Service)
**Nền Tảng Quản Lý Vận Hành Bất Động Sản B2B SaaS Vivona**

*Ban hành và có hiệu lực từ ngày: 15/11/2026*  
*Áp dụng cho: Đơn vị Quản lý Vận hành Bất động sản, Ban Quản Lý Tòa nhà, Chủ sở hữu và Cư dân sử dụng dịch vụ.*

---

## 1. Định Nghĩa & Phạm Vi Thỏa Thuận
Điều khoản Dịch vụ này ("Thỏa thuận") cấu thành một hợp đồng pháp lý có giá trị ràng buộc giữa **Vivona** ("Bên Cung Cấp Nền Tảng") và **Khách Hàng Doanh Nghiệp** ("Ban Quản Lý", "Công ty Quản lý Bất động sản" hoặc "Chủ Tòa Nhà") cùng **Người Dùng Cuối** ("Cư dân", "Khách thuê").

Bằng việc truy cập, tải về hoặc sử dụng hệ thống ứng dụng Vivona (bao gồm Mobile App iOS/Android và Web Workstation), Bên Sử Dụng đồng ý chịu sự điều chỉnh của toàn bộ nội dung trong Thỏa thuận này.

---

## 2. Cam Kết Chất Lượng Dịch Vụ (Service Level Agreement - SLA)

1. **Tính Sẵn Sàng Của Hệ Thống (Uptime SLA)**:
   - Vivona cam kết tỷ lệ hoạt động ổn định của máy chủ cơ sở dữ liệu và hệ thống API đạt tối thiểu **99.5%** mỗi tháng tính theo lịch (24/7/365).
   - Thời gian bảo trì định kỳ có kế hoạch (Scheduled Maintenance) sẽ được thông báo trước tối thiểu **48 giờ** và chỉ diễn ra trong khung giờ thấp điểm (01:00 AM - 04:00 AM giờ Việt Nam).
2. **Thời Gian Phản Hồi Sự Cố Kỹ Thuật**:
   - **Sự cố P0 (Hệ thống ngưng trệ toàn bộ, lỗi thanh toán/hóa đơn nghiêm trọng)**: Thời gian tiếp nhận và xử lý trong vòng **60 phút**.
   - **Sự cố P1 (Lỗi một phân hệ tính năng, không thể tạo phản ánh hoặc check-in)**: Xử lý trong vòng **04 giờ làm việc**.
   - **Yêu cầu hỗ trợ thông thường P2/P3**: Phản hồi trong vòng **24 giờ làm việc**.
3. **Sao Lưu & Phục Hồi Thảm Họa (Backup & Disaster Recovery)**:
   - Toàn bộ cơ sở dữ liệu Supabase PostgreSQL được cấu hình sao lưu tự động (Automated Daily Snapshots) và lưu trữ phân tán an toàn.
   - Mục tiêu thời gian phục hồi dữ liệu (RTO): $\le 2$ giờ. Mục tiêu điểm phục hồi (RPO): $\le 1$ giờ.

---

## 3. Quyền & Nghĩa Vụ Của Bên Cung Cấp Nền Tảng (Vivona)

1. Cung cấp hạ tầng kỹ thuật, tài nguyên máy chủ đám mây, các bản cập nhật bảo mật và nâng cấp tính năng định kỳ theo gói thuê bao đã ký kết.
2. Bảo mật tuyệt đối dữ liệu nội bộ của tòa nhà và thông tin cá nhân của cư dân, tuân thủ nghiêm ngặt Chính sách Quyền riêng tư theo Luật Bảo vệ dữ liệu cá nhân 91/2025/QH15.
3. Không truy cập, sử dụng hoặc tiết lộ dữ liệu tài chính, sổ cái, thông tin nhân khẩu của khách hàng cho bất kỳ bên thứ ba nào khi chưa có sự đồng ý bằng văn bản của Khách hàng, trừ trường hợp cơ quan tư pháp yêu cầu theo luật định.

---

## 4. Quyền & Nghĩa Vụ Của Ban Quản Lý (Khách Hàng B2B)

1. Chịu trách nhiệm về tính chính xác, tính hợp pháp của danh sách cư dân, hợp đồng căn hộ và số liệu công tơ điện nước nhập vào hệ thống.
2. Quản lý, bảo mật nghiêm ngặt tài khoản quản trị viên cấp cao (Admin Credentials), bắt buộc kích hoạt xác thực hai yếu tố (2FA/TOTP) cho nhân sự phụ trách kế toán và điều hành.
3. Chịu trách nhiệm pháp lý đối với việc thu-chi các khoản phí quản lý, phí gửi xe và việc sử dụng quỹ bảo trì 2% của tòa nhà theo Luật Nhà ở năm 2023.
4. Thanh toán phí bản quyền sử dụng dịch vụ phần mềm SaaS đúng kỳ hạn theo hợp đồng thương mại đã ký.

---

## 5. Quyền & Nghĩa Vụ Của Cư Dân & Khách Thuê

1. Sử dụng ứng dụng đúng mục đích sinh hoạt cư dân: theo dõi hóa đơn, thanh toán phí sinh hoạt đúng hạn, tạo phản ánh sự cố văn minh và đăng ký thủ tục khách thăm/bưu kiện.
2. Không thực hiện các hành vi phá hoại, tấn công từ chối dịch vụ (DDoS), đảo ngược mã nguồn (Reverse Engineering) hoặc khai thác lỗ hổng bảo mật.
3. Tự chịu trách nhiệm bảo mật thiết bị cá nhân, mã PIN nhận hàng và mã QR khách thăm được cấp.

---

## 6. Sở Hữu Trí Tuệ (Intellectual Property)
1. Toàn bộ mã nguồn, cấu trúc phần mềm, thuật toán định lượng rủi ro nợ xấu, giao diện đồ họa, nhãn hiệu thương mại "Vivona" thuộc quyền sở hữu trí tuệ độc quyền của Ban Dự Án Vivona.
2. Khách hàng được cấp quyền sử dụng phần mềm có thời hạn (Non-exclusive, non-transferable SaaS license) phù hợp với gói thuê bao và quy mô căn hộ đã đăng ký.
3. Mọi dữ liệu do Khách hàng tải lên hoặc phát sinh từ hoạt động quản lý vận hành tòa nhà thuộc quyền sở hữu vĩnh viễn của Khách hàng. Trong trường hợp chấm dứt hợp đồng, Vivona sẽ bàn giao đầy đủ toàn bộ tệp kết xuất dữ liệu (.SQL / .CSV / .JSON) trong vòng 30 ngày.

---

## 7. Giới Hạn Trách Nhiệm & Bất Khả Kháng
Vivona không chịu trách nhiệm bồi thường thiệt hại đối với các nguyên nhân ngoài tầm kiểm soát hợp lý:
- Sự cố ngắt kết nối mạng Internet viễn thông quốc gia hoặc nhà mạng cung cấp dịch vụ viễn thông tại Việt Nam.
- Các giao dịch chuyển khoản ngân hàng bị chậm trễ do lỗi hệ thống Napas/Ngân hàng thụ hưởng.
- Sự kiện bất khả kháng theo quy định của Bộ luật Dân sự (thiên tai, dịch bệnh, chiến tranh hoặc thay đổi chính sách pháp luật bắt buộc tạm dừng dịch vụ).

---

## 8. Luật Áp Dụng & Giải Quyết Tranh Chấp
1. Thỏa thuận này được điều chỉnh và giải thích theo pháp luật nước Cộng hòa Xã hội Chủ nghĩa Việt Nam.
2. Mọi tranh chấp phát sinh từ hoặc liên quan đến Thỏa thuận này trước hết sẽ được thương lượng hòa giải trên tinh thần hợp tác và bình đẳng.
3. Nếu không đạt được thỏa thuận hòa giải trong vòng 30 ngày kể từ ngày phát sinh tranh chấp, một trong các bên có quyền đưa vụ việc ra Trung tâm Trọng tài Quốc tế Việt Nam (VIAC) hoặc Tòa án nhân dân có thẩm quyền tại Thành phố Hà Nội để giải quyết theo luật định.

