import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vivona/data/models/building_amenity_model.dart';
import 'package:vivona/data/models/amenity_booking_model.dart';
import 'package:vivona/data/models/amenity_inspection_model.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/providers/handbook_provider.dart';
import 'package:vivona/data/providers/amenity_booking_provider.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/repositories/amenity_booking_repository.dart';
import 'package:vivona/data/repositories/handbook_repository.dart';
import 'package:vivona/features/management/screens/amenity_management_screen.dart';

class MockHandbookRepoForInspection implements HandbookRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<BuildingAmenityModel>> fetchBuildingAmenities() async {
    return [
      BuildingAmenityModel(
        id: 'amenity-bbq-1',
        name: 'Vườn Nướng BBQ Sân Thượng',
        displayOrder: 1,
        bookingType: 'exclusive',
        maxCapacity: 15,
        openHours: '16:00 - 22:00',
        feeAmount: 200000,
        requiresDeposit: true,
        depositAmount: 500000,
        maxSlotsPerWeek: 2,
      ),
    ];
  }
}

class MockAmenityBookingRepoForInspection implements AmenityBookingRepository {
  bool checkInTicketCalled = false;
  String? lastTicketToken;

  bool inspectCalled = false;
  AmenityInspectionModel? lastInspection;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<AmenityBookingModel>> getBookingsByAmenityAndDate({
    required String amenityId,
    required DateTime date,
  }) async {
    return [];
  }

  @override
  Future<List<AmenityBookingModel>> getAllBookings() async => [];

  @override
  Future<List<AmenityBookingModel>> getBookingsPendingInspection() async {
    return [
      AmenityBookingModel(
        id: 'bk-inspect-001',
        amenityId: 'amenity-bbq-1',
        amenityName: 'Vườn Nướng BBQ Sân Thượng',
        apartmentId: 'apt-a0110',
        apartmentCode: 'A0110',
        bookerName: 'Lê Cư Dân',
        bookingDate: DateTime.now(),
        timeSlot: '16:00 - 18:00',
        status: 'checked_in',
        feeAmount: 200000,
        depositAmount: 500000,
        depositStatus: 'received',
        qrTicketToken: 'TK-BBQ-987654321',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> checkInTicket(String qrTicketToken) async {
    checkInTicketCalled = true;
    lastTicketToken = qrTicketToken;
    return {
      'success': true,
      'booking_id': 'bk-inspect-001',
      'message': 'Check-in vé thành công',
    };
  }

  @override
  Future<Map<String, dynamic>> inspectAndSettleDeposit(
      AmenityInspectionModel inspection) async {
    inspectCalled = true;
    lastInspection = inspection;
    return {
      'success': true,
      'booking_id': inspection.bookingId,
      'forfeited_amount': inspection.forfeitedAmount,
      'deposit_status':
          inspection.inspectionResult == 'passed' ? 'refunded' : 'forfeited',
    };
  }
}

class FakeStaffAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeStaffAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi', null);
  });

  testWidgets(
      'AmenityManagementScreen: Quét vé QR Check-in và Trạm nghiệm thu hoàn cọc B2B SaaS',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockHandbook = MockHandbookRepoForInspection();
    final mockBookingRepo = MockAmenityBookingRepoForInspection();
    final staffUser = UserModel(
      id: 'staff-admin-99',
      fullName: 'Quản Lý Nguyễn',
      phone: '0988776655',
      role: 'admin',
    );

    final bbqAmenity = BuildingAmenityModel(
      id: 'amenity-bbq-1',
      name: 'Vườn Nướng BBQ Sân Thượng',
      displayOrder: 1,
      bookingType: 'exclusive',
      maxCapacity: 15,
      openHours: '16:00 - 22:00',
      feeAmount: 200000,
      requiresDeposit: true,
      depositAmount: 500000,
      maxSlotsPerWeek: 2,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          handbookRepositoryProvider.overrideWithValue(mockHandbook),
          amenityBookingRepositoryProvider.overrideWithValue(mockBookingRepo),
          authProvider.overrideWith((ref) => FakeStaffAuthNotifier(staffUser)),
          buildingAmenitiesProvider.overrideWith((ref) => [bbqAmenity]),
          allAmenityBookingsProvider.overrideWith((ref) => []),
          pendingAmenityInspectionsProvider.overrideWith(
              (ref) => mockBookingRepo.getBookingsPendingInspection()),
        ],
        child: const MaterialApp(
          home: AmenityManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Kiểm tra Tab "Nghiệm Thu Cọc" xuất hiện trên TabBar
    final tabFinder = find.text('Nghiệm Thu Cọc');
    expect(tabFinder, findsOneWidget);

    // 2. Chuyển sang Tab "Nghiệm Thu Cọc"
    await tester.ensureVisible(tabFinder);
    await tester.tap(tabFinder);
    await tester.pumpAndSettle();

    // Kiểm tra hiển thị danh sách đơn chờ nghiệm thu
    expect(find.text('Vườn Nướng BBQ Sân Thượng'), findsWidgets);
    expect(find.textContaining('A0110'), findsWidgets);
    expect(find.textContaining('500.000'), findsWidgets);

    // 3. Bấm nút "Nghiệm Thu Mặt Bằng"
    final inspectBtn = find.text('Nghiệm Thu Mặt Bằng');
    expect(inspectBtn, findsOneWidget);
    await tester.tap(inspectBtn);
    await tester.pumpAndSettle();

    // Kiểm tra hộp thoại nghiệm thu xuất hiện
    expect(find.text('Nghiệm Thu & Quyết Toán Cọc'), findsOneWidget);
    expect(find.text('Đạt tiêu chuẩn (Hoàn 100%)'), findsOneWidget);

    // Bấm nút "Xác Nhận Nghiệm Thu"
    final confirmInspectBtn = find.text('Xác Nhận Quyết Toán');
    expect(confirmInspectBtn, findsOneWidget);
    await tester.tap(confirmInspectBtn);
    await tester.pumpAndSettle();

    // Kiểm tra mock repo đã nhận lệnh inspect với kết quả passed và khấu trừ 0đ
    expect(mockBookingRepo.inspectCalled, isTrue);
    expect(mockBookingRepo.lastInspection?.bookingId, 'bk-inspect-001');
    expect(mockBookingRepo.lastInspection?.inspectionResult, 'passed');
    expect(mockBookingRepo.lastInspection?.forfeitedAmount, 0.0);

    // 4. Test chức năng Quét / Check-in Vé QR
    // Bấm nút "Quét / Nhập mã Check-in" trên AppBar
    final qrCheckInAction = find.byIcon(Icons.qr_code_scanner_outlined);
    expect(qrCheckInAction, findsOneWidget);
    await tester.tap(qrCheckInAction);
    await tester.pumpAndSettle();

    // Kiểm tra hộp thoại Check-in xuất hiện
    expect(find.text('Check-in Tiện Ích (QR/Mã)'), findsOneWidget);

    // Nhập mã vé token vào TextField
    final tokenField = find.byKey(const Key('qr_token_input_field'));
    expect(tokenField, findsOneWidget);
    await tester.enterText(
        tokenField, 'PKA-TICKET:TK-BBQ-987654321:A0110:16:00 - 18:00');
    await tester.pumpAndSettle();

    // Bấm nút "Xác nhận vào cửa"
    final confirmCheckInBtn = find.text('Xác nhận vào cửa');
    expect(confirmCheckInBtn, findsOneWidget);
    await tester.tap(confirmCheckInBtn);
    await tester.pumpAndSettle();

    // Kiểm tra mock repo đã nhận lệnh checkInTicket với token được trích xuất
    expect(mockBookingRepo.checkInTicketCalled, isTrue);
    expect(mockBookingRepo.lastTicketToken, 'TK-BBQ-987654321');
  });
}
