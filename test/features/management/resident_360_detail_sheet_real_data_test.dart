import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Resident360DetailSheet Real Data Tests', () {
    test('Source code does not contain hardcoded mock strings Honda Vision, 1.480.000, Goi Gym', () {
      final file = File('lib/features/management/widgets/resident_360_detail_sheet.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('Honda Vision'), isFalse, reason: 'Must not hardcode Honda Vision');
      expect(content.contains('1.480.000'), isFalse, reason: 'Must not hardcode 1.480.000');
      expect(content.contains('Gói Gym'), isFalse, reason: 'Must not hardcode Gói Gym');
    });
  });
}
