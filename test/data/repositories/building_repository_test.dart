import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/building_model.dart';
import 'package:pka_home/data/providers/building_provider.dart';
import 'package:pka_home/data/repositories/building_repository.dart';

void main() {
  group('BuildingRepository & Providers Tests', () {
    test('BuildingRepository constants are canonical', () {
      expect(
        BuildingRepository.kDefaultCanonicalBuildingId,
        '00000000-0000-0000-0000-000000000002',
      );
      expect(
        BuildingRepository.kDefaultCanonicalOrgId,
        '00000000-0000-0000-0000-000000000001',
      );
    });

    test('activeBuildingIdProvider starts with canonical default and updates', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(activeBuildingIdProvider),
        BuildingRepository.kDefaultCanonicalBuildingId,
      );

      container.read(activeBuildingIdProvider.notifier).setBuildingId('b-test-99');
      expect(container.read(activeBuildingIdProvider), 'b-test-99');
    });

    test('activeBuildingProvider resolves model from active ID', () async {
      final sampleBuilding = BuildingModel(
        id: 'b-test-99',
        organizationId: 'org-1',
        name: 'Park 2 Tower',
        code: 'PKAP2',
      );

      final container = ProviderContainer(
        overrides: [
          activeBuildingIdProvider.overrideWith((ref) => ActiveBuildingIdNotifier()..setBuildingId('b-test-99')),
          activeBuildingProvider.overrideWith((ref) => Future.value(sampleBuilding)),
        ],
      );
      addTearDown(container.dispose);

      final active = await container.read(activeBuildingProvider.future);
      expect(active?.name, 'Park 2 Tower');
      expect(active?.code, 'PKAP2');
    });
  });
}
