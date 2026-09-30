import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/role_delegation_provider.dart';
import 'package:pka_home/data/providers/dashboard_providers.dart';
import 'package:pka_home/data/providers/management_provider.dart';
import 'package:pka_home/features/management/screens/management_home_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('ManagementHomeScreen hiển thị tab Hóa đơn khi user có ủy quyền accountant', (tester) async {
    final technicianUser = UserModel(
      id: 'tech-user-1',
      fullName: 'Kỹ thuật viên A',
      phone: '0901234567',
      role: 'technician',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(technicianUser)),
          // Có ủy quyền accountant đang hoạt động
          activeDelegationsProvider.overrideWith((ref) => Stream.value(['accountant'])),
          pendingLinkRequestsCountProvider.overrideWith((ref) => Stream.value(0)),
          pendingConfirmationInvoicesProvider.overrideWith((ref) => Stream.value(0)),
          pendingIssuesCountProvider.overrideWith((ref) => Stream.value(0)),
          allIssuesProvider.overrideWith((ref) async => []),
          totalResidentsProvider.overrideWith((ref) => Stream.value(10)),
          apartmentsStreamProvider.overrideWith((ref) => Stream.value([
            {'id': 'apt-1', 'code': 'A0101', 'is_empty': false},
          ])),
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
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Do có ủy quyền accountant, tab 'Hóa đơn' phải xuất hiện
    expect(find.text('Hóa đơn'), findsWidgets);
    // Kỹ thuật viên cũng có tab 'Phản ánh'
    expect(find.text('Phản ánh'), findsWidgets);
  });

  testWidgets('ManagementHomeScreen áp dụng fail-closed: không hiển thị Quick Action của Admin cho technician', (tester) async {
    final technicianUser = UserModel(
      id: 'tech-user-2',
      fullName: 'Kỹ thuật viên B',
      phone: '0901234568',
      role: 'technician',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(technicianUser)),
          activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
          pendingLinkRequestsCountProvider.overrideWith((ref) => Stream.value(0)),
          pendingConfirmationInvoicesProvider.overrideWith((ref) => Stream.value(0)),
          pendingIssuesCountProvider.overrideWith((ref) => Stream.value(0)),
          allIssuesProvider.overrideWith((ref) async => []),
          totalResidentsProvider.overrideWith((ref) => Stream.value(10)),
          apartmentsStreamProvider.overrideWith((ref) => Stream.value([])),
          financialStatsProvider.overrideWith((ref) => Stream.value(FinancialStats(
            paidTotal: 0.0,
            unpaidTotal: 0.0,
            paidCount: 0,
            unpaidCount: 0,
          ))),
          monthlyRevenueTrendProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: ManagementHomeScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Không phải admin và không có ủy quyền: không được thấy nút "Duyệt liên kết" hay "Ủy quyền"
    expect(find.text('Duyệt liên kết'), findsNothing);
    expect(find.text('Ủy quyền'), findsNothing);
    // Cũng không thấy tab 'Hóa đơn'
    expect(find.text('Hóa đơn'), findsNothing);
    // Nhưng vẫn thấy tab 'Phản ánh'
    expect(find.text('Phản ánh'), findsWidgets);
  });
}
