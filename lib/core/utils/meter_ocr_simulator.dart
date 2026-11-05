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

    final unit = meterType == MeterType.electric ? 'kWh' : 'm³';
    // Bỏ cộng ngẫu nhiên gây sai lệch dữ liệu tài chính, giữ đúng chỉ số hiện tại để người dùng xác nhận từ ảnh thật
    final detectedReading = currentReading;
    final rawText = "ĐỒNG HỒ ${meterType == MeterType.electric ? 'ĐIỆN' : 'NƯỚC'}: ${detectedReading.toStringAsFixed(1)} $unit";
    final confidence = 1.0;

    return MeterOcrResult(
      detectedReading: detectedReading,
      meterType: meterType,
      confidence: confidence,
      unit: unit,
      rawText: rawText,
    );
  }
}
