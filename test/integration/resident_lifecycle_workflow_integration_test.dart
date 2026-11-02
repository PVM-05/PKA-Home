import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/resident_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/link_request_provider.dart';
import 'package:pka_home/data/providers/resident_lifecycle_provider.dart';
import 'package:pka_home/data/repositories/resident_lifecycle_repository.dart';
import 'package:pka_home/features/management/widgets/resident_360_detail_sheet.dart';
import 'package:pka_home/features/management/widgets/apartment_contract_sheet.dart';
import 'package:pka_home/features/resident/screens/link_request_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeResidentLinkNotifier extends StateNotifier<ResidentLinkStatus> implements ResidentLinkNotifier {
  FakeResidentLinkNotifier() : super(ResidentLinkStatus(status: LinkStatus.none));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLifecycleRepo extends ResidentLifecycleRepository {
  @override
  Future<List<ResidentLeaseContractModel>> fetchApartmentContracts(String apartmentId) async {
    return [
      ResidentLeaseContractModel(
        id: 'c-01',
        userId: 'u-01',
        apartmentId: apartmentId,
        fullName: 'Le Van Test',
        phone: '0901112233',
        relationRole: 'owner',
        status: 'active',
        startDate: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }
}

void main() {
  final residentUser = UserModel(
    id: 'res-user-1',
    fullName: 'Cư dân Test',
    phone: '0909999999',
    role: 'resident',
  );

  testWidgets('LinkRequestScreen hien thi nut Gia nhap bang ma moi tu phuc vu', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(residentUser)),
          residentLinkProvider.overrideWith((ref) => FakeResidentLinkNotifier()),
          availableApartmentsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: LinkRequestScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Gia nhập bằng mã mời (Tự phục vụ)'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
  });

  testWidgets('Resident360DetailSheet hien thi nut Xem hop dong va mo ApartmentContractSheet', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final resident = ResidentModel(
      id: 'res-01',
      fullName: 'Tran Thi B',
      phone: '0912345678',
      role: 'resident',
      isLocked: false,
      apartment: ApartmentModel(
        id: 'apt-01',
        code: 'A0101',
        area: 75.0,
        floorNumber: 1,
        buildingCode: 'A',
      ),
      apartments: [
        ResidentApartmentLink(
          apartmentId: 'apt-01',
          apartmentCode: 'A0101',
          relationRole: 'owner',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          residentLifecycleRepositoryProvider.overrideWithValue(MockLifecycleRepo()),
          apartmentContractsProvider('apt-01').overrideWith((ref) => Future.value([])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Resident360DetailSheet(resident: resident),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final contractBtn = find.text('Xem hợp đồng & lưu trú');
    expect(contractBtn, findsOneWidget);

    await tester.tap(contractBtn);
    await tester.pumpAndSettle();

    expect(find.byType(ApartmentContractSheet), findsOneWidget);
  });
}
