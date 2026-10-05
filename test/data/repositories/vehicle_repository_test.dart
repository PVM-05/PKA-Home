import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/repositories/vehicle_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('VehicleRepository Tests', () {
    test('có thể khởi tạo với MockSupabaseClient', () {
      final mockClient = MockSupabaseClient();
      final repo = VehicleRepository(mockClient);
      expect(repo, isNotNull);
    });
  });
}
