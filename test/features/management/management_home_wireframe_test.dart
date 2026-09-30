import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
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
  final adminUser = UserModel(
    id: 'admin-1',
    fullName: 'Trưởng BQL',
    phone: '0901112233',
    role: 'admin',
  );

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(adminUser)),
        activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
        pendingLinkRequestsCountProvider.overrideWith((ref) => Stream.value(0)),
        pendingConfirmationInvoicesProvider.overrideWith((ref) => Stream.value(0)),
        pendingIssuesCountProvider.overrideWith((ref) => Stream.value(0)),
        allIssuesProvider.overrideWith((ref) async => []),
        totalResidentsProvider.overrideWith((ref) => Stream.value(10)),
        apartmentsStreamProvider.overrideWith((ref) => Stream.value([])),
        financialStatsProvider.overrideWith((ref) => Stream.value(FinancialStats(
          paidTotal: 5000000.0,
          unpaidTotal: 1000000.0,
          paidCount: 5,
          unpaidCount: 1,
        ))),
        monthlyRevenueTrendProvider.overrideWith((ref) => Stream.value([])),
      ],
      child: const MaterialApp(
        home: ManagementHomeScreen(),
      ),
    );
  }

  testWidgets('ManagementHomeScreen hiển thị tiêu đề và nút Đăng xuất theo Wireframe Section 4', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 1. Tiêu đề mục sự cố khẩn cấp: Phản ánh cần xử lý gấp
    expect(find.textContaining('Phản ánh cần xử lý gấp'), findsOneWidget);

    // 2. Tiêu đề mục thống kê: Tổng quan trạng thái
    expect(find.textContaining('Tổng quan trạng thái'), findsOneWidget);

    // 3. Nút Đăng xuất nhanh trên AppBar
    final logoutBtn = find.byTooltip('Đăng xuất');
    expect(logoutBtn, findsOneWidget);

    // 4. Nhấn nút Đăng xuất hiển thị Dialog xác nhận
    await tester.tap(logoutBtn);
    await tester.pumpAndSettle();

    expect(find.text('Bạn có chắc chắn muốn đăng xuất không?'), findsOneWidget);
    expect(find.text('Hủy'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Đăng xuất'), findsOneWidget);
  });
}
