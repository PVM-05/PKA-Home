import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Design System Theme & Color CI Guardrail Tests', () {
    /// Danh sách các file màn hình đã được chuẩn hóa theo Design Tokens (Whitelist)
    /// Khi một module hoàn thành refactor, thêm file của module đó vào danh sách này.
    final targetModulesWhitelist = <String>[
      // Module 1: Tài chính & Hóa đơn (Đã hoàn thiện chuẩn Design System)
      'lib/features/resident/screens/resident_invoice_screen.dart',
      'lib/features/resident/screens/resident_invoice_detail_screen.dart',
      'lib/features/management/screens/invoice_management_screen.dart',
      'lib/features/management/screens/management_invoice_detail_screen.dart',
      // Sẽ được kích hoạt trong Task 4:
      // 'lib/features/resident/screens/resident_issue_screen.dart',
      // 'lib/features/resident/screens/issue_detail_screen.dart',
      // 'lib/features/management/screens/issue_management_screen.dart',
    ];

    test('Guardrail: Các màn hình trong whitelist không được chứa mã màu cứng Color(0x...)', () {
      final hardcodedColorRegex = RegExp(r'Color\(0x[0-9a-fA-F]+\)');
      final violations = <String>[];

      for (final filePath in targetModulesWhitelist) {
        final file = File(filePath);
        if (!file.existsSync()) continue;

        final lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('//') || line.startsWith('/*')) continue;

          if (hardcodedColorRegex.hasMatch(line)) {
            violations.add('$filePath:${i + 1}: $line');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Phát hiện mã màu cứng trong các module đã chuẩn hóa Design System:\n${violations.join('\n')}',
      );
    });

    test('Guardrail: Các màn hình trong whitelist không được chứa fontSize cứng', () {
      final hardcodedFontSizeRegex = RegExp(r'fontSize:\s*[0-9]+(\.[0-9]+)?');
      final violations = <String>[];

      for (final filePath in targetModulesWhitelist) {
        final file = File(filePath);
        if (!file.existsSync()) continue;

        final lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('//') || line.startsWith('/*')) continue;

          if (hardcodedFontSizeRegex.hasMatch(line)) {
            violations.add('$filePath:${i + 1}: $line');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Phát hiện fontSize cứng trong các module đã chuẩn hóa Design System:\n${violations.join('\n')}',
      );
    });

    test('Guardrail test logic: Bắt chính xác lỗi nếu file có mã màu hoặc fontSize cứng', () {
      const sampleBadCode = '''
        Text("Sample", style: TextStyle(fontSize: 14, color: Color(0xFF123456)));
      ''';

      expect(RegExp(r'Color\(0x[0-9a-fA-F]+\)').hasMatch(sampleBadCode), isTrue);
      expect(RegExp(r'fontSize:\s*[0-9]+').hasMatch(sampleBadCode), isTrue);
    });
  });
}
