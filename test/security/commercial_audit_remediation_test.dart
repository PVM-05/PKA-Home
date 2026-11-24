import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/constants/permissions.dart';
import 'package:vivona/core/security/visitor_pass_token_service.dart';
import 'package:vivona/core/utils/utility_fee_calculator.dart';

void main() {
  group('Commercial Pre-Release Security & Edge-Case Remediation Tests', () {
    late String enumMigrationSql;
    late String hardeningSql;
    late String vnpayIpnTs;
    late String createVnpayTs;
    late String sendFcmTs;

    setUpAll(() {
      enumMigrationSql = File(
        'supabase/migrations/20261124010000_align_remaining_enum_values.sql',
      ).readAsStringSync();
      hardeningSql = File(
        'supabase/migrations/20261124020000_commercial_security_rls_and_payment_hardening.sql',
      ).readAsStringSync();
      vnpayIpnTs = File('supabase/functions/vnpay-ipn/index.ts').readAsStringSync();
      createVnpayTs = File('supabase/functions/create-vnpay-url/index.ts').readAsStringSync();
      sendFcmTs = File('supabase/functions/send-fcm-notification/index.ts').readAsStringSync();
    });

    test('[P0-C5] Enum migration bổ sung giá trị cancelled cho vehicle_status và meter_submission_status', () {
      expect(enumMigrationSql, contains("ALTER TYPE public.vehicle_status ADD VALUE IF NOT EXISTS 'cancelled'"));
      expect(enumMigrationSql, contains("ALTER TYPE public.meter_submission_status ADD VALUE IF NOT EXISTS 'cancelled'"));
    });

    test('[P0-C1 & P0-C2] Hardening migration khóa tự nâng quyền admin và xóa USING(true) trên users', () {
      expect(hardeningSql, contains('CREATE OR REPLACE FUNCTION public.is_super_admin()'));
      expect(hardeningSql, contains('CREATE OR REPLACE FUNCTION public.is_building_staff('));
      expect(hardeningSql, contains('DROP POLICY IF EXISTS "users_read_all_authenticated" ON public.users;'));
      expect(hardeningSql, contains('CREATE POLICY "users_read_scoped" ON public.users'));
      expect(hardeningSql, contains("IF NEW.role = 'admin' OR OLD.role = 'admin' THEN"));
    });

    test('[P0-C3 & P0-C4] Khóa cư dân tự INSERT payment_transactions, hỗ trợ cộng dồn trả góp & ghi Có tiền thừa', () {
      expect(hardeningSql, contains('DROP POLICY IF EXISTS "payment_transactions_insert" ON public.payment_transactions;'));
      expect(hardeningSql, contains('CREATE OR REPLACE FUNCTION public.fn_credit_overpayment_to_ledger('));
      expect(hardeningSql, contains('v_cumulative_paid >= v_invoice.total_amount'));
      expect(hardeningSql, contains('v_verified_building_id'));
      expect(hardeningSql, contains('CREATE OR REPLACE FUNCTION public.reconcile_unmatched_payment_transaction('));
    });

    test('[P0-C5 & P1-H2/H5/M1] Vá ON CONFLICT (building_id, code), security_invoker view, private vehicle-docs và PDPL server-side', () {
      expect(hardeningSql, contains('ON CONFLICT (building_id, code) DO UPDATE'));
      expect(hardeningSql, contains('WITH (security_invoker = true)'));
      expect(hardeningSql, contains('NULL::TEXT AS pickup_pin_hash'));
      expect(hardeningSql, contains("UPDATE storage.buckets SET public = false WHERE id = 'vehicle-docs'"));
      expect(hardeningSql, contains('CREATE TABLE IF NOT EXISTS public.user_pdpl_consents'));
      expect(hardeningSql, contains('CREATE OR REPLACE FUNCTION public.record_pdpl_consent('));
    });

    test('[P0-C4 & P1-H4] Edge Functions: VNPay IPN không log expectedHash, kiểm tra tenant & FCM dùng dữ liệu DB', () {
      expect(vnpayIpnTs, contains('constantTimeEqual'));
      expect(vnpayIpnTs, contains('verified_building_id: verifiedBuildingId'));
      expect(vnpayIpnTs, isNot(contains('expected: expectedHash')));
      expect(createVnpayTs, contains('has_building_role'));
      expect(sendFcmTs, contains('authoritativeNotif'));
    });

    test('[P2-M2] RBAC Permissions bao phủ đầy đủ các tuyến thông báo, lễ tân, cộng đồng và đánh giá', () {
      expect(AppPermissions.announcementManagement.allows('technician'), isFalse);
      expect(AppPermissions.announcementManagement.allows('management'), isTrue);
      expect(AppPermissions.frontDeskWorkstation.allows('security'), isTrue);
      expect(AppPermissions.communityManagement.allows('accountant'), isFalse);
      expect(AppPermissions.serviceRatingOverview.allows('management'), isTrue);
    });

    test('[P2-M3] UtilityFeeCalculator.calculateProratedVehicleFee xử lý an toàn cả định dạng YYYY-MM và MM/YYYY', () {
      final dashResult = UtilityFeeCalculator.calculateProratedVehicleFee(
        monthlyRate: 1200000,
        startDate: DateTime(2026, 11, 16),
        period: '2026-11',
      );
      final slashResult = UtilityFeeCalculator.calculateProratedVehicleFee(
        monthlyRate: 1200000,
        startDate: DateTime(2026, 11, 16),
        period: '11/2026',
      );

      expect(dashResult.daysInMonth, 30);
      expect(dashResult.daysUsed, 15);
      expect(dashResult.totalAmount, 600000);
      expect(slashResult.daysInMonth, 30);
      expect(slashResult.daysUsed, 15);
      expect(slashResult.totalAmount, 600000);
    });

    test('[P1-H6] VisitorPassTokenService chặn hạ cấp không chữ ký PKAPASS: theo mặc định', () {
      final res = VisitorPassTokenService.verifyAndParseQrPayload('PKAPASS:VP-202611-00001:deadbeef');
      expect(res.isValid, isFalse);
    });
  });
}
