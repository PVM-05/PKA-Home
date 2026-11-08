import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/theme/app_theme.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/models/payment_transaction_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/role_delegation_provider.dart';
import 'package:pka_home/data/providers/dashboard_providers.dart';
import 'package:pka_home/data/providers/management_provider.dart';
import 'package:pka_home/data/providers/notification_provider.dart';
import 'package:pka_home/data/providers/payment_provider.dart';
import 'package:pka_home/features/management/screens/management_home_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final adminUser = UserModel(
    id: 'cefe60f0-571b-4b5c-a924-8081a5fcf05a',
    fullName: 'Nguyễn Văn An',
    phone: '0901234567',
    role: 'admin',
  );

  Widget buildTestApp({required double width, required double height}) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(adminUser)),
        activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
        pendingLinkRequestsCountProvider.overrideWith((ref) => Stream.value(0)),
        pendingConfirmationInvoicesProvider.overrideWith((ref) => Stream.value(0)),
        pendingIssuesCountProvider.overrideWith((ref) => Stream.value(0)),
        rawIssuesStreamProvider.overrideWith((ref) => Stream.value([])),
        notificationsStreamProvider.overrideWith((ref) => Stream.value([])),
        allIssuesProvider.overrideWith((ref) async => []),
        totalResidentsProvider.overrideWith((ref) => Stream.value(10)),
        apartmentsStreamProvider.overrideWith((ref) => Stream.value([])),
        financialStatsProvider.overrideWith((ref) => Stream.value(FinancialStats(
          paidTotal: 5000000.0,
          unpaidTotal: 1000000.0,
          paidCount: 5,
          unpaidCount: 2,
        ))),
        monthlyRevenueTrendProvider.overrideWith((ref) => Stream.value([])),
        paymentTransactionsProvider.overrideWith((ref) async => <PaymentTransactionModel>[]),
        residentsProvider.overrideWith((ref) async => []),
        apartmentsProvider.overrideWith((ref) async => []),
        invoicesProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, height)),
          child: const ManagementHomeScreen(),
        ),
      ),
    );
  }

  group('ManagementHomeScreen Responsive & Anti-Overflow Tests', () {
    testWidgets('renders desktop dashboard at width 1440dp without overflow', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(width: 1440, height: 900));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('Thao tác nhanh'), findsOneWidget);
    });

    testWidgets('renders mobile dashboard at narrow width 320dp without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(width: 320, height: 640));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('Thao tác nhanh'), findsOneWidget);
    });
  });
}
