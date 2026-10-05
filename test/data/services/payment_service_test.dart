import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/payment_transaction_model.dart';
import 'package:pka_home/data/services/payment_service.dart';

void main() {
  group('PaymentTransactionModel Multi-Type Tests', () {
    test('Khởi tạo giao dịch loại INVOICE', () {
      final model = PaymentTransactionModel(
        id: 'tx-1',
        invoiceId: 'inv-1',
        bookingId: null,
        type: 'INVOICE',
        title: 'Hóa đơn tháng 10/2026',
        apartmentId: 'apt-1',
        amount: 1480000.0,
        paymentMethod: 'Demo Payment',
        status: 'SUCCESS',
        transactionCode: 'DEMO-20261005-0001',
        createdAt: DateTime(2026, 10, 5, 22, 15),
      );

      expect(model.isInvoice, isTrue);
      expect(model.isService, isFalse);
      expect(model.isSuccess, isTrue);
      expect(model.title, 'Hóa đơn tháng 10/2026');
      expect(model.transactionCode, 'DEMO-20261005-0001');
    });

    test('Khởi tạo giao dịch loại SERVICE từ JSON', () {
      final json = {
        'id': 'tx-2',
        'invoice_id': null,
        'booking_id': 'bk-123',
        'type': 'SERVICE',
        'title': 'Sân cầu lông (18:00 - 19:00)',
        'apartment_id': 'apt-1',
        'amount': 100000.0,
        'payment_method': 'Demo Payment',
        'status': 'SUCCESS',
        'transaction_code': 'DEMO-20261005-0002',
        'created_at': '2026-10-05T22:30:00.000Z',
      };

      final model = PaymentTransactionModel.fromJson(json);

      expect(model.isService, isTrue);
      expect(model.isInvoice, isFalse);
      expect(model.bookingId, 'bk-123');
      expect(model.invoiceId, isNull);
      expect(model.title, 'Sân cầu lông (18:00 - 19:00)');
    });
  });

  group('PaymentResult Tests', () {
    test('PaymentResult lưu đầy đủ thông tin sau giao dịch', () {
      final now = DateTime.now();
      final result = PaymentResult(
        success: true,
        transactionCode: 'DEMO-20261005-0001',
        transactionId: 'tx-01',
        amount: 1480000.0,
        title: 'Hóa đơn tháng 10/2026',
        paidAt: now,
      );

      expect(result.success, isTrue);
      expect(result.transactionCode, 'DEMO-20261005-0001');
      expect(result.amount, 1480000.0);
    });
  });
}
