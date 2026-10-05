import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/bulk_invoice_validation_model.dart';

void main() {
  group('BulkInvoiceValidationModel Tests', () {
    final sampleJson = {
      'period': '10/2026',
      'total_scanned': 280,
      'valid_count': 270,
      'missing_count': 7,
      'invalid_count': 3,
      'already_invoiced_count': 0,
      'total_estimated_amount': 395000000,
      'valid_items': [
        {
          'apartment_id': 'apt-101',
          'apartment_code': 'A0110',
          'area': 75.5,
          'electric_usage': 140.0,
          'water_usage': 11.0,
          'estimated_total': 1480000.0,
        },
      ],
      'issues': [
        {
          'apartment_id': 'apt-105',
          'apartment_code': 'A0105',
          'type': 'missing_data',
          'message': 'Chưa có chỉ số nước tháng 10/2026',
        },
        {
          'apartment_id': 'apt-203',
          'apartment_code': 'A0203',
          'type': 'invalid_reading',
          'message': 'Chỉ số điện mới nhỏ hơn chỉ số cũ',
        },
      ],
    };

    test('fromJson va toJson anh xa day du cac truong', () {
      final model = BulkInvoiceValidationModel.fromJson(sampleJson);

      expect(model.period, '10/2026');
      expect(model.totalScanned, 280);
      expect(model.validCount, 270);
      expect(model.missingCount, 7);
      expect(model.invalidCount, 3);
      expect(model.alreadyInvoicedCount, 0);
      expect(model.totalEstimatedAmount, 395000000.0);

      // Kiem tra valid_items
      expect(model.validItems.length, 1);
      final item = model.validItems.first;
      expect(item.apartmentCode, 'A0110');
      expect(item.electricUsage, 140.0);
      expect(item.waterUsage, 11.0);
      expect(item.estimatedTotal, 1480000.0);

      // Kiem tra issues
      expect(model.issues.length, 2);
      expect(model.issues[0].apartmentCode, 'A0105');
      expect(model.issues[0].isMissingData, isTrue);
      expect(model.issues[0].typeDisplayName, 'Thiếu dữ liệu');
      expect(model.issues[1].apartmentCode, 'A0203');
      expect(model.issues[1].isInvalidReading, isTrue);
      expect(model.issues[1].typeDisplayName, 'Bất thường');

      // Helper getters
      expect(model.canGenerateAny, isTrue);
      expect(model.totalIssuesCount, 10);
    });

    test('Helper getters khi validCount = 0', () {
      final emptyValidJson = {
        'period': '10/2026',
        'total_scanned': 10,
        'valid_count': 0,
        'missing_count': 5,
        'invalid_count': 5,
        'already_invoiced_count': 0,
        'total_estimated_amount': 0,
        'valid_items': [],
        'issues': [],
      };

      final model = BulkInvoiceValidationModel.fromJson(emptyValidJson);
      expect(model.canGenerateAny, isFalse);
      expect(model.totalIssuesCount, 10);
    });
  });
}
