import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/payment_transaction_model.dart';

void main() {
  group('PaymentTransactionModel Status Display Tests', () {
    test('Correctly maps status to statusDisplayName', () {
      final successTx = PaymentTransactionModel(
        id: '1',
        apartmentId: 'apt-1',
        amount: 500000,
        paymentMethod: 'CASH',
        status: 'SUCCESS',
        transactionCode: 'TXN-01',
        createdAt: DateTime.now(),
      );
      expect(successTx.statusDisplayName, equals('Thành công'));
      expect(successTx.isSuccess, isTrue);

      final failedTx = PaymentTransactionModel(
        id: '2',
        apartmentId: 'apt-1',
        amount: 500000,
        paymentMethod: 'CASH',
        status: 'FAILED',
        transactionCode: 'TXN-02',
        createdAt: DateTime.now(),
      );
      expect(failedTx.statusDisplayName, equals('Thất bại'));
      expect(failedTx.isFailed, isTrue);

      final cancelledTx = PaymentTransactionModel(
        id: '3',
        apartmentId: 'apt-1',
        amount: 500000,
        paymentMethod: 'CASH',
        status: 'CANCELLED',
        transactionCode: 'TXN-03',
        createdAt: DateTime.now(),
      );
      expect(cancelledTx.statusDisplayName, equals('Đã hủy'));
      expect(cancelledTx.isCancelled, isTrue);
    });

    test('ManagementPaymentTransactionsScreen uses dynamic status and colors instead of hardcoded Thành công', () {
      final file = javaOrDartFile('lib/features/management/screens/management_payment_transactions_screen.dart');
      final content = file.readAsStringSync();

      expect(content.contains("tx.statusDisplayName"), isTrue, reason: 'Badge must show dynamic tx.statusDisplayName');
      expect(content.contains("const Text(\n                                          'Thành công',"), isFalse, reason: 'Must not hardcode Thành công for all rows');
    });

    test('ManagementInvoiceDetailScreen records payment transaction when confirming receipt', () {
      final file = javaOrDartFile('lib/features/management/screens/management_invoice_detail_screen.dart');
      final content = file.readAsStringSync();

      expect(
        content.contains('recordManualPayment') || content.contains('recordPaymentTransaction'),
        isTrue,
        reason: 'Must call recordManualPayment or recordPaymentTransaction when staff confirms cash/transfer',
      );
    });
  });
}

File javaOrDartFile(String path) => File(path);

