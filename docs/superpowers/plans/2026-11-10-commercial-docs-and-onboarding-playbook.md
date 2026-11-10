# Kế Hoạch Triển Khai: Bộ Tài Liệu Thương Mại B2B SaaS, Sổ Tay Onboarding & Nghiệm Thu QA/UAT

- **Mục tiêu:**
  1. Nâng cấp toàn diện `docs/TESTING_AND_QA.md` theo tiêu chuẩn kiểm thử chất lượng thương mại B2B SaaS, tích hợp 368 test files, ma trận CI/CD Quality Gate và 12 kịch bản UAT thực địa.
  2. Xây dựng Sổ Tay Triển Khai & Onboarding Khách Hàng (`docs/DEPLOYMENT_PLAYBOOK.md`) theo mục 6 của `document-plan.md`.
  3. Xây dựng Hồ Sơ Đề Xuất Giải Pháp & Pitch Deck Thương Mại (`docs/PITCH_DECK_PROPOSAL.md`) theo mục 7 của `document-plan.md`.
  4. Đảm bảo 100% tuân thủ pháp luật Việt Nam (Luật Nhà ở 2023, Luật Bảo vệ dữ liệu cá nhân 2026, Nghị định hóa đơn 123/2020), 0 emoji, tiếng Việt chuẩn mực SaaS B2B.
- **Nhánh thực hiện:** `main` (commit trực tiếp theo quy định dự án).

---

## Danh Sách Nhiệm Vụ Chi Tiết

### Task 1: Nâng Cấp Toàn Diện Bộ Quy Chuẩn QA & UAT Nghiệm Thu Thực Địa
**Tệp:** `docs/TESTING_AND_QA.md`
- [x] **Step 1:** Cập nhật số liệu test suite thực tế: 368 tệp kiểm thử tự động, 5 tầng kiểm thử chuyên biệt.
- [x] **Step 2:** Chi tiết hóa ma trận bảo mật RLS, bảo vệ nguyên tử tài chính VietQR, kiểm thử phản hồi co giãn Anti-RenderFlex.
- [x] **Step 3:** Thiết lập 12 kịch bản UAT (User Acceptance Testing) thực tế tại tòa nhà cho 6 đối tượng (BQL, Kế toán, Kỹ thuật, Lễ tân, Cư dân, Khách thuê).
- [x] **Step 4:** Quy định ma trận cổng chất lượng CI/CD Quality Gates & Tiêu chí dừng kiểm thử (Pass criteria).
- [x] **Step 5:** Commit thay đổi vào `main`: `docs: nang cap quy chuan qa va kich ban nghiem thu uat b2b saas`.

---

### Task 2: Xây Dựng Sổ Tay Triển Khai & Onboarding Khách Hàng (Deployment Playbook)
**Tệp:** `docs/DEPLOYMENT_PLAYBOOK.md`
- [x] **Step 1:** Soạn thảo quy trình khởi tạo Tổ chức / Đơn vị vận hành và Tòa nhà mới (Tenant Isolation).
- [x] **Step 2:** Cung cấp thông số kỹ thuật bộ mẫu dữ liệu Excel/CSV nhập khẩu căn hộ, cư dân, xe và công nợ đầu kỳ.
- [x] **Step 3:** Quy trình cấp phát tài khoản, phân quyền RBAC và bàn giao bí mật bảo mật 2FA/TOTP.
- [x] **Step 4:** Checklist tiến độ Go-Live 7 ngày (T-7 đến T-0) cho ban quản lý tòa nhà mới.
- [x] **Step 5:** Commit thay đổi vào `main`: `docs: xay dung so tay trien khai onboarding khach hang deployment playbook`.

---

### Task 3: Xây Dựng Hồ Sơ Đề Xuất Giải Pháp & Pitch Deck Thương Mại
**Tệp:** `docs/PITCH_DECK_PROPOSAL.md`
- [x] **Step 1:** Tuyên bố giá trị sản phẩm PropTech PKA-Home B2B SaaS và giải quyết triệt để nỗi đau vận hành bất động sản.
- [x] **Step 2:** Ma trận so sánh tính năng và năng lực cạnh tranh với các giải pháp trên thị trường.
- [x] **Step 3:** Bảng giá gói thương mại phân tầng theo quy mô căn hộ (Khởi nghiệp, Tiêu chuẩn, Doanh nghiệp lớn).
- [x] **Step 4:** Bảng tính toán hoàn vốn đầu tư ROI và lợi ích kinh tế thực tế cho Đơn vị Quản lý Vận hành.
- [x] **Step 5:** Commit thay đổi vào `main`: `docs: xay dung ho so de xuat giai phap va pitch deck thuong mai b2b`.

---

### Task 4: Cập Nhật Tri Thức Đồ Thị & Hoàn Tất Kế Hoạch
- [x] **Step 1:** Cập nhật đồ thị tri thức kiến trúc: `graphify update .`.
- [x] **Step 2:** Đánh dấu hoàn tất toàn bộ các mục tiêu trong tài liệu kế hoạch.
- [x] **Step 3:** Commit vào `main`: `docs: hoan thanh tron ven bo ho so thuong mai b2b saas`.
