import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/widgets/accounting_voucher_dialog.dart';
import 'package:pka_home/data/models/maintenance_fund_transaction_model.dart';

void main() {
  testWidgets('AccountingVoucherDialog displays standard voucher fields and Vietnamese words', (tester) async {
    final tx = MaintenanceFundTransactionModel(
      id: 'tx-1',
      buildingId: 'b-1',
      fundId: 'f-1',
      voucherNumber: 'PC-202610-00008',
      transactionType: 'EXPENSE',
      category: 'EQUIPMENT_REPAIR',
      amount: 15000000.0,
      balanceAfter: 2485000000.0,
      recipientOrPayer: 'Công ty Cổ phần Thang máy Alpha',
      description: 'Nghiệm thu bảo dưỡng định kỳ hệ thống thang máy',
      createdAt: DateTime(2026, 10, 27, 14, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => AccountingVoucherDialog.show(
                ctx,
                transaction: tx,
                buildingName: 'Tòa nhà Landmark PKA',
              ),
              child: const Text('Xem chứng từ'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Xem chứng từ'));
    await tester.pumpAndSettle();

    expect(find.textContaining('PHIẾU CHI'), findsOneWidget);
    expect(find.textContaining('Mẫu 02-TT'), findsOneWidget);
    expect(find.textContaining('PC-202610-00008'), findsOneWidget);
    expect(find.textContaining('Công ty Cổ phần Thang máy Alpha'), findsOneWidget);
    expect(find.textContaining('Mười lăm triệu đồng chẵn'), findsOneWidget);
    expect(find.textContaining('Giám đốc BQL'), findsOneWidget);
    expect(find.textContaining('Kế toán trưởng'), findsOneWidget);
    expect(find.textContaining('Người nhận tiền'), findsOneWidget);
  });
}
