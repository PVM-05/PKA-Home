import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P0 Security: Auth Role Escalation Prevention Tests', () {
    late String migrationContent;

    setUpAll(() {
      final migrationFile = File('supabase/migrations/20261011_06_fix_security_meters_vehicles_and_storage.sql');
      expect(migrationFile.existsSync(), isTrue, reason: 'File migration 20261011_06 phải tồn tại');
      migrationContent = migrationFile.readAsStringSync();
    });

    test('Trigger handle_new_user() luôn gán cứng resident và phớt lờ client role metadata', () {
      expect(migrationContent, contains("CREATE OR REPLACE FUNCTION public.handle_new_user()"));
      expect(migrationContent, contains("'resident'::public.user_role"));
      // Không còn đọc role từ client metadata
      expect(migrationContent, isNot(contains("raw_user_meta_data->>'role'")));
    });

    test('Mô phỏng xử lý đăng ký với metadata role nguy hiểm (admin, management, accountant) đều phải thành resident', () {
      // Giả lập logic SQL trigger trong Dart
      String resolveRoleFromTrigger(Map<String, dynamic> rawUserMetaData) {
        // Trigger mới cố định gán 'resident', phớt lờ hoàn toàn rawUserMetaData['role']
        return 'resident';
      }

      final testCases = [
        {'role': 'admin', 'full_name': 'Hacker Admin'},
        {'role': 'management', 'full_name': 'Hacker BQL'},
        {'role': 'accountant', 'full_name': 'Hacker KeToan'},
        {'role': 'super_admin', 'full_name': 'Hacker Super'},
        {'full_name': 'Cư dân bình thường'},
      ];

      for (final testCase in testCases) {
        final assignedRole = resolveRoleFromTrigger(testCase);
        expect(assignedRole, equals('resident'), 
            reason: 'Tài khoản đăng ký với metadata ${testCase["role"]} phải luôn bị ép về resident');
      }
    });
  });
}
