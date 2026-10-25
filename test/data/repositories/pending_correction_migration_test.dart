import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Task 1: Kiểm tra tính hợp lệ của Migration 20261024_04', () {
    final migrationFile = File('supabase/migrations/20261024_04_pending_requests_correction_and_reschedule.sql');

    test('File migration 20261024_04 phải tồn tại', () {
      expect(migrationFile.existsSync(), isTrue, reason: 'Chưa tạo file migration 20261024_04');
    });

    test('Migration phải định nghĩa đầy đủ 6 RPCs nguyên tử', () {
      expect(migrationFile.existsSync(), isTrue);
      final content = migrationFile.readAsStringSync();

      expect(content.contains('cancel_pending_vehicle'), isTrue);
      expect(content.contains('update_pending_vehicle'), isTrue);
      expect(content.contains('reschedule_amenity_booking'), isTrue);
      expect(content.contains('update_pending_meter_reading'), isTrue);
      expect(content.contains('cancel_pending_meter_reading'), isTrue);
      expect(content.contains('cancel_apartment_link_request'), isTrue);
    });

    test('reschedule_amenity_booking phải có cơ chế sắp xếp advisory lock chống Deadlock', () {
      expect(migrationFile.existsSync(), isTrue);
      final content = migrationFile.readAsStringSync();

      expect(content.contains('pg_advisory_xact_lock'), isTrue);
      expect(content.contains('LEAST(') && content.contains('GREATEST('), isTrue,
          reason: 'Bắt buộc phải sắp xếp hash lock bằng LEAST/GREATEST để chống Deadlock');
    });

    test('update_pending_vehicle phải khóa advisory theo căn hộ và kiểm tra hạn mức 2 xe máy', () {
      expect(migrationFile.existsSync(), isTrue);
      final content = migrationFile.readAsStringSync();

      expect(content.contains('vehicle_limit_'), isTrue);
      expect(content.contains('Mỗi căn hộ chỉ được đăng ký tối đa 2 xe máy'), isTrue);
    });

    test('cancel_pending_vehicle phải kiểm tra quyền sở hữu nghiêm ngặt', () {
      expect(migrationFile.existsSync(), isTrue);
      final content = migrationFile.readAsStringSync();

      expect(content.contains('user_id = v_user_id') || content.contains('registered_by = v_user_id'), isTrue);
      expect(content.contains('public.is_staff()'), isTrue);
    });

    test('apartment_link_requests phải chuyển sang VARCHAR và dùng Partial Unique Index', () {
      expect(migrationFile.existsSync(), isTrue);
      final content = migrationFile.readAsStringSync();

      expect(content.contains('uq_link_requests_active'), isTrue);
      expect(content.contains('WHERE status IN (\'pending\', \'approved\')'), isTrue);
    });

    test('Migration phải dọn trùng dữ liệu và không chứa EXCEPTION WHEN OTHERS THEN NULL', () {
      expect(migrationFile.existsSync(), isTrue);
      final content = migrationFile.readAsStringSync();
      expect(content.contains('EXCEPTION WHEN OTHERS THEN NULL'), isFalse,
          reason: 'Khối nuốt lỗi DDL đã phải được loại bỏ hoàn toàn.');
      expect(content.contains('WITH duplicates AS'), isTrue,
          reason: 'Bắt buộc phải có CTE duplicates để dọn bản ghi trùng.');

      final dropDefaultIdx = content.indexOf('ALTER COLUMN status DROP DEFAULT');
      final alterTypeIdx = content.indexOf('ALTER COLUMN status TYPE VARCHAR(20)');
      final duplicatesIdx = content.indexOf('WITH duplicates AS');
      final createIndexIdx = content.indexOf('CREATE UNIQUE INDEX IF NOT EXISTS uq_link_requests_active');

      expect(dropDefaultIdx, isNonNegative, reason: 'Phải DROP DEFAULT trước');
      expect(alterTypeIdx, greaterThan(dropDefaultIdx), reason: 'Phải ALTER TYPE sau khi DROP DEFAULT');
      expect(duplicatesIdx, greaterThan(alterTypeIdx), reason: 'Phải dọn trùng sau khi cột chấp nhận cancelled');
      expect(createIndexIdx, greaterThan(duplicatesIdx), reason: 'Phải tạo index sau khi đã dọn trùng');
    });

    test('Các RPC sửa/hủy xe và điện nước không được chứa quyền thao tác chéo qua residents_apartments', () {
      expect(migrationFile.existsSync(), isTrue);
      final content = migrationFile.readAsStringSync();

      // Khối RPC update_pending_vehicle
      final vehicleUpdateStart = content.indexOf('FUNCTION public.update_pending_vehicle');
      final vehicleUpdateEnd = content.indexOf('FUNCTION public.reschedule_amenity_booking');
      final vehicleUpdateBlock = content.substring(vehicleUpdateStart, vehicleUpdateEnd);
      expect(vehicleUpdateBlock.contains('residents_apartments'), isFalse,
          reason: 'update_pending_vehicle không được cho phép cư dân cùng căn hộ sửa xe.');

      // Khối RPC meter reading
      final meterStart = content.indexOf('FUNCTION public.update_pending_meter_reading');
      final meterEnd = content.indexOf('FUNCTION public.cancel_apartment_link_request');
      final meterBlock = content.substring(meterStart, meterEnd);
      expect(meterBlock.contains('residents_apartments'), isFalse,
          reason: 'RPCs phiếu điện nước không được cho phép cư dân cùng căn hộ sửa/hủy chéo.');
    });

    test('Migration phải định nghĩa trigger check_vehicle_limits có SECURITY DEFINER và khóa FOR UPDATE', () {
      expect(migrationFile.existsSync(), isTrue);
      final content = migrationFile.readAsStringSync();
      expect(content.contains('CREATE OR REPLACE FUNCTION public.check_vehicle_limits()'), isTrue);
      expect(content.contains('SECURITY DEFINER'), isTrue);
      expect(content.contains('SET search_path = public, pg_catalog'), isTrue);
      expect(content.contains('PERFORM 1 FROM public.apartments WHERE id = NEW.apartment_id FOR UPDATE'), isTrue);
      expect(content.contains('NEW.status IN (\'pending\', \'approved\')'), isTrue);
      expect(content.contains('CREATE TRIGGER trg_check_vehicle_limits'), isTrue);
      expect(content.contains('REVOKE ALL ON FUNCTION public.check_vehicle_limits() FROM PUBLIC, anon'), isTrue);
    });

    test('reschedule_amenity_booking phải kiểm tra định dạng giờ regex, logic start < end và Strict FIFO', () {
      expect(migrationFile.existsSync(), isTrue);
      final content = migrationFile.readAsStringSync();
      expect(content.contains('invalid_datetime_format'), isFalse,
          reason: 'Không được nuốt lỗi invalid_datetime_format trong đổi lịch.');
      expect(content.contains('^([01][0-9]|2[0-3]):[0-5][0-9]'), isTrue,
          reason: 'Phải kiểm tra regex 24h định dạng khung giờ.');
      expect(content.contains('v_slot_start_time >= v_slot_end_time'), isTrue,
          reason: 'Phải kiểm tra giờ bắt đầu nhỏ hơn giờ kết thúc.');
      expect(content.contains('v_old_slot_avail'), isTrue,
          reason: 'Phải tính sức chứa còn lại của slot cũ.');
      expect(content.contains('rescheduled_confirmed'), isTrue,
          reason: 'Phải trả về action cụ thể để UI hiển thị chuẩn.');
    });

    test('reschedule_amenity_booking phải dùng regex 24h chuẩn và báo lỗi khi open_hours sai định dạng', () {
      expect(migrationFile.existsSync(), isTrue);
      final content = migrationFile.readAsStringSync();

      // Kiểm tra regex 24h chuẩn
      expect(content.contains('^([01][0-9]|2[0-3]):[0-5][0-9]'), isTrue,
          reason: 'Regex phải là chuẩn 24 giờ ^([01][0-9]|2[0-3]):[0-5][0-9]');
      
      // Kiểm tra báo lỗi khi open_hours sai định dạng
      expect(content.contains('Giờ mở cửa của tiện ích') && content.contains('không đúng định dạng'), isTrue,
          reason: 'Phải báo lỗi khi open_hours có dữ liệu nhưng sai định dạng');
    });

    test('reschedule_amenity_booking phải tự động tạo hoặc đồng bộ payment_transactions PENDING khi đôn Waitlist', () {
      expect(migrationFile.existsSync(), isTrue);
      final content = migrationFile.readAsStringSync();

      final rescheduleStart = content.indexOf('FUNCTION public.reschedule_amenity_booking');
      final rescheduleEnd = content.indexOf('FUNCTION public.update_pending_meter_reading');
      final rescheduleBlock = content.substring(rescheduleStart, rescheduleEnd);

      expect(rescheduleBlock.contains('INSERT INTO public.payment_transactions'), isTrue,
          reason: 'Phải có INSERT INTO payment_transactions khi booking chưa có giao dịch PENDING');
      expect(rescheduleBlock.contains('SVC'), isTrue,
          reason: 'Phải sinh mã giao dịch dịch vụ SVC chuẩn');
    });

    test('Migration phải cấp quyền REVOKE và GRANT EXECUTE tường minh cho approve_link_request', () {
      expect(migrationFile.existsSync(), isTrue);
      final content = migrationFile.readAsStringSync();

      expect(content.contains('REVOKE ALL ON FUNCTION public.approve_link_request(UUID) FROM PUBLIC, anon;'), isTrue,
          reason: 'Phải có REVOKE ALL cho approve_link_request');
      expect(content.contains('GRANT EXECUTE ON FUNCTION public.approve_link_request(UUID) TO authenticated;'), isTrue,
          reason: 'Phải có GRANT EXECUTE cho approve_link_request');
    });
  });

  group('Task 1.2: Kiểm tra Migration 20261025_01 (Remediation SYS-01, SYS-02, SYS-04)', () {
    final file = File('supabase/migrations/20261025_01_fix_waitlist_transactions_and_rpc_security.sql');

    test('File migration 20261025_01 phải tồn tại', () {
      expect(file.existsSync(), isTrue, reason: 'Chưa tạo file migration 20261025_01');
    });

    test('Migration 20261025_01 phải bổ sung updated_at và mở rộng status check cho payment_transactions', () {
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('payment_transactions_status_check'), isTrue);
      expect(content.contains('PENDING'), isTrue);
      expect(content.contains('ADD COLUMN IF NOT EXISTS updated_at'), isTrue);
      expect(content.contains('payment_transactions_type_check'), isTrue);
    });

    test('Migration 20261025_01 phải đồng bộ hóa RPC simulate_unified_payment và loại bỏ overload cũ', () {
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('DROP FUNCTION IF EXISTS public.simulate_unified_payment(varchar, uuid, varchar, varchar, text);'), isTrue);
      expect(content.contains('CREATE OR REPLACE FUNCTION public.simulate_unified_payment'), isTrue);
      expect(content.contains('SET search_path = public, pg_catalog'), isTrue);
    });

    test('Migration 20261025_01 phải siết confirm_payment và phân quyền helper functions', () {
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('confirm_payment'), isTrue);
      expect(content.contains('public.is_admin() OR public.is_accountant()'), isTrue);
      expect(content.contains('REVOKE ALL ON FUNCTION public.confirm_payment(UUID) FROM PUBLIC, anon;'), isTrue);
      expect(content.contains('is_staff_or_management()'), isTrue);
    });

    test('Migration 20261025_01 phải kiểm tra khoảng bảo trì với start_time và end_time', () {
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('start_time AT TIME ZONE'), isTrue);
      expect(content.contains('end_time AT TIME ZONE'), isTrue);
    });
  });
}
