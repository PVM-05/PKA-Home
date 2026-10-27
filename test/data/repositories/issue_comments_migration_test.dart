import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Issue Comments Migration & Realtime Configuration Tests', () {
    test('Tập tin migration 20260926_01_issue_comments.sql phải tồn tại', () {
      final file = File('supabase/migrations_archive/20260926_01_issue_comments.sql');
      expect(file.existsSync(), isTrue, reason: 'Migration 20260926_01_issue_comments.sql chưa tồn tại');
    });

    test('Migration phải có đầy đủ cấu trúc bảng, RLS policies, REPLICA IDENTITY FULL và Realtime publication', () {
      final file = File('supabase/migrations_archive/20260926_01_issue_comments.sql');
      final content = file.readAsStringSync();

      // 1. Tạo bảng issue_comments
      expect(content.contains('CREATE TABLE IF NOT EXISTS public.issue_comments'), isTrue);
      expect(content.contains('issue_report_id uuid NOT NULL REFERENCES public.issue_reports'), isTrue);
      expect(content.contains('user_id uuid NOT NULL REFERENCES public.users'), isTrue);
      expect(content.contains('created_at timestamptz DEFAULT now() NOT NULL'), isTrue);

      // 2. Index
      expect(content.contains('idx_issue_comments_report'), isTrue);

      // 3. RLS
      expect(content.contains('ALTER TABLE public.issue_comments ENABLE ROW LEVEL SECURITY'), isTrue);

      // 4. REPLICA IDENTITY FULL cho Realtime
      expect(content.contains('ALTER TABLE public.issue_comments REPLICA IDENTITY FULL'), isTrue);

      // 5. Policies
      expect(content.contains('residents_view_own_comments'), isTrue);
      expect(content.contains('users_insert_own_comments'), isTrue);

      // 6. Supabase Realtime publication
      expect(content.contains('ALTER PUBLICATION supabase_realtime ADD TABLE public.issue_comments'), isTrue);
    });
  });
}

