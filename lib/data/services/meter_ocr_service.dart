import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../core/utils/utility_meter_ocr_engine.dart';

export '../../core/utils/utility_meter_ocr_engine.dart'
    show MeterOcrParsedResult, MeterType;

/// Interface nhận diện văn bản từ hình ảnh (cho phép mock trong test hoặc thay thế engine)
abstract class MeterTextRecognizer {
  Future<String> recognizeTextFromPath(String imagePath);
  Future<void> dispose();
}

/// Triển khai nhận diện ký tự quang học sử dụng Google ML Kit On-Device Text Recognition
class MlKitMeterTextRecognizer implements MeterTextRecognizer {
  TextRecognizer? _recognizer;

  MlKitMeterTextRecognizer({TextRecognizer? recognizer}) {
    _recognizer = recognizer;
  }

  TextRecognizer _getOrCreateRecognizer() {
    return _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
  }

  @override
  Future<String> recognizeTextFromPath(String imagePath) async {
    // Chỉ chạy ML Kit trên Android hoặc iOS có platform channels hỗ trợ
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return '';
    }

    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizer = _getOrCreateRecognizer();
    final RecognizedText recognizedText = await recognizer.processImage(inputImage);
    return recognizedText.text;
  }

  @override
  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}

/// Dịch vụ OCR công tơ điện và nước thực tế
class MeterOcrService {
  final MeterTextRecognizer _textRecognizer;

  MeterOcrService({MeterTextRecognizer? textRecognizer})
      : _textRecognizer = textRecognizer ?? MlKitMeterTextRecognizer();

  /// Quét hình ảnh công tơ thực tế và bóc tách số đo tiêu thụ
  Future<MeterOcrParsedResult> recognizeMeterReading({
    required String imagePath,
    required MeterType meterType,
  }) async {
    final defaultUnit = meterType == MeterType.electric ? 'kWh' : 'm³';

    if (imagePath.trim().isEmpty) {
      return MeterOcrParsedResult.invalid(
        rawText: '',
        unit: defaultUnit,
        errorMessage: 'Đường dẫn ảnh công tơ không hợp lệ hoặc để trống.',
      );
    }

    try {
      final rawText = await _textRecognizer.recognizeTextFromPath(imagePath);
      if (rawText.trim().isEmpty) {
        return MeterOcrParsedResult.invalid(
          rawText: '',
          unit: defaultUnit,
          errorMessage:
              'Không nhận diện được ký tự nào từ ảnh công tơ. Vui lòng chụp rõ nét mặt đồng hồ.',
        );
      }

      return UtilityMeterOcrEngine.parseReadingFromOcrText(
        rawText: rawText,
        meterType: meterType,
      );
    } catch (e) {
      return MeterOcrParsedResult.invalid(
        rawText: '',
        unit: defaultUnit,
        errorMessage: 'Lỗi trong quá trình quét OCR: $e',
      );
    }
  }

  Future<void> dispose() async {
    await _textRecognizer.dispose();
  }
}

/// Riverpod provider cho MeterOcrService
final meterOcrServiceProvider = Provider<MeterOcrService>((ref) {
  final service = MeterOcrService();
  ref.onDispose(() => service.dispose());
  return service;
});
