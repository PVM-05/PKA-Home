import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pka_home/data/providers/auth_provider.dart';

void main() {
  group('Expired Session Guard Tests', () {
    test('sessionExpiredNoticeProvider mặc định là false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final isExpired = container.read(sessionExpiredNoticeProvider);
      expect(isExpired, isFalse);
    });

    test('Có thể bật và tắt cờ sessionExpiredNoticeProvider một cách an toàn', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(sessionExpiredNoticeProvider.notifier).state = true;
      expect(container.read(sessionExpiredNoticeProvider), isTrue);

      container.read(sessionExpiredNoticeProvider.notifier).state = false;
      expect(container.read(sessionExpiredNoticeProvider), isFalse);
    });
  });
}
