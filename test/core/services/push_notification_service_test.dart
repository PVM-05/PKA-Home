import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/router/route_names.dart';
import 'package:pka_home/core/services/push_notification_service.dart';
import 'package:pka_home/data/models/notification_model.dart';
import 'package:pka_home/data/repositories/notification_repository.dart';

class MockNotificationRepository implements NotificationRepository {
  List<NotificationModel> mockNotifications = [];

  @override
  Stream<List<NotificationModel>> streamUserNotifications(
    String userId, {
    String? buildingId,
  }) {
    return Stream.value(mockNotifications);
  }

  @override
  Future<List<NotificationModel>> getNotifications(
    String userId, {
    String? buildingId,
  }) async {
    return mockNotifications;
  }

  @override
  Future<void> markAsRead(String notificationId) async {}

  @override
  Future<void> markAllAsRead(String userId) async {}

  @override
  Future<void> registerFcmToken({
    required String userId,
    required String token,
    String? deviceInfo,
  }) async {}

  @override
  Future<int> triggerInvoiceRemindersScan({String? buildingId}) async => 0;
}

void main() {
  group('PushNotificationService Deep-Linking & Route Tests', () {
    late PushNotificationService service;
    late MockNotificationRepository mockRepo;

    setUp(() {
      mockRepo = MockNotificationRepository();
      service = PushNotificationService(mockRepo);
    });

    test('resolveRouteFromNotification điều hướng chính xác từng loại thông báo', () {
      expect(
        service.resolveRouteFromNotification({'type': 'new_invoice'}),
        equals(AppRoutes.residentInvoices),
      );

      expect(
        service.resolveRouteFromNotification({'type': 'invoice_due_reminder'}),
        equals(AppRoutes.residentInvoices),
      );

      expect(
        service.resolveRouteFromNotification({'type': 'issue_update'}),
        equals(AppRoutes.residentIssues),
      );

      expect(
        service.resolveRouteFromNotification({'type': 'equipment_maintenance'}),
        equals(AppRoutes.residentHome),
      );

      expect(
        service.resolveRouteFromNotification({'type': 'announcement'}),
        equals(AppRoutes.residentHandbook),
      );

      expect(
        service.resolveRouteFromNotification({'type': 'unknown'}),
        equals(AppRoutes.residentNotifications),
      );

      expect(
        service.resolveRouteFromNotification({}),
        equals(AppRoutes.residentNotifications),
      );
    });

    test('startRealtimeNotificationListener không bắn thông báo cho các thông báo cũ trước mốc mở app', () async {
      final oldNotif = NotificationModel(
        id: 'notif-old-1',
        userId: 'usr-1',
        title: 'Hóa đơn tháng trước',
        body: 'Nội dung thông báo cũ',
        type: 'new_invoice',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );

      mockRepo.mockNotifications = [oldNotif];

      // Kích hoạt listener
      service.startRealtimeNotificationListener(userId: 'usr-1');

      // Chờ stream emit
      await Future.delayed(const Duration(milliseconds: 50));

      // ID đã được ghi nhận vào seenNotificationIds để không bị lặp
      expect(service.seenNotificationIds.contains('notif-old-1'), isTrue);

      service.stopRealtimeNotificationListener();
    });
  });
}
