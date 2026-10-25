import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pka_home/data/models/building_amenity_model.dart';
import 'package:pka_home/data/models/amenity_booking_model.dart';
import 'package:pka_home/data/models/amenity_maintenance_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/handbook_provider.dart';
import 'package:pka_home/data/providers/amenity_booking_provider.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/repositories/amenity_booking_repository.dart';
import 'package:pka_home/data/repositories/handbook_repository.dart';
import 'package:pka_home/features/management/screens/amenity_management_screen.dart';

class MockHandbookRepo implements HandbookRepository {
  bool updateCalled = false;
  int? updatedCapacity;

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

  @override
  Future<void> updateBuildingAmenity({
    required String id,
    required String name,
    String? description,
    String? openHours,
    int displayOrder = 0,
    String? bookingType,
    int? maxCapacity,
    int? slotDurationMinutes,
    double? feeAmount,
    double? depositAmount,
    bool? requiresDeposit,
    bool? isActive,
  }) async {
    updateCalled = true;
    updatedCapacity = maxCapacity;
  }
}

class MockAmenityBookingRepo implements AmenityBookingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<AmenityBookingModel>> getAllBookings() async {
    return [
      AmenityBookingModel(
        id: 'bk-1',
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
    return [];
  }

  @override
  Future<List<AmenityMaintenanceModel>> getMaintenanceWindows({
    required String amenityId,
    required DateTime date,
  }) async {
    return [];
  }
}

class MockAdminAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  MockAdminAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi', null);
  });

  testWidgets('AmenityManagementScreen hiển thị đầy đủ 3 Tab và cho phép sửa sức chứa', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockHandbook = MockHandbookRepo();
    final mockBooking = MockAmenityBookingRepo();

    final adminUser = UserModel(
      id: 'admin-1',
      fullName: 'Quản Trị Viên',
      phone: '0988776655',
      role: 'admin',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => MockAdminAuthNotifier(adminUser)),
          handbookRepositoryProvider.overrideWithValue(mockHandbook),
          amenityBookingRepositoryProvider.overrideWithValue(mockBooking),
          buildingAmenitiesProvider.overrideWith((ref) => mockHandbook.fetchBuildingAmenities()),
          allAmenityBookingsProvider.overrideWith((ref) => mockBooking.getAllBookings()),
        ],
        child: const MaterialApp(
          home: AmenityManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Kiểm tra 3 Tabs hiện diện
    expect(find.text('Duyệt Lịch Đặt Chỗ'), findsOneWidget);
    expect(find.text('Tiện Ích & Sức Chứa'), findsOneWidget);
    expect(find.text('Lịch Bảo Trì'), findsOneWidget);

    // Tab 1: Duyệt Lịch Đặt Chỗ hiển thị booking A0110
    expect(find.textContaining('Căn hộ: A0110'), findsOneWidget);

    // 2. Chuyển sang Tab 2: 'Tiện Ích & Sức Chứa'
    final tab2 = find.text('Tiện Ích & Sức Chứa');
    await tester.tap(tab2);
    await tester.pumpAndSettle();

    // Hiển thị tiện ích Hồ Bơi Vô Cực với sức chứa 30 người
    expect(find.text('Hồ Bơi Vô Cực'), findsOneWidget);
    expect(find.textContaining('30 người'), findsOneWidget);

    // Bấm nút "Sửa cấu hình" của Hồ Bơi Vô Cực
    final editBtn = find.widgetWithText(OutlinedButton, 'Sửa cấu hình').first;
    expect(editBtn, findsOneWidget);
    await tester.tap(editBtn);
    await tester.pumpAndSettle();

    // Dialog mở lên
    expect(find.text('Chỉnh Sửa Tiện Ích & Sức Chứa'), findsOneWidget);

    // Tìm ô Sức chứa và sửa thành 40
    final capacityField = find.widgetWithText(TextFormField, 'Sức chứa tối đa (người) *');
    expect(capacityField, findsOneWidget);
    await tester.enterText(capacityField, '40');

    // Bấm Lưu cấu hình
    final saveBtn = find.widgetWithText(ElevatedButton, 'Lưu cấu hình');
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    // Xác nhận đã gọi cập nhật repository
    expect(mockHandbook.updateCalled, isTrue);
    expect(mockHandbook.updatedCapacity, 40);
  });
}
