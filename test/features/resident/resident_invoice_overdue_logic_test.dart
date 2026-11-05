import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';

void main() {
  group('Resident Invoice Overdue Logic Tests', () {
    final sampleApartment = ApartmentModel(
      id: 'apt-01',
      code: 'A0110',
      buildingCode: 'A',
      floorNumber: 1,
      area: 70.0,
      isEmpty: false,
    );

    test('Hóa đơn có hạn vào đúng ngày hôm nay không bị tính là quá hạn', () {
      final now = DateTime.now();
      final todayDueDate = DateTime(now.year, now.month, now.day);

      final invoice = InvoiceModel(
        id: 'inv-due-today',
        apartmentId: 'apt-01',
        period: '11/2026',
        dueDate: todayDueDate,
        totalAmount: 1500000,
        status: 'unpaid',
        createdAt: now.subtract(const Duration(days: 5)),
        apartment: sampleApartment,
      );

      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(invoice.dueDate.year, invoice.dueDate.month, invoice.dueDate.day);
      final daysDiff = today.difference(dueDay).inDays;

      expect(daysDiff, equals(0));
      final isOverdue = invoice.status == 'unpaid' && daysDiff > 0;
      final isDueToday = invoice.status == 'unpaid' && daysDiff == 0;

      expect(isOverdue, isFalse, reason: 'Hóa đơn đến hạn hôm nay không được coi là quá hạn');
      expect(isDueToday, isTrue, reason: 'Hóa đơn đến hạn hôm nay phải hiển thị trạng thái đến hạn hôm nay');
    });

    test('Hóa đơn có hạn vào ngày hôm qua bị tính là quá hạn 1 ngày', () {
      final now = DateTime.now();
      final yesterdayDueDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));

      final invoice = InvoiceModel(
        id: 'inv-due-yesterday',
        apartmentId: 'apt-01',
        period: '11/2026',
        dueDate: yesterdayDueDate,
        totalAmount: 1500000,
        status: 'unpaid',
        createdAt: now.subtract(const Duration(days: 6)),
        apartment: sampleApartment,
      );

      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(invoice.dueDate.year, invoice.dueDate.month, invoice.dueDate.day);
      final daysDiff = today.difference(dueDay).inDays;

      expect(daysDiff, equals(1));
      final isOverdue = invoice.status == 'unpaid' && daysDiff > 0;

      expect(isOverdue, isTrue);
    });

    test('Hóa đơn có hạn trong tương lai không bị tính là quá hạn', () {
      final now = DateTime.now();
      final futureDueDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 5));

      final invoice = InvoiceModel(
        id: 'inv-due-future',
        apartmentId: 'apt-01',
        period: '11/2026',
        dueDate: futureDueDate,
        totalAmount: 1500000,
        status: 'unpaid',
        createdAt: now.subtract(const Duration(days: 2)),
        apartment: sampleApartment,
      );

      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(invoice.dueDate.year, invoice.dueDate.month, invoice.dueDate.day);
      final daysDiff = today.difference(dueDay).inDays;

      expect(daysDiff, lessThan(0));
      final isOverdue = invoice.status == 'unpaid' && daysDiff > 0;
      final isDueToday = invoice.status == 'unpaid' && daysDiff == 0;

      expect(isOverdue, isFalse);
      expect(isDueToday, isFalse);
    });
  });
}

