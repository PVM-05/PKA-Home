import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/contracts/finance_rpc_contracts.dart';

void main() {
  group('Final UAT Security Hardening Migration (20261127010000)', () {
    final migrationFile = File(
      'supabase/migrations/20261127010000_final_uat_security_rls_rpc_hardening.sql',
    );
    late String sql;

    setUpAll(() {
      expect(
        migrationFile.existsSync(),
        isTrue,
        reason: 'Tệp migration 20261127010000 phải tồn tại trong supabase/migrations/',
      );
      sql = migrationFile.readAsStringSync();
    });

    test('Gỡ bỏ đủ 9 legacy permissive RLS policies USING(true)', () {
      const droppedPolicies = [
        'DROP POLICY IF EXISTS "Allow anon and authenticated to view apartments" ON public.apartments',
        'DROP POLICY IF EXISTS "Users can view meter submissions" ON public.meter_reading_submissions',
        'DROP POLICY IF EXISTS "Users can insert meter submissions" ON public.meter_reading_submissions',
        'DROP POLICY IF EXISTS "Staff can update meter submissions" ON public.meter_reading_submissions',
        'DROP POLICY IF EXISTS "building_equipments_select_policy" ON public.building_equipments',
        'DROP POLICY IF EXISTS "building_equipments_modify_policy" ON public.building_equipments',
        'DROP POLICY IF EXISTS "equipment_tasks_select_policy" ON public.equipment_maintenance_tasks',
        'DROP POLICY IF EXISTS "equipment_tasks_modify_policy" ON public.equipment_maintenance_tasks',
        'DROP POLICY IF EXISTS "issue_ratings_select_policy" ON public.issue_ratings',
        'DROP POLICY IF EXISTS "issue_ratings_insert_policy" ON public.issue_ratings',
      ];
      for (final stmt in droppedPolicies) {
        expect(sql, contains(stmt));
      }
      expect(sql, contains('CREATE POLICY "equipment_tasks_read"'));
      expect(sql, contains('CREATE POLICY "equipment_tasks_manage"'));
      expect(sql, contains('CREATE POLICY "issue_ratings_insert"'));
      expect(sql, contains('reporter_id = auth.uid()'));
    });

    test('Loại bỏ toàn bộ RPC overload trùng lặp và khóa simulate_unified_payment', () {
      expect(sql, contains('DROP FUNCTION IF EXISTS public.check_in_visitor_pass(TEXT, UUID)'));
      expect(sql, contains('DROP FUNCTION IF EXISTS public.calculate_utility_charge(VARCHAR, NUMERIC)'));
      expect(sql, contains('DROP FUNCTION IF EXISTS public.simulate_unified_payment(TEXT, UUID, TEXT, TEXT, TEXT, TEXT)'));
      expect(sql, contains('DROP FUNCTION IF EXISTS public.submit_apartment_link_request(UUID, public.apartment_relation_role)'));
      expect(sql, contains('DROP FUNCTION IF EXISTS public.check_and_generate_invoice_due_reminders()'));
      expect(sql, contains('REVOKE ALL ON FUNCTION public.simulate_unified_payment(UUID, TEXT, TEXT, TEXT, TEXT)'));
    });

    test('Hợp nhất record_maintenance_fund_transaction với kiểm tra is_building_staff và đủ cột', () {
      expect(sql, contains('public.is_building_staff('));
      expect(sql, contains('p_recipient_or_payer TEXT DEFAULT'));
      expect(sql, contains('p_reference_type VARCHAR DEFAULT'));
      expect(sql, contains('ADD COLUMN IF NOT EXISTS receipt_url TEXT'));
    });

    test('Gia cố update_invoice_with_items chặn sửa hóa đơn đã thanh toán và chéo tòa nhà', () {
      expect(sql, contains("IF v_inv.status::text IN ('paid', 'pending_confirmation') THEN"));
      expect(sql, contains('v_target_building_id IS DISTINCT FROM v_building_id'));
    });

    test('Thu hồi quyền anon trên toàn bộ hàm nội bộ ngoại trừ 4 RPC công khai trước đăng nhập', () {
      expect(sql, contains("REVOKE EXECUTE ON FUNCTION %s FROM anon, PUBLIC;"));
      expect(sql, contains("'verify_activation_code'"));
      expect(sql, contains("'verify_activation_otp'"));
      expect(sql, contains("'complete_resident_activation'"));
      expect(sql, contains("'verify_document_lookup'"));
    });

    test('RecordMaintenanceTransactionRequestDto ánh xạ đúng p_recipient_or_payer và p_reference_type', () {
      const dto = RecordMaintenanceTransactionRequestDto(
        buildingId: 'bld-1',
        transactionType: 'INCOME',
        amount: 2500000,
        category: 'QUY_2_PHAN_TRAM',
        description: 'Thu quỹ bảo trì',
        recipientOrPayer: 'Chủ đầu tư',
        referenceType: 'MANUAL',
      );
      final params = dto.toRpcParams();
      expect(params['p_recipient_or_payer'], 'Chủ đầu tư');
      expect(params['p_reference_type'], 'MANUAL');
    });
  });
}
