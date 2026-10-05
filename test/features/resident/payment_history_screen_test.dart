import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/payment_transaction_model.dart';
import 'package:pka_home/data/providers/payment_provider.dart';
import 'package:pka_home/features/resident/screens/payment_history_screen.dart';

void main() {
  testWidgets('PaymentHistoryScreen hiển thị danh sách giao dịch và lọc theo tab Hóa đơn / Dịch vụ', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockTransactions = [
      PaymentTransactionModel(
        id: 'tx-1',
        invoiceId: 'inv-1',
        type: 'INVOICE',
        title: 'Hóa đơn tháng 10/2026',
        apartmentId: 'apt-1',
        amount: 1480000.0,
        paymentMethod: 'Demo Payment',
        status: 'SUCCESS',
        transactionCode: 'DEMO-20261005-0001',
        createdAt: DateTime(2026, 10, 5, 22, 15),
      ),
      PaymentTransactionModel(
        id: 'tx-2',
        bookingId: 'bk-1',
        type: 'SERVICE',
        title: 'Sân cầu lông (18:00 - 19:30)',
        apartmentId: 'apt-1',
        amount: 100000.0,
        paymentMethod: 'Demo Payment',
        status: 'SUCCESS',
        transactionCode: 'DEMO-20261005-0002',
        createdAt: DateTime(2026, 10, 3, 18, 0),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentTransactionsProvider.overrideWith((ref) => mockTransactions),
        ],
        child: const MaterialApp(
          home: PaymentHistoryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Kiểm tra tiêu đề và bộ lọc
    expect(find.text('Lịch sử thanh toán'), findsOneWidget);
    expect(find.text('Tất cả (2)'), findsOneWidget);
    expect(find.text('Hóa đơn (1)'), findsOneWidget);
    expect(find.text('Dịch vụ (1)'), findsOneWidget);

    // 2. Tab Tất cả hiển thị cả 2 giao dịch
    expect(find.text('Hóa đơn tháng 10/2026'), findsOneWidget);
    expect(find.text('Sân cầu lông (18:00 - 19:30)'), findsOneWidget);
    expect(find.text('DEMO-20261005-0001'), findsOneWidget);
    expect(find.text('DEMO-20261005-0002'), findsOneWidget);

    // 3. Chuyển sang tab Hóa đơn
    await tester.tap(find.text('Hóa đơn (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Hóa đơn tháng 10/2026'), findsOneWidget);
    expect(find.text('Sân cầu lông (18:00 - 19:30)'), findsNothing);

    // 4. Chuyển sang tab Dịch vụ
    await tester.tap(find.text('Dịch vụ (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Sân cầu lông (18:00 - 19:30)'), findsOneWidget);
    expect(find.text('Hóa đơn tháng 10/2026'), findsNothing);
  });
}
