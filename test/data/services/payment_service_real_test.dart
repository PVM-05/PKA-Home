import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/services/payment_service.dart';

void main() {
  group('PaymentResult Data Model & JSON Parsing Tests', () {
    test('Xử lý phản hồi PENDING từ create_payment_intent thành công', () {
      final json = {
        'success': true,
        'status': 'PENDING',
        'is_pending': true,
        'transaction_id': 'tx-intent-001',
        'reference_code': 'INV-202611-A0110',
        'amount': 2500000.0,
        'message': 'Đã khởi tạo giao dịch chờ thanh toán. Vui lòng chuyển khoản đúng nội dung.',
      };

      final result = PaymentResult.fromJson(json);

      expect(result.success, isTrue);
      expect(result.isPending, isTrue);
      expect(result.status, 'PENDING');
      expect(result.transactionId, 'tx-intent-001');
      expect(result.transactionCode, 'INV-202611-A0110');
      expect(result.amount, 2500000.0);
      expect(result.errorMessage, contains('Đã khởi tạo giao dịch chờ thanh toán'));
    });

    test('Xử lý phản hồi SUCCESS từ Webhook ngân hàng thành công', () {
      final json = {
        'success': true,
        'status': 'SUCCESS',
        'is_pending': false,
        'transaction_id': 'tx-real-002',
        'receipt_number': 'REC-20261104-ABC123',
        'amount': 1800000.0,
        'paid_at': '2026-11-04T08:30:00Z',
        'message': 'Gạch nợ hóa đơn thành công.',
      };

      final result = PaymentResult.fromJson(json);

      expect(result.success, isTrue);
      expect(result.isPending, isFalse);
      expect(result.status, 'SUCCESS');
      expect(result.transactionCode, 'REC-20261104-ABC123');
      expect(result.amount, 1800000.0);
    });

    test('Xử lý phản hồi OVERPAID nộp thừa tiền', () {
      final json = {
        'success': true,
        'status': 'OVERPAID',
        'transaction_id': 'tx-over-003',
        'receipt_number': 'REC-20261104-OVER99',
        'amount': 2000000.0,
        'message': 'Hóa đơn đã được thanh toán trước đó. Giao dịch được ghi nhận để hoàn tiền.',
      };

      final result = PaymentResult.fromJson(json);

      expect(result.status, 'OVERPAID');
      expect(result.transactionCode, 'REC-20261104-OVER99');
    });

    test('Xử lý phản hồi PARTIAL_PAID nộp thiếu tiền', () {
      final json = {
        'success': false,
        'status': 'PARTIAL_PAID',
        'transaction_id': 'tx-part-004',
        'amount': 500000.0,
        'message': 'Số tiền chuyển khoản chưa đủ để thanh toán toàn bộ hóa đơn.',
      };

      final result = PaymentResult.fromJson(json);

      expect(result.success, isFalse);
      expect(result.status, 'PARTIAL_PAID');
      expect(result.errorMessage, contains('chưa đủ để thanh toán'));
    });

    test('Xử lý phản hồi DUPLICATE giao dịch trùng lặp', () {
      final json = {
        'success': true,
        'status': 'DUPLICATE',
        'message': 'Giao dịch này đã được ghi nhận và gạch nợ trước đó.',
      };

      final result = PaymentResult.fromJson(json);

      expect(result.status, 'DUPLICATE');
      expect(result.errorMessage, contains('đã được ghi nhận'));
    });
  });
}
