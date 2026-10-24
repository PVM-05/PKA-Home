import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/amenity_booking_model.dart';

void main() {
  group('P1 & P2 System Audit Migration Tests (20261024_02)', () {
    test('Tập tin migration 20261024_02_system_audit_p1_p2_fixes.sql phải tồn tại', () {
      final file = File('supabase/migrations/20261024_02_system_audit_p1_p2_fixes.sql');
      expect(file.existsSync(), isTrue, reason: 'Migration 20261024_02_system_audit_p1_p2_fixes.sql chưa được tạo');
    });

    test('Migration phải định nghĩa cột notes, Partial Unique Index và RPC ẩn danh PII', () {
      final file = File('supabase/migrations/20261024_02_system_audit_p1_p2_fixes.sql');
      final content = file.readAsStringSync();

      // 1. Cột notes
      expect(content.contains('ADD COLUMN IF NOT EXISTS notes TEXT'), isTrue);

      // 2. Chống giao dịch PENDING trùng lặp
      expect(content.contains('uq_pending_invoice_transaction'), isTrue);
      expect(content.contains('uq_pending_booking_transaction'), isTrue);
      expect(content.contains("WHERE status = 'PENDING'"), isTrue);

      // 3. RPC ẩn danh PII slot availability
      expect(content.contains('get_amenity_slot_availability'), isTrue);
      expect(content.contains('is_my_booking'), isTrue);

      // 4. Siết RLS đọc amenity_bookings
      expect(content.contains('booked_by = auth.uid()'), isTrue);

      // 5. Múi giờ Việt Nam và kiểm tra bảo trì trong book_amenity_slot
      expect(content.contains('Asia/Ho_Chi_Minh'), isTrue);
      expect(content.contains('amenity_maintenance_windows'), isTrue);
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
