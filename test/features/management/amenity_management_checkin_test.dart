import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/building_amenity_model.dart';
import 'package:pka_home/data/models/amenity_booking_model.dart';
import 'package:pka_home/data/models/amenity_maintenance_model.dart';
import 'package:pka_home/data/providers/handbook_provider.dart';
import 'package:pka_home/data/providers/amenity_booking_provider.dart';
import 'package:pka_home/data/repositories/amenity_booking_repository.dart';
import 'package:pka_home/features/management/screens/amenity_management_screen.dart';

class MockAmenityBookingRepo implements AmenityBookingRepository {
  bool checkInCalled = false;
  String? lastCheckedInBookingId;

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
    bool allowWaitlist = false,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> cancelBooking(String bookingId) async {}

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
          amenityBookingRepositoryProvider.overrideWithValue(mockRepo),
          buildingAmenitiesProvider.overrideWith((ref) => [testAmenity]),
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

    // 1. Kiểm tra tiêu đề và tabs
    expect(find.text('Quản Trị Tiện Ích'), findsOneWidget);
    expect(find.text('Lịch Đặt Chỗ & Check-in'), findsOneWidget);
    expect(find.text('Lịch Bảo Trì'), findsOneWidget);

    // 2. Kiểm tra thông tin lượt đặt chỗ của căn hộ A0110
    expect(find.textContaining('A0110'), findsOneWidget);
    expect(find.text('Chờ Check-in'), findsOneWidget);
    expect(find.textContaining('Trần Văn B'), findsOneWidget);
    expect(find.textContaining('Phí dịch vụ:'), findsOneWidget);

    // 3. Kiểm tra nút Xác nhận Check-in và bấm check-in
    final checkInBtn = find.widgetWithText(ElevatedButton, 'Xác nhận Check-in');
    expect(checkInBtn, findsOneWidget);

    await tester.tap(checkInBtn);
    await tester.pumpAndSettle();

    expect(mockRepo.checkInCalled, isTrue);
    expect(mockRepo.lastCheckedInBookingId, 'booking-1');
    expect(find.textContaining('Xác nhận check-in thành công'), findsOneWidget);

    // 4. Kiểm tra nút Quét / Nhập mã Check-in trên AppBar
    final qrIconBtn = find.byIcon(Icons.qr_code_scanner_outlined);
    expect(qrIconBtn, findsWidgets);

    await tester.tap(qrIconBtn.first);
    await tester.pumpAndSettle();

    expect(find.text('Check-in Tiện Ích (QR/Mã)'), findsOneWidget);
    expect(find.text('Mã đặt chỗ (Booking ID)'), findsOneWidget);
  });
}
