import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/parking_slot_model.dart';
import 'package:pka_home/data/models/parking_capacity_stats_model.dart';

void main() {
  group('ParkingSlotModel Tests', () {
    test('fromJson and toJson should work correctly', () {
      final json = {
        'id': 'slot-01',
        'building_id': 'b-01',
        'zone': 'B1',
        'slot_number': 'P-B1-01',
        'slot_type': 'car',
        'status': 'occupied',
        'assigned_vehicle_id': 'veh-01',
        'assigned_apartment_id': 'apt-01',
        'license_plate': '30A-999.88',
        'apartment_code': 'A0101',
        'note': 'Chỗ đỗ xe VIP',
        'created_at': '2026-11-02T10:00:00Z',
      };

      final model = ParkingSlotModel.fromJson(json);

      expect(model.id, 'slot-01');
      expect(model.zone, 'B1');
      expect(model.slotNumber, 'P-B1-01');
      expect(model.slotType, 'car');
      expect(model.status, 'occupied');
      expect(model.isOccupied, isTrue);
      expect(model.isCar, isTrue);
      expect(model.displayStatus, 'Đã có xe');
      expect(model.displayType, 'Ô tô');
      expect(model.licensePlate, '30A-999.88');
      expect(model.apartmentCode, 'A0101');

      final outputJson = model.toJson();
      expect(outputJson['slot_number'], 'P-B1-01');
      expect(outputJson['status'], 'occupied');
    });

    test('copyWith updates fields as expected', () {
      final model = ParkingSlotModel(
        id: 'slot-02',
        zone: 'B2',
        slotNumber: 'M-B2-01',
        slotType: 'motorcycle',
        status: 'available',
        createdAt: DateTime.now(),
      );

      final updated = model.copyWith(
        status: 'occupied',
        licensePlate: '29B1-123.45',
      );

      expect(updated.status, 'occupied');
      expect(updated.licensePlate, '29B1-123.45');
      expect(updated.slotNumber, 'M-B2-01');
    });
  });

  group('ParkingCapacityStatsModel Tests', () {
    test('fromJson calculates occupancy rates and remaining slots', () {
      final json = {
        'car_total': 50,
        'car_occupied': 35,
        'car_available': 15,
        'moto_total': 200,
        'moto_occupied': 120,
        'moto_available': 80,
        'visitor_count': 12,
      };

      final stats = ParkingCapacityStatsModel.fromJson(json);

      expect(stats.carTotal, 50);
      expect(stats.carOccupied, 35);
      expect(stats.carAvailable, 15);
      expect(stats.carOccupancyRate, 70.0);
      expect(stats.motoTotal, 200);
      expect(stats.motoOccupied, 120);
      expect(stats.motoAvailable, 80);
      expect(stats.motoOccupancyRate, 60.0);
      expect(stats.visitorCount, 12);
    });
  });
}
