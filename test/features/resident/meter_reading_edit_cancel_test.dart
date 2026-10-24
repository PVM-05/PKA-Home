import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/meter_reading_submission_model.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/meter_reading_provider.dart';
import 'package:pka_home/data/providers/vehicle_provider.dart';
import 'package:pka_home/data/repositories/meter_reading_repository.dart';
import 'package:pka_home/features/resident/screens/resident_meter_reading_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMeterReadingRepository implements MeterReadingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<MeterReadingSubmissionModel>> getMySubmissions(String apartmentId) async => [];
}

void main() {
  testWidgets('ResidentMeterReadingScreen hien thi nut Sua va Huy cho phieu pending, an cho phieu approved', (tester) async {
    final pendingSub = MeterReadingSubmissionModel(
      id: 'sub-pending-1',
      apartmentId: 'apt-1',
      apartmentCode: 'A0110',
      submittedBy: 'user-1',
      period: '10/2026',
      electricReading: 1500.0,
      waterReading: 90.0,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    final approvedSub = MeterReadingSubmissionModel(
      id: 'sub-approved-2',
      apartmentId: 'apt-1',
      apartmentCode: 'A0110',
      submittedBy: 'user-1',
      period: '09/2026',
      electricReading: 1400.0,
      waterReading: 80.0,
      status: 'approved',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
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
          authProvider.overrideWith((ref) => FakeAuthNotifier(fakeUser)),
          residentApartmentIdProvider.overrideWith((ref) => 'apt-1'),
          currentApartmentReadingsProvider.overrideWith((ref) => Future.value({
            'id': 'apt-1',
            'code': 'A0110',
            'electric_reading': 1400.0,
            'water_reading': 80.0,
          })),
          residentMeterReadingsProvider.overrideWith((ref) => Future.value([pendingSub, approvedSub])),
          meterReadingRepositoryProvider.overrideWithValue(FakeMeterReadingRepository()),
        ],
        child: const MaterialApp(
          home: ResidentMeterReadingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Xác nhận hiển thị 2 kỳ
    expect(find.text('Kỳ: 10/2026'), findsOneWidget);
    expect(find.text('Kỳ: 09/2026'), findsOneWidget);

    // Nút "Sửa chỉ số" và "Hủy phiếu" phải xuất hiện cho pendingSub
    expect(find.text('Sửa chỉ số'), findsOneWidget);
    expect(find.text('Hủy phiếu'), findsOneWidget);
  });
}
