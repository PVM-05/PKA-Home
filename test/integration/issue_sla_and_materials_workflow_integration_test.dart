import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/issue_material_usage_model.dart';
import 'package:pka_home/data/models/issue_model.dart';
import 'package:pka_home/data/models/issue_sla_stats_model.dart';
import 'package:pka_home/data/models/resident_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/management_provider.dart';
import 'package:pka_home/data/providers/material_provider.dart';
import 'package:pka_home/data/providers/role_delegation_provider.dart';
import 'package:pka_home/features/management/screens/issue_management_screen.dart';
import 'package:pka_home/features/resident/screens/issue_detail_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.now();

  final mockIssue = IssueModel(
    id: 'iss-flow-01',
    apartmentId: 'apt-01',
    reporterId: 'usr-res-01',
    description: 'Chập cầu dao tổng phòng khách, mất điện toàn bộ',
    status: 'in_progress',
    priority: 'high',
    category: 'electrical',
    createdAt: now.subtract(const Duration(minutes: 45)),
    slaDeadline: now.add(const Duration(hours: 1, minutes: 15)),
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
      id: 'usr-res-01',
      fullName: 'Hoàng Minh Quân',
      phone: '0912345678',
      role: 'resident',
    ),
  );

  final mockMaterials = [
    IssueMaterialUsageModel(
      id: 'mat-use-01',
      issueReportId: 'iss-flow-01',
      materialId: 'mat-01',
      materialName: 'Aptomat Panasonic 32A',
      quantity: 1,
      unit: 'cái',
      unitPrice: 85000.0,
      totalAmount: 85000.0,
      isChargeable: true,
      note: 'Thay thế át-tô-mát tổng bị cháy cuộn hút',
      createdAt: now.subtract(const Duration(minutes: 10)),
    ),
  ];

  final mockSlaStats = const IssueSlaStatsModel(
    totalIssues: 1,
    onTimeCount: 1,
    warningCount: 0,
    breachedCount: 0,
    complianceRate: 100.0,
  );

  testWidgets('BQL theo dõi SLA sự cố thời gian thực và dải KPI', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(
                UserModel(id: 'usr-admin', fullName: 'BQL Kỹ Thuật', role: 'admin'),
              )),
          activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
          allIssuesProvider.overrideWith((ref) async => [mockIssue]),
          issueSlaStatsProvider.overrideWith((ref) async => mockSlaStats),
          issueMaterialsProvider.overrideWith((ref, issueId) async => mockMaterials),
        ],
        child: const MaterialApp(
          home: IssueManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Kiểm tra tiêu đề và KPI SLA
    expect(find.text('Xử lý Phản ánh'), findsOneWidget);
    expect(find.text('Đúng hạn'), findsWidgets);
    expect(find.text('1 sự cố'), findsWidgets);

    // 2. Kiểm tra thông tin chuyên môn Điện và thời gian SLA đếm ngược trên thẻ sự cố
    expect(find.text('Chập cầu dao tổng phòng khách, mất điện toàn bộ'), findsOneWidget);
    expect(find.text('Điện'), findsWidgets);
    expect(find.textContaining('Còn 1h'), findsWidgets);
  });

  testWidgets('Cư dân đối soát danh sách vật tư kỹ thuật đã xuất kho trên chi tiết sự cố', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(
                UserModel(id: 'usr-res-01', fullName: 'Hoàng Minh Quân', role: 'resident'),
              )),
          activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
          issueMaterialsProvider.overrideWith((ref, issueId) async => mockMaterials),
        ],
        child: MaterialApp(
          home: IssueDetailScreen(issue: mockIssue),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Kiểm tra thông tin Header trên màn hình Cư dân
    expect(find.text('Chập cầu dao tổng phòng khách, mất điện toàn bộ'), findsOneWidget);
    expect(find.text('Điện'), findsWidgets);
    expect(find.text('Đang xử lý'), findsWidgets);

    // 2. Kiểm tra danh mục vật tư kỹ thuật đã xuất kho
    expect(find.text('Vật tư kỹ thuật đã sử dụng'), findsOneWidget);
    expect(find.text('1 mục'), findsOneWidget);
    expect(find.text('Aptomat Panasonic 32A'), findsOneWidget);
    expect(find.textContaining('85.000'), findsWidgets);
    expect(find.text('Tính phí căn hộ'), findsWidgets);
    expect(find.text('Tổng tính vào hóa đơn kỳ tới:'), findsOneWidget);
  });
}
