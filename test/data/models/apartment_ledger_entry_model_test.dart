import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_ledger_entry_model.dart';

void main() {
  group('ApartmentLedgerEntryModel Tests', () {
    final sampleJson = {
      'id': 'ale-123',
      'building_id': 'bld-456',
      'apartment_id': 'apt-789',
      'entry_code': 'LE-202610-00001',
      'entry_type': 'DEBIT',
      'amount': 1500000.0,
      'balance_after': 1500000.0,
      'period': '2026-10',
      'reference_type': 'INVOICE',
      'reference_id': 'inv-001',
      'description': 'Phát hành hóa đơn tháng 10/2026',
      'created_by': 'usr-admin',
      'created_at': '2026-10-29T17:05:00.000Z',
    };

    test('fromJson and toJson parse data correctly', () {
      final entry = ApartmentLedgerEntryModel.fromJson(sampleJson);

      expect(entry.id, 'ale-123');
      expect(entry.buildingId, 'bld-456');
      expect(entry.apartmentId, 'apt-789');
      expect(entry.entryCode, 'LE-202610-00001');
      expect(entry.entryType, 'DEBIT');
      expect(entry.amount, 1500000.0);
      expect(entry.balanceAfter, 1500000.0);
      expect(entry.period, '2026-10');
      expect(entry.referenceType, 'INVOICE');
      expect(entry.referenceId, 'inv-001');
      expect(entry.description, 'Phát hành hóa đơn tháng 10/2026');
      expect(entry.createdBy, 'usr-admin');
      expect(entry.createdAt, DateTime.parse('2026-10-29T17:05:00.000Z'));

      final json = entry.toJson();
      expect(json['entry_code'], 'LE-202610-00001');
      expect(json['entry_type'], 'DEBIT');
      expect(json['amount'], 1500000.0);
      expect(json['balance_after'], 1500000.0);
    });

    test('Vietnamese formatted helpers return standard strings', () {
      final entry = ApartmentLedgerEntryModel.fromJson(sampleJson);

      expect(entry.formattedPeriod, 'Tháng 10/2026');
      expect(entry.formattedAmount, contains('1.500.000'));
      expect(entry.formattedBalanceAfter, contains('1.500.000'));
      expect(entry.formattedCreatedAt, '29/10/2026');
      expect(entry.entryTypeVietnamese, 'Phát sinh nợ (Hóa đơn)');
      expect(entry.isDebit, isTrue);
    });

    test('handles CREDIT and CREDIT_NOTE types properly', () {
      final creditJson = {
        'id': 'ale-124',
        'building_id': 'bld-456',
        'apartment_id': 'apt-789',
        'entry_code': 'LE-202610-00002',
        'entry_type': 'CREDIT_NOTE',
        'amount': 200000,
        'balance_after': 1300000,
        'period': '2026-10',
        'reference_type': 'CREDIT_NOTE',
        'description': 'Giảm trừ tiền nước',
      };

      final entry = ApartmentLedgerEntryModel.fromJson(creditJson);
      expect(entry.isDebit, isFalse);
      expect(entry.entryTypeVietnamese, 'Phiếu giảm nợ');
      expect(entry.amount, 200000.0);
      expect(entry.balanceAfter, 1300000.0);
    });
  });
}
