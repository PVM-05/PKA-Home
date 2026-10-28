import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/services/push_notification_service.dart';
import 'package:pka_home/data/models/notification_model.dart';
import 'package:pka_home/data/repositories/notification_repository.dart';

class MockNotificationRepository extends NotificationRepository {
  final StreamController<List<NotificationModel>> controller =
      StreamController<List<NotificationModel>>.broadcast();

  MockNotificationRepository() : super();

  @override
  Stream<List<NotificationModel>> streamUserNotifications(String userId, {String? buildingId}) {
    return controller.stream;
  }
}

void main() {
  group('PushNotificationService Realtime Dispatcher Tests', () {
    late MockNotificationRepository mockRepo;
    late PushNotificationService service;

    setUp(() {
      mockRepo = MockNotificationRepository();
      service = PushNotificationService(mockRepo);
    });

    tearDown(() {
      service.dispose();
      mockRepo.controller.close();
    });

    test('startRealtimeNotificationListener lắng nghe và ghi nhận các thông báo mới', () async {
      final sampleNotif = NotificationModel(
        id: 'notif-101',
        userId: 'user-01',
        title: 'Hóa đơn mới',
        body: 'Hóa đơn kỳ 10/2026 đã được phát hành',
        type: 'new_invoice',
        isRead: false,
        createdAt: DateTime.now(),
      );

      service.startRealtimeNotificationListener(userId: 'user-01');

      // Phát thông báo qua stream
      mockRepo.controller.add([sampleNotif]);
      await pumpEventQueue();

      expect(service.seenNotificationIds.contains('notif-101'), isTrue);

      // Hủy lắng nghe
      service.stopRealtimeNotificationListener();
      expect(service.seenNotificationIds.isEmpty, isTrue);
    });

    test('resolveRouteFromNotification điều hướng chính xác theo loại thông báo', () {
      expect(service.resolveRouteFromNotification({'type': 'new_invoice'}), '/resident/invoices');
      expect(service.resolveRouteFromNotification({'type': 'invoice_due_reminder'}), '/resident/invoices');
      expect(service.resolveRouteFromNotification({'type': 'issue_update'}), '/resident/issues');
      expect(service.resolveRouteFromNotification({'type': 'announcement'}), '/resident/handbook');
      expect(service.resolveRouteFromNotification({'type': 'link_request'}), '/resident/notifications');
      expect(service.resolveRouteFromNotification({'type': 'unknown'}), '/resident/notifications');
    });
  });
}
