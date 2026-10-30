import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Resident Lifecycle & Contracts Migration Tests (20261030_04)', () {
    const migrationPath = 'supabase/migrations/20261030_04_resident_lifecycle_and_contracts.sql';

    test('Migration file exists and is not empty', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Migration file must exist at $migrationPath');
      final content = file.readAsStringSync().trim();
      expect(content.isNotEmpty, isTrue, reason: 'Migration file must not be empty');
    });

    test('Migration alters residents_apartments with lifecycle and contract columns', () {
      final content = File(migrationPath).readAsStringSync();
      expect(content.contains('residents_apartments'), isTrue);
      expect(content.contains('start_date'), isTrue);
      expect(content.contains('end_date'), isTrue);
      expect(content.contains('deposit_amount'), isTrue);
      expect(content.contains('contract_number'), isTrue);
      expect(content.contains('status'), isTrue);
    });

    test('Migration defines apartment_invitations table with required columns', () {
      final content = File(migrationPath).readAsStringSync();
      expect(content.contains('CREATE TABLE IF NOT EXISTS public.apartment_invitations'), isTrue);
      expect(content.contains('apartment_id'), isTrue);
      expect(content.contains('invite_code'), isTrue);
      expect(content.contains('target_role'), isTrue);
      expect(content.contains('expires_at'), isTrue);
      expect(content.contains('max_uses'), isTrue);
      expect(content.contains('used_count'), isTrue);
    });

    test('Migration defines required RPCs for invitation and stay termination', () {
      final content = File(migrationPath).readAsStringSync();
      expect(content.contains('create_apartment_invitation'), isTrue);
      expect(content.contains('accept_apartment_invitation'), isTrue);
      expect(content.contains('terminate_resident_stay'), isTrue);
      expect(content.contains('get_apartment_contracts'), isTrue);
    });
  });
}
