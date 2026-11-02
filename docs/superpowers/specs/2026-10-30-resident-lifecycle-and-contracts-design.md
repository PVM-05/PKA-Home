# Đặc Tả Thiết Kế: Vòng Đời Cư Dân, Hợp Đồng Thuê & Mã Mời Kích Hoạt Tự Phục Vụ (D1)

- **Giai đoạn:** D1 (trong `COMMERCIAL_PRODUCT_ROADMAP.md`)
- **Mục tiêu:** 
  1. Chuyển đổi liên kết cư dân - căn hộ từ quan hệ tĩnh sang vòng đời có hiệu lực theo thời gian (`start_date`, `end_date`, `status: active/expired/terminated`).
  2. Quản lý thông tin hợp đồng thuê: mã hợp đồng, tiền cọc giữ chỗ, ghi chú bàn giao, và kết thúc quan hệ lưu vết (`terminate_resident_stay`) không làm mất dữ liệu hóa đơn/thanh toán cũ.
  3. Cơ chế mời thành viên / người thuê tự phục vụ qua mã Token và QR Link (`apartment_invitations`): BQL hoặc chủ hộ sinh mã mời có hạn, người dùng quét mã/nhập mã để kích hoạt liên kết căn hộ tức thì mà không cần BQL tạo tài khoản thủ công với mật khẩu mặc định.

---

## 1. Kiến Trúc Cơ Sở Dữ Liệu (PostgreSQL / Supabase)

### 1.1. Nâng cấp bảng `residents_apartments`
Bổ sung các cột phục vụ quản lý hợp đồng thuê và vòng đời lưu vết:
```sql
ALTER TABLE public.residents_apartments
    ADD COLUMN IF NOT EXISTS start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    ADD COLUMN IF NOT EXISTS end_date DATE,
    ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expired', 'terminated')),
    ADD COLUMN IF NOT EXISTS deposit_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS contract_number VARCHAR(50),
    ADD COLUMN IF NOT EXISTS note TEXT;
```

### 1.2. Bảng `apartment_invitations`
Bảng quản lý mã mời tham gia căn hộ:
```sql
CREATE TABLE IF NOT EXISTS public.apartment_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES public.users(id),
    invite_code VARCHAR(16) NOT NULL UNIQUE,
    target_role public.apartment_relation_role NOT NULL DEFAULT 'member',
    max_uses INT NOT NULL DEFAULT 1,
    used_count INT NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked', 'exhausted', 'expired')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_apt_invites_code ON public.apartment_invitations(invite_code);
CREATE INDEX IF NOT EXISTS idx_apt_invites_apt ON public.apartment_invitations(apartment_id);
```

### 1.3. Các hàm thủ tục lưu trữ (RPCs)
1. **`create_apartment_invitation(p_apartment_id, p_target_role, p_expires_hours, p_max_uses)`**:
   - Sinh mã ngẫu nhiên 8 ký tự định dạng `PKA-XXXXXX`.
   - Thiết lập thời gian hết hạn (mặc định 48h).
   - Kiểm tra quyền: Chỉ Admin/BQL hoặc Chủ hộ (`owner`) của căn hộ đó mới được tạo mã mời.
2. **`accept_apartment_invitation(p_invite_code)`**:
   - Xác thực mã mời: kiểm tra trạng thái `active`, chưa hết hạn (`expires_at > now()`), `used_count < max_uses`.
   - Tạo hoặc cập nhật bản ghi trong `residents_apartments` với `status = 'active'`, `start_date = CURRENT_DATE`.
   - Tăng `used_count`. Nếu `used_count >= max_uses` thì cập nhật trạng thái `exhausted`.
   - Ghi nhật ký kiểm toán hệ thống (`audit_logs`).
3. **`terminate_resident_stay(p_user_id, p_apartment_id, p_termination_date, p_note)`**:
   - Chốt ngày kết thúc quan hệ lưu trú (`end_date = p_termination_date`).
   - Cập nhật `status = 'terminated'`.
   - Nếu căn hộ không còn cư dân nào ở trạng thái `active`, cập nhật `apartments.is_empty = true`.
   - Bảo toàn 100% dữ liệu lịch sử hóa đơn, thanh toán, sự cố của cư dân gắn với căn hộ.

---

## 2. Thiết Kế Tầng Dữ Liệu (Dart Data Layer)

- **Models:**
  - `ResidentLeaseContractModel`: đại diện cho hợp đồng/quan hệ lưu trú của cư dân tại căn hộ (`id`, `userId`, `apartmentId`, `residentName`, `phone`, `relationRole`, `startDate`, `endDate`, `status`, `depositAmount`, `contractNumber`, `note`).
  - `ApartmentInvitationModel`: đại diện cho lời mời (`id`, `apartmentId`, `apartmentCode`, `inviteCode`, `targetRole`, `maxUses`, `usedCount`, `expiresAt`, `status`, `isExpired`).
- **Repository:**
  - `ResidentLifecycleRepository`:
    - `fetchApartmentContracts(String apartmentId)`
    - `fetchApartmentInvitations(String apartmentId)`
    - `createInvitation({required String apartmentId, required String targetRole, int expiresHours = 48})`
    - `acceptInvitation(String inviteCode)`
    - `terminateResidentStay({required String userId, required String apartmentId, DateTime? terminationDate, String? note})`
- **Providers:**
  - `apartmentContractsProvider.family<List<ResidentLeaseContractModel>, String>`
  - `apartmentInvitationsProvider.family<List<ApartmentInvitationModel>, String>`
  - `residentLifecycleRepositoryProvider`

---

## 3. Thiết Kế Giao Diện Người Dùng (UI/UX)

- **Màn hình/Hộp thoại Quản lý Hợp đồng & Cọc (`ApartmentContractSheet`):**
  - Hiển thị danh sách cư dân hiện tại và cư dân cũ đã kết thúc lưu trú.
  - Thông tin hợp đồng: Số hợp đồng, Tiền cọc (format VNĐ), Ngày bắt đầu - Ngày kết thúc.
  - Nút **"Kết thúc lưu trú"**: Mở hộp thoại xác nhận chốt ngày dọn đi, ghi chú hiện trạng bàn giao và hoàn cọc.
- **Hộp thoại Tạo & Chia sẻ Mã mời (`CreateApartmentInvitationSheet`):**
  - Chọn vai trò người được mời: Người thuê (`tenant`) hoặc Thành viên ở cùng (`member`).
  - Chọn thời hạn: 24 giờ, 48 giờ, 7 ngày.
  - Hiển thị Mã mời to rõ, mã QR Code động và nút **"Sao chép liên kết mời"**.
- **Hộp thoại Tham Gia Căn Hộ Qua Mã Mời (`AcceptInvitationDialog`):**
  - Nằm tại màn hình Yêu cầu liên kết hoặc menu Cư dân.
  - Ô nhập mã mời 8 ký tự với tự động viết hoa (Auto-capitalize).
  - Nút **"Kích hoạt vào căn hộ"**: Tự động liên kết và thông báo chúc mừng gia nhập thành công.

---

## 4. Kế Hoạch Kiểm Thử Tự Động (TDD)

1. Migration test: Kiểm tra schema SQL, trigger, và RPCs.
2. Unit tests cho models `ResidentLeaseContractModel`, `ApartmentInvitationModel`.
3. Unit tests cho `ResidentLifecycleRepository`.
4. Widget tests cho `CreateApartmentInvitationSheet` và `ApartmentContractSheet`.
5. Integration test cho luồng trọn vẹn: Tạo mã mời $\rightarrow$ Cư dân kích hoạt $\rightarrow$ BQL kết thúc lưu trú có lưu vết.
