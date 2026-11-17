import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/building_utility_rate_model.dart';
import 'package:vivona/data/models/meter_reading_submission_model.dart';

void main() {
  group('Utility Billing Models Tests', () {
    test('BuildingUtilityRateModel: parse JSON chính xác biểu giá cố định và tính toán', () {
      final json = {
        'id': 'rate-elec-001',
        'utility_type': 'electricity',
        'pricing_model': 'fixed',
        'base_unit_price': 3500.0,
        'vat_percentage': 8.0,
        'environment_fee_percentage': 0.0,
        'tiers': [],
        'effective_from': '2026-01-01',
        'is_active': true,
      };

      final model = BuildingUtilityRateModel.fromJson(json);

      expect(model.id, 'rate-elec-001');
      expect(model.utilityType, 'electricity');
      expect(model.isElectricity, isTrue);
      expect(model.isWater, isFalse);
      expect(model.baseUnitPrice, 3500.0);
      expect(model.vatPercentage, 8.0);
      expect(model.isActive, isTrue);

      final charge = model.calculateCost(100.0);
      expect(charge['subtotal'], 350000.0);
      expect(charge['vat_amount'], 28000.0);
      expect(charge['total_amount'], 378000.0);
    });

    test('BuildingUtilityRateModel: parse JSON biểu giá nước có phí môi trường', () {
      final json = {
        'id': 'rate-water-001',
        'utility_type': 'water',
        'pricing_model': 'fixed',
        'base_unit_price': 25000.0,
        'vat_percentage': 5.0,
        'environment_fee_percentage': 10.0,
        'tiers': [],
        'effective_from': '2026-01-01',
        'is_active': true,
      };

      final model = BuildingUtilityRateModel.fromJson(json);
      expect(model.isWater, isTrue);

      final charge = model.calculateCost(10.0);
      expect(charge['subtotal'], 250000.0);
      expect(charge['vat_amount'], 12500.0);
      expect(charge['env_fee_amount'], 25000.0);
      expect(charge['total_amount'], 287500.0);
    });

    test('MeterReadingSubmissionModel: parse đầy đủ các trường tiêu thụ và invoice_id', () {
      final json = {
        'id': 'sub-001',
        'apartment_id': 'apt-a0110',
        'apartment_code': 'A0110',
        'submitted_by': 'user-1',
        'period': '11/2026',
        'electric_reading': 1520.0,
        'water_reading': 85.0,
        'previous_electric_reading': 1370.0,
        'previous_water_reading': 70.0,
        'electric_consumed': 150.0,
        'water_consumed': 15.0,
        'invoice_id': 'inv-12345',
        'reader_id': 'staff-9',
        'status': 'approved',
        'created_at': '2026-11-08T10:00:00Z',
      };

      final model = MeterReadingSubmissionModel.fromJson(json);

      expect(model.id, 'sub-001');
      expect(model.electricConsumed, 150.0);
      expect(model.waterConsumed, 15.0);
      expect(model.effectiveElectricConsumed, 150.0);
      expect(model.effectiveWaterConsumed, 15.0);
      expect(model.invoiceId, 'inv-12345');
      expect(model.hasGeneratedInvoice, isTrue);
      expect(model.readerId, 'staff-9');
    });
  });
}
