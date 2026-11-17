import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/apartment_model.dart';
import 'package:vivona/data/models/invoice_model.dart';
import 'package:vivona/data/models/payment_transaction_model.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/providers/accounting_workstation_provider.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/payment_provider.dart';
import 'package:vivona/features/management/screens/accounting_web_workstation_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime(2026, 11, 8, 10, 0);

  final adminUser = UserModel(
    id: 'user-admin-1',
    fullName: 'Kế Toán Trưởng',
    phone: '0900000001',
    role: 'accountant',
  );

  final mockInvoices = [
    InvoiceModel(
      id: 'inv-sepay-1',
      apartmentId: 'apt-1',
      period: '2026-11',
      dueDate: now.add(const Duration(days: 10)),
      totalAmount: 1800000,
      status: 'unpaid',
      createdAt: now,
      paymentCode: 'INV2611A0110',
      apartment: ApartmentModel(
        id: 'apt-1',
        code: 'a0110',
        buildingCode: 'A',
        floorNumber: 1,
      ),
    ),
  ];

  final mockTransactions = [
    PaymentTransactionModel(
      id: 'tx-sepay-01',
      invoiceId: 'inv-sepay-0',
      type: 'INVOICE',
      title: 'INV2611A0105 chuyen tien dien nuoc',
      apartmentId: 'apt-0',
      amount: 1500000,
      paymentMethod: 'sepay',
      status: 'SUCCESS',
      transactionCode: 'REC-20261108-001',
      createdAt: now.subtract(const Duration(hours: 2)),
    ),
    PaymentTransactionModel(
      id: 'tx-sepay-02',
      type: 'INVOICE',
      title: 'tien phong thang 11 phong 110',
      apartmentId: '',
      amount: 1800000,
      paymentMethod: 'sepay',
      status: 'UNMATCHED',
      transactionCode: 'SEPAY-TXN-888999',
      failureReason: 'Không tìm thấy hóa đơn khớp mã: tien phong thang 11 phong 110',
      createdAt: now.subtract(const Duration(minutes: 30)),
    ),
  ];

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(adminUser)),
        accountingWorkstationRawInvoicesProvider.overrideWith((ref) => Future.value(mockInvoices)),
        paymentTransactionsProvider.overrideWith((ref) => Future.value(mockTransactions)),
      ],
      child: const MaterialApp(
        home: AccountingWebWorkstationScreen(),
      ),
    );
  }

  testWidgets('AccountingWebWorkstationScreen ho tro tab Doi Soat SePay va hien thi giao dich UNMATCHED', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Kiểm tra Tab Chuyển đổi
    expect(find.text('Sổ Công Nợ Hóa Đơn'), findsOneWidget);
    expect(find.text('Đối Soát SePay & Chưa Khớp'), findsOneWidget);

    // Chuyển sang Tab "Đối Soát SePay & Chưa Khớp"
    await tester.tap(find.text('Đối Soát SePay & Chưa Khớp'));
    await tester.pumpAndSettle();

    // Kiểm tra thẻ KPI SePay
    expect(find.text('Tổng Giao Dịch SePay'), findsOneWidget);
    expect(find.text('Đã Gạch Nợ Tự Động'), findsOneWidget);
    expect(find.text('Giao Dịch Chưa Khớp'), findsOneWidget);

    // Kiểm tra thông tin giao dịch trong bảng
    expect(find.text('REC-20261108-001'), findsOneWidget);
    expect(find.text('SEPAY-TXN-888999'), findsOneWidget);
    expect(find.text('tien phong thang 11 phong 110'), findsOneWidget);

    // Kiểm tra trạng thái và nút hành động khớp thủ công
    expect(find.text('Chưa khớp cú pháp'), findsOneWidget);
    expect(find.text('Khớp nợ thủ công'), findsOneWidget);
  });
}
