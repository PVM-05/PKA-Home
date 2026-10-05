import 'dart:math';

enum MeterType {
  electric,
  water,
}

class MeterOcrResult {
  final double detectedReading;
  final MeterType meterType;
  final double confidence;
  final String unit;
  final String rawText;

  const MeterOcrResult({
    required this.detectedReading,
    required this.meterType,
    required this.confidence,
    required this.unit,
    required this.rawText,
  });
}

class MeterOcrSimulator {
  MeterOcrSimulator._();

  /// Giả lập quá trình phân tích thị giác máy tính / OCR để trích xuất số liệu từ ảnh công tơ
  static Future<MeterOcrResult> simulateScan({
    required MeterType meterType,
    double currentReading = 0.0,
    int simulatedDelayMs = 1200,
    String? imagePath,
  }) async {
    if (simulatedDelayMs > 0) {
      await Future.delayed(Duration(milliseconds: simulatedDelayMs));
    }

    final random = Random();
    double detectedReading;
    String unit;
    String rawText;
    final confidence = 0.96 + (random.nextDouble() * 0.035); // 96% - 99.5%

    if (meterType == MeterType.electric) {
      unit = 'kWh';
      // Chỉ số điện tăng bình quân 120 - 180 kWh
      final delta = 130.0 + random.nextInt(50);
      detectedReading = double.parse((currentReading + delta).toStringAsFixed(1));
      rawText = "ĐỒNG HỒ ĐIỆN VINA-EMIC: ${detectedReading.toStringAsFixed(1)} kWh (Chính xác ${(confidence * 100).toStringAsFixed(1)}%)";
    } else {
      unit = 'm³';
      // Chỉ số nước tăng bình quân 8 - 16 m³
      final delta = 9.0 + random.nextInt(8);
      detectedReading = double.parse((currentReading + delta).toStringAsFixed(1));
      rawText = "ĐỒNG HỒ NƯỚC MINOL: ${detectedReading.toStringAsFixed(1)} m³ (Chính xác ${(confidence * 100).toStringAsFixed(1)}%)";
    }

    return MeterOcrResult(
      detectedReading: detectedReading,
      meterType: meterType,
      confidence: confidence,
      unit: unit,
      rawText: rawText,
    );
  }
}
