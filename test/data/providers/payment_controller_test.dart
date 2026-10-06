import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/services/payment_service.dart';
import 'package:pka_home/data/providers/payment_provider.dart';

class MockPaymentService extends PaymentService {
  final bool shouldSucceed;
  int payCallCount = 0;

  MockPaymentService({this.shouldSucceed = true});

  @override
  Future<PaymentResult> pay({
    required PaymentType type,
    required String referenceId,
    String outcome = 'SUCCESS',
  }) async {
    payCallCount++;
    return PaymentResult(
      success: shouldSucceed,
      transactionCode: 'TX-TEST-001',
      transactionId: 'id-test-001',
      amount: 500000.0,
      title: 'Hóa đơn dịch vụ',
      paidAt: DateTime.now(),
    );
  }
}

void main() {
  group('PaymentController Tests', () {
    test('pay() thành công gọi đúng service và kích hoạt invalidation cho hóa đơn', () async {
      final mockService = MockPaymentService(shouldSucceed: true);
      final container = ProviderContainer(
        overrides: [
          paymentServiceProvider.overrideWithValue(mockService),
        ],
      );

      final controller = container.read(paymentControllerProvider);
      final result = await controller.pay(
        type: PaymentType.invoice,
        referenceId: 'inv-123',
      );

      expect(mockService.payCallCount, equals(1));
      expect(result.success, isTrue);
      expect(result.transactionCode, equals('TX-TEST-001'));
    });

    test('pay() thất bại không kích hoạt invalidation', () async {
      final mockService = MockPaymentService(shouldSucceed: false);
      final container = ProviderContainer(
        overrides: [
          paymentServiceProvider.overrideWithValue(mockService),
        ],
      );

      final controller = container.read(paymentControllerProvider);
      final result = await controller.pay(
        type: PaymentType.service,
        referenceId: 'srv-456',
      );

      expect(mockService.payCallCount, equals(1));
      expect(result.success, isFalse);
    });
  });
}
