import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/core/widgets/unified_payment_sheet.dart';
import 'package:pka_home/data/services/payment_service.dart';
import 'package:pka_home/data/providers/payment_provider.dart';

class FakePaymentService extends PaymentService {
  final PaymentResult fakeResult;
  FakePaymentService(this.fakeResult);

  @override
  Future<PaymentResult> pay({
    required PaymentType type,
    required String referenceId,
    String outcome = 'SUCCESS',
  }) async {
    return fakeResult;
  }
}

void main() {
  testWidgets('UnifiedPaymentSheet hiển thị xác nhận và hoàn tất thanh toán thành công', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeResult = PaymentResult(
      success: true,
      transactionCode: 'DEMO-20261005-0001',
      transactionId: 'tx-001',
      amount: 1480000.0,
      title: 'Hóa đơn tháng 10/2026',
      paidAt: DateTime(2026, 10, 5, 22, 30),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentServiceProvider.overrideWithValue(FakePaymentService(fakeResult)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showUnifiedPaymentSheet(
                      context: ctx,
                      type: PaymentType.invoice,
                      referenceId: 'inv-123',
                      title: 'Thanh toán hóa đơn',
                      referenceCode: '#INV-202610-A0110',
                      amount: 1480000.0,
                      feeBreakdown: [
                        {'name': 'Phí quản lý', 'amount': 750000.0},
                        {'name': 'Điện', 'amount': 450000.0},
                        {'name': 'Nước', 'amount': 180000.0},
                        {'name': 'Gửi xe', 'amount': 100000.0},
                      ],
                    );
                  },
                  child: const Text('MỞ CỔNG THANH TOÁN'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Bấm nút mở sheet
    await tester.tap(find.text('MỞ CỔNG THANH TOÁN'));
    await tester.pumpAndSettle();

    // 1. Kiểm tra trạng thái Xác nhận
    expect(find.text('Thanh toán hóa đơn'), findsOneWidget);
    expect(find.text('#INV-202610-A0110'), findsOneWidget);
    expect(find.text('Demo Payment'), findsOneWidget);
    expect(find.text('Giao dịch mô phỏng (Sandbox)'), findsOneWidget);
    expect(find.text('Phí quản lý'), findsOneWidget);
    expect(find.text('THANH TOÁN'), findsOneWidget);

    // 2. Bấm nút THANH TOÁN
    await tester.tap(find.text('THANH TOÁN'));
    await tester.pump(); // frame đầu tiên chuyển sang Processing
    expect(find.text('Đang xử lý giao dịch...'), findsOneWidget);

    // Chờ trễ giả lập và gọi API xong
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    // 3. Kiểm tra trạng thái Thành công
    expect(find.text('Thanh toán thành công'), findsOneWidget);
    expect(find.text('DEMO-20261005-0001'), findsOneWidget);
    expect(find.text('HOÀN TẤT'), findsOneWidget);

    // Bấm hoàn tất
    await tester.tap(find.text('HOÀN TẤT'));
    await tester.pumpAndSettle();

    // Bottom sheet đã đóng
    expect(find.text('Thanh toán thành công'), findsNothing);
  });
}
