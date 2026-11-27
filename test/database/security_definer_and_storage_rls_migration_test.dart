import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/widgets/app_storage_image.dart';

void main() {
  group('Wave 3 Security Definer RPC & Storage RLS Migration (20261127030000)', () {
    final migrationFile = File(
      'supabase/migrations/20261127030000_harden_security_definer_rpcs_and_storage_rls.sql',
    );
    late String sql;

    setUpAll(() {
      expect(
        migrationFile.existsSync(),
        isTrue,
        reason: 'Tệp migration 20261127030000 phải tồn tại trong supabase/migrations/',
      );
      sql = migrationFile.readAsStringSync();
    });

    test('Vá 5 lỗi vỡ cột / sai enum runtime trong các RPC quan trọng', () {
      // 1. charge_issue_materials_to_invoice dùng 'maintenance' và không chèn subtotal
      expect(sql, contains('ADD COLUMN IF NOT EXISTS description TEXT'));
      expect(sql, contains("INSERT INTO public.invoice_items (\n            invoice_id,\n            fee_type,\n            unit_price,\n            quantity,\n            description"));
      expect(sql, contains("'maintenance',"));
      expect(sql, isNot(contains("'service'")));

      // 2. reject_meter_reading dùng reject_reason, reviewed_by, reviewed_at
      expect(sql, contains('reject_reason ='));
      expect(sql, contains('reviewed_by = v_user_id'));

      // 3. onboard_building_commercial_config dùng đúng cột audit_logs
      expect(sql, contains('INSERT INTO public.audit_logs ('));
      expect(sql, contains('new_values,'));
      expect(sql, isNot(contains('new_data')));

      // 4. check_in_amenity_ticket dùng checked_in_at
      expect(sql, contains('v_booking.checked_in_at'));
      expect(sql, isNot(contains('check_in_time')));

      // 5. create_payment_intent kiểm tra đã thanh toán qua payment_transactions thay cho cột không tồn tại
      expect(sql, contains('FROM public.payment_transactions pt'));
      expect(sql, isNot(contains('v_booking.payment_status')));
    });

    test('Khóa đa cơ sở is_building_staff / can_access_apartment trên toàn bộ SECURITY DEFINER RPC nhạy cảm', () {
      const hardenedFunctions = [
        'close_accounting_period',
        'record_apartment_ledger_entry',
        'issue_credit_note',
        'generate_receipt_number',
        'confirm_payment',
        'record_manual_payment',
        'inspect_and_settle_amenity_deposit',
        'check_in_amenity_booking',
        'record_issue_materials_usage',
        'checkout_visitor_ticket',
        'broadcast_announcement',
        'mark_announcement_read',
        'triage_and_auto_assign_issue',
        'approve_link_request',
        'batch_record_meter_readings',
        'batch_import_apartments',
        'batch_import_meter_readings',
        'batch_import_residents',
        'import_residents_batch',
        'get_building_activation_list',
        'regenerate_resident_activation',
        'revoke_resident_activation',
        'create_apartment_invitation',
        'terminate_resident_stay',
        'calculate_apartment_debt_risk',
        'execute_dunning_action',
        'get_building_debt_radar',
        'get_apartment_contracts',
        'get_apartment_ledger_balance',
        'detect_meter_reading_anomaly',
        'get_organization_subscription_status',
        'get_front_desk_stats',
        'get_issue_sla_stats',
        'get_parking_capacity_stats',
        'get_upcoming_maintenance_equipments',
      ];
      for (final fn in hardenedFunctions) {
        expect(sql, contains('CREATE OR REPLACE FUNCTION public.$fn'));
      }

      // create_apartment_invitation dùng tiền tố Vivona 'VVN'
      expect(sql, contains("CONCAT('VVN'"));
      expect(sql, contains('public.is_building_staff('));
      expect(sql, contains('public.can_access_apartment('));
    });

    test('Gỡ policy storage toàn cục và khóa RLS theo tòa nhà cho private buckets', () {
      expect(sql, contains('DROP POLICY IF EXISTS "Management toàn quyền storage" ON storage.objects;'));
      expect(sql, contains('CREATE POLICY "vehicle_docs_insert_scoped"'));
      expect(sql, contains('CREATE POLICY "handover_docs_delete_scoped"'));
      expect(sql, contains('CREATE POLICY "issue_images_staff_scoped"'));
      expect(sql, contains('CREATE POLICY "meter_readings_staff_scoped"'));
    });
  });

  group('AppStorageImage.parseStorageTarget multi-bucket parsing', () {
    test('Phân tích chính xác public URL, signed URL và đường dẫn tương đối đa bucket', () {
      final vehiclePublic = AppStorageImage.parseStorageTarget(
        'https://demo.supabase.co/storage/v1/object/public/vehicle-docs/apt-1/123.jpg',
      );
      expect(vehiclePublic, isNotNull);
      expect(vehiclePublic!.bucket, 'vehicle-docs');
      expect(vehiclePublic.objectPath, 'apt-1/123.jpg');

      final vehicleRaw = AppStorageImage.parseStorageTarget(
        'apt-1/car_456.png',
        defaultBucket: 'vehicle-docs',
      );
      expect(vehicleRaw, isNotNull);
      expect(vehicleRaw!.bucket, 'vehicle-docs');
      expect(vehicleRaw.objectPath, 'apt-1/car_456.png');

      final handoverSig = AppStorageImage.parseStorageTarget(
        'signatures/ho-1_staff_999.png',
      );
      expect(handoverSig, isNotNull);
      expect(handoverSig!.bucket, 'handover-docs');
      expect(handoverSig.objectPath, 'signatures/ho-1_staff_999.png');

      final issuePath = AppStorageImage.parseStorageTarget('staff-1/issue-1/proof.jpg');
      expect(issuePath, isNotNull);
      expect(issuePath!.bucket, 'issue-images');
      expect(issuePath.objectPath, 'staff-1/issue-1/proof.jpg');

      final externalUrl = AppStorageImage.parseStorageTarget('https://example.com/avatar.png');
      expect(externalUrl, isNull);

      final empty = AppStorageImage.parseStorageTarget('   ');
      expect(empty, isNull);
    });
  });
}
