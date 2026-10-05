import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pka_home/data/models/building_amenity_model.dart';
import 'package:pka_home/data/models/amenity_booking_model.dart';
import 'package:pka_home/data/models/amenity_maintenance_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/repositories/amenity_booking_repository.dart';
import 'package:pka_home/data/providers/amenity_booking_provider.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/vehicle_provider.dart';
import 'package:pka_home/data/services/payment_service.dart';
import 'package:pka_home/data/providers/payment_provider.dart';
import 'package:pka_home/core/widgets/unified_payment_sheet.dart';
import 'package:pka_home/features/resident/screens/amenity_booking_screen.dart';

class FakePaymentServiceForAmenity extends PaymentService {
  @override
  Future<PaymentResult> pay({
    required WidgetRef ref,
    required PaymentType type,
    required String referenceId,
    String outcome = 'SUCCESS',
  }) async {
    return PaymentResult(
      success: true,
      transactionCode: 'DEMO-20261005-0099',
      transactionId: 'tx-99',
      amount: 100000.0,
      title: 'Sân cầu lông (06:00 - 07:30)',
      paidAt: DateTime(2026, 10, 5, 22, 40),
    );
  }
}

class FakeAmenityBookingRepo implements AmenityBookingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

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
    return AmenityBookingModel(
      id: 'bk-12345678',
      amenityId: amenityId,
      apartmentId: apartmentId,
      bookingDate: date,
      timeSlot: timeSlot,
      guestsCount: guestsCount,
      feeAmount: 100000.0,
      status: 'confirmed',
      createdAt: DateTime.now(),
      amenityName: 'Sân cầu lông',
      apartmentCode: 'A0110',
    );
  }

  @override
  Future<List<AmenityBookingModel>> getBookingsByAmenityAndDate({
    required String amenityId,
    required DateTime date,
  }) async => [];

  @override
  Future<List<AmenityMaintenanceModel>> getMaintenanceWindows({
    required String amenityId,
    required DateTime date,
  }) async => [];

  @override
  Future<List<AmenityBookingModel>> getMyBookings(String userId) async => [];

  @override
  Future<void> cancelBooking(String bookingId) async {}
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

  testWidgets('AmenityBookingScreen mở UnifiedPaymentSheet khi đặt dịch vụ có phí', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final amenity = BuildingAmenityModel(
      id: 'amenity-badminton',
      name: 'Sân cầu lông',
      bookingType: 'exclusive',
      openHours: '06:00 - 22:00',
      displayOrder: 1,
      feeAmount: 100000.0,
      slotDurationMinutes: 90,
      maxCapacity: 4,
    );

    final mockUser = UserModel(
      id: 'user-01',
      fullName: 'Nguyễn Văn A',
      phone: '0901234567',
      role: 'resident',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentServiceProvider.overrideWithValue(FakePaymentServiceForAmenity()),
          amenityBookingRepositoryProvider.overrideWithValue(FakeAmenityBookingRepo()),
          authProvider.overrideWith((ref) => MockAuthNotifier(mockUser)),
          residentApartmentIdProvider.overrideWith((ref) => 'apt-01'),
        ],
        child: MaterialApp(
          home: AmenityBookingScreen(amenity: amenity),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Để tránh slot hôm nay đã trôi qua sau 22h, chọn ngày mai (item index 1 trong thanh chọn ngày)
    final dateItems = find.byType(GestureDetector);
    if (dateItems.evaluate().length > 1) {
      // Tap vào ngày mai
      await tester.tap(dateItems.at(1));
      await tester.pumpAndSettle();
    }

    // Tìm một khung giờ trống để đặt (Card hoặc ListTile)
    final slotCards = find.byType(Card);
    expect(slotCards, findsWidgets);

    // Bấm vào khung giờ đầu tiên
    await tester.tap(slotCards.first);
    await tester.pumpAndSettle();

    // Bấm nút "Đặt lịch khung giờ ..." ở đáy màn hình
    final bookSlotBtn = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data != null && widget.data!.startsWith('Đặt lịch khung giờ'),
    );
    expect(bookSlotBtn, findsOneWidget);
    await tester.tap(bookSlotBtn);
    await tester.pumpAndSettle();

    // Modal Xác nhận đặt lịch xuất hiện
    expect(find.text('Xác Nhận Đặt Lịch'), findsOneWidget);
    final confirmBtn = find.text('Xác nhận đặt');
    expect(confirmBtn, findsOneWidget);

    // Bấm xác nhận đặt -> Mở UnifiedPaymentSheet
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // Kiểm tra UnifiedPaymentSheet mở ra
    expect(find.byType(UnifiedPaymentSheet), findsOneWidget);
    expect(find.text('Demo Payment'), findsOneWidget);
    expect(find.text('THANH TOÁN'), findsOneWidget);

    // Bấm THANH TOÁN
    await tester.tap(find.text('THANH TOÁN'));
    await tester.pump();
    expect(find.text('Đang xử lý giao dịch...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    // Thanh toán thành công trong sheet
    expect(find.text('Thanh toán thành công'), findsOneWidget);
    await tester.tap(find.text('HOÀN TẤT'));
    await tester.pumpAndSettle();

    // Dialog thông báo thành công kèm mã QR xuất hiện
    expect(find.text('Đặt Dịch Vụ Thành Công!'), findsOneWidget);
    expect(find.text('Xem Mã QR Check-in'), findsOneWidget);
  });
}
