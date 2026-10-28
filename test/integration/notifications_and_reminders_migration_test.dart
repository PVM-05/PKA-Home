import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Notifications and Reminders Migration Tests', () {
    final migrationFile = File('supabase/migrations/20261028_01_notifications_and_reminders.sql');

    test('Tập tin migration 20261028_01_notifications_and_reminders.sql phải tồn tại', () {
      expect(migrationFile.existsSync(), isTrue);
    });

    test('Migration phải định nghĩa bảng user_fcm_tokens và notifications', () {
      final content = migrationFile.readAsStringSync();
      expect(content.contains('CREATE TABLE IF NOT EXISTS public.user_fcm_tokens'), isTrue);
      expect(content.contains('CREATE TABLE IF NOT EXISTS public.notifications'), isTrue);
      expect(content.contains('uq_user_fcm_token UNIQUE(user_id, token)'), isTrue);
    });

    test('Migration phải nâng cấp bảng announcements với target_type và target_value', () {
      final content = migrationFile.readAsStringSync();
      expect(content.contains('ALTER TABLE public.announcements'), isTrue);
      expect(content.contains('target_type'), isTrue);
      expect(content.contains('target_value'), isTrue);
    });

    test('Migration phải định nghĩa RPC check_and_generate_invoice_due_reminders với logic 3 mức nhắc', () {
      final content = migrationFile.readAsStringSync();
      expect(content.contains('FUNCTION public.check_and_generate_invoice_due_reminders'), isTrue);
      expect(content.contains('invoice_due_soon'), isTrue);
      expect(content.contains('invoice_due_today'), isTrue);
      expect(content.contains('invoice_overdue'), isTrue);
    });
  });
}
