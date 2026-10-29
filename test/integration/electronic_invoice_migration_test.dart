import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Electronic Invoice & Lookup Engine Migration Tests (20261029_05)', () {
    const migrationPath =
        'supabase/migrations/20261029_05_electronic_invoice_and_lookup_engine.sql';

    test('Migration file 20261029_05_electronic_invoice_and_lookup_engine.sql must exist', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue,
          reason: 'Migration file 20261029_05_electronic_invoice_and_lookup_engine.sql must exist');
    });

    test('Migration adds lookup_code column to public.invoices with unique constraint and index', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Migration file must exist');
      final content = file.readAsStringSync();

      expect(content, contains('ALTER TABLE public.invoices'));
      expect(content, contains('lookup_code VARCHAR(32) UNIQUE'));
      expect(content, contains('idx_invoices_lookup_code'));
      expect(content, contains('ON public.invoices(lookup_code)'));
    });

    test('Migration defines trigger or function to generate lookup_code on insert', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Migration file must exist');
      final content = file.readAsStringSync();

      final hasFunction = content.contains('ensure_invoice_lookup_code') ||
          content.contains('generate_invoice_lookup_code');
      expect(hasFunction, isTrue,
          reason: 'Should define function ensure_invoice_lookup_code or generate_invoice_lookup_code');

      expect(content, contains('TRIGGER'));
      expect(content, contains('BEFORE INSERT ON public.invoices'));
      expect(content, contains("'INV-'"));
    });

    test('Migration backfills existing invoices with null or empty lookup_code', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Migration file must exist');
      final content = file.readAsStringSync();

      expect(content, contains('UPDATE public.invoices'));
      expect(content, contains('SET lookup_code ='));
      expect(content, contains('WHERE lookup_code IS NULL'));
    });

    test('Migration defines verify_document_lookup RPC with SECURITY DEFINER and expected keys', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Migration file must exist');
      final content = file.readAsStringSync();

      expect(content, contains('verify_document_lookup'));
      expect(content, contains('p_lookup_code TEXT'));
      expect(content, contains('RETURNS JSONB'));
      expect(content, contains('SECURITY DEFINER'));

      // Check required response keys in RPC JSON output
      expect(content, contains("'valid'"));
      expect(content, contains("'lookup_code'"));
      expect(content, contains("'document_type'"));
      expect(content, contains("'period'"));
      expect(content, contains("'apartment_code'"));
      expect(content, contains("'total_amount'"));
      expect(content, contains("'status'"));
      expect(content, contains("'issuer'"));
    });
  });
}
