import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Database Migration: 20261103_04_issue_smart_triage_and_auto_assign.sql', () {
    late String migrationSql;

    setUpAll(() {
      final file = File('supabase/migrations/20261103_04_issue_smart_triage_and_auto_assign.sql');
      expect(file.existsSync(), isTrue, reason: 'Migration file 20261103_04 phải tồn tại.');
      migrationSql = file.readAsStringSync();
    });

    test('Chứa lệnh thêm các cột AI Triage vào issue_reports', () {
      expect(migrationSql, contains('ALTER TABLE public.issue_reports'));
      expect(migrationSql, contains('ai_category_confidence'));
      expect(migrationSql, contains('ai_suggested_category'));
      expect(migrationSql, contains('ai_suggested_priority'));
      expect(migrationSql, contains('ai_triage_reason'));
      expect(migrationSql, contains('is_hazardous'));
      expect(migrationSql, contains('auto_assigned'));
    });

    test('Chứa chỉ mục hỗ trợ lọc sự cố theo mức độ nguy hiểm và phân loại', () {
      expect(migrationSql, contains('idx_issue_reports_triage'));
      expect(migrationSql, contains('idx_issue_reports_auto_assigned'));
    });

    test('Chứa RPC triage_and_auto_assign_issue với cơ chế phân bổ tải công việc', () {
      expect(migrationSql, contains('CREATE OR REPLACE FUNCTION public.triage_and_auto_assign_issue'));
      expect(migrationSql, contains('p_issue_id UUID'));
      expect(migrationSql, contains('SECURITY DEFINER'));
      expect(migrationSql, contains('p_auto_assign'));
    });
  });
}
