import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/core/theme/app_theme.dart';
import 'package:pka_home/data/models/meter_reading_submission_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/meter_reading_provider.dart';
import 'package:pka_home/data/repositories/meter_reading_repository.dart';
import 'package:pka_home/features/management/screens/management_meter_reading_screen.dart';

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
  final adminUser = UserModel(
    id: 'admin-1',
    fullName: 'Ban Quản Trị',
    phone: '0988888888',
    role: 'admin',
  );

  final samplePendingSubmissions = <MeterReadingSubmissionModel>[
    MeterReadingSubmissionModel(
      id: 'sub-p1',
      apartmentId: 'apt-101',
      apartmentCode: 'A0110',
      submittedBy: 'user-res-1',
      submitterName: 'Nguyễn Văn A',
      period: '11/2026',
      electricReading: 155.0,
      waterReading: 42.0,
      status: 'pending',
      createdAt: DateTime(2026, 11, 5, 10, 30),
      updatedAt: DateTime(2026, 11, 5, 10, 30),
    ),
    MeterReadingSubmissionModel(
      id: 'sub-p2',
      apartmentId: 'apt-102',
      apartmentCode: 'A0201',
      submittedBy: 'user-res-2',
      submitterName: 'Trần Thị B',
      period: '11/2026',
      electricReading: 320.0,
      waterReading: 85.0,
      status: 'pending',
      anomalySeverity: 'danger',
      anomalyReason: 'Chỉ số điện tăng vọt gấp 3 lần so với tháng trước (100 kWh)',
      previousElectricReading: 100.0,
      avgElectricUsage: 110.0,
      createdAt: DateTime(2026, 11, 5, 11, 00),
      updatedAt: DateTime(2026, 11, 5, 11, 00),
    ),
  ];

  Widget buildTestApp({
    required double width,
    required double height,
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(adminUser)),
        meterReadingRepositoryProvider.overrideWithValue(FakeMeterReadingRepository()),
        allMeterReadingsProvider('pending').overrideWith((ref) async => samplePendingSubmissions),
        allMeterReadingsProvider('approved').overrideWith((ref) async => []),
        allMeterReadingsProvider('rejected').overrideWith((ref) async => []),
        anomalyMeterReadingsProvider.overrideWith((ref) async => [samplePendingSubmissions[1]]),
        pendingMeterReadingsCountProvider.overrideWith((ref) async => 2),
        pendingAnomalyCountProvider.overrideWith((ref) async => 1),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const ManagementMeterReadingScreen(),
        ),
      ),
    );
  }

  group('ManagementMeterReadingScreen Impeccable Responsive Tests', () {
    testWidgets('renders safely on 320dp narrow mobile with 1.3x text zoom without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(width: 320, height: 600, textScale: 1.3));
      await tester.pumpAndSettle();

      expect(find.text('Duyệt Chỉ Số Điện Nước'), findsOneWidget);
      expect(find.text('Chờ duyệt'), findsOneWidget);
      expect(find.text('Căn hộ A0110'), findsOneWidget);
      expect(find.text('Từ chối'), findsWidgets);
      expect(find.text('Phê duyệt'), findsWidgets);

      // Anti-RenderFlex Guarantee
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Executive KPI Dashboard and multi-column layout at 1200dp desktop width', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(width: 1200, height: 800));
      await tester.pumpAndSettle();

      // Check Executive KPI elements
      expect(find.textContaining('Chờ duyệt'), findsWidgets);
      expect(find.textContaining('Bất thường'), findsWidgets);
      expect(find.text('Căn hộ A0110'), findsOneWidget);
      expect(find.text('Căn hộ A0201'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
