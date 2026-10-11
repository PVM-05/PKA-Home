import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/repositories/amenity_booking_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('AmenityBookingRepository Error Propagation Tests', () {
    late MockSupabaseClient mockClient;
    late AmenityBookingRepository repo;

    setUp(() {
      mockClient = MockSupabaseClient();
      repo = AmenityBookingRepository(mockClient);
    });

    test('Khởi tạo AmenityBookingRepository với mockClient thành công', () {
      expect(repo, isNotNull);
    });

    test('getBookingsByAmenityAndDate không nuốt lỗi khi client ném ngoại lệ', () async {
      when(() => mockClient.from('amenity_bookings')).thenThrow(
        const PostgrestException(message: 'Permission denied', code: '42501'),
      );

      expect(
        () async => await repo.getBookingsByAmenityAndDate(
          amenityId: 'amenity-uuid',
          date: DateTime(2026, 10, 11),
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('getMaintenanceWindows không nuốt lỗi khi client ném ngoại lệ', () async {
      when(() => mockClient.from('amenity_maintenance_windows')).thenThrow(
        const PostgrestException(message: 'Database connection failed', code: '08006'),
      );

      expect(
        () async => await repo.getMaintenanceWindows(
          amenityId: 'amenity-uuid',
          date: DateTime(2026, 10, 11),
        ),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
