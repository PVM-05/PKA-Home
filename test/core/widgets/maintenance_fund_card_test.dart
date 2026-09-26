import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/widgets/maintenance_fund_card.dart';

void main() {
  testWidgets('MaintenanceFundCard renders fund title and expands details on click', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MaintenanceFundCard(isManagement: true),
          ),
        ),
      ),
    );

    // Kiểm tra hiển thị tiêu đề và số liệu
    expect(find.text('Quỹ bảo trì 2% sở hữu chung'), findsOneWidget);
    expect(find.text('Theo Điều 108 Luật Nhà ở Việt Nam'), findsOneWidget);
    expect(find.text('98.5%'), findsOneWidget);

    // Chưa mở rộng, không thấy thông tin tài khoản ngân hàng
    expect(find.text('Tài khoản ngân hàng lưu ký'), findsNothing);

    // Nhấn vào icon mở rộng
    final expandButton = find.byType(IconButton);
    expect(expandButton, findsOneWidget);
    await tester.tap(expandButton);
    await tester.pumpAndSettle();

    // Đã mở rộng, hiển thị chi tiết
    expect(find.text('Tài khoản ngân hàng lưu ký'), findsOneWidget);
    expect(find.text('Mục đích sử dụng hợp pháp'), findsOneWidget);
    expect(find.text('Nghiêm cấm theo pháp luật'), findsOneWidget);
  });
}
