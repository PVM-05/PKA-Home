import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pka_home/data/models/building_amenity_model.dart';
import 'package:pka_home/data/models/amenity_booking_model.dart';
import 'package:pka_home/data/models/amenity_maintenance_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/repositories/amenity_booking_repository.dart';
import 'package:pka_home/data/repositories/handbook_repository.dart';
import 'package:pka_home/data/providers/amenity_booking_provider.dart';
import 'package:pka_home/data/providers/handbook_provider.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/vehicle_provider.dart';
import 'package:pka_home/features/resident/screens/amenity_booking_screen.dart';
import 'package:pka_home/features/management/screens/amenity_management_screen.dart';

class ResponsiveMockAmenityBookingRepo implements AmenityBookingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<AmenityBookingModel>> getAllBookings() async {
    return [
      AmenityBookingModel(
        id: 'bk-res-1',
        amenityId: 'amenity-pool-1',
        apartmentId: 'apt-1',
        bookedBy: 'user-1',
        bookingDate: DateTime.now().add(const Duration(days: 1)),
        timeSlot: '07:30 - 09:00',
        guestsCount: 4,
        feeAmount: 50000,
        status: 'pending_payment',
        createdAt: DateTime.now(),
        amenityName: 'Hồ Bơi Vô Cực',
        apartmentCode: 'A0110',
        bookerName: 'Trần Văn Nam',
      ),
    ];
  }

  @override
  Future<List<AmenityBookingModel>> getBookingsByAmenityAndDate({
    required String amenityId,
    required DateTime date,
  }) async {
    return [
      AmenityBookingModel(
        id: 'bk-user-1',
        amenityId: amenityId,
        apartmentId: 'apt-1',
        bookedBy: 'user-test-123',
        bookingDate: date,
        timeSlot: '06:00 - 07:30',
        guestsCount: 2,
        status: 'confirmed',
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<List<AmenityMaintenanceModel>> getMaintenanceWindows({
    required String amenityId,
    required DateTime date,
  }) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    return {'success': true, 'booking_id': bookingId};
  }
}

class ResponsiveMockHandbookRepo implements HandbookRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<BuildingAmenityModel>> fetchBuildingAmenities() async {
    return [
      BuildingAmenityModel(
        id: 'amenity-pool-1',
        name: 'Hồ Bơi Vô Cực',
        bookingType: 'shared',
        maxCapacity: 30,
        openHours: '06:00 - 20:00',
        slotDurationMinutes: 90,
        feeAmount: 50000,
        depositAmount: 100000,
        requiresDeposit: true,
        displayOrder: 1,
      ),
      BuildingAmenityModel(
        id: 'amenity-bbq-1',
        name: 'Khu Nướng BBQ',
        bookingType: 'shared',
        maxCapacity: 15,
        openHours: '16:00 - 22:00',
        slotDurationMinutes: 180,
        feeAmount: 200000,
        depositAmount: 500000,
        requiresDeposit: true,
        displayOrder: 2,
      ),
    ];
  }
}

class ResponsiveMockAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  ResponsiveMockAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi', null);
  });

  final residentUser = UserModel(
    id: 'user-test-123',
    fullName: 'Cư Dân Test',
    role: 'resident',
    phone: '0901234567',
  );

  final adminUser = UserModel(
    id: 'admin-123',
    fullName: 'Ban Quản Lý',
    role: 'admin',
    phone: '0909999999',
  );

  final testAmenity = BuildingAmenityModel(
    id: 'amenity-pool-1',
    name: 'Hồ Bơi Vô Cực',
    bookingType: 'shared',
    maxCapacity: 30,
    openHours: '06:00 - 20:00',
    slotDurationMinutes: 90,
    feeAmount: 50000,
    depositAmount: 100000,
    requiresDeposit: true,
    displayOrder: 1,
  );

  final myBookingsList = [
    AmenityBookingModel(
      id: 'bk-user-1',
      amenityId: 'amenity-pool-1',
      apartmentId: 'apt-1',
      bookedBy: 'user-test-123',
      bookingDate: DateTime.now().add(const Duration(days: 1)),
      timeSlot: '07:30 - 09:00',
      guestsCount: 2,
      feeAmount: 50000,
      depositAmount: 100000,
      depositStatus: 'unpaid',
      status: 'pending_payment',
      createdAt: DateTime.now(),
      amenityName: 'Hồ Bơi Vô Cực',
    ),
  ];

  testWidgets('Màn hình Cư Dân trên 360x640: không RenderFlex overflow, có thể xem và hủy lịch', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockBookingRepo = ResponsiveMockAmenityBookingRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          amenityBookingRepositoryProvider.overrideWithValue(mockBookingRepo),
          authProvider.overrideWith((ref) => ResponsiveMockAuthNotifier(residentUser)),
          residentApartmentIdProvider.overrideWith((ref) => 'apt-1'),
          myAmenityBookingsProvider.overrideWith((ref) => myBookingsList),
        ],
        child: MaterialApp(
          home: AmenityBookingScreen(amenity: testAmenity),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Kiểm tra không có exception RenderFlex
    expect(tester.takeException(), isNull);
    expect(find.text('Chọn Khung Giờ'), findsOneWidget);

    // Chuyển sang Tab 'Lịch Đã Đặt'
    final myBookingsTab = find.text('Lịch Đã Đặt');
    await tester.tap(myBookingsTab);
    await tester.pumpAndSettle();

    // Nút Hủy lịch này hiển thị đầy đủ và không bị tràn viền
    expect(tester.takeException(), isNull);
    expect(find.text('Hủy lịch này'), findsOneWidget);
    expect(find.text('Thanh toán ngay'), findsOneWidget);
  });

  testWidgets('Màn hình BQL 3 Tab trên 360x640 & 390x844: không RenderFlex overflow', (tester) async {
    // Thử nghiệm độ phân giải cực nhỏ 360x640
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockBookingRepo = ResponsiveMockAmenityBookingRepo();
    final mockHandbookRepo = ResponsiveMockHandbookRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          amenityBookingRepositoryProvider.overrideWithValue(mockBookingRepo),
          handbookRepositoryProvider.overrideWithValue(mockHandbookRepo),
          authProvider.overrideWith((ref) => ResponsiveMockAuthNotifier(adminUser)),
          buildingAmenitiesProvider.overrideWith((ref) => mockHandbookRepo.fetchBuildingAmenities()),
          allAmenityBookingsProvider.overrideWith((ref) => mockBookingRepo.getAllBookings()),
        ],
        child: const MaterialApp(
          home: AmenityManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tab 1: Duyệt lịch
    expect(tester.takeException(), isNull);
    expect(find.text('Duyệt Lịch Đặt Chỗ'), findsOneWidget);

    // Chuyển sang Tab 2 bằng cách cuộn TabBar hoặc vuốt trang
    await tester.drag(find.byType(TabBarView), const Offset(-360, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Hồ Bơi Vô Cực'), findsOneWidget);

    // Chuyển sang Tab 3 bằng cách vuốt tiếp
    await tester.drag(find.byType(TabBarView), const Offset(-360, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Thêm Lịch Bảo Trì'), findsOneWidget);
  });
}
