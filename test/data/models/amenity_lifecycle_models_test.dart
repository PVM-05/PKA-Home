import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/building_amenity_model.dart';
import 'package:vivona/data/models/amenity_booking_model.dart';
import 'package:vivona/data/models/amenity_inspection_model.dart';

void main() {
  group('Amenity Lifecycle Models Tests', () {
    test('BuildingAmenityModel parse đầy đủ các trường quota và quy định', () {
      final json = {
        'id': 'amenity-01',
        'name': 'Sân nướng BBQ ngoài trời',
        'open_hours': '17:00 - 21:00',
        'display_order': 1,
        'booking_type': 'exclusive',
        'max_capacity': 1,
        'slot_duration_minutes': 120,
        'fee_amount': 200000,
        'deposit_amount': 500000,
        'requires_deposit': true,
        'is_active': true,
        'max_advance_days': 14,
        'max_slots_per_week': 2,
        'rules_and_regulations': 'Dọn dẹp sạch sẽ sau khi nướng, không làm cháy vỉ than.',
      };

      final model = BuildingAmenityModel.fromJson(json);

      expect(model.id, 'amenity-01');
      expect(model.name, 'Sân nướng BBQ ngoài trời');
      expect(model.maxAdvanceDays, 14);
      expect(model.maxSlotsPerWeek, 2);
      expect(model.rulesAndRegulations, 'Dọn dẹp sạch sẽ sau khi nướng, không làm cháy vỉ than.');
      expect(model.isExclusive, isTrue);
      expect(model.requiresDeposit, isTrue);

      final encoded = model.toJson();
      expect(encoded['max_advance_days'], 14);
      expect(encoded['max_slots_per_week'], 2);
      expect(encoded['rules_and_regulations'], contains('Dọn dẹp sạch sẽ'));
    });

    test('AmenityBookingModel parse đầy đủ token vé QR và dữ liệu nghiệm thu cọc', () {
      final json = {
        'id': 'booking-bbq-01',
        'amenity_id': 'amenity-01',
        'apartment_id': 'apt-01',
        'booking_date': '2026-11-08',
        'time_slot': '17:00 - 19:00',
        'status': 'checked_in',
        'fee_amount': 200000,
        'deposit_amount': 500000,
        'deposit_status': 'refunded',
        'qr_ticket_token': '550e8400-e29b-41d4-a716-446655440000',
        'checked_in_by': 'user-staff-01',
        'check_in_time': '2026-11-08T17:05:00Z',
        'inspected_by': 'user-staff-01',
        'inspected_at': '2026-11-08T19:15:00Z',
        'inspection_result': 'passed',
        'forfeited_amount': 0.0,
        'refund_amount': 500000.0,
        'inspection_notes': 'Sân nướng sạch sẽ, vỉ nướng nguyên vẹn.',
        'inspection_image_urls': ['https://storage.vivona.vn/bbq_done.jpg'],
        'created_at': '2026-11-08T10:00:00Z',
      };

      final booking = AmenityBookingModel.fromJson(json);

      expect(booking.id, 'booking-bbq-01');
      expect(booking.qrTicketToken, '550e8400-e29b-41d4-a716-446655440000');
      expect(booking.isCheckedIn, isTrue);
      expect(booking.depositStatus, 'refunded');
      expect(booking.isRefunded, isTrue);
      expect(booking.isForfeited, isFalse);
      expect(booking.inspectionResult, 'passed');
      expect(booking.refundAmount, 500000.0);
      expect(booking.forfeitedAmount, 0.0);
      expect(booking.inspectionNotes, contains('Sân nướng sạch sẽ'));
      expect(booking.inspectionImageUrls, hasLength(1));
    });

    test('AmenityInspectionModel tạo payload DTO nghiệm thu chuẩn', () {
      const dto = AmenityInspectionModel(
        bookingId: 'booking-bbq-02',
        inspectionResult: 'violated',
        forfeitedAmount: 200000,
        notes: 'Làm cháy hỏng vỉ than và không dọn rác.',
        imageUrls: ['https://storage.vivona.vn/violation_1.jpg'],
      );

      final rpcParams = dto.toRpcParams();

      expect(rpcParams['p_booking_id'], 'booking-bbq-02');
      expect(rpcParams['p_inspection_result'], 'violated');
      expect(rpcParams['p_forfeited_amount'], 200000);
      expect(rpcParams['p_notes'], contains('Làm cháy hỏng'));
      expect(rpcParams['p_image_urls'], contains('https://storage.vivona.vn/violation_1.jpg'));
    });
  });
}
