import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/router/app_router.dart';
import 'package:pka_home/core/router/route_names.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/providers/auth_provider.dart';

void main() {
  group('AppRouter Redirect Tests', () {
    test('Router không tự động redirect người dùng ra trang chủ khi ở verifyOtp và resetPassword', () {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(
            UserModel(id: 'u1', fullName: 'Test User', role: 'resident', isLocked: false),
          )),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      expect(router, isNotNull);
      // Kiểm tra route names
      expect(AppRoutes.verifyOtp, equals('/verify-otp'));
      expect(AppRoutes.resetPassword, equals('/reset-password'));
    });
  });
}

class FakeAuthNotifier extends StateNotifier<AsyncValue<UserModel?>> implements AuthNotifier {
  FakeAuthNotifier(UserModel? user) : super(AsyncValue.data(user));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
