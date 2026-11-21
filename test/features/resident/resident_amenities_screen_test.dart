import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivona/core/theme/app_theme.dart';
import 'package:vivona/data/models/building_amenity_model.dart';
import 'package:vivona/data/models/amenity_booking_model.dart';
import 'package:vivona/data/providers/handbook_provider.dart';
import 'package:vivona/data/providers/amenity_booking_provider.dart';
import 'package:vivona/features/resident/screens/resident_amenities_screen.dart';

void main() {
  final now = DateTime.now();

  final mockAmenities = <BuildingAmenityModel>[
    BuildingAmenityModel(
      id: 'amenity-01',
      name: 'Hồ Bơi Chân Mây Tầng Thượng',
      description: 'Phục vụ cư dân miễn phí, nước ấm bốn mùa.',
      openHours: '06:00 - 21:00',
      bookingType: 'shared',
      maxCapacity: 25,
      feeAmount: 0,
      displayOrder: 1,
      createdAt: now,
    ),
    BuildingAmenityModel(
      id: 'amenity-02',
      name: 'Khu Vực Nướng BBQ Ngoài Trời',
      description: 'Khu vực nướng gia đình view công viên trung tâm.',
      openHours: '17:00 - 22:00',
      bookingType: 'exclusive',
      maxCapacity: 15,
      feeAmount: 200000,
      depositAmount: 500000,
      displayOrder: 2,
      createdAt: now,
    ),
  ];

  final mockBookings = <AmenityBookingModel>[
    AmenityBookingModel(
      id: 'booking-01',
      amenityId: 'amenity-02',
      apartmentId: 'apt-01',
      amenityName: 'Khu Vực Nướng BBQ Ngoài Trời',
      bookingDate: now.add(const Duration(days: 2)),
      timeSlot: '18:00 - 21:00',
      status: 'confirmed',
      depositAmount: 500000,
      depositStatus: 'received',
      createdAt: now,
    ),
  ];

  Widget createWidget() {
    return ProviderScope(
      overrides: [
        buildingAmenitiesProvider.overrideWith((ref) => Future.value(mockAmenities)),
        myAmenityBookingsProvider.overrideWith((ref) => Future.value(mockBookings)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ResidentAmenitiesScreen(),
      ),
    );
  }

  group('ResidentAmenitiesScreen Tests', () {
    testWidgets('hiển thị đầy đủ 2 tabs, danh mục tiện ích và thông tin chi tiết', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Tiện Ích Tòa Nhà'), findsOneWidget);
      expect(find.text('Danh mục tiện ích'), findsOneWidget);
      expect(find.text('Lịch đặt của tôi'), findsOneWidget);

      // Kiểm tra thẻ tiện ích
      expect(find.text('Hồ Bơi Chân Mây Tầng Thượng'), findsOneWidget);
      expect(find.text('Khu Vực Nướng BBQ Ngoài Trời'), findsOneWidget);
      expect(find.text('06:00 - 21:00'), findsOneWidget);
      expect(find.text('Tối đa 25 người'), findsOneWidget);
      expect(find.text('Miễn phí'), findsOneWidget);
      expect(find.text('Đặt lịch sử dụng'), findsNWidgets(2));
    });

    testWidgets('chuyển tab Lịch đặt của tôi hiển thị ca đặt đã xác nhận', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Chuyển sang tab Lịch đặt của tôi
      await tester.tap(find.text('Lịch đặt của tôi'));
      await tester.pumpAndSettle();

      expect(find.text('Khu Vực Nướng BBQ Ngoài Trời'), findsOneWidget);
      expect(find.text('Đã xác nhận'), findsOneWidget);
      expect(find.text('18:00 - 21:00'), findsOneWidget);
      expect(find.textContaining('Tiền cọc:'), findsOneWidget);
    });

    testWidgets('tìm kiếm tiện ích lọc chính xác theo từ khóa', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Nhập từ khóa 'BBQ'
      await tester.enterText(find.byType(TextField), 'BBQ');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.text('Khu Vực Nướng BBQ Ngoài Trời'), findsOneWidget);
      expect(find.text('Hồ Bơi Chân Mây Tầng Thượng'), findsNothing);
    });
  });
}
