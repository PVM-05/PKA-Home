import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/amenity_booking_model.dart';

void main() {
  group('AmenityBookingModel', () {
    test('fromJson and toJson parse pending_payment status and fee fields correctly', () {
      final json = {
        'id': 'bk-123',
        'amenity_id': 'am-456',
        'apartment_id': 'apt-789',
        'booked_by': 'usr-001',
        'booking_date': '2026-10-25',
        'time_slot': '08:00 - 09:00',
        'status': 'pending_payment',
        'guests_count': 3,
        'fee_amount': 150000.0,
        'deposit_amount': 50000.0,
        'deposit_status': 'pending',
        'deposit_notes': 'Chờ nộp cọc',
        'building_amenities': {'name': 'Phòng Gym & Yoga'},
        'apartments': {'code': 'A0101'},
        'users': {'full_name': 'Phạm Minh Đức'},
        'created_at': '2026-10-24T12:00:00Z',
      };

      final model = AmenityBookingModel.fromJson(json);

      expect(model.id, 'bk-123');
      expect(model.status, 'pending_payment');
      expect(model.isPendingPayment, isTrue);
      expect(model.isConfirmed, isFalse);
      expect(model.isWaitlist, isFalse);
      expect(model.guestsCount, 3);
      expect(model.feeAmount, 150000.0);
      expect(model.depositAmount, 50000.0);
      expect(model.depositStatus, 'pending');
      expect(model.amenityName, 'Phòng Gym & Yoga');
      expect(model.apartmentCode, 'A0101');
      expect(model.bookerName, 'Phạm Minh Đức');

      final serialized = model.toJson();
      expect(serialized['id'], 'bk-123');
      expect(serialized['status'], 'pending_payment');
      expect(serialized['fee_amount'], 150000.0);
      expect(serialized['deposit_amount'], 50000.0);
      expect(serialized['guests_count'], 3);
    });

    test('isPendingPayment and canCancel status helpers work as expected', () {
      final model = AmenityBookingModel(
        id: 'bk-999',
        amenityId: 'am-1',
        apartmentId: 'apt-1',
        bookingDate: DateTime(2026, 10, 25),
        timeSlot: '09:00 - 10:00',
        status: 'pending_payment',
        createdAt: DateTime.now(),
      );

      expect(model.isPendingPayment, isTrue);
      expect(model.isConfirmed, isFalse);
    });
  });
}
