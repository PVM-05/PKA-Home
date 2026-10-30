# Tài Liệu Thiết Kế Kỹ Thuật: Báo Cáo Tài Chính & Phân Tích Tuổi Nợ (C6)

> **Mục tiêu:** Xây dựng hệ thống Báo cáo Tài chính toàn diện và Phân tích Tuổi nợ (Debt Aging Analysis) cho Ban Quản Lý và Kế toán tòa nhà, hoàn tất trọn vẹn Giai đoạn C trong Lộ trình Thương mại hóa (Commercial Roadmap).
> **Ngày lập:** 30/10/2026
> **Trạng thái:** Đã phê duyệt (Approved)

---

## 1. Bối Cảnh & Mục Tiêu Nghiệp Vụ

### 1.1. Vấn đề thực tế của Ban Quản Lý chung cư
- Hiện tại, màn hình quản lý hóa đơn chỉ liệt kê đơn thuần các hóa đơn theo trạng thái (`paid`, `unpaid`, `overdue`), thiếu góc nhìn tổng thể về:
  1. **Hiệu suất thu hồi công nợ:** Chưa thấy được tỷ lệ thu hồi (%) theo từng kỳ, từng tòa (Block A, Block B), hoặc tầng.
  2. **Phân loại rủi ro công nợ (Debt Aging):** Chưa có cơ chế phân loại nợ theo tuổi nợ kế toán chuẩn quốc tế (0-30 ngày, 31-60 ngày, 61-90 ngày, và nợ xấu >90 ngày).
  3. **Hành động xử lý nợ đọng:** Chưa có công cụ lọc nhanh các căn hộ nợ nhiều nhất, nợ lâu nhất để gửi thông báo đôn đốc thu tiền kịp thời.
  4. **Báo cáo phục vụ hội nghị / kiểm toán:** Thiếu chức năng xuất bảng phân tích tuổi nợ ra file Excel chuẩn đối soát gửi Ban Quản Trị hoặc cơ quan thuế/kiểm toán.

### 1.2. Mục tiêu kỹ thuật
- **Hiệu năng cao:** Tính toán và gom nhóm trên máy chủ Supabase qua PostgreSQL RPC chuyên biệt (`get_financial_aging_report`), trả kết quả tức thời (< 100ms) ngay cả khi có hàng nghìn căn hộ và chục nghìn hóa đơn.
- **Dự phòng Offline/Lỗi mạng:** Client Dart có thuật toán fallback độc lập để tự tính toán nếu mất mạng.
- **Trải nghiệm UI/UX trực quan:** Biểu đồ phân bổ tỷ lệ `fl_chart`, thanh đo KPI tài chính, bộ lọc linh hoạt (Kỳ thu, Tòa nhà), danh sách căn hộ nợ đọng có nút nhắc nợ nhanh và nút chuyển sang Sổ cái căn hộ.
- **Xuất dữ liệu Excel đối soát:** Nâng cấp `ExcelExportHelper` xuất bảng phân tích tuổi nợ chi tiết kèm thông tin căn hộ, chủ hộ, các mức nợ và số ngày quá hạn.

---

## 2. Kiến Trúc Cơ Sở Dữ Liệu & RPC Backend

### 2.1. Migration SQL: `20261030_01_financial_aging_report_rpc.sql`
Tạo hàm RPC `get_financial_aging_report` với đặc tính `SECURITY DEFINER` và phân quyền RBAC:

```sql
CREATE OR REPLACE FUNCTION public.get_financial_aging_report(
    p_building_id UUID DEFAULT NULL,
    p_period TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_calling_user_id UUID;
    v_is_authorized BOOLEAN;
    v_result JSONB;
BEGIN
    -- 1. Xác thực phân quyền: Chỉ Admin, Ban Quản Lý hoặc Kế toán
    v_calling_user_id := auth.uid();
    
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = v_calling_user_id
          AND role IN ('admin', 'management', 'accountant')
    ) INTO v_is_authorized;

    IF NOT v_is_authorized THEN
        -- Kiểm tra quyền ủy quyền (role_delegations)
        SELECT EXISTS (
            SELECT 1 FROM public.role_delegations
            WHERE delegate_id = v_calling_user_id
              AND is_active = TRUE
              AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP)
              AND delegated_role IN ('admin', 'management', 'accountant')
        ) INTO v_is_authorized;
    END IF;

    IF NOT v_is_authorized THEN
        RAISE EXCEPTION 'Truy cập bị từ chối: Chỉ Ban Quản Lý hoặc Kế toán mới có quyền xem báo cáo tài chính';
    END IF;

    -- 2. Gom nhóm tính toán dữ liệu tài chính & tuổi nợ
    WITH filtered_invoices AS (
        SELECT 
            i.id,
            i.apartment_id,
            i.period,
            i.total_amount,
            i.status,
            i.due_date,
            a.code AS apartment_code,
            a.building_id,
            COALESCE(u.full_name, 'Chưa đăng ký') AS owner_name,
            COALESCE(u.phone, '') AS owner_phone,
            GREATEST(0, (CURRENT_DATE - i.due_date::date)) AS days_overdue
        FROM public.invoices i
        JOIN public.apartments a ON i.apartment_id = a.id
        LEFT JOIN public.residents_apartments ra ON ra.apartment_id = a.id AND ra.relation_role = 'owner'
        LEFT JOIN public.users u ON ra.user_id = u.id
        WHERE i.status != 'cancelled'
          AND (p_building_id IS NULL OR a.building_id = p_building_id)
          AND (p_period IS NULL OR i.period = p_period)
    ),
    summary_calc AS (
        SELECT
            COALESCE(SUM(total_amount), 0) AS total_billed,
            COALESCE(SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END), 0) AS actual_collected,
            COALESCE(SUM(CASE WHEN status IN ('unpaid', 'overdue') THEN total_amount ELSE 0 END), 0) AS total_outstanding,
            COUNT(id) AS total_invoice_count,
            COUNT(CASE WHEN status = 'paid' THEN 1 END) AS paid_invoice_count,
            COUNT(CASE WHEN status IN ('unpaid', 'overdue') THEN 1 END) AS unpaid_invoice_count
        FROM filtered_invoices
    ),
    aging_calc AS (
        SELECT
            -- 0-30 ngày
            COALESCE(SUM(CASE WHEN status IN ('unpaid', 'overdue') AND days_overdue BETWEEN 0 AND 30 THEN total_amount ELSE 0 END), 0) AS amount_0_30,
            COUNT(CASE WHEN status IN ('unpaid', 'overdue') AND days_overdue BETWEEN 0 AND 30 THEN 1 END) AS count_0_30,
            -- 31-60 ngày
            COALESCE(SUM(CASE WHEN status IN ('unpaid', 'overdue') AND days_overdue BETWEEN 31 AND 60 THEN total_amount ELSE 0 END), 0) AS amount_31_60,
            COUNT(CASE WHEN status IN ('unpaid', 'overdue') AND days_overdue BETWEEN 31 AND 60 THEN 1 END) AS count_31_60,
            -- 61-90 ngày
            COALESCE(SUM(CASE WHEN status IN ('unpaid', 'overdue') AND days_overdue BETWEEN 61 AND 90 THEN total_amount ELSE 0 END), 0) AS amount_61_90,
            COUNT(CASE WHEN status IN ('unpaid', 'overdue') AND days_overdue BETWEEN 61 AND 90 THEN 1 END) AS count_61_90,
            -- > 90 ngày
            COALESCE(SUM(CASE WHEN status IN ('unpaid', 'overdue') AND days_overdue > 90 THEN total_amount ELSE 0 END), 0) AS amount_over_90,
            COUNT(CASE WHEN status IN ('unpaid', 'overdue') AND days_overdue > 90 THEN 1 END) AS count_over_90
        FROM filtered_invoices
    ),
    debtors AS (
        SELECT
            apartment_id,
            apartment_code,
            owner_name,
            owner_phone,
            SUM(total_amount) AS total_debt,
            MAX(days_overdue) AS max_days_overdue,
            COUNT(id) AS unpaid_invoices_count,
            MIN(due_date) AS oldest_due_date,
            CASE 
                WHEN MAX(days_overdue) > 90 THEN 'over_90'
                WHEN MAX(days_overdue) >= 61 THEN '61_90'
                WHEN MAX(days_overdue) >= 31 THEN '31_60'
                ELSE '0_30'
            END AS risk_level
        FROM filtered_invoices
        WHERE status IN ('unpaid', 'overdue')
        GROUP BY apartment_id, apartment_code, owner_name, owner_phone
        ORDER BY total_debt DESC, max_days_overdue DESC
    ),
    collection_by_block AS (
        SELECT
            COALESCE(SUBSTRING(apartment_code FROM '^[A-Za-z]+'), 'Chung') AS block_name,
            COALESCE(SUM(total_amount), 0) AS block_billed,
            COALESCE(SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END), 0) AS block_collected,
            COALESCE(SUM(CASE WHEN status IN ('unpaid', 'overdue') THEN total_amount ELSE 0 END), 0) AS block_outstanding,
            CASE 
                WHEN SUM(total_amount) > 0 THEN ROUND((SUM(CASE WHEN status = 'paid' THEN total_amount ELSE 0 END)::numeric / SUM(total_amount)::numeric) * 100, 2)
                ELSE 0 
            END AS collection_rate
        FROM filtered_invoices
        GROUP BY COALESCE(SUBSTRING(apartment_code FROM '^[A-Za-z]+'), 'Chung')
        ORDER BY block_name
    )
    SELECT jsonb_build_object(
        'generated_at', CURRENT_TIMESTAMP,
        'filter_building_id', p_building_id,
        'filter_period', p_period,
        'summary', (
            SELECT jsonb_build_object(
                'total_billed', total_billed,
                'actual_collected', actual_collected,
                'total_outstanding', total_outstanding,
                'total_invoice_count', total_invoice_count,
                'paid_invoice_count', paid_invoice_count,
                'unpaid_invoice_count', unpaid_invoice_count,
                'collection_rate', CASE WHEN total_billed > 0 THEN ROUND((actual_collected::numeric / total_billed::numeric) * 100, 2) ELSE 0 END
            ) FROM summary_calc
        ),
        'aging_buckets', (
            SELECT jsonb_build_object(
                'bucket_0_30', jsonb_build_object('amount', amount_0_30, 'count', count_0_30),
                'bucket_31_60', jsonb_build_object('amount', amount_31_60, 'count', count_31_60),
                'bucket_61_90', jsonb_build_object('amount', amount_61_90, 'count', count_61_90),
                'bucket_over_90', jsonb_build_object('amount', amount_over_90, 'count', count_over_90)
            ) FROM aging_calc
        ),
        'collection_by_block', (
            SELECT COALESCE(jsonb_agg(to_jsonb(b)), '[]'::jsonb) FROM collection_by_block b
        ),
        'debtors', (
            SELECT COALESCE(jsonb_agg(to_jsonb(d)), '[]'::jsonb) FROM debtors d
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;
```

---

## 3. Tầng Dữ Liệu & Mô Hình Dart (Data Layer)

### 3.1. Các Models
Tạo file `lib/data/models/financial_aging_report_model.dart`:
- `FinancialAgingSummaryModel`:
  - `double totalBilled`
  - `double actualCollected`
  - `double totalOutstanding`
  - `int totalInvoiceCount`
  - `int paidInvoiceCount`
  - `int unpaidInvoiceCount`
  - `double collectionRate`
- `DebtAgingBucketModel`:
  - `double amount0To30`, `int count0To30`
  - `double amount31To60`, `int count31To60`
  - `double amount61To90`, `int count61To90`
  - `double amountOver90`, `int countOver90`
  - `double get totalDebt`
- `BlockCollectionRateModel`:
  - `String blockName`
  - `double billed`, `double collected`, `double outstanding`
  - `double collectionRate`
- `DebtorApartmentModel`:
  - `String apartmentId`, `String apartmentCode`
  - `String ownerName`, `String ownerPhone`
  - `double totalDebt`, `int maxDaysOverdue`
  - `int unpaidInvoicesCount`
  - `DateTime? oldestDueDate`
  - `String riskLevel` ('0_30', '31_60', '61_90', 'over_90')

### 3.2. Accounting Repository
Mở rộng `AccountingRepository`:
- Phương thức `Future<FinancialAgingReportModel> fetchAgingReport({String? buildingId, String? period})`:
  - Gọi RPC `get_financial_aging_report`.
  - Nếu gặp lỗi mạng hoặc RPC chưa sẵn sàng, tự động kích hoạt hàm fallback `_calculateAgingReportOffline(...)` từ dữ liệu invoices trong local cache.

### 3.3. Riverpod Providers
Tạo `lib/data/providers/financial_report_provider.dart`:
- State: `FinancialReportFilterState` (chứa `selectedPeriod`, `selectedBuildingId`, `selectedBucketFilter`).
- Provider: `financialAgingReportProvider`: Provider dạng `FutureProvider.family` hoặc `NotifierProvider` quản lý trạng thái tải dữ liệu, tự động làm mới khi đổi bộ lọc.

---

## 4. Tầng Giao Diện Người Dùng (UI/UX)

### 4.1. Màn hình `FinancialReportScreen`
Tạo tại `lib/features/management/screens/financial_report_screen.dart`:
1. **Header & Bộ lọc:**
   - Dropdown chọn Kỳ thu (Tháng gần nhất, Tất cả các kỳ).
   - Dropdown chọn Tòa nhà/Block.
   - Nút icon "Xuất Excel" màu xanh lá, gọi hàm xuất file và mở Share Sheet.
2. **Khu vực KPI Tổng quan:**
   - Hàng thẻ màu sắc trực quan (AppCard):
     - Xanh dương: Tổng phát hành.
     - Xanh lá: Thực thu (Đã thu).
     - Đỏ cam: Nợ đọng tồn đọng.
     - Tím/Teal: Tỷ lệ thu hồi (%).
3. **Khu vực Phân tích Tuổi nợ (Aging Visualization):**
   - Biểu đồ cột/thanh ngang trực quan sử dụng `fl_chart` hoặc bảng đo lường tiến trình 4 mức:
     - Xanh (0-30 ngày): Bình thường.
     - Vàng (31-60 ngày): Nhắc nhở lần 1.
     - Cam (61-90 ngày): Cảnh báo dịch vụ.
     - Đỏ (>90 ngày): Nợ xấu khó đòi.
   - Thống kê tỷ lệ thu hồi theo từng Block (Block A: 92%, Block B: 85%).
4. **Khu vực Danh sách Căn hộ Nợ đọng (Debtor List):**
   - Bộ lọc chip: `Tất cả`, `0-30 ngày`, `31-60 ngày`, `61-90 ngày`, `>90 ngày`.
   - Mỗi item hiển thị:
     - Mã căn (ví dụ `A0110`), tên chủ hộ, số điện thoại.
     - Badge mức độ nợ + số ngày quá hạn (ví dụ `Quá hạn 45 ngày`).
     - Tổng tiền nợ (định dạng `#,##0 đ`).
     - **Nút "Nhắc nợ"**: Mở hộp thoại xác nhận gửi thông báo cho cư dân.
     - **Nút "Sổ cái"**: Chuyển hướng trực tiếp sang `ApartmentLedgerScreen` của căn hộ đó.

### 4.2. Nâng cấp Xuất File Excel (`ExcelExportHelper`)
Mở rộng `lib/core/utils/excel_export_helper.dart`:
- Thêm phương thức:
  ```dart
  static Future<String?> exportAgingReport({
    required FinancialAgingReportModel report,
    String? period,
  });
  ```
- Tạo file Excel gồm 2 trang tính (Sheets):
  1. `Tổng Quan & Tuổi Nợ`: Bảng tóm tắt KPI tài chính, tỷ lệ thu hồi, số tiền từng xô nợ.
  2. `Danh Sách Căn Hộ Nợ`: Chi tiết từng dòng: Mã căn, Chủ hộ, SĐT, Số hóa đơn nợ, Ngày đến hạn cũ nhất, Số ngày quá hạn, Xô tuổi nợ, Tổng tiền nợ.

---

## 5. Kế Hoạch Kiểm Thử TDD & Verification

1. **Unit Test Models & Calculations**:
   - `test/data/models/financial_aging_report_model_test.dart`: Parse JSON từ RPC, tính toán các getters và tỷ lệ thu hồi.
2. **Unit Test Accounting Repository**:
   - `test/data/repositories/accounting_repository_aging_report_test.dart`: Kiểm tra gọi RPC thành công và kiểm tra cơ chế offline fallback.
3. **Unit Test Excel Export**:
   - `test/core/utils/excel_export_aging_report_test.dart`: Kiểm tra hàm sinh file Excel phân tích tuổi nợ không lỗi.
4. **Integration & UI Test**:
   - `test/features/management/screens/financial_report_screen_test.dart`: Kiểm tra giao diện hiển thị đúng 4 xô nợ, bộ lọc kỳ, danh sách căn hộ nợ và nút gửi nhắc nợ.
5. **Quality Gate**:
   - `dart analyze`: 0 issues.
   - `flutter test`: Toàn bộ tests vượt qua 100%.
