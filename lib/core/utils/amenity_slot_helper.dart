import '../../data/models/amenity_maintenance_model.dart';

class AmenitySlotHelper {
  static const List<String> defaultSlots = [
    '06:00 - 07:30',
    '07:30 - 09:00',
    '09:00 - 10:30',
    '14:00 - 15:30',
    '15:30 - 17:00',
    '17:00 - 18:30',
    '18:30 - 20:00',
    '20:00 - 21:30',
  ];

  /// Sinh danh sách khung giờ dựa trên giờ hoạt động (HH:mm - HH:mm) và độ dài mỗi slot (phút)
  static List<String> generateSlots(String? openHours, int slotDurationMinutes) {
    if (openHours == null || !openHours.contains(' - ')) {
      return defaultSlots;
    }

    try {
      final parts = openHours.split(' - ');
      if (parts.length != 2) return defaultSlots;

      final startParts = parts[0].trim().split(':');
      final endParts = parts[1].trim().split(':');

      if (startParts.length != 2 || endParts.length != 2) return defaultSlots;

      final startHour = int.parse(startParts[0]);
      final startMin = int.parse(startParts[1]);
      final endHour = int.parse(endParts[0]);
      final endMin = int.parse(endParts[1]);

      final startTotalMin = startHour * 60 + startMin;
      final endTotalMin = endHour * 60 + endMin;

      if (endTotalMin <= startTotalMin || slotDurationMinutes <= 0) {
        return defaultSlots;
      }

      final List<String> slots = [];
      int current = startTotalMin;

      while (current + slotDurationMinutes <= endTotalMin) {
        final slotStartHour = current ~/ 60;
        final slotStartMin = current % 60;

        final next = current + slotDurationMinutes;
        final slotEndHour = next ~/ 60;
        final slotEndMin = next % 60;

        final startFormatted =
            "${slotStartHour.toString().padLeft(2, '0')}:${slotStartMin.toString().padLeft(2, '0')}";
        final endFormatted =
            "${slotEndHour.toString().padLeft(2, '0')}:${slotEndMin.toString().padLeft(2, '0')}";

        slots.add("$startFormatted - $endFormatted");
        current = next;
      }

      return slots.isNotEmpty ? slots : defaultSlots;
    } catch (_) {
      return defaultSlots;
    }
  }

  /// Kiểm tra xem khung giờ đã qua so với thời gian hiện tại hay chưa
  static bool isSlotInPast(DateTime date, String timeSlot, [DateTime? now]) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final bookingDay = DateTime(date.year, date.month, date.day);

    if (bookingDay.isBefore(today)) return true;
    if (bookingDay.isAfter(today)) return false;

    // Trường hợp đặt cho chính hôm nay -> kiểm tra giờ bắt đầu của slot
    try {
      final startStr = timeSlot.split(' - ').first.trim();
      final timeParts = startStr.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final slotStartTime = DateTime(
        current.year,
        current.month,
        current.day,
        hour,
        minute,
      );

      return slotStartTime.isBefore(current);
    } catch (_) {
      return false;
    }
  }

  /// Kiểm tra xem khung giờ có giao cắt với bất kỳ khoảng bảo trì nào không
  /// Giao cắt khi: slot_start < maint_end && slot_end > maint_start
  static bool isSlotInMaintenance(
    DateTime date,
    String timeSlot,
    List<AmenityMaintenanceModel> maintenanceWindows,
  ) {
    if (maintenanceWindows.isEmpty) return false;

    try {
      final parts = timeSlot.split(' - ');
      if (parts.length != 2) return false;

      final startParts = parts[0].trim().split(':');
      final endParts = parts[1].trim().split(':');

      final startHour = int.parse(startParts[0]);
      final startMin = int.parse(startParts[1]);
      final endHour = int.parse(endParts[0]);
      final endMin = int.parse(endParts[1]);

      final slotStart = DateTime(
        date.year,
        date.month,
        date.day,
        startHour,
        startMin,
      );
      final slotEnd = DateTime(
        date.year,
        date.month,
        date.day,
        endHour,
        endMin,
      );

      for (final maint in maintenanceWindows) {
        if (slotStart.isBefore(maint.endTime) && slotEnd.isAfter(maint.startTime)) {
          return true;
        }
      }

      return false;
    } catch (_) {
      return false;
    }
  }
}
