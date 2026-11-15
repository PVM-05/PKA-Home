import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/services/meter_ocr_service.dart';

class MockMeterTextRecognizer implements MeterTextRecognizer {
  final String textToReturn;
  final bool shouldThrow;

  MockMeterTextRecognizer({
    this.textToReturn = '',
    this.shouldThrow = false,
  });

  @override
  Future<String> recognizeTextFromPath(String imagePath) async {
    if (shouldThrow) {
      throw Exception('Camera buffer unreadable');
    }
    return textToReturn;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('MeterOcrService Real Recognition Tests', () {
    test('Nhận diện chính xác chỉ số công tơ điện từ văn bản OCR', () async {
      final mockRecognizer = MockMeterTextRecognizer(
        textToReturn: '''
          EVN HANOI - TỔNG CÔNG TY ĐIỆN LỰC
          Loại công tơ 1 pha 2 dây
          220V 50Hz 10(40)A
          01452.8 kWh
          Cấp chính xác 1.0
        ''',
      );

      final service = MeterOcrService(textRecognizer: mockRecognizer);
      final result = await service.recognizeMeterReading(
        imagePath: '/storage/emulated/0/DCIM/electric_meter.jpg',
        meterType: MeterType.electric,
      );

      expect(result.isValid, isTrue);
      expect(result.detectedReading, 1452.8);
      expect(result.unit, 'kWh');
      expect(result.confidence, greaterThanOrEqualTo(0.9));
    });

    test('Nhận diện chính xác chỉ số công tơ nước từ văn bản OCR', () async {
      final mockRecognizer = MockMeterTextRecognizer(
        textToReturn: '''
          CÔNG TY NƯỚC SẠCH HÀ NỘI
          ĐỒNG HỒ ĐO NƯỚC LẠNH
          Qn 1.5 m3/h Class B
          00085.4 m3
        ''',
      );

      final service = MeterOcrService(textRecognizer: mockRecognizer);
      final result = await service.recognizeMeterReading(
        imagePath: '/storage/emulated/0/DCIM/water_meter.jpg',
        meterType: MeterType.water,
      );

      expect(result.isValid, isTrue);
      expect(result.detectedReading, 85.4);
      expect(result.unit, 'm³');
      expect(result.confidence, greaterThanOrEqualTo(0.9));
    });

    test('Báo lỗi rõ ràng khi hình ảnh mờ hoặc không có ký tự', () async {
      final mockRecognizer = MockMeterTextRecognizer(textToReturn: '   ');
      final service = MeterOcrService(textRecognizer: mockRecognizer);

      final result = await service.recognizeMeterReading(
        imagePath: '/storage/emulated/0/DCIM/blurry.jpg',
        meterType: MeterType.electric,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Không nhận diện được ký tự nào'));
    });

    test('Báo lỗi khi đường dẫn ảnh trống', () async {
      final mockRecognizer = MockMeterTextRecognizer();
      final service = MeterOcrService(textRecognizer: mockRecognizer);

      final result = await service.recognizeMeterReading(
        imagePath: '',
        meterType: MeterType.water,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('không hợp lệ'));
    });

    test('Xử lý an toàn khi engine OCR ném ngoại lệ', () async {
      final mockRecognizer = MockMeterTextRecognizer(shouldThrow: true);
      final service = MeterOcrService(textRecognizer: mockRecognizer);

      final result = await service.recognizeMeterReading(
        imagePath: '/storage/emulated/0/DCIM/error.jpg',
        meterType: MeterType.electric,
      );

      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Lỗi trong quá trình quét OCR'));
    });
  });
}
