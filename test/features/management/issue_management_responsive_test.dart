import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/data/models/apartment_model.dart';
import 'package:vivona/data/models/issue_model.dart';
import 'package:vivona/data/models/issue_sla_stats_model.dart';
import 'package:vivona/data/models/resident_model.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/management_provider.dart';
import 'package:vivona/data/providers/material_provider.dart';
import 'package:vivona/data/providers/role_delegation_provider.dart';
import 'package:vivona/features/management/screens/issue_management_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.now();

  final mockAdmin = UserModel(
    id: 'usr-admin-1',
    fullName: 'Trưởng BQL PKA',
    role: 'admin',
  );

  final mockIssues = [
    IssueModel(
      id: 'iss-test-01',
      apartmentId: 'apt-01',
      reporterId: 'usr-01',
      description: 'Chập át-tô-mát phòng ngủ gây mất điện toàn bộ căn hộ cần kiểm tra khẩn cấp',
      status: 'pending',
      priority: 'high',
      category: 'electrical',
      createdAt: now.subtract(const Duration(minutes: 30)),
      slaDeadline: now.add(const Duration(hours: 1, minutes: 30)),
      slaStatus: 'on_time',
      apartment: ApartmentModel(
        id: 'apt-01',
        code: 'A0110',
        buildingCode: 'A',
        floorNumber: 1,
        area: 75.0,
        isEmpty: false,
      ),
      reporter: ResidentModel(
        id: 'usr-01',
        fullName: 'Nguyễn Văn An',
        phone: '0901234567',
        role: 'resident',
      ),
    ),
    IssueModel(
      id: 'iss-test-02',
      apartmentId: 'apt-02',
      reporterId: 'usr-02',
      description: 'Rò rỉ đường ống nước bồn rửa chén tầng dưới bị thấm trần',
      status: 'in_progress',
      priority: 'medium',
      category: 'plumbing',
      createdAt: now.subtract(const Duration(hours: 3)),
      slaDeadline: now.subtract(const Duration(hours: 1)),
      slaStatus: 'breached',
      apartment: ApartmentModel(
        id: 'apt-02',
        code: 'A0205',
        buildingCode: 'A',
        floorNumber: 2,
        area: 68.0,
        isEmpty: false,
      ),
      reporter: ResidentModel(
        id: 'usr-02',
        fullName: 'Trần Thị Bình',
        phone: '0909876543',
        role: 'resident',
      ),
    ),
  ];

  const mockSlaStats = IssueSlaStatsModel(
    totalIssues: 2,
    onTimeCount: 1,
    warningCount: 0,
    breachedCount: 1,
    complianceRate: 50.0,
  );

  Widget buildIssueManagementApp({
    required double width,
    required double height,
    double textScaleFactor = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(mockAdmin)),
        activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
        allIssuesProvider.overrideWith((ref) async => mockIssues),
        issueSlaStatsProvider.overrideWith((ref) async => mockSlaStats),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: const IssueManagementScreen(),
        ),
      ),
    );
  }

  group('IssueManagementScreen Responsive Tests', () {
    testWidgets('renders desktop layout at 1000dp width without overflow', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildIssueManagementApp(width: 1000, height: 800));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Xử lý Phản ánh'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp width without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildIssueManagementApp(width: 320, height: 640));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Xử lý Phản ánh'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp with 1.3x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildIssueManagementApp(
        width: 320,
        height: 700,
        textScaleFactor: 1.3,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Xử lý Phản ánh'), findsOneWidget);
    });
  });
}

