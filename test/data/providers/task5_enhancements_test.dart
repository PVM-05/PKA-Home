import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/user_model.dart';

void main() {
  group('Task 5 Enhancements Tests', () {
    test('UserModel isLocked property behaves correctly', () {
      final activeUser = UserModel(
        id: 'u1',
        fullName: 'Nguyen Van A',
        role: 'resident',
        isLocked: false,
      );
      expect(activeUser.isLocked, isFalse);

      final lockedUser = UserModel(
        id: 'u2',
        fullName: 'Tran Van B',
        role: 'resident',
        isLocked: true,
      );
      expect(lockedUser.isLocked, isTrue);
    });

    test('Source code check: AuthNotifier handles isLocked and cancels stream on dispose', () {
      final file = File('lib/data/providers/auth_provider.dart');
      final content = file.readAsStringSync();

      expect(content.contains('isLocked'), isTrue, reason: 'AuthNotifier must check isLocked');
      expect(content.contains('dispose()'), isTrue, reason: 'AuthNotifier must implement dispose');
      expect(content.contains('cancel()'), isTrue, reason: 'AuthNotifier must cancel stream subscription');
    });

    test('Source code check: createApartment normalizes code to uppercase', () {
      final file = File('lib/data/repositories/management_repository.dart');
      final content = file.readAsStringSync();

      expect(content.contains('toUpperCase()'), isTrue, reason: 'createApartment must uppercase apartment code');
    });

    test('Source code check: NotificationCard uses Theme cardColor instead of hardcoded white', () {
      final file = File('lib/features/resident/widgets/notification_card.dart');
      final content = file.readAsStringSync();

      expect(content.contains('Theme.of(context).cardColor'), isTrue, reason: 'NotificationCard must adapt to Dark mode');
      expect(content.contains('color: Colors.white,'), isFalse, reason: 'Must not hardcode white');
    });

    test('Source code check: financialStatsProvider computes stats on currentInvoices', () {
      final file = File('lib/data/providers/dashboard_providers.dart');
      final content = file.readAsStringSync();

      // Ensure paid and unpaid loop over currentInvoices
      expect(content.contains('for (var inv in currentInvoices)'), isTrue, reason: 'Must compute paid/unpaid on current period invoices');
    });
  });
}
