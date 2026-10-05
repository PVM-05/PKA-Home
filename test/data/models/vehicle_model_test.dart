import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/vehicle_model.dart';

void main() {
  group('VehicleModel Tests', () {
    test('VehicleModel serialization fromJson và toJson chính xác', () {
      final json = {
        'id': 'v-1',
        'apartment_id': 'apt-1',
        'user_id': 'user-1',
        'vehicle_type': 'motorbike',
        'license_plate': '29A1-12345',
        'brand_model': 'Honda Vision',
        'status': 'pending',
        'created_at': '2026-10-05T20:00:00.000Z',
      };

      final vehicle = VehicleModel.fromJson(json);

      expect(vehicle.id, 'v-1');
      expect(vehicle.apartmentId, 'apt-1');
      expect(vehicle.vehicleType, 'motorbike');
      expect(vehicle.licensePlate, '29A1-12345');
      expect(vehicle.brandModel, 'Honda Vision');
      expect(vehicle.status, 'pending');
      expect(vehicle.isPending, isTrue);
      expect(vehicle.isApproved, isFalse);
      expect(vehicle.vehicleTypeDisplayName, 'Xe máy');
      expect(vehicle.statusDisplayName, 'Chờ phê duyệt');

      final outputJson = vehicle.toJson();
      expect(outputJson['license_plate'], '29A1-12345');
      expect(outputJson['vehicle_type'], 'motorbike');
    });

    test('VehicleModel copyWith hoạt động đúng', () {
      final vehicle = VehicleModel(
        id: 'v-2',
        apartmentId: 'apt-1',
        vehicleType: 'car',
        licensePlate: '30E-99999',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      final approvedVehicle = vehicle.copyWith(status: 'approved');
      expect(approvedVehicle.status, 'approved');
      expect(approvedVehicle.isApproved, isTrue);
      expect(approvedVehicle.statusDisplayName, 'Đã phê duyệt');
      expect(approvedVehicle.licensePlate, '30E-99999');
    });
  });
}
