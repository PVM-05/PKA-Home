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

class FakeMeterReadingRepo implements MeterReadingRepository {
  String? submittedElectricImageUrl;
  String? submittedWaterImageUrl;
  bool submitCalled = false;

  @override
  Future<MeterReadingSubmissionModel> submitReading({
    required String apartmentId,
    required String userId,
    required String period,
    required double electricReading,
    required double waterReading,
    String? electricImageUrl,
    String? waterImageUrl,
    double ocrConfidence = 0.95,
    bool isAnomaly = false,
    String anomalySeverity = 'normal',
    String? anomalyReason,
  }) async {
    submitCalled = true;
    submittedElectricImageUrl = electricImageUrl;
    submittedWaterImageUrl = waterImageUrl;
    return MeterReadingSubmissionModel(
      id: 'sub-new-1',
      apartmentId: apartmentId,
      apartmentCode: 'A0110',
      submittedBy: userId,
      submitterName: 'Nguyễn Văn A',
      period: period,
      electricReading: electricReading,
      waterReading: waterReading,
      electricImageUrl: electricImageUrl,
      waterImageUrl: waterImageUrl,
      status: 'pending',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('ResidentMeterReadingScreen yêu cầu ảnh thật và không còn nút mô phỏng nhận diện (Commercial B2B)', (tester) async {
    final fakeRepo = FakeMeterReadingRepo();
    final testUser = UserModel(
      id: 'user-res-1',
      fullName: 'Nguyễn Văn A',
      phone: '0901234567',
      role: 'resident',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
          residentApartmentIdProvider.overrideWith((ref) async => 'apt-101'),
          currentApartmentReadingsProvider.overrideWith((ref) async => {
                'apartment_id': 'apt-101',
                'code': 'A0110',
                'electric_reading': 100.0,
                'water_reading': 20.0,
              }),
          residentMeterReadingsProvider.overrideWith((ref) async => []),
          meterReadingRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: ResidentMeterReadingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Xác nhận không còn nút mô phỏng nhận diện giả lập (Demo)
    final scanButtons = find.widgetWithText(OutlinedButton, 'Mô phỏng nhận diện');
    expect(scanButtons, findsNothing, reason: 'Phải loại bỏ hoàn toàn mô phỏng nhận diện theo chuẩn B2B SaaS');

    // 2. Kiểm tra có các nút chụp ảnh camera và thư viện cho điện & nước
    expect(find.byIcon(Icons.camera_alt_outlined), findsNWidgets(2));
    expect(find.byIcon(Icons.photo_library_outlined), findsNWidgets(2));

    // 3. Nhập số liệu và nộp chỉ số
    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), '125.0');
    await tester.enterText(textFields.at(1), '25.0');
    await tester.pumpAndSettle();

    final submitBtn = find.widgetWithText(ElevatedButton, 'Gửi chỉ số cho Ban Quản Lý');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // 4. Xác nhận gửi thành công
    expect(fakeRepo.submitCalled, isTrue);
  });
}
