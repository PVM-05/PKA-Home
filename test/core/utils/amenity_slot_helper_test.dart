import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/utils/amenity_slot_helper.dart';
import 'package:pka_home/data/models/amenity_maintenance_model.dart';

void main() {
  group('AmenitySlotHelper.generateSlots', () {
    test('sinh khung giờ đúng theo khoảng mở cửa và độ dài slot', () {
      final slots = AmenitySlotHelper.generateSlots('06:00 - 09:00', 90);
      expect(slots, ['06:00 - 07:30', '07:30 - 09:00']);
    });

    test('sinh khung giờ với slotDuration 60 phút', () {
      final slots = AmenitySlotHelper.generateSlots('08:00 - 11:00', 60);
      expect(slots, ['08:00 - 09:00', '09:00 - 10:00', '10:00 - 11:00']);
    });

    test('fallback sang default nếu open_hours null hoặc sai cú pháp', () {
      final slotsNull = AmenitySlotHelper.generateSlots(null, 90);
      expect(slotsNull.isNotEmpty, isTrue);

      final slotsInvalid = AmenitySlotHelper.generateSlots('invalid-time', 90);
      expect(slotsInvalid.isNotEmpty, isTrue);
    });
  });

  group('AmenitySlotHelper.isSlotInPast', () {
    test('chặn slot đã qua trong ngày hôm nay', () {
      final today = DateTime(2026, 10, 4);
      final fakeNow = DateTime(2026, 10, 4, 10, 30);

      // Slot 08:00 - 09:30 đã qua so với 10:30
      expect(AmenitySlotHelper.isSlotInPast(today, '08:00 - 09:30', fakeNow), isTrue);

      // Slot 11:00 - 12:30 chưa qua
      expect(AmenitySlotHelper.isSlotInPast(today, '11:00 - 12:30', fakeNow), isFalse);

      // Ngày mai không bị coi là quá khứ
      final tomorrow = DateTime(2026, 10, 5);
      expect(AmenitySlotHelper.isSlotInPast(tomorrow, '08:00 - 09:30', fakeNow), isFalse);

      // Ngày hôm qua bị coi là quá khứ
      final yesterday = DateTime(2026, 10, 3);
      expect(AmenitySlotHelper.isSlotInPast(yesterday, '14:00 - 15:30', fakeNow), isTrue);
    });
  });

  group('AmenitySlotHelper.isSlotInMaintenance', () {
    test('phát hiện giao cắt khoảng bảo trì chính xác (slot_start < maint_end && slot_end > maint_start)', () {
      final date = DateTime(2026, 10, 4);
      final maint = AmenityMaintenanceModel(
        id: 'm1',
        amenityId: 'a1',
        startTime: DateTime(2026, 10, 4, 8, 30),
        endTime: DateTime(2026, 10, 4, 11, 0),
        reason: 'Bảo dưỡng',
      );

      // Slot 08:00 - 09:30 giao cắt với [08:30, 11:00]
      expect(
        AmenitySlotHelper.isSlotInMaintenance(date, '08:00 - 09:30', [maint]),
        isTrue,
      );

      // Slot 06:00 - 07:30 không giao cắt
      expect(
        AmenitySlotHelper.isSlotInMaintenance(date, '06:00 - 07:30', [maint]),
        isFalse,
      );

      // Slot 11:00 - 12:30 tiếp giáp tại 11:00 nhưng không giao cắt
      expect(
        AmenitySlotHelper.isSlotInMaintenance(date, '11:00 - 12:30', [maint]),
        isFalse,
      );
    });
  });
}
