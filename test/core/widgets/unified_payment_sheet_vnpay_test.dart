import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vivona/core/widgets/unified_payment_sheet.dart';
import 'package:vivona/data/models/building_model.dart';
import 'package:vivona/data/models/building_payment_config_model.dart';
import 'package:vivona/data/models/invoice_model.dart';
import 'package:vivona/data/providers/building_provider.dart';
import 'package:vivona/data/providers/payment_provider.dart';
import 'package:vivona/data/providers/resident_invoice_provider.dart';
import 'package:vivona/data/services/payment_service.dart';

void main() {
  group('UnifiedPaymentSheet VNPay Integration Tests', () {
    final testBuilding = BuildingModel(
      id: 'bld-vnpay-01',
      organizationId: 'org-001',
      name: 'Tòa Nhà PKA Sunrise',
      code: 'PKAS',
      bankBin: '970422',
      bankName: 'MBBank',
      bankAccountNumber: '0988776655',
      bankAccountName: 'BQL TOA NHA PKA SUNRISE',
    );

    final unpaidInvoice = InvoiceModel(
      id: 'inv-vnpay-001',
      apartmentId: 'apt-01',
      period: '11/2026',
      dueDate: DateTime(2026, 11, 25),
      totalAmount: 1800000,
      status: 'unpaid',
      createdAt: DateTime(2026, 11, 1),
      paymentCode: 'INV2611A0110',
    );

    testWidgets('hiển thị tùy chọn VNPay và khi cấu hình hợp lệ nút hiển thị MỞ CỔNG VNPAY', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final activeVnpayConfig = BuildingPaymentConfigModel(
        id: 'cfg-vnpay-01',
        buildingId: 'bld-vnpay-01',
        bankAccountNumber: '0988776655',
        bankAccountName: 'BQL TOA NHA PKA SUNRISE',
        bankName: 'MBBank',
        bankBin: '970422',
        isActive: true,
        vnpayTmnCode: 'PKASUNRISE01',
        vnpayIsActive: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeBuildingProvider.overrideWith((ref) => Future.value(testBuilding)),
            buildingByIdProvider('bld-vnpay-01').overrideWith((ref) => Future.value(testBuilding)),
            buildingPaymentConfigProvider('bld-vnpay-01').overrideWith((ref) => Future.value(activeVnpayConfig)),
            residentInvoiceProvider.overrideWith((ref) => Future.value([unpaidInvoice])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UnifiedPaymentSheet(
                type: PaymentType.invoice,
                referenceId: 'inv-vnpay-001',
                buildingId: 'bld-vnpay-01',
                title: 'Hóa đơn tiền nước & dịch vụ',
                referenceCode: 'INV2611A0110',
                amount: 1800000,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra có tùy chọn Cổng thanh toán trực tuyến VNPay
      expect(find.text('Cổng thanh toán trực tuyến VNPay'), findsOneWidget);

      // Nhấn chọn hình thức VNPay
      await tester.tap(find.text('Cổng thanh toán trực tuyến VNPay'));
      await tester.pumpAndSettle();

      // Phải hiển thị thông tin bảo mật VNPay
      expect(find.text('Cổng thanh toán bảo mật VNPay 2.1.0'), findsOneWidget);
      expect(find.textContaining('HMAC-SHA512'), findsOneWidget);

      // Nút hành động phải đổi thành MỞ CỔNG VNPAY
      expect(find.text('MỞ CỔNG VNPAY'), findsOneWidget);
    });

    testWidgets('khi tòa nhà chưa cấu hình VNPay hiển thị cảnh báo và vô hiệu hóa nút mở cổng', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final inactiveVnpayConfig = BuildingPaymentConfigModel(
        id: 'cfg-vnpay-02',
        buildingId: 'bld-vnpay-01',
        bankAccountNumber: '0988776655',
        bankAccountName: 'BQL TOA NHA PKA SUNRISE',
        bankName: 'MBBank',
        bankBin: '970422',
        isActive: true,
        vnpayIsActive: false, // Chưa kích hoạt
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeBuildingProvider.overrideWith((ref) => Future.value(testBuilding)),
            buildingByIdProvider('bld-vnpay-01').overrideWith((ref) => Future.value(testBuilding)),
            buildingPaymentConfigProvider('bld-vnpay-01').overrideWith((ref) => Future.value(inactiveVnpayConfig)),
            residentInvoiceProvider.overrideWith((ref) => Future.value([unpaidInvoice])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UnifiedPaymentSheet(
                type: PaymentType.invoice,
                referenceId: 'inv-vnpay-001',
                buildingId: 'bld-vnpay-01',
                title: 'Hóa đơn tiền nước & dịch vụ',
                referenceCode: 'INV2611A0110',
                amount: 1800000,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Nhấn chọn hình thức VNPay
      await tester.tap(find.text('Cổng thanh toán trực tuyến VNPay'));
      await tester.pumpAndSettle();

      // Hiển thị thông báo tòa nhà chưa kích hoạt
      expect(find.textContaining('Tòa nhà hiện chưa kích hoạt cổng thanh toán trực tuyến VNPay'), findsOneWidget);
      expect(find.text('BQL CHƯA KÍCH HOẠT VNPAY'), findsOneWidget);

      // Kiểm tra nút bị disabled
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('khi thanh toán tiện ích dịch vụ (PaymentType.service) không hiển thị tùy chọn VNPay', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final activeVnpayConfig = BuildingPaymentConfigModel(
        id: 'cfg-vnpay-01',
        buildingId: 'bld-vnpay-01',
        bankAccountNumber: '0988776655',
        bankAccountName: 'BQL TOA NHA PKA SUNRISE',
        bankName: 'MBBank',
        bankBin: '970422',
        isActive: true,
        vnpayTmnCode: 'PKASUNRISE01',
        vnpayIsActive: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeBuildingProvider.overrideWith((ref) => Future.value(testBuilding)),
            buildingByIdProvider('bld-vnpay-01').overrideWith((ref) => Future.value(testBuilding)),
            buildingPaymentConfigProvider('bld-vnpay-01').overrideWith((ref) => Future.value(activeVnpayConfig)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UnifiedPaymentSheet(
                type: PaymentType.service,
                referenceId: 'bk-vnpay-001',
                buildingId: 'bld-vnpay-01',
                title: 'Đặt sân Tennis',
                referenceCode: 'BK2611001',
                amount: 200000,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Không được hiển thị tùy chọn VNPay vì VNPay server hiện chỉ tra cứu invoices
      expect(find.text('Cổng thanh toán trực tuyến VNPay'), findsNothing);
      expect(find.text('Chuyển khoản VietQR (Napas 247)'), findsOneWidget);
    });

    test('PaymentService sinh URL sandbox hoặc production dựa trên cấu hình isSandbox', () async {
      const paymentService = PaymentService(isMockMode: true);

      final sandboxUrl = await paymentService.createVnpayPaymentUrl(
        invoiceId: 'inv-test-01',
        isSandbox: true,
      );
      expect(sandboxUrl, contains('https://sandbox.vnpayment.vn/paymentv2/vpcpay.html'));

      final prodUrl = await paymentService.createVnpayPaymentUrl(
        invoiceId: 'inv-test-01',
        isSandbox: false,
      );
      expect(prodUrl, contains('https://pay.vnpayment.vn/paymentv2/vpcpay.html'));
    });
  });
}
