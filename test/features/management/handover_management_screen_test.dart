import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_handover_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/handover_provider.dart';
import 'package:pka_home/data/repositories/handover_repository.dart';
import 'package:pka_home/features/management/screens/handover_management_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHandoverRepository extends Fake implements HandoverRepository {
  @override
  Future<List<ApartmentHandoverModel>> fetchHandoversByBuilding(
    String buildingId, {
    String? status,
    String? type,
  }) async =>
      [];
}

void main() {
  group('HandoverManagementScreen Widget Tests', () {
    final adminUser = UserModel(
      id: 'admin-01',
      fullName: 'Quản Lý Trưởng',
      role: 'admin',
    );

    testWidgets('Hiển thị tiêu đề, dải KPI và danh sách biên bản', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(adminUser)),
            handoverRepositoryProvider.overrideWithValue(FakeHandoverRepository()),
            buildingHandoversProvider.overrideWith((ref, buildingId) async {
              return [
                ApartmentHandoverModel(
                  id: 'ho-01',
                  apartmentId: 'apt-01',
                  buildingId: 'bld-01',
                  residentId: 'res-01',
                  handoverType: 'move_out',
                  reportCode: 'HO-202611-00001',
                  handoverDate: DateTime.now(),
                  conductedBy: 'staff-01',
                  depositHeld: 10000000.0,
                  totalDeduction: 1200000.0,
                  depositRefund: 8800000.0,
                  status: 'pending_resident',
                  lookupCode: 'HK-TEST01',
                  apartmentCode: 'A0110',
                  residentName: 'Nguyễn Văn An',
                  staffName: 'Trần Kỹ Thuật',
                ),
              ];
            }),
          ],
          child: const MaterialApp(
            home: HandoverManagementScreen(buildingId: 'bld-01'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Quản lý bàn giao & kiểm kê'), findsOneWidget);
      expect(find.text('HO-202611-00001'), findsOneWidget);
      expect(find.text('Căn hộ: A0110'), findsOneWidget);
      expect(find.text('Trả nhà (Move-out)'), findsOneWidget);
      expect(find.text('Chờ cư dân ký'), findsOneWidget);
      expect(find.text('Tạo biên bản mới'), findsOneWidget);
    });
  });
}

