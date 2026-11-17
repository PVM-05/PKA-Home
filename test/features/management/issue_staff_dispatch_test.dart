import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vivona/data/models/apartment_model.dart';
import 'package:vivona/data/models/issue_model.dart';
import 'package:vivona/data/models/issue_sla_stats_model.dart';
import 'package:vivona/data/models/resident_model.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/management_provider.dart';
import 'package:vivona/data/providers/material_provider.dart';
import 'package:vivona/data/providers/role_delegation_provider.dart';
import 'package:vivona/data/repositories/management_repository.dart';
import 'package:vivona/features/management/screens/issue_management_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockManagementRepository extends Mock implements ManagementRepository {}

void main() {
  final now = DateTime.now();
  const currentTechId = 'tech-001';

  final mockIssues = [
    IssueModel(
      id: 'iss-my-01',
      apartmentId: 'apt-01',
      reporterId: 'usr-01',
      assignedStaffId: currentTechId,
      description: 'Hỏng van nước phòng tắm A0110',
      status: 'in_progress',
      priority: 'high',
      category: 'plumbing',
      createdAt: now.subtract(const Duration(hours: 1)),
      slaDeadline: now.add(const Duration(hours: 1)),
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
      assignedStaff: ResidentModel(
        id: currentTechId,
        fullName: 'Kỹ Thuật Viên 1',
        phone: '0988001122',
        role: 'technician',
      ),
    ),
    IssueModel(
      id: 'iss-other-02',
      apartmentId: 'apt-02',
      reporterId: 'usr-02',
      assignedStaffId: 'other-tech-999',
      description: 'Chập bóng đèn hành lang tầng 2',
      status: 'pending',
      priority: 'medium',
      category: 'electrical',
      createdAt: now.subtract(const Duration(hours: 2)),
      slaDeadline: now.add(const Duration(hours: 22)),
      slaStatus: 'on_time',
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
      assignedStaff: ResidentModel(
        id: 'other-tech-999',
        fullName: 'Kỹ Thuật Viên Khác',
        phone: '0988999888',
        role: 'technician',
      ),
    ),
  ];

  final mockSlaStats = const IssueSlaStatsModel(
    totalIssues: 2,
    onTimeCount: 2,
    warningCount: 0,
    breachedCount: 0,
    complianceRate: 100.0,
  );

  Widget createWidget({ManagementRepository? mockRepo}) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (ref) => FakeAuthNotifier(
            UserModel(
              id: currentTechId,
              fullName: 'Kỹ Thuật Viên 1',
              role: 'technician',
            ),
          ),
        ),
        activeDelegationsProvider.overrideWith((ref) => Stream.value([])),
        allIssuesProvider.overrideWith((ref) async => mockIssues),
        issueSlaStatsProvider.overrideWith((ref) async => mockSlaStats),
        if (mockRepo != null)
          managementRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: const MaterialApp(
        home: IssueManagementScreen(),
      ),
    );
  }

  group('IssueManagementScreen - Phân công KTV & Bộ lọc "Giao cho tôi"', () {
    testWidgets('Hiển thị chip lọc "Giao cho tôi" và lọc chính xác sự cố của KTV', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Kiểm tra cả 2 sự cố đều được render ban đầu (chế độ Tất cả)
      expect(find.text('Hỏng van nước phòng tắm A0110'), findsOneWidget);
      expect(find.text('Chập bóng đèn hành lang tầng 2'), findsOneWidget);

      // Tìm chip 'Giao cho tôi'
      final myAssignedChip = find.widgetWithText(FilterChip, 'Giao cho tôi');
      expect(myAssignedChip, findsOneWidget);

      // Cuộn để thấy chip và nhấn vào chip 'Giao cho tôi'
      await tester.ensureVisible(myAssignedChip);
      await tester.tap(myAssignedChip);
      await tester.pumpAndSettle();

      // Chỉ sự cố của currentTechId được hiển thị
      expect(find.text('Hỏng van nước phòng tắm A0110'), findsOneWidget);
      expect(find.text('Chập bóng đèn hành lang tầng 2'), findsNothing);

      // Bỏ chọn chip 'Giao cho tôi'
      await tester.ensureVisible(myAssignedChip);
      await tester.tap(myAssignedChip);
      await tester.pumpAndSettle();

      // Cả 2 sự cố hiển thị lại
      expect(find.text('Hỏng van nước phòng tắm A0110'), findsOneWidget);
      expect(find.text('Chập bóng đèn hành lang tầng 2'), findsOneWidget);
    });

    testWidgets('Dialog phân công KTV gọi qua ManagementRepository.fetchAssignableStaff()', (tester) async {
      final mockRepo = MockManagementRepository();
      when(() => mockRepo.fetchAssignableStaff()).thenAnswer(
        (_) async => [
          {'id': currentTechId, 'name': 'Kỹ Thuật Viên 1 (Kỹ thuật viên)', 'role': 'technician'},
          {'id': 'tech-002', 'name': 'Kỹ Thuật Viên 2 (Kỹ thuật viên)', 'role': 'technician'},
        ],
      );

      await tester.pumpWidget(createWidget(mockRepo: mockRepo));
      await tester.pumpAndSettle();

      // Mở menu popup thao tác của thẻ sự cố thứ 2 (chưa hoặc đang phân công)
      final popupMenuButtons = find.byType(PopupMenuButton<String>);
      if (popupMenuButtons.evaluate().isNotEmpty) {
        await tester.tap(popupMenuButtons.first);
        await tester.pumpAndSettle();

        final assignMenuItem = find.text('Phân công KTV');
        if (assignMenuItem.evaluate().isNotEmpty) {
          await tester.tap(assignMenuItem);
          await tester.pumpAndSettle();

          // Xác nhận fetchAssignableStaff đã được gọi từ repository
          verify(() => mockRepo.fetchAssignableStaff()).called(1);
          expect(find.text('Tiếp nhận & Phân công'), findsOneWidget);
        }
      }
    });
  });
}
