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
    String paymentMethod = 'bank_transfer',
    String outcome = 'SUCCESS',
    String? failureReason,
  }) async {
    return fakeResult;
  }
}

void main() {
  testWidgets('UnifiedPaymentSheet hiển thị xác nhận và bước pendingConfirmation (Chờ BQL xác nhận)', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final pendingResult = PaymentResult(
      success: true,
      isPending: true,
      status: 'PENDING',
      transactionCode: 'PENDING-INV-20261011-0001',
      transactionId: 'tx-pending-001',
      amount: 1480000.0,
      title: 'Yêu cầu thanh toán hóa đơn kỳ 10/2026',
      paidAt: DateTime(2026, 10, 11, 20, 30),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentServiceProvider.overrideWithValue(FakePaymentService(pendingResult)),
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
    expect(find.textContaining('Quy trình mô phỏng phục vụ đánh giá đồ án'), findsOneWidget);
    expect(find.text('Chuyển khoản (VietQR Mô Phỏng)'), findsOneWidget);
    expect(find.text('Tiền mặt tại văn phòng Ban Quản Lý'), findsOneWidget);
    expect(find.text('GỬI THÔNG BÁO THANH TOÁN'), findsOneWidget);

    // 2. Bấm nút GỬI THÔNG BÁO THANH TOÁN
    await tester.tap(find.text('GỬI THÔNG BÁO THANH TOÁN'));
    await tester.pump(); // frame đầu tiên chuyển sang Processing
    expect(find.text('Đang gửi thông báo thanh toán...'), findsOneWidget);

    // Chờ trễ giả lập và gọi API xong
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    // 3. Kiểm tra bước pendingConfirmation (Không được hiển thị "Thanh toán thành công" giả)
    expect(find.text('Đã gửi thông báo thanh toán'), findsOneWidget);
    expect(find.text('Chờ Ban Quản Lý xác nhận'), findsOneWidget);
    expect(find.text('PENDING-INV-20261011-0001'), findsOneWidget);
    expect(find.text('ĐÃ HIỂU'), findsOneWidget);
    expect(find.text('Thanh toán thành công'), findsNothing);

    // Bấm ĐÃ HIỂU để đóng sheet
    await tester.tap(find.text('ĐÃ HIỂU'));
    await tester.pumpAndSettle();

    // Bottom sheet đã đóng
    expect(find.text('Đã gửi thông báo thanh toán'), findsNothing);
  });

  testWidgets('UnifiedPaymentSheet hiển thị bước success khi kết quả thanh toán là SUCCESS trực tiếp', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final successResult = PaymentResult(
      success: true,
      isPending: false,
      status: 'SUCCESS',
      transactionCode: 'SUCCESS-20261011-0002',
      transactionId: 'tx-success-002',
      amount: 500000.0,
      title: 'Hóa đơn tiền điện tháng 10/2026',
      paidAt: DateTime(2026, 10, 11, 21, 0),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentServiceProvider.overrideWithValue(FakePaymentService(successResult)),
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
                      referenceId: 'inv-456',
                      title: 'Hóa đơn tiền điện tháng 10/2026',
                      referenceCode: '#INV-202610-A0201',
                      amount: 500000.0,
                    );
                  },
                  child: const Text('MỞ CỔNG'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('MỞ CỔNG'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GỬI THÔNG BÁO THANH TOÁN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.text('Thanh toán thành công'), findsOneWidget);
    expect(find.text('SUCCESS-20261011-0002'), findsOneWidget);
    expect(find.text('HOÀN TẤT'), findsOneWidget);
  });
}
