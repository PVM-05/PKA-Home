import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/building_amenity_model.dart';
import 'package:pka_home/data/models/amenity_booking_model.dart';
import 'package:pka_home/data/models/amenity_maintenance_model.dart';

void main() {
  group('BuildingAmenityModel v2', () {
    test('deserialize đầy đủ các trường nâng cao', () {
      final json = {
        'id': 'amenity-1',
        'name': 'Hồ bơi vô cực',
        'description': 'Tầng thượng',
        'open_hours': '06:00 - 21:00',
        'display_order': 1,
        'booking_type': 'shared',
        'max_capacity': 20,
        'slot_duration_minutes': 60,
        'fee_amount': 50000.0,
        'deposit_amount': 0.0,
        'requires_deposit': false,
        'is_active': true,
      };

      final model = BuildingAmenityModel.fromJson(json);
      expect(model.bookingType, 'shared');
      expect(model.maxCapacity, 20);
      expect(model.slotDurationMinutes, 60);
      expect(model.feeAmount, 50000.0);
      expect(model.depositAmount, 0.0);
      expect(model.requiresDeposit, isFalse);
      expect(model.isActive, isTrue);
      expect(model.isShared, isTrue);
      expect(model.isExclusive, isFalse);
    });

    test('toJson serialize chính xác', () {
      final model = BuildingAmenityModel(
        id: 'amenity-1',
        name: 'Sân nướng BBQ',
        displayOrder: 2,
        bookingType: 'exclusive',
        maxCapacity: 1,
        slotDurationMinutes: 120,
        feeAmount: 200000,
        depositAmount: 500000,
        requiresDeposit: true,
        isActive: true,
      );

      final json = model.toJson();
      expect(json['booking_type'], 'exclusive');
      expect(json['max_capacity'], 1);
      expect(json['slot_duration_minutes'], 120);
      expect(json['fee_amount'], 200000);
      expect(json['deposit_amount'], 500000);
      expect(json['requires_deposit'], isTrue);
      expect(json['is_active'], isTrue);
    });
  });

  group('AmenityBookingModel v2', () {
    test('deserialize waitlist và snapshot phí/cọc', () {
      final json = {
        'id': 'booking-1',
        'amenity_id': 'amenity-1',
        'apartment_id': 'apt-1',
        'booking_date': '2026-10-10',
        'time_slot': '08:00 - 09:30',
        'status': 'waitlist',
        'guests_count': 2,
        'fee_amount': 100000.0,
        'deposit_amount': 500000.0,
        'deposit_status': 'pending',
        'deposit_notes': 'Chờ nhận cọc tại sảnh',
        'created_at': '2026-10-04T10:00:00Z',
      };

      final model = AmenityBookingModel.fromJson(json);
      expect(model.isWaitlist, isTrue);
      expect(model.isConfirmed, isFalse);
      expect(model.isCompleted, isFalse);
      expect(model.isNoShow, isFalse);
      expect(model.guestsCount, 2);
      expect(model.feeAmount, 100000.0);
      expect(model.depositAmount, 500000.0);
      expect(model.depositStatus, 'pending');
      expect(model.depositNotes, 'Chờ nhận cọc tại sảnh');
    });

    test('toJson serialize các trường v2', () {
      final model = AmenityBookingModel(
        id: 'booking-2',
        amenityId: 'amenity-1',
        apartmentId: 'apt-1',
        bookingDate: DateTime(2026, 10, 10),
        timeSlot: '14:00 - 15:30',
        status: 'confirmed',
        guestsCount: 4,
        feeAmount: 50000,
        depositAmount: 200000,
        depositStatus: 'received',
        createdAt: DateTime.now(),
      );

      final json = model.toJson();
      expect(json['guests_count'], 4);
      expect(json['fee_amount'], 50000);
      expect(json['deposit_amount'], 200000);
      expect(json['deposit_status'], 'received');
    });
  });

  group('AmenityMaintenanceModel', () {
    test('deserialize và serialize chính xác', () {
      final json = {
        'id': 'maint-1',
        'amenity_id': 'amenity-1',
        'start_time': '2026-10-10T08:00:00Z',
        'end_time': '2026-10-10T12:00:00Z',
        'reason': 'Vệ sinh định kỳ',
        'created_by': 'user-1',
        'created_at': '2026-10-04T07:00:00Z',
      };

      final model = AmenityMaintenanceModel.fromJson(json);
      expect(model.id, 'maint-1');
      expect(model.amenityId, 'amenity-1');
      expect(model.reason, 'Vệ sinh định kỳ');
      expect(model.startTime, DateTime.parse('2026-10-10T08:00:00Z'));
      expect(model.endTime, DateTime.parse('2026-10-10T12:00:00Z'));

      final outJson = model.toJson();
      expect(outJson['reason'], 'Vệ sinh định kỳ');
      expect(outJson['amenity_id'], 'amenity-1');
    });
  });
}
