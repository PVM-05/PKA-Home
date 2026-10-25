import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/building_amenity_model.dart';
import 'package:pka_home/data/models/amenity_booking_model.dart';
import 'package:pka_home/data/models/amenity_maintenance_model.dart';
import 'package:pka_home/data/providers/handbook_provider.dart';
import 'package:pka_home/data/providers/amenity_booking_provider.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/repositories/amenity_booking_repository.dart';
import 'package:pka_home/features/management/screens/amenity_management_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAmenityBookingRepo implements AmenityBookingRepository {
  bool checkInCalled = false;
  String? lastCheckedInBookingId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Map<String, dynamic>> checkInBooking(String bookingId) async {
    checkInCalled = true;
    lastCheckedInBookingId = bookingId;
    return {'success': true, 'message': 'Check-in thành công!', 'booking_id': bookingId};
  }

  @override
  Future<List<AmenityBookingModel>> getBookingsByAmenityAndDate({
    required String amenityId,
    required DateTime date,
  }) async {
    return [
      AmenityBookingModel(
        id: 'booking-1',
        amenityId: amenityId,
        apartmentId: 'apt-1',
        apartmentCode: 'A0110',
        bookerName: 'Trần Văn B',
        bookingDate: date,
        timeSlot: '08:00 - 10:00',
        status: 'confirmed',
        feeAmount: 50000,
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<List<AmenityBookingModel>> getAllBookings() async => [];

  @override
  Future<List<AmenityBookingModel>> getMyBookings(String userId) async => [];

  @override
  Future<AmenityBookingModel> createBooking({
    required String amenityId,
    required String apartmentId,
    required String userId,
    required DateTime date,
    required String timeSlot,
    int guestsCount = 1,
    String? notes,
    bool allowWaitlist = false,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> cancelBooking(String bookingId) async => {'success': true};

  @override
  Future<void> updateDepositStatus(String bookingId, String depositStatus, {String? notes}) async {}

  @override
  Future<void> markBookingAttendance(String bookingId, String status) async {}

  @override
  Future<List<AmenityMaintenanceModel>> getMaintenanceWindows({
    required String amenityId,
    required DateTime date,
  }) async => [];

  @override
  Future<void> createMaintenanceWindow({
    required String amenityId,
    required DateTime startTime,
    required DateTime endTime,
    required String reason,
    String? createdBy,
  }) async {}

  @override
  Future<void> deleteMaintenanceWindow(String windowId) async {}

  @override
  Future<Map<String, dynamic>> recordManualAmenityPayment({
    required String bookingId,
    String paymentMethod = 'CASH',
    String? notes,
  }) async {
    return {'success': true, 'message': 'Xác nhận thành công'};
  }


  @override
  Future<Map<String, dynamic>> rescheduleBooking({
    required String bookingId,
    required DateTime newDate,
    required String newTimeSlot,
    int? newGuestsCount,
    String? newNotes,
  }) async {
    return {'success': true, 'message': 'Đổi lịch thành công'};
  }
}


void main() {
  testWidgets('AmenityManagementScreen hiển thị Tab Lịch Đặt Chỗ & Check-in và thực hiện check-in thành công', (tester) async {
    final mockRepo = MockAmenityBookingRepo();

    final testAmenity = BuildingAmenityModel(
      id: 'amenity-bbq',
      name: 'Vườn nướng BBQ',
      description: 'Khu vực nướng ngoài trời',
      openHours: '08:00 - 22:00',
      displayOrder: 1,
      slotDurationMinutes: 120,
      maxCapacity: 10,
      feeAmount: 50000,
      requiresDeposit: false,
      depositAmount: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(UserModel(
                id: 'admin-1',
                fullName: 'Quản trị viên',
                phone: '0901234567',
                role: 'admin',
              ))),
          amenityBookingRepositoryProvider.overrideWithValue(mockRepo),
          buildingAmenitiesProvider.overrideWith((ref) => [testAmenity]),
          allAmenityBookingsProvider.overrideWith((ref) => mockRepo.getBookingsByAmenityAndDate(
                amenityId: testAmenity.id,
                date: DateTime.now(),
              )),
          amenityBookingsForDateProvider.overrideWith((ref, query) => mockRepo.getBookingsByAmenityAndDate(
                amenityId: query.amenityId,
                date: query.date,
              )),
          amenityMaintenanceForDateProvider.overrideWith((ref, query) => []),
        ],
        child: const MaterialApp(
          home: AmenityManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Kiểm tra tiêu đề và 3 tabs
    expect(find.text('Quản Trị Tiện Ích'), findsOneWidget);
    expect(find.text('Duyệt Lịch Đặt Chỗ'), findsOneWidget);
    expect(find.text('Tiện Ích & Sức Chứa'), findsOneWidget);
    expect(find.text('Lịch Bảo Trì'), findsOneWidget);

    // 2. Kiểm tra thông tin lượt đặt chỗ của căn hộ A0110
    expect(find.textContaining('Căn hộ: A0110'), findsOneWidget);
    expect(find.textContaining('Trần Văn B'), findsOneWidget);

    // 3. Kiểm tra nút Check-in và bấm check-in
    final checkInBtn = find.widgetWithText(ElevatedButton, 'Check-in');
    expect(checkInBtn, findsOneWidget);

    await tester.tap(checkInBtn);
    await tester.pumpAndSettle();

    expect(mockRepo.checkInCalled, isTrue);
    expect(mockRepo.lastCheckedInBookingId, 'booking-1');
    expect(find.textContaining('Check-in thành công'), findsOneWidget);

    // 4. Kiểm tra nút Quét / Nhập mã Check-in trên AppBar
    final qrIconBtn = find.byIcon(Icons.qr_code_scanner_outlined);
    expect(qrIconBtn, findsWidgets);

    await tester.tap(qrIconBtn.first);
    await tester.pumpAndSettle();

    expect(find.text('Check-in Tiện Ích (QR/Mã)'), findsOneWidget);
    expect(find.text('Mã đặt chỗ (Booking ID)'), findsOneWidget);
  });

  testWidgets('Dropdown chọn tiện ích hiển thị ổn định khi danh sách thay đổi và chọn tiện ích khác', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockRepo = MockAmenityBookingRepo();
    final testAmenity1 = BuildingAmenityModel(
      id: 'amenity-1',
      name: 'Sân Pickleball',
      displayOrder: 1,
      bookingType: 'exclusive',
      maxCapacity: 4,
    );
    final testAmenity2 = BuildingAmenityModel(
      id: 'amenity-2',
      name: 'Hồ bơi vô cực',
      displayOrder: 2,
      bookingType: 'shared',
      maxCapacity: 20,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(UserModel(
                id: 'admin-1',
                fullName: 'Quản trị viên',
                phone: '0901234567',
                role: 'admin',
              ))),
          amenityBookingRepositoryProvider.overrideWithValue(mockRepo),
          buildingAmenitiesProvider.overrideWith((ref) => [testAmenity1, testAmenity2]),
          allAmenityBookingsProvider.overrideWith((ref) => []),
          amenityBookingsForDateProvider.overrideWith((ref, query) => []),
          amenityMaintenanceForDateProvider.overrideWith((ref, query) => []),
        ],
        child: const MaterialApp(
          home: AmenityManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Chuyển sang Tab 3: Lịch Bảo Trì (chứa dropdown chọn tiện ích)
    await tester.tap(find.text('Lịch Bảo Trì'));
    await tester.pumpAndSettle();

    expect(find.text('Sân Pickleball'), findsOneWidget);

    await tester.tap(find.text('Sân Pickleball'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hồ bơi vô cực').last);
    await tester.pumpAndSettle();

    expect(find.text('Hồ bơi vô cực'), findsOneWidget);
  });

  testWidgets('Dropdown chọn tiện ích tên rất dài không bị RenderFlex overflow trên màn hình hẹp', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockRepo = MockAmenityBookingRepo();
    final testAmenityLong = BuildingAmenityModel(
      id: 'amenity-long',
      name: 'Phòng sinh hoạt cộng đồng Tòa A mở rộng tích hợp khu vui chơi trẻ em',
      displayOrder: 1,
      bookingType: 'exclusive',
      maxCapacity: 50,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(UserModel(
                id: 'admin-1',
                fullName: 'Quản trị viên',
                phone: '0901234567',
                role: 'admin',
              ))),
          amenityBookingRepositoryProvider.overrideWithValue(mockRepo),
          buildingAmenitiesProvider.overrideWith((ref) => [testAmenityLong]),
          allAmenityBookingsProvider.overrideWith((ref) => []),
          amenityBookingsForDateProvider.overrideWith((ref, query) => []),
          amenityMaintenanceForDateProvider.overrideWith((ref, query) => []),
        ],
        child: const MaterialApp(
          home: AmenityManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Chuyển sang Tab 3 (Lịch Bảo Trì) bằng cử chỉ vuốt trên màn hình 360dp
    await tester.drag(find.byType(TabBarView), const Offset(-360, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(TabBarView), const Offset(-360, 0));
    await tester.pumpAndSettle();

    // Xác nhận không ném ngoại lệ RenderFlex overflow và widget hiển thị bình thường
    expect(tester.takeException(), isNull);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });
}

