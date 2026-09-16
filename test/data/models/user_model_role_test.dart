import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/models/resident_model.dart';

void main() {
  group('UserModel RBAC Role Tests', () {
    test('admin role getters and display name', () {
      final user = UserModel(
        id: 'u1',
        fullName: 'Admin User',
        role: 'admin',
        phone: '0901111111',
      );

      expect(user.isAdmin, isTrue);
      expect(user.isAccountant, isFalse);
      expect(user.isTechnician, isFalse);
      expect(user.isResident, isFalse);
      expect(user.isManagement, isTrue);
      expect(user.roleDisplayName, 'Quản trị viên');
    });

    test('legacy management role is recognized as admin and management', () {
      final user = UserModel(
        id: 'u1_legacy',
        fullName: 'Legacy Mgmt',
        role: 'management',
      );

      expect(user.isAdmin, isTrue);
      expect(user.isManagement, isTrue);
      expect(user.roleDisplayName, 'Quản trị viên');
    });

    test('accountant role getters and display name', () {
      final user = UserModel(
        id: 'u2',
        fullName: 'Accountant User',
        role: 'accountant',
      );

      expect(user.isAdmin, isFalse);
      expect(user.isAccountant, isTrue);
      expect(user.isTechnician, isFalse);
      expect(user.isResident, isFalse);
      expect(user.isManagement, isTrue);
      expect(user.roleDisplayName, 'Kế toán');
    });

    test('technician role getters and display name', () {
      final user = UserModel(
        id: 'u3',
        fullName: 'Tech User',
        role: 'technician',
      );

      expect(user.isAdmin, isFalse);
      expect(user.isAccountant, isFalse);
      expect(user.isTechnician, isTrue);
      expect(user.isResident, isFalse);
      expect(user.isManagement, isTrue);
      expect(user.roleDisplayName, 'Kỹ thuật viên');
    });

    test('resident role getters and display name', () {
      final user = UserModel(
        id: 'u4',
        fullName: 'Resident User',
        role: 'resident',
      );

      expect(user.isAdmin, isFalse);
      expect(user.isAccountant, isFalse);
      expect(user.isTechnician, isFalse);
      expect(user.isResident, isTrue);
      expect(user.isManagement, isFalse);
      expect(user.roleDisplayName, 'Cư dân');
    });
  });

  group('ResidentModel RBAC Role Tests', () {
    test('ResidentModel role methods match role correctly', () {
      final resident = ResidentModel(
        id: 'r1',
        fullName: 'Cư dân Nguyễn',
        phone: '0901234567',
        role: 'resident',
      );

      expect(resident.isResident, isTrue);
      expect(resident.isAdmin, isFalse);
      expect(resident.isAccountant, isFalse);
      expect(resident.isTechnician, isFalse);
      expect(resident.isManagement, isFalse);
      expect(resident.roleDisplayName, 'Cư dân');

      final technician = ResidentModel(
        id: 'r2',
        fullName: 'Kỹ thuật viên Trần',
        role: 'technician',
      );

      expect(technician.isTechnician, isTrue);
      expect(technician.isManagement, isTrue);
      expect(technician.roleDisplayName, 'Kỹ thuật viên');
    });
  });
}
