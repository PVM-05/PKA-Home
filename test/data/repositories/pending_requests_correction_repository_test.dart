import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/repositories/vehicle_repository.dart';
import 'package:pka_home/data/repositories/amenity_booking_repository.dart';
import 'package:pka_home/data/repositories/meter_reading_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('Task 2: Kiểm tra các phương thức Repository sửa sai & hủy yêu cầu', () {
    late MockSupabaseClient mockClient;

    setUp(() {
      mockClient = MockSupabaseClient();
    });

    test('VehicleRepository phải có updatePendingVehicle và cancelPendingVehicle', () {
      final repo = VehicleRepository(mockClient);
      expect(repo.updatePendingVehicle, isNotNull);
      expect(repo.cancelPendingVehicle, isNotNull);
    });

    test('AmenityBookingRepository phải có rescheduleBooking', () {
      final repo = AmenityBookingRepository(mockClient);
      expect(repo.rescheduleBooking, isNotNull);
    });

    test('MeterReadingRepository phải có updatePendingSubmission và cancelPendingSubmission', () {
      final repo = MeterReadingRepository(mockClient);
      expect(repo.updatePendingSubmission, isNotNull);
      expect(repo.cancelPendingSubmission, isNotNull);
    });
  });
}
