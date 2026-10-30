import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';
import 'package:pka_home/data/providers/accounting_workstation_provider.dart';

void main() {
  group('AccountingWorkstationProvider Tests', () {
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
      InvoiceModel(
        id: 'inv-3',
        apartmentId: 'apt-3',
        period: '2026-09',
        dueDate: now.subtract(const Duration(days: 30)),
        totalAmount: 1200000,
        status: 'paid',
        createdAt: now,
        paidAt: now.subtract(const Duration(days: 25)),
        paymentCode: 'INV202609B0101',
        apartment: ApartmentModel(
          id: 'apt-3',
          code: 'b0101',
          buildingCode: 'B',
          floorNumber: 1,
        ),
      ),
    ];

    test('khoi tao filter mac dinh va loc dung', () {
      final container = ProviderContainer(
        overrides: [
          accountingWorkstationRawInvoicesProvider.overrideWith((ref) => Future.value(mockInvoices)),
        ],
      );
      addTearDown(container.dispose);

      // Ban dau chua apply filter
      final filter = container.read(accountingWorkstationFilterProvider);
      expect(filter.searchQuery, '');
      expect(filter.period, isNull);
      expect(filter.status, isNull);

      // Thay doi filter theo period
      container.read(accountingWorkstationFilterProvider.notifier).state =
          filter.copyWith(period: '2026-10');

      final updatedFilter = container.read(accountingWorkstationFilterProvider);
      expect(updatedFilter.period, '2026-10');
    });

    test('quan ly selection va toggle toan bo', () {
      final container = ProviderContainer(
        overrides: [
          accountingWorkstationRawInvoicesProvider.overrideWith((ref) => Future.value(mockInvoices)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(selectedInvoiceIdsProvider.notifier);
      expect(container.read(selectedInvoiceIdsProvider).isEmpty, isTrue);

      notifier.toggle('inv-1');
      expect(container.read(selectedInvoiceIdsProvider).contains('inv-1'), isTrue);

      notifier.toggle('inv-1');
      expect(container.read(selectedInvoiceIdsProvider).contains('inv-1'), isFalse);

      notifier.selectAll(['inv-1', 'inv-2', 'inv-3']);
      expect(container.read(selectedInvoiceIdsProvider).length, 3);

      notifier.clear();
      expect(container.read(selectedInvoiceIdsProvider).isEmpty, isTrue);
    });

    test('exportWorkstationToCsv tao dinh dang CSV kem BOM UTF-8', () {
      final rows = mockInvoices
          .map((inv) => InvoiceTableRowItem.fromInvoice(inv, residentName: 'Cư dân thử nghiệm'))
          .toList();

      final csv = exportWorkstationToCsv(rows);

      // Kiem tra UTF-8 BOM
      expect(csv.startsWith('\uFEFF'), isTrue);
      // Kiem tra tieu de cot
      expect(csv.contains('Mã Căn Hộ,Cư Dân,Kỳ Thu,Tổng Tiền (VNĐ),Trạng Thái,Mã VietQR,Hạn Thanh Toán,Ngày Nộp'), isTrue);
      // Kiem tra du lieu
      expect(csv.contains('A0110'), isTrue);
      expect(csv.contains('INV202610A0110'), isTrue);
    });
  });
}
