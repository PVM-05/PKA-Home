import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/meter_ocr_simulator.dart';
import 'package:pka_home/core/utils/utility_anomaly_detector.dart';

void main() {
  group('UtilityAnomalyDetector Unit Tests', () {
    test('Phát hiện chỉ số lùi (currentReading < previousReading) - Nguy hiểm', () {
      final result = UtilityAnomalyDetector.analyzeReading(
        currentReading: 120.0,
        previousReading: 150.0,
        averageUsage: 40.0,
        meterType: MeterType.electric,
      );

      expect(result.isAnomaly, isTrue);
      expect(result.severity, AnomalySeverity.danger);
      expect(result.reason, contains('nhỏ hơn chỉ số kỳ trước'));
      expect(result.deltaUsage, -30.0);
    });

    test('Phát hiện tiêu thụ tăng vọt cực đại (gấp > 2.5 lần trung bình) - Báo động', () {
      // Trung bình 15 m3 nước, tháng này vọt lên 45 m3 (tăng 200%)
      final result = UtilityAnomalyDetector.analyzeReading(
        currentReading: 245.0,
        previousReading: 200.0,
        averageUsage: 15.0,
        meterType: MeterType.water,
      );

      expect(result.isAnomaly, isTrue);
      expect(result.severity, AnomalySeverity.danger);
      expect(result.reason, contains('tăng đột biến'));
      expect(result.deltaUsage, 45.0);
      expect(result.percentChange, 200.0);
    });

    test('Phát hiện tiêu thụ tăng cao (tăng > 50% trung bình) - Cảnh báo', () {
      // Trung bình 100 kWh, tháng này dùng 160 kWh (tăng 60%)
      final result = UtilityAnomalyDetector.analyzeReading(
        currentReading: 1160.0,
        previousReading: 1000.0,
        averageUsage: 100.0,
        meterType: MeterType.electric,
      );

      expect(result.isAnomaly, isTrue);
      expect(result.severity, AnomalySeverity.warning);
      expect(result.reason, contains('tăng cao'));
      expect(result.deltaUsage, 160.0);
      expect(result.percentChange, 60.0);
    });

    test('Phát hiện tiêu thụ bằng 0 khi trước đó có trung bình sử dụng - Lưu ý', () {
      final result = UtilityAnomalyDetector.analyzeReading(
        currentReading: 500.0,
        previousReading: 500.0,
        averageUsage: 80.0,
        meterType: MeterType.electric,
      );

      expect(result.isAnomaly, isTrue);
      expect(result.severity, AnomalySeverity.info);
      expect(result.reason, contains('bằng 0'));
      expect(result.deltaUsage, 0.0);
    });

    test('Tiêu thụ bình thường trong ngưỡng an toàn', () {
      // Trung bình 120 kWh, tháng này dùng 130 kWh (tăng ~8.3%)
      final result = UtilityAnomalyDetector.analyzeReading(
        currentReading: 1130.0,
        previousReading: 1000.0,
        averageUsage: 120.0,
        meterType: MeterType.electric,
      );

      expect(result.isAnomaly, isFalse);
      expect(result.severity, AnomalySeverity.normal);
      expect(result.reason, isNull);
      expect(result.deltaUsage, 130.0);
    });
  });
}
