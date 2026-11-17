import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/building_model.dart';
import 'package:vivona/data/models/resident_activation_model.dart';
import 'package:vivona/data/providers/building_provider.dart';
import 'package:vivona/data/providers/resident_activation_provider.dart';
import 'package:vivona/data/repositories/resident_activation_repository.dart';
import 'package:vivona/features/management/widgets/resident_activation_management_sheet.dart';

class FakeResidentActivationRepository extends ResidentActivationRepository {
  @override
  Future<List<ResidentActivationModel>> fetchBuildingActivationList(
    String buildingId,
  ) async {
    return [
      const ResidentActivationModel(
        userId: 'u1',
        fullName: 'Nguyễn Văn An',
        phone: '0901234567',
        apartmentCode: 'A0110',
        relationRole: 'owner',
        activationCode: 'ACT-102948',
        status: 'pending',
        isActive: false,
      ),
      const ResidentActivationModel(
        userId: 'u2',
        fullName: 'Trần Thị Bình',
        phone: '0912345678',
        apartmentCode: 'A0110',
        relationRole: 'family_member',
        activationCode: 'ACT-593821',
        status: 'activated',
        isActive: true,
      ),
    ];
  }
}

void main() {
  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        residentActivationRepositoryProvider.overrideWithValue(
          FakeResidentActivationRepository(),
        ),
        activeBuildingProvider.overrideWith(
          (ref) async => BuildingModel(
            id: 'test-building-id',
            organizationId: 'org-1',
            code: 'A',
            name: 'Tòa A',
            totalFloors: 10,
            totalUnits: 100,
          ),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ResidentActivationManagementSheet(),
        ),
      ),
    );
  }

  group('ResidentActivationManagementSheet Tests', () {
    testWidgets('renders activation list and stat badges correctly', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Mã Kích Hoạt & Thư Mời Cư Dân'), findsOneWidget);
      expect(find.text('Đã kích hoạt'), findsNWidgets(2));
      expect(find.text('Chờ kích hoạt'), findsOneWidget);
      expect(find.text('Chưa cấp mã'), findsOneWidget);
      expect(find.text('Đã cấp mã (Chưa kích hoạt)'), findsOneWidget);

      // Thống kê đếm: 1 đã kích hoạt, 1 chờ kích hoạt, 0 chưa cấp mã
      expect(find.text('1'), findsNWidgets(2));

      // Hiển thị danh sách cư dân và mã
      expect(find.text('Nguyễn Văn An'), findsOneWidget);
      expect(find.text('ACT-102948'), findsOneWidget);
      expect(find.text('Trần Thị Bình'), findsOneWidget);

      // Nút tạo mã và xuất CSV
      expect(find.text('Tạo mã cho cư dân mới'), findsOneWidget);
      expect(find.text('Xuất CSV'), findsOneWidget);
    });

    testWidgets('filters resident list based on search query', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Bình');
      await tester.pumpAndSettle();

      expect(find.text('Trần Thị Bình'), findsOneWidget);
      expect(find.text('Nguyễn Văn An'), findsNothing);
    });
  });
}
