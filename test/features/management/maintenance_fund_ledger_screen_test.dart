import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/features/management/screens/maintenance_fund_ledger_screen.dart';
import 'package:pka_home/data/models/maintenance_fund_model.dart';
import 'package:pka_home/data/models/maintenance_fund_transaction_model.dart';
import 'package:pka_home/data/providers/maintenance_fund_provider.dart';

void main() {
  testWidgets('MaintenanceFundLedgerScreen displays fund balance, filters, and transaction list', (tester) async {
    final mockFund = MaintenanceFundModel(
      id: 'f-1',
      totalBalance: 2450000000.0,
      annualInterestEarned: 127400000.0,
      interestRatePercent: 5.2,
      collectedPercent: 98.5,
      bankName: 'BIDV',
      bankAccountNumber: '1234567890',
    );

    final mockTxs = [
      MaintenanceFundTransactionModel(
        id: 'tx-1',
        buildingId: 'b-1',
        fundId: 'f-1',
        voucherNumber: 'PT-202610-00001',
        transactionType: 'INCOME',
        category: 'MAINTENANCE_FEE',
        amount: 5000000.0,
        balanceAfter: 2450000000.0,
        recipientOrPayer: 'Cư dân Căn A0110',
        description: 'Thu phí bảo trì',
        createdAt: DateTime(2026, 10, 27, 9, 0),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeMaintenanceFundProvider.overrideWith((ref) => Future.value(mockFund)),
          maintenanceFundLedgerProvider.overrideWith((ref) => Future.value(mockTxs)),
        ],
        child: const MaterialApp(
          home: MaintenanceFundLedgerScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Sổ Quỹ Bảo Trì 2%'), findsOneWidget);
    expect(find.textContaining('PT-202610-00001'), findsOneWidget);
    expect(find.text('Thu phí bảo trì'), findsWidgets);
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('Thu quỹ'), findsOneWidget);
    expect(find.text('Chi quỹ'), findsOneWidget);
  });
}
