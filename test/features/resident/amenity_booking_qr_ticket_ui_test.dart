import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:vivona/data/models/building_amenity_model.dart';
import 'package:vivona/data/models/amenity_booking_model.dart';
import 'package:vivona/data/models/amenity_maintenance_model.dart';
import 'package:vivona/data/models/user_model.dart';
import 'package:vivona/data/repositories/amenity_booking_repository.dart';
import 'package:vivona/data/providers/amenity_booking_provider.dart';
import 'package:vivona/data/providers/auth_provider.dart';
import 'package:vivona/data/providers/vehicle_provider.dart';
import 'package:vivona/features/resident/screens/amenity_booking_screen.dart';

class MockAmenityBookingRepositoryForTicket implements AmenityBookingRepository {
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
  Future<List<AmenityMaintenanceModel>> getMaintenanceWindows({
    required String amenityId,
    required DateTime date,
  }) async {
    return [];
  }

  @override
  Future<List<AmenityBookingModel>> getMyBookings([String? userId]) async {
    return [
      AmenityBookingModel(
        id: 'bk-bbq-001',
        amenityId: 'amenity-bbq-1',
        apartmentId: 'apt-a0110',
        apartmentCode: 'A0110',
        bookedBy: 'user-test-123',
        bookingDate: DateTime.now(),
        timeSlot: '18:00 - 20:00',
        status: 'confirmed',
        guestsCount: 8,
        feeAmount: 200000,
        depositAmount: 500000,
        depositStatus: 'received',
        qrTicketToken: 'TK-BBQ-987654321',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        amenityName: 'Vườn Nướng BBQ Sân Thượng',
      ),
      AmenityBookingModel(
        id: 'bk-bbq-002',
        amenityId: 'amenity-bbq-1',
        apartmentId: 'apt-a0110',
        apartmentCode: 'A0110',
        bookedBy: 'user-test-123',
        bookingDate: DateTime.now().subtract(const Duration(days: 1)),
        timeSlot: '18:00 - 20:00',
        status: 'checked_in',
        checkedInAt: DateTime.now().subtract(const Duration(hours: 20)),
        guestsCount: 6,
        feeAmount: 200000,
        depositAmount: 500000,
        depositStatus: 'refunded',
        qrTicketToken: 'TK-BBQ-123456789',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        amenityName: 'Vườn Nướng BBQ Sân Thượng',
        refundAmount: 500000,
        inspectionResult: 'passed',
        inspectionNotes: 'Mặt bằng sạch sẽ, bàn giao đầy đủ vỉ nướng',
      ),
    ];
  }
}

class MockAuthNotifierTicket extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  MockAuthNotifierTicket(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi', null);
  });

  testWidgets(
      'AmenityBookingScreen: Hiển thị Quota tuần & Vé QR check-in với mã token chuẩn B2B SaaS',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockRepo = MockAmenityBookingRepositoryForTicket();
    final mockUser = UserModel(
      id: 'user-test-123',
      fullName: 'Trần Văn Cư Dân',
      phone: '0901234567',
      role: 'resident',
    );

    final bbqAmenity = BuildingAmenityModel(
      id: 'amenity-bbq-1',
      name: 'Vườn Nướng BBQ Sân Thượng',
      displayOrder: 1,
      bookingType: 'exclusive',
      maxCapacity: 15,
      openHours: '16:00 - 22:00',
      slotDurationMinutes: 120,
      feeAmount: 200000,
      requiresDeposit: true,
      depositAmount: 500000,
      maxAdvanceDays: 7,
      maxSlotsPerWeek: 2,
      rulesAndRegulations:
          'Cư dân vui lòng dọn dẹp vệ sinh và tắt bếp than trước khi bàn giao. BQL sẽ nghiệm thu và hoàn cọc 100% trong 2 giờ.',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          amenityBookingRepositoryProvider.overrideWithValue(mockRepo),
          authProvider.overrideWith((ref) => MockAuthNotifierTicket(mockUser)),
          residentApartmentIdProvider.overrideWith((ref) => 'apt-a0110'),
          myAmenityBookingsProvider.overrideWith(
              (ref) => Future.value(mockRepo.getMyBookings('user-test-123'))),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AmenityBookingScreen(amenity: bbqAmenity),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Kiểm tra hiển thị Quota tuần và Quy định trong Tab 1 (Đặt tiện ích)
    expect(find.textContaining('Tối đa 2 lượt/tuần'), findsOneWidget);
    expect(find.textContaining('Quy định & Hoàn cọc'), findsOneWidget);

    // 2. Chuyển sang Tab 2: "Lịch Đã Đặt"
    await tester.tap(find.text('Lịch Đã Đặt'));
    await tester.pumpAndSettle();

    // 3. Kiểm tra thông tin các lượt đặt
    expect(find.text('Vườn Nướng BBQ Sân Thượng'), findsWidgets);
    expect(find.textContaining('Cọc: 500.000'), findsWidgets);

    // Kiểm tra hiển thị badge Đã hoàn cọc 100% cho đơn đã nghiệm thu
    expect(find.textContaining('Đã hoàn cọc 100%'), findsOneWidget);

    // 4. Bấm nút xem Vé QR Check-in trên ca sắp tới (bk-bbq-001)
    final qrButtons = find.byIcon(Icons.qr_code_2_rounded);
    expect(qrButtons, findsWidgets);

    await tester.tap(qrButtons.first);
    await tester.pumpAndSettle();

    // 5. Kiểm tra Hộp thoại Vé điện tử QR Code
    expect(find.text('Vé Điện Tử Check-in'), findsOneWidget);
    expect(find.textContaining('TK-BBQ-987654321'), findsOneWidget);
    expect(find.textContaining('Căn hộ: A0110'), findsOneWidget);

    // Kiểm tra Widget QrImageView hiển thị
    final qrViewFinder = find.byType(QrImageView);
    expect(qrViewFinder, findsOneWidget);
  });
}
