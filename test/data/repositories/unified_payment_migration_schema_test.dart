import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Unified Payment Simulation Migration Tests', () {
    final migrationFile = File('supabase/migrations/20261005_03_unified_payment_simulation.sql');

    test('Tập tin migration 20261005_03_unified_payment_simulation.sql phải tồn tại', () {
      expect(migrationFile.existsSync(), isTrue, reason: 'Migration file 20261005_03_unified_payment_simulation.sql must exist');
    });

    test('Migration phải định nghĩa mở rộng bảng payment_transactions và RPC simulate_unified_payment', () {
      if (!migrationFile.existsSync()) return;
      final content = migrationFile.readAsStringSync();

      expect(content.contains('ALTER TABLE public.payment_transactions'), isTrue);
      expect(content.contains('type VARCHAR(20)'), isTrue);
      expect(content.contains('booking_id UUID'), isTrue);
      expect(content.contains('simulate_unified_payment'), isTrue);
      expect(content.contains('DEMO-'), isTrue);
    });
  });
}
