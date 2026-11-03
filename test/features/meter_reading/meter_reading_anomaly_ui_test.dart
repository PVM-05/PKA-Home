import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/theme/app_theme.dart';
import 'package:pka_home/core/utils/meter_ocr_simulator.dart';
import 'package:pka_home/core/utils/utility_anomaly_detector.dart';

void main() {
  group('Meter Reading Anomaly UI Component Tests', () {
    testWidgets('Hiển thị banner cảnh báo bất thường màu đỏ khi có lỗi danger (chỉ số lùi)', (tester) async {
      final analysis = UtilityAnomalyDetector.analyzeReading(
        currentReading: 100.0,
        previousReading: 120.0,
        averageUsage: 30.0,
        meterType: MeterType.electric,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                if (!analysis.isAnomaly) return const SizedBox.shrink();
                return Container(
                  key: const Key('anomaly_banner'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: analysis.severity == AnomalySeverity.danger
                        ? AppTheme.error.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    border: Border.all(
                      color: analysis.severity == AnomalySeverity.danger
                          ? AppTheme.error
                          : Colors.orange,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        analysis.severity == AnomalySeverity.danger
                            ? Icons.error_outline
                            : Icons.warning_amber_rounded,
                        color: analysis.severity == AnomalySeverity.danger
                            ? AppTheme.error
                            : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          analysis.reason ?? '',
                          style: TextStyle(
                            color: analysis.severity == AnomalySeverity.danger
                                ? AppTheme.error
                                : Colors.orange.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('anomaly_banner')), findsOneWidget);
      expect(find.textContaining('nhỏ hơn chỉ số kỳ trước'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('Hiển thị banner cảnh báo bất thường màu cam khi tăng vọt tiêu thụ', (tester) async {
      final analysis = UtilityAnomalyDetector.analyzeReading(
        currentReading: 1200.0,
        previousReading: 1000.0,
        averageUsage: 100.0,
        meterType: MeterType.electric,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                if (!analysis.isAnomaly) return const SizedBox.shrink();
                return Container(
                  key: const Key('anomaly_warning_banner'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(analysis.reason ?? ''),
                );
              },
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('anomaly_warning_banner')), findsOneWidget);
      expect(find.textContaining('tăng cao'), findsOneWidget);
    });
  });
}

