import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/meter_ocr_simulator.dart';
import 'package:pka_home/core/utils/utility_meter_ocr_engine.dart';

void main() {
  group('UtilityMeterOcrEngine Unit Tests', () {
    test('Bóc tách chỉ số điện từ chuỗi OCR có đơn vị kWh và thông số kỹ thuật', () {
      const rawText = '''
        CONG TY DIEN LUC
        VINA-EMIC 1 PHA 2 DAY
        220V 50Hz 10(40)A 450 rev/kWh
        SO CONG TO: 082914
        01485.6 kWh
      ''';

      final result = UtilityMeterOcrEngine.parseReadingFromOcrText(
        rawText: rawText,
        meterType: MeterType.electric,
      );

      expect(result.isValid, isTrue);
      expect(result.detectedReading, 1485.6);
      expect(result.unit, 'kWh');
      expect(result.confidence, greaterThanOrEqualTo(0.85));
    });

    test('Bóc tách chỉ số điện từ đồng hồ điện tử LCD', () {
      const rawText = 'TỔNG ĐIỆN NĂNG: 00352.0 KWH';

      final result = UtilityMeterOcrEngine.parseReadingFromOcrText(
        rawText: rawText,
        meterType: MeterType.electric,
      );

      expect(result.isValid, isTrue);
      expect(result.detectedReading, 352.0);
      expect(result.unit, 'kWh');
    });

    test('Bóc tách chỉ số nước từ chuỗi OCR đồng hồ nước m³', () {
      const rawText = '''
        DONG HO NUOC MINOL
        Qn 1.5 m3/h
        CLASS B - ISO 4064
        00184.5 m3
      ''';

      final result = UtilityMeterOcrEngine.parseReadingFromOcrText(
        rawText: rawText,
        meterType: MeterType.water,
      );

      expect(result.isValid, isTrue);
      expect(result.detectedReading, 184.5);
      expect(result.unit, 'm³');
      expect(result.confidence, greaterThanOrEqualTo(0.85));
    });

    test('Bóc tách chỉ số nước với dấu phẩy phân cách thập phân', () {
      const rawText = 'CHỈ SỐ: 00095,8 M3';

      final result = UtilityMeterOcrEngine.parseReadingFromOcrText(
        rawText: rawText,
        meterType: MeterType.water,
      );

      expect(result.isValid, isTrue);
      expect(result.detectedReading, 95.8);
      expect(result.unit, 'm³');
    });

    test('Xử lý khi văn bản không chứa chỉ số hợp lệ', () {
      const rawText = 'KHÔNG THỂ NHẬN DIỆN MẶT CÔNG TƠ ẢNH MỜ';

      final result = UtilityMeterOcrEngine.parseReadingFromOcrText(
        rawText: rawText,
        meterType: MeterType.electric,
      );

      expect(result.isValid, isFalse);
      expect(result.detectedReading, 0.0);
      expect(result.confidence, lessThan(0.5));
    });
  });
}

