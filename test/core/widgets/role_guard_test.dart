import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/constants/permissions.dart';
import 'package:pka_home/core/widgets/role_guard.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/role_delegation_provider.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget createWidgetUnderTest({
    required UserModel user,
    List<String> delegations = const [],
    required PermissionItem permission,
    Widget? fallback,
  }) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(user)),
        activeDelegationsProvider.overrideWith((ref) => Stream.value(delegations)),
      ],
      child: MaterialApp(
        home: RoleGuard(
          permission: permission,
          fallback: fallback,
          child: const Scaffold(
            body: Text('Protected Content'),
          ),
        ),
      ),
    );
  }

  group('RoleGuard Widget Tests', () {
    testWidgets('renders child when user has allowed role', (tester) async {
      final accountant = UserModel(
        id: 'user-acc',
        fullName: 'Kế toán viên',
        role: 'accountant',
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          user: accountant,
          permission: AppPermissions.invoiceManagement,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protected Content'), findsOneWidget);
      expect(find.text('Không có quyền truy cập'), findsNothing);
    });

    testWidgets('renders access denied screen when user has forbidden role', (tester) async {
      final technician = UserModel(
        id: 'user-tech',
        fullName: 'Kỹ thuật viên',
        role: 'technician',
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          user: technician,
          permission: AppPermissions.invoiceManagement,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protected Content'), findsNothing);
      expect(find.text('Không có quyền truy cập'), findsOneWidget);
      expect(find.textContaining('Quản lý & Lập hóa đơn'), findsWidgets);
      expect(find.textContaining('Kỹ thuật viên'), findsOneWidget);
    });

    testWidgets('renders child when user has temporary delegation', (tester) async {
      final technician = UserModel(
        id: 'user-tech',
        fullName: 'Kỹ thuật viên',
        role: 'technician',
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          user: technician,
          delegations: ['accountant'],
          permission: AppPermissions.invoiceManagement,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protected Content'), findsOneWidget);
      expect(find.text('Không có quyền truy cập'), findsNothing);
    });

    testWidgets('renders fallback widget if provided and unauthorized', (tester) async {
      final resident = UserModel(
        id: 'user-res',
        fullName: 'Cư dân A',
        role: 'resident',
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          user: resident,
          permission: AppPermissions.residentManagement,
          fallback: const Text('Custom Fallback View'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protected Content'), findsNothing);
      expect(find.text('Custom Fallback View'), findsOneWidget);
    });
  });
}
