import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/resident_apartment_provider.dart';
import 'package:pka_home/features/resident/screens/create_issue_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final testUser = UserModel(
    id: 'user-1',
    fullName: 'Cư dân A',
    phone: '0901234567',
    role: 'resident',
  );

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier(testUser)),
        currentSelectedApartmentProvider.overrideWith((ref) => {
          'apartment_id': 'apt-1',
          'code': 'A0110',
        }),
      ],
      child: const MaterialApp(
        home: CreateIssueScreen(),
      ),
    );
  }

  testWidgets('CreateIssueScreen hiển thị đúng tiêu đề, mô tả và nút theo Wireframe Section 3', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // 1. Tiêu đề AppBar: Gửi Phản Ánh
    expect(find.text('Gửi Phản Ánh'), findsOneWidget);

    // 2. Nhãn hướng dẫn: Vui lòng mô tả sự cố hoặc yêu cầu hỗ trợ:
    expect(find.textContaining('Vui lòng mô tả sự cố hoặc yêu cầu hỗ trợ:'), findsOneWidget);

    // 3. Hint text trong ô nhập: Ví dụ: Bóng đèn hành lang tầng 5 bị cháy...
    expect(find.textContaining('Ví dụ: Bóng đèn hành lang tầng 5 bị cháy...'), findsOneWidget);

    // 4. Nhãn hình ảnh đính kèm
    expect(find.textContaining('Đính kèm hình ảnh (Tối đa 3 ảnh):'), findsOneWidget);

    // 5. Nút bấm: GỬI YÊU CẦU
    expect(find.widgetWithText(ElevatedButton, 'GỬI YÊU CẦU'), findsOneWidget);
  });
}
