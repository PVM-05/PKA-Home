import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/co_residents_provider.dart';
import 'package:vivona/data/providers/resident_apartment_provider.dart';
import 'package:vivona/features/resident/screens/resident_profile_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testUser = UserModel(
    id: 'user-res-1',
    fullName: 'Nguyễn Văn Cư Dân',
    phone: '0987654321',
    role: 'resident',
  );

  final testApartments = [
    {
      'apartment_id': 'apt-101',
      'relation_role': 'owner',
      'apartments': {
        'id': 'apt-101',
        'code': 'A0110',
        'area': 75.5,
      },
    },
  ];

  final testCoResidents = [
    {
      'relation_role': 'owner',
      'users': {
        'full_name': 'Nguyễn Văn Cư Dân',
        'phone': '0987654321',
      },
    },
    {
      'relation_role': 'tenant',
      'users': {
        'full_name': 'Trần Thị Thuê Nhà',
        'phone': '0912345678',
      },
    },
  ];

  Widget buildTestWidget({required Size screenSize, double textScale = 1.0}) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
        residentApartmentsProvider.overrideWith((ref) => Future.value(testApartments)),
        coResidentsProvider('apt-101').overrideWith((ref) => Future.value(testCoResidents)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: screenSize,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const ResidentProfileScreen(),
        ),
      ),
    );
  }

  testWidgets('ResidentProfileScreen renders safely on narrow 320dp mobile with 1.3x text zoom', (tester) async {
    tester.view.physicalSize = const Size(320 * 2, 600 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget(screenSize: const Size(320, 600), textScale: 1.3));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tài khoản của tôi'), findsOneWidget);
    expect(find.text('Nguyễn Văn Cư Dân'), findsWidgets);
    expect(find.text('Căn hộ A0110'), findsOneWidget);
  });

  testWidgets('ResidentProfileScreen renders centered and constrained on enterprise desktop 1200dp', (tester) async {
    tester.view.physicalSize = const Size(1200 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestWidget(screenSize: const Size(1200, 800)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tài khoản của tôi'), findsOneWidget);
    expect(find.text('Cài đặt & Bảo mật'), findsOneWidget);
  });
}
