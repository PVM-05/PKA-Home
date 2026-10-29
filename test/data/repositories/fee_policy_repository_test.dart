import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/models/fee_tier_policy_model.dart';
import 'package:pka_home/data/models/tiered_calculation_result_model.dart';
import 'package:pka_home/data/repositories/fee_policy_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class FakePostgrestFilterBuilder extends Fake implements PostgrestFilterBuilder<dynamic> {
  final dynamic _result;
  FakePostgrestFilterBuilder(this._result);

  @override
  Future<R> then<R>(FutureOr<R> Function(dynamic value) onValue, {Function? onError}) {
    return Future.value(_result).then(onValue, onError: onError);
  }
}

void main() {
  group('FeePolicyRepository Unit Tests', () {
    late MockSupabaseClient mockClient;

    setUp(() {
      mockClient = MockSupabaseClient();
    });

    test('Có thể khởi tạo FeePolicyRepository không cần tham số', () {
      final repo = FeePolicyRepository();
      expect(repo, isNotNull);
    });

    test('Có thể khởi tạo FeePolicyRepository với client được tiêm vào', () {
      final repo = FeePolicyRepository(mockClient);
      expect(repo, isNotNull);
    });

    group('Helper Parsing Methods', () {
      test('parsePolicies phân tích danh sách dữ liệu chính sách biểu giá đúng định dạng', () {
        final repo = FeePolicyRepository();
        final rawList = [
          {
            'id': 'pol-1',
            'building_id': 'bld-1',
            'policy_type': 'ELECTRICITY_TIER',
            'name': 'Biểu giá điện 6 bậc',
            'calculation_method': 'PROGRESSIVE_TIER',
            'tiers': [],
            'effective_from': '2026-01-01',
            'is_active': true,
          },
        ];

        final policies = repo.parsePolicies(rawList);
        expect(policies.length, 1);
        expect(policies.first, isA<FeeTierPolicyModel>());
        expect(policies.first.name, 'Biểu giá điện 6 bậc');
        expect(policies.first.policyType, FeePolicyType.electricityTier);
      });

      test('parseTieredResult phân tích kết quả tính toán lũy tiến đúng', () {
        final repo = FeePolicyRepository();
        final rawData = {
          'policy_id': 'pol-elec',
          'policy_name': 'Điện sinh hoạt 6 bậc',
          'consumption': 120.0,
          'total_amount': 250000.0,
          'breakdown': [
            {
              'tier': 1,
              'name': 'Bậc 1 (0 - 50 kWh)',
              'from': 0.0,
              'to': 50.0,
              'rate': 1893.0,
              'units': 50.0,
              'amount': 94650.0,
            }
          ],
        };

        final result = repo.parseTieredResult(rawData);
        expect(result, isA<TieredCalculationResultModel>());
        expect(result.consumption, 120.0);
        expect(result.totalAmount, 250000.0);
        expect(result.breakdown.length, 1);
        expect(result.breakdown.first.units, 50.0);
      });

      test('parseProratedResult phân tích kết quả tính phí xe theo ngày đúng', () {
        final repo = FeePolicyRepository();
        final rawData = {
          'monthly_rate': 120000.0,
          'period': '2026-10',
          'start_date': '2026-10-15',
          'days_in_month': 31,
          'days_used': 17,
          'is_prorated': true,
          'total_amount': 65806.0,
        };

        final result = repo.parseProratedResult(rawData);
        expect(result, isA<ProratedFeeResultModel>());
        expect(result.monthlyRate, 120000.0);
        expect(result.daysUsed, 17);
        expect(result.isProrated, isTrue);
        expect(result.totalAmount, 65806.0);
      });

      test('parseLatePenaltyResult phân tích kết quả phạt trễ hạn đúng', () {
        final repo = FeePolicyRepository();
        final rawData = {
          'invoice_id': 'inv-123',
          'due_date': '2026-10-10',
          'as_of_date': '2026-10-20',
          'days_overdue': 10,
          'in_grace_period': false,
          'penalty_rate_per_day': 0.0005,
          'penalty_amount': 10000.0,
          'total_amount': 2000000.0,
        };

        final result = repo.parseLatePenaltyResult(rawData);
        expect(result, isA<LatePenaltyResultModel>());
        expect(result.invoiceId, 'inv-123');
        expect(result.daysOverdue, 10);
        expect(result.inGracePeriod, isFalse);
        expect(result.penaltyAmount, 10000.0);
      });
    });

    group('fetchPolicies', () {
      test('Trả về danh sách rỗng khi không có client kết nối', () async {
        final repo = FeePolicyRepository();
        final policies = await repo.fetchPolicies(buildingId: 'bld-test');
        expect(policies, isEmpty);
      });
    });

    group('calculateElectricityFee RPC & Offline Fallback', () {
      test('Gọi RPC calculate_progressive_electricity_fee thành công khi online', () async {
        final rpcResult = {
          'policy_id': 'pol-1',
          'policy_name': 'Điện sinh hoạt EVN 6 bậc (QĐ 2024)',
          'consumption': 100.0,
          'total_amount': 192450.0,
          'breakdown': [
            {
              'tier': 1,
              'name': 'Bậc 1 (0 - 50 kWh)',
              'from': 0.0,
              'to': 50.0,
              'rate': 1893.0,
              'units': 50.0,
              'amount': 94650.0,
            },
            {
              'tier': 2,
              'name': 'Bậc 2 (51 - 100 kWh)',
              'from': 50.0,
              'to': 100.0,
              'rate': 1956.0,
              'units': 50.0,
              'amount': 97800.0,
            },
          ],
        };

        when(() => mockClient.rpc(
              'calculate_progressive_electricity_fee',
              params: any(named: 'params'),
            )).thenAnswer((_) => FakePostgrestFilterBuilder(rpcResult));

        final repo = FeePolicyRepository(mockClient);
        final result = await repo.calculateElectricityFee(100.0, buildingId: 'bld-1');

        verify(() => mockClient.rpc(
              'calculate_progressive_electricity_fee',
              params: {'p_consumption': 100.0, 'p_building_id': 'bld-1'},
            )).called(1);

        expect(result.consumption, 100.0);
        expect(result.totalAmount, 192450.0);
        expect(result.breakdown.length, 2);
      });

      test('Tự động fallback sang UtilityFeeCalculator khi client null hoặc lỗi mạng', () async {
        final repo = FeePolicyRepository(); // client null
        final result = await repo.calculateElectricityFee(100.0);

        expect(result.consumption, 100.0);
        // EVN 6 bậc: 50*1893 + 50*1956 = 94650 + 97800 = 192450
        expect(result.totalAmount, 192450.0);
        expect(result.breakdown.length, 6);
      });

      test('Tự động fallback sang UtilityFeeCalculator khi RPC ném ngoại lệ', () async {
        when(() => mockClient.rpc(
              'calculate_progressive_electricity_fee',
              params: any(named: 'params'),
            )).thenThrow(Exception('Network disconnected'));

        final repo = FeePolicyRepository(mockClient);
        final result = await repo.calculateElectricityFee(50.0);

        expect(result.consumption, 50.0);
        expect(result.totalAmount, 50 * 1893.0);
      });
    });

    group('calculateWaterFee RPC & Offline Fallback', () {
      test('Gọi RPC calculate_quota_water_fee thành công khi online', () async {
        final rpcResult = {
          'policy_id': 'pol-water',
          'policy_name': 'Nước sinh hoạt định mức 4m3/người',
          'consumption': 10.0,
          'total_amount': 92000.0,
          'resident_count': 2,
          'base_quota': 8.0,
          'breakdown': [
            {
              'tier': 1,
              'name': 'Trong định mức (0 - 8 m³)',
              'from': 0.0,
              'to': 8.0,
              'rate': 8500.0,
              'consumption': 8.0,
              'amount': 68000.0,
            },
            {
              'tier': 2,
              'name': 'Vượt định mức cấp 1 (8 - 12 m³)',
              'from': 8.0,
              'to': 12.0,
              'rate': 12000.0,
              'consumption': 2.0,
              'amount': 24000.0,
            },
          ],
        };

        when(() => mockClient.rpc(
              'calculate_quota_water_fee',
              params: any(named: 'params'),
            )).thenAnswer((_) => FakePostgrestFilterBuilder(rpcResult));

        final repo = FeePolicyRepository(mockClient);
        final result = await repo.calculateWaterFee(10.0, residentCount: 2, buildingId: 'bld-1');

        verify(() => mockClient.rpc(
              'calculate_quota_water_fee',
              params: {
                'p_consumption': 10.0,
                'p_resident_count': 2,
                'p_building_id': 'bld-1',
              },
            )).called(1);

        expect(result.consumption, 10.0);
        expect(result.totalAmount, 92000.0);
        expect(result.residentCount, 2);
      });

      test('Tự động fallback sang UtilityFeeCalculator khi RPC gặp lỗi', () async {
        when(() => mockClient.rpc(
              'calculate_quota_water_fee',
              params: any(named: 'params'),
            )).thenThrow(Exception('RPC timeout'));

        final repo = FeePolicyRepository(mockClient);
        final result = await repo.calculateWaterFee(10.0, residentCount: 2);

        // Định mức 2 người = 8m3 * 8500 = 68000, 2m3 vượt = 2 * 12000 = 24000 => 92000
        expect(result.totalAmount, 92000.0);
        expect(result.residentCount, 2);
      });
    });

    group('calculateProratedVehicleFee RPC & Fallback', () {
      test('Gọi RPC calculate_prorated_vehicle_fee thành công khi online', () async {
        final rpcResult = {
          'monthly_rate': 100000.0,
          'period': '2026-10',
          'start_date': '2026-10-16',
          'days_in_month': 31,
          'days_used': 16,
          'is_prorated': true,
          'total_amount': 51613.0,
        };

        when(() => mockClient.rpc(
              'calculate_prorated_vehicle_fee',
              params: any(named: 'params'),
            )).thenAnswer((_) => FakePostgrestFilterBuilder(rpcResult));

        final repo = FeePolicyRepository(mockClient);
        final result = await repo.calculateProratedVehicleFee(
          monthlyRate: 100000.0,
          startDate: DateTime(2026, 10, 16),
          period: '2026-10',
        );

        verify(() => mockClient.rpc(
              'calculate_prorated_vehicle_fee',
              params: {
                'p_monthly_rate': 100000.0,
                'p_start_date': '2026-10-16',
                'p_period': '2026-10',
              },
            )).called(1);

        expect(result.totalAmount, 51613.0);
        expect(result.daysUsed, 16);
      });

      test('calculateProratedParkingFee alias hoạt động đồng nhất', () async {
        final repo = FeePolicyRepository();
        final result = await repo.calculateProratedParkingFee(
          monthlyRate: 100000.0,
          startDate: DateTime(2026, 10, 16),
          period: '2026-10',
        );
        expect(result.daysUsed, 16);
        expect(result.isProrated, isTrue);
      });

      test('Tự động fallback sang UtilityFeeCalculator khi client null', () async {
        final repo = FeePolicyRepository();
        final result = await repo.calculateProratedVehicleFee(
          monthlyRate: 310000.0,
          startDate: DateTime(2026, 10, 1),
          period: '2026-10',
        );
        expect(result.isProrated, isFalse);
        expect(result.totalAmount, 310000.0);
      });
    });

    group('calculateLatePaymentPenalty RPC', () {
      test('Gọi RPC calculate_late_payment_penalty thành công', () async {
        final rpcResult = {
          'invoice_id': 'inv-uuid-1',
          'due_date': '2026-10-10',
          'as_of_date': '2026-10-20',
          'days_overdue': 10,
          'in_grace_period': false,
          'penalty_rate_per_day': 0.0005,
          'penalty_amount': 5000.0,
          'total_amount': 1000000.0,
        };

        when(() => mockClient.rpc(
              'calculate_late_payment_penalty',
              params: any(named: 'params'),
            )).thenAnswer((_) => FakePostgrestFilterBuilder(rpcResult));

        final repo = FeePolicyRepository(mockClient);
        final result = await repo.calculateLatePaymentPenalty(
          invoiceId: 'inv-uuid-1',
          asOfDate: DateTime(2026, 10, 20),
        );

        verify(() => mockClient.rpc(
              'calculate_late_payment_penalty',
              params: {
                'p_invoice_id': 'inv-uuid-1',
                'p_as_of_date': '2026-10-20',
              },
            )).called(1);

        expect(result.invoiceId, 'inv-uuid-1');
        expect(result.daysOverdue, 10);
        expect(result.penaltyAmount, 5000.0);
      });

      test('calculateLatePenalty alias gọi đúng hàm chính', () async {
        final rpcResult = {
          'invoice_id': 'inv-uuid-2',
          'due_date': '2026-10-10',
          'as_of_date': '2026-10-12',
          'days_overdue': 2,
          'in_grace_period': true,
          'penalty_rate_per_day': 0.0005,
          'penalty_amount': 0.0,
          'total_amount': 500000.0,
        };

        when(() => mockClient.rpc(
              'calculate_late_payment_penalty',
              params: any(named: 'params'),
            )).thenAnswer((_) => FakePostgrestFilterBuilder(rpcResult));

        final repo = FeePolicyRepository(mockClient);
        final result = await repo.calculateLatePenalty('inv-uuid-2');
        expect(result.inGracePeriod, isTrue);
      });

      test('Ném ngoại lệ khi client null và không thể tính lãi phạt', () async {
        final repo = FeePolicyRepository();
        expect(
          () => repo.calculateLatePaymentPenalty(invoiceId: 'inv-none'),
          throwsException,
        );
      });
    });
  });
}
