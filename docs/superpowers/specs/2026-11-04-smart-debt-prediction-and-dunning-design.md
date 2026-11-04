# Thiết Kế Chi Tiết E3: Dự Báo Nợ Xấu & Nhắc Nợ Thông Minh (Smart Debt Prediction & Multi-Tier Dunning Strategy)

## 1. Bối cảnh & Mục tiêu Nghiệp Vụ
Trong vận hành tòa nhà chung cư thương mại, công nợ chậm thanh toán là rủi ro lớn nhất đe dọa dòng tiền vận hành và quỹ bảo trì. Trước đây hệ thống mới dừng lại ở báo cáo tuổi nợ 4 xô (0-30, 31-60, 61-90, >90 ngày) theo tính chất thống kê thụ động. 

Mục tiêu của **Giai đoạn E3** là nâng cấp hệ thống kế toán thành **Chủ động phòng ngừa rủi ro (Proactive Debt Risk Mitigation)** với 2 trụ cột:
1. **Thuật toán Chấm Điểm Rủi Ro Nợ Xấu (Debt Risk Prediction Algorithm):** Đánh giá xác suất căn hộ trễ hạn / mất khả năng thanh toán theo thang điểm 0 - 100 dựa trên mô hình định lượng 3 thành phần (Số ngày quá hạn, Tỷ lệ nợ/phí trung bình, Lịch sử nộp muộn trong quá khứ).
2. **Chiến Lược Đôn Đốc Đa Tầng (Multi-Tier Dunning Strategy):** Khuyến nghị tự động hành động theo 3 nấc chuẩn mực văn hóa chung cư và pháp lý Việt Nam:
   - **Tầng 1 (Nhắc nhở thân thiện - Gentle Reminder):** Quá hạn 1-15 ngày / Rủi ro thấp.
   - **Tầng 2 (Cảnh báo tài chính - Financial Warning):** Quá hạn 16-45 ngày / Rủi ro trung bình, thông báo tính lãi chậm nộp theo quy định.
   - **Tầng 3 (Thông báo chế tài & Tạm ngừng dịch vụ - Service Restriction Notice):** Quá hạn > 45 ngày / Rủi ro cao, đề xuất tạm ngừng các dịch vụ tiện ích bổ sung (ô đỗ xe, thẻ bơi/gym) và bàn giao Ban Quản Trị giải quyết.

---

## 2. Kiến Trúc Cơ Sở Dữ Liệu & RPC PostgreSQL

### 2.1. Bảng Dữ Liệu
#### Bảng `debt_risk_scores` (Điểm rủi ro nợ xấu căn hộ)
```sql
CREATE TABLE IF NOT EXISTS public.debt_risk_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    risk_score INTEGER NOT NULL CHECK (risk_score >= 0 AND risk_score <= 100),
    risk_level VARCHAR(20) NOT NULL CHECK (risk_level IN ('low', 'medium', 'high')),
    overdue_days INTEGER NOT NULL DEFAULT 0,
    unpaid_amount NUMERIC(15, 2) NOT NULL DEFAULT 0,
    monthly_fee_avg NUMERIC(15, 2) NOT NULL DEFAULT 0,
    late_payment_count INTEGER NOT NULL DEFAULT 0,
    recommended_tier VARCHAR(20) NOT NULL CHECK (recommended_tier IN ('tier_1', 'tier_2', 'tier_3')),
    risk_factors JSONB NOT NULL DEFAULT '[]'::jsonb,
    assessed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_debt_risk_apartment UNIQUE (apartment_id)
);
```

#### Bảng `dunning_actions` (Nhật ký đôn đốc đa tầng)
```sql
CREATE TABLE IF NOT EXISTS public.dunning_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartment_id UUID NOT NULL REFERENCES public.apartments(id) ON DELETE CASCADE,
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    tier VARCHAR(20) NOT NULL CHECK (tier IN ('tier_1', 'tier_2', 'tier_3')),
    action_type VARCHAR(50) NOT NULL DEFAULT 'notification',
    action_title TEXT NOT NULL,
    action_content TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'sent' CHECK (status IN ('draft', 'sent', 'acknowledged', 'resolved')),
    performed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

### 2.2. Thuật Toán Định Lượng Điểm Rủi Ro (Debt Risk Formula)
$$\text{Risk Score} = \min(100, \text{Round}(0.40 \times S_{\text{overdue}} + 0.35 \times S_{\text{ratio}} + 0.25 \times S_{\text{history}}))$$

Trong đó:
1. **$S_{\text{overdue}}$ (Điểm theo số ngày quá hạn, 0-100):**
   - 0 ngày quá hạn: 0 điểm.
   - 1 - 15 ngày: $\min(40, \text{days} \times 2.6)$.
   - 16 - 30 ngày: $40 + (\text{days} - 15) \times 2$. (tối đa 70).
   - > 30 ngày: $\min(100, 70 + (\text{days} - 30) \times 1.5)$.
2. **$S_{\text{ratio}}$ (Tỷ lệ nợ / Phí trung bình 1 tháng, 0-100):**
   - Tỷ lệ $\le 0$: 0 điểm.
   - Tỷ lệ $\le 1.0$ (nợ 1 kỳ): Tỷ lệ $\times 40$.
   - Tỷ lệ $\le 2.0$ (nợ 2 kỳ): $40 + (\text{tỷ lệ} - 1.0) \times 30$ (tối đa 70).
   - Tỷ lệ $> 2.0$: $\min(100, 70 + (\text{tỷ lệ} - 2.0) \times 30)$.
3. **$S_{\text{history}}$ (Lịch sử nộp muộn trong quá khứ, 0-100):**
   - Đếm số hóa đơn từng thanh toán sau ngày `due_date` trong 6 kỳ gần nhất.
   - 0 lần: 0 điểm.
   - 1 lần: 25 điểm.
   - 2 lần: 50 điểm.
   - 3 lần: 75 điểm.
   - $\ge 4$ lần: 100 điểm.

### 2.3. RPCs PostgreSQL
1. `calculate_apartment_debt_risk(p_building_id UUID, p_apartment_id UUID)`: Tính toán và cập nhật vào bảng `debt_risk_scores`.
2. `get_building_debt_radar(p_building_id UUID)`: Trả về danh sách căn hộ kèm điểm rủi ro, yếu tố rủi ro và khuyến nghị đôn đốc.
3. `execute_dunning_action(p_building_id UUID, p_apartment_id UUID, p_tier VARCHAR, p_title TEXT, p_content TEXT)`: Ghi nhật ký vào `dunning_actions` và tự động gửi notification cho chủ hộ/cư dân liên kết.

---

## 3. Tầng Dữ Liệu Dart & Fallback Engine
- Models: `DebtRiskScoreModel`, `DunningActionModel`.
- Enums:
  - `DebtRiskLevel` (`low`: An toàn, `medium`: Cần chú ý, `high`: Rủi ro cao).
  - `DunningTier` (`tier1`: Nhắc nhở lịch sự, `tier2`: Cảnh báo tài chính, `tier3`: Chế tài dịch vụ).
- `DebtPredictionEngine`: Logic tính toán thuần túy có thể chạy offline trên Client nếu không có kết nối mạng tới Supabase.
- `DebtPredictionRepository`: Kết nối Supabase RPC và tự động fallback sang `DebtPredictionEngine` khi offline.
- Providers: `debtPredictionRepositoryProvider`, `buildingDebtRadarProvider(buildingId)`.

---

## 4. Tầng Giao Diện Người Dùng (UI/UX)
- Bổ sung màn hình hoặc Tab "Radar Rủi Ro Nợ Xấu" (`DebtRiskRadarTab`):
  - Dải KPI: Căn hộ rủi ro cao, Căn hộ cần chú ý, Tổng nợ có nguy cơ.
  - Bộ lọc: Tất cả / Rủi ro cao / Cần chú ý / An toàn.
  - Bảng danh sách căn hộ hiển thị rõ điểm số (Vòng cung hoặc Thanh tiến trình nhỏ có màu ngữ nghĩa), số ngày trễ hạn, đề xuất đôn đốc.
  - Hộp thoại thực thi đôn đốc (`ExecuteDunningDialog`): Chọn mẫu nhắc nhở theo cấp độ, chỉnh sửa nội dung, xác nhận gửi.

---

## 5. Kế Hoạch Kiểm Thử
1. **Kiểm thử CSDL:** `test/database/debt_prediction_migration_test.dart` xác minh cấu trúc bảng, RPC, RLS policies và công thức tính điểm.
2. **Kiểm thử Data & Fallback:** `test/data/repositories/debt_prediction_repository_test.dart` kiểm tra thuật toán định lượng và fallback engine.
3. **Kiểm thử Giao diện:** `test/features/management/debt_risk_radar_test.dart` kiểm tra hiển thị KPI, bảng căn hộ và hộp thoại gửi nhắc nợ đa tầng.
