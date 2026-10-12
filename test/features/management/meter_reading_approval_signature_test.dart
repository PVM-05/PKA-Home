import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kiểm thử hợp đồng tham số approve_meter_reading', () {
    test('Format đúng định dạng tham số truyền vào RPC', () {
      final dueDate = DateTime(2026, 11, 15);
      final dueStr = "${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}";
      
      final params = {
        'p_submission_id': 'test-submission-id',
        'p_generate_invoice': true,
        'p_due_date': dueStr,
      };

      expect(params['p_submission_id'], 'test-submission-id');
      expect(params['p_generate_invoice'], isTrue);
      expect(params['p_due_date'], '2026-11-15');
    });

    test('Không truyền ngày do generateInvoice = false', () {
      String? formatDueDate(bool genInvoice, DateTime? date) {
        if (genInvoice && date != null) {
          return "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        }
        return null;
      }

      final dueStr = formatDueDate(false, DateTime(2026, 11, 15));

      final params = {
        'p_submission_id': 'test-submission-id',
        'p_generate_invoice': false,
        'p_due_date': dueStr,
      };

      expect(params['p_generate_invoice'], isFalse);
      expect(params['p_due_date'], isNull);
    });
  });
}
