import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/widgets/maintenance_fund_card.dart';
import 'package:pka_home/data/models/maintenance_fund_model.dart';
import 'package:pka_home/data/providers/maintenance_fund_provider.dart';

void main() {
  testWidgets('MaintenanceFundCard renders fund title and expands details on click with real provider data', (tester) async {
    final testFund = MaintenanceFundModel(
      id: 'fund-1',
      totalBalance: 3200000000.0,
      annualInterestEarned: 166400000.0,
      interestRatePercent: 5.2,
      collectedPercent: 99.1,
      bankName: 'Ngân hàng BIDV',
      bankAccountNumber: '0011 0042 88999',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          maintenanceFundProvider.overrideWith((ref) => Future.value(testFund)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MaintenanceFundCard(isManagement: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Kiểm tra hiển thị tiêu đề và số liệu động từ model
    expect(find.text('Quỹ bảo trì 2% sở hữu chung'), findsOneWidget);
    expect(find.text('Theo Điều 108 Luật Nhà ở Việt Nam'), findsOneWidget);
    expect(find.text('99.1%'), findsOneWidget);

    // Chưa mở rộng, không thấy thông tin tài khoản ngân hàng
    expect(find.text('Tài khoản ngân hàng lưu ký'), findsNothing);

    // Nhấn vào icon mở rộng
    final expandButton = find.byType(IconButton);
    expect(expandButton, findsOneWidget);
    await tester.tap(expandButton);
    await tester.pumpAndSettle();

    // Đã mở rộng, hiển thị chi tiết
    expect(find.text('Tài khoản ngân hàng lưu ký'), findsOneWidget);
    expect(find.textContaining('0011 0042 88999'), findsOneWidget);
    expect(find.text('Mục đích sử dụng hợp pháp'), findsOneWidget);
    expect(find.text('Nghiêm cấm theo pháp luật'), findsOneWidget);
  });
}
