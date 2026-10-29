import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/fee_tier_policy_model.dart';
import 'package:pka_home/data/models/tiered_calculation_result_model.dart';
import 'package:pka_home/data/providers/fee_policy_providers.dart';
import 'package:pka_home/data/repositories/fee_policy_repository.dart';

class FakeFeePolicyRepository extends FeePolicyRepository {
  @override
  Future<List<FeeTierPolicyModel>> fetchPolicies({
    String? buildingId,
    FeePolicyType? policyType,
  }) async {
    return [
      FeeTierPolicyModel(
        id: 'pol-fake-1',
        buildingId: buildingId,
        policyType: policyType ?? FeePolicyType.electricityTier,
        name: 'Chính sách biểu giá điện giả lập',
        calculationMethod: FeeCalculationMethod.progressiveTier,
        tiers: [],
        effectiveFrom: DateTime(2026, 1, 1),
        isActive: true,
      ),
    ];
  }

  @override
  Future<LatePenaltyResultModel> calculateLatePaymentPenalty({
    required String invoiceId,
    DateTime? asOfDate,
  }) async {
    return LatePenaltyResultModel(
      invoiceId: invoiceId,
      dueDate: DateTime(2026, 10, 10),
      asOfDate: asOfDate ?? DateTime(2026, 10, 25),
      daysOverdue: 15,
      inGracePeriod: false,
      penaltyRatePerDay: 0.0005,
      penaltyAmount: 15000.0,
      totalAmount: 2000000.0,
    );
  }
}

void main() {
  group('Fee Policy Providers Tests', () {
    test('feePolicyRepositoryProvider cung cấp thể hiện FeePolicyRepository mặc định', () {
      final container = ProviderContainer();
      final repo = container.read(feePolicyRepositoryProvider);
      expect(repo, isA<FeePolicyRepository>());
    });

    test('feePoliciesProvider tải danh sách chính sách biểu giá thành công', () async {
      final container = ProviderContainer(
        overrides: [
          feePolicyRepositoryProvider.overrideWithValue(FakeFeePolicyRepository()),
        ],
      );

      final policies = await container.read(feePoliciesProvider('bld-mock').future);
      expect(policies.length, 1);
      expect(policies.first.id, 'pol-fake-1');
      expect(policies.first.name, 'Chính sách biểu giá điện giả lập');
      expect(policies.first.buildingId, 'bld-mock');
    });

    test('buildingFeePoliciesProvider alias hoạt động đồng nhất với feePoliciesProvider', () async {
      final container = ProviderContainer(
        overrides: [
          feePolicyRepositoryProvider.overrideWithValue(FakeFeePolicyRepository()),
        ],
      );

      final policies = await container.read(buildingFeePoliciesProvider('bld-mock').future);
      expect(policies.length, 1);
      expect(policies.first.id, 'pol-fake-1');
    });

    test('calculatedLatePenaltyProvider tính toán lãi phạt trễ hạn chính xác', () async {
      final container = ProviderContainer(
        overrides: [
          feePolicyRepositoryProvider.overrideWithValue(FakeFeePolicyRepository()),
        ],
      );

      final penalty = await container.read(calculatedLatePenaltyProvider('inv-fake-999').future);
      expect(penalty.invoiceId, 'inv-fake-999');
      expect(penalty.daysOverdue, 15);
      expect(penalty.penaltyAmount, 15000.0);
      expect(penalty.totalAmount, 2000000.0);
      expect(penalty.totalWithPenalty, 2015000.0);
    });
  });
}
