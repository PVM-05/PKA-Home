import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/models/issue_model.dart';
import 'package:vivona/data/models/payment_transaction_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/role_delegation_provider.dart';
import 'package:vivona/data/providers/dashboard_providers.dart';
import 'package:vivona/data/providers/management_provider.dart';
import 'package:vivona/data/providers/notification_provider.dart';
import 'package:vivona/data/providers/payment_provider.dart';
import 'package:vivona/data/providers/meter_reading_provider.dart';
import 'package:vivona/features/management/screens/management_home_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final adminUser = UserModel(
    id: 'cefe60f0-571b-4b5c-a924-8081a5fcf05a',
    fullName: 'Nguyễn Văn An Quản Trị Viên',
    phone: '0901234567',
    role: 'admin',
  );

  final testUrgentIssue = IssueModel(
    id: 'iss-urgent-1',
    apartmentId: 'apt-1',
    reporterId: 'user-1',
    description: 'Chập điện khẩn cấp tại phòng kỹ thuật tầng 12',
    status: 'pending',
    priority: 'high',
    createdAt: DateTime(2026, 11, 8),
  );

  Widget buildTestApp({
    required double width,
    required double height,
    double textScaleFactor = 1.0,
    List<IssueModel> issues = const [],
    int pendingConfirmations = 0,
    int pendingLinks = 0,
    int pendingMeters = 0,
  }) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(adminUser)),
        activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
        pendingLinkRequestsCountProvider.overrideWith((ref) => Stream.value(pendingLinks)),
        pendingConfirmationInvoicesProvider.overrideWith((ref) => Stream.value(pendingConfirmations)),
        pendingIssuesCountProvider.overrideWith((ref) => Stream.value(issues.length)),
        pendingMeterReadingsCountProvider.overrideWith((ref) async => pendingMeters),
        rawIssuesStreamProvider.overrideWith((ref) => Stream.value([])),
        notificationsStreamProvider.overrideWith((ref) => Stream.value([])),
        allIssuesProvider.overrideWith((ref) async => issues),
        totalResidentsProvider.overrideWith((ref) => Stream.value(142)),
        totalApartmentsProvider.overrideWithValue(const AsyncValue.data(150)),
        occupancyRateProvider.overrideWithValue(const AsyncValue.data(0.946)),
        apartmentsStreamProvider.overrideWith((ref) => Stream.value([])),
        financialStatsProvider.overrideWith((ref) => Stream.value(FinancialStats(
          paidTotal: 185000000.0,
          unpaidTotal: 14200000.0,
          paidCount: 135,
          unpaidCount: 15,
        ))),
        monthlyRevenueTrendProvider.overrideWith((ref) => Stream.value([])),
        paymentTransactionsProvider.overrideWith((ref) async => <PaymentTransactionModel>[]),
        residentsProvider.overrideWith((ref) async => []),
        apartmentsProvider.overrideWith((ref) async => []),
        invoicesProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: const ManagementHomeScreen(),
        ),
      ),
    );
  }

  group('ManagementHomeScreen Responsive & Anti-Overflow Tests', () {
    testWidgets('renders desktop workstation at width 1440dp in 2-column command center mode without overflow', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(
        width: 1440,
        height: 900,
        issues: [testUrgentIssue],
        pendingConfirmations: 3,
        pendingLinks: 2,
        pendingMeters: 4,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('Thao tác nhanh'), findsOneWidget);
      expect(find.text('Cư dân & Căn hộ — Tổng quan trạng thái'), findsOneWidget);
      expect(find.text('Tài chính & Thu phí'), findsOneWidget);
    });

    testWidgets('renders mobile dashboard at narrow width 320dp without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(width: 320, height: 640));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('Thao tác nhanh'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp with font zoom 1.3x and active urgent work items without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 750);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(
        width: 320,
        height: 750,
        textScaleFactor: 1.3,
        issues: [testUrgentIssue],
        pendingConfirmations: 5,
        pendingLinks: 3,
        pendingMeters: 7,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('Thao tác nhanh'), findsOneWidget);
      expect(find.text('Công việc cần xử lý ngay • Phản ánh cần xử lý gấp'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Xem ngay'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Đối soát'), findsOneWidget);
    });
  });
}
