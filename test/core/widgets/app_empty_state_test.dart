import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/widgets/app_empty_state.dart';

void main() {
  group('AppEmptyState Widget Tests', () {
    testWidgets('render đúng icon, title, description và button khi có action', (tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Chưa có hóa đơn nào',
              description: 'Tất cả các khoản phí sinh hoạt kỳ này đã được thanh toán đầy đủ.',
              actionLabel: 'Làm mới dữ liệu',
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
      expect(find.text('Chưa có hóa đơn nào'), findsOneWidget);
      expect(
        find.text('Tất cả các khoản phí sinh hoạt kỳ này đã được thanh toán đầy đủ.'),
        findsOneWidget,
      );
      expect(find.text('Làm mới dữ liệu'), findsOneWidget);

      await tester.tap(find.text('Làm mới dữ liệu'));
      expect(actionTapped, isTrue);
    });

    testWidgets('render đúng khi không truyền action button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              icon: Icons.notifications_none,
              title: 'Không có thông báo mới',
              description: 'Bạn đã đọc tất cả thông báo từ Ban Quản Lý.',
            ),
          ),
        ),
      );

      expect(find.text('Không có thông báo mới'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });
  });
}

