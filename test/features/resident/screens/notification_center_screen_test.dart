import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  group('NotificationCenterScreen Widget Tests', () {
    testWidgets('Hiển thị đầy đủ các bộ lọc và danh sách thông báo', (tester) async {
      final sampleNotifications = [
        NotificationModel(
          id: 'n1',
          userId: 'u1',
          title: 'Hóa đơn tháng 10',
          body: 'Hóa đơn căn hộ A0110 sắp đến hạn',
          type: 'invoice_due_soon',
          isRead: false,
          createdAt: DateTime.now(),
        ),
        NotificationModel(
          id: 'n2',
          userId: 'u1',
          title: 'Thông báo cắt nước',
          body: 'Bảo trì đường ống nước',
          type: 'announcement',
          isRead: true,
          createdAt: DateTime.now(),
        ),
      ];

      final user = UserModel(
        id: 'u1',
        fullName: 'Nguyễn Văn A',
        phone: '0901234567',
        role: 'resident',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(user)),
            notificationsStreamProvider.overrideWith((ref) => Stream.value(sampleNotifications)),
          ],
          child: const MaterialApp(
            home: NotificationCenterScreen(),
          ),
        ),
      );

      // Chờ stream emit
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề AppBar
      expect(find.text('Thông báo & Nhắc nhở'), findsOneWidget);

      // Kiểm tra sự xuất hiện của các Filter Chips
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Chưa đọc'), findsOneWidget);
      expect(find.text('Hóa đơn & Phí'), findsOneWidget);
      expect(find.text('Tòa nhà'), findsOneWidget);

      // Kiểm tra danh sách hiển thị thông báo
      expect(find.text('Hóa đơn tháng 10'), findsOneWidget);
      expect(find.text('Thông báo cắt nước'), findsOneWidget);

      // Chuyển sang tab "Chưa đọc"
      await tester.tap(find.text('Chưa đọc'));
      await tester.pumpAndSettle();

      // Chỉ thông báo chưa đọc hiển thị
      expect(find.text('Hóa đơn tháng 10'), findsOneWidget);
      expect(find.text('Thông báo cắt nước'), findsNothing);
    });
  });
}
