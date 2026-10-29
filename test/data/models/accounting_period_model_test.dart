import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/accounting_period_model.dart';

void main() {
  group('AccountingPeriodModel Tests', () {
    final sampleJson = {
      'id': 'ap-101',
      'building_id': 'bld-456',
      'period': '2026-10',
      'status': 'OPEN',
      'opened_at': '2026-10-01T00:00:00.000Z',
      'notes': 'Kỳ kế toán tháng 10 năm 2026',
    };

    test('fromJson and toJson parse open period correctly', () {
      final period = AccountingPeriodModel.fromJson(sampleJson);

      expect(period.id, 'ap-101');
      expect(period.buildingId, 'bld-456');
      expect(period.period, '2026-10');
      expect(period.status, 'OPEN');
      expect(period.isClosed, isFalse);
      expect(period.formattedPeriod, 'Tháng 10/2026');
      expect(period.statusVietnamese, 'Đang mở');

      final json = period.toJson();
      expect(json['period'], '2026-10');
      expect(json['status'], 'OPEN');
    });

    test('fromJson parses closed period correctly', () {
      final closedJson = {
        'id': 'ap-102',
        'building_id': 'bld-456',
        'period': '2026-09',
        'status': 'CLOSED',
        'opened_at': '2026-09-01T00:00:00.000Z',
        'closed_at': '2026-10-05T10:00:00.000Z',
        'closed_by': 'usr-accountant',
        'notes': 'Đã khóa sổ tháng 9/2026',
      };

      final period = AccountingPeriodModel.fromJson(closedJson);
      expect(period.isClosed, isTrue);
      expect(period.statusVietnamese, 'Đã khóa sổ');
      expect(period.closedAt, DateTime.parse('2026-10-05T10:00:00.000Z'));
      expect(period.closedBy, 'usr-accountant');
    });
  });
}
