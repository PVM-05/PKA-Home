import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/maintenance_material_model.dart';

void main() {
  group('MaintenanceMaterialModel Tests', () {
    final jsonSample = {
      'id': 'mat-01',
      'building_id': 'bld-01',
      'code': 'MAT-ELEC-01',
      'name': 'Bóng đèn LED Rạng Đông 18W',
      'category': 'electrical',
      'unit': 'cái',
      'unit_price': 65000,
      'stock_quantity': 4,
      'min_stock_alert': 5,
      'created_at': '2026-11-01T10:00:00.000Z',
      'updated_at': '2026-11-02T10:00:00.000Z',
    };

    test('fromJson parses data correctly', () {
      final model = MaintenanceMaterialModel.fromJson(jsonSample);

      expect(model.id, 'mat-01');
      expect(model.buildingId, 'bld-01');
      expect(model.code, 'MAT-ELEC-01');
      expect(model.name, 'Bóng đèn LED Rạng Đông 18W');
      expect(model.category, 'electrical');
      expect(model.unit, 'cái');
      expect(model.unitPrice, 65000.0);
      expect(model.stockQuantity, 4);
      expect(model.minStockAlert, 5);

      // Helper getters
      expect(model.isLowStock, isTrue); // 4 <= 5
      expect(model.categoryDisplayName, 'Điện');
      expect(model.priceFormatted, contains('65.000'));
    });

    test('toJson serializes correctly', () {
      final model = MaintenanceMaterialModel.fromJson(jsonSample);
      final json = model.toJson();

      expect(json['code'], 'MAT-ELEC-01');
      expect(json['stock_quantity'], 4);
      expect(json['category'], 'electrical');
    });

    test('copyWith updates fields correctly', () {
      final model = MaintenanceMaterialModel.fromJson(jsonSample);
      final updated = model.copyWith(stockQuantity: 15);

      expect(updated.stockQuantity, 15);
      expect(updated.isLowStock, isFalse);
    });
  });
}

