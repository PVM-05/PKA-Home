import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/credit_note_model.dart';

void main() {
  group('CreditNoteModel Tests', () {
    final sampleJson = {
      'id': 'cn-111',
      'credit_note_code': 'CN-202610-00001',
      'building_id': 'bld-456',
      'apartment_id': 'apt-789',
      'invoice_id': 'inv-001',
      'note_type': 'CREDIT',
      'amount': 250000.0,
      'reason': 'Điều chỉnh sai lệch chỉ số nước tháng 10',
      'status': 'APPROVED',
      'approved_by': 'usr-accountant',
      'approved_at': '2026-10-29T17:10:00.000Z',
      'created_at': '2026-10-29T17:09:00.000Z',
    };

    test('fromJson and toJson parse data correctly', () {
      final note = CreditNoteModel.fromJson(sampleJson);

      expect(note.id, 'cn-111');
      expect(note.creditNoteCode, 'CN-202610-00001');
      expect(note.buildingId, 'bld-456');
      expect(note.apartmentId, 'apt-789');
      expect(note.invoiceId, 'inv-001');
      expect(note.noteType, 'CREDIT');
      expect(note.amount, 250000.0);
      expect(note.reason, 'Điều chỉnh sai lệch chỉ số nước tháng 10');
      expect(note.status, 'APPROVED');
      expect(note.approvedBy, 'usr-accountant');
      expect(note.approvedAt, DateTime.parse('2026-10-29T17:10:00.000Z'));

      final json = note.toJson();
      expect(json['credit_note_code'], 'CN-202610-00001');
      expect(json['amount'], 250000.0);
    });

    test('Vietnamese formatted helpers return standard strings', () {
      final note = CreditNoteModel.fromJson(sampleJson);

      expect(note.formattedAmount, contains('250.000'));
      expect(note.formattedCreatedAt, '29/10/2026');
      expect(note.noteTypeVietnamese, 'Giảm trừ nợ');
      expect(note.isApproved, isTrue);
    });
  });
}
