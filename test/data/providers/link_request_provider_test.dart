import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pka_home/data/models/user_model.dart';
import 'package:pka_home/data/repositories/auth_repository.dart';
import 'package:pka_home/data/providers/auth_provider.dart';
import 'package:pka_home/data/providers/link_request_provider.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    when(() => mockAuthRepository.currentUser).thenReturn(null);
    when(() => mockAuthRepository.authStateChanges).thenAnswer((_) => const Stream.empty());
  });

  group('residentLinkProvider Auth Reaction Unit Tests', () {
    test('Khởi tạo với user null -> trạng thái LinkStatus.none', () {
      final notifier = ResidentLinkNotifier(null);
      expect(notifier.state.status, equals(LinkStatus.none));
    });

    test('resetToForm() chuyển trạng thái về LinkStatus.none', () {
      final notifier = ResidentLinkNotifier(null);
      notifier.resetToForm();
      expect(notifier.state.status, equals(LinkStatus.none));
    });

    test('Khi authProvider đổi user -> residentLinkProvider tự động re-evaluate theo user mới', () {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
        ],
      );
      addTearDown(container.dispose);

      // Ban đầu chưa có user
      final authNotifier = container.read(authProvider.notifier);
      authNotifier.state = const AsyncValue.data(null);
      expect(container.read(residentLinkProvider).status, equals(LinkStatus.none));

      // Lấy notifier ban đầu
      final initialNotifier = container.read(residentLinkProvider.notifier);

      // User A đăng nhập
      authNotifier.state = AsyncValue.data(
        UserModel(id: 'user-a', fullName: 'User A', role: 'resident'),
      );

      // Sau khi authProvider đổi user, residentLinkProvider tạo ra notifier mới
      final newNotifier = container.read(residentLinkProvider.notifier);
      expect(identical(initialNotifier, newNotifier), isFalse, reason: 'ResidentLinkNotifier phải được tạo mới khi đổi user');

      // Đăng xuất: user trở về null -> residentLinkProvider tạo notifier với user null
      authNotifier.state = const AsyncValue.data(null);
      final logoutNotifier = container.read(residentLinkProvider.notifier);
      expect(identical(newNotifier, logoutNotifier), isFalse, reason: 'ResidentLinkNotifier phải được tạo mới khi đăng xuất');
      expect(container.read(residentLinkProvider).status, equals(LinkStatus.none));
    });
  });
}
