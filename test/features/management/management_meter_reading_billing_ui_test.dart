import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vivona/data/models/building_utility_rate_model.dart';
import 'package:vivona/data/models/meter_reading_submission_model.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/meter_reading_provider.dart';
import 'package:vivona/data/repositories/meter_reading_repository.dart';
import 'package:vivona/features/management/screens/management_meter_reading_screen.dart';

class FakeAuthNotifierBilling extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifierBilling(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMeterRepoForBilling implements MeterReadingRepository {
  bool approveCalled = false;
  bool? lastGenerateInvoice;
  bool batchRecordCalled = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<BuildingUtilityRateModel>> getUtilityRates() async {
    return [
      const BuildingUtilityRateModel(
        id: 'rate-1',
        utilityType: 'electricity',
        baseUnitPrice: 3500.0,
        vatPercentage: 8.0,
      ),
      const BuildingUtilityRateModel(
        id: 'rate-2',
        utilityType: 'water',
        baseUnitPrice: 25000.0,
        vatPercentage: 5.0,
        environmentFeePercentage: 10.0,
      ),
    ];
  }

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
      'message': 'Đã phê duyệt và sinh hóa đơn thành công',
      'submission_id': submissionId,
      'invoice_id': 'inv-elec-999',
    };
  }

  @override
  Future<Map<String, dynamic>> batchRecordReadings({
    required String period,
    required List<Map<String, dynamic>> readings,
  }) async {
    batchRecordCalled = true;
    return {
      'success': true,
      'inserted_count': readings.length,
      'message': 'Đã chốt thành công ${readings.length} căn hộ',
    };
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi', null);
  });

  testWidgets(
      'ManagementMeterReadingScreen: Duyệt chỉ số tự động tính phí, sinh hóa đơn và chốt số hàng loạt',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final adminUser = UserModel(
      id: 'admin-1',
      fullName: 'Kế Toán Trưởng',
      phone: '0988888888',
      role: 'admin',
    );

    final mockRepo = FakeMeterRepoForBilling();

    final pendingSubmissions = [
      MeterReadingSubmissionModel(
        id: 'sub-p1',
        apartmentId: 'apt-a0110',
        apartmentCode: 'A0110',
        submittedBy: 'user-res-1',
        submitterName: 'Nguyễn Văn Cư Dân',
        period: '11/2026',
        electricReading: 1500.0,
        waterReading: 80.0,
        previousElectricReading: 1350.0,
        previousWaterReading: 65.0,
        electricConsumed: 150.0,
        waterConsumed: 15.0,
        status: 'pending',
        createdAt: DateTime.now(),
      ),
    ];

    final approvedSubmissions = [
      MeterReadingSubmissionModel(
        id: 'sub-a1',
        apartmentId: 'apt-a0201',
        apartmentCode: 'A0201',
        submittedBy: 'user-res-2',
        submitterName: 'Trần Thị Chủ Hộ',
        period: '11/2026',
        electricReading: 1200.0,
        waterReading: 50.0,
        previousElectricReading: 1100.0,
        previousWaterReading: 40.0,
        electricConsumed: 100.0,
        waterConsumed: 10.0,
        invoiceId: 'inv-elec-999',
        status: 'approved',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifierBilling(adminUser)),
          meterReadingRepositoryProvider.overrideWithValue(mockRepo),
          allMeterReadingsProvider.overrideWith((ref, status) {
            if (status == 'pending') return Future.value(pendingSubmissions);
            if (status == 'approved') return Future.value(approvedSubmissions);
            return Future.value([]);
          }),
          anomalyMeterReadingsProvider.overrideWith((ref) => Future.value([])),
          pendingMeterReadingsCountProvider.overrideWith((ref) => Future.value(1)),
          pendingAnomalyCountProvider.overrideWith((ref) => Future.value(0)),
          buildingUtilityRatesProvider.overrideWith(
              (ref) => mockRepo.getUtilityRates()),
        ],
        child: const MaterialApp(
          home: ManagementMeterReadingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Kiểm tra màn hình hiển thị danh sách chỉ số chờ duyệt
    expect(find.text('Quản Lý Chỉ Số Tiện Ích'), findsOneWidget);
    expect(find.textContaining('A0110'), findsOneWidget);

    // 2. Bấm nút Phê duyệt trên card căn A0110
    final approveBtn = find.text('Phê duyệt');
    expect(approveBtn, findsOneWidget);
    await tester.tap(approveBtn);
    await tester.pumpAndSettle();

    // 3. Kiểm tra hộp thoại phê duyệt hiển thị lượng tiêu thụ tính toán
    expect(find.textContaining('Phê Duyệt Chỉ Số - Căn A0110'), findsOneWidget);
    expect(find.textContaining('Tiêu thụ điện: 150'), findsOneWidget);
    expect(find.textContaining('Tiêu thụ nước: 15'), findsOneWidget);
    expect(find.textContaining('Tự động tạo hóa đơn tháng cho căn hộ này'), findsOneWidget);

    // Bấm nút "Xác nhận duyệt"
    final confirmApproveBtn = find.text('Xác nhận duyệt');
    expect(confirmApproveBtn, findsOneWidget);
    await tester.tap(confirmApproveBtn);
    await tester.pumpAndSettle();

    // Kiểm tra mock repo đã gọi approveReading với generateInvoice = true
    expect(mockRepo.approveCalled, isTrue);
    expect(mockRepo.lastGenerateInvoice, isTrue);

    // 4. Chuyển sang Tab "Đã duyệt"
    await tester.tap(find.text('Đã duyệt'));
    await tester.pumpAndSettle();

    // Kiểm tra hiển thị căn A0201 kèm badge "Đã xuất hóa đơn"
    expect(find.textContaining('A0201'), findsOneWidget);
    expect(find.textContaining('Đã xuất hóa đơn'), findsOneWidget);

    // 5. Kiểm tra nút Action "Chốt số theo tầng" trên AppBar
    final batchRecordAction = find.byTooltip('Chốt số theo tầng');
    expect(batchRecordAction, findsOneWidget);
    await tester.tap(batchRecordAction);
    await tester.pumpAndSettle();

    // Hộp thoại chốt số xuất hiện
    expect(find.text('Trạm Chốt Số Tiện Ích Theo Tầng'), findsOneWidget);
  });
}

