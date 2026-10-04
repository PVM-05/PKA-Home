import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pka_home/data/repositories/equipment_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('EquipmentRepository Tests', () {
    test('can be instantiated with MockSupabaseClient', () {
      final mockClient = MockSupabaseClient();
      final repo = EquipmentRepository(mockClient);
      expect(repo, isNotNull);
    });
  });
}
