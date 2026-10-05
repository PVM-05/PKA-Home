import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/meter_ocr_simulator.dart';

void main() {
  group('MeterOcrSimulator Tests', () {
    test('simulateScan trích xuất số liệu điện hợp lý (lớn hơn chỉ số cũ)', () async {
      const oldReading = 1250.0;
      final result = await MeterOcrSimulator.simulateScan(
        meterType: MeterType.electric,
        currentReading: oldReading,
        simulatedDelayMs: 50, // Test nhanh
      );

      expect(result.detectedReading, greaterThanOrEqualTo(oldReading));
      expect(result.meterType, MeterType.electric);
      expect(result.confidence, greaterThanOrEqualTo(0.95));
      expect(result.unit, 'kWh');
    });

    test('simulateScan trích xuất số liệu nước hợp lý (lớn hơn chỉ số cũ)', () async {
      const oldReading = 80.0;
      final result = await MeterOcrSimulator.simulateScan(
        meterType: MeterType.water,
        currentReading: oldReading,
        simulatedDelayMs: 50, // Test nhanh
      );

      expect(result.detectedReading, greaterThanOrEqualTo(oldReading));
      expect(result.meterType, MeterType.water);
      expect(result.confidence, greaterThanOrEqualTo(0.95));
      expect(result.unit, 'm³');
    });
  });
}
