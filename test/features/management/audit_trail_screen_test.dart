import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/features/management/screens/audit_trail_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AuditTrailScreen Widget Tests', () {
    final testAdmin = UserModel(
      id: 'admin-1',
      role: 'admin',
      fullName: 'Quan Tri Vien Admin',
    );

    final mockLogs = [
      AuditLogItem(
        title: 'Xác nhận thu tiền hóa đơn',
        subtitle: 'Đã xác nhận thu tiền thành công qua vietqr.',
        updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        icon: Icons.receipt_long_outlined,
        color: Colors.green,
        category: 'invoice',
        performerName: 'Kế toán viên',
      ),
      AuditLogItem(
        title: 'Cập nhật phê duyệt thẻ xe',
        subtitle: 'Biển số 29A1-12345: Đã duyệt.',
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        icon: Icons.directions_car_outlined,
        color: Colors.green,
        category: 'vehicle',
        performerName: 'Quản trị viên',
      ),
      AuditLogItem(
        title: 'Thiết lập ủy quyền vai trò',
        subtitle: 'Cấp quyền [accountant] có thời hạn.',
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        icon: Icons.admin_panel_settings_outlined,
        color: Colors.blue,
        category: 'rbac',
        performerName: 'Admin',
      ),
    ];

    testWidgets('Hiển thị tiêu đề, các filter chips và danh sách nhật ký kiểm toán', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(testAdmin)),
            auditTrailProvider.overrideWith((ref) => Future.value(mockLogs)),
          ],
          child: const MaterialApp(
            home: AuditTrailScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề
      expect(find.text('Lịch sử Hoạt động'), findsOneWidget);

      // Kiểm tra các filter chips
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.text('Hóa đơn'), findsOneWidget);
      expect(find.text('Thẻ xe'), findsOneWidget);
      expect(find.text('Phân quyền'), findsOneWidget);

      // Kiểm tra nội dung nhật ký
      expect(find.text('Xác nhận thu tiền hóa đơn'), findsOneWidget);
      expect(find.text('Cập nhật phê duyệt thẻ xe'), findsOneWidget);
      expect(find.text('Thiết lập ủy quyền vai trò'), findsOneWidget);
    });

    testWidgets('Lọc danh mục khi bấm vào chip Thẻ xe', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(testAdmin)),
            auditTrailProvider.overrideWith((ref) => Future.value(mockLogs)),
          ],
          child: const MaterialApp(
            home: AuditTrailScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Bấm vào chip Thẻ xe
      await tester.tap(find.text('Thẻ xe'));
      await tester.pumpAndSettle();

      // Chỉ hiển thị thẻ xe, không hiển thị hóa đơn
      expect(find.text('Cập nhật phê duyệt thẻ xe'), findsOneWidget);
      expect(find.text('Xác nhận thu tiền hóa đơn'), findsNothing);
    });
  });
}
