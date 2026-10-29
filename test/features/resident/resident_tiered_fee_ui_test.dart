import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/core/utils/utility_fee_calculator.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/providers/resident_invoice_provider.dart';
import 'package:pka_home/features/resident/screens/resident_invoice_detail_screen.dart';
import 'package:pka_home/features/resident/widgets/tiered_fee_breakdown_dialog.dart';

void main() {
  final testApartment = ApartmentModel(
    id: 'apt-01',
    code: 'A0110',
    buildingCode: 'A',
    floorNumber: 1,
    buildingId: 'bld-01',
    area: 65.0,
  );

  group('TieredFeeBreakdownDialog Widget Tests', () {
    testWidgets('hiển thị đầy đủ thông tin các bậc (tiêu thụ, đơn giá, thành tiền, tổng tiền)', (tester) async {
      final sampleResult = UtilityFeeCalculator.calculateElectricityEVN6Tiers(150);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => TieredFeeBreakdownDialog(
                      title: 'Biểu phí điện sinh hoạt',
                      unit: 'kWh',
                      result: sampleResult,
                    ),
                  );
                },
                child: const Text('Mở Dialog'),
              ),
            ),
          ),
        ),
      );

      // Mở dialog
      await tester.tap(find.text('Mở Dialog'));
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề và đơn vị
      expect(find.text('Biểu phí điện sinh hoạt'), findsOneWidget);
      expect(find.textContaining('150 kWh'), findsWidgets);

      // Kiểm tra các bậc hiển thị
      expect(find.textContaining('Bậc 1'), findsWidgets);
      expect(find.textContaining('Bậc 2'), findsWidgets);
      expect(find.textContaining('Bậc 3'), findsWidgets);

      // Kiểm tra tổng tiền
      expect(find.textContaining(sampleResult.formattedTotalAmount), findsWidgets);

      // Kiểm tra nút Đóng và đóng dialog thành công
      final closeBtn = find.text('Đóng');
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(find.byType(TieredFeeBreakdownDialog), findsNothing);
    });
  });

  group('ResidentInvoiceDetailScreen Tiered Fee & Penalty Tests', () {
    testWidgets('khi hóa đơn có khoản mục electricity hoặc water, xuất hiện nút/chip Chi tiết bậc thang và mở Dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final invoice = InvoiceModel(
        id: 'inv-test-tiered-01',
        apartmentId: 'apt-01',
        period: '2026-10',
        dueDate: DateTime.now().add(const Duration(days: 5)),
        totalAmount: 950000.0,
        status: 'unpaid',
        createdAt: DateTime.now(),
        apartment: testApartment,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            residentInvoiceDetailProvider('inv-test-tiered-01').overrideWith(
              (ref) async => [
                {
                  'id': 'item-elec',
                  'invoice_id': 'inv-test-tiered-01',
                  'fee_type': 'electricity',
                  'unit_price': 2500,
                  'quantity': 120,
                  'subtotal': 300000,
                },
                {
                  'id': 'item-water',
                  'invoice_id': 'inv-test-tiered-01',
                  'fee_type': 'water',
                  'unit_price': 12000,
                  'quantity': 18,
                  'subtotal': 216000,
                },
              ],
            ),
          ],
          child: MaterialApp(
            home: ResidentInvoiceDetailScreen(invoice: invoice),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra xuất hiện nút/chip "Chi tiết bậc thang"
      final breakdownButtons = find.text('Chi tiết bậc thang');
      expect(breakdownButtons, findsNWidgets(2));

      // Tap vào nút chi tiết bậc thang đầu tiên (Điện)
      await tester.tap(breakdownButtons.first);
      await tester.pumpAndSettle();

      // Xác nhận dialog mở ra với số liệu bậc thang điện
      expect(find.byType(TieredFeeBreakdownDialog), findsOneWidget);
      expect(find.textContaining('120 kWh'), findsWidgets);
      expect(find.textContaining('Bậc 1'), findsWidgets);

      // Đóng dialog
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();

      expect(find.byType(TieredFeeBreakdownDialog), findsNothing);

      // Tap vào nút chi tiết bậc thang thứ hai (Nước)
      await tester.tap(breakdownButtons.last);
      await tester.pumpAndSettle();

      // Xác nhận dialog mở ra với số liệu bậc thang nước
      expect(find.byType(TieredFeeBreakdownDialog), findsOneWidget);
      expect(find.textContaining('18 m³'), findsWidgets);
    });

    testWidgets('khi hóa đơn có khoản mục parking với ghi chú ngày lẻ/pro-rata, hiển thị chip Phí theo ngày lẻ', (tester) async {
      final invoice = InvoiceModel(
        id: 'inv-test-prorata-01',
        apartmentId: 'apt-01',
        period: '2026-10',
        dueDate: DateTime.now().add(const Duration(days: 5)),
        totalAmount: 150000.0,
        status: 'unpaid',
        createdAt: DateTime.now(),
        apartment: testApartment,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            residentInvoiceDetailProvider('inv-test-prorata-01').overrideWith(
              (ref) async => [
                {
                  'id': 'item-parking',
                  'invoice_id': 'inv-test-prorata-01',
                  'fee_type': 'parking',
                  'unit_price': 150000,
                  'quantity': 1,
                  'subtotal': 150000,
                  'description': 'Phí gửi xe máy 15 ngày lẻ (pro-rata)',
                },
              ],
            ),
          ],
          child: MaterialApp(
            home: ResidentInvoiceDetailScreen(invoice: invoice),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra chip Phí theo ngày lẻ xuất hiện
      expect(find.text('Phí theo ngày lẻ'), findsOneWidget);
    });

    testWidgets('khi hóa đơn unpaid và quá hạn dueDate, hiển thị cảnh báo trễ hạn kèm tiền lãi phạt trễ hạn', (tester) async {
      final overdueDueDate = DateTime.now().subtract(const Duration(days: 10));
      final invoice = InvoiceModel(
        id: 'inv-test-overdue-01',
        apartmentId: 'apt-01',
        period: '2026-10',
        dueDate: overdueDueDate,
        totalAmount: 1000000.0,
        status: 'unpaid',
        createdAt: DateTime.now().subtract(const Duration(days: 25)),
        apartment: testApartment,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            residentInvoiceDetailProvider('inv-test-overdue-01').overrideWith(
              (ref) async => [
                {
                  'id': 'item-mgmt',
                  'invoice_id': 'inv-test-overdue-01',
                  'fee_type': 'management',
                  'unit_price': 1000000,
                  'quantity': 1,
                  'subtotal': 1000000,
                },
              ],
            ),
          ],
          child: MaterialApp(
            home: ResidentInvoiceDetailScreen(invoice: invoice),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra hiển thị cảnh báo trễ hạn
      expect(find.textContaining('Quá hạn'), findsWidgets);
      expect(find.textContaining('10 ngày'), findsWidgets);

      // Kiểm tra tiền phạt trễ hạn ước tính: 1.000.000 x 0.05%/ngày x 10 ngày = 5.000 đ
      expect(find.textContaining('5.000'), findsWidgets);
    });
  });
}

