import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kiểm tra Migration 20261104_03: Dự Báo Nợ Xấu & Đôn Đốc Đa Tầng E3', () {
    const migrationPath = 'supabase/migrations/20261104_03_debt_prediction_and_dunning.sql';

    test('File migration phải tồn tại và không rỗng', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Migration 20261104_03 phải tồn tại');
      final content = file.readAsStringSync();
      expect(content.trim().isNotEmpty, isTrue, reason: 'Nội dung migration không được rỗng');
    });

    test('Phải định nghĩa bảng debt_risk_scores với đầy đủ trường định lượng', () {
      final content = File(migrationPath).readAsStringSync();
      expect(content.contains('CREATE TABLE IF NOT EXISTS public.debt_risk_scores'), isTrue);
      expect(content.contains('risk_score INTEGER NOT NULL CHECK (risk_score >= 0 AND risk_score <= 100)'), isTrue);
      expect(content.contains("risk_level VARCHAR(20) NOT NULL CHECK (risk_level IN ('low', 'medium', 'high'))"), isTrue);
      expect(content.contains("recommended_tier VARCHAR(20) NOT NULL CHECK (recommended_tier IN ('tier_1', 'tier_2', 'tier_3'))"), isTrue);
      expect(content.contains('uq_debt_risk_apartment UNIQUE (apartment_id)'), isTrue);
    });

    test('Phải định nghĩa bảng dunning_actions để lưu vết các hành động đôn đốc', () {
      final content = File(migrationPath).readAsStringSync();
      expect(content.contains('CREATE TABLE IF NOT EXISTS public.dunning_actions'), isTrue);
      expect(content.contains("tier VARCHAR(20) NOT NULL CHECK (tier IN ('tier_1', 'tier_2', 'tier_3'))"), isTrue);
      expect(content.contains('performed_by UUID REFERENCES public.users(id)'), isTrue);
      expect(content.contains('status VARCHAR(20) NOT NULL DEFAULT \'sent\''), isTrue);
    });

    test('Phải bật RLS và thiết lập phân quyền cách ly tenant cho cả hai bảng', () {
      final content = File(migrationPath).readAsStringSync();
      expect(content.contains('ALTER TABLE public.debt_risk_scores ENABLE ROW LEVEL SECURITY;'), isTrue);
      expect(content.contains('ALTER TABLE public.dunning_actions ENABLE ROW LEVEL SECURITY;'), isTrue);
      expect(content.contains('building_memberships'), isTrue);
      expect(content.contains('debt_risk_scores_staff_manage'), isTrue);
      expect(content.contains('dunning_actions_staff_manage'), isTrue);
      expect(content.contains('dunning_actions_resident_read'), isTrue);
    });

    test('Phải có RPC calculate_apartment_debt_risk với công thức 3 trọng số', () {
      final content = File(migrationPath).readAsStringSync();
      expect(content.contains('CREATE OR REPLACE FUNCTION public.calculate_apartment_debt_risk'), isTrue);
      expect(content.contains('v_score_overdue'), isTrue, reason: 'Phải tính điểm quá hạn (40%)');
      expect(content.contains('v_score_ratio'), isTrue, reason: 'Phải tính điểm tỷ lệ nợ (35%)');
      expect(content.contains('v_score_history'), isTrue, reason: 'Phải tính điểm lịch sử trả muộn (25%)');
      expect(content.contains('0.40 * v_score_overdue + 0.35 * v_score_ratio + 0.25 * v_score_history'), isTrue);
    });

    test('Phải có RPC get_building_debt_radar và execute_dunning_action', () {
      final content = File(migrationPath).readAsStringSync();
      expect(content.contains('CREATE OR REPLACE FUNCTION public.get_building_debt_radar'), isTrue);
      expect(content.contains('CREATE OR REPLACE FUNCTION public.execute_dunning_action'), isTrue);
      expect(content.contains('GRANT EXECUTE ON FUNCTION public.get_building_debt_radar'), isTrue);
      expect(content.contains('GRANT EXECUTE ON FUNCTION public.execute_dunning_action'), isTrue);
    });
  });
}
