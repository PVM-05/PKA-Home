import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Batch Invoice Prevalidation Migration Tests', () {
    const migrationPath = 'supabase/migrations/20261006_01_batch_invoice_prevalidation.sql';

    test('Tập tin migration 20261006_01_batch_invoice_prevalidation.sql phải tồn tại', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Tập tin migration phải được tạo');
    });

    test('Migration phải định nghĩa Unique Constraint và các hàm RPC dry-run & generate', () {
      final file = File(migrationPath);
      final content = file.readAsStringSync();

      // 1. Ràng buộc Unique chống duplicate
      expect(content.contains('uq_invoices_apartment_period') || content.contains('UNIQUE (apartment_id, period)'), isTrue);

      // 2. RPC Dry-Run: validate_monthly_bulk_invoices
      expect(content.contains('validate_monthly_bulk_invoices'), isTrue);
      expect(content.contains('p_period'), isTrue);
      expect(content.contains('valid_count'), isTrue);
      expect(content.contains('missing_count'), isTrue);
      expect(content.contains('invalid_count'), isTrue);
      expect(content.contains('already_invoiced_count'), isTrue);

      // 3. RPC Create: generate_valid_bulk_invoices
      expect(content.contains('generate_valid_bulk_invoices'), isTrue);
      expect(content.contains('p_period'), isTrue);
      expect(content.contains('p_due_date'), isTrue);
      expect(content.contains('ON CONFLICT (apartment_id, period) DO NOTHING'), isTrue);
      expect(content.contains('invoices_created'), isTrue);
    });
  });
}
