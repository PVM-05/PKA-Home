import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/providers/link_request_provider.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/features/resident/screens/link_request_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>>
    implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeResidentLinkNotifier extends StateNotifier<ResidentLinkStatus>
    implements ResidentLinkNotifier {
  FakeResidentLinkNotifier() : super(ResidentLinkStatus(status: LinkStatus.none));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('LinkRequestScreen hiển thị ô nhập mã căn hộ thủ công khi danh mục căn hộ rỗng', (tester) async {
    final residentUser = UserModel(
      id: 'res-user-1',
      fullName: 'Cư dân Test',
      phone: '0909999999',
      role: 'resident',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(residentUser)),
          residentLinkProvider.overrideWith((ref) => FakeResidentLinkNotifier()),
          // Giả lập danh mục căn hộ rỗng []
          availableApartmentsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(
          home: LinkRequestScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Phải thấy banner cảnh báo
    expect(find.textContaining('Chưa tải được danh mục căn hộ tự động'), findsOneWidget);

    // QUAN TRỌNG: Phải thấy ô nhập mã căn hộ thủ công (không bị kẹt)
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Gửi yêu cầu'), findsOneWidget);

    // Người dùng có thể nhập mã căn hộ
    await tester.enterText(find.byType(TextFormField), 'A0110');
    await tester.pump();

    expect(find.text('A0110'), findsOneWidget);
  });

  testWidgets('LinkRequestScreen cho phép chuyển đổi linh hoạt giữa dropdown và nhập mã trực tiếp', (tester) async {
    final residentUser = UserModel(
      id: 'res-user-1',
      fullName: 'Cư dân Test',
      phone: '0909999999',
      role: 'resident',
    );

    final mockApartments = [
      ParsedApartment(code: 'A0110', building: 'A', floor: '1', room: 'A0110'),
      ParsedApartment(code: 'A0111', building: 'A', floor: '1', room: 'A0111'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(residentUser)),
          residentLinkProvider.overrideWith((ref) => FakeResidentLinkNotifier()),
          availableApartmentsProvider.overrideWith((ref) async => mockApartments),
        ],
        child: const MaterialApp(
          home: LinkRequestScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Mặc định hiển thị Tòa nhà, Tầng, Phòng và nút "Nhập mã trực tiếp"
    expect(find.text('Tòa nhà'), findsOneWidget);
    expect(find.text('Nhập mã trực tiếp'), findsOneWidget);

    // Nhấn chuyển sang nhập mã trực tiếp
    await tester.tap(find.text('Nhập mã trực tiếp'));
    await tester.pump();

    // Hiển thị TextFormField và nút quay lại "Chọn theo Tòa - Tầng - Phòng"
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Chọn theo Tòa - Tầng - Phòng'), findsOneWidget);

    // Nhấn quay lại dropdown
    await tester.tap(find.text('Chọn theo Tòa - Tầng - Phòng'));
    await tester.pump();

    expect(find.text('Tòa nhà'), findsOneWidget);
    expect(find.text('Nhập mã trực tiếp'), findsOneWidget);
  });
}
