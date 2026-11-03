import 'meter_ocr_simulator.dart';

enum AnomalySeverity {
  normal,
  info,
  warning,
  danger,
}

class AnomalyAnalysisResult {
  final bool isAnomaly;
  final AnomalySeverity severity;
  final String? reason;
  final double deltaUsage;
  final double? percentChange;

  const AnomalyAnalysisResult({
    required this.isAnomaly,
    required this.severity,
    this.reason,
    required this.deltaUsage,
    this.percentChange,
  });

  String get severityDisplayName {
    switch (severity) {
      case AnomalySeverity.danger:
        return 'Báo Động';
      case AnomalySeverity.warning:
        return 'Cảnh Báo';
      case AnomalySeverity.info:
        return 'Lưu Ý';
      case AnomalySeverity.normal:
        return 'Bình Thường';
    }
  }

  factory AnomalyAnalysisResult.normal({required double deltaUsage}) {
    return AnomalyAnalysisResult(
      isAnomaly: false,
      severity: AnomalySeverity.normal,
      reason: null,
      deltaUsage: deltaUsage,
      percentChange: null,
    );
  }
}

class UtilityAnomalyDetector {
  UtilityAnomalyDetector._();

  /// Phân tích tiêu thụ năng lượng và phát hiện dấu hiệu bất thường
  static AnomalyAnalysisResult analyzeReading({
    required double currentReading,
    required double previousReading,
    double? averageUsage,
    required MeterType meterType,
  }) {
    final deltaUsage = currentReading - previousReading;
    final unit = meterType == MeterType.electric ? 'kWh' : 'm³';

    // 1. Chỉ số lùi (currentReading < previousReading) - Lỗi nghiêm trọng / đấu ngược
    if (currentReading < previousReading) {
      return AnomalyAnalysisResult(
        isAnomaly: true,
        severity: AnomalySeverity.danger,
        reason:
            'Chỉ số mới (${currentReading.toStringAsFixed(1)} $unit) nhỏ hơn chỉ số kỳ trước (${previousReading.toStringAsFixed(1)} $unit). Vui lòng kiểm tra lại công tơ.',
        deltaUsage: deltaUsage,
        percentChange: null,
      );
    }

    // 2. Tiêu thụ bằng 0 trong khi lịch sử trước đó có dùng
    if (deltaUsage == 0.0) {
      if (averageUsage != null && averageUsage > 0.0) {
        return AnomalyAnalysisResult(
          isAnomaly: true,
          severity: AnomalySeverity.info,
          reason:
              'Tiêu thụ bằng 0 $unit trong kỳ này (mức trung bình là ${averageUsage.toStringAsFixed(1)} $unit). Cần kiểm tra xem căn hộ có để trống hay công tơ bị kẹt kim.',
          deltaUsage: 0.0,
          percentChange: -100.0,
        );
      }
      return AnomalyAnalysisResult.normal(deltaUsage: 0.0);
    }

    // 3. Phân tích so sánh với mức tiêu thụ trung bình các kỳ trước (nếu có dữ liệu)
    if (averageUsage != null && averageUsage > 0.0) {
      final percentChange = ((deltaUsage - averageUsage) / averageUsage) * 100.0;
      final minDeltaThreshold = meterType == MeterType.electric ? 30.0 : 4.0;

      // 3.1. Tiêu thụ tăng cực đại (gấp >= 2.5 lần và vượt ngưỡng sai số tối thiểu)
      if (deltaUsage >= averageUsage * 2.5 && (deltaUsage - averageUsage) >= minDeltaThreshold) {
        return AnomalyAnalysisResult(
          isAnomaly: true,
          severity: AnomalySeverity.danger,
          reason:
              'Tiêu thụ tăng đột biến ${percentChange.toStringAsFixed(0)}% (từ ${averageUsage.toStringAsFixed(1)} lên ${deltaUsage.toStringAsFixed(1)} $unit). Nguy cơ rò rỉ đường ống hoặc chập điện.',
          deltaUsage: deltaUsage,
          percentChange: percentChange,
        );
      }

      // 3.2. Tiêu thụ tăng cao (tăng >= 50% so với trung bình và vượt ngưỡng tối thiểu)
      if (deltaUsage >= averageUsage * 1.5 && (deltaUsage - averageUsage) >= (minDeltaThreshold / 2)) {
        return AnomalyAnalysisResult(
          isAnomaly: true,
          severity: AnomalySeverity.warning,
          reason:
              'Tiêu thụ tăng cao ${percentChange.toStringAsFixed(0)}% so với mức trung bình (${averageUsage.toStringAsFixed(1)} $unit).',
          deltaUsage: deltaUsage,
          percentChange: percentChange,
        );
      }
    }

    return AnomalyAnalysisResult.normal(deltaUsage: deltaUsage);
  }
}

