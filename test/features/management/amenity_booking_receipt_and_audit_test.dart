import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/amenity_booking_model.dart';
import 'package:pka_home/data/models/building_amenity_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/amenity_booking_provider.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/handbook_provider.dart';
import 'package:pka_home/features/management/screens/amenity_management_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('AmenityBookingModel maps payment transaction fields correctly', () {
    final rawBooking = {
      'id': 'booking-uuid-12345678',
      'amenity_id': 'amenity-pool-1',
      'apartment_id': 'apt-1',
      'user_id': 'user-1',
      'booking_date': '2026-10-26',
      'time_slot': '14:00 - 15:30',
      'status': 'confirmed',
      'guests_count': 2,
      'is_waitlist': false,
      'fee_amount': 50000,
      'deposit_amount': 100000,
      'deposit_status': 'received',
      'created_at': '2026-10-26T08:00:00Z',
      'apartments': {'code': 'A0110'},
      'building_amenities': {'name': 'Hồ bơi bốn mùa'},
      'users': {'full_name': 'Nguyễn Văn A', 'phone': '0901234567'},
      'payment_transactions': [
        {
          'id': 'tx-123',
          'transaction_code': 'SVC20261026001',
          'payment_method': 'BANK_TRANSFER',
          'status': 'paid',
          'amount': 150000,
          'paid_at': '2026-10-26T08:05:00Z',
        }
      ]
    };

    final model = AmenityBookingModel.fromJson(rawBooking);

    expect(model.id, 'booking-uuid-12345678');
    expect(model.hasFee, true);
    expect(model.transactionCode, 'SVC20261026001');
    expect(model.paymentMethod, 'BANK_TRANSFER');
    expect(model.paymentStatus, 'paid');
    expect(model.totalPaymentAmount, 150000.0);
    expect(model.isPendingPayment, false);
  });

  testWidgets('AmenityManagementScreen renders Biên nhận button for bookings with fee/payment',
      (tester) async {
    final sampleAmenity = BuildingAmenityModel(
      id: 'amenity-pool-1',
      name: 'Hồ bơi vô cực',
      bookingType: 'shared',
      maxCapacity: 10,
      slotDurationMinutes: 90,
      openHours: '06:00 - 22:00',
      feeAmount: 50000,
      depositAmount: 50000,
      requiresDeposit: true,
      displayOrder: 1,
    );

    final today = DateTime.now();

    final sampleBooking = AmenityBookingModel(
      id: 'booking-uuid-12345678',
      amenityId: 'amenity-pool-1',
      apartmentId: 'apt-1',
      bookedBy: 'user-1',
      bookingDate: today,
      timeSlot: '14:00 - 15:30',
      status: 'confirmed',
      guestsCount: 2,
      feeAmount: 50000,
      depositAmount: 50000,
      depositStatus: 'received',
      createdAt: DateTime.now(),
      apartmentCode: 'A0110',
      amenityName: 'Hồ bơi vô cực',
      bookerName: 'Nguyễn Văn A',
      transactionCode: 'SVC20261026001',
      paymentMethod: 'BANK_TRANSFER',
      paymentStatus: 'paid',
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
          buildingAmenitiesProvider.overrideWith((ref) => [sampleAmenity]),
          allAmenityBookingsProvider.overrideWith((ref) => [sampleBooking]),
          amenityBookingsForDateProvider.overrideWith((ref, query) => [sampleBooking]),
          amenityMaintenanceForDateProvider.overrideWith((ref, query) => []),
        ],
        child: const MaterialApp(
          home: AmenityManagementScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify booking is shown
    expect(find.textContaining('A0110'), findsWidgets);
    expect(find.textContaining('Hồ bơi vô cực'), findsWidgets);

    // Verify 'Biên nhận' button exists
    final receiptBtn = find.widgetWithText(OutlinedButton, 'Biên nhận');
    expect(receiptBtn, findsOneWidget);

    // Tap 'Biên nhận'
    await tester.tap(receiptBtn);
    await tester.pumpAndSettle();

    // Verify receipt sheet opened
    expect(find.text('BIÊN NHẬN ĐIỆN TỬ BQL'), findsOneWidget);
    expect(find.textContaining('REC-SVC-BOOKING-'), findsOneWidget);
    expect(find.text('SVC20261026001'), findsOneWidget);
    expect(find.text('Sao chép thông tin biên nhận'), findsOneWidget);
  });
}
