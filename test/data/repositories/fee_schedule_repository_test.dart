import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/fee_schedule_model.dart';

void main() {
  group('FeeScheduleModel Tests', () {
    test('fromJson parses properly with full and partial fields', () {
      final json = {
        'id': 'fee-123',
        'fee_type': 'electricity',
        'name': 'Tiền điện',
        'unit': 'kWh',
        'unit_price': 3500.0,
        'effective_from': '2026-01-01',
        'effective_to': null,
        'is_active': true,
        'created_at': '2026-01-01T00:00:00Z',
      };

      final model = FeeScheduleModel.fromJson(json);
      expect(model.id, 'fee-123');
      expect(model.feeType, 'electricity');
      expect(model.name, 'Tiền điện');
      expect(model.unit, 'kWh');
      expect(model.unitPrice, 3500.0);
      expect(model.isActive, isTrue);
      expect(model.effectiveTo, isNull);
    });

    test('toJson serializes correctly', () {
      final model = FeeScheduleModel(
        id: 'fee-water',
        feeType: 'water',
        name: 'Tiền nước',
        unit: 'm3',
        unitPrice: 18000.0,
        effectiveFrom: DateTime(2026, 1, 1),
        isActive: true,
      );

      final json = model.toJson();
      expect(json['fee_type'], 'water');
      expect(json['unit_price'], 18000.0);
      expect(json['effective_from'], '2026-01-01');
    });
  });
}
