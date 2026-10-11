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
    String? note,
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
  testWidgets('ResidentMeterReadingScreen hiển thị nhãn Mô phỏng nhận diện và không lưu ảnh giả lập làm bằng chứng thật', (tester) async {
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

    // 1. Kiểm tra nhãn nút rõ ràng là "Mô phỏng nhận diện" thay vì đánh lừa người dùng
    final scanButtons = find.widgetWithText(OutlinedButton, 'Mô phỏng nhận diện');
    expect(scanButtons, findsNWidgets(2), reason: 'Phải có 2 nút mô phỏng nhận diện cho điện và nước');

    // 2. Bấm nút mô phỏng nhận diện điện
    await tester.tap(scanButtons.first);
    await tester.pump(); // Start simulation
    expect(find.textContaining('Đang chạy thuật toán mô phỏng nhận diện'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    // 3. Kiểm tra thông báo dữ liệu mô phỏng
    expect(find.textContaining('Số liệu mô phỏng (Demo) • Vui lòng đối chiếu công tơ thực tế'), findsOneWidget);

    // 4. Nhập kỳ và nộp chỉ số
    final textFields = find.byType(TextFormField);
    // Nhập nước và kỳ
    await tester.enterText(textFields.at(1), '25.0');
    await tester.enterText(textFields.at(2), '11/2026');
    await tester.pumpAndSettle();

    final submitBtn = find.widgetWithText(ElevatedButton, 'Gửi chỉ số cho Ban Quản Lý');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // 5. Xác nhận không gửi URL ảnh mẫu giả lập
    expect(fakeRepo.submitCalled, isTrue);
    expect(fakeRepo.submittedElectricImageUrl, isNull, reason: 'Không được lưu ảnh mẫu giả lập làm bằng chứng thật');
  });
}
