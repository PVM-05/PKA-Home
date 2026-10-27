import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/providers/meter_reading_provider.dart';
import 'package:pka_home/data/providers/vehicle_provider.dart';

void main() {
  group('currentApartmentReadingsProvider Tests', () {
    test('returns null when residentApartmentIdProvider is null', () async {
      final container = ProviderContainer(
        overrides: [
          residentApartmentIdProvider.overrideWith((ref) => Future.value(null)),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(currentApartmentReadingsProvider.future);
      expect(result, isNull);
    });

    test('returns null when Supabase query fails instead of falling back to mock A0110', () async {
      final container = ProviderContainer(
        overrides: [
          residentApartmentIdProvider.overrideWith((ref) => Future.value('mock-apt-id')),
        ],
      );
      addTearDown(container.dispose);

      // In test environment without Supabase initialized, catch block triggers
      final result = await container.read(currentApartmentReadingsProvider.future);
      expect(result, isNull, reason: 'Should return null on error, not fake A0110');
    });
  });
}
