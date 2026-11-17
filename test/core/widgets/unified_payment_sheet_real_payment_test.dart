import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/core/widgets/unified_payment_sheet.dart';
import 'package:pka_home/data/models/building_model.dart';
import 'package:pka_home/data/models/building_payment_config_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/providers/building_provider.dart';
import 'package:pka_home/data/providers/payment_provider.dart';
import 'package:pka_home/data/providers/resident_invoice_provider.dart';
import 'package:pka_home/data/services/payment_service.dart';

void main() {
  group('UnifiedPaymentSheet Real Payment Tests', () {
    testWidgets('hiển thị đầy đủ thông tin VietQR SePay và không chứa bất kỳ từ demo nào', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testBuilding = BuildingModel(
        id: 'bld-sepay-01',
        organizationId: 'org-001',
        name: 'Tòa Nhà PKA Central',
        code: 'PKAC',
        bankBin: '970422',
        bankName: 'MBBank',
        bankAccountNumber: '0988776655',
        bankAccountName: 'BQL TOA NHA PKA CENTRAL',
      );

      final sepayConfig = BuildingPaymentConfigModel(
        id: 'cfg-01',
        buildingId: 'bld-sepay-01',
        bankAccountNumber: '0988776655',
        bankAccountName: 'BQL TOA NHA PKA CENTRAL',
        bankName: 'MBBank',
        bankBin: '970422',
        isActive: true,
      );

      final unpaidInvoice = InvoiceModel(
        id: 'inv-sepay-001',
        apartmentId: 'apt-01',
        period: '11/2026',
        dueDate: DateTime(2026, 11, 25),
        totalAmount: 2500000,
        status: 'unpaid',
        createdAt: DateTime(2026, 11, 1),
        paymentCode: 'INV2611A0110',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeBuildingProvider.overrideWith((ref) => Future.value(testBuilding)),
            buildingByIdProvider('bld-sepay-01').overrideWith((ref) => Future.value(testBuilding)),
            buildingPaymentConfigProvider('bld-sepay-01').overrideWith((ref) => Future.value(sepayConfig)),
            residentInvoiceProvider.overrideWith((ref) => Future.value([unpaidInvoice])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UnifiedPaymentSheet(
                type: PaymentType.invoice,
                referenceId: 'inv-sepay-001',
                buildingId: 'bld-sepay-01',
                title: 'Phí dịch vụ & Quản lý tháng 11/2026',
                referenceCode: 'INV2611A0110',
                amount: 2500000,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra thông tin thanh toán chuẩn mực
      expect(find.text('Phí dịch vụ & Quản lý tháng 11/2026'), findsOneWidget);
      expect(find.text('INV2611A0110'), findsOneWidget);
      expect(find.text('Chuyển khoản VietQR (Napas 247)'), findsOneWidget);
      expect(find.text('Sao chép STK'), findsOneWidget);
      expect(find.text('Sao chép Nội dung'), findsOneWidget);
      expect(find.text('Sao chép Số tiền'), findsOneWidget);
      expect(find.textContaining('0988776655'), findsWidgets);

      // Tuyệt đối không chứa bất kỳ chuỗi demo nào
      expect(find.textContaining('DEMO', findRichText: true), findsNothing);
      expect(find.textContaining('demo', findRichText: true), findsNothing);
      expect(find.textContaining('giả lập', findRichText: true), findsNothing);
    });

    testWidgets('tự động gạch nợ thành công tức thì khi hóa đơn chuyển sang status paid qua Realtime', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testBuilding = BuildingModel(
        id: 'bld-sepay-01',
        organizationId: 'org-001',
        name: 'Tòa Nhà PKA Central',
        code: 'PKAC',
        bankBin: '970422',
        bankName: 'MBBank',
        bankAccountNumber: '0988776655',
        bankAccountName: 'BQL TOA NHA PKA CENTRAL',
      );

      final unpaidInvoice = InvoiceModel(
        id: 'inv-sepay-002',
        apartmentId: 'apt-01',
        period: '11/2026',
        dueDate: DateTime(2026, 11, 25),
        totalAmount: 3200000,
        status: 'unpaid',
        createdAt: DateTime(2026, 11, 1),
        paymentCode: 'INV2611A0110',
      );

      final invoicesNotifier = StateProvider<List<InvoiceModel>>((ref) => [unpaidInvoice]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeBuildingProvider.overrideWith((ref) => Future.value(testBuilding)),
            buildingByIdProvider('bld-sepay-01').overrideWith((ref) => Future.value(testBuilding)),
            buildingPaymentConfigProvider('bld-sepay-01').overrideWith((ref) => Future.value(null)),
            residentInvoiceProvider.overrideWith((ref) => Future.value(ref.watch(invoicesNotifier))),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UnifiedPaymentSheet(
                type: PaymentType.invoice,
                referenceId: 'inv-sepay-002',
                buildingId: 'bld-sepay-01',
                title: 'Hóa đơn tổng hợp kỳ 11/2026',
                referenceCode: 'INV2611A0110',
                amount: 3200000,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Giả lập SePay Webhook đã xử lý xong và Supabase Realtime đẩy state mới
      final paidInvoice = InvoiceModel(
        id: 'inv-sepay-002',
        apartmentId: 'apt-01',
        period: '11/2026',
        dueDate: DateTime(2026, 11, 25),
        totalAmount: 3200000,
        paidAmount: 3200000,
        status: 'paid',
        createdAt: DateTime(2026, 11, 1),
        paidAt: DateTime(2026, 11, 8, 14, 30),
        receiptNumber: 'REC-20261108-SEPAY01',
        paymentCode: 'INV2611A0110',
        transactionCode: 'SEPAY-TXN-998877',
      );

      final container = ProviderScope.containerOf(tester.element(find.byType(UnifiedPaymentSheet)));
      container.read(invoicesNotifier.notifier).state = [paidInvoice];

      await tester.pump();
      await tester.pumpAndSettle();

      // Màn hình tự động gạch nợ thành công
      expect(find.text('Thanh toán thành công'), findsOneWidget);
      expect(find.text('REC-20261108-SEPAY01'), findsOneWidget);
      expect(find.text('HOÀN TẤT'), findsOneWidget);
    });
  });
}
