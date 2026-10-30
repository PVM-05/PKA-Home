import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Financial Aging Report Migration Tests (20261030_01)', () {
    const migrationFilePath = 'supabase/migrations/20261030_01_financial_aging_report_rpc.sql';

    test('Migration file 20261030_01_financial_aging_report_rpc.sql must exist', () {
      final file = File(migrationFilePath);
      expect(file.existsSync(), isTrue, reason: 'Tệp migration C6 $migrationFilePath phải tồn tại');
    });

    test('Migration defines get_financial_aging_report RPC with security definer and RBAC', () {
      final file = File(migrationFilePath);
      if (!file.existsSync()) {
        fail('Migration file not found');
      }
      final sql = file.readAsStringSync();

      expect(sql.contains('CREATE OR REPLACE FUNCTION public.get_financial_aging_report'), isTrue,
          reason: 'RPC get_financial_aging_report phải được khai báo');
      expect(sql.contains('p_building_id UUID DEFAULT NULL'), isTrue,
          reason: 'RPC phải hỗ trợ tham số p_building_id');
      expect(sql.contains('p_period TEXT DEFAULT NULL'), isTrue,
          reason: 'RPC phải hỗ trợ tham số p_period');
      expect(sql.contains('SECURITY DEFINER'), isTrue,
          reason: 'RPC phải có SECURITY DEFINER để bảo mật và thực thi quyền hạn');
      expect(sql.contains('role IN (\'admin\', \'management\', \'accountant\')'), isTrue,
          reason: 'RPC phải kiểm tra vai trò admin, management, hoặc accountant');
      expect(sql.contains('role_delegations'), isTrue,
          reason: 'RPC phải kiểm tra bảng ủy quyền vai trò');
    });

    test('Migration computes 4 aging buckets and debtor list', () {
      final file = File(migrationFilePath);
      if (!file.existsSync()) {
        fail('Migration file not found');
      }
      final sql = file.readAsStringSync();

      // Kiểm tra 4 xô nợ
      expect(sql.contains('amount_0_30') && sql.contains('count_0_30'), isTrue,
          reason: 'Phải tính toán xô nợ 0-30 ngày');
      expect(sql.contains('amount_31_60') && sql.contains('count_31_60'), isTrue,
          reason: 'Phải tính toán xô nợ 31-60 ngày');
      expect(sql.contains('amount_61_90') && sql.contains('count_61_90'), isTrue,
          reason: 'Phải tính toán xô nợ 61-90 ngày');
      expect(sql.contains('amount_over_90') && sql.contains('count_over_90'), isTrue,
          reason: 'Phải tính toán xô nợ trên 90 ngày');

      // Kiểm tra danh sách con nợ & tỷ lệ thu hồi theo block
      expect(sql.contains('debtors'), isTrue, reason: 'Phải có CTE tổng hợp con nợ');
      expect(sql.contains('collection_by_block'), isTrue, reason: 'Phải có thống kê tỷ lệ thu hồi theo block');
      expect(sql.contains('jsonb_build_object'), isTrue, reason: 'Phải kết xuất kết quả dạng JSONB');
    });
  });
}
