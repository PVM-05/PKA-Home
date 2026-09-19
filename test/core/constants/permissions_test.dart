import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/constants/permissions.dart';

void main() {
  group('AppPermissions Tests', () {
    test('invoiceManagement allows admin, management, and accountant', () {
      final perm = AppPermissions.invoiceManagement;
      expect(perm.allows('admin'), isTrue);
      expect(perm.allows('management'), isTrue);
      expect(perm.allows('accountant'), isTrue);
      expect(perm.allows('technician'), isFalse);
      expect(perm.allows('resident'), isFalse);
      expect(perm.allows(null), isFalse);
    });

    test('issueManagement allows admin, management, and technician', () {
      final perm = AppPermissions.issueManagement;
      expect(perm.allows('admin'), isTrue);
      expect(perm.allows('management'), isTrue);
      expect(perm.allows('technician'), isTrue);
      expect(perm.allows('accountant'), isFalse);
      expect(perm.allows('resident'), isFalse);
      expect(perm.allows(null), isFalse);
    });

    test('residentManagement and linkRequestManagement allow only admin and management', () {
      expect(AppPermissions.residentManagement.allows('admin'), isTrue);
      expect(AppPermissions.residentManagement.allows('management'), isTrue);
      expect(AppPermissions.residentManagement.allows('accountant'), isFalse);
      expect(AppPermissions.residentManagement.allows('technician'), isFalse);

      expect(AppPermissions.linkRequestManagement.allows('admin'), isTrue);
      expect(AppPermissions.linkRequestManagement.allows('management'), isTrue);
      expect(AppPermissions.linkRequestManagement.allows('accountant'), isFalse);
      expect(AppPermissions.linkRequestManagement.allows('technician'), isFalse);
    });

    test('apartmentManagement, handbookManagement, roleDelegation allow only admin and management', () {
      final adminOnly = [
        AppPermissions.apartmentManagement,
        AppPermissions.handbookManagement,
        AppPermissions.roleDelegation,
      ];

      for (final perm in adminOnly) {
        expect(perm.allows('admin'), isTrue);
        expect(perm.allows('management'), isTrue);
        expect(perm.allows('accountant'), isFalse);
        expect(perm.allows('technician'), isFalse);
        expect(perm.allows('resident'), isFalse);
      }
    });

    test('activeDelegations temporarily extends permissions', () {
      // Kỹ thuật viên bình thường không vào được hóa đơn
      expect(AppPermissions.invoiceManagement.allows('technician'), isFalse);

      // Khi có ủy quyền 'accountant' hợp lệ, được phép vào hóa đơn
      expect(
        AppPermissions.invoiceManagement.allows('technician', activeDelegations: ['accountant']),
        isTrue,
      );

      // Khi có ủy quyền không liên quan (ví dụ 'other'), vẫn bị chặn
      expect(
        AppPermissions.invoiceManagement.allows('technician', activeDelegations: ['other']),
        isFalse,
      );
    });

    test('AppPermissions.all contains all 7 permissions with valid metadata', () {
      expect(AppPermissions.all.length, equals(7));
      for (final item in AppPermissions.all) {
        expect(item.key.isNotEmpty, isTrue);
        expect(item.name.isNotEmpty, isTrue);
        expect(item.category.isNotEmpty, isTrue);
        expect(item.description.isNotEmpty, isTrue);
        expect(item.allowedRoles.isNotEmpty, isTrue);
      }
    });
  });
}
