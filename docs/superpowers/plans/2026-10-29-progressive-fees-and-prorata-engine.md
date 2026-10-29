# Kế Hoạch Triển Khai: Engine Tính Phí Đa Dạng, Bậc Thang EVN, Phí Xe Pro-rata & Phạt Trễ Hạn (C2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xây dựng engine tính phí lũy tiến động (`fee_tier_policies`), tính tiền điện 6 bậc chuẩn EVN, tính tiền nước sinh hoạt theo định mức nhân khẩu, phân bổ phí gửi xe theo ngày lẻ thực tế (pro-rata), tự động tính lãi phạt trễ hạn sau 3 ngày ân hạn, cùng giao diện phân rã minh bạch 100% tiếng Việt.

**Architecture:** Sử dụng PostgreSQL Supabase Migration 11 với bảng cấu hình chính sách biểu giá JSONB, các RPCs tính toán phân rã toán học chuẩn xác chống sai số; phía Client Flutter sử dụng Utility Calculator, Riverpod providers và các Widget phân rã chi tiết từng bậc.

**Tech Stack:** Flutter 3.x, Dart 3.x, Supabase (PostgreSQL, RLS, RPCs), flutter_riverpod, intl.

## Global Constraints
- Commit trực tiếp vào nhánh `main` (không tạo branch phụ/worktree).
- Đặt tên file `snake_case`, class `UpperCamelCase`, provider `lowerCamelCase + Provider`.
- Định dạng mã căn hộ chuẩn `A0110` / `a0110`.
- Ngôn ngữ UI: 100% tiếng Việt chuẩn mực, không hardcode tiếng Anh lai tạp.
- Định dạng thời gian: `dd/MM/yyyy` cho ngày, `dd/MM/yyyy HH:mm` cho thời gian chi tiết, `Tháng MM/yyyy` cho kỳ kế toán.
- Định dạng tiền tệ: `#,##0 đ` (VD: `1.250.000 đ`).

---

### Task 1: Migration Cơ Sở Dữ Liệu (Bảng fee_tier_policies, Seeds & 4 RPCs Tính Toán)

**Files:**
- Create: `supabase/migrations/20261029_04_progressive_fees_and_prorata_engine.sql`
- Test: `test/integration/progressive_fees_migration_test.dart`

**Interfaces:**
- Consumes: `buildings(id)`, `invoices(id)`
- Produces:
  - Bảng: `public.fee_tier_policies`
  - RPCs:
    - `calculate_progressive_electricity_fee(p_consumption NUMERIC, p_building_id UUID)`
    - `calculate_quota_water_fee(p_consumption NUMERIC, p_resident_count INT, p_building_id UUID)`
    - `calculate_prorated_vehicle_fee(p_monthly_rate NUMERIC, p_start_date DATE, p_period VARCHAR(7))`
    - `calculate_late_payment_penalty(p_invoice_id UUID, p_as_of_date DATE)`

- [ ] **Step 1: Viết test kiểm tra migration**
Viết `test/integration/progressive_fees_migration_test.dart` kiểm tra file migration tồn tại, chứa định nghĩa bảng `fee_tier_policies`, seed dữ liệu 6 bậc EVN & định mức nước, và 4 RPCs tính toán.

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Chạy `flutter test test/integration/progressive_fees_migration_test.dart` và xác nhận thất bại do chưa có file migration.

- [ ] **Step 3: Viết migration SQL**
Tạo file `supabase/migrations/20261029_04_progressive_fees_and_prorata_engine.sql`:
- Bảng `fee_tier_policies` (id, building_id, policy_type, name, calculation_method, tiers, effective_from, effective_to, is_active, created_at, updated_at).
- RLS read cho mọi authenticated users, RLS manage cho BQL.
- Seed biểu giá 6 bậc EVN mặc định, nước định mức 4 m³/người/tháng, lãi phạt trễ hạn 0.05%/ngày (ân hạn 3 ngày).
- Triển khai 4 RPCs tính toán với thuật toán toán học chuẩn xác, trả về JSON phân rã chi tiết từng bậc.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Chạy `flutter test test/integration/progressive_fees_migration_test.dart` đảm bảo pass 100%.

- [ ] **Step 5: Commit vào git**
```bash
git add supabase/migrations/20261029_04_progressive_fees_and_prorata_engine.sql test/integration/progressive_fees_migration_test.dart
git commit -m "feat(db): migration engine tinh phi bac thang evn pro rata va phat tre han C2"
```

---

### Task 2: Models & Calculation Helpers (Dart Engine)

**Files:**
- Create:
  - `lib/data/models/fee_tier_policy_model.dart`
  - `lib/data/models/tiered_calculation_result_model.dart`
  - `lib/core/utils/utility_fee_calculator.dart`
- Test:
  - `test/data/models/fee_tier_policy_model_test.dart`
  - `test/core/utils/utility_fee_calculator_test.dart`

**Interfaces:**
- Consumes: JSON từ Supabase RPCs và queries
- Produces:
  - `FeeTierPolicyModel` (id, buildingId, policyType, name, calculationMethod, tiers, effectiveFrom, isActive)
  - `TieredCalculationResultModel` (consumption, totalAmount, formattedTotalAmount, breakdown: List<TierItemBreakdown>)
  - `ProratedFeeResultModel` (monthlyRate, period, daysInMonth, daysUsed, isProrated, totalAmount, formattedTotalAmount)
  - `LatePenaltyResultModel` (invoiceId, dueDate, asOfDate, daysOverdue, inGracePeriod, penaltyRatePerDay, penaltyAmount, formattedPenaltyAmount)
  - `UtilityFeeCalculator`: Các hàm tính toán on-device dự phòng kiểm tra ngoại tuyến.

- [ ] **Step 1: Viết test cho Models và UtilityFeeCalculator**
Viết unit test cho serialization, tính toán bậc thang điện EVN, định mức nước, pro-rata xe, và lãi phạt trễ hạn.

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Chạy `flutter test test/data/models/fee_tier_policy_model_test.dart test/core/utils/utility_fee_calculator_test.dart` xác nhận FAIL.

- [ ] **Step 3: Triển khai Models & Calculator**
Tạo 3 file tương ứng, áp dụng NumberFormat và DateFormat chuẩn Việt Nam.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Chạy lại các test, xác nhận PASS 100%.

- [ ] **Step 5: Commit vào git**
```bash
git add lib/data/models/fee_tier_policy_model.dart lib/data/models/tiered_calculation_result_model.dart lib/core/utils/utility_fee_calculator.dart test/data/models/fee_tier_policy_model_test.dart test/core/utils/utility_fee_calculator_test.dart
git commit -m "feat(models): bo sung models va utility calculator cho phi bac thang va pro rata C2"
```

---

### Task 3: Repository & Riverpod Providers

**Files:**
- Create:
  - `lib/data/repositories/fee_policy_repository.dart`
  - `lib/data/providers/fee_policy_providers.dart`
- Test:
  - `test/data/repositories/fee_policy_repository_test.dart`
  - `test/data/providers/fee_policy_providers_test.dart`

**Interfaces:**
- Consumes: `SupabaseClient`, `FeeTierPolicyModel`, `TieredCalculationResultModel`
- Produces:
  - `FeePolicyRepository`:
    - `fetchPolicies(String? buildingId)`
    - `calculateElectricityFee(double consumption, {String? buildingId})`
    - `calculateWaterFee(double consumption, {int residentCount, String? buildingId})`
    - `calculateProratedParkingFee({required double monthlyRate, required DateTime startDate, required String period})`
    - `calculateLatePenalty(String invoiceId)`
  - Providers:
    - `feePolicyRepositoryProvider`
    - `buildingFeePoliciesProvider(buildingId)`
    - `calculatedLatePenaltyProvider(invoiceId)`

- [ ] **Step 1: Viết unit tests cho Repository & Providers**
Tạo mock client, kiểm thử gọi đúng RPCs và queries.

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Chạy `flutter test test/data/repositories/fee_policy_repository_test.dart test/data/providers/fee_policy_providers_test.dart` xác nhận FAIL.

- [ ] **Step 3: Triển khai Repository & Providers**
Viết `FeePolicyRepository` và `fee_policy_providers.dart`.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Chạy lại test, xác nhận PASS 100%.

- [ ] **Step 5: Commit vào git**
```bash
git add lib/data/repositories/fee_policy_repository.dart lib/data/providers/fee_policy_providers.dart test/data/repositories/fee_policy_repository_test.dart test/data/providers/fee_policy_providers_test.dart
git commit -m "feat(repo): them fee_policy_repository va providers cho phi bac thang C2"
```

---

### Task 4: UI Hiển Thị Phân Rã Bậc Thang Trên Hóa Đơn Cư Dân

**Files:**
- Create:
  - `lib/features/resident/widgets/tiered_fee_breakdown_dialog.dart`
- Modify:
  - `lib/features/resident/screens/resident_invoice_detail_screen.dart`
- Test:
  - `test/features/resident/resident_tiered_fee_ui_test.dart`

**Interfaces:**
- Consumes: `TieredCalculationResultModel`, `UtilityFeeCalculator`
- Produces:
  - `TieredFeeBreakdownDialog`: Modal hiển thị bảng phân rã từng bậc (Bậc 1, 2, 3... kWh/m3 x đơn giá = thành tiền).
  - Cập nhật `_buildFeeItemCard` trong `ResidentInvoiceDetailScreen`: Nếu là Tiền điện hoặc Tiền nước, hiển thị nút/chip "Xem chi tiết bậc thang" mở dialog; hiển thị banner cảnh báo trễ hạn kèm tiền phạt nếu quá hạn.

- [ ] **Step 1: Viết widget test cho hiển thị bậc thang và cảnh báo trễ hạn**
Kiểm thử nút "Xem chi tiết bậc thang" xuất hiện trên item điện/nước và mở dialog hiển thị các bậc tiêu thụ.

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Chạy `flutter test test/features/resident/resident_tiered_fee_ui_test.dart` xác nhận FAIL.

- [ ] **Step 3: Triển khai Widget & Cập nhật màn hình**
Viết `TieredFeeBreakdownDialog` và cập nhật `ResidentInvoiceDetailScreen`, áp dụng Material 3, font Google Fonts, word-wrap an toàn.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Chạy widget test, xác nhận PASS 100%.

- [ ] **Step 5: Commit vào git**
```bash
git add lib/features/resident/widgets/tiered_fee_breakdown_dialog.dart lib/features/resident/screens/resident_invoice_detail_screen.dart test/features/resident/resident_tiered_fee_ui_test.dart
git commit -m "feat(ui): them dialog phan ra bac thang dien nuoc tren hoa don cu dan C2"
```

---

### Task 5: UI Quản Lý Biểu Giá & Công Cụ Tính Nhanh Cho Ban Quản Lý

**Files:**
- Create:
  - `lib/features/management/screens/fee_policy_management_screen.dart`
  - `lib/features/management/widgets/quick_fee_calculator_sheet.dart`
- Test:
  - `test/features/management/fee_policy_management_screen_test.dart`

**Interfaces:**
- Consumes: `feePolicyRepositoryProvider`, `buildingFeePoliciesProvider`
- Produces:
  - `FeePolicyManagementScreen`: Màn hình xem danh mục chính sách biểu giá (Điện EVN 6 bậc, Nước định mức, Phí xe pro-rata, Lãi phạt trễ hạn).
  - `QuickFeeCalculatorSheet`: Công cụ tính nhanh cho kế toán: nhập số cũ, số mới, số nhân khẩu -> tự động xuất bảng phân rã chi tiết.

- [ ] **Step 1: Viết widget test cho `FeePolicyManagementScreen`**
Kiểm thử hiển thị các thẻ chính sách biểu giá và nút mở công cụ tính nhanh.

- [ ] **Step 2: Chạy test để xác nhận FAIL**
Chạy `flutter test test/features/management/fee_policy_management_screen_test.dart` xác nhận FAIL.

- [ ] **Step 3: Triển khai Màn hình & Dialog cho BQL**
Viết màn hình và bottom sheet, tuân thủ 100% `design-rules.md`.

- [ ] **Step 4: Chạy test để xác nhận PASS**
Chạy widget test, xác nhận PASS 100%.

- [ ] **Step 5: Commit vào git**
```bash
git add lib/features/management/screens/fee_policy_management_screen.dart lib/features/management/widgets/quick_fee_calculator_sheet.dart test/features/management/fee_policy_management_screen_test.dart
git commit -m "feat(ui): them man hinh quan ly bieu gia va cong cu tinh nhanh cho BQL C2"
```

---

### Task 6: Toàn Bộ Verification, Static Analysis & Cập Nhật Roadmap

**Files:**
- Modify: `docs/COMMERCIAL_PRODUCT_ROADMAP.md`
- Test: Toàn bộ test suite `flutter test`, `flutter analyze`

- [ ] **Step 1: Chạy toàn bộ test suite**
Chạy `flutter test` đảm bảo 100% tests vượt qua không có lỗi.

- [ ] **Step 2: Chạy static analysis**
Chạy `flutter analyze` đảm bảo 0 cảnh báo, 0 lỗi.

- [ ] **Step 3: Cập nhật tiến độ roadmap**
Đánh dấu `[x] C2. Engine tính phí đa dạng` trong `docs/COMMERCIAL_PRODUCT_ROADMAP.md`.

- [ ] **Step 4: Commit hoàn tất**
```bash
git add docs/COMMERCIAL_PRODUCT_ROADMAP.md docs/superpowers/plans/2026-10-29-progressive-fees-and-prorata-engine.md
git commit -m "docs: hoan thanh C2 engine tinh phi da dang trong lo trinh thuong mai"
```
