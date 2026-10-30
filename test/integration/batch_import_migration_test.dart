import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Batch Import Migration Tests (20261030_02)', () {
    const migrationFilePath = 'supabase/migrations/20261030_02_residents_apartments_lifecycle_and_batch_import.sql';

    test('Migration file 20261030_02 must exist', () {
      final file = File(migrationFilePath);
      expect(file.existsSync(), isTrue, reason: 'Tệp migration B2 $migrationFilePath phải tồn tại');
    });

    test('Migration adds start_date, end_date, and status to residents_apartments', () {
      final file = File(migrationFilePath);
      if (!file.existsSync()) {
        fail('Migration file not found');
      }
      final sql = file.readAsStringSync();

      expect(sql.contains('ALTER TABLE public.residents_apartments'), isTrue,
          reason: 'Bảng residents_apartments phải được nâng cấp');
      expect(sql.contains('start_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP'), isTrue,
          reason: 'Phải có cột start_date');
      expect(sql.contains('end_date TIMESTAMPTZ DEFAULT NULL'), isTrue,
          reason: 'Phải có cột end_date');
      expect(sql.contains('status TEXT DEFAULT \'active\''), isTrue,
          reason: 'Phải có cột status active/ended');
      expect(sql.contains('CHECK (status IN (\'active\', \'ended\'))'), isTrue,
          reason: 'Phải có ràng buộc CHECK trạng thái active/ended');
    });

    test('Migration defines batch import RPCs with RBAC security', () {
      final file = File(migrationFilePath);
      if (!file.existsSync()) {
        fail('Migration file not found');
      }
      final sql = file.readAsStringSync();

      expect(sql.contains('CREATE OR REPLACE FUNCTION public.batch_import_apartments'), isTrue,
          reason: 'Phải khai báo RPC batch_import_apartments');
      expect(sql.contains('CREATE OR REPLACE FUNCTION public.batch_import_residents'), isTrue,
          reason: 'Phải khai báo RPC batch_import_residents');
      expect(sql.contains('CREATE OR REPLACE FUNCTION public.batch_import_meter_readings'), isTrue,
          reason: 'Phải khai báo RPC batch_import_meter_readings');

      // Kiểm tra bảo mật
      expect(sql.contains('SECURITY DEFINER'), isTrue, reason: 'Các RPC phải có SECURITY DEFINER');
      expect(sql.contains('role IN (\'admin\', \'management\')'), isTrue,
          reason: 'Các RPC phải kiểm tra quyền BQL hoặc Admin');
    });
  });
}

