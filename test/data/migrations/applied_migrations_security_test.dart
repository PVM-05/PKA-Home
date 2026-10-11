import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kiểm tra Migration bảo mật bảng public._applied_migrations', () {
    final migrationFile = File(
      'supabase/migrations/20261011_02_secure_applied_migrations.sql',
    );

    test('File migration 20261011_02_secure_applied_migrations.sql phải tồn tại', () {
      expect(
        migrationFile.existsSync(),
        isTrue,
        reason: 'Cần có migration khắc phục cảnh báo RLS trên bảng public._applied_migrations',
      );
    });

    test('Migration phải kích hoạt RLS và thu hồi quyền từ role anon, authenticated', () {
      if (!migrationFile.existsSync()) return;
      final content = migrationFile.readAsStringSync();

      expect(
        content.contains('ENABLE ROW LEVEL SECURITY'),
        isTrue,
        reason: 'Bắt buộc phải bật ROW LEVEL SECURITY cho _applied_migrations',
      );
      expect(
        content.contains('REVOKE ALL ON TABLE public._applied_migrations FROM anon, authenticated'),
        isTrue,
        reason: 'Bắt buộc thu hồi toàn bộ quyền từ anon và authenticated',
      );
      expect(
        content.contains('GRANT ALL ON TABLE public._applied_migrations TO postgres, service_role'),
        isTrue,
        reason: 'Cấp quyền truy cập cho postgres và service_role',
      );
    });
  });
}
