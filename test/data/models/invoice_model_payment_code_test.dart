import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/invoice_model.dart';

void main() {
  group('InvoiceModel Payment Code & VietQR Tests', () {
    test('fromJson parses payment_code correctly', () {
      final json = {
        'id': 'inv-uuid-12345678',
        'apartment_id': 'apt-uuid-1',
        'period': '10/2026',
        'due_date': '2026-11-05T00:00:00Z',
        'total_amount': 1500000,
        'status': 'unpaid',
        'created_at': '2026-10-29T00:00:00Z',
        'payment_code': 'INV2610A0110',
      };

      final invoice = InvoiceModel.fromJson(json);

      expect(invoice.paymentCode, equals('INV2610A0110'));
      expect(invoice.effectivePaymentCode, equals('INV2610A0110'));
    });

    test('effectivePaymentCode does not fabricate code when payment_code is null (P0 Fail-Closed)', () {
      final json = {
        'id': 'inv-uuid-abcdef12',
        'apartment_id': 'apt-uuid-1',
        'period': '10/2026',
        'due_date': '2026-11-05T00:00:00Z',
        'total_amount': 1200000,
        'status': 'unpaid',
        'created_at': '2026-10-29T00:00:00Z',
      };

      final invoice = InvoiceModel.fromJson(json);

      expect(invoice.paymentCode, isNull);
      expect(invoice.effectivePaymentCode, isEmpty);
    });

    test('displayReceiptNumber and displayLookupCode work as expected', () {
      final json = {
        'id': 'a1b2c3d4-e5f6-7890',
        'apartment_id': 'apt-uuid-1',
        'period': '10/2026',
        'due_date': '2026-11-05T00:00:00Z',
        'total_amount': 2000000,
        'status': 'paid',
        'created_at': '2026-10-29T00:00:00Z',
        'receipt_number': 'REC-20261029-A1B2C3',
        'einvoice_lookup_code': 'EIN-998877',
        'payment_code': 'INV2610000001',
      };

      final invoice = InvoiceModel.fromJson(json);

      expect(invoice.displayReceiptNumber, equals('REC-20261029-A1B2C3'));
      expect(invoice.displayLookupCode, equals('EIN-998877'));
      expect(invoice.effectivePaymentCode, equals('INV2610000001'));
    });
  });
}
