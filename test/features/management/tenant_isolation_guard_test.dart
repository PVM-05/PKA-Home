import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/constants/permissions.dart';
import 'package:pka_home/core/widgets/role_guard.dart';
import 'package:pka_home/data/models/building_membership_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/role_delegation_provider.dart';
import 'package:pka_home/data/repositories/membership_repository.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Tenant Isolation & Context-Aware RBAC Tests', () {
    test('PermissionItem.allows cho phép khi buildingRoles khớp vai trò được cấp phép', () {
      const permission = AppPermissions.invoiceManagement; // ['admin', 'management', 'accountant']

      // Cư dân bình thường toàn cục nhưng là Kế toán tại tòa A
      final hasAccessBuildingA = permission.allows(
        'resident',
        buildingRoles: ['accountant'],
      );
      expect(hasAccessBuildingA, isTrue);

      // Tại tòa B chỉ là cư dân bình thường
      final hasAccessBuildingB = permission.allows(
        'resident',
        buildingRoles: ['resident'],
      );
      expect(hasAccessBuildingB, isFalse);
    });

    testWidgets('RoleGuard cho phép truy cập khi người dùng có building membership kế toán tại tòa nhà được chỉ định',
        (tester) async {
      final residentUser = UserModel(
        id: 'user-001',
        fullName: 'Nguyễn Văn Kế Toán',
        phone: '0987654321',
        role: 'resident', // vai trò toàn cục là cư dân
      );

      final buildingAMembership = BuildingMembershipModel(
        id: 'bm-001',
        buildingId: 'bld-A',
        userId: 'user-001',
        buildingRole: 'accountant',
        isActive: true,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(residentUser)),
            activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
            userBuildingMembershipsProvider('user-001').overrideWith(
              (ref) async => [buildingAMembership],
            ),
          ],
          child: const MaterialApp(
            home: RoleGuard(
              permission: AppPermissions.invoiceManagement,
              buildingId: 'bld-A',
              child: Text('NỘI DUNG QUẢN LÝ HÓA ĐƠN TÒA A'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Cho phép hiển thị nội dung quản trị
      expect(find.text('NỘI DUNG QUẢN LÝ HÓA ĐƠN TÒA A'), findsOneWidget);
      expect(find.text('Không có quyền truy cập'), findsNothing);
    });

    testWidgets('RoleGuard chặn truy cập khi người dùng mở tòa nhà mà họ không có quyền kế toán',
        (tester) async {
      final residentUser = UserModel(
        id: 'user-001',
        fullName: 'Nguyễn Văn Kế Toán',
        phone: '0987654321',
        role: 'resident',
      );

      // Chỉ có quyền tại tòa A, không có quyền tại tòa B
      final buildingAMembership = BuildingMembershipModel(
        id: 'bm-001',
        buildingId: 'bld-A',
        userId: 'user-001',
        buildingRole: 'accountant',
        isActive: true,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(residentUser)),
            activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
            userBuildingMembershipsProvider('user-001').overrideWith(
              (ref) async => [buildingAMembership],
            ),
          ],
          child: const MaterialApp(
            home: RoleGuard(
              permission: AppPermissions.invoiceManagement,
              buildingId: 'bld-B', // Kiểm tra tòa B
              child: Text('NỘI DUNG QUẢN LÝ HÓA ĐƠN TÒA B'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Chặn truy cập và hiển thị màn hình cảnh báo
      expect(find.text('NỘI DUNG QUẢN LÝ HÓA ĐƠN TÒA B'), findsNothing);
      expect(find.text('Không có quyền truy cập'), findsOneWidget);
    });
  });
}
