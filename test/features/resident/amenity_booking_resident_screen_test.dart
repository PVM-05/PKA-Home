import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pka_home/data/models/building_amenity_model.dart';
import 'package:pka_home/data/models/amenity_booking_model.dart';
import 'package:pka_home/data/models/amenity_maintenance_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/repositories/amenity_booking_repository.dart';
import 'package:pka_home/data/providers/amenity_booking_provider.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/vehicle_provider.dart';
import 'package:pka_home/features/resident/screens/amenity_booking_screen.dart';

class MockAmenityBookingRepository implements AmenityBookingRepository {
  bool cancelCalled = false;
  String? cancelledId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    cancelCalled = true;
    cancelledId = bookingId;
    return {'success': true, 'booking_id': bookingId};
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
      AmenityBookingModel(
        id: 'bk-other-2',
        amenityId: amenityId,
        apartmentId: 'apt-2',
        bookedBy: 'other-user',
        bookingDate: date,
        timeSlot: '07:30 - 09:00',
        guestsCount: 5,
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
}

class MockAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  MockAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi', null);
  });

  testWidgets('AmenityBookingScreen: Thẻ Lịch Đã Đặt trên 360dp không bị RenderFlex overflow và có thể bấm Hủy lịch này', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockRepo = MockAmenityBookingRepository();
    final mockUser = UserModel(
      id: 'user-test-123',
      fullName: 'Nguyễn Văn Cư Dân',
      phone: '0901234567',
      role: 'resident',
    );

    final testAmenity = BuildingAmenityModel(
      id: 'amenity-pool-1',
      name: 'Bể Bơi Vô Cực',
      bookingType: 'shared',
      maxCapacity: 30,
      openHours: '06:00 - 20:00',
      slotDurationMinutes: 90,
      feeAmount: 50000,
      depositAmount: 100000,
      requiresDeposit: true,
      displayOrder: 1,
    );

    final futureDate = DateTime.now().add(const Duration(days: 2));

    final myBooking = AmenityBookingModel(
      id: 'my-bk-999',
      amenityId: 'amenity-pool-1',
      apartmentId: 'apt-1',
      bookedBy: 'user-test-123',
      bookingDate: futureDate,
      timeSlot: '16:00 - 17:30',
      guestsCount: 2,
      feeAmount: 50000,
      depositAmount: 100000,
      depositStatus: 'pending',
      status: 'pending_payment',
      createdAt: DateTime.now(),
      amenityName: 'Bể Bơi Vô Cực',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(mockUser)),
          residentApartmentIdProvider.overrideWith((ref) => 'apt-1'),
          amenityBookingRepositoryProvider.overrideWithValue(mockRepo),
          myAmenityBookingsProvider.overrideWith((ref) => [myBooking]),
        ],
        child: MaterialApp(
          home: AmenityBookingScreen(amenity: testAmenity),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Chuyển sang Tab 2: 'Lịch Đã Đặt'
    final myBookingsTab = find.text('Lịch Đã Đặt');
    expect(myBookingsTab, findsOneWidget);
    await tester.tap(myBookingsTab);
    await tester.pumpAndSettle();

    // Thấy nút 'Hủy lịch này' hiển thị trọn vẹn, không bị tràn (findsOneWidget)
    final cancelBtn = find.text('Hủy lịch này');
    expect(cancelBtn, findsOneWidget);

    // Bấm 'Hủy lịch này' để mở Dialog xác nhận
    await tester.tap(cancelBtn);
    await tester.pumpAndSettle();

    expect(find.text('Hủy Lịch Đã Đặt'), findsOneWidget);

    // Bấm xác nhận 'Hủy lịch' trong Dialog
    final confirmBtn = find.widgetWithText(ElevatedButton, 'Hủy lịch');
    expect(confirmBtn, findsOneWidget);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // Xác nhận repository đã được gọi thành công
    expect(mockRepo.cancelCalled, isTrue);
    expect(mockRepo.cancelledId, 'my-bk-999');
  });

  testWidgets('AmenityBookingScreen: Tab Chọn Khung Giờ hiển thị huy hiệu Lịch của bạn và chỗ trống chính xác', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockRepo = MockAmenityBookingRepository();
    final mockUser = UserModel(
      id: 'user-test-123',
      fullName: 'Nguyễn Văn Cư Dân',
      phone: '0901234567',
      role: 'resident',
    );

    final testAmenity = BuildingAmenityModel(
      id: 'amenity-pool-1',
      name: 'Bể Bơi Vô Cực',
      bookingType: 'shared',
      maxCapacity: 30,
      openHours: '06:00 - 10:00',
      slotDurationMinutes: 90,
      feeAmount: 50000,
      displayOrder: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(mockUser)),
          residentApartmentIdProvider.overrideWith((ref) => 'apt-1'),
          amenityBookingRepositoryProvider.overrideWithValue(mockRepo),
          myAmenityBookingsProvider.overrideWith((ref) => []),
        ],
        child: MaterialApp(
          home: AmenityBookingScreen(amenity: testAmenity),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Chọn ngày mai để các slot thời gian đều là khung giờ tương lai
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowText = DateFormat('dd/MM').format(tomorrow);
    final tomorrowTile = find.text(tomorrowText);
    expect(tomorrowTile, findsOneWidget);
    await tester.tap(tomorrowTile);
    await tester.pumpAndSettle();

    // Kiểm tra slot 06:00 - 07:30 có huy hiệu 'Lịch của bạn'
    expect(find.textContaining('Lịch của bạn'), findsWidgets);

    // Chạm vào slot 06:00 - 07:30 đã đặt: thanh dưới phải chuyển thành nút hủy
    final mySlotTile = find.text('06:00 - 07:30');
    await tester.tap(mySlotTile);
    await tester.pumpAndSettle();
    expect(find.textContaining('Hủy lịch khung giờ 06:00 - 07:30'), findsOneWidget);

    // Kiểm tra slot 07:30 - 09:00 trừ 5 khách (30 - 5 = 25 chỗ)
    expect(find.textContaining('25 chỗ'), findsOneWidget);
  });
}
