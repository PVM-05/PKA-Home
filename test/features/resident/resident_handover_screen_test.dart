import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_handover_model.dart';
import 'package:pka_home/data/models/handover_item_model.dart';
import 'package:pka_home/data/providers/handover_provider.dart';
import 'package:pka_home/data/repositories/handover_repository.dart';
import 'package:pka_home/features/resident/screens/resident_handover_detail_screen.dart';
import 'package:pka_home/features/resident/screens/resident_handover_screen.dart';

void main() {
  group('ResidentHandoverScreen Widget Tests', () {
    late HandoverRepository repository;

    setUp(() {
      repository = HandoverRepository();
    });

    testWidgets('Hiển thị danh sách biên bản bàn giao của cư dân', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            handoverRepositoryProvider.overrideWithValue(repository),
            residentHandoversProvider.overrideWith((ref, residentId) async {
              return [
                ApartmentHandoverModel(
                  id: 'ho-01',
                  apartmentId: 'apt-01',
                  buildingId: 'bld-01',
                  residentId: 'res-01',
                  handoverType: 'move_in',
                  reportCode: 'HO-202611-00001',
                  handoverDate: DateTime.now(),
                  conductedBy: 'staff-01',
                  status: 'pending_resident',
                  lookupCode: 'HK-TEST01',
                  apartmentCode: 'A0110',
                  staffName: 'Trần Kỹ Thuật',
                ),
              ];
            }),
          ],
          child: const MaterialApp(
            home: ResidentHandoverScreen(residentId: 'res-01'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Biên bản bàn giao căn hộ'), findsOneWidget);
      expect(find.text('HO-202611-00001'), findsOneWidget);
      expect(find.text('Nhận nhà (Move-in)'), findsOneWidget);
      expect(find.text('Chờ cư dân ký'), findsOneWidget);
    });

    testWidgets('Màn hình chi tiết ResidentHandoverDetailScreen hiển thị đồ đạc và nút ký xác nhận', (tester) async {
      final mockHandover = ApartmentHandoverModel(
        id: 'ho-01',
        apartmentId: 'apt-01',
        buildingId: 'bld-01',
        residentId: 'res-01',
        handoverType: 'move_out',
        reportCode: 'HO-202611-00001',
        handoverDate: DateTime.now(),
        conductedBy: 'staff-01',
        initialElectricityReading: 1540.0,
        initialWaterReading: 85.0,
        depositHeld: 10000000.0,
        totalDeduction: 1200000.0,
        depositRefund: 8800000.0,
        status: 'pending_resident',
        lookupCode: 'HK-TEST01',
        apartmentCode: 'A0110',
        staffName: 'Trần Kỹ Thuật',
        items: [
          const HandoverItemModel(
            id: 'item-01',
            handoverId: 'ho-01',
            itemName: 'Điều hòa Daikin 1.5HP',
            roomArea: 'bedroom',
            condition: 'good',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            handoverRepositoryProvider.overrideWithValue(repository),
            handoverDetailProvider.overrideWith((ref, id) async => mockHandover),
          ],
          child: const MaterialApp(
            home: ResidentHandoverDetailScreen(handoverId: 'ho-01'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Chi tiết biên bản bàn giao'), findsOneWidget);
      expect(find.text('Điều hòa Daikin 1.5HP'), findsOneWidget);
      expect(find.text('Chỉ số điện: 1540.0 kWh'), findsOneWidget);
      expect(find.text('Ký tên xác nhận'), findsOneWidget);
      expect(find.text('Có ý kiến / Khiếu nại'), findsOneWidget);
    });
  });
}

