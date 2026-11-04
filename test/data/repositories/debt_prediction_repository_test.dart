import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pka_home/data/models/debt_risk_score_model.dart';
import 'package:pka_home/data/models/dunning_action_model.dart';
import 'package:pka_home/data/repositories/debt_prediction_repository.dart';
import 'package:pka_home/data/services/debt_prediction_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('DebtPredictionEngine - Thuật toán định lượng rủi ro nợ xấu', () {
    test('Căn hộ không nợ và không trễ hạn phải có điểm rủi ro bằng 0 (An toàn)', () {
      final res = DebtPredictionEngine.calculate(
        unpaidAmount: 0,
        overdueDays: 0,
        monthlyFeeAvg: 1500000,
        latePaymentCount: 0,
      );

      expect(res.riskScore, 0);
      expect(res.riskLevel, DebtRiskLevel.low);
      expect(res.recommendedTier, DunningTier.tier1);
      expect(res.riskFactors.isEmpty, isTrue);
    });

    test('Căn hộ nợ kéo dài quá hạn 52 ngày, nợ gấp 4.9 lần phí tháng phải có rủi ro cao (tier 3)', () {
      final res = DebtPredictionEngine.calculate(
        unpaidAmount: 7850000,
        overdueDays: 52,
        monthlyFeeAvg: 1600000,
        latePaymentCount: 3,
      );

      expect(res.riskScore, greaterThanOrEqualTo(70));
      expect(res.riskLevel, DebtRiskLevel.high);
      expect(res.recommendedTier, DunningTier.tier3);
      expect(res.riskFactors.isNotEmpty, isTrue);
      expect(res.riskFactors.any((f) => f.factor == 'overdue_duration'), isTrue);
    });

    test('Căn hộ nợ vừa phải 24 ngày trễ, nợ 2.3 lần phí phải thuộc nhóm Cần chú ý (tier 2 hoặc tier 3)', () {
      final res = DebtPredictionEngine.calculate(
        unpaidAmount: 4200000,
        overdueDays: 24,
        monthlyFeeAvg: 1800000,
        latePaymentCount: 2,
      );

      expect(res.riskScore, inInclusiveRange(40, 75));
      expect(res.riskLevel, isIn([DebtRiskLevel.medium, DebtRiskLevel.high]));
      expect(res.recommendedTier, isIn([DunningTier.tier2, DunningTier.tier3]));
    });
  });

  group('DunningTier & Mẫu Văn Bản Tiếng Việt', () {
    test('DunningTier phải sinh đúng nội dung tiếng Việt chuẩn mực theo 3 tầng', () {
      final content1 = DunningTier.tier1.defaultContent('A0110', 1500000, 5);
      expect(content1.contains('Kính gửi Quý cư dân căn hộ A0110'), isTrue);
      expect(content1.contains('quá hạn 5 ngày'), isTrue);

      final content2 = DunningTier.tier2.defaultContent('A0110', 4500000, 20);
      expect(content2.contains('đôn đốc công nợ lần 2'), isTrue);
      expect(content2.contains('tính lãi chậm trả'), isTrue);

      final content3 = DunningTier.tier3.defaultContent('A0110', 8000000, 50);
      expect(content3.contains('CẢNH BÁO ĐÔN ĐỐC ĐẶC BIỆT'), isTrue);
      expect(content3.contains('tạm dừng quyền sử dụng các dịch vụ tiện ích bổ sung'), isTrue);
    });

    test('DunningActionModel mapping json', () {
      final json = {
        'id': 'act-123',
        'apartment_id': 'apt-1',
        'building_id': 'bld-1',
        'tier': 'tier_2',
        'action_type': 'notification',
        'action_title': 'Đôn đốc lần 2',
        'action_content': 'Nội dung nhắc nợ',
        'status': 'sent',
        'performed_by': 'usr-admin',
        'created_at': '2026-11-04T10:00:00Z',
      };

      final model = DunningActionModel.fromJson(json);
      expect(model.id, 'act-123');
      expect(model.tier, DunningTier.tier2);
      expect(model.status, 'sent');
      expect(model.actionTitle, 'Đôn đốc lần 2');
    });
  });

  group('DebtPredictionRepository - Fallback Engine & Realtime', () {
    late MockSupabaseClient mockClient;
    late DebtPredictionRepository repository;

    setUp(() {
      mockClient = MockSupabaseClient();
      repository = DebtPredictionRepository(client: mockClient);
    });

    test('Khi RPC gặp sự cố hoặc offline, getBuildingDebtRadar phải kích hoạt Fallback Engine', () async {
      when(() => mockClient.rpc(any(), params: any(named: 'params')))
          .thenThrow(Exception('No connection to database'));

      final radar = await repository.getBuildingDebtRadar('bld-mock-1');

      expect(radar.apartments.isNotEmpty, isTrue);
      expect(radar.kpi.totalAtRiskApartments, greaterThan(0));
      expect(radar.kpi.totalOverdueDebt, greaterThan(0));
      // Kiểm tra sắp xếp giảm dần theo điểm rủi ro
      for (int i = 0; i < radar.apartments.length - 1; i++) {
        expect(
          radar.apartments[i].riskScore,
          greaterThanOrEqualTo(radar.apartments[i + 1].riskScore),
        );
      }
    });

    test('calculateApartmentDebtRisk tính toán fallback chính xác cho căn hộ', () async {
      when(() => mockClient.rpc(any(), params: any(named: 'params')))
          .thenThrow(Exception('RPC failed'));

      final res = await repository.calculateApartmentDebtRisk(
        buildingId: 'bld-mock-1',
        apartmentId: 'apt-01',
      );

      expect(res.apartmentId, 'apt-01');
      expect(res.apartmentCode, 'A0110');
      expect(res.riskScore, greaterThan(50));
      expect(res.riskLevel, DebtRiskLevel.high);
    });

    test('executeDunningAction lưu vết hành động thành công dù offline', () async {
      when(() => mockClient.rpc(any(), params: any(named: 'params')))
          .thenThrow(Exception('Offline'));
      when(() => mockClient.auth).thenReturn(FakeGoTrueClient());

      final action = await repository.executeDunningAction(
        buildingId: 'bld-1',
        apartmentId: 'apt-01',
        tier: DunningTier.tier2,
        title: 'Cảnh báo nợ',
        content: 'Vui lòng thanh toán',
      );

      expect(action.apartmentId, 'apt-01');
      expect(action.tier, DunningTier.tier2);
      expect(action.status, 'sent');
    });
  });
}

class FakeGoTrueClient extends Fake implements GoTrueClient {
  @override
  User? get currentUser => null;
}
