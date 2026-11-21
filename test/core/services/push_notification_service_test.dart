import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/router/route_names.dart';
import 'package:vivona/core/services/push_notification_service.dart';
import 'package:vivona/data/models/notification_model.dart';
import 'package:vivona/data/repositories/notification_repository.dart';

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

    test('resolveRouteFromNotification điều hướng chính xác từng loại thông báo cho cư dân', () {
      service.setCurrentUserRole('resident');
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
        service.resolveRouteFromNotification({'type': 'meter_reading'}),
        equals(AppRoutes.residentMeterReading),
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

    test('resolveRouteFromNotification cho Ban Quản Lý / Staff / Admin điều hướng về phân hệ quản trị, không kẹt màn cư dân', () {
      for (final role in ['admin', 'management', 'staff', 'accountant', 'technician']) {
        service.setCurrentUserRole(role);

        expect(
          service.resolveRouteFromNotification({'type': 'new_invoice'}),
          equals(AppRoutes.managementInvoices),
          reason: 'Role $role hóa đơn phải về /management/invoices',
        );

        expect(
          service.resolveRouteFromNotification({'type': 'invoice_due_reminder'}),
          equals(AppRoutes.managementInvoices),
          reason: 'Role $role nhắc nợ phải về /management/invoices',
        );

        expect(
          service.resolveRouteFromNotification({'type': 'issue_update'}),
          equals(AppRoutes.managementIssues),
          reason: 'Role $role sự cố phải về /management/issues',
        );

        expect(
          service.resolveRouteFromNotification({'type': 'equipment_maintenance'}),
          equals(AppRoutes.managementEquipment),
          reason: 'Role $role thiết bị phải về /management/equipment',
        );

        expect(
          service.resolveRouteFromNotification({'type': 'announcement'}),
          equals(AppRoutes.managementAnnouncements),
          reason: 'Role $role thông báo phải về /management/announcements',
        );

        expect(
          service.resolveRouteFromNotification({'type': 'meter_reading'}),
          equals(AppRoutes.managementMeterReading),
          reason: 'Role $role chỉ số điện nước phải về /management/meter-readings',
        );

        expect(
          service.resolveRouteFromNotification({'type': 'vehicle_approval'}),
          equals(AppRoutes.managementVehicleApproval),
          reason: 'Role $role duyệt xe phải về /management/vehicle-approval',
        );

        expect(
          service.resolveRouteFromNotification({'type': 'link_request'}),
          equals(AppRoutes.managementLinkRequests),
          reason: 'Role $role liên kết căn hộ phải về /management/link-requests',
        );

        expect(
          service.resolveRouteFromNotification({'type': 'unknown'}),
          equals(AppRoutes.managementHome),
          reason: 'Role $role thông báo chung phải về /management',
        );
      }
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
