import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pka_home/data/models/amenity_booking_model.dart';
import 'package:pka_home/data/models/building_amenity_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/amenity_booking_provider.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/vehicle_provider.dart';
import 'package:pka_home/data/repositories/amenity_booking_repository.dart';
import 'package:pka_home/features/resident/screens/amenity_booking_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAmenityBookingRepo implements AmenityBookingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<AmenityBookingModel>> getBookingsByAmenityAndDate({
    required String amenityId,
    required DateTime date,
  }) async => [];

  @override
  Future<List<AmenityBookingModel>> getMyBookings(String userId) async => [];
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi', null);
  });

  testWidgets('AmenityBookingScreen hien thi nut Doi lich cho booking hop le va khong hien thi cho booking da huy', (tester) async {
    final amenity = BuildingAmenityModel(
      id: 'amenity-bbq',
      name: 'Vườn Nướng BBQ',
      displayOrder: 1,
      bookingType: 'exclusive',
      maxCapacity: 10,
      slotDurationMinutes: 120,
      openHours: '08:00 - 22:00',
    );

    final futureDate = DateTime.now().add(const Duration(days: 3));
    final futureBooking = AmenityBookingModel(
      id: 'bk-future-1',
      amenityId: 'amenity-bbq',
      amenityName: 'Vườn Nướng BBQ',
      apartmentId: 'apt-1',
      bookingDate: futureDate,
      timeSlot: '16:00 - 18:00',
      status: 'confirmed',
      createdAt: DateTime.now(),
    );

    final cancelledBooking = AmenityBookingModel(
      id: 'bk-cancelled-2',
      amenityId: 'amenity-bbq',
      amenityName: 'Vườn Nướng BBQ',
      apartmentId: 'apt-1',
      bookingDate: futureDate,
      timeSlot: '18:00 - 20:00',
      status: 'cancelled',
      createdAt: DateTime.now(),
    );

    final fakeUser = UserModel(
      id: 'user-1',
      fullName: 'Cư dân Test',
      phone: '0901234567',
      role: 'resident',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          amenityBookingRepositoryProvider.overrideWithValue(FakeAmenityBookingRepo()),
          authProvider.overrideWith((ref) => FakeAuthNotifier(fakeUser)),
          residentApartmentIdProvider.overrideWith((ref) => 'apt-1'),
          myAmenityBookingsProvider.overrideWith((ref) => Future.value([futureBooking, cancelledBooking])),
          amenityBookingsForDateProvider(AmenityDateQuery(amenityId: amenity.id, date: DateTime(futureDate.year, futureDate.month, futureDate.day)))
              .overrideWith((ref) => Future.value([futureBooking])),
        ],
        child: MaterialApp(
          home: AmenityBookingScreen(amenity: amenity),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Chuyển sang tab "Lịch Đã Đặt"
    await tester.tap(find.text('Lịch Đã Đặt'));
    await tester.pumpAndSettle();

    // Xác nhận hiển thị 2 lượt đặt chỗ
    expect(find.text('16:00 - 18:00'), findsOneWidget);
    expect(find.text('18:00 - 20:00'), findsOneWidget);

    // Nút "Hủy lịch này" phải xuất hiện cho futureBooking, nhưng chỉ có đúng 1 nút vì cancelledBooking không có
    expect(find.text('Hủy lịch này'), findsOneWidget);

    // Nút "Đổi lịch" phải xuất hiện cho futureBooking
    expect(find.text('Đổi lịch'), findsOneWidget);
  });
}
