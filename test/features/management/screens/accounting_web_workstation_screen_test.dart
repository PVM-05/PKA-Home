import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/providers/accounting_workstation_provider.dart';
import 'package:pka_home/features/management/screens/accounting_web_workstation_screen.dart';

void main() {
  final now = DateTime(2026, 10, 30);
  final mockInvoices = [
    InvoiceModel(
      id: 'inv-1',
      apartmentId: 'apt-1',
      period: '2026-10',
      dueDate: now.add(const Duration(days: 5)),
      totalAmount: 1500000,
      status: 'unpaid',
      createdAt: now,
      paymentCode: 'INV202610A0110',
      apartment: ApartmentModel(
        id: 'apt-1',
        code: 'a0110',
        buildingCode: 'A',
        floorNumber: 1,
      ),
    ),
    InvoiceModel(
      id: 'inv-2',
      apartmentId: 'apt-2',
      period: '2026-10',
      dueDate: now.subtract(const Duration(days: 2)),
      totalAmount: 2000000,
      status: 'overdue',
      createdAt: now,
      paymentCode: 'INV202610A0201',
      apartment: ApartmentModel(
        id: 'apt-2',
        code: 'a0201',
        buildingCode: 'A',
        floorNumber: 2,
      ),
    ),
  ];

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        accountingWorkstationRawInvoicesProvider.overrideWith((ref) => Future.value(mockInvoices)),
      ],
      child: const MaterialApp(
        home: AccountingWebWorkstationScreen(),
      ),
    );
  }

  testWidgets('AccountingWebWorkstationScreen hien thi KPI strip va bang du lieu doi soat', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Kiem tra Header
    expect(find.text('Bàn Làm Việc Kế Toán & Đối Soát'), findsOneWidget);

    // Kiem tra 4 the KPI
    expect(find.text('Tổng Phát Hành'), findsOneWidget);
    expect(find.text('Thực Thu'), findsOneWidget);
    expect(find.text('Chờ Thu Trong Hạn'), findsOneWidget);
    expect(find.text('Nợ Quá Hạn'), findsOneWidget);

    // Kiem tra ma can ho trong bang
    expect(find.text('A0110'), findsOneWidget);
    expect(find.text('A0201'), findsOneWidget);

    // Kiem tra nut Xuat Excel
    expect(find.text('Xuất Excel'), findsOneWidget);
  });

  testWidgets('AccountingWebWorkstationScreen hien thi bulk toolbar khi chon checkbox', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Chon checkbox dau tien trong danh sach
    final checkboxes = find.byType(Checkbox);
    expect(checkboxes, findsWidgets);

    // Nhap vao checkbox dong thu nhat (checkboxes.at(1) vi at(0) la select-all)
    await tester.tap(checkboxes.at(1));
    await tester.pumpAndSettle();

    // Bulk bar xuat hien
    expect(find.textContaining('Đã chọn 1'), findsOneWidget);
    expect(find.text('Gửi Nhắc Nợ'), findsOneWidget);
  });
}
