import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Commercial VietQR & Webhook Migration Tests (20261029_02)', () {
    const migrationPath = 'supabase/migrations/20261029_02_commercial_vietqr_and_webhook.sql';

    test('Tập tin migration 20261029_02_commercial_vietqr_and_webhook.sql phải tồn tại', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Migration 20261029_02 chưa được tạo.');
    });

    test('Migration phải bổ sung cột payment_code vào invoices và bank_bin vào buildings', () {
      final content = File(migrationPath).readAsStringSync();

      expect(content.contains('payment_code'), isTrue);
      expect(content.contains('bank_bin'), isTrue);
      expect(content.contains('idx_invoices_payment_code'), isTrue);
    });

    test('Migration phải có Trigger tự động sinh payment_code duy nhất khi tạo hóa đơn', () {
      final content = File(migrationPath).readAsStringSync();

      expect(content.contains('fn_generate_invoice_payment_code'), isTrue);
      expect(content.contains('trg_generate_invoice_payment_code'), isTrue);
    });

    test('Migration phải định nghĩa RPC process_bank_payment_webhook xử lý tự động gạch nợ', () {
      final content = File(migrationPath).readAsStringSync();

      expect(content.contains('process_bank_payment_webhook'), isTrue);
      expect(content.contains('FOR UPDATE'), isTrue);
      expect(content.contains('gateway_transaction_id'), isTrue);
      expect(content.contains('idempotency_key'), isTrue);
      expect(content.contains('SUCCESS'), isTrue);
      expect(content.contains('payment_transactions'), isTrue);
    });
  });
}
