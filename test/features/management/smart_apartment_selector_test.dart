import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/invoice_model.dart';

void main() {
  group('Smart Apartment Selector Logic Tests', () {
    final apartments = [
      ApartmentModel(id: '1', code: 'A0101', buildingCode: 'A', floorNumber: 1, area: 65.0, isEmpty: false),
      ApartmentModel(id: '2', code: 'A0102', buildingCode: 'A', floorNumber: 1, area: 70.0, isEmpty: true), // Căn trống
      ApartmentModel(id: '3', code: 'B0201', buildingCode: 'B', floorNumber: 2, area: 85.0, isEmpty: false),
      ApartmentModel(id: '4', code: 'B0202', buildingCode: 'B', floorNumber: 2, area: 90.0, isEmpty: false),
      ApartmentModel(id: '5', code: 'C0301', buildingCode: 'C', floorNumber: 3, area: 55.0, isEmpty: true), // Căn trống tòa C
    ];

    test('Chỉ lọc các căn hộ có người ở (!isEmpty)', () {
      final occupied = apartments.where((a) => !a.isEmpty).toList();

      expect(occupied.length, equals(3));
      expect(occupied.any((a) => a.code == 'A0102'), isFalse);
      expect(occupied.any((a) => a.code == 'C0301'), isFalse);
    });

    test('Lấy danh sách các tòa nhà có căn hộ có người ở', () {
      final occupied = apartments.where((a) => !a.isEmpty).toList();
      final buildings = occupied.map((a) => a.buildingCode.toUpperCase()).toSet().toList()..sort();

      expect(buildings, equals(['A', 'B']));
      expect(buildings.contains('C'), isFalse); // Tòa C toàn căn trống nên không xuất hiện
    });

    test('Lọc căn hộ theo tòa nhà đã chọn', () {
      final occupied = apartments.where((a) => !a.isEmpty).toList();
      
      final buildingAApartments = occupied.where((a) => a.buildingCode.toUpperCase() == 'A').toList();
      expect(buildingAApartments.length, equals(1));
      expect(buildingAApartments.first.code, equals('A0101'));

      final buildingBApartments = occupied.where((a) => a.buildingCode.toUpperCase() == 'B').toList();
      expect(buildingBApartments.length, equals(2));
      expect(buildingBApartments.map((a) => a.code).toList(), equals(['B0201', 'B0202']));
    });
  });

  group('InvoiceModel Unit Tests', () {
    test('fromJson maps correctly including nested apartment', () {
      final json = {
        'id': 'inv-123',
        'apartment_id': 'apt-456',
        'period': '09/2026',
        'due_date': '2026-09-15',
        'total_amount': 1500000.0,
        'status': 'unpaid',
        'created_at': '2026-09-01T08:00:00Z',
        'apartments': {
          'id': 'apt-456',
          'code': 'A0110',
          'building_code': 'A',
          'floor_number': 1,
          'area': 75.5,
          'is_empty': false,
        }
      };

      final invoice = InvoiceModel.fromJson(json);

      expect(invoice.id, equals('inv-123'));
      expect(invoice.period, equals('09/2026'));
      expect(invoice.totalAmount, equals(1500000.0));
      expect(invoice.status, equals('unpaid'));
      expect(invoice.apartment, isNotNull);
      expect(invoice.apartment?.code, equals('A0110'));
      expect(invoice.apartment?.area, equals(75.5));
    });
  });
}
