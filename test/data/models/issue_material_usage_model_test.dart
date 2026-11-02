import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/issue_material_usage_model.dart';

void main() {
  group('IssueMaterialUsageModel Tests', () {
    final jsonSample = {
      'id': 'usage-01',
      'issue_report_id': 'issue-01',
      'material_id': 'mat-01',
      'material_name': 'Bóng đèn LED Rạng Đông 18W',
      'quantity': 2,
      'unit': 'cái',
      'unit_price': 65000,
      'total_amount': 130000,
      'is_chargeable': true,
      'note': 'Thay bóng đèn phòng khách',
      'created_at': '2026-11-02T10:30:00.000Z',
    };

    test('fromJson parses correctly', () {
      final model = IssueMaterialUsageModel.fromJson(jsonSample);

      expect(model.id, 'usage-01');
      expect(model.issueReportId, 'issue-01');
      expect(model.materialId, 'mat-01');
      expect(model.materialName, 'Bóng đèn LED Rạng Đông 18W');
      expect(model.quantity, 2);
      expect(model.unit, 'cái');
      expect(model.unitPrice, 65000.0);
      expect(model.totalAmount, 130000.0);
      expect(model.isChargeable, isTrue);
      expect(model.note, 'Thay bóng đèn phòng khách');

      expect(model.totalAmountFormatted, contains('130.000'));
      expect(model.chargeableDisplayName, 'Tính phí căn hộ');
    });

    test('toJson serializes correctly', () {
      final model = IssueMaterialUsageModel.fromJson(jsonSample);
      final json = model.toJson();

      expect(json['is_chargeable'], isTrue);
      expect(json['quantity'], 2);
      expect(json['total_amount'], 130000.0);
    });
  });
}
