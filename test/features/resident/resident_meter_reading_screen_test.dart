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
  final testUser = UserModel(
    id: 'user-res-1',
    fullName: 'Nguyễn Văn A',
    phone: '0901234567',
    role: 'resident',
  );

  final sampleApartmentData = <String, dynamic>{
    'apartment_id': 'apt-101',
    'code': 'A0110',
    'electric_reading': 120.0,
    'water_reading': 35.0,
  };

  final sampleSubmissions = <MeterReadingSubmissionModel>[
    MeterReadingSubmissionModel(
      id: 'sub-1',
      apartmentId: 'apt-101',
      apartmentCode: 'A0110',
      submittedBy: 'user-res-1',
      period: '09/2026',
      electricReading: 120.0,
      waterReading: 35.0,
      status: 'approved',
      createdAt: DateTime(2026, 9, 25),
      updatedAt: DateTime(2026, 9, 26),
    ),
    MeterReadingSubmissionModel(
      id: 'sub-2',
      apartmentId: 'apt-101',
      apartmentCode: 'A0110',
      submittedBy: 'user-res-1',
      period: '10/2026',
      electricReading: 155.0,
      waterReading: 42.0,
      status: 'pending',
      createdAt: DateTime(2026, 10, 5),
      updatedAt: DateTime(2026, 10, 5),
    ),
  ];

  Widget createTestWidget({
    Map<String, dynamic>? aptData,
    List<MeterReadingSubmissionModel>? submissions,
    MeterReadingRepository? repo,
  }) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
        residentApartmentIdProvider.overrideWith((ref) async => 'apt-101'),
        currentApartmentReadingsProvider.overrideWith((ref) async => aptData ?? sampleApartmentData),
        residentMeterReadingsProvider.overrideWith((ref) async => submissions ?? sampleSubmissions),
        if (repo != null) meterReadingRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        home: ResidentMeterReadingScreen(),
      ),
    );
  }

  testWidgets('hien thi dung thong tin chi so cu va danh sach lich su', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Kiem tra tieu de AppBar
    expect(find.text('Khai Báo Chỉ Số Điện Nước'), findsOneWidget);

    // Kiem tra the chi so ky truoc
    expect(find.textContaining('Chỉ số kỳ trước • Căn hộ A0110'), findsOneWidget);
    expect(find.text('120.0 kWh'), findsOneWidget);
    expect(find.text('35.0 m³'), findsOneWidget);

    // Kiem tra danh sach lich su
    expect(find.text('Lịch Sử Khai Báo Chỉ Số'), findsOneWidget);
    expect(find.text('Kỳ: 09/2026'), findsOneWidget);
    expect(find.text('Đã phê duyệt'), findsOneWidget);
    expect(find.text('Kỳ: 10/2026'), findsOneWidget);
    expect(find.text('Chờ phê duyệt'), findsOneWidget);
  });

  testWidgets('nhap chi so va gui thanh cong', (tester) async {
    final fakeRepo = FakeMeterReadingRepository();
    await tester.pumpWidget(createTestWidget(repo: fakeRepo));
    await tester.pumpAndSettle();

    // Tim cac text field
    final textFields = find.byType(TextFormField);
    expect(textFields, findsNWidgets(3));

    // Field 0 la Dien moi, Field 1 la Nuoc moi, Field 2 la Ky khai bao
    await tester.enterText(textFields.at(0), '160.0');
    await tester.enterText(textFields.at(1), '45.0');
    await tester.enterText(textFields.at(2), '11/2026');
    await tester.pumpAndSettle();

    // Cuon tim nut Gui chi so
    final submitButton = find.widgetWithText(ElevatedButton, 'Gửi chỉ số cho Ban Quản Lý');
    expect(submitButton, findsOneWidget);

    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(fakeRepo.submitCalled, isTrue);
  });

  testWidgets('kiem tra chan khi nhap chi so nho hon ky truoc', (tester) async {
    final fakeRepo = FakeMeterReadingRepository();
    await tester.pumpWidget(createTestWidget(repo: fakeRepo));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextFormField);
    // Nhap chi so nho hon ky truoc (100 < 120)
    await tester.enterText(textFields.at(0), '100.0');
    await tester.enterText(textFields.at(1), '40.0');
    await tester.pumpAndSettle();

    final submitButton = find.widgetWithText(ElevatedButton, 'Gửi chỉ số cho Ban Quản Lý');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump();

    // Hien SnackBar canh bao
    expect(find.textContaining('không được nhỏ hơn chỉ số cũ'), findsOneWidget);
    expect(fakeRepo.submitCalled, isFalse);
  });
}
