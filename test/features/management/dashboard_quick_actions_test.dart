import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/dashboard_providers.dart';
import 'package:pka_home/data/providers/management_provider.dart';
import 'package:pka_home/data/providers/role_delegation_provider.dart';
import 'package:pka_home/data/providers/payment_provider.dart';
import 'package:pka_home/features/management/screens/management_home_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('A1: Dashboard hiển thị các lối tắt chính và nút Xem tất cả mở Modal Bottom Sheet', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final adminUser = UserModel(
      id: 'admin-1',
      fullName: 'Trưởng BQL',
      role: 'admin',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(adminUser)),
          activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
          pendingLinkRequestsCountProvider.overrideWith((ref) => Stream.value(3)),
          pendingConfirmationInvoicesProvider.overrideWith((ref) => Stream.value(0)),
          pendingIssuesCountProvider.overrideWith((ref) => Stream.value(2)),
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
          paymentTransactionsProvider.overrideWith((ref) => []),
        ],
        child: const MaterialApp(
          home: ManagementHomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 1. Kiểm tra tiêu đề Thao tác nhanh
    expect(find.text('Thao tác nhanh'), findsOneWidget);

    // 2. Chạm nút "Xem tất cả" để mở Modal Bottom Sheet
    final seeAllBtn = find.widgetWithText(TextButton, 'Xem tất cả').first;
    expect(seeAllBtn, findsOneWidget);
    await tester.tap(seeAllBtn);
    await tester.pumpAndSettle();

    // 3. Xác nhận Bottom Sheet hiển thị với 3 nhóm phân loại
    expect(find.text('Tất cả thao tác quản trị'), findsOneWidget);
    expect(find.text('Cư dân & Căn hộ'), findsWidgets);
    expect(find.text('Tài chính & Thu phí'), findsWidgets);
    expect(find.text('Vận hành & Kỹ thuật'), findsWidgets);
  });
}
