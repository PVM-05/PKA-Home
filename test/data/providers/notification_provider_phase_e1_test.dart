import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/notification_model.dart';
import 'package:pka_home/data/providers/notification_provider.dart';

void main() {
  group('NotificationProvider Phase E1 Filter Tests', () {
    test('filteredNotificationsProvider lọc đúng theo filterType', () async {
      final sampleNotifications = [
        NotificationModel(
          id: '1',
          userId: 'u1',
          title: 'Hóa đơn tháng 10',
          body: 'Sắp đến hạn',
          type: 'invoice_due_soon',
          isRead: false,
          createdAt: DateTime.now(),
        ),
        NotificationModel(
          id: '2',
          userId: 'u1',
          title: 'Họp cư dân',
          body: 'Tất cả cư dân',
          type: 'announcement',
          isRead: true,
          createdAt: DateTime.now(),
        ),
        NotificationModel(
          id: '3',
          userId: 'u1',
          title: 'Hóa đơn tháng 9',
          body: 'Đã quá hạn',
          type: 'invoice_overdue',
          isRead: true,
          createdAt: DateTime.now(),
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          notificationsStreamProvider.overrideWith((ref) => Stream.value(sampleNotifications)),
        ],
      );
      addTearDown(container.dispose);

      // Đợi StreamProvider nhận dữ liệu đầu tiên
      await container.read(notificationsStreamProvider.future);

      // Default: ALL
      expect(container.read(notificationFilterTypeProvider), equals('ALL'));
      expect(container.read(filteredNotificationsProvider).length, equals(3));

      // UNREAD
      container.read(notificationFilterTypeProvider.notifier).state = 'UNREAD';
      expect(container.read(filteredNotificationsProvider).length, equals(1));
      expect(container.read(filteredNotificationsProvider).first.id, equals('1'));

      // INVOICE
      container.read(notificationFilterTypeProvider.notifier).state = 'INVOICE';
      expect(container.read(filteredNotificationsProvider).length, equals(2));

      // BUILDING
      container.read(notificationFilterTypeProvider.notifier).state = 'BUILDING';
      expect(container.read(filteredNotificationsProvider).length, equals(1));
      expect(container.read(filteredNotificationsProvider).first.id, equals('2'));
    });
  });
}
