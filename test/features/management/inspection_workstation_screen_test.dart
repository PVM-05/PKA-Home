import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_asset_model.dart';
import 'package:pka_home/data/providers/handover_provider.dart';
import 'package:pka_home/data/repositories/handover_repository.dart';
import 'package:pka_home/features/management/screens/inspection_workstation_screen.dart';

void main() {
  group('InspectionWorkstationScreen Widget Tests', () {
    late HandoverRepository repository;

    setUp(() {
      repository = HandoverRepository(null, true);
    });

    testWidgets('Hiển thị form kiểm kê hiện trường, chốt chỉ số và danh sách tài sản', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            handoverRepositoryProvider.overrideWithValue(repository),
            apartmentAssetsProvider.overrideWith((ref, apartmentId) async {
              return [
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
            }),
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
      expect(find.text('Chỉ số điện (kWh)'), findsOneWidget);
      expect(find.text('Chỉ số nước (m³)'), findsOneWidget);
      expect(find.text('Khóa cửa thông minh vân tay'), findsOneWidget);
      expect(find.text('Ký tên BQL'), findsOneWidget);
    });
  });
}
