import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Migration 20261025_03 phải chứa các định nghĩa vá bảo mật và RPC tiện ích', () {
    final file = File('supabase/migrations/20261025_03_audit_remediation_and_amenity_system.sql');
    expect(file.existsSync(), isTrue, reason: 'File migration 20261025_03 phải tồn tại');

    final content = file.readAsStringSync();
    expect(content.contains("'resident'::public.user_role"), isTrue,
        reason: 'handle_new_user phải ép cứng role resident chống leo thang đặc quyền');
    expect(content.contains('cancel_amenity_booking'), isTrue,
        reason: 'Phải có RPC cancel_amenity_booking');
    expect(content.contains('simulate_unified_payment'), isTrue,
        reason: 'Phải chuẩn hóa simulate_unified_payment');
    expect(content.contains('get_amenity_slot_availability'), isTrue,
        reason: 'Phải có RPC get_amenity_slot_availability ẩn danh');
    expect(content.contains('booking_id = p_booking_id'), isTrue,
        reason: 'reschedule_amenity_booking phải dùng booking_id = p_booking_id');
    expect(content.contains('estimated_total'), isTrue,
        reason: 'validate_monthly_bulk_invoices phải trả estimated_total');
    expect(content.contains('invoices_created'), isTrue,
        reason: 'generate_valid_bulk_invoices phải trả invoices_created');
    expect(content.contains('issue-images'), isTrue,
        reason: 'Phải cấu hình lại bucket issue-images sang private');
  });
}
