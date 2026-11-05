import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kết quả kiểm tra giới hạn tốc độ (Rate Limit Check)
class RateLimitResult {
  final bool isAllowed;
  final int remainingAttempts;
  final int lockoutRemainingSeconds;
  final int cooldownRemainingSeconds;
  final String? message;

  const RateLimitResult({
    required this.isAllowed,
    this.remainingAttempts = 0,
    this.lockoutRemainingSeconds = 0,
    this.cooldownRemainingSeconds = 0,
    this.message,
  });
}

/// Bản ghi theo dõi số lần thử sai của 1 định danh (email/số điện thoại)
class _AttemptRecord {
  int attempts = 0;
  DateTime? lockedUntil;

  _AttemptRecord();

  bool get isLocked => lockedUntil != null && DateTime.now().isBefore(lockedUntil!);

  int get remainingLockoutSeconds {
    if (!isLocked) return 0;
    return max(0, lockedUntil!.difference(DateTime.now()).inSeconds);
  }
}

/// Bộ kiểm soát tốc độ xác thực chống tấn công Brute-Force và spam OTP
class AuthRateLimiter {
  final int maxLoginAttempts;
  final Duration lockoutDuration;
  final Duration otpCooldownDuration;
  final int maxOtpVerifyAttempts;

  final Map<String, _AttemptRecord> _loginRecords = {};
  final Map<String, DateTime> _otpSentRecords = {};
  final Map<String, _AttemptRecord> _otpVerifyRecords = {};

  AuthRateLimiter({
    this.maxLoginAttempts = 5,
    this.lockoutDuration = const Duration(minutes: 15),
    this.otpCooldownDuration = const Duration(seconds: 60),
    this.maxOtpVerifyAttempts = 3,
  });

  String _normalize(String identifier) => identifier.trim().toLowerCase();

  // ---------------------------------------------------------------------------
  // 1. Kiểm soát đăng nhập mật khẩu (Login Protection)
  // ---------------------------------------------------------------------------

  RateLimitResult checkLoginAllowed(String identifier) {
    final key = _normalize(identifier);
    final record = _loginRecords[key];

    if (record == null) {
      return RateLimitResult(
        isAllowed: true,
        remainingAttempts: maxLoginAttempts,
      );
    }

    if (record.isLocked) {
      final secs = record.remainingLockoutSeconds;
      final mins = (secs / 60).ceil();
      return RateLimitResult(
        isAllowed: false,
        remainingAttempts: 0,
        lockoutRemainingSeconds: secs,
        message: 'Tài khoản tạm thời bị khóa do nhập sai mật khẩu nhiều lần. Vui lòng thử lại sau $mins phút.',
      );
    }

    // Nếu thời gian khóa đã trôi qua, tự động reset
    if (record.lockedUntil != null && DateTime.now().isAfter(record.lockedUntil!)) {
      _loginRecords.remove(key);
      return RateLimitResult(
        isAllowed: true,
        remainingAttempts: maxLoginAttempts,
      );
    }

    final remaining = max(0, maxLoginAttempts - record.attempts);
    return RateLimitResult(
      isAllowed: remaining > 0,
      remainingAttempts: remaining,
    );
  }

  void recordLoginFailure(String identifier) {
    final key = _normalize(identifier);
    final record = _loginRecords.putIfAbsent(key, () => _AttemptRecord());

    record.attempts++;
    if (record.attempts >= maxLoginAttempts) {
      record.lockedUntil = DateTime.now().add(lockoutDuration);
    }
  }

  void resetLoginAttempts(String identifier) {
    _loginRecords.remove(_normalize(identifier));
  }

  // ---------------------------------------------------------------------------
  // 2. Kiểm soát gửi mã OTP (OTP Send Cooldown)
  // ---------------------------------------------------------------------------

  RateLimitResult checkOtpSendAllowed(String identifier) {
    final key = _normalize(identifier);
    final lastSent = _otpSentRecords[key];

    if (lastSent == null) {
      return const RateLimitResult(isAllowed: true);
    }

    final diff = DateTime.now().difference(lastSent);
    if (diff < otpCooldownDuration) {
      final remainingSecs = (otpCooldownDuration - diff).inSeconds;
      return RateLimitResult(
        isAllowed: false,
        cooldownRemainingSeconds: remainingSecs,
        message: 'Vui lòng chờ $remainingSecs giây trước khi yêu cầu gửi lại mã OTP.',
      );
    }

    return const RateLimitResult(isAllowed: true);
  }

  void recordOtpSent(String identifier) {
    _otpSentRecords[_normalize(identifier)] = DateTime.now();
  }

  // ---------------------------------------------------------------------------
  // 3. Kiểm soát xác thực mã OTP (OTP Verify Protection)
  // ---------------------------------------------------------------------------

  RateLimitResult checkOtpVerifyAllowed(String identifier) {
    final key = _normalize(identifier);
    final record = _otpVerifyRecords[key];

    if (record == null) {
      return RateLimitResult(
        isAllowed: true,
        remainingAttempts: maxOtpVerifyAttempts,
      );
    }

    if (record.isLocked) {
      final secs = record.remainingLockoutSeconds;
      final mins = (secs / 60).ceil();
      return RateLimitResult(
        isAllowed: false,
        remainingAttempts: 0,
        lockoutRemainingSeconds: secs,
        message: 'Nhập sai mã OTP quá $maxOtpVerifyAttempts lần. Vui lòng chờ $mins phút để thử lại.',
      );
    }

    final remaining = max(0, maxOtpVerifyAttempts - record.attempts);
    return RateLimitResult(
      isAllowed: remaining > 0,
      remainingAttempts: remaining,
    );
  }

  void recordOtpVerifyFailure(String identifier) {
    final key = _normalize(identifier);
    final record = _otpVerifyRecords.putIfAbsent(key, () => _AttemptRecord());

    record.attempts++;
    if (record.attempts >= maxOtpVerifyAttempts) {
      record.lockedUntil = DateTime.now().add(const Duration(minutes: 10));
    }
  }

  void resetOtpVerifyAttempts(String identifier) {
    _otpVerifyRecords.remove(_normalize(identifier));
  }
}

/// Riverpod Provider cung cấp AuthRateLimiter singleton
final authRateLimiterProvider = Provider<AuthRateLimiter>((ref) {
  return AuthRateLimiter();
});

