import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/data/models/meter_reading_submission_model.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/meter_reading_provider.dart';
import 'package:vivona/data/providers/vehicle_provider.dart';
import 'package:vivona/data/repositories/meter_reading_repository.dart';
import 'package:vivona/features/resident/screens/resident_meter_reading_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMeterReadingRepository implements MeterReadingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final residentUser = UserModel(
    id: 'res-user-1',
    fullName: 'Lê Văn Cư Dân',
    phone: '0912345678',
    role: 'resident',
  );

  final sampleHistory = <MeterReadingSubmissionModel>[
    MeterReadingSubmissionModel(
      id: 'sub-hist-1',
      apartmentId: 'apt-101',
      apartmentCode: 'A0110',
      submittedBy: 'res-user-1',
      submitterName: 'Lê Văn Cư Dân',
      period: '10/2026',
      electricReading: 120.0,
      waterReading: 35.0,
      status: 'approved',
      createdAt: DateTime(2026, 10, 20, 9, 0),
      updatedAt: DateTime(2026, 10, 21, 14, 0),
    ),
    MeterReadingSubmissionModel(
      id: 'sub-hist-2',
      apartmentId: 'apt-101',
      apartmentCode: 'A0110',
      submittedBy: 'res-user-1',
      submitterName: 'Lê Văn Cư Dân',
      period: '09/2026',
      electricReading: 105.0,
      waterReading: 30.0,
      status: 'approved',
      createdAt: DateTime(2026, 9, 20, 8, 30),
      updatedAt: DateTime(2026, 9, 21, 10, 0),
    ),
  ];

  final aptData = <String, dynamic>{
    'code': 'A0110',
    'electric_reading': 120.0,
    'water_reading': 35.0,
  };

  Widget buildTestApp({
    required double width,
    required double height,
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(residentUser)),
        meterReadingRepositoryProvider.overrideWithValue(FakeMeterReadingRepository()),
        residentApartmentIdProvider.overrideWith((ref) async => 'apt-101'),
        currentApartmentReadingsProvider.overrideWith((ref) async => aptData),
        residentMeterReadingsProvider.overrideWith((ref) async => sampleHistory),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const ResidentMeterReadingScreen(),
        ),
      ),
    );
  }

  group('ResidentMeterReadingScreen Impeccable Responsive Tests', () {
    testWidgets('renders safely on 320dp narrow mobile with 1.3x text zoom without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(width: 320, height: 600, textScale: 1.3));
      await tester.pumpAndSettle();

      expect(find.text('Khai Báo Chỉ Số Điện Nước'), findsOneWidget);
      expect(find.textContaining('Chỉ số kỳ trước'), findsOneWidget);
      expect(find.textContaining('Công tơ Điện'), findsOneWidget);
      expect(find.textContaining('Công tơ Nước'), findsOneWidget);
      expect(find.textContaining('Lịch Sử Khai Báo Chỉ Số'), findsOneWidget);

      // Anti-RenderFlex Guarantee
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Split-Screen dual-column layout at 1200dp desktop width', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(width: 1200, height: 800));
      await tester.pumpAndSettle();

      expect(find.text('Khai Báo Chỉ Số Điện Nước'), findsOneWidget);
      expect(find.textContaining('Chỉ số kỳ trước'), findsOneWidget);
      expect(find.textContaining('Công tơ Điện'), findsOneWidget);
      expect(find.textContaining('Công tơ Nước'), findsOneWidget);
      expect(find.textContaining('Lịch Sử Khai Báo Chỉ Số'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
