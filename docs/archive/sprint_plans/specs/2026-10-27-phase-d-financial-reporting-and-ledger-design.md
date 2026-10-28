# Đặc Tả Kỹ Thuật: Giai Đoạn D - Báo Cáo Tài Chính Chuyên Sâu, Sổ Quỹ Bảo Trì 2% (Live Ledger) & Chứng Từ Kế Toán Chuẩn

**Tác giả:** Antigravity Agent & PKA-Home Team  
**Ngày lập:** 2026-10-27  
**Trạng thái:** Bản thiết kế hoàn chỉnh (Ready for Implementation Plan)  
**Mục tiêu:** Nâng cấp hệ thống tài chính PKA-Home theo chuẩn quản lý tài sản chung cư chuyên nghiệp và Luật Nhà ở: Quản lý biến động thực tế (Live Ledger) của Quỹ bảo trì 2% theo từng tòa nhà, liên kết chặt chẽ dòng chi với phiếu nghiệm thu sửa chữa thiết bị (`equipment_maintenance_tasks`), cung cấp giao diện Sổ Quỹ chi tiết và phát hành Phiếu thu / Phiếu chi chuẩn Bộ Tài Chính (Mẫu 01-TT, 02-TT) có số tiền đọc bằng chữ tiếng Việt.

---

## 1. Bối Cảnh & Vấn Đề

1. **Quỹ bảo trì hiện là số liệu tĩnh (Static balance):** Bảng `maintenance_funds` hiện chỉ lưu số dư đơn lẻ mà chưa theo dõi được từng bút toán thu (từ thu quỹ bảo trì trong hóa đơn) và chi (cho các hạng mục thay thế, sửa chữa thang máy, máy bơm, PCCC). Theo Luật Nhà ở Việt Nam, quỹ bảo trì là tài khoản phong tỏa đặc thù, bắt buộc phải công khai minh bạch từng giao dịch với cư dân.
2. **Chưa liên kết dòng tiền với bảo trì kỹ thuật tòa nhà:** Khi hoàn thành bảo dưỡng thiết bị tòa nhà (`equipment_maintenance_tasks`) có phát sinh chi phí (`cost > 0`), Ban Quản lý chưa có cơ chế xuất phiếu chi nghiệm thu để khấu trừ trực tiếp vào sổ quỹ.
3. **Thiếu chứng từ kế toán chuẩn Việt Nam:** Ban Quản lý và cư dân cần chứng từ kế toán chuẩn mực (Phiếu thu 01-TT, Phiếu chi 02-TT) ghi rõ ngày giờ, lý do, người nộp/nhận, số tiền viết bằng chữ tiếng Việt và các chức danh ký duyệt.

---

## 2. Thiết Kế Cơ Sở Dữ Liệu (Supabase / PostgreSQL)

### 2.1. Cập Nhật Bảng `maintenance_funds`
Bổ sung `building_id` để hỗ trợ đa tòa nhà:
```sql
ALTER TABLE public.maintenance_funds
    ADD COLUMN IF NOT EXISTS building_id UUID REFERENCES public.buildings(id) ON DELETE CASCADE;
```

### 2.2. Tạo Bảng Sổ Quỹ Biến Động `maintenance_fund_transactions`
```sql
CREATE TABLE IF NOT EXISTS public.maintenance_fund_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    fund_id UUID NOT NULL REFERENCES public.maintenance_funds(id) ON DELETE CASCADE,
    voucher_number VARCHAR(30) NOT NULL, -- PT-YYYYMM-XXXXX hoặc PC-YYYYMM-XXXXX
    transaction_type VARCHAR(20) NOT NULL, -- 'INCOME' (Thu) hoặc 'EXPENSE' (Chi)
    category VARCHAR(50) NOT NULL, -- 'MAINTENANCE_FEE', 'EQUIPMENT_REPAIR', 'BANK_INTEREST', 'OTHER'
    amount NUMERIC(15,2) NOT NULL CHECK (amount > 0),
    balance_after NUMERIC(15,2) NOT NULL,
    reference_type VARCHAR(30), -- 'INVOICE', 'EQUIPMENT_TASK', 'BANK_INTEREST', 'MANUAL'
    reference_id UUID,
    recipient_or_payer TEXT NOT NULL,
    description TEXT NOT NULL,
    created_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mft_building ON public.maintenance_fund_transactions(building_id);
CREATE INDEX IF NOT EXISTS idx_mft_voucher ON public.maintenance_fund_transactions(voucher_number);
CREATE INDEX IF NOT EXISTS idx_mft_created_at ON public.maintenance_fund_transactions(created_at DESC);
```

### 2.3. RLS Policies Bảo Mật Sổ Quỹ
- Cư dân: Quyền `SELECT` các giao dịch thuộc tòa nhà của căn hộ mình để giám sát tính minh bạch theo Luật Nhà ở.
- Ban Quản lý / Kế toán / Admin: Quyền `SELECT` và `INSERT` thông qua RPC bảo vệ.

### 2.4. RPC Ghi Sổ Quỹ & Đồng Bộ Số Dư An Toàn (ACID Safe)
```sql
CREATE OR REPLACE FUNCTION public.record_maintenance_fund_transaction(
    p_building_id UUID,
    p_transaction_type VARCHAR(20),
    p_category VARCHAR(50),
    p_amount NUMERIC(15,2),
    p_description TEXT,
    p_recipient_or_payer TEXT,
    p_reference_type VARCHAR(30) DEFAULT NULL,
    p_reference_id UUID DEFAULT NULL,
    p_created_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_fund_id UUID;
    v_current_balance NUMERIC(15,2);
    v_new_balance NUMERIC(15,2);
    v_period TEXT;
    v_prefix TEXT;
    v_seq INT;
    v_voucher_number TEXT;
    v_tx_id UUID;
BEGIN
    -- 1. Tìm hoặc tạo bản ghi quỹ bảo trì cho tòa nhà
    SELECT id, total_balance INTO v_fund_id, v_current_balance
    FROM public.maintenance_funds
    WHERE building_id = p_building_id
    LIMIT 1
    FOR UPDATE;

    IF v_fund_id IS NULL THEN
        -- Lấy bản ghi default nếu chưa gắn building_id
        SELECT id, total_balance INTO v_fund_id, v_current_balance
        FROM public.maintenance_funds
        WHERE building_id IS NULL
        LIMIT 1
        FOR UPDATE;
        
        IF v_fund_id IS NOT NULL THEN
            UPDATE public.maintenance_funds SET building_id = p_building_id WHERE id = v_fund_id;
        ELSE
            INSERT INTO public.maintenance_funds (building_id, total_balance)
            VALUES (p_building_id, 0.00)
            RETURNING id, total_balance INTO v_fund_id, v_current_balance;
        END IF;
    END IF;

    -- 2. Tính số dư mới
    IF p_transaction_type = 'INCOME' THEN
        v_new_balance := v_current_balance + p_amount;
        v_prefix := 'PT-';
    ELSIF p_transaction_type = 'EXPENSE' THEN
        IF v_current_balance < p_amount THEN
            RAISE EXCEPTION 'Số dư quỹ bảo trì không đủ để chi (Số dư hiện tại: %, Cần chi: %)', v_current_balance, p_amount;
        END IF;
        v_new_balance := v_current_balance - p_amount;
        v_prefix := 'PC-';
    ELSE
        RAISE EXCEPTION 'Loại giao dịch không hợp lệ: %', p_transaction_type;
    END IF;

    -- 3. Sinh số chứng từ kế toán
    SELECT to_char(CURRENT_DATE, 'YYYYMM') INTO v_period;
    SELECT COALESCE(COUNT(*), 0) + 1 INTO v_seq
    FROM public.maintenance_fund_transactions
    WHERE voucher_number LIKE v_prefix || v_period || '-%';

    v_voucher_number := v_prefix || v_period || '-' || LPAD(v_seq::text, 5, '0');

    -- 4. Cập nhật số dư bảng chính
    UPDATE public.maintenance_funds
    SET total_balance = v_new_balance,
        updated_at = now()
    WHERE id = v_fund_id;

    -- 5. Ghi sổ giao dịch
    INSERT INTO public.maintenance_fund_transactions (
        building_id,
        fund_id,
        voucher_number,
        transaction_type,
        category,
        amount,
        balance_after,
        reference_type,
        reference_id,
        recipient_or_payer,
        description,
        created_by,
        created_at
    ) VALUES (
        p_building_id,
        v_fund_id,
        v_voucher_number,
        p_transaction_type,
        p_category,
        p_amount,
        v_new_balance,
        p_reference_type,
        p_reference_id,
        p_recipient_or_payer,
        p_description,
        p_created_by,
        now()
    ) RETURNING id INTO v_tx_id;

    RETURN jsonb_build_object(
        'success', true,
        'transaction_id', v_tx_id,
        'voucher_number', v_voucher_number,
        'new_balance', v_new_balance
    );
END;
$$;
```

---

## 3. Kiến Trúc Tầng Logic & Dữ Liệu (Data Layer)

### 3.1. Models
- `MaintenanceFundTransactionModel`:
  - `id`, `buildingId`, `fundId`, `voucherNumber`, `transactionType` (isIncome / isExpense), `category`, `amount`, `balanceAfter`, `referenceType`, `referenceId`, `recipientOrPayer`, `description`, `createdBy`, `createdAt`.
  - Helper getters: `categoryDisplayName`, `isIncome`, `isExpense`, `typeDisplayName`.

### 3.2. Repositories & Providers
- `MaintenanceFundRepository`:
  - `fetchFundByBuilding(String? buildingId)`
  - `fetchTransactions({String? buildingId, String? transactionType, DateTime? fromDate, DateTime? toDate})`
  - `recordTransaction(...)` (gọi RPC `record_maintenance_fund_transaction`)
- Providers:
  - `maintenanceFundLedgerProvider` (`FutureProvider.autoDispose.family<List<MaintenanceFundTransactionModel>, ...>`)
  - `recordFundTransactionProvider`

---

## 4. Giao Diện Người Dùng & Chứng Từ Kế Toán (UI/UX)

### 4.1. Màn hình Sổ Quỹ Bảo Trì (`MaintenanceFundLedgerScreen`)
- Đường dẫn: `/management/maintenance-fund-ledger`
- Nút truy cập nhanh từ `MaintenanceFundCard` trên Dashboard BQL.
- Header tổng quan:
  - Thẻ số dư khả dụng (Gradient màu nổi bật, số tiền định dạng VNĐ).
  - Thống kê 2 cột: **Tổng thu lũy kế** (Màu xanh `+`) & **Tổng chi nghiệm thu** (Màu đỏ `-`).
- Thanh công cụ (Toolbar):
  - Lọc theo loại: Tất cả / Phiếu thu (INCOME) / Phiếu chi (EXPENSE).
  - Nút **"Lập phiếu thu/chi"** nhanh cho Ban Quản lý.
- Danh sách sổ cái:
  - Hiển thị từng dòng chứng từ kế toán rõ ràng: Số phiếu (`PT-...` / `PC-...`), ngày thực hiện, lý do, số tiền và số dư tức thời sau giao dịch.
  - Bấm vào mở `AccountingVoucherDialog` để xem bản in chứng từ kế toán.

### 4.2. Mẫu Chứng Từ Kế Toán Chuẩn (Mẫu 01-TT & Mẫu 02-TT)
- Component `AccountingVoucherDialog`:
  - Tiêu đề: **PHIẾU THU** (Mẫu 01-TT theo TT 200/2014/TT-BTC) hoặc **PHIẾU CHI** (Mẫu 02-TT).
  - Tên Đơn vị / Tòa nhà, Ban Quản trị.
  - Số chứng từ, ngày tháng lập phiếu.
  - Người nộp / nhận tiền, địa chỉ/căn hộ.
  - Lý do thu / chi chi tiết.
  - Số tiền bằng số (VNĐ) và **Số tiền viết bằng chữ** (tiếng Việt chuẩn mực).
  - Bảng 4 ô ký tên: Giám đốc BQL, Kế toán trưởng, Người lập phiếu, Người nộp/nhận tiền.
  - Nút thao tác: "In / Chia sẻ chứng từ", "Đóng".

### 4.3. Tích Hợp Nghiệm Thu Bảo Trì Thiết Bị (`EquipmentDetailScreen` / `EquipmentMaintenanceTask`)
- Khi một công việc bảo trì hoàn thành (`status == 'completed'`) có `cost > 0`:
- Hiển thị nút **"Chi trả từ Quỹ bảo trì"** (nếu chưa lập phiếu chi).
- Khi bấm, tự động điền form phiếu chi với lý do: `Bảo dưỡng thiết bị: <Tên thiết bị> (<Mã thiết bị>) - Đơn vị: <vendorName>`, số tiền `cost`, và ghi vào sổ quỹ sau khi xác nhận.

---

## 5. Quy Chuẩn Đảm Bảo (Quality & Verification Gates)

- Tuân thủ 100% tiếng Việt tự nhiên theo `design-rules.md`, không dùng từ Anh-Việt lẫn lộn.
- Viết Unit & Integration Test đầy đủ cho Model, Repository và Screen trước khi hoàn tất.
- `flutter analyze` 0 lỗi linter, toàn bộ test suite hiện có (455+ test) giữ nguyên tính tương thích và pass 100%.
