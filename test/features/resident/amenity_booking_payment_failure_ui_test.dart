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

class FailingPaymentService extends PaymentService {
  @override
  Future<PaymentResult> pay({
    required PaymentType type,
    required String referenceId,
    String paymentMethod = 'bank_transfer',
    String outcome = 'SUCCESS',
  }) async {
    return PaymentResult(
      success: false,
      transactionCode: 'FAILED-001',
      transactionId: 'tx-failed',
      amount: 100000.0,
      title: 'Sân cầu lông',
      paidAt: DateTime.now(),
      errorMessage: 'Thanh toán trực tuyến chưa được cấu hình. Vui lòng liên hệ Ban Quản Lý.',
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
    String? notes,
    bool allowWaitlist = false,
  }) async {
    return AmenityBookingModel(
      id: 'bk-99998888',
      amenityId: amenityId,
      apartmentId: apartmentId,
      bookingDate: date,
      timeSlot: timeSlot,
      guestsCount: guestsCount,
      feeAmount: 100000.0,
      status: 'pending_payment',
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

  testWidgets('AmenityBookingScreen thông báo Chờ thanh toán khi thanh toán thất bại/bị đóng', (tester) async {
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
          paymentServiceProvider.overrideWithValue(FailingPaymentService()),
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

    // Chọn ngày mai
    final dateItems = find.byType(GestureDetector);
    if (dateItems.evaluate().length > 1) {
      await tester.tap(dateItems.at(1));
      await tester.pumpAndSettle();
    }

    // Bấm vào khung giờ đầu tiên
    final slotCards = find.byType(Card);
    expect(slotCards, findsWidgets);
    await tester.tap(slotCards.first);
    await tester.pumpAndSettle();

    // Bấm nút Đặt lịch
    final bookSlotBtn = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data != null && widget.data!.startsWith('Đặt lịch khung giờ'),
    );
    await tester.tap(bookSlotBtn);
    await tester.pumpAndSettle();

    // Bấm xác nhận đặt -> mở UnifiedPaymentSheet
    await tester.tap(find.text('Xác nhận đặt'));
    await tester.pumpAndSettle();

    expect(find.byType(UnifiedPaymentSheet), findsOneWidget);

    // Bấm GỬI THÔNG BÁO THANH TOÁN
    await tester.tap(find.text('GỬI THÔNG BÁO THANH TOÁN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    // Giao dịch không thành công
    expect(find.text('Giao dịch không thành công'), findsOneWidget);

    // Bấm ĐÓNG
    await tester.tap(find.text('ĐÓNG'));
    await tester.pumpAndSettle();

    // Kiểm tra không hiển thị dialog thành công xanh, mà hiển thị SnackBar cảnh báo Chờ thanh toán
    expect(find.text('Đặt Dịch Vụ Thành Công!'), findsNothing);
    expect(
      find.text('Lịch đặt đã được ghi nhận ở trạng thái Chờ thanh toán. Vui lòng liên hệ Ban Quản Lý để hoàn tất thanh toán trước giờ sử dụng.'),
      findsOneWidget,
    );
  });
}
