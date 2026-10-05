import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  bool approveCalled = false;
  bool rejectCalled = false;
  bool? lastGenerateInvoice;
  String? lastRejectReason;

  @override
  Future<Map<String, dynamic>> approveReading({
    required String submissionId,
    bool generateInvoice = true,
    DateTime? dueDate,
  }) async {
    approveCalled = true;
    lastGenerateInvoice = generateInvoice;
    return {
      'success': true,
      'message': 'Đã phê duyệt thành công',
      'submission_id': submissionId,
    };
  }

  @override
  Future<Map<String, dynamic>> rejectReading({
    required String submissionId,
    required String reason,
  }) async {
    rejectCalled = true;
    lastRejectReason = reason;
    return {
      'success': true,
      'message': 'Đã từ chối thành công',
      'submission_id': submissionId,
    };
  }

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
      period: '10/2026',
      electricReading: 155.0,
      waterReading: 42.0,
      status: 'pending',
      createdAt: DateTime(2026, 10, 5, 10, 30),
      updatedAt: DateTime(2026, 10, 5, 10, 30),
    ),
  ];

  final sampleApprovedSubmissions = <MeterReadingSubmissionModel>[
    MeterReadingSubmissionModel(
      id: 'sub-a1',
      apartmentId: 'apt-102',
      apartmentCode: 'A0201',
      submittedBy: 'user-res-2',
      submitterName: 'Trần Thị B',
      period: '10/2026',
      electricReading: 180.0,
      waterReading: 50.0,
      status: 'approved',
      reviewedBy: 'admin-1',
      reviewedAt: DateTime(2026, 10, 5, 11, 0),
      createdAt: DateTime(2026, 10, 5, 9, 30),
    ),
  ];

  final sampleRejectedSubmissions = <MeterReadingSubmissionModel>[
    MeterReadingSubmissionModel(
      id: 'sub-r1',
      apartmentId: 'apt-103',
      apartmentCode: 'B0105',
      submittedBy: 'user-res-3',
      submitterName: 'Lê Văn C',
      period: '10/2026',
      electricReading: 90.0,
      waterReading: 20.0,
      status: 'rejected',
      rejectReason: 'Ảnh công tơ mờ không rõ số',
      reviewedBy: 'admin-1',
      reviewedAt: DateTime(2026, 10, 5, 11, 15),
      createdAt: DateTime(2026, 10, 5, 8, 30),
    ),
  ];

  Widget createTestWidget({
    List<MeterReadingSubmissionModel>? pendingList,
    List<MeterReadingSubmissionModel>? approvedList,
    List<MeterReadingSubmissionModel>? rejectedList,
    MeterReadingRepository? repo,
  }) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(adminUser)),
        pendingMeterReadingsCountProvider.overrideWith((ref) async => (pendingList ?? samplePendingSubmissions).length),
        allMeterReadingsProvider('pending').overrideWith((ref) async => pendingList ?? samplePendingSubmissions),
        allMeterReadingsProvider('approved').overrideWith((ref) async => approvedList ?? sampleApprovedSubmissions),
        allMeterReadingsProvider('rejected').overrideWith((ref) async => rejectedList ?? sampleRejectedSubmissions),
        if (repo != null) meterReadingRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        home: ManagementMeterReadingScreen(),
      ),
    );
  }

  testWidgets('hien thi giao dien quan ly chi so voi 3 tab va the cho duyet', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Kiem tra tieu de AppBar
    expect(find.text('Duyệt Chỉ Số Điện Nước'), findsOneWidget);

    // Kiem tra 3 tab
    expect(find.text('Chờ duyệt'), findsOneWidget);
    expect(find.text('Đã duyệt'), findsOneWidget);
    expect(find.text('Đã từ chối'), findsOneWidget);

    // Kiem tra the submission cho duyet
    expect(find.text('Căn hộ A0110'), findsOneWidget);
    expect(find.text('155.0 kWh'), findsOneWidget);
    expect(find.text('42.0 m³'), findsOneWidget);
    expect(find.text('Người gửi: Nguyễn Văn A'), findsOneWidget);

    // Kiem tra 2 nut hanh dong
    expect(find.widgetWithText(OutlinedButton, 'Từ chối'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Phê duyệt'), findsOneWidget);
  });

  testWidgets('phe duyet chi so kem tao hoa don tu dong', (tester) async {
    final fakeRepo = FakeMeterReadingRepository();
    await tester.pumpWidget(createTestWidget(repo: fakeRepo));
    await tester.pumpAndSettle();

    // Bấm nút Phê duyệt
    final approveButton = find.widgetWithText(ElevatedButton, 'Phê duyệt');
    await tester.tap(approveButton);
    await tester.pumpAndSettle();

    // Kiem tra dialog phe duyet xuat hien
    expect(find.text('Phê Duyệt Chỉ Số - Căn A0110'), findsOneWidget);
    expect(find.text('Tự động tạo hóa đơn tháng cho căn hộ này'), findsOneWidget);

    // Xac nhan duyet
    final confirmApprove = find.widgetWithText(ElevatedButton, 'Xác nhận duyệt');
    await tester.tap(confirmApprove);
    await tester.pumpAndSettle();

    expect(fakeRepo.approveCalled, isTrue);
    expect(fakeRepo.lastGenerateInvoice, isTrue);
  });

  testWidgets('tu choi chi so va nhap ly do bat buoc', (tester) async {
    final fakeRepo = FakeMeterReadingRepository();
    await tester.pumpWidget(createTestWidget(repo: fakeRepo));
    await tester.pumpAndSettle();

    // Bấm nút Từ chối
    final rejectButton = find.widgetWithText(OutlinedButton, 'Từ chối');
    await tester.tap(rejectButton);
    await tester.pumpAndSettle();

    // Kiem tra dialog tu choi xuat hien
    expect(find.text('Từ Chối Chỉ Số - Căn A0110'), findsOneWidget);

    // Bấm Xác nhận ngay ma chua nhap -> validate loi
    final confirmReject = find.widgetWithText(ElevatedButton, 'Xác nhận từ chối');
    await tester.tap(confirmReject);
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập lý do từ chối'), findsOneWidget);
    expect(fakeRepo.rejectCalled, isFalse);

    // Nhap ly do
    final reasonField = find.byType(TextFormField);
    await tester.enterText(reasonField, 'Ảnh chụp công tơ bị nhòe');
    await tester.pumpAndSettle();

    // Bấm xác nhận lại
    await tester.tap(confirmReject);
    await tester.pumpAndSettle();

    expect(fakeRepo.rejectCalled, isTrue);
    expect(fakeRepo.lastRejectReason, 'Ảnh chụp công tơ bị nhòe');
  });

  testWidgets('chuyen tab Da duyet va Da tu choi', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Chuyen sang Tab Da duyet
    await tester.tap(find.text('Đã duyệt'));
    await tester.pumpAndSettle();
    expect(find.text('Căn hộ A0201'), findsOneWidget);
    expect(find.text('180.0 kWh'), findsOneWidget);

    // Chuyen sang Tab Da tu choi
    await tester.tap(find.text('Đã từ chối'));
    await tester.pumpAndSettle();
    expect(find.text('Căn hộ B0105'), findsOneWidget);
    expect(find.text('Lý do từ chối: Ảnh công tơ mờ không rõ số'), findsOneWidget);
  });
}
