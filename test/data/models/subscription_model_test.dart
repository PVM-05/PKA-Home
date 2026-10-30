import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/subscription_plan_model.dart';
import 'package:pka_home/data/models/subscription_model.dart';

void main() {
  group('Subscription & Quota Models Tests', () {
    test('SubscriptionPlanModel serialization and helper getters', () {
      final json = {
        'id': 'plan-pro-1',
        'code': 'pro',
        'name': 'Gói Nâng Cao',
        'description': 'Lựa chọn tối ưu cho chung cư 100-500 căn',
        'max_apartments': 500,
        'max_buildings': 5,
        'max_staff': 10,
        'price_monthly': 1499000,
        'price_yearly': 14990000,
        'features': {'financial_aging_report': true, 'vietqr': true},
        'is_active': true,
        'sort_order': 2,
      };

      final plan = SubscriptionPlanModel.fromJson(json);
      expect(plan.id, 'plan-pro-1');
      expect(plan.code, 'pro');
      expect(plan.name, 'Gói Nâng Cao');
      expect(plan.maxApartments, 500);
      expect(plan.isUnlimitedApartments, isFalse);
      expect(plan.priceMonthly, 1499000.0);
      expect(plan.formattedPriceMonthly, contains('1.499.000'));
      expect(plan.features['financial_aging_report'], isTrue);

      final outJson = plan.toJson();
      expect(outJson['code'], 'pro');
      expect(outJson['max_apartments'], 500);
    });

    test('SubscriptionPlanModel handles unlimited (-1) values correctly', () {
      final json = {
        'id': 'plan-ent-1',
        'code': 'enterprise',
        'name': 'Gói Doanh Nghiệp',
        'max_apartments': -1,
        'max_buildings': -1,
        'max_staff': -1,
        'price_monthly': 3999000,
        'price_yearly': 39990000,
      };

      final plan = SubscriptionPlanModel.fromJson(json);
      expect(plan.isUnlimitedApartments, isTrue);
      expect(plan.isUnlimitedBuildings, isTrue);
      expect(plan.isUnlimitedStaff, isTrue);
      expect(plan.displayMaxApartments, 'Không giới hạn');
    });

    test('SubscriptionUsageMetricsModel calculates percentages and alert flags', () {
      final metrics = SubscriptionUsageMetricsModel(
        usedApartments: 420,
        maxApartments: 500,
        apartmentUsagePercent: 84.0,
        isNearLimit: true,
        isAtLimit: false,
        usedBuildings: 2,
        maxBuildings: 5,
        usedStaff: 4,
        maxStaff: 10,
      );

      expect(metrics.usedApartments, 420);
      expect(metrics.apartmentUsagePercent, 84.0);
      expect(metrics.isNearLimit, isTrue);
      expect(metrics.isAtLimit, isFalse);
      expect(metrics.displayApartmentRatio, '420 / 500 căn');
    });

    test('SubscriptionStatusModel parses RPC response accurately', () {
      final rpcJson = {
        'organization_id': 'org-123',
        'subscription_id': 'sub-456',
        'plan_code': 'pro',
        'plan_name': 'Gói Nâng Cao',
        'plan_description': 'Dành cho chung cư vừa và lớn',
        'status': 'active',
        'start_date': '2026-01-01T00:00:00Z',
        'expires_at': '2027-01-01T00:00:00Z',
        'days_remaining': 62,
        'is_expiring_soon': false,
        'billing_cycle': 'yearly',
        'auto_renew': true,
        'price_monthly': 1499000,
        'price_yearly': 14990000,
        'features': {'vietqr': true},
        'usage': {
          'used_apartments': 150,
          'max_apartments': 500,
          'apartment_usage_percent': 30.0,
          'is_near_limit': false,
          'is_at_limit': false,
          'used_buildings': 1,
          'max_buildings': 5,
          'used_staff': 3,
          'max_staff': 10,
        },
      };

      final status = SubscriptionStatusModel.fromJson(rpcJson);
      expect(status.organizationId, 'org-123');
      expect(status.planCode, 'pro');
      expect(status.planName, 'Gói Nâng Cao');
      expect(status.status, 'active');
      expect(status.daysRemaining, 62);
      expect(status.isExpiringSoon, isFalse);
      expect(status.statusBadgeText, 'Đang hoạt động');
      expect(status.usage.usedApartments, 150);
      expect(status.usage.maxApartments, 500);
    });
  });
}

