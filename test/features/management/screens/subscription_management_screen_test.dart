import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/subscription_model.dart';
import 'package:pka_home/data/models/subscription_plan_model.dart';
import 'package:pka_home/data/providers/subscription_provider.dart';
import 'package:pka_home/data/repositories/subscription_repository.dart';
import 'package:pka_home/features/management/screens/subscription_management_screen.dart';

class FakeSubscriptionRepository extends SubscriptionRepository {
  @override
  Future<SubscriptionStatusModel> fetchSubscriptionStatus({
    required String buildingId,
  }) async {
    return SubscriptionStatusModel(
      organizationId: 'org-test',
      subscriptionId: 'sub-test',
      planCode: 'pro',
      planName: 'Gói Nâng Cao',
      planDescription: 'Chung cư vừa và lớn',
      status: 'active',
      startDate: DateTime(2026, 1, 1),
      expiresAt: DateTime(2027, 1, 1),
      daysRemaining: 180,
      isExpiringSoon: false,
      billingCycle: 'yearly',
      autoRenew: true,
      priceMonthly: 1499000,
      priceYearly: 14990000,
      features: const {'vietqr': true},
      usage: const SubscriptionUsageMetricsModel(
        usedApartments: 420,
        maxApartments: 500,
        apartmentUsagePercent: 84.0,
        isNearLimit: true,
        isAtLimit: false,
        usedBuildings: 2,
        maxBuildings: 5,
        usedStaff: 4,
        maxStaff: 10,
      ),
    );
  }

  @override
  Future<List<SubscriptionPlanModel>> fetchAvailablePlans() async {
    return getFallbackPlans();
  }
}

void main() {
  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        subscriptionRepositoryProvider.overrideWithValue(
          FakeSubscriptionRepository(),
        ),
      ],
      child: const MaterialApp(
        home: SubscriptionManagementScreen(),
      ),
    );
  }

  group('SubscriptionManagementScreen Widget Tests', () {
    testWidgets('renders current subscription and quota gauge cards', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Gói Dịch Vụ & Hạn Mức'), findsOneWidget);
      expect(find.text('Gói Nâng Cao'), findsWidgets);
      expect(find.text('Đang hoạt động'), findsOneWidget);
      expect(find.text('Còn 180 ngày'), findsOneWidget);

      // Usage metrics
      expect(find.text('Hạn Mức Sử Dụng Thực Tế'), findsOneWidget);
      expect(find.text('420 / 500 căn'), findsOneWidget);
      expect(find.text('(84.0%)'), findsOneWidget);
      expect(find.text('2 / 5 tòa'), findsOneWidget);
      expect(find.text('4 / 10 nhân viên'), findsOneWidget);
    });

    testWidgets('renders comparison of 3 plans with upgrade buttons', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Bảng Gói Dịch Vụ Nâng Cấp'), findsOneWidget);
      expect(find.text('Gói Tiêu Chuẩn'), findsOneWidget);
      expect(find.text('Gói Doanh Nghiệp'), findsOneWidget);

      // Pro is current plan
      expect(find.text('Đang Sử Dụng'), findsOneWidget);
      // Enterprise can be upgraded
      expect(find.text('Yêu Cầu Nâng Cấp Gói Này'), findsWidgets);
    });

    testWidgets('tapping upgrade button opens upgrade request dialog', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final upgradeButtons = find.widgetWithText(ElevatedButton, 'Yêu Cầu Nâng Cấp Gói Này');
      expect(upgradeButtons, findsWidgets);

      await tester.ensureVisible(upgradeButtons.first);
      await tester.pumpAndSettle();

      await tester.tap(upgradeButtons.first);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Số điện thoại liên hệ (*)'), findsOneWidget);
      expect(find.text('Gửi yêu cầu'), findsOneWidget);
    });
  });
}
