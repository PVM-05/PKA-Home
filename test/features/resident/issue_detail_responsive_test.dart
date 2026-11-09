import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/apartment_model.dart';
import 'package:pka_home/data/models/issue_comment_model.dart';
import 'package:pka_home/data/models/issue_material_usage_model.dart';
import 'package:pka_home/data/models/issue_model.dart';
import 'package:pka_home/data/models/issue_rating_model.dart';
import 'package:pka_home/data/models/resident_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/issue_comment_provider.dart';
import 'package:pka_home/data/providers/issue_rating_provider.dart';
import 'package:pka_home/data/providers/material_provider.dart';
import 'package:pka_home/features/resident/screens/issue_detail_screen.dart';

class _FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  _FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.now();

  final mockIssue = IssueModel(
    id: 'iss-detail-01',
    apartmentId: 'apt-01',
    reporterId: 'usr-res-01',
    description: 'Chập cầu dao tổng phòng khách, mất điện toàn bộ căn hộ gây gián đoạn sinh hoạt',
    status: 'resolved',
    priority: 'high',
    category: 'electrical',
    createdAt: now.subtract(const Duration(days: 2)),
    updatedAt: now.subtract(const Duration(days: 1)),
    slaDeadline: now.subtract(const Duration(days: 1, hours: 2)),
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
    assignedStaff: ResidentModel(
      id: 'usr-staff-01',
      fullName: 'Trần Kỹ Thuật',
      phone: '0987654321',
      role: 'technical',
    ),
    imageUrls: const [],
  );

  final mockMaterials = [
    IssueMaterialUsageModel(
      id: 'mat-01',
      issueReportId: 'iss-detail-01',
      materialId: 'm-01',
      materialName: 'Aptomat Panasonic 32A',
      quantity: 1,
      unit: 'cái',
      unitPrice: 85000,
      totalAmount: 85000,
      isChargeable: true,
      note: 'Thay át tổng',
      createdAt: now.subtract(const Duration(days: 1)),
    ),
  ];

  final mockComments = <IssueCommentModel>[
    IssueCommentModel(
      id: 'cmt-01',
      issueReportId: 'iss-detail-01',
      userId: 'usr-staff-01',
      userName: 'Trần Kỹ Thuật',
      userRole: 'technician',
      content: 'Chào anh, tôi đã có mặt tại căn hộ và đang tiến hành kiểm tra tủ điện.',
      createdAt: now.subtract(const Duration(hours: 3)),
    ),
    IssueCommentModel(
      id: 'cmt-02',
      issueReportId: 'iss-detail-01',
      userId: 'usr-res-01',
      userName: 'Hoàng Minh Quân',
      userRole: 'resident',
      content: 'Cảm ơn anh, nhờ anh kiểm tra kỹ xem có bị chập ngầm trong tường không nhé.',
      createdAt: now.subtract(const Duration(hours: 2)),
    ),
  ];

  final mockRating = IssueRatingModel(
    id: 'rate-01',
    issueReportId: 'iss-detail-01',
    reporterId: 'usr-res-01',
    overallRating: 5.0,
    speedRating: 5,
    attitudeRating: 5,
    qualityRating: 5,
    comment: 'Kỹ thuật viên nhiệt tình, xử lý nhanh và chuyên nghiệp.',
    createdAt: now.subtract(const Duration(hours: 1)),
  );

  Widget createWidget({required IssueModel issue}) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith(
          (ref) => _FakeAuthNotifier(
            UserModel(
              id: 'usr-res-01',
              fullName: 'Hoàng Minh Quân',
              role: 'resident',
            ),
          ),
        ),
        issueMaterialsProvider.overrideWith(
          (ref, issueId) async => mockMaterials,
        ),
        issueCommentsProvider.overrideWith(
          (ref, issueId) => Stream.value(mockComments),
        ),
        issueRatingProvider.overrideWith(
          (ref, issueId) async => mockRating,
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: IssueDetailScreen(issue: issue),
      ),
    );
  }

  group('IssueDetailScreen Responsive & Impeccable Tests', () {
    testWidgets('renders desktop/tablet layout at 1000dp width cleanly without overflow', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidget(issue: mockIssue));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết phản ánh'), findsOneWidget);
      expect(find.textContaining('Chập cầu dao tổng phòng khách'), findsOneWidget);
      expect(find.text('Vật tư kỹ thuật đã sử dụng'), findsOneWidget);
      expect(find.text('Trao đổi'), findsOneWidget);
      expect(find.text('Đánh giá dịch vụ'), findsOneWidget);
    });

    testWidgets('renders narrow mobile 320dp width with 1.3x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await tester.pumpWidget(createWidget(issue: mockIssue));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết phản ánh'), findsOneWidget);
      expect(find.textContaining('Chập cầu dao tổng'), findsOneWidget);
    });
  });
}
