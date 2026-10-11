import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/services/payment_service.dart';

void main() {
  group('PaymentResult Tests', () {
    test('deserialize kết quả PENDING (chờ BQL xác nhận)', () {
      final json = {
        'success': true,
        'is_pending': true,
        'status': 'PENDING',
        'message': 'Đã gửi thông báo thanh toán. Vui lòng chờ Ban Quản Lý đối soát và xác nhận.',
        'transaction_id': 'tx-pending-1',
        'transaction_code': 'PENDING-INV-20261011-001',
        'amount': 1250000.0,
        'title': 'Yêu cầu thanh toán hóa đơn kỳ 10/2026',
        'paid_at': '2026-10-11T20:45:00Z',
      };

      final result = PaymentResult.fromJson(json);

      expect(result.success, isTrue);
      expect(result.isPending, isTrue);
      expect(result.status, 'PENDING');
      expect(result.transactionCode, 'PENDING-INV-20261011-001');
      expect(result.amount, 1250000.0);
      expect(result.errorMessage, contains('Đã gửi thông báo'));
    });

    test('deserialize kết quả SUCCESS (đã thu tiền)', () {
      final json = {
        'success': true,
        'status': 'SUCCESS',
        'transaction_id': 'tx-success-1',
        'transaction_code': 'PENDING-INV-20261011-001',
        'amount': 1250000.0,
        'title': 'Thanh toán hóa đơn kỳ 10/2026',
        'paid_at': '2026-10-11T21:00:00Z',
      };

      final result = PaymentResult.fromJson(json);

      expect(result.success, isTrue);
      expect(result.isPending, isFalse);
      expect(result.status, 'SUCCESS');
      expect(result.transactionCode, 'PENDING-INV-20261011-001');
    });

    test('deserialize kết quả FAILED', () {
      final json = {
        'success': false,
        'status': 'FAILED',
        'message': 'Hóa đơn này đã được thanh toán trước đó',
      };

      final result = PaymentResult.fromJson(json);

      expect(result.success, isFalse);
      expect(result.isPending, isFalse);
      expect(result.status, 'FAILED');
      expect(result.errorMessage, 'Hóa đơn này đã được thanh toán trước đó');
    });

    test('không tự suy đoán SUCCESS khi thiếu status dù có success: true', () {
      final json = {
        'success': true,
        'transaction_code': 'LEGACY-001',
      };

      final result = PaymentResult.fromJson(json);

      expect(result.status, 'UNKNOWN');
      expect(result.success, isFalse);
      expect(result.isPending, isFalse);
      expect(result.errorMessage, contains('thiếu trạng thái'));
    });
  });
}
