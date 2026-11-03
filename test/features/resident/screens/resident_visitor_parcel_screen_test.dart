import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/data/models/parcel_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/models/visitor_pass_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/front_desk_provider.dart';
import 'package:pka_home/data/providers/resident_apartment_provider.dart';
import 'package:pka_home/features/resident/screens/resident_visitor_parcel_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('ResidentVisitorParcelScreen hien thi day du 2 tabs va thong tin ma PIN', (tester) async {
    const testAptId = 'apt-01';

    final testPasses = [
      VisitorPassModel(
        id: 'vp-test-01',
        passCode: 'VP-202611-00001',
        apartmentId: testAptId,
        hostUserId: 'user-01',
        visitorName: 'Nguyễn Văn Nam',
        expectedArrival: DateTime.now().add(const Duration(hours: 2)),
        qrPayload: 'PKAPASS:VP-202611-00001:123456',
        createdAt: DateTime.now(),
      ),
    ];

    final testParcels = [
      ParcelModel(
        id: 'pcl-test-01',
        parcelCode: 'PCL-202611-00001',
        apartmentId: testAptId,
        carrier: 'SPX',
        trackingNumber: 'SPXVN999888',
        shelfLocation: 'Kệ A1 - Tầng 2',
        pickupPin: '582914',
        status: 'arrived',
        arrivedAt: DateTime.now().subtract(const Duration(hours: 3)),
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ];

    final testUser = UserModel(
      id: 'user-01',
      fullName: 'Cư Dân Test',
      role: 'resident',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
          selectedApartmentIdProvider.overrideWith((ref) => SelectedApartmentNotifier()..selectApartment(testAptId)),
          residentVisitorPassesProvider(testAptId).overrideWith((ref) => Future.value(testPasses)),
          residentParcelsProvider(testAptId).overrideWith((ref) => Future.value(testParcels)),
        ],
        child: const MaterialApp(
          home: ResidentVisitorParcelScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Kiểm tra tiêu đề và tabs
    expect(find.text('Đón Khách & Bưu Kiện'), findsOneWidget);
    expect(find.text('Khách Viếng Thăm'), findsOneWidget);
    expect(find.text('Bưu Kiện Của Tôi'), findsOneWidget);

    // 2. Tab 1: Khách viếng thăm
    expect(find.text('Nguyễn Văn Nam'), findsOneWidget);
    expect(find.text('VP-202611-00001'), findsOneWidget);
    expect(find.text('Xem Mã QR'), findsOneWidget);

    // 3. Chuyển sang Tab 2: Bưu kiện
    await tester.tap(find.text('Bưu Kiện Của Tôi'));
    await tester.pumpAndSettle();

    expect(find.text('Shopee Xpress (SPX)'), findsOneWidget);
    expect(find.text('582914'), findsOneWidget);
    expect(find.textContaining('Kệ A1 - Tầng 2'), findsOneWidget);
  });
}
