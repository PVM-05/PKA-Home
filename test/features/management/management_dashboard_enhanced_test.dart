import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/models/payment_transaction_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/payment_provider.dart';
import 'package:pka_home/data/providers/role_delegation_provider.dart';
import 'package:pka_home/data/providers/dashboard_providers.dart';
import 'package:pka_home/data/providers/management_provider.dart';
import 'package:pka_home/features/management/screens/management_home_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('ManagementHomeScreen Dashboard hiển thị đầy đủ KPI, tiến độ thu phí và thanh toán gần đây', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final adminUser = UserModel(
      id: 'admin-1',
      fullName: 'Trưởng BQL',
      role: 'admin',
    );

    final mockTransactions = [
      PaymentTransactionModel(
        id: 'tx-1',
        title: 'Hóa đơn tháng 10/2026',
        apartmentId: 'apt-1',
        amount: 1480000.0,
        paymentMethod: 'Demo Payment',
        status: 'SUCCESS',
        transactionCode: 'DEMO-20261005-001',
        createdAt: DateTime(2026, 10, 5, 21, 35),
      ),
      PaymentTransactionModel(
        id: 'tx-2',
        title: 'Sân cầu lông (18:00 - 19:30)',
        apartmentId: 'apt-2',
        amount: 100000.0,
        paymentMethod: 'Demo Payment',
        status: 'SUCCESS',
        transactionCode: 'DEMO-20261005-002',
        createdAt: DateTime(2026, 10, 5, 18, 0),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(adminUser)),
          activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
          pendingLinkRequestsCountProvider.overrideWith((ref) => Stream.value(0)),
          pendingConfirmationInvoicesProvider.overrideWith((ref) => Stream.value(0)),
          pendingIssuesCountProvider.overrideWith((ref) => Stream.value(0)),
          allIssuesProvider.overrideWith((ref) async => []),
          totalResidentsProvider.overrideWith((ref) => Stream.value(356)),
          apartmentsStreamProvider.overrideWith((ref) => Stream.value([])),
          financialStatsProvider.overrideWith((ref) => Stream.value(FinancialStats(
            paidTotal: 82500000.0,
            unpaidTotal: 18000000.0,
            paidCount: 230,
            unpaidCount: 50,
          ))),
          monthlyRevenueTrendProvider.overrideWith((ref) => Stream.value([])),
          paymentTransactionsProvider.overrideWith((ref) => mockTransactions),
        ],
        child: const MaterialApp(
          home: ManagementHomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 1. Kiểm tra tiêu đề và các mục thao tác nhanh
    expect(find.textContaining('Ban Quản Lý'), findsOneWidget);
    expect(find.text('Thao tác nhanh'), findsOneWidget);
    expect(find.text('Duyệt xe'), findsOneWidget);
    expect(find.text('Giao dịch'), findsOneWidget);

    // 2. Kiểm tra khối Thanh toán gần đây
    expect(find.text('Thanh toán gần đây'), findsOneWidget);
    expect(find.textContaining('DEMO-20261005-001'), findsOneWidget);
    expect(find.textContaining('DEMO-20261005-002'), findsOneWidget);
  });
}
