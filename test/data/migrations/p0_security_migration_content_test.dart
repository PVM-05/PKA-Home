import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kiểm thử bảo vệ các bản sửa lỗi trong Migration 20261120_03, 20261120_04 và Fresh DB', () {
    final migration03 = File('supabase/migrations/20261120030000_security_hardening_and_missing_rpcs.sql');
    final migration04 = File('supabase/migrations/20261120040000_patch_activation_and_staff_roles.sql');
    final migration06 = File('supabase/migrations/20261106010000_cleanup_dead_tables_and_seed_data.sql');
    final migration14 = File('supabase/migrations/20261114010000_secure_bank_webhook_and_vnpay.sql');

    test('Blocker 1: is_staff_or_management loại bỏ enum manager không hợp lệ (không crash enum user_role)', () {
      expect(migration03.existsSync(), isTrue);
      expect(migration04.existsSync(), isTrue);

      for (final file in [migration03, migration04]) {
        final content = file.readAsStringSync();
        final start = content.indexOf('FUNCTION public.is_staff_or_management()');
        expect(start, isNot(-1));
        final end = content.indexOf(r'$$;', start);
        final funcBody = content.substring(start, end);

        expect(funcBody.contains("'manager'"), isFalse,
            reason: "'manager' không nằm trong enum user_role, sẽ gây crash Postgres runtime: ${file.path}");
        expect(funcBody.contains("'admin'"), isTrue);
        expect(funcBody.contains("'management'"), isTrue);
        expect(funcBody.contains("'staff'"), isTrue);
        expect(funcBody.contains("'accountant'"), isTrue);
        expect(funcBody.contains("'technician'"), isTrue);
      }
    });

    test('Blocker 2: verify_activation_code dùng code_attempts, expires_at và không chứa failed_attempts', () {
      expect(migration03.existsSync(), isTrue);
      expect(migration04.existsSync(), isTrue);

      for (final file in [migration03, migration04]) {
        final content = file.readAsStringSync();
        expect(content.contains("ALTER TABLE public.resident_activations ADD COLUMN IF NOT EXISTS expires_at"), isTrue);
        expect(content.contains("ALTER TABLE public.resident_activations ADD COLUMN IF NOT EXISTS code_attempts"), isTrue);

        final start = content.indexOf('FUNCTION public.verify_activation_code(');
        expect(start, isNot(-1));
        final end = content.indexOf(r'$$;', start);
        final funcBody = content.substring(start, end);

        expect(funcBody.contains('failed_attempts'), isFalse,
            reason: 'Bảng resident_activations không có cột failed_attempts trong: ${file.path}');
        expect(funcBody.contains('code_attempts'), isTrue,
            reason: 'Phải dùng cột code_attempts để rate limit trong: ${file.path}');
        expect(funcBody.contains("COALESCE(v_record.expires_at, v_record.created_at + INTERVAL '30 days')"), isTrue,
            reason: 'Phải kiểm tra hết hạn linh hoạt trong: ${file.path}');
      }
    });

    test('Blocker 3: verify_activation_code cập nhật status = otp_sent và trả về full_name, apartment_code, phone', () {
      expect(migration03.existsSync(), isTrue);
      expect(migration04.existsSync(), isTrue);

      for (final file in [migration03, migration04]) {
        final content = file.readAsStringSync();
        final start = content.indexOf('FUNCTION public.verify_activation_code(');
        final end = content.indexOf(r'$$;', start);
        final funcBody = content.substring(start, end);

        expect(funcBody.contains("status = 'otp_sent'"), isTrue,
            reason: "Phải set status = 'otp_sent' để verify_activation_otp hoạt động");
        expect(funcBody.contains("status IN ('pending', 'otp_sent')"), isTrue,
            reason: "Cho phép xin lại OTP khi mã đang ở trạng thái pending hoặc otp_sent");
        expect(funcBody.contains("'full_name'"), isTrue);
        expect(funcBody.contains("'apartment_code'"), isTrue);
        expect(funcBody.contains("'phone'"), isTrue);
        expect(funcBody.contains("'activation_code'"), isTrue);
      }
    });

    test('Đầy đủ 22/22 RPCs: migration 03 & 04 chứa 3 RPCs mới và mở rộng bảng building_equipments', () {
      expect(migration03.existsSync(), isTrue);
      expect(migration04.existsSync(), isTrue);

      for (final file in [migration03, migration04]) {
        final content = file.readAsStringSync();
        expect(content.contains('FUNCTION public.update_own_profile('), isTrue);
        expect(content.contains('FUNCTION public.get_upcoming_maintenance_equipments('), isTrue);
        expect(content.contains('FUNCTION public.record_meter_reading('), isTrue);

        expect(content.contains('idx_building_equipments_next_maint'), isTrue);
        expect(content.contains('maintenance_interval_days'), isTrue);
      }
    });

    test('Fresh DB: Migration 20261106_01 và 20261114_01 có guard an toàn cho fresh database', () {
      expect(migration06.existsSync(), isTrue);
      expect(migration14.existsSync(), isTrue);

      final content06 = migration06.readAsStringSync();
      expect(content06.contains("to_regclass('public._applied_migrations') IS NOT NULL"), isTrue);

      final content14 = migration14.readAsStringSync();
      expect(content14.contains("information_schema.columns"), isTrue);
    });
  });
}
