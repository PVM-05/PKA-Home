import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResidentMeterReadingScreen Validation Tests', () {
    test('Source code does not contain hardcoded Unsplash images or silent fake fallbacks', () {
      final file = File('lib/features/resident/screens/resident_meter_reading_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // No fake Unsplash links
      expect(content.contains('images.unsplash.com'), isFalse, reason: 'Must not use fake Unsplash image URLs');

      // Uses validateInvoicePeriod
      expect(content.contains('validateInvoicePeriod'), isTrue, reason: 'Must use validateInvoicePeriod for period field');

      // No silent fallback to A0110 and 1250.0 when apartment data is missing
      expect(content.contains("?? 'A0110'"), isFalse, reason: 'Must show error/link prompt when apartment is missing');
      expect(content.contains("?? 1250.0"), isFalse, reason: 'Must not fake old electric reading');
      expect(content.contains("?? 80.0"), isFalse, reason: 'Must not fake old water reading');
    });
  });
}
