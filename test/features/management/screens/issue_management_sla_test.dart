import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/issue_model.dart';
import 'package:pka_home/data/models/issue_sla_stats_model.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/resident_model.dart';
import 'package:pka_home/data/providers/management_provider.dart';
import 'package:pka_home/data/providers/material_provider.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/role_delegation_provider.dart';
import 'package:pka_home/features/management/screens/issue_management_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.now();

  final mockIssues = [
    IssueModel(
      id: 'iss-test-01',
      apartmentId: 'apt-01',
      reporterId: 'usr-01',
      description: 'Chập át-tô-mát phòng ngủ',
      status: 'pending',
      priority: 'high',
      category: 'electrical',
      createdAt: now.subtract(const Duration(minutes: 30)),
      slaDeadline: now.add(const Duration(hours: 1, minutes: 30)),
      slaStatus: 'on_time',
      apartment: ApartmentModel(id: 'apt-01', code: 'A0110', buildingCode: 'A', floorNumber: 1, area: 75.0, isEmpty: false),
      reporter: ResidentModel(id: 'usr-01', fullName: 'Nguyễn Văn An', phone: '0901234567', role: 'resident'),
    ),
    IssueModel(
      id: 'iss-test-02',
      apartmentId: 'apt-02',
      reporterId: 'usr-02',
      description: 'Rò rỉ nước bồn rửa chén',
      status: 'in_progress',
      priority: 'high',
      category: 'plumbing',
      createdAt: now.subtract(const Duration(hours: 3)),
      slaDeadline: now.subtract(const Duration(hours: 1)),
      slaStatus: 'breached',
      apartment: ApartmentModel(id: 'apt-02', code: 'A0205', buildingCode: 'A', floorNumber: 2, area: 68.0, isEmpty: false),
      reporter: ResidentModel(id: 'usr-02', fullName: 'Trần Thị Bình', phone: '0909876543', role: 'resident'),
    ),
  ];

  final mockSlaStats = const IssueSlaStatsModel(
    totalIssues: 2,
    onTimeCount: 1,
    warningCount: 0,
    breachedCount: 1,
    complianceRate: 50.0,
  );

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(UserModel(id: 'usr-admin', fullName: 'BQL Kỹ Thuật', role: 'admin'))),
        activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
        allIssuesProvider.overrideWith((ref) async => mockIssues),
        issueSlaStatsProvider.overrideWith((ref) async => mockSlaStats),
      ],
      child: const MaterialApp(
        home: IssueManagementScreen(),
      ),
    );
  }

  testWidgets('IssueManagementScreen hiển thị dải KPI SLA và chip SLA đếm ngược trên thẻ', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // 1. Kiểm tra tiêu đề và bộ lọc
    expect(find.text('Xử lý Phản ánh'), findsOneWidget);

    // 2. Kiểm tra các thẻ KPI SLA
    expect(find.text('Đúng hạn'), findsWidgets);
    expect(find.text('Trễ SLA'), findsWidgets);

    // 3. Kiểm tra thông tin chuyên môn & SLA trên thẻ sự cố
    expect(find.text('Chập át-tô-mát phòng ngủ'), findsOneWidget);
    expect(find.text('Điện'), findsWidgets);
    expect(find.text('Rò rỉ nước bồn rửa chén'), findsOneWidget);
    expect(find.text('Nước'), findsWidgets);

    // Kiểm tra có badge SLA trễ hạn
    expect(find.textContaining('Trễ hạn'), findsWidgets);
  });
}
