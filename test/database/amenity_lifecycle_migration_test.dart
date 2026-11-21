import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Database Migration: 20261108020000_amenity_lifecycle_and_deposit.sql', () {
    late String migrationContent;

    setUpAll(() {
      final file = File('supabase/migrations/20261108020000_amenity_lifecycle_and_deposit.sql');
      expect(file.existsSync(), isTrue, reason: 'Tệp migration phải tồn tại');
      migrationContent = file.readAsStringSync();
    });

    test('Chứa lệnh mở rộng bảng building_amenities và amenity_bookings', () {
      expect(migrationContent, contains('ALTER TABLE public.building_amenities'));
      expect(migrationContent, contains('max_advance_days'));
      expect(migrationContent, contains('max_slots_per_week'));
      expect(migrationContent, contains('rules_and_regulations'));

      expect(migrationContent, contains('ALTER TABLE public.amenity_bookings'));
      expect(migrationContent, contains('qr_ticket_token'));
      expect(migrationContent, contains('checked_in_by'));
      expect(migrationContent, contains('inspected_by'));
      expect(migrationContent, contains('inspected_at'));
      expect(migrationContent, contains('inspection_result'));
      expect(migrationContent, contains('forfeited_amount'));
      expect(migrationContent, contains('refund_amount'));
      expect(migrationContent, contains('inspection_notes'));
    });

    test('Chứa RPC book_amenity_slot nâng cấp hỗ trợ quota tuần và token vé QR', () {
      expect(migrationContent, contains('CREATE OR REPLACE FUNCTION public.book_amenity_slot'));
      expect(migrationContent, contains('max_slots_per_week'));
      expect(migrationContent, contains('qr_ticket_token'));
      expect(migrationContent, contains('pg_advisory_xact_lock'));
    });

    test('Chứa RPC check_in_amenity_ticket xác thực vé QR tại cổng', () {
      expect(migrationContent, contains('CREATE OR REPLACE FUNCTION public.check_in_amenity_ticket'));
      expect(migrationContent, contains('p_qr_ticket_token'));
      expect(migrationContent, contains('checked_in'));
      expect(migrationContent, contains('check_in_time'));
    });

    test('Chứa RPC inspect_and_settle_amenity_deposit nghiệm thu cọc', () {
      expect(migrationContent, contains('CREATE OR REPLACE FUNCTION public.inspect_and_settle_amenity_deposit'));
      expect(migrationContent, contains('p_booking_id'));
      expect(migrationContent, contains('p_inspection_result'));
      expect(migrationContent, contains('refunded'));
      expect(migrationContent, contains('forfeited'));
    });
  });
}
