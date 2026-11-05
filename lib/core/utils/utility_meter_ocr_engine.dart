import 'meter_ocr_simulator.dart';

class MeterOcrParsedResult {
  final bool isValid;
  final double detectedReading;
  final String unit;
  final double confidence;
  final String rawText;
  final String? errorMessage;

  const MeterOcrParsedResult({
    required this.isValid,
    required this.detectedReading,
    required this.unit,
    required this.confidence,
    required this.rawText,
    this.errorMessage,
  });

  factory MeterOcrParsedResult.invalid({
    required String rawText,
    required String unit,
    String? errorMessage,
  }) {
    return MeterOcrParsedResult(
      isValid: false,
      detectedReading: 0.0,
      unit: unit,
      confidence: 0.2,
      rawText: rawText,
      errorMessage:
          errorMessage ?? 'Không tìm thấy số đo hợp lệ trên mặt công tơ.',
    );
  }
}

class UtilityMeterOcrEngine {
  UtilityMeterOcrEngine._();

  /// Phân tích bóc tách chỉ số công tơ từ văn bản OCR (thu được từ camera / text recognizer)
  static MeterOcrParsedResult parseReadingFromOcrText({
    required String rawText,
    required MeterType meterType,
  }) {
    final defaultUnit = meterType == MeterType.electric ? 'kWh' : 'm³';
    if (rawText.trim().isEmpty) {
      return MeterOcrParsedResult.invalid(
        rawText: rawText,
        unit: defaultUnit,
        errorMessage: 'Hình ảnh không có văn bản hoặc quá mờ.',
      );
    }

    // Chuẩn hóa văn bản
    final normalized = rawText
        .replaceAll('m3', 'm³')
        .replaceAll('M3', 'm³')
        .replaceAll('kwh', 'kWh')
        .replaceAll('KWH', 'kWh')
        .replaceAll('Kwh', 'kWh');

    // Loại bỏ lưu lượng tức thời dòng chảy Qn, Q3 m³/h để tránh nhầm với chỉ số tích lũy
    final cleaned = normalized
        .replaceAll(
          RegExp(r'Q[n3]?\s*\d+[\.,]?\d*\s*m[³3]/h', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\d+[\.,]?\d*\s*m[³3]/h', caseSensitive: false), '')
        .replaceAll(
          RegExp(r'\d+[\.,]?\d*\s*rev/kWh', caseSensitive: false),
          '',
        );

    // 1. Tìm kiếm cụm số đi liền ngay trước đơn vị đo (kWh hoặc m³ đứng riêng không có /h)
    final unitKeyword = meterType == MeterType.electric ? 'kWh' : 'm³';
    final patternWithUnit = RegExp(
      r'(\d{1,7}(?:[\.,]\d{1,3})?)\s*' +
          RegExp.escape(unitKeyword) +
          r'(?!\s*/)',
      caseSensitive: false,
    );

    final matchesWithUnit = patternWithUnit.allMatches(cleaned).toList();
    if (matchesWithUnit.isNotEmpty) {
      // Ưu tiên match cuối cùng hoặc match có nhiều chữ số nhất (tránh số nhỏ như cấp chính xác)
      matchesWithUnit.sort((a, b) {
        final aVal = a.group(1)!.length;
        final bVal = b.group(1)!.length;
        return bVal.compareTo(aVal);
      });

      final bestMatch = matchesWithUnit.first;
      final numStr = bestMatch.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(numStr);
      if (val != null) {
        return MeterOcrParsedResult(
          isValid: true,
          detectedReading: val,
          unit: defaultUnit,
          confidence: 0.95,
          rawText: rawText,
        );
      }
    }

    // 2. Tìm kiếm theo dòng chứa số đo công tơ
    final lines = cleaned.split('\n');
    for (final line in lines) {
      final cleanLine = line.trim();
      // Bỏ qua các dòng chứa thông số kỹ thuật điện áp/dòng điện/tần số
      if (meterType == MeterType.electric &&
          (cleanLine.contains('220V') ||
              cleanLine.contains('50Hz') ||
              cleanLine.contains('(40)A') ||
              cleanLine.contains('(20)A') ||
              cleanLine.contains('(60)A'))) {
        continue;
      }

      // Tìm số thực có từ 3 đến 7 chữ số (có thể có 1-2 số thập phân)
      final numberRegex = RegExp(r'\b(\d{3,7}(?:[\.,]\d{1,2})?)\b');
      final matches = numberRegex.allMatches(cleanLine);
      for (final m in matches) {
        final parsedStr = m.group(1)!.replaceAll(',', '.');
        final val = double.tryParse(parsedStr);
        if (val != null && val > 0) {
          final confidence = cleanLine.contains(unitKeyword) ? 0.90 : 0.85;
          return MeterOcrParsedResult(
            isValid: true,
            detectedReading: val,
            unit: defaultUnit,
            confidence: confidence,
            rawText: rawText,
          );
        }
      }
    }

    // Không tìm thấy số hợp lệ
    return MeterOcrParsedResult.invalid(rawText: rawText, unit: defaultUnit);
  }
}
