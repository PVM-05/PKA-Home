import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/data/models/role_delegation_model.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/role_delegation_provider.dart';
import 'package:vivona/features/management/screens/permission_matrix_screen.dart';
import 'package:vivona/features/management/screens/role_delegation_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testAdmin = UserModel(
    id: 'admin-1',
    fullName: 'Trưởng BQL PKA',
    role: 'admin',
  );

  final mockDelegations = [
    RoleDelegationModel(
      id: 'del-1',
      delegatorId: 'admin-1',
      delegateId: 'user-2',
      delegatedRole: 'accountant',
      startsAt: DateTime.now().subtract(const Duration(hours: 1)),
      endsAt: DateTime.now().add(const Duration(days: 2)),
      note: 'Kế toán trưởng đi công tác đột xuất 2 ngày',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      delegateName: 'Lê Văn Kế Toán Phó',
      delegatorName: 'Trưởng BQL PKA',
    ),
    RoleDelegationModel(
      id: 'del-2',
      delegatorId: 'admin-1',
      delegateId: 'user-3',
      delegatedRole: 'technician',
      startsAt: DateTime.now().subtract(const Duration(days: 5)),
      endsAt: DateTime.now().subtract(const Duration(days: 2)),
      note: 'Ủy quyền trực ca bảo dưỡng máy phát',
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
      delegateName: 'Trần Văn Kỹ Thuật Viên',
      delegatorName: 'Trưởng BQL PKA',
    ),
  ];

  Widget buildPermissionMatrixWidget({required Size screenSize, double textScale = 1.0}) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testAdmin)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: screenSize,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const PermissionMatrixScreen(),
        ),
      ),
    );
  }

  Widget buildRoleDelegationWidget({required Size screenSize, double textScale = 1.0}) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testAdmin)),
        delegationsListProvider.overrideWith((ref) => Future.value(mockDelegations)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: screenSize,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const RoleDelegationScreen(),
        ),
      ),
    );
  }

  group('Governance Screens Responsive & Anti-RenderFlex Tests', () {
    testWidgets('PermissionMatrixScreen renders safely on 320dp mobile with 1.3x text zoom', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildPermissionMatrixWidget(screenSize: const Size(320, 600), textScale: 1.3));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Bảng Ma Trận Phân Quyền'), findsOneWidget);
      expect(find.text('Kiến Trúc Bảo Mật Phòng Thủ 2 Lớp'), findsOneWidget);
    });

    testWidgets('PermissionMatrixScreen renders centered on 1200dp desktop width', (tester) async {
      tester.view.physicalSize = const Size(1200 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildPermissionMatrixWidget(screenSize: const Size(1200, 800)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Bảng Ma Trận Phân Quyền'), findsOneWidget);
    });

    testWidgets('RoleDelegationScreen renders safely on 320dp mobile with 1.3x text zoom', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildRoleDelegationWidget(screenSize: const Size(320, 600), textScale: 1.3));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Quản Lý Ủy Quyền'), findsOneWidget);
      expect(find.text('Người nhận: Lê Văn Kế Toán Phó'), findsOneWidget);
    });

    testWidgets('RoleDelegationScreen renders centered on 1200dp desktop width', (tester) async {
      tester.view.physicalSize = const Size(1200 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildRoleDelegationWidget(screenSize: const Size(1200, 800)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Quản Lý Ủy Quyền'), findsOneWidget);
    });
  });
}
