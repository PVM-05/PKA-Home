import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/features/auth/screens/login_screen.dart';

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier() : super(const AsyncValue.data(null));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => FakeAuthNotifier()),
      ],
      child: const MaterialApp(
        home: LoginScreen(),
      ),
    );
  }

  testWidgets('LoginScreen hiển thị tiêu đề và dòng Quên mật khẩu chuẩn theo Wireframe', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // 1. Phải có phụ đề Ứng Dụng Quản Lý Chung Cư theo Wireframe
    expect(find.textContaining('Ứng Dụng Quản Lý Chung Cư'), findsOneWidget);

    // 2. Dòng Quên mật khẩu chuẩn Wireframe: "Quên mật khẩu? Vui lòng liên hệ Ban quản lý"
    final forgotPasswordBtn = find.text('Quên mật khẩu? Vui lòng liên hệ Ban quản lý');
    expect(forgotPasswordBtn, findsOneWidget);

    // 3. Nút Đăng nhập
    expect(find.widgetWithText(ElevatedButton, 'Đăng nhập'), findsOneWidget);

    // 4. Nhấn Quên mật khẩu mở dialog hướng dẫn
    await tester.tap(forgotPasswordBtn);
    await tester.pumpAndSettle();

    expect(find.text('Quên mật khẩu?'), findsOneWidget);
    expect(find.textContaining('Vui lòng liên hệ Văn phòng Ban Quản lý'), findsOneWidget);
  });
}
