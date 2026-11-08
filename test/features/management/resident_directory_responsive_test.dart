import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/models/resident_model.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/management_provider.dart';
import 'package:pka_home/data/providers/dashboard_providers.dart';
import 'package:pka_home/data/providers/role_delegation_provider.dart';
import 'package:pka_home/features/management/screens/resident_management_screen.dart';
import 'package:pka_home/features/management/screens/apartment_management_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testAdmin = UserModel(
    id: 'admin-1',
    fullName: 'Trưởng BQL PKA',
    role: 'admin',
  );

  final mockApartments = [
    ApartmentModel(
      id: 'apt-1',
      code: 'A0110',
      buildingCode: 'A',
      floorNumber: 1,
      area: 75.0,
      isEmpty: false,
    ),
    ApartmentModel(
      id: 'apt-2',
      code: 'A0210',
      buildingCode: 'A',
      floorNumber: 2,
      area: 85.0,
      isEmpty: true,
    ),
    ApartmentModel(
      id: 'apt-3',
      code: 'B0502',
      buildingCode: 'B',
      floorNumber: 5,
      area: 68.5,
      isEmpty: false,
    ),
  ];

  final mockResidents = [
    ResidentModel(
      id: 'res-1',
      fullName: 'Nguyễn Văn Cư Dân',
      email: 'nguyen.van.a@pka-home.vn',
      phone: '0901234567',
      role: 'resident',
      isActive: true,
      isLocked: false,
      apartment: mockApartments[0],
    ),
    ResidentModel(
      id: 'res-2',
      fullName: 'Trần Thị Thuê Nhà',
      email: 'tran.thi.b@pka-home.vn',
      phone: '0909876543',
      role: 'resident',
      isActive: false,
      isLocked: true,
      apartment: null,
    ),
    ResidentModel(
      id: 'res-3',
      fullName: 'Phạm Kỹ Thuật Viên',
      email: 'pham.kythuat@pka-home.vn',
      phone: '0912345678',
      role: 'technician',
      isActive: true,
      isLocked: false,
      apartment: null,
    ),
  ];

  Widget buildResidentManagementApp({
    required double width,
    required double height,
    double textScaleFactor = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testAdmin)),
        activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
        residentsProvider.overrideWith((ref) async => mockResidents),
        apartmentsProvider.overrideWith((ref) async => mockApartments),
        pendingLinkRequestsCountProvider.overrideWith((ref) => Stream.value(2)),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: const ResidentManagementScreen(),
        ),
      ),
    );
  }

  Widget buildApartmentManagementApp({
    required double width,
    required double height,
    double textScaleFactor = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testAdmin)),
        activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
        apartmentsProvider.overrideWith((ref) async => mockApartments),
        residentsProvider.overrideWith((ref) async => mockResidents),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: const ApartmentManagementScreen(),
        ),
      ),
    );
  }

  group('ResidentManagementScreen Responsive Tests', () {
    testWidgets('renders desktop layout at 1000dp width without overflow', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildResidentManagementApp(width: 1000, height: 800));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Quản lý Cư dân'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp width without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildResidentManagementApp(width: 320, height: 640));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Quản lý Cư dân'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp with 1.3x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildResidentManagementApp(
        width: 320,
        height: 700,
        textScaleFactor: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Quản lý Cư dân'), findsOneWidget);
    });
  });

  group('ApartmentManagementScreen Responsive Tests', () {
    testWidgets('renders desktop layout at 1000dp width without overflow', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApartmentManagementApp(width: 1000, height: 800));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Quản lý Căn hộ'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp width without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApartmentManagementApp(width: 320, height: 640));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Quản lý Căn hộ'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp with 1.3x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApartmentManagementApp(
        width: 320,
        height: 700,
        textScaleFactor: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Quản lý Căn hộ'), findsOneWidget);
    });
  });
}

