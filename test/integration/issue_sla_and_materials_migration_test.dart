import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Task 1: Kiem tra Migration SQL Canh Bao SLA & Kho Vat Tu Su Co D3', () {
    const migrationPath = 'supabase/migrations/20261102_02_issue_sla_and_materials.sql';

    test('1. Tập tin migration 20261102_02 phải tồn tại', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Migration file 20261102_02_issue_sla_and_materials.sql phải tồn tại');
    });

    test('2. Migration phải mở rộng bảng issue_reports với các cột SLA và category', () {
      final content = File(migrationPath).readAsStringSync();

      expect(content, contains('category'), reason: 'Phải có cột category');
      expect(content, contains('sla_deadline'), reason: 'Phải có cột sla_deadline');
      expect(content, contains('acknowledged_at'), reason: 'Phải có cột acknowledged_at');
      expect(content, contains('resolved_at'), reason: 'Phải có cột resolved_at');
      expect(content, contains('sla_status'), reason: 'Phải có cột sla_status');
    });

    test('3. Migration phải định nghĩa trigger tự động tính toán sla_deadline', () {
      final content = File(migrationPath).readAsStringSync();

      expect(content, contains('trg_calculate_issue_sla'), reason: 'Phải có trigger tính SLA');
      expect(content, contains('2 hours'), reason: 'Mức high phải có deadline 2 giờ');
      expect(content, contains('24 hours'), reason: 'Mức medium phải có deadline 24 giờ');
      expect(content, contains('72 hours'), reason: 'Mức low phải có deadline 72 giờ');
    });

    test('4. Migration phải định nghĩa bảng maintenance_materials và issue_materials kèm RLS', () {
      final content = File(migrationPath).readAsStringSync();

      expect(content, contains('CREATE TABLE IF NOT EXISTS maintenance_materials'), reason: 'Bảng kho vật tư');
      expect(content, contains('CREATE TABLE IF NOT EXISTS issue_materials'), reason: 'Bảng vật tư sự cố');
      expect(content, contains('ENABLE ROW LEVEL SECURITY'), reason: 'Phải bật RLS cho các bảng');
      expect(content, contains('is_chargeable'), reason: 'Phải có cờ tính phí căn hộ');
    });

    test('5. Migration phải định nghĩa đầy đủ 3 RPCs SLA và xuất kho vật tư', () {
      final content = File(migrationPath).readAsStringSync();

      expect(content, contains('get_issue_sla_stats'), reason: 'RPC thống kê SLA');
      expect(content, contains('record_issue_materials_usage'), reason: 'RPC xuất kho vật tư nghiệm thu');
      expect(content, contains('charge_issue_materials_to_invoice'), reason: 'RPC kết chuyển vật tư vào hóa đơn');
    });
  });
}
