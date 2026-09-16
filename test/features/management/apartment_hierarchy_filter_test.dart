import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_model.dart';

void main() {
  group('Apartment Hierarchy & Filter Tests', () {
    final mockApartments = [
      ApartmentModel(id: '1', code: 'A0101', buildingCode: 'A', floorNumber: 1, area: 55.0, isEmpty: false),
      ApartmentModel(id: '2', code: 'A0102', buildingCode: 'A', floorNumber: 1, area: 60.0, isEmpty: true),
      ApartmentModel(id: '3', code: 'A0201', buildingCode: 'A', floorNumber: 2, area: 75.0, isEmpty: false),
      ApartmentModel(id: '4', code: 'B0101', buildingCode: 'B', floorNumber: 1, area: 55.0, isEmpty: true),
      ApartmentModel(id: '5', code: 'B0305', buildingCode: 'B', floorNumber: 3, area: 90.0, isEmpty: false),
    ];

    test('Lấy danh sách các Tòa nhà duy nhất đã sắp xếp', () {
      final buildings = mockApartments
          .map((a) => a.buildingCode.toUpperCase())
          .where((b) => b.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      expect(buildings, equals(['A', 'B']));
    });

    test('Lấy danh sách các Tầng duy nhất theo Tòa nhà đã chọn', () {
      final floorsBuildingA = mockApartments
          .where((a) => a.buildingCode.toUpperCase() == 'A')
          .map((a) => a.floorNumber)
          .toSet()
          .toList()
        ..sort();

      expect(floorsBuildingA, equals([1, 2]));

      final floorsBuildingB = mockApartments
          .where((a) => a.buildingCode.toUpperCase() == 'B')
          .map((a) => a.floorNumber)
          .toSet()
          .toList()
        ..sort();

      expect(floorsBuildingB, equals([1, 3]));
    });

    test('Lọc theo Tòa, Tầng và Trạng thái', () {
      // 1. Lọc Tòa A + Tầng 1
      var filtered = mockApartments.where((a) {
        return a.buildingCode.toUpperCase() == 'A' && a.floorNumber == 1;
      }).toList();
      expect(filtered.length, equals(2));

      // 2. Lọc Tòa A + Tầng 1 + Chỉ phòng trống
      filtered = mockApartments.where((a) {
        return a.buildingCode.toUpperCase() == 'A' &&
            a.floorNumber == 1 &&
            a.isEmpty == true;
      }).toList();
      expect(filtered.length, equals(1));
      expect(filtered.first.code, equals('A0102'));

      // 3. Lọc theo search query mã phòng
      const query = '0305';
      filtered = mockApartments.where((a) {
        return a.code.toLowerCase().contains(query.toLowerCase());
      }).toList();
      expect(filtered.length, equals(1));
      expect(filtered.first.code, equals('B0305'));
    });
  });
}
