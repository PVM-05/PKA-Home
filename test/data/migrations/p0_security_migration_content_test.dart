import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Migration 20261007_02 chứa đầy đủ các bản vá bảo mật RPC và RLS', () {
    final file = File('supabase/migrations/20261007_02_fix_critical_security_and_policies.sql');
    expect(file.existsSync(), isTrue, reason: 'File migration 20261007_02 phải tồn tại');

    final content = file.readAsStringSync();
    expect(content.contains('is_admin_or_accountant()'), isTrue, reason: 'Phải dùng guard is_admin_or_accountant');
    expect(content.contains('create_invoice_with_items'), isTrue, reason: 'Phải siết hàm create_invoice_with_items');
    expect(content.contains('update_invoice_with_items'), isTrue, reason: 'Phải siết hàm update_invoice_with_items');
    expect(content.contains('record_manual_payment'), isTrue, reason: 'Phải có RPC record_manual_payment');
    expect(content.contains("rejection_reason IS NULL"), isTrue, reason: 'Vehicle insert phải ép rejection_reason IS NULL');
    expect(content.contains("submitted_by = auth.uid()"), isTrue, reason: 'Meter reading phải ép submitted_by = auth.uid()');
    expect(content.contains("Cư dân đặt lịch tiện ích"), isTrue, reason: 'Phải drop policy insert direct tiện ích');
    expect(content.contains("simulate_invoice_payment"), isTrue, reason: 'Phải drop hàm cũ simulate_invoice_payment');
    expect(content.contains("Cư dân xóa yêu cầu bị từ chối"), isTrue, reason: 'Phải có policy DELETE link requests rejected');
  });
}
