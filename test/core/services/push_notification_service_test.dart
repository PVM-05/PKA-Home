import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pka_home/core/router/route_names.dart';
import 'package:pka_home/core/services/push_notification_service.dart';
import 'package:pka_home/data/repositories/notification_repository.dart';

class MockNotificationRepository extends Mock implements NotificationRepository {}

void main() {
  late MockNotificationRepository mockRepo;
  late PushNotificationService service;

  setUp(() {
    mockRepo = MockNotificationRepository();
    service = PushNotificationService(mockRepo);
  });

  group('PushNotificationService Route Resolution Tests', () {
    test('resolves new_invoice to resident invoices route', () {
      final route = service.resolveRouteFromNotification({'type': 'new_invoice'});
      expect(route, equals(AppRoutes.residentInvoices));
    });

    test('resolves invoice_due_reminder to resident invoices route', () {
      final route = service.resolveRouteFromNotification({'type': 'invoice_due_reminder'});
      expect(route, equals(AppRoutes.residentInvoices));
    });

    test('resolves equipment_maintenance to resident handbook/interruption route', () {
      final route = service.resolveRouteFromNotification({'type': 'equipment_maintenance'});
      expect(route, equals(AppRoutes.residentHome));
    });

    test('resolves issue_update to resident issues route', () {
      final route = service.resolveRouteFromNotification({'type': 'issue_update'});
      expect(route, equals(AppRoutes.residentIssues));
    });

    test('resolves unknown or empty type to default notifications route', () {
      final route = service.resolveRouteFromNotification({});
      expect(route, equals(AppRoutes.residentNotifications));
    });
  });

  group('PushNotificationService Initialization & Fallback Tests', () {
    test('registerTokenManually calls notification repository registerFcmToken', () async {
      when(() => mockRepo.registerFcmToken(
            userId: any(named: 'userId'),
            token: any(named: 'token'),
            deviceInfo: any(named: 'deviceInfo'),
          )).thenAnswer((_) async {});

      await service.registerTokenManually(
        userId: 'user-123',
        token: 'fcm-token-abc',
        deviceInfo: 'android_test',
      );

      verify(() => mockRepo.registerFcmToken(
            userId: 'user-123',
            token: 'fcm-token-abc',
            deviceInfo: 'android_test',
          )).called(1);
    });

    test('safeInitialize executes gracefully when Firebase is not configured in test environment', () async {
      // In unit test environment, Firebase.initializeApp is not run,
      // safeInitialize should not throw exceptions and instead complete gracefully.
      expect(
        () async => await service.safeInitialize(userId: 'user-123'),
        returnsNormally,
      );
    });
  });
}
