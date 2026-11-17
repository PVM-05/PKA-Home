import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/apartment_asset_model.dart';
import 'package:vivona/data/models/apartment_handover_model.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/handover_provider.dart';
import 'package:vivona/data/repositories/handover_repository.dart';
import 'package:vivona/features/management/screens/inspection_workstation_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHandoverRepository extends Fake implements HandoverRepository {
  final List<ApartmentAssetModel> assets;
  final ApartmentHandoverModel? handoverDetail;

  FakeHandoverRepository({this.assets = const [], this.handoverDetail});

  @override
  Future<List<ApartmentAssetModel>> fetchAssetsByApartment(String apartmentId) async => assets;

  @override
  Future<ApartmentHandoverModel?> fetchHandoverDetail(String handoverId) async => handoverDetail;
}

void main() {
  group('InspectionWorkstationScreen Widget Tests', () {
    final adminUser = UserModel(
      id: 'admin-01',
      fullName: 'Quản Lý Trưởng',
      role: 'admin',
    );

    final mockAssets = [
      const ApartmentAssetModel(
        id: 'asset-01',
        apartmentId: 'apt-01',
        buildingId: 'bld-01',
        roomArea: 'living_room',
        name: 'Khóa cửa thông minh vân tay',
        quantity: 1,
        condition: 'good',
        replacementPrice: 3500000.0,
      ),
    ];

    testWidgets('Hiển thị form kiểm kê hiện trường, chốt chỉ số và danh sách tài sản', (tester) async {
      final repository = FakeHandoverRepository(assets: mockAssets);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(adminUser)),
            handoverRepositoryProvider.overrideWithValue(repository),
            apartmentAssetsProvider.overrideWith((ref, apartmentId) async => mockAssets),
          ],
          child: const MaterialApp(
            home: InspectionWorkstationScreen(
              buildingId: 'bld-01',
              apartmentId: 'apt-01',
              apartmentCode: 'A0110',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Trạm kiểm kê & bàn giao'), findsOneWidget);
      expect(find.text('Căn hộ A0110'), findsOneWidget);
      expect(find.textContaining('Chỉ số điện (kWh)'), findsOneWidget);
      expect(find.textContaining('Chỉ số nước (m³)'), findsOneWidget);
      expect(find.text('Khóa cửa thông minh vân tay'), findsOneWidget);
      expect(find.text('Ký tên BQL'), findsOneWidget);
    });

    testWidgets('Khóa chỉnh sửa và hiển thị huy hiệu bất biến khi isReadOnly = true', (tester) async {
      final repository = FakeHandoverRepository(assets: []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(adminUser)),
            handoverRepositoryProvider.overrideWithValue(repository),
            apartmentAssetsProvider.overrideWith((ref, apartmentId) async => []),
          ],
          child: const MaterialApp(
            home: InspectionWorkstationScreen(
              buildingId: 'bld-01',
              apartmentId: 'apt-01',
              apartmentCode: 'A0110',
              isReadOnly: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Đã duyệt (Bất biến)'), findsOneWidget);
      expect(find.text('Gửi cư dân'), findsNothing);
      expect(find.text('Ký tên BQL'), findsNothing);
    });
  });
}

