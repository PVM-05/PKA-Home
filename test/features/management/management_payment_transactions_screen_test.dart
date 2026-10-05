import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/payment_transaction_model.dart';
import 'package:pka_home/data/providers/payment_provider.dart';
import 'package:pka_home/features/management/screens/management_payment_transactions_screen.dart';

void main() {
  testWidgets('ManagementPaymentTransactionsScreen hiển thị danh sách đối soát giao dịch và bộ lọc', (tester) async {
    final mockTransactions = [
      PaymentTransactionModel(
        id: 'tx-1',
        title: 'Hóa đơn tháng 10/2026',
        type: 'INVOICE',
        apartmentId: 'apt-1',
        amount: 1480000.0,
        paymentMethod: 'Demo Payment',
        status: 'SUCCESS',
        transactionCode: 'DEMO-20261005-001',
        createdAt: DateTime(2026, 10, 5, 21, 35),
      ),
      PaymentTransactionModel(
        id: 'tx-2',
        title: 'Sân cầu lông (18:00 - 19:30)',
        type: 'SERVICE',
        apartmentId: 'apt-2',
        amount: 100000.0,
        paymentMethod: 'Demo Payment',
        status: 'SUCCESS',
        transactionCode: 'DEMO-20261005-002',
        createdAt: DateTime(2026, 10, 5, 18, 0),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentTransactionsProvider.overrideWith((ref) => mockTransactions),
        ],
        child: const MaterialApp(
          home: ManagementPaymentTransactionsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Kiểm tra tiêu đề và bộ lọc
    expect(find.text('Đối soát Giao dịch'), findsOneWidget);
    expect(find.text('Tất cả (2)'), findsOneWidget);
    expect(find.text('Hóa đơn (1)'), findsOneWidget);
    expect(find.text('Dịch vụ (1)'), findsOneWidget);

    // 2. Kiểm tra danh sách giao dịch
    expect(find.text('Hóa đơn tháng 10/2026'), findsOneWidget);
    expect(find.text('Sân cầu lông (18:00 - 19:30)'), findsOneWidget);
    expect(find.textContaining('DEMO-20261005-001'), findsOneWidget);
  });
}
