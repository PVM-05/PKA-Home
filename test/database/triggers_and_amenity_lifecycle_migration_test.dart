import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Migration 51 - Triggers, Amenity Lifecycle & Remaining RPC RBAC', () {
    late String migrationSql;
    late String executableSql;

    setUpAll(() {
      final file = File(
        'supabase/migrations/20261127040000_fix_triggers_amenity_lifecycle_and_remaining_rpcs.sql',
      );
      expect(file.existsSync(), isTrue, reason: 'Migration #51 file must exist');
      migrationSql = file.readAsStringSync();
      executableSql = migrationSql
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('--'))
          .join('\n');
    });

    test('adds rejection_reason to apartment_link_requests', () {
      expect(
        executableSql,
        contains('ALTER TABLE public.apartment_link_requests'),
      );
      expect(
        executableSql,
        contains('ADD COLUMN IF NOT EXISTS rejection_reason TEXT'),
      );
    });

    test('fixes runtime SQL/enum/ON CONFLICT crashes in triggers and RPCs', () {
      expect(executableSql, contains("NEW.status::text = 'rejected'"));
      expect(executableSql, contains("NEW.vehicle_type IN ('motorbike', 'motorcycle')"));
      expect(executableSql, contains("status NOT IN ('rejected', 'cancelled')"));
      expect(executableSql, contains('VIVONAPASS:'));
      expect(executableSql, isNot(contains('PKAPASS:')));
      expect(executableSql, contains('pg_trigger_depth() > 0'));
      expect(executableSql, isNot(contains('ON CONFLICT (apartment_id, period)')));
      expect(executableSql, isNot(contains('payment_status')));
      expect(executableSql, isNot(contains("'per_slot'")));
    });

    test('fixes create_invoice_with_items to calculate total_amount before inserting invoice', () {
      final idxFn = executableSql.indexOf('CREATE OR REPLACE FUNCTION public.create_invoice_with_items');
      final idxInsert = executableSql.indexOf('INSERT INTO public.invoices', idxFn);
      final idxSum = executableSql.indexOf('v_total_amount := v_total_amount + v_subtotal;', idxFn);
      expect(idxFn, greaterThan(-1));
      expect(idxSum, greaterThan(idxFn));
      expect(idxInsert, greaterThan(idxSum));
    });

    test('fixes bulk invoice fee_type keys to match InvoiceFeeHelper', () {
      expect(executableSql, contains("'management'"));
      expect(executableSql, contains("'electricity'"));
      expect(executableSql, contains("'water'"));
      expect(executableSql, contains("'parking_motorbike'"));
      expect(executableSql, contains("'parking_car'"));
    });

    test('removes all global is_staff_or_management calls and scopes read RPCs', () {
      expect(executableSql, isNot(contains('is_staff_or_management(')));
      for (final fn in [
        'get_poll_results',
        'get_amenity_slot_availability',
        'calculate_late_payment_penalty',
        'calculate_visitor_parking_fee',
        'cancel_amenity_booking',
        'cancel_apartment_link_request',
        'cancel_pending_meter_reading',
        'update_pending_meter_reading',
        'cancel_pending_vehicle',
        'update_pending_vehicle',
        'get_co_residents',
        'record_manual_amenity_payment',
        'approve_meter_reading',
        'send_invoice_dunning_notifications',
        'validate_monthly_bulk_invoices',
      ]) {
        expect(migrationSql, contains('FUNCTION public.$fn('));
      }
    });
  });
}
