import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/core/services/push_notification_service.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/repositories/notification_repository.dart';

class FakePushNotificationService extends PushNotificationService {
  String? initializedUserId;
  String? listeningUserId;
  bool isStopped = false;

  FakePushNotificationService() : super(NotificationRepository());

  @override
  Future<void> safeInitialize({required String userId, void Function(String route)? onSelectNotificationRoute}) async {
    initializedUserId = userId;
  }

  @override
  void startRealtimeNotificationListener({required String userId, String? buildingId}) {
    listeningUserId = userId;
    isStopped = false;
  }

  @override
  void stopRealtimeNotificationListener() {
    isStopped = true;
    listeningUserId = null;
  }
}

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel? user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Realtime Notification Sync Provider Tests', () {
    test('Kích hoạt safeInitialize và startRealtimeNotificationListener khi user đăng nhập', () {
      final fakePush = FakePushNotificationService();
      final rootContainer = ProviderContainer(
        overrides: [
          pushNotificationServiceProvider.overrideWithValue(fakePush),
          authProvider.overrideWith((ref) => FakeAuthNotifier(
                UserModel(id: 'usr-123', role: 'resident', fullName: 'Nguyen Van A'),
              )),
        ],
      );

      rootContainer.read(fcmTokenSyncProvider);

      expect(fakePush.initializedUserId, 'usr-123');
      expect(fakePush.listeningUserId, 'usr-123');
      expect(fakePush.isStopped, isFalse);
    });

    test('Gọi stopRealtimeNotificationListener khi user null (đăng xuất)', () {
      final fakePush = FakePushNotificationService();
      final rootContainer = ProviderContainer(
        overrides: [
          pushNotificationServiceProvider.overrideWithValue(fakePush),
          authProvider.overrideWith((ref) => FakeAuthNotifier(null)),
        ],
      );

      rootContainer.read(fcmTokenSyncProvider);

      expect(fakePush.initializedUserId, isNull);
      expect(fakePush.listeningUserId, isNull);
      expect(fakePush.isStopped, isTrue);
    });
  });
}
