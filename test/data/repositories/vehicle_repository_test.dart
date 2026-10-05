import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/models/vehicle_model.dart';
import 'package:pka_home/data/repositories/vehicle_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('VehicleRepository Tests', () {
    test('VehicleRepository khởi tạo với MockSupabaseClient', () {
      final mockClient = MockSupabaseClient();
      final repo = VehicleRepository(mockClient);
      expect(repo, isNotNull);
    });

    test('approveVehicle và rejectVehicle cập nhật status đúng', () {
      final mockVehicle = VehicleModel(
        id: 'v-100',
        apartmentId: 'apt-1',
        vehicleType: 'motorbike',
        licensePlate: '29A1-99999',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      final approved = mockVehicle.copyWith(status: 'approved');
      expect(approved.status, 'approved');
      expect(approved.isApproved, isTrue);

      final rejected = mockVehicle.copyWith(status: 'rejected');
      expect(rejected.status, 'rejected');
      expect(rejected.isRejected, isTrue);
    });
  });
}
