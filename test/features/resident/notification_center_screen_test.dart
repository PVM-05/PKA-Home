import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/notification_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/notification_provider.dart';
import 'package:pka_home/features/resident/screens/notification_center_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testUser = UserModel(
    id: 'user-notif-1',
    fullName: 'Lê Văn B',
    phone: '0912345678',
    role: 'resident',
  );

  final sampleNotifications = [
    NotificationModel(
      id: 'notif-1',
      userId: 'user-notif-1',
      title: 'Hóa đơn mới kỳ 10/2026',
      body: 'Căn hộ A0110 có hóa đơn mới 1.500.000 đ',
      type: 'new_invoice',
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    NotificationModel(
      id: 'notif-2',
      userId: 'user-notif-1',
      title: 'Bảo trì thiết bị: Thang máy A1',
      body: 'Thang máy A1 tạm gián đoạn dịch vụ từ 14:00 đến 16:00.',
      type: 'equipment_maintenance',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    NotificationModel(
      id: 'notif-3',
      userId: 'user-notif-1',
      title: 'Sự cố đã được tiếp nhận xử lý',
      body: 'Phản ánh sự cố đường ống nước đã được tiếp nhận.',
      type: 'issue_update',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  Widget createTestWidget({List<NotificationModel>? notifications}) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
        notificationsStreamProvider.overrideWith((ref) => Stream.value(notifications ?? [])),
      ],
      child: const MaterialApp(
        home: NotificationCenterScreen(),
      ),
    );
  }

  group('NotificationCenterScreen Tests', () {
    testWidgets('renders empty state when there are no notifications', (tester) async {
      await tester.pumpWidget(createTestWidget(notifications: []));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có thông báo nào'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    });

    testWidgets('renders new_invoice, equipment_maintenance, and issue_update notifications',
        (tester) async {
      await tester.pumpWidget(createTestWidget(notifications: sampleNotifications));
      await tester.pumpAndSettle();

      expect(find.text('Hóa đơn mới kỳ 10/2026'), findsOneWidget);
      expect(find.text('Bảo trì thiết bị: Thang máy A1'), findsOneWidget);
      expect(find.text('Sự cố đã được tiếp nhận xử lý'), findsOneWidget);

      expect(find.text('Căn hộ A0110 có hóa đơn mới 1.500.000 đ'), findsOneWidget);
      expect(find.text('Thang máy A1 tạm gián đoạn dịch vụ từ 14:00 đến 16:00.'), findsOneWidget);
      expect(find.text('Phản ánh sự cố đường ống nước đã được tiếp nhận.'), findsOneWidget);
    });
  });
}
