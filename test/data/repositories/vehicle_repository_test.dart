import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/repositories/vehicle_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('VehicleRepository Unit Tests', () {
    late MockSupabaseClient mockClient;
    late VehicleRepository repository;

    setUp(() {
      mockClient = MockSupabaseClient();
      repository = VehicleRepository(mockClient);
    });

    test('VehicleRepository khởi tạo thành công với SupabaseClient', () {
      expect(repository, isNotNull);
    });
  });
}
