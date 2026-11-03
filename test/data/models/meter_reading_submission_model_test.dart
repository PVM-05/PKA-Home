import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/meter_reading_submission_model.dart';

void main() {
  group('MeterReadingSubmissionModel Tests with Anomaly & OCR fields', () {
    test('Khởi tạo và parse fromJson đầy đủ thông tin anomaly và ocr', () {
      final json = {
        'id': 'sub-123',
        'apartment_id': 'apt-456',
        'apartment_code': 'A0110',
        'submitted_by': 'user-789',
        'submitter_name': 'Nguyễn Văn A',
        'period': '11/2026',
        'electric_reading': 1580.5,
        'water_reading': 185.0,
        'electric_image_url': 'https://example.com/elec.jpg',
        'water_image_url': 'https://example.com/water.jpg',
        'status': 'pending',
        'ocr_confidence': 0.965,
        'is_anomaly': true,
        'anomaly_severity': 'danger',
        'anomaly_reason': 'Tiêu thụ nước tăng đột biến 120% (nghi ngờ rò rỉ)',
        'previous_electric_reading': 1450.0,
        'previous_water_reading': 150.0,
        'avg_electric_usage': 130.0,
        'avg_water_usage': 16.0,
        'created_at': '2026-11-03T08:00:00Z',
      };

      final model = MeterReadingSubmissionModel.fromJson(json);

      expect(model.id, 'sub-123');
      expect(model.apartmentCode, 'A0110');
      expect(model.electricReading, 1580.5);
      expect(model.waterReading, 185.0);
      expect(model.ocrConfidence, 0.965);
      expect(model.isAnomaly, isTrue);
      expect(model.isDangerAnomaly, isTrue);
      expect(model.isWarningAnomaly, isFalse);
      expect(model.anomalySeverityDisplayName, 'Báo động');
      expect(model.anomalyReason, contains('rò rỉ'));
      expect(model.previousElectricReading, 1450.0);
      expect(model.previousWaterReading, 150.0);
      expect(model.avgElectricUsage, 130.0);
      expect(model.avgWaterUsage, 16.0);
    });

    test('toJson và copyWith hoạt động trơn tru với các trường mới', () {
      final model = MeterReadingSubmissionModel(
        id: 'sub-001',
        apartmentId: 'apt-001',
        submittedBy: 'user-001',
        period: '11/2026',
        electricReading: 500.0,
        waterReading: 50.0,
        isAnomaly: false,
        anomalySeverity: 'normal',
        ocrConfidence: 0.98,
        createdAt: DateTime(2026, 11, 3),
      );

      final updated = model.copyWith(
        isAnomaly: true,
        anomalySeverity: 'warning',
        anomalyReason: 'Tiêu thụ tăng 55%',
      );

      expect(updated.isAnomaly, isTrue);
      expect(updated.isWarningAnomaly, isTrue);
      expect(updated.anomalySeverityDisplayName, 'Cảnh báo');

      final json = updated.toJson();
      expect(json['is_anomaly'], isTrue);
      expect(json['anomaly_severity'], 'warning');
      expect(json['anomaly_reason'], 'Tiêu thụ tăng 55%');
    });
  });
}
