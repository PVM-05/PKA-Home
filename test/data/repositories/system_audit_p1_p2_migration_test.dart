import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/amenity_booking_model.dart';

void main() {
  group('P1 & P2 System Audit Migration Tests', () {
    test('Tập tin migration tiện ích & bảo mật phải tồn tại', () {
      final file1 = File('supabase/migrations/20261108020000_amenity_lifecycle_and_deposit.sql');
      final file2 = File('supabase/migrations/20261120010000_security_hardening_auth_and_rls.sql');
      expect(file1.existsSync(), isTrue);
      expect(file2.existsSync(), isTrue);
    });

    test('Migration phải định nghĩa RPC ẩn danh PII, múi giờ Việt Nam và kiểm tra bảo trì', () {
      final content1 = File('supabase/migrations/20261108020000_amenity_lifecycle_and_deposit.sql').readAsStringSync();
      final content2 = File('supabase/migrations/20261120010000_security_hardening_auth_and_rls.sql').readAsStringSync();

      // 1. RPC ẩn danh PII slot availability
      expect(content2.contains('get_amenity_slot_availability'), isTrue);
      expect(content2.contains('is_my_booking'), isTrue);

      // 2. Múi giờ Việt Nam và kiểm tra bảo trì trong book_amenity_slot
      expect(content1.contains('Asia/Ho_Chi_Minh'), isTrue);
      expect(content1.contains('amenity_maintenance_windows'), isTrue);
    });

    test('AmenityBookingModel ánh xạ đúng trường notes trong fromJson và toJson', () {
      final jsonSample = {
        'id': 'booking-123',
        'amenity_id': 'amenity-456',
        'apartment_id': 'apt-789',
        'booked_by': 'user-001',
        'booking_date': '2026-10-25',
        'time_slot': '08:00 - 10:00',
        'status': 'confirmed',
        'guests_count': 3,
        'fee_amount': 150000.0,
        'deposit_amount': 200000.0,
        'deposit_status': 'received',
        'notes': 'Yêu cầu chuẩn bị 2 bóng rổ tiêu chuẩn',
        'created_at': '2026-10-24T10:00:00Z',
      };

      final model = AmenityBookingModel.fromJson(jsonSample);
      expect(model.notes, 'Yêu cầu chuẩn bị 2 bóng rổ tiêu chuẩn');
      expect(model.guestsCount, 3);
      expect(model.feeAmount, 150000.0);

      final exported = model.toJson();
      expect(exported['notes'], 'Yêu cầu chuẩn bị 2 bóng rổ tiêu chuẩn');
      expect(exported['amenity_id'], 'amenity-456');
    });
  });
}

