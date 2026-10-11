import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P2 Database Verification: Concurrency Locks & Storage Policy Tests', () {
    late String migrationContent;

    setUpAll(() {
      final migrationFile = File('supabase/migrations/20261011_06_fix_security_meters_vehicles_and_storage.sql');
      expect(migrationFile.existsSync(), isTrue, reason: 'File migration 20261011_06 phải tồn tại');
      migrationContent = migrationFile.readAsStringSync();
    });

    test('Trigger check_vehicle_limits sử dụng FOR UPDATE để khóa căn hộ chống race condition', () {
      expect(migrationContent, contains('CREATE OR REPLACE FUNCTION public.check_vehicle_limits()'));
      expect(
        migrationContent,
        contains('PERFORM 1 FROM public.apartments WHERE id = NEW.apartment_id FOR UPDATE;'),
        reason: 'Phải khóa căn hộ FOR UPDATE để tuần tự hóa các yêu cầu đăng ký xe đồng thời',
      );
      expect(migrationContent, contains("current_motorbike_count >= 2"));
    });

    test('Storage Policy cho issue-images siết chặt quyền SELECT chỉ cho authenticated và người liên quan', () {
      expect(migrationContent, contains('bucket_id = \'issue-images\''));
      expect(migrationContent, contains("auth.role() = 'authenticated'"));
      expect(migrationContent, contains('public.is_staff()'));
      expect(migrationContent, contains('reporter_id = auth.uid()'));
      expect(migrationContent, contains('residents_apartments'));
    });
  });
}
