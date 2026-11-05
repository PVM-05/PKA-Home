import 'package:flutter_test/flutter_test.dart';
import 'package:pka_home/core/security/auth_rate_limiter.dart';

void main() {
  group('AuthRateLimiter Tests', () {
    late AuthRateLimiter limiter;

    setUp(() {
      limiter = AuthRateLimiter(
        maxLoginAttempts: 5,
        lockoutDuration: const Duration(minutes: 15),
        otpCooldownDuration: const Duration(seconds: 60),
        maxOtpVerifyAttempts: 3,
      );
    });

    test('Đăng nhập lần đầu được phép thực hiện', () {
      final status = limiter.checkLoginAllowed('user@pka.vn');
      expect(status.isAllowed, isTrue);
      expect(status.remainingAttempts, 5);
      expect(status.lockoutRemainingSeconds, 0);
    });

    test('Ghi nhận số lần thử sai giảm dần remainingAttempts', () {
      limiter.recordLoginFailure('user@pka.vn');
      final status1 = limiter.checkLoginAllowed('user@pka.vn');
      expect(status1.isAllowed, isTrue);
      expect(status1.remainingAttempts, 4);

      limiter.recordLoginFailure('user@pka.vn');
      limiter.recordLoginFailure('user@pka.vn');
      final status3 = limiter.checkLoginAllowed('user@pka.vn');
      expect(status3.isAllowed, isTrue);
      expect(status3.remainingAttempts, 2);
    });

    test('Khóa đăng nhập sau khi vượt quá 5 lần thử sai', () {
      for (int i = 0; i < 5; i++) {
        limiter.recordLoginFailure('user@pka.vn');
      }

      final status = limiter.checkLoginAllowed('user@pka.vn');
      expect(status.isAllowed, isFalse);
      expect(status.remainingAttempts, 0);
      expect(status.lockoutRemainingSeconds, greaterThan(0));
      expect(status.message, contains('Tài khoản tạm thời bị khóa'));
    });

    test('resetLoginAttempts đưa trạng thái đăng nhập về ban đầu', () {
      limiter.recordLoginFailure('user@pka.vn');
      limiter.recordLoginFailure('user@pka.vn');
      limiter.resetLoginAttempts('user@pka.vn');

      final status = limiter.checkLoginAllowed('user@pka.vn');
      expect(status.isAllowed, isTrue);
      expect(status.remainingAttempts, 5);
    });

    test('checkOtpSendAllowed bắt buộc giãn cách 60 giây giữa các lần gửi mã', () {
      final status1 = limiter.checkOtpSendAllowed('user@pka.vn');
      expect(status1.isAllowed, isTrue);

      limiter.recordOtpSent('user@pka.vn');

      final status2 = limiter.checkOtpSendAllowed('user@pka.vn');
      expect(status2.isAllowed, isFalse);
      expect(status2.cooldownRemainingSeconds, greaterThan(0));
      expect(status2.message, contains('Vui lòng chờ'));
    });

    test('checkOtpVerifyAllowed khóa sau 3 lần nhập sai mã OTP', () {
      for (int i = 0; i < 3; i++) {
        limiter.recordOtpVerifyFailure('user@pka.vn');
      }

      final status = limiter.checkOtpVerifyAllowed('user@pka.vn');
      expect(status.isAllowed, isFalse);
      expect(status.message, contains('Nhập sai mã OTP quá 3 lần'));
    });
  });
}

