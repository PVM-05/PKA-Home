import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/vehicle_model.dart';

void main() {
  group('VehicleModel Tests', () {
    test('Khởi tạo VehicleModel đầy đủ và kiểm tra helper getters', () {
      final vehicle = VehicleModel(
        id: 'v-1',
        apartmentId: 'apt-1',
        vehicleType: 'motorbike',
        licensePlate: '29A-12345',
        brandModel: 'Honda AirBlade',
        status: 'pending',
        createdAt: DateTime(2026, 10, 6),
      );

      expect(vehicle.isPending, isTrue);
      expect(vehicle.isApproved, isFalse);
      expect(vehicle.isRejected, isFalse);
      expect(vehicle.isActive, isTrue);
      expect(vehicle.hasRejectionReason, isFalse);
      expect(vehicle.vehicleTypeDisplayName, 'Xe máy');
      expect(vehicle.monthlyFee, 100000.0);
    });

    test('fromJson parse dung rejection_reason va brand_model', () {
      final json = {
        'id': 'v-2',
        'apartment_id': 'apt-1',
        'vehicle_type': 'car',
        'license_plate': '30H-999.88',
        'brand_model': 'Mazda CX-5',
        'status': 'rejected',
        'rejection_reason': 'Biển số xe không rõ ràng trong ảnh chụp',
        'created_at': '2026-10-06T10:00:00.000Z',
      };

      final vehicle = VehicleModel.fromJson(json);

      expect(vehicle.isRejected, isTrue);
      expect(vehicle.isActive, isFalse);
      expect(vehicle.hasRejectionReason, isTrue);
      expect(vehicle.rejectionReason, 'Biển số xe không rõ ràng trong ảnh chụp');
      expect(vehicle.brandModel, 'Mazda CX-5');
      expect(vehicle.vehicleTypeDisplayName, 'Ô tô');
      expect(vehicle.monthlyFee, 1200000.0);

      final outJson = vehicle.toJson();
      expect(outJson['rejection_reason'], 'Biển số xe không rõ ràng trong ảnh chụp');
      expect(outJson['brand_model'], 'Mazda CX-5');
    });

    test('copyWith cap nhat dung rejection_reason', () {
      final vehicle = VehicleModel(
        id: 'v-3',
        apartmentId: 'apt-1',
        vehicleType: 'motorbike',
        licensePlate: '59-X1 56789',
        status: 'pending',
        createdAt: DateTime(2026, 10, 6),
      );

      final updated = vehicle.copyWith(
        status: 'rejected',
        rejectionReason: 'Vượt quá hạn mức 2 xe máy của căn hộ',
      );

      expect(updated.isRejected, isTrue);
      expect(updated.rejectionReason, 'Vượt quá hạn mức 2 xe máy của căn hộ');
    });
  });
}
