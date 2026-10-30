import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/accounting_workstation_model.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';

void main() {
  group('AccountingWorkstationFilter', () {
    test('khoi tao gia tri mac dinh chinh xac', () {
      final filter = const AccountingWorkstationFilter();
      expect(filter.searchQuery, '');
      expect(filter.period, isNull);
      expect(filter.status, isNull);
      expect(filter.buildingId, isNull);
    });

    test('copyWith cap nhat tung truong dung dan', () {
      final filter = const AccountingWorkstationFilter();
      final updated = filter.copyWith(
        searchQuery: 'a0110',
        period: '2026-10',
        status: 'unpaid',
      );

      expect(updated.searchQuery, 'a0110');
      expect(updated.period, '2026-10');
      expect(updated.status, 'unpaid');
      expect(updated.buildingId, isNull);
    });
  });

  group('InvoiceTableRowItem', () {
    final now = DateTime(2026, 10, 30);
    final invoice = InvoiceModel(
      id: 'inv-001',
      apartmentId: 'apt-001',
      period: '2026-10',
      dueDate: DateTime(2026, 11, 5),
      totalAmount: 1500000,
      status: 'paid',
      createdAt: now,
      paidAt: DateTime(2026, 10, 25),
      paymentMethod: 'VietQR',
      transactionCode: 'TX998877',
      paymentCode: 'INV202610A0110',
      apartment: ApartmentModel(
        id: 'apt-001',
        code: 'a0110',
        buildingCode: 'B01',
        floorNumber: 1,
        buildingId: 'b-01',
        area: 75.5,
      ),
    );

    test('fromInvoice tao row item day du thong tin', () {
      final item = InvoiceTableRowItem.fromInvoice(
        invoice,
        residentName: 'Nguyen Van A',
        isSelected: false,
      );

      expect(item.id, 'inv-001');
      expect(item.apartmentCode, 'A0110');
      expect(item.residentName, 'Nguyen Van A');
      expect(item.period, '2026-10');
      expect(item.totalAmount, 1500000);
      expect(item.displayStatus, 'Đã thanh toán');
      expect(item.vietQrCode, 'INV202610A0110');
      expect(item.isSelected, isFalse);
      expect(item.formattedAmount, contains('1.500.000'));
    });

    test('displayStatus anh xa dung cho cac trang thai', () {
      expect(InvoiceTableRowItem.mapStatusToDisplay('paid'), 'Đã thanh toán');
      expect(InvoiceTableRowItem.mapStatusToDisplay('unpaid'), 'Chờ thanh toán');
      expect(InvoiceTableRowItem.mapStatusToDisplay('overdue'), 'Quá hạn');
      expect(InvoiceTableRowItem.mapStatusToDisplay('cancelled'), 'Đã hủy');
      expect(InvoiceTableRowItem.mapStatusToDisplay('unknown'), 'Không xác định');
    });
  });

  group('AccountingWorkstationSummary', () {
    final now = DateTime(2026, 10, 30);
    final items = [
      InvoiceTableRowItem(
        id: '1',
        apartmentCode: 'A0101',
        residentName: 'Tran B',
        period: '2026-10',
        totalAmount: 1000000,
        status: 'paid',
        displayStatus: 'Đã thanh toán',
        vietQrCode: 'INV01',
        dueDate: now,
        paidAt: now,
        createdAt: now,
      ),
      InvoiceTableRowItem(
        id: '2',
        apartmentCode: 'A0102',
        residentName: 'Le C',
        period: '2026-10',
        totalAmount: 2000000,
        status: 'unpaid',
        displayStatus: 'Chờ thanh toán',
        vietQrCode: 'INV02',
        dueDate: now.add(const Duration(days: 5)),
        createdAt: now,
      ),
      InvoiceTableRowItem(
        id: '3',
        apartmentCode: 'A0103',
        residentName: 'Pham D',
        period: '2026-10',
        totalAmount: 1000000,
        status: 'overdue',
        displayStatus: 'Quá hạn',
        vietQrCode: 'INV03',
        dueDate: now.subtract(const Duration(days: 5)),
        createdAt: now,
      ),
    ];

    test('tinh toan summary tu danh sach rows chuan xac', () {
      final summary = AccountingWorkstationSummary.fromRows(items);

      expect(summary.totalInvoices, 3);
      expect(summary.totalAmount, 4000000);
      expect(summary.paidAmount, 1000000);
      expect(summary.unpaidAmount, 2000000);
      expect(summary.overdueAmount, 1000000);
      expect(summary.collectionRate, 25.0); // 1.000.000 / 4.000.000 = 25%
    });

    test('collectionRate bang 0 neu tong tien la 0', () {
      final summary = AccountingWorkstationSummary.fromRows([]);
      expect(summary.totalInvoices, 0);
      expect(summary.totalAmount, 0);
      expect(summary.collectionRate, 0.0);
    });
  });
}
