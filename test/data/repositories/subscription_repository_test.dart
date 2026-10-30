import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/subscription_model.dart';
import 'package:pka_home/data/repositories/subscription_repository.dart';

void main() {
  group('SubscriptionRepository Tests', () {
    test('SubscriptionRepository can be instantiated without Supabase client initialized', () {
      final repo = SubscriptionRepository();
      expect(repo, isNotNull);
    });

    test('buildOfflineFallbackStatus produces valid SubscriptionStatusModel', () {
      final repo = SubscriptionRepository();
      final status = repo.buildOfflineFallbackStatus(
        buildingId: 'bld-test-1',
        totalApartments: 120,
      );

      expect(status, isA<SubscriptionStatusModel>());
      expect(status.planCode, 'pro');
      expect(status.planName, contains('Nâng Cao'));
      expect(status.status, 'active');
      expect(status.usage.usedApartments, 120);
      expect(status.usage.maxApartments, 500);
      expect(status.usage.apartmentUsagePercent, 24.0);
      expect(status.daysRemaining, greaterThan(0));
    });

    test('getFallbackPlans returns 3 standard SaaS plans', () {
      final repo = SubscriptionRepository();
      final plans = repo.getFallbackPlans();

      expect(plans.length, 3);
      expect(plans.any((p) => p.code == 'starter'), isTrue);
      expect(plans.any((p) => p.code == 'pro'), isTrue);
      expect(plans.any((p) => p.code == 'enterprise'), isTrue);

      final starter = plans.firstWhere((p) => p.code == 'starter');
      expect(starter.maxApartments, 100);
      expect(starter.maxBuildings, 1);

      final enterprise = plans.firstWhere((p) => p.code == 'enterprise');
      expect(enterprise.isUnlimitedApartments, isTrue);
    });

    test('requestPlanUpgrade returns confirmation structure', () async {
      final repo = SubscriptionRepository();
      final result = await repo.requestPlanUpgrade(
        buildingId: 'bld-test-1',
        targetPlanCode: 'enterprise',
        contactPhone: '0901234567',
        notes: 'Cần mở rộng thêm 2 tòa nhà mới',
      );

      expect(result['success'], isTrue);
      expect(result['message'], contains('tiếp nhận'));
    });
  });
}
